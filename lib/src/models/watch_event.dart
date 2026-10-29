import '../enums/watch_event_type.dart';

/// 文件系统监视事件
class WatchEvent {
  /// 事件类型
  final WatchEventType type;

  /// 发生变化的文件或目录的完整路径
  final String path;

  /// 所属监视的根路径（传给 `watch` / `startWatching` 的路径，已规范化）
  final String? watchedPath;

  /// 发生变化的是否为目录
  final bool isDirectory;

  /// 创建一个监视事件
  const WatchEvent({
    required this.type,
    required this.path,
    this.watchedPath,
    this.isDirectory = false,
  });

  /// 从Map创建WatchEvent实例
  factory WatchEvent.fromMap(Map<String, dynamic> map) {
    return WatchEvent(
      type: WatchEventType.fromValue(map['eventType'] as int),
      path: map['path'] as String,
      watchedPath: map['watchedPath'] as String?,
      isDirectory: map['isDirectory'] as bool? ?? false,
    );
  }

  /// 将WatchEvent转换为Map
  Map<String, dynamic> toMap() {
    return {
      'eventType': type.value,
      'path': path,
      'eventName': type.name,
      'watchedPath': watchedPath,
      'isDirectory': isDirectory,
    };
  }

  @override
  String toString() =>
      'WatchEvent(type: ${type.name}, path: $path, isDirectory: $isDirectory)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WatchEvent &&
        other.type == type &&
        other.path == path &&
        other.watchedPath == watchedPath &&
        other.isDirectory == isDirectory;
  }

  @override
  int get hashCode => Object.hash(type, path, watchedPath, isDirectory);

  /// 创建一个新的WatchEvent实例，但更改某些属性
  WatchEvent copyWith({
    WatchEventType? type,
    String? path,
    String? watchedPath,
    bool? isDirectory,
  }) {
    return WatchEvent(
      type: type ?? this.type,
      path: path ?? this.path,
      watchedPath: watchedPath ?? this.watchedPath,
      isDirectory: isDirectory ?? this.isDirectory,
    );
  }
}
