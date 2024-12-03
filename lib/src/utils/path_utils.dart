import 'dart:io' as io;
import 'package:path/path.dart' as p;

/// 路径工具类
class PathUtils {
  /// 规范化路径
  ///
  /// 将路径转换为标准格式，处理 . 和 .. 引用，统一分隔符
  static String normalize(String path) {
    return p.normalize(path);
  }

  /// 获取绝对路径
  ///
  /// 如果传入的是相对路径，则转换为绝对路径
  static String absolute(String path) {
    return p.absolute(path);
  }

  /// 获取相对路径
  ///
  /// [from] 基准路径
  /// [to] 目标路径
  static String relative(String path, {String? from}) {
    return p.relative(path, from: from);
  }

  /// 获取路径的父目录
  static String dirname(String path) {
    return p.dirname(path);
  }

  /// 获取路径的文件名部分
  static String basename(String path) {
    return p.basename(path);
  }

  /// 获取路径的扩展名
  static String extension(String path) {
    return p.extension(path);
  }

  /// 获取不带扩展名的文件名
  static String basenameWithoutExtension(String path) {
    return p.basenameWithoutExtension(path);
  }

  /// 判断路径是否为绝对路径
  static bool isAbsolute(String path) {
    return p.isAbsolute(path);
  }

  /// 判断路径是否为相对路径
  static bool isRelative(String path) {
    return !isAbsolute(path);
  }

  /// 连接路径片段
  static String join(List<String> parts) {
    return p.joinAll(parts);
  }

  /// 分割路径为片段
  static List<String> split(String path) {
    return p.split(path);
  }

  /// 检查路径是否存在
  static Future<bool> exists(String path) async {
    final entity = io.File(path);
    return await entity.exists();
  }

  /// 同步检查路径是否存在
  static bool existsSync(String path) {
    final entity = io.File(path);
    return entity.existsSync();
  }

  /// 检查路径是否为文件
  static Future<bool> isFile(String path) async {
    return await io.FileSystemEntity.isFile(path);
  }

  /// 同步检查路径是否为文件
  static bool isFileSync(String path) {
    return io.FileSystemEntity.isFileSync(path);
  }

  /// 检查路径是否为目录
  static Future<bool> isDirectory(String path) async {
    return await io.FileSystemEntity.isDirectory(path);
  }

  /// 同步检查路径是否为目录
  static bool isDirectorySync(String path) {
    return io.FileSystemEntity.isDirectorySync(path);
  }

  /// 检查路径是否为链接
  static Future<bool> isLink(String path) async {
    return await io.FileSystemEntity.isLink(path);
  }

  /// 同步检查路径是否为链接
  static bool isLinkSync(String path) {
    return io.FileSystemEntity.isLinkSync(path);
  }

  /// 获取路径类型
  static Future<io.FileSystemEntityType> type(String path) async {
    return await io.FileSystemEntity.type(path);
  }

  /// 同步获取路径类型
  static io.FileSystemEntityType typeSync(String path) {
    return io.FileSystemEntity.typeSync(path);
  }

  /// 获取临时目录路径
  static String get tempDir => io.Directory.systemTemp.path;

  /// 获取当前工作目录
  static String get currentDir => io.Directory.current.path;

  /// 检查路径是否包含非法字符
  static bool hasIllegalChars(String path) {
    // Windows 文件系统非法字符
    final windowsIllegalChars = RegExp(r'[<>:"/\\|?*]');
    // Unix 文件系统非法字符
    final unixIllegalChars = RegExp(r'/\0/');

    return windowsIllegalChars.hasMatch(path) ||
        unixIllegalChars.hasMatch(path);
  }

  /// 获取合法的文件名
  ///
  /// 移除文件名中的非法字符
  static String sanitizeFilename(String filename) {
    // 替换 Windows 和 Unix 的非法字符
    return filename.replaceAll(RegExp(r'[<>:"/\\|?*\0]'), '_');
  }

  /// 检查路径是否为隐藏文件
  static bool isHidden(String path) {
    final basename = p.basename(path);
    // Unix 风格的隐藏文件以 . 开头
    if (basename.startsWith('.')) return true;
    // Windows 隐藏文件属性需要通过系统 API 检查
    if (io.Platform.isWindows) {
      try {
        final file = io.File(path);
        // 此处可以添加 Windows 特定的隐藏文件检查逻辑
        return file.existsSync() && basename.startsWith('.');
      } catch (_) {
        return false;
      }
    }
    return false;
  }

  /// 获取文件大小的可读字符串表示
  static String getReadableSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();

    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }

    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  /// 检查路径是否可访问
  static Future<bool> isAccessible(String path) async {
    try {
      if (await isFile(path)) {
        final file = io.File(path);
        // 尝试打开文件来检查是否可访问
        var raf = await file.open(mode: io.FileMode.read);
        await raf.close();
        return true;
      } else if (await isDirectory(path)) {
        final dir = io.Directory(path);
        // 尝试列出目录内容来检查是否可访问
        await dir.list().first;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  /// 同步检查路径是否可访问
  static bool isAccessibleSync(String path) {
    try {
      if (isFileSync(path)) {
        final file = io.File(path);
        // 尝试打开文件来检查是否可访问
        var raf = file.openSync(mode: io.FileMode.read);
        raf.closeSync();
        return true;
      } else if (isDirectorySync(path)) {
        final dir = io.Directory(path);
        // 尝试列出目录内容来检查是否可访问
        dir.listSync().isNotEmpty;
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
