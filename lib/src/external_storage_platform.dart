import 'dart:typed_data';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'external_storage_method_channel.dart';
import 'models/storage_device.dart';
import 'models/file_info.dart';
import 'models/directory_info.dart';
import 'enums/watch_event_type.dart';

/// 外部存储插件的平台接口
abstract class ExternalStoragePlatform extends PlatformInterface {
  ExternalStoragePlatform() : super(token: _token);

  static final Object _token = Object();
  static ExternalStoragePlatform _instance =
      MethodChannelExternalStorage() as ExternalStoragePlatform;

  static ExternalStoragePlatform get instance => _instance;

  static set instance(ExternalStoragePlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// 获取所有存储设备信息
  Future<List<StorageDevice>> getAllStorageDevices() {
    throw UnimplementedError(
        'getAllStorageDevices() has not been implemented.');
  }

  /// 文件操作相关方法
  Future<Uint8List> readFile(String path, {int offset = 0, int length = -1}) {
    throw UnimplementedError('readFile() has not been implemented.');
  }

  Future<int> writeFile(String path, Uint8List data, {bool append = false}) {
    throw UnimplementedError('writeFile() has not been implemented.');
  }

  Future<bool> copyFile(String sourcePath, String targetPath) {
    throw UnimplementedError('copyFile() has not been implemented.');
  }

  Future<bool> moveFile(String sourcePath, String targetPath) {
    throw UnimplementedError('moveFile() has not been implemented.');
  }

  Future<bool> deleteFile(String path) {
    throw UnimplementedError('deleteFile() has not been implemented.');
  }

  Future<FileInfo> getFileInfo(String path) {
    throw UnimplementedError('getFileInfo() has not been implemented.');
  }

  Future<String> calculateMD5(String path) {
    throw UnimplementedError('calculateMD5() has not been implemented.');
  }

  Future<bool> createFile(String path) {
    throw UnimplementedError('createFile() has not been implemented.');
  }

  Future<bool> fileExists(String path) {
    throw UnimplementedError('fileExists() has not been implemented.');
  }

  Future<String?> getMimeType(String path) {
    throw UnimplementedError('getMimeType() has not been implemented.');
  }

  Future<bool> truncateFile(String path, int size) {
    throw UnimplementedError('truncateFile() has not been implemented.');
  }

  /// 目录操作相关方法
  Future<List<FileInfo>> listDirectory(String path, {bool recursive = false}) {
    throw UnimplementedError('listDirectory() has not been implemented.');
  }

  Future<bool> createDirectory(String path, {bool recursive = false}) {
    throw UnimplementedError('createDirectory() has not been implemented.');
  }

  Future<bool> deleteDirectory(String path, {bool recursive = false}) {
    throw UnimplementedError('deleteDirectory() has not been implemented.');
  }

  Future<bool> moveDirectory(String sourcePath, String targetPath) {
    throw UnimplementedError('moveDirectory() has not been implemented.');
  }

  Future<bool> copyDirectory(String sourcePath, String targetPath) {
    throw UnimplementedError('copyDirectory() has not been implemented.');
  }

  Future<DirectoryInfo> getDirectoryInfo(String path) {
    throw UnimplementedError('getDirectoryInfo() has not been implemented.');
  }

  Future<bool> isDirectoryEmpty(String path) {
    throw UnimplementedError('isDirectoryEmpty() has not been implemented.');
  }

  Future<int> getDirectorySize(String path) {
    throw UnimplementedError('getDirectorySize() has not been implemented.');
  }

  Future<bool> directoryExists(String path) {
    throw UnimplementedError('directoryExists() has not been implemented.');
  }

  /// 文件系统监视相关方法
  Future<bool> startWatching(
    String path, {
    bool recursive = false,
    List<WatchEventType> events = const [],
  }) {
    throw UnimplementedError('startWatching() has not been implemented.');
  }

  Future<bool> stopWatching(String path) {
    throw UnimplementedError('stopWatching() has not been implemented.');
  }

  Future<bool> stopAllWatching() {
    throw UnimplementedError('stopAllWatching() has not been implemented.');
  }

  Future<List<String>> getWatchedPaths() {
    throw UnimplementedError('getWatchedPaths() has not been implemented.');
  }

  Future<bool> isWatching(String path) {
    throw UnimplementedError('isWatching() has not been implemented.');
  }

  /// 权限相关方法
  Future<bool> checkStoragePermissions() {
    throw UnimplementedError(
        'checkStoragePermissions() has not been implemented.');
  }

  Future<bool> requestStoragePermissions() {
    throw UnimplementedError(
        'requestStoragePermissions() has not been implemented.');
  }

  Future<bool> shouldShowRequestPermissionRationale() {
    throw UnimplementedError(
        'shouldShowRequestPermissionRationale() has not been implemented.');
  }

  Future<bool> openAppSettings() {
    throw UnimplementedError('openAppSettings() has not been implemented.');
  }

  Future<bool> checkPermission(String permission) {
    throw UnimplementedError('checkPermission() has not been implemented.');
  }

  Future<List<String>> getGrantedPermissions() {
    throw UnimplementedError(
        'getGrantedPermissions() has not been implemented.');
  }

  /// 监听器注册方法
  void registerWatchEventCallback(
      void Function(String path, WatchEventType event) callback) {
    throw UnimplementedError(
        'registerWatchEventCallback() has not been implemented.');
  }

  void unregisterWatchEventCallback() {
    throw UnimplementedError(
        'unregisterWatchEventCallback() has not been implemented.');
  }

  void registerPermissionResultCallback(void Function(bool granted) callback) {
    throw UnimplementedError(
        'registerPermissionResultCallback() has not been implemented.');
  }

  void unregisterPermissionResultCallback() {
    throw UnimplementedError(
        'unregisterPermissionResultCallback() has not been implemented.');
  }
}
