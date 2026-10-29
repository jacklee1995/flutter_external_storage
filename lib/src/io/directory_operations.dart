import 'dart:io' as io;
import 'dart:isolate';

import 'package:path/path.dart' as p;

import '../models/directory_info.dart';
import '../models/file_info.dart';
import 'access_flags.dart';
import 'entries.dart';

/// 卷容量（字节），由原生端提供；dart:io 没有 statvfs。
typedef StorageSpace = ({int total, int free, int usable});

Future<io.Directory> _existingDirectory(String path) async {
  final dir = io.Directory(path);
  if (!await dir.exists()) {
    throw io.FileSystemException(
        'Directory does not exist or is not a directory', path);
  }
  return dir;
}

Future<void> _ensureTargetFree(String target) async {
  if (await pathExists(target)) {
    throw io.FileSystemException('Target already exists', target);
  }
}

/// 路径不是可读目录时返回空列表。递归遍历跳过无权限的子目录（如 Android 11+ 的
/// Android/data），会跟随指向目录的符号链接但不会重复进入同一目录。
Future<List<FileInfo>> listDirectory(String path, bool recursive) {
  final root = absolutePath(path);
  return Isolate.run(() => _listSync(root, recursive));
}

List<FileInfo> _listSync(String root, bool recursive) {
  final entries = <FileInfo>[];
  final visited = <String>{realPathSync(root)};

  void walk(String dir) {
    final List<io.FileSystemEntity> children;
    try {
      children = io.Directory(dir).listSync(followLinks: false);
    } on io.FileSystemException {
      return;
    }
    for (final child in children) {
      final stat = io.FileStat.statSync(child.path);
      entries.add(fileInfoFromStat(child.path, stat));
      if (recursive &&
          stat.type == io.FileSystemEntityType.directory &&
          visited.add(realPathSync(child.path))) {
        walk(child.path);
      }
    }
  }

  walk(root);
  return entries;
}

Future<void> createDirectory(String path, bool recursive) async {
  await _ensureTargetFree(path);
  await io.Directory(path).create(recursive: recursive);
}

/// 递归删除不会跟随符号链接（只删除链接本身）。
Future<void> deleteDirectory(String path, bool recursive) async {
  final dir = await _existingDirectory(path);
  await dir.delete(recursive: recursive);
}

Future<void> moveDirectory(String source, String target) async {
  final dir = await _existingDirectory(source);
  await _ensureTargetFree(target);
  final src = absolutePath(source);
  final dst = absolutePath(target);
  if (p.isWithin(src, dst)) {
    throw io.FileSystemException('Cannot move a directory into itself', target);
  }
  await io.Directory(p.dirname(dst)).create(recursive: true);
  try {
    await dir.rename(dst);
  } on io.FileSystemException {
    // 跨卷移动（EXDEV）：复制完成后再删除源目录。
    await _copyTreeOrCleanUp(src, dst);
    await dir.delete(recursive: true);
  }
}

Future<void> copyDirectory(String source, String target) async {
  await _existingDirectory(source);
  await _ensureTargetFree(target);
  final src = absolutePath(source);
  final dst = absolutePath(target);
  if (p.isWithin(src, dst)) {
    throw io.FileSystemException('Cannot copy a directory into itself', target);
  }
  await _copyTreeOrCleanUp(src, dst);
}

Future<void> _copyTreeOrCleanUp(String source, String target) async {
  try {
    await _copyTree(source, target, {realPathSync(source)});
  } catch (_) {
    try {
      await io.Directory(target).delete(recursive: true);
    } on io.FileSystemException {
      // 目标可能根本没有创建成功。
    }
    rethrow;
  }
}

// 跟随符号链接复制内容：FUSE 共享存储和 FAT/exFAT 的 SD 卡都不支持创建链接。
Future<void> _copyTree(String source, String target, Set<String> visited) async {
  await io.Directory(target).create(recursive: true);
  await for (final entity in io.Directory(source).list(followLinks: true)) {
    final destination = p.join(target, p.basename(entity.path));
    if (entity is io.Directory) {
      if (visited.add(realPathSync(entity.path))) {
        await _copyTree(entity.path, destination, visited);
      }
    } else if (entity is io.File) {
      await entity.copy(destination);
    }
  }
}

Future<DirectoryInfo> getDirectoryInfo(
  String path,
  Future<StorageSpace> Function(String path) storageSpace,
) async {
  final dir = await _existingDirectory(path);
  final abs = absolutePath(path);
  final stat = await dir.stat();
  final flags = accessFlags(abs, stat.mode);

  var fileCount = 0;
  var directoryCount = 0;
  final children = dir
      .list(followLinks: true)
      .handleError((Object _) {}, test: (e) => e is io.FileSystemException);
  await for (final child in children) {
    if (child is io.File) {
      fileCount++;
    } else if (child is io.Directory) {
      directoryCount++;
    }
  }

  final space = await storageSpace(abs);
  final parent = p.dirname(abs);
  final name = p.basename(abs);
  return DirectoryInfo(
    name: name,
    path: abs,
    parent: parent == abs ? null : parent,
    lastModified: stat.modified,
    canRead: flags.read,
    canWrite: flags.write,
    canExecute: flags.execute,
    isHidden: name.startsWith('.'),
    totalSpace: space.total,
    freeSpace: space.free,
    usableSpace: space.usable,
    fileCount: fileCount,
    directoryCount: directoryCount,
  );
}

Future<bool> isDirectoryEmpty(String path) async {
  final dir = await _existingDirectory(path);
  return dir.list().isEmpty;
}

/// 所有文件大小之和；不跟随符号链接，避免重复计算和循环。
Future<int> getDirectorySize(String path) async {
  await _existingDirectory(path);
  final root = absolutePath(path);
  return Isolate.run(() => _sizeSync(root));
}

int _sizeSync(String root) {
  var total = 0;

  void walk(String dir) {
    final List<io.FileSystemEntity> children;
    try {
      children = io.Directory(dir).listSync(followLinks: false);
    } on io.FileSystemException {
      return;
    }
    for (final child in children) {
      if (child is io.Directory) {
        walk(child.path);
      } else if (child is io.File) {
        final size = io.FileStat.statSync(child.path).size;
        if (size > 0) total += size;
      }
    }
  }

  walk(root);
  return total;
}

Future<bool> directoryExists(String path) => io.Directory(path).exists();
