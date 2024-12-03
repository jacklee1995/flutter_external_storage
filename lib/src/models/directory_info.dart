/// 目录信息模型
class DirectoryInfo {
  /// 目录名
  final String name;

  /// 目录完整路径
  final String path;

  /// 父目录路径
  final String? parent;

  /// 最后修改时间
  final DateTime lastModified;

  /// 是否可读
  final bool canRead;

  /// 是否可写
  final bool canWrite;

  /// 是否可执行
  final bool canExecute;

  /// 是否隐藏
  final bool isHidden;

  /// 总空间(字节)
  final int totalSpace;

  /// 可用空间(字节)
  final int freeSpace;

  /// 可用空间(字节)
  final int usableSpace;

  /// 文件数量
  final int fileCount;

  /// 子目录数量
  final int directoryCount;

  DirectoryInfo({
    required this.name,
    required this.path,
    this.parent,
    required this.lastModified,
    required this.canRead,
    required this.canWrite,
    required this.canExecute,
    required this.isHidden,
    required this.totalSpace,
    required this.freeSpace,
    required this.usableSpace,
    required this.fileCount,
    required this.directoryCount,
  });

  /// 从Map创建实例
  factory DirectoryInfo.fromMap(Map<String, dynamic> map) {
    return DirectoryInfo(
      name: map['name'] as String,
      path: map['path'] as String,
      parent: map['parent'] as String?,
      lastModified: DateTime.parse(map['lastModified'] as String),
      canRead: map['canRead'] as bool,
      canWrite: map['canWrite'] as bool,
      canExecute: map['canExecute'] as bool,
      isHidden: map['isHidden'] as bool,
      totalSpace: map['totalSpace'] as int,
      freeSpace: map['freeSpace'] as int,
      usableSpace: map['usableSpace'] as int,
      fileCount: map['fileCount'] as int,
      directoryCount: map['directoryCount'] as int,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'path': path,
      'parent': parent,
      'lastModified': lastModified.toIso8601String(),
      'canRead': canRead,
      'canWrite': canWrite,
      'canExecute': canExecute,
      'isHidden': isHidden,
      'totalSpace': totalSpace,
      'freeSpace': freeSpace,
      'usableSpace': usableSpace,
      'fileCount': fileCount,
      'directoryCount': directoryCount,
    };
  }

  @override
  String toString() {
    return 'DirectoryInfo{name: $name, path: $path, parent: $parent, '
        'lastModified: $lastModified, canRead: $canRead, canWrite: $canWrite, '
        'canExecute: $canExecute, isHidden: $isHidden, totalSpace: $totalSpace, '
        'freeSpace: $freeSpace, usableSpace: $usableSpace, fileCount: $fileCount, '
        'directoryCount: $directoryCount}';
  }
}
