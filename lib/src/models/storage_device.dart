/// 存储设备信息模型
class StorageDevice {
  /// 存储设备路径
  final String path;

  /// 存储设备名称
  final String name;

  /// 是否可移除
  final bool isRemovable;

  /// 总容量(字节)
  final int totalSize;

  /// 可用容量(字节)
  final int availableSize;

  /// 是否只读
  final bool isReadOnly;

  StorageDevice({
    required this.path,
    required this.name,
    required this.isRemovable,
    required this.totalSize,
    required this.availableSize,
    required this.isReadOnly,
  });

  /// 从Map创建实例
  factory StorageDevice.fromMap(Map<String, dynamic> map) {
    return StorageDevice(
      path: map['path'] as String,
      name: map['name'] as String,
      isRemovable: map['isRemovable'] as bool,
      totalSize: map['totalSize'] as int,
      availableSize: map['availableSize'] as int,
      isReadOnly: map['isReadOnly'] as bool,
    );
  }

  /// 转换为Map
  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'isRemovable': isRemovable,
      'totalSize': totalSize,
      'availableSize': availableSize,
      'isReadOnly': isReadOnly,
    };
  }

  /// 已使用容量(字节)
  int get usedSize => totalSize - availableSize;

  /// 使用率(百分比)
  double get usagePercentage => (usedSize / totalSize) * 100;

  @override
  String toString() {
    return 'StorageDevice{path: $path, name: $name, isRemovable: $isRemovable, '
        'totalSize: $totalSize, availableSize: $availableSize, isReadOnly: $isReadOnly}';
  }
}
