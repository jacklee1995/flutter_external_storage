import 'dart:io' as io;
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as crypto;
import 'package:mime/mime.dart' as mime;

import '../models/file_info.dart';
import 'entries.dart';

Future<io.File> _existingFile(String path) async {
  final file = io.File(path);
  if (!await file.exists()) {
    throw io.FileSystemException('File does not exist or is not a file', path);
  }
  return file;
}

/// [length] < 0 表示读到文件末尾；范围超出文件时返回实际可读的部分（可能为空）。
Future<Uint8List> readFile(String path, int offset, int length) async {
  final file = await _existingFile(path);
  if (offset <= 0 && length < 0) return file.readAsBytes();

  final raf = await file.open();
  try {
    final size = await raf.length();
    final start = offset.clamp(0, size);
    final available = size - start;
    final count = length < 0 ? available : math.min(length, available);
    if (count <= 0) return Uint8List(0);

    await raf.setPosition(start);
    final buffer = Uint8List(count);
    var read = 0;
    while (read < count) {
      final n = await raf.readInto(buffer, read, count);
      if (n <= 0) break;
      read += n;
    }
    return read == count ? buffer : Uint8List.sublistView(buffer, 0, read);
  } finally {
    await raf.close();
  }
}

Future<int> writeFile(String path, Uint8List data, bool append) async {
  final file = io.File(path);
  await file.parent.create(recursive: true);
  await file.writeAsBytes(
    data,
    mode: append ? io.FileMode.append : io.FileMode.write,
    flush: true,
  );
  return data.length;
}

Future<void> copyFile(String source, String target) async {
  final file = await _existingFile(source);
  if (await isSameEntity(source, target)) {
    throw io.FileSystemException('Source and target are the same file', target);
  }
  await io.File(target).parent.create(recursive: true);
  await file.copy(target);
}

Future<void> moveFile(String source, String target) async {
  final file = await _existingFile(source);
  await io.File(target).parent.create(recursive: true);
  try {
    await file.rename(target);
  } on io.FileSystemException {
    if (await isSameEntity(source, target)) rethrow;
    // 跨卷移动（如内部存储 -> SD 卡）时 rename 返回 EXDEV，退化为复制后删除。
    final copy = await file.copy(target);
    try {
      await file.delete();
    } catch (_) {
      await copy.delete();
      rethrow;
    }
  }
}

Future<void> deleteFile(String path) async {
  final file = await _existingFile(path);
  await file.delete();
}

Future<FileInfo> getFileInfo(String path) async {
  final stat = await io.FileStat.stat(path);
  if (stat.type == io.FileSystemEntityType.notFound) {
    throw io.FileSystemException('File does not exist', path);
  }
  return fileInfoFromStat(absolutePath(path), stat);
}

Future<String> calculateMD5(String path) async {
  await _existingFile(path);
  // 哈希是纯 CPU 计算，放到后台 isolate，避免大文件卡住 UI。
  return Isolate.run(() => _md5(path));
}

Future<String> _md5(String path) async =>
    (await crypto.md5.bind(io.File(path).openRead()).first).toString();

Future<void> createFile(String path) async {
  if (await pathExists(path)) {
    throw io.FileSystemException('Path already exists', path);
  }
  await io.File(path).create(recursive: true, exclusive: true);
}

/// 先按文件头魔数识别（扩展名错误时也能识别），再按扩展名。
Future<String?> getMimeType(String path) async {
  final file = await _existingFile(path);
  final raf = await file.open();
  final List<int> header;
  try {
    header = await raf.read(mime.defaultMagicNumbersMaxLength);
  } finally {
    await raf.close();
  }
  return mime.lookupMimeType(path, headerBytes: header);
}

Future<void> truncateFile(String path, int size) async {
  final file = await _existingFile(path);
  // append 模式打开不会先清空文件。
  final raf = await file.open(mode: io.FileMode.append);
  try {
    await raf.truncate(size);
  } finally {
    await raf.close();
  }
}
