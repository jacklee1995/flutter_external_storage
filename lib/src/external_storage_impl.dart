import 'dart:typed_data';
import 'external_storage_platform_interface.dart';
import 'models/storage_device.dart';
import 'models/file_info.dart';
import 'models/directory_info.dart';
import 'models/watch_event.dart';
import 'enums/watch_event_type.dart';

/// 外部存储插件的主类
///
/// 错误约定：返回数据的方法失败时抛出 code 为 `OPERATION_FAILED` 的
/// `PlatformException`；返回 `bool` 的方法失败时返回 `false`。
class ExternalStorage {
  /// 获取平台接口实例
  static ExternalStoragePlatform get _platform =>
      ExternalStoragePlatform.instance;

  /// 获取所有已挂载的存储设备
  ///
  /// Android：内部存储、SD 卡、USB OTG（可移除卷带 [StorageDevice.uuid]）。
  /// iOS：App 沙盒所在的数据卷，[StorageDevice.path] 为 Documents 目录。
  Future<List<StorageDevice>> getAllStorageDevices() {
    return _platform.getAllStorageDevices();
  }

  /// 读取文件内容，[length] 为负数时读到文件末尾
  Future<Uint8List> readFile(String path, {int offset = 0, int length = -1}) {
    return _platform.readFile(path, offset: offset, length: length);
  }

  /// 写入文件内容（自动创建父目录），返回写入的字节数
  Future<int> writeFile(String path, Uint8List data, {bool append = false}) {
    return _platform.writeFile(path, data, append: append);
  }

  /// 复制文件（目标已存在时覆盖）
  Future<bool> copyFile(String sourcePath, String targetPath) {
    return _platform.copyFile(sourcePath, targetPath);
  }

  /// 移动文件；跨存储卷时自动改为复制后删除
  Future<bool> moveFile(String sourcePath, String targetPath) {
    return _platform.moveFile(sourcePath, targetPath);
  }

  /// 删除文件
  Future<bool> deleteFile(String path) {
    return _platform.deleteFile(path);
  }

  /// 获取文件或目录的信息
  Future<FileInfo> getFileInfo(String path) {
    return _platform.getFileInfo(path);
  }

  /// 计算文件MD5（在后台 isolate 中进行）
  Future<String> calculateMD5(String path) {
    return _platform.calculateMD5(path);
  }

  /// 创建空文件（自动创建父目录）；路径已存在时返回 false
  Future<bool> createFile(String path) {
    return _platform.createFile(path);
  }

  /// 检查路径是否存在（文件或目录均返回 true）
  Future<bool> fileExists(String path) {
    return _platform.fileExists(path);
  }

  /// 获取文件MIME类型，先按文件头识别再按扩展名，无法识别时返回 null
  Future<String?> getMimeType(String path) {
    return _platform.getMimeType(path);
  }

  /// 把文件截断（或扩展）到 [size] 字节
  Future<bool> truncateFile(String path, int size) {
    return _platform.truncateFile(path, size);
  }

  /// 列出目录内容；路径不是可读目录时返回空列表
  ///
  /// [recursive] 为 true 时包含所有子目录的内容，无权限的子目录会被跳过。
  Future<List<FileInfo>> listDirectory(String path, {bool recursive = false}) {
    return _platform.listDirectory(path, recursive: recursive);
  }

  /// 创建目录；路径已存在时返回 false，[recursive] 为 true 时同时创建父目录
  Future<bool> createDirectory(String path, {bool recursive = false}) {
    return _platform.createDirectory(path, recursive: recursive);
  }

  /// 删除目录；非空目录需要 [recursive] 为 true
  Future<bool> deleteDirectory(String path, {bool recursive = false}) {
    return _platform.deleteDirectory(path, recursive: recursive);
  }

  /// 移动目录（目标必须不存在）；跨存储卷时自动改为复制后删除
  Future<bool> moveDirectory(String sourcePath, String targetPath) {
    return _platform.moveDirectory(sourcePath, targetPath);
  }

  /// 递归复制目录（目标必须不存在）
  Future<bool> copyDirectory(String sourcePath, String targetPath) {
    return _platform.copyDirectory(sourcePath, targetPath);
  }

  /// 获取目录信息（含所在存储卷的容量）
  Future<DirectoryInfo> getDirectoryInfo(String path) {
    return _platform.getDirectoryInfo(path);
  }

  /// 检查目录是否为空
  Future<bool> isDirectoryEmpty(String path) {
    return _platform.isDirectoryEmpty(path);
  }

  /// 获取目录下所有文件的大小之和（字节）
  Future<int> getDirectorySize(String path) {
    return _platform.getDirectorySize(path);
  }

  /// 检查目录是否存在
  Future<bool> directoryExists(String path) {
    return _platform.directoryExists(path);
  }

  /// 监视文件或目录的变化（推荐）
  ///
  /// 开始监听时启动监视，取消订阅时自动停止；可以同时监视多个路径，互不影响。
  /// [events] 为空表示所有事件。路径不存在时流会收到一个 `PlatformException` 错误。
  /// 根路径被删除或移走后流结束。
  ///
  /// - Android：基于 inotify，支持 [WatchEventType] 的全部事件。
  /// - iOS：轮询实现（默认每秒一次），只产生 create、modify、delete、deleteSelf，
  ///   重命名表现为 delete + create。
  Stream<WatchEvent> watch(
    String path, {
    bool recursive = false,
    List<WatchEventType> events = const [],
  }) {
    return _platform.watch(path, recursive: recursive, events: events);
  }

  /// 开始监视目录，事件通过 [registerWatchEventCallback] 注册的回调接收
  ///
  /// 同一路径重复调用会替换之前的监视。新代码建议使用 [watch]。
  Future<bool> startWatching(
    String path, {
    bool recursive = false,
    List<WatchEventType> events = const [],
  }) {
    return _platform.startWatching(path, recursive: recursive, events: events);
  }

  /// 停止 [startWatching] 开始的监视
  Future<bool> stopWatching(String path) {
    return _platform.stopWatching(path);
  }

  /// 停止所有监视（包括 [watch] 返回的流，它们会结束）
  Future<bool> stopAllWatching() {
    return _platform.stopAllWatching();
  }

  /// 获取所有被监视的路径
  Future<List<String>> getWatchedPaths() {
    return _platform.getWatchedPaths();
  }

  /// 检查路径是否被监视
  Future<bool> isWatching(String path) {
    return _platform.isWatching(path);
  }

  /// 检查存储权限
  ///
  /// Android 11+ 检查「所有文件访问权限」(MANAGE_EXTERNAL_STORAGE)，
  /// Android 6-10 检查 READ/WRITE_EXTERNAL_STORAGE。
  /// iOS 没有存储权限（App 只能访问自己的沙盒），始终返回 true。
  Future<bool> checkStoragePermissions() {
    return _platform.checkStoragePermissions();
  }

  /// 请求存储权限，返回用户最终是否授权
  ///
  /// Android 11+ 会跳转系统设置页，用户返回 App 后才完成。
  /// 宿主 App 必须在 AndroidManifest.xml 中声明 MANAGE_EXTERNAL_STORAGE，
  /// 否则抛出 code 为 `PERMISSION_NOT_DECLARED` 的 PlatformException。
  /// iOS 上直接返回 true。
  Future<bool> requestStoragePermissions() {
    return _platform.requestStoragePermissions();
  }

  /// 检查是否需要显示权限说明（仅 Android 6-10 可能为 true）
  Future<bool> shouldShowRequestPermissionRationale() {
    return _platform.shouldShowRequestPermissionRationale();
  }

  /// 打开本应用的系统设置页面
  Future<bool> openAppSettings() {
    return _platform.openAppSettings();
  }

  /// 检查特定的 Android 权限（iOS 上返回 false）
  Future<bool> checkPermission(String permission) {
    return _platform.checkPermission(permission);
  }

  /// 获取已授予的 Android 权限列表（iOS 上为空）
  Future<List<String>> getGrantedPermissions() {
    return _platform.getGrantedPermissions();
  }

  /// 注册 [startWatching] 的事件回调（只保留最后注册的一个）
  void registerWatchEventCallback(
      void Function(String path, WatchEventType event) callback) {
    _platform.registerWatchEventCallback(callback);
  }

  /// 注销文件系统事件回调
  void unregisterWatchEventCallback() {
    _platform.unregisterWatchEventCallback();
  }

  /// 注册权限结果回调，每次 [requestStoragePermissions] 完成后调用
  void registerPermissionResultCallback(void Function(bool granted) callback) {
    _platform.registerPermissionResultCallback(callback);
  }

  /// 注销权限结果回调
  void unregisterPermissionResultCallback() {
    _platform.unregisterPermissionResultCallback();
  }
}
