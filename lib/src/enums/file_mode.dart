/// 文件访问模式枚举
enum FileMode {
  /// 只读模式
  ///
  /// 文件必须存在,否则会抛出异常
  read,

  /// 写入模式
  ///
  /// 如果文件存在则清空内容,不存在则创建新文件
  write,

  /// 追加模式
  ///
  /// 如果文件存在则在末尾追加内容,不存在则创建新文件
  append,

  /// 读写模式
  ///
  /// 文件必须存在,可以读取和写入
  readWrite,

  /// 读写追加模式
  ///
  /// 如果文件存在则可以读取和在末尾追加,不存在则创建新文件
  readAppend,

  /// 写入更新模式
  ///
  /// 如果文件存在则可以读取和写入,不存在则创建新文件
  writeUpdate,

  /// 追加更新模式
  ///
  /// 如果文件存在则可以读取和在末尾追加,不存在则创建新文件
  appendUpdate;

  /// 获取对应的整数值
  int get value {
    switch (this) {
      case FileMode.read:
        return 0;
      case FileMode.write:
        return 1;
      case FileMode.append:
        return 2;
      case FileMode.readWrite:
        return 3;
      case FileMode.readAppend:
        return 4;
      case FileMode.writeUpdate:
        return 5;
      case FileMode.appendUpdate:
        return 6;
    }
  }

  /// 从整数值获取枚举
  static FileMode fromValue(int value) {
    switch (value) {
      case 0:
        return FileMode.read;
      case 1:
        return FileMode.write;
      case 2:
        return FileMode.append;
      case 3:
        return FileMode.readWrite;
      case 4:
        return FileMode.readAppend;
      case 5:
        return FileMode.writeUpdate;
      case 6:
        return FileMode.appendUpdate;
      default:
        throw ArgumentError('Invalid FileMode value: $value');
    }
  }
}
