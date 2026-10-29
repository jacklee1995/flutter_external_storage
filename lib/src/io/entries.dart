import 'dart:io' as io;

import 'package:path/path.dart' as p;

import '../models/file_info.dart';
import 'access_flags.dart';

/// 规范化为绝对路径（去掉 `.`、`..` 和结尾的分隔符），作为回传和比较用的路径。
String absolutePath(String path) => p.normalize(p.absolute(path));

/// [stat] 应该跟随符号链接（`FileStat.stat` 的默认行为），与 java.io.File 一致。
FileInfo fileInfoFromStat(String path, io.FileStat stat) {
  final name = p.basename(path);
  final flags = accessFlags(path, stat.mode);
  return FileInfo(
    name: name,
    path: path,
    size: stat.size < 0 ? 0 : stat.size,
    lastModified: stat.modified,
    isDirectory: stat.type == io.FileSystemEntityType.directory,
    isFile: stat.type == io.FileSystemEntityType.file,
    canRead: flags.read,
    canWrite: flags.write,
    canExecute: flags.execute,
    isHidden: name.startsWith('.'),
  );
}

/// 解析符号链接后的真实路径，用于递归遍历时识别循环链接。
String realPathSync(String path) {
  try {
    return io.File(path).resolveSymbolicLinksSync();
  } on io.FileSystemException {
    return path;
  }
}

Future<bool> pathExists(String path) async =>
    await io.FileSystemEntity.type(path) != io.FileSystemEntityType.notFound;

Future<bool> isSameEntity(String a, String b) async {
  try {
    return await io.FileSystemEntity.identical(a, b);
  } on io.FileSystemException {
    return false;
  }
}
