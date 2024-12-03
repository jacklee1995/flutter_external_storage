import 'dart:typed_data';
import 'external_storage_platform_interface.dart';
import 'models/storage_device.dart';
import 'models/file_info.dart';
import 'models/directory_info.dart';
import 'enums/watch_event_type.dart';

/// 外部存储插件的主类
class ExternalStorage {
  /// 获取平台接口实例
  static ExternalStoragePlatform get _platform =>
      ExternalStoragePlatform.instance;

  /// 获取所有存储设备信息
  Future<List<StorageDevice>> getAllStorageDevices() {
    return _platform.getAllStorageDevices();
  }

  /// 读取文件内容
  Future<Uint8List> readFile(String path, {int offset = 0, int length = -1}) {
    return _platform.readFile(path, offset: offset, length: length);
  }

  /// 写入文件内容
  Future<int> writeFile(String path, Uint8List data, {bool append = false}) {
    return _platform.writeFile(path, data, append: append);
  }

  /// 复制文件
  Future<bool> copyFile(String sourcePath, String targetPath) {
    return _platform.copyFile(sourcePath, targetPath);
  }

  /// 移动文件
  Future<bool> moveFile(String sourcePath, String targetPath) {
    return _platform.moveFile(sourcePath, targetPath);
  }

  /// 删除文件
  Future<bool> deleteFile(String path) {
    return _platform.deleteFile(path);
  }

  /// 获取文件信息
  Future<FileInfo> getFileInfo(String path) {
    return _platform.getFileInfo(path);
  }

  /// 计算文件MD5
  Future<String> calculateMD5(String path) {
    return _platform.calculateMD5(path);
  }

  /// 创建文件
  Future<bool> createFile(String path) {
    return _platform.createFile(path);
  }

  /// 检查文件是否存在
  Future<bool> fileExists(String path) {
    return _platform.fileExists(path);
  }

  /// 获取文件MIME类型
  Future<String?> getMimeType(String path) {
    return _platform.getMimeType(path);
  }

  /// 截断文件
  Future<bool> truncateFile(String path, int size) {
    return _platform.truncateFile(path, size);
  }

  /// 列出目录内容
  Future<List<FileInfo>> listDirectory(String path, {bool recursive = false}) {
    return _platform.listDirectory(path, recursive: recursive);
  }

  /// 创建目录
  Future<bool> createDirectory(String path, {bool recursive = false}) {
    return _platform.createDirectory(path, recursive: recursive);
  }

  /// 删除目录
  Future<bool> deleteDirectory(String path, {bool recursive = false}) {
    return _platform.deleteDirectory(path, recursive: recursive);
  }

  /// 移动目录
  Future<bool> moveDirectory(String sourcePath, String targetPath) {
    return _platform.moveDirectory(sourcePath, targetPath);
  }

  /// 复制目录
  Future<bool> copyDirectory(String sourcePath, String targetPath) {
    return _platform.copyDirectory(sourcePath, targetPath);
  }

  /// 获取目录信息
  Future<DirectoryInfo> getDirectoryInfo(String path) {
    return _platform.getDirectoryInfo(path);
  }

  /// 检查目录是否为空
  Future<bool> isDirectoryEmpty(String path) {
    return _platform.isDirectoryEmpty(path);
  }

  /// 获取目录大小
  Future<int> getDirectorySize(String path) {
    return _platform.getDirectorySize(path);
  }

  /// 检查目录是否存在
  Future<bool> directoryExists(String path) {
    return _platform.directoryExists(path);
  }

  /// 开始监视目录
  Future<bool> startWatching(
    String path, {
    bool recursive = false,
    List<WatchEventType> events = const [],
  }) {
    return _platform.startWatching(path, recursive: recursive, events: events);
  }

  /// 停止监视目录
  Future<bool> stopWatching(String path) {
    return _platform.stopWatching(path);
  }

  /// 停止所有监视
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
  Future<bool> checkStoragePermissions() {
    return _platform.checkStoragePermissions();
  }

  /// 请求存储权限
  Future<bool> requestStoragePermissions() {
    return _platform.requestStoragePermissions();
  }

  /// 检查是否需要显示权限说明
  Future<bool> shouldShowRequestPermissionRationale() {
    return _platform.shouldShowRequestPermissionRationale();
  }

  /// 打开应用设置页面
  Future<bool> openAppSettings() {
    return _platform.openAppSettings();
  }

  /// 检查特定权限
  Future<bool> checkPermission(String permission) {
    return _platform.checkPermission(permission);
  }

  /// 获取已授予的权限列表
  Future<List<String>> getGrantedPermissions() {
    return _platform.getGrantedPermissions();
  }

  /// 注册文件系统事件回调
  void registerWatchEventCallback(
      void Function(String path, WatchEventType event) callback) {
    _platform.registerWatchEventCallback(callback);
  }

  /// 注销文件系统事件回调
  void unregisterWatchEventCallback() {
    _platform.unregisterWatchEventCallback();
  }

  /// 注册权限结果回调
  void registerPermissionResultCallback(void Function(bool granted) callback) {
    _platform.registerPermissionResultCallback(callback);
  }

  /// 注销权限结果回调
  void unregisterPermissionResultCallback() {
    _platform.unregisterPermissionResultCallback();
  }
}
