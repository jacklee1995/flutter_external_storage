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

  /// 检查路径是否存在（文件、目录或有效的链接）
  static Future<bool> exists(String path) async {
    return await io.FileSystemEntity.type(path) !=
        io.FileSystemEntityType.notFound;
  }

  /// 同步检查路径是否存在（文件、目录或有效的链接）
  static bool existsSync(String path) {
    return io.FileSystemEntity.typeSync(path) !=
        io.FileSystemEntityType.notFound;
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

  // FAT32 / exFAT（SD 卡、U 盘常用）和 Windows 不允许出现在文件名中的字符。
  static final _illegalNameChars = RegExp(r'[<>:"/\\|?*\x00-\x1F]');

  /// 检查路径的各级名称是否包含非法字符
  ///
  /// 路径分隔符和 Windows 盘符（如 `C:`）不算非法字符；名称中的 `<>:"\|?*`
  /// 和控制字符在 FAT32 / exFAT 存储卷上无法使用。
  static bool hasIllegalChars(String path) {
    final root = p.rootPrefix(path);
    final rest = path.substring(root.length);
    if (rest.isEmpty) return false;
    return p.split(rest).any(_illegalNameChars.hasMatch);
  }

  /// 获取合法的文件名
  ///
  /// 把文件名中的非法字符（含路径分隔符和控制字符）替换为 `_`
  static String sanitizeFilename(String filename) {
    return filename.replaceAll(_illegalNameChars, '_');
  }

  /// 检查路径是否为隐藏文件（名称以 `.` 开头，`.` 和 `..` 除外）
  static bool isHidden(String path) {
    final basename = p.basename(path);
    return basename.startsWith('.') && basename != '.' && basename != '..';
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
        // 尝试列出目录内容来检查是否可访问（空目录也算可访问）
        await dir.list().take(1).toList();
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
        // 尝试列出目录内容来检查是否可访问
        io.Directory(path).listSync();
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
