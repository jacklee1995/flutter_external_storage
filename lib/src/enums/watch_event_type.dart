enum WatchEventType {
  /// 文件被访问
  access,

  /// 文件被修改
  modify,

  /// 文件属性被修改
  attrib,

  /// 文件被关闭(写入)
  closeWrite,

  /// 文件被关闭(未写入)
  closeNoWrite,

  /// 文件被打开
  open,

  /// 文件被移动(源)
  movedFrom,

  /// 文件被移动(目标)
  movedTo,

  /// 文件被创建
  create,

  /// 文件被删除
  delete,

  /// 自身被删除
  deleteSelf,

  /// 自身被移动
  moveSelf;

  /// 获取对应的整数值
  int get value {
    switch (this) {
      case WatchEventType.access:
        return 1;
      case WatchEventType.modify:
        return 2;
      case WatchEventType.attrib:
        return 4;
      case WatchEventType.closeWrite:
        return 8;
      case WatchEventType.closeNoWrite:
        return 16;
      case WatchEventType.open:
        return 32;
      case WatchEventType.movedFrom:
        return 64;
      case WatchEventType.movedTo:
        return 128;
      case WatchEventType.create:
        return 256;
      case WatchEventType.delete:
        return 512;
      case WatchEventType.deleteSelf:
        return 1024;
      case WatchEventType.moveSelf:
        return 2048;
    }
  }

  /// 从整数值获取枚举
  static WatchEventType fromValue(int value) {
    switch (value) {
      case 1:
        return WatchEventType.access;
      case 2:
        return WatchEventType.modify;
      case 4:
        return WatchEventType.attrib;
      case 8:
        return WatchEventType.closeWrite;
      case 16:
        return WatchEventType.closeNoWrite;
      case 32:
        return WatchEventType.open;
      case 64:
        return WatchEventType.movedFrom;
      case 128:
        return WatchEventType.movedTo;
      case 256:
        return WatchEventType.create;
      case 512:
        return WatchEventType.delete;
      case 1024:
        return WatchEventType.deleteSelf;
      case 2048:
        return WatchEventType.moveSelf;
      default:
        throw ArgumentError('Invalid WatchEventType value: $value');
    }
  }

  /// 获取事件类型名称
  String get name {
    switch (this) {
      case WatchEventType.access:
        return 'ACCESS';
      case WatchEventType.modify:
        return 'MODIFY';
      case WatchEventType.attrib:
        return 'ATTRIB';
      case WatchEventType.closeWrite:
        return 'CLOSE_WRITE';
      case WatchEventType.closeNoWrite:
        return 'CLOSE_NOWRITE';
      case WatchEventType.open:
        return 'OPEN';
      case WatchEventType.movedFrom:
        return 'MOVED_FROM';
      case WatchEventType.movedTo:
        return 'MOVED_TO';
      case WatchEventType.create:
        return 'CREATE';
      case WatchEventType.delete:
        return 'DELETE';
      case WatchEventType.deleteSelf:
        return 'DELETE_SELF';
      case WatchEventType.moveSelf:
        return 'MOVE_SELF';
    }
  }
}
