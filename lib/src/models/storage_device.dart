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

  /// 是否为主存储（内部存储）
  final bool isPrimary;

  /// 卷 UUID（如 SD 卡 / U 盘的 `1A2B-3C4D`），主存储通常为 null。
  ///
  /// 相当于 Windows 上的「磁盘代号」，同一张卡在不同设备上保持不变。
  final String? uuid;

  /// 系统提供的卷描述（如 "SanDisk SD card"），API 24 以下为 null。
  final String? description;

  StorageDevice({
    required this.path,
    required this.name,
    required this.isRemovable,
    required this.totalSize,
    required this.availableSize,
    required this.isReadOnly,
    this.isPrimary = false,
    this.uuid,
    this.description,
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
      isPrimary: map['isPrimary'] as bool? ?? false,
      uuid: map['uuid'] as String?,
      description: map['description'] as String?,
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
      'isPrimary': isPrimary,
      'uuid': uuid,
      'description': description,
    };
  }

  /// 已使用容量(字节)
  int get usedSize => totalSize - availableSize;

  /// 使用率(百分比)
  double get usagePercentage =>
      totalSize == 0 ? 0 : (usedSize / totalSize) * 100;

  @override
  String toString() {
    return 'StorageDevice{path: $path, name: $name, isRemovable: $isRemovable, '
        'totalSize: $totalSize, availableSize: $availableSize, '
        'isReadOnly: $isReadOnly, isPrimary: $isPrimary, uuid: $uuid, '
        'description: $description}';
  }
}
