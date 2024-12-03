import '../enums/watch_event_type.dart';

/// 文件系统监视事件
class WatchEvent {
  /// 事件类型
  final WatchEventType type;

  /// 发生事件的文件或目录路径
  final String path;

  /// 创建一个监视事件
  const WatchEvent({
    required this.type,
    required this.path,
  });

  /// 从Map创建WatchEvent实例
  factory WatchEvent.fromMap(Map<String, dynamic> map) {
    return WatchEvent(
      type: WatchEventType.fromValue(map['eventType'] as int),
      path: map['path'] as String,
    );
  }

  /// 将WatchEvent转换为Map
  Map<String, dynamic> toMap() {
    return {
      'eventType': type.value,
      'path': path,
      'eventName': type.name,
    };
  }

  @override
  String toString() => 'WatchEvent(type: ${type.name}, path: $path)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WatchEvent && other.type == type && other.path == path;
  }

  @override
  int get hashCode => type.hashCode ^ path.hashCode;

  /// 创建一个新的WatchEvent实例，但更改某些属性
  WatchEvent copyWith({
    WatchEventType? type,
    String? path,
  }) {
    return WatchEvent(
      type: type ?? this.type,
      path: path ?? this.path,
    );
  }
}
