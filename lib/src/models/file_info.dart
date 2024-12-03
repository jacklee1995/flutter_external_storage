/// 文件信息模型
class FileInfo {
  /// 文件名
  final String name;

  /// 文件完整路径
  final String path;

  /// 文件大小(字节)
  final int size;

  /// 最后修改时间
  final DateTime lastModified;

  /// 是否为目录
  final bool isDirectory;

  /// 是否为文件
  final bool isFile;

  /// 是否可读
  final bool canRead;

  /// 是否可写
  final bool canWrite;

  /// 是否可执行
  final bool canExecute;

  /// 是否隐藏
  final bool isHidden;

  FileInfo({
    required this.name,
    required this.path,
    required this.size,
    required this.lastModified,
    required this.isDirectory,
    required this.isFile,
    required this.canRead,
    required this.canWrite,
    required this.canExecute,
    required this.isHidden,
  });

  /// 从Map创建实例
  factory FileInfo.fromMap(Map<String, dynamic> map) {
    try {
      return FileInfo(
        name: map['name'] as String? ?? '',
        path: map['path'] as String? ?? '',
        size: map['size'] as int? ?? 0,
        lastModified: DateTime.fromMillisecondsSinceEpoch(
            (map['lastModified'] as int?) ?? 0),
        isDirectory: map['isDirectory'] as bool? ?? false,
        isFile: map['isFile'] as bool? ?? true,
        canRead: map['canRead'] as bool? ?? false,
        canWrite: map['canWrite'] as bool? ?? false,
        canExecute: map['canExecute'] as bool? ?? false,
        isHidden: map['isHidden'] as bool? ?? false,
      );
    } catch (e, s) {
      print('Error creating FileInfo from map: $e\n$s');
      print('Problematic map: $map');
      rethrow;
    }
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'path': path,
      'size': size,
      'lastModified': lastModified.millisecondsSinceEpoch,
      'isDirectory': isDirectory,
      'isFile': isFile,
      'canRead': canRead,
      'canWrite': canWrite,
      'canExecute': canExecute,
      'isHidden': isHidden,
    };
  }

  @override
  String toString() {
    return 'FileInfo{name: $name, path: $path, size: $size, '
        'lastModified: $lastModified, isDirectory: $isDirectory, '
        'isFile: $isFile, canRead: $canRead, canWrite: $canWrite, '
        'canExecute: $canExecute, isHidden: $isHidden}';
  }
}
