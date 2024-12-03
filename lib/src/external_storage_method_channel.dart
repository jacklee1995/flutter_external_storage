import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'external_storage_platform_interface.dart';
import 'models/storage_device.dart';
import 'models/file_info.dart';
import 'models/directory_info.dart';
import 'enums/watch_event_type.dart';

/// 通过方法通道实现的外部存储平台接口
class MethodChannelExternalStorage extends ExternalStoragePlatform {
  /// 与原生平台交互的方法通道
  @visibleForTesting
  final methodChannel = const MethodChannel('tech.thispage.external_storage');

  // 事件回调
  void Function(String path, WatchEventType event)? _watchEventCallback;
  void Function(bool granted)? _permissionResultCallback;

  // 构造函数中设置事件监听
  MethodChannelExternalStorage() {
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  // 处理来自平台的方法调用
  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onFileSystemEvent':
        if (_watchEventCallback != null) {
          final Map<String, dynamic> args = call.arguments;
          _watchEventCallback!(
            args['path'],
            WatchEventType.fromValue(args['eventType']),
          );
        }
        break;
      case 'onPermissionResult':
        if (_permissionResultCallback != null) {
          final bool granted = call.arguments['granted'];
          _permissionResultCallback!(granted);
        }
        break;
    }
  }

  @override
  Future<List<StorageDevice>> getAllStorageDevices() async {
    final List<dynamic> result =
        await methodChannel.invokeMethod('getAllStorageDevices');
    return result
        .cast<Map<dynamic, dynamic>>()
        .map((map) => StorageDevice.fromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  @override
  Future<Uint8List> readFile(String path,
      {int offset = 0, int length = -1}) async {
    final result = await methodChannel.invokeMethod('readFile', {
      'path': path,
      'offset': offset,
      'length': length,
    });
    return result['data'];
  }

  @override
  Future<int> writeFile(String path, Uint8List data,
      {bool append = false}) async {
    final result = await methodChannel.invokeMethod('writeFile', {
      'path': path,
      'data': data,
      'append': append,
    });
    return result['bytesWritten'];
  }

  @override
  Future<bool> copyFile(String sourcePath, String targetPath) async {
    final result = await methodChannel.invokeMethod('copyFile', {
      'sourcePath': sourcePath,
      'targetPath': targetPath,
    });
    return result['success'];
  }

  @override
  Future<bool> moveFile(String sourcePath, String targetPath) async {
    final result = await methodChannel.invokeMethod('moveFile', {
      'sourcePath': sourcePath,
      'targetPath': targetPath,
    });
    return result['success'];
  }

  @override
  Future<bool> deleteFile(String path) async {
    final result = await methodChannel.invokeMethod('deleteFile', {
      'path': path,
    });
    return result['success'];
  }

  @override
  Future<FileInfo> getFileInfo(String path) async {
    final Map<dynamic, dynamic> result = await methodChannel.invokeMethod(
      'getFileInfo',
      {'path': path},
    );
    return FileInfo.fromMap(Map<String, dynamic>.from(result));
  }

  @override
  Future<String> calculateMD5(String path) async {
    final result = await methodChannel.invokeMethod('calculateMD5', {
      'path': path,
    });
    return result['md5'];
  }

  @override
  Future<bool> createFile(String path) async {
    final result = await methodChannel.invokeMethod('createFile', {
      'path': path,
    });
    return result['success'];
  }

  @override
  Future<bool> fileExists(String path) async {
    final result = await methodChannel.invokeMethod('fileExists', {
      'path': path,
    });
    return result['exists'];
  }

  @override
  Future<String?> getMimeType(String path) async {
    final result = await methodChannel.invokeMethod('getMimeType', {
      'path': path,
    });
    return result['mimeType'];
  }

  @override
  Future<bool> truncateFile(String path, int size) async {
    final result = await methodChannel.invokeMethod('truncateFile', {
      'path': path,
      'size': size,
    });
    return result['success'];
  }

  @override
  Future<List<FileInfo>> listDirectory(String path,
      {bool recursive = false}) async {
    try {
      final result = await methodChannel.invokeMethod('listDirectory', {
        'path': path,
        'recursive': recursive,
      });

      if (result == null || result['entries'] == null) {
        print('Warning: Null result from listDirectory for path: $path');
        return [];
      }

      final entries = result['entries'] as List?;
      if (entries == null) {
        print('Warning: Null entries list for path: $path');
        return [];
      }

      return entries
          .map((entry) {
            if (entry == null) {
              print('Warning: Null entry in list for path: $path');
              return null;
            }
            try {
              return FileInfo.fromMap(Map<String, dynamic>.from(entry));
            } catch (e, s) {
              print('Error converting entry to FileInfo: $e\n$s');
              print('Problematic entry: $entry');
              return null;
            }
          })
          .where((element) => element != null)
          .cast<FileInfo>()
          .toList();
    } catch (e, s) {
      print('Error in listDirectory: $e\n$s');
      return [];
    }
  }

  @override
  Future<bool> createDirectory(String path, {bool recursive = false}) async {
    final result = await methodChannel.invokeMethod('createDirectory', {
      'path': path,
      'recursive': recursive,
    });
    return result['success'];
  }

  @override
  Future<bool> deleteDirectory(String path, {bool recursive = false}) async {
    final result = await methodChannel.invokeMethod('deleteDirectory', {
      'path': path,
      'recursive': recursive,
    });
    return result['success'];
  }

  @override
  Future<bool> moveDirectory(String sourcePath, String targetPath) async {
    final result = await methodChannel.invokeMethod('moveDirectory', {
      'sourcePath': sourcePath,
      'targetPath': targetPath,
    });
    return result['success'];
  }

  @override
  Future<bool> copyDirectory(String sourcePath, String targetPath) async {
    final result = await methodChannel.invokeMethod('copyDirectory', {
      'sourcePath': sourcePath,
      'targetPath': targetPath,
    });
    return result['success'];
  }

  @override
  Future<DirectoryInfo> getDirectoryInfo(String path) async {
    final Map<dynamic, dynamic> result = await methodChannel.invokeMethod(
      'getDirectoryInfo',
      {'path': path},
    );
    return DirectoryInfo.fromMap(Map<String, dynamic>.from(result));
  }

  @override
  Future<bool> isDirectoryEmpty(String path) async {
    final result = await methodChannel.invokeMethod('isDirectoryEmpty', {
      'path': path,
    });
    return result['isEmpty'];
  }

  @override
  Future<int> getDirectorySize(String path) async {
    final result = await methodChannel.invokeMethod('getDirectorySize', {
      'path': path,
    });
    return result['size'];
  }

  @override
  Future<bool> directoryExists(String path) async {
    final result = await methodChannel.invokeMethod('directoryExists', {
      'path': path,
    });
    return result['exists'];
  }

  @override
  Future<bool> startWatching(
    String path, {
    bool recursive = false,
    List<WatchEventType> events = const [],
  }) async {
    final result = await methodChannel.invokeMethod('startWatching', {
      'path': path,
      'recursive': recursive,
      'eventMask': events.fold(0, (mask, event) => mask | event.value),
    });
    return result['success'];
  }

  @override
  Future<bool> stopWatching(String path) async {
    final result = await methodChannel.invokeMethod('stopWatching', {
      'path': path,
    });
    return result['success'];
  }

  @override
  Future<bool> stopAllWatching() async {
    final result = await methodChannel.invokeMethod('stopAllWatching');
    return result['success'];
  }

  @override
  Future<List<String>> getWatchedPaths() async {
    final result = await methodChannel.invokeMethod('getWatchedPaths');
    return (result['paths'] as List).cast<String>();
  }

  @override
  Future<bool> isWatching(String path) async {
    final result = await methodChannel.invokeMethod('isWatching', {
      'path': path,
    });
    return result['watching'];
  }

  @override
  Future<bool> checkStoragePermissions() async {
    final result = await methodChannel.invokeMethod('checkStoragePermissions');
    return result['hasPermission'];
  }

  @override
  Future<bool> requestStoragePermissions() async {
    final result =
        await methodChannel.invokeMethod('requestStoragePermissions');
    return result['success'];
  }

  @override
  Future<bool> shouldShowRequestPermissionRationale() async {
    final result = await methodChannel
        .invokeMethod('shouldShowRequestPermissionRationale');
    return result['shouldShow'];
  }

  @override
  Future<bool> openAppSettings() async {
    final result = await methodChannel.invokeMethod('openAppSettings');
    return result['success'];
  }

  @override
  Future<bool> checkPermission(String permission) async {
    final result = await methodChannel.invokeMethod('checkPermission', {
      'permission': permission,
    });
    return result['hasPermission'];
  }

  @override
  Future<List<String>> getGrantedPermissions() async {
    final result = await methodChannel.invokeMethod('getGrantedPermissions');
    return (result['permissions'] as List).cast<String>();
  }

  @override
  void registerWatchEventCallback(
      void Function(String path, WatchEventType event) callback) {
    _watchEventCallback = callback;
  }

  @override
  void unregisterWatchEventCallback() {
    _watchEventCallback = null;
  }

  @override
  void registerPermissionResultCallback(void Function(bool granted) callback) {
    _permissionResultCallback = callback;
  }

  @override
  void unregisterPermissionResultCallback() {
    _permissionResultCallback = null;
  }
}
