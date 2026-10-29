import 'dart:async';
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'enums/watch_event_type.dart';
import 'external_storage_platform_interface.dart';
import 'io/directory_operations.dart' as dirs;
import 'io/entries.dart';
import 'io/errors.dart';
import 'io/file_operations.dart' as files;
import 'io/polling_watcher.dart';
import 'models/directory_info.dart';
import 'models/file_info.dart';
import 'models/storage_device.dart';
import 'models/watch_event.dart';

/// 默认的平台实现。
///
/// - 文件和目录操作直接使用 `dart:io`（Android、iOS 共用一套实现，不经过平台通道）。
/// - 存储卷信息、存储权限、Android 的 inotify 文件监视通过方法通道调用原生代码。
/// - 没有原生监视的平台（iOS 等）用轮询实现文件监视，间隔为 [pollingInterval]。
///
/// 返回数据的方法失败时抛出 code 为 `OPERATION_FAILED` 的 [PlatformException]；
/// 返回 `bool` 的方法失败时返回 `false`。
class MethodChannelExternalStorage extends ExternalStoragePlatform {
  /// [isAndroid] 决定是否使用 Android 原生的权限与监视实现，默认取当前平台，主要用于测试。
  MethodChannelExternalStorage({
    bool? isAndroid,
    this.pollingInterval = const Duration(seconds: 1),
  }) : _isAndroid = isAndroid ?? io.Platform.isAndroid;

  /// 与原生平台交互的方法通道
  @visibleForTesting
  final methodChannel = const MethodChannel('tech.thispage.external_storage');

  /// 没有原生文件监视的平台上，轮询目录变化的间隔。
  final Duration pollingInterval;

  static const String _streamIdPrefix = 'stream:';

  final bool _isAndroid;
  bool _handlerInstalled = false;
  int _nextStreamId = 0;
  final Map<String, StreamController<WatchEvent>> _streams = {};
  final Map<String, PollingWatcher> _pollers = {};

  void Function(String path, WatchEventType event)? _watchEventCallback;
  void Function(bool granted)? _permissionResultCallback;

  // 延迟到真正需要原生回调时才注册，这样在 binding 初始化前也能调用文件操作。
  void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    methodChannel.setMethodCallHandler(_handleMethodCall);
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    final arguments = call.arguments;
    if (arguments is! Map) return;
    final args = Map<String, dynamic>.from(arguments);
    switch (call.method) {
      case 'onFileSystemEvent':
        final event = WatchEvent.fromMap(args);
        _dispatch(args['watchId'] as String? ?? event.watchedPath ?? '', event);
      case 'onWatchDone':
        _finishWatch(args['watchId'] as String);
    }
  }

  /// 调用原生方法并返回结果 Map；`success == false` 时抛出 [PlatformException]。
  Future<Map<dynamic, dynamic>> _invokeChecked(String method,
      [Map<String, dynamic>? arguments]) async {
    final result =
        await methodChannel.invokeMapMethod<dynamic, dynamic>(method, arguments);
    if (result == null) {
      throw PlatformException(
        code: operationFailedCode,
        message: '$method returned no result',
      );
    }
    if (result['success'] == false) {
      throw PlatformException(
        code: operationFailedCode,
        message: '$method: ${result['error'] ?? 'unknown error'}',
      );
    }
    return result;
  }

  /// 调用返回 `{success: bool}` 的原生方法。
  Future<bool> _invokeSuccess(String method,
      [Map<String, dynamic>? arguments]) async {
    final result =
        await methodChannel.invokeMapMethod<dynamic, dynamic>(method, arguments);
    return result?['success'] as bool? ?? false;
  }

  Future<T> _guard<T>(String method, Future<T> Function() operation) async {
    try {
      return await operation();
    } catch (e, s) {
      Error.throwWithStackTrace(operationFailed(method, e), s);
    }
  }

  Future<bool> _succeeds(Future<void> Function() operation) async {
    try {
      await operation();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<dirs.StorageSpace> _storageSpace(String path) async {
    try {
      final result = await methodChannel
          .invokeMapMethod<String, dynamic>('getStorageSpace', {'path': path});
      return (
        total: result?['totalSpace'] as int? ?? 0,
        free: result?['freeSpace'] as int? ?? 0,
        usable: result?['usableSpace'] as int? ?? 0,
      );
    } on PlatformException {
      return (total: 0, free: 0, usable: 0);
    } on MissingPluginException {
      return (total: 0, free: 0, usable: 0);
    }
  }

  @override
  Future<List<StorageDevice>> getAllStorageDevices() async {
    final result =
        await methodChannel.invokeListMethod<dynamic>('getAllStorageDevices');
    return (result ?? const [])
        .cast<Map<dynamic, dynamic>>()
        .map((map) => StorageDevice.fromMap(Map<String, dynamic>.from(map)))
        .toList();
  }

  @override
  Future<Uint8List> readFile(String path, {int offset = 0, int length = -1}) =>
      _guard('readFile', () => files.readFile(path, offset, length));

  @override
  Future<int> writeFile(String path, Uint8List data, {bool append = false}) =>
      _guard('writeFile', () => files.writeFile(path, data, append));

  @override
  Future<bool> copyFile(String sourcePath, String targetPath) =>
      _succeeds(() => files.copyFile(sourcePath, targetPath));

  @override
  Future<bool> moveFile(String sourcePath, String targetPath) =>
      _succeeds(() => files.moveFile(sourcePath, targetPath));

  @override
  Future<bool> deleteFile(String path) =>
      _succeeds(() => files.deleteFile(path));

  @override
  Future<FileInfo> getFileInfo(String path) =>
      _guard('getFileInfo', () => files.getFileInfo(path));

  @override
  Future<String> calculateMD5(String path) =>
      _guard('calculateMD5', () => files.calculateMD5(path));

  @override
  Future<bool> createFile(String path) =>
      _succeeds(() => files.createFile(path));

  @override
  Future<bool> fileExists(String path) =>
      _guard('fileExists', () => pathExists(path));

  @override
  Future<String?> getMimeType(String path) =>
      _guard('getMimeType', () => files.getMimeType(path));

  @override
  Future<bool> truncateFile(String path, int size) =>
      _succeeds(() => files.truncateFile(path, size));

  @override
  Future<List<FileInfo>> listDirectory(String path, {bool recursive = false}) =>
      _guard('listDirectory', () => dirs.listDirectory(path, recursive));

  @override
  Future<bool> createDirectory(String path, {bool recursive = false}) =>
      _succeeds(() => dirs.createDirectory(path, recursive));

  @override
  Future<bool> deleteDirectory(String path, {bool recursive = false}) =>
      _succeeds(() => dirs.deleteDirectory(path, recursive));

  @override
  Future<bool> moveDirectory(String sourcePath, String targetPath) =>
      _succeeds(() => dirs.moveDirectory(sourcePath, targetPath));

  @override
  Future<bool> copyDirectory(String sourcePath, String targetPath) =>
      _succeeds(() => dirs.copyDirectory(sourcePath, targetPath));

  @override
  Future<DirectoryInfo> getDirectoryInfo(String path) => _guard(
      'getDirectoryInfo', () => dirs.getDirectoryInfo(path, _storageSpace));

  @override
  Future<bool> isDirectoryEmpty(String path) =>
      _guard('isDirectoryEmpty', () => dirs.isDirectoryEmpty(path));

  @override
  Future<int> getDirectorySize(String path) =>
      _guard('getDirectorySize', () => dirs.getDirectorySize(path));

  @override
  Future<bool> directoryExists(String path) =>
      _guard('directoryExists', () => dirs.directoryExists(path));

  @override
  Stream<WatchEvent> watch(
    String path, {
    bool recursive = false,
    List<WatchEventType> events = const [],
  }) {
    final root = absolutePath(path);
    final id = '$_streamIdPrefix${_nextStreamId++}';
    late final StreamController<WatchEvent> controller;
    controller = StreamController<WatchEvent>(
      onListen: () async {
        _streams[id] = controller;
        try {
          await _startWatch(id, root, recursive, events);
        } catch (e, s) {
          if (_streams.remove(id) != null) {
            controller.addError(operationFailed('watch', e), s);
            unawaited(controller.close());
          }
          return;
        }
        // 启动期间已被取消：补上停止，避免原生端残留监视。
        if (!_streams.containsKey(id)) await _stopWatch(id);
      },
      onCancel: () async {
        if (_streams.remove(id) != null) await _stopWatch(id);
      },
    );
    return controller.stream;
  }

  Future<void> _startWatch(String id, String root, bool recursive,
      List<WatchEventType> events) async {
    final mask = WatchEventType.maskOf(events);
    if (_isAndroid) {
      _ensureHandler();
      await _invokeChecked('startWatching', {
        'watchId': id,
        'path': root,
        'recursive': recursive,
        'eventMask': mask,
      });
      return;
    }
    _pollers.remove(id)?.cancel();
    final poller = PollingWatcher(
      root,
      recursive: recursive,
      mask: mask == 0 ? WatchEventType.allMask : mask,
      interval: pollingInterval,
      onEvent: (event) => _dispatch(id, event),
      onDone: () => _finishWatch(id),
    );
    _pollers[id] = poller;
    try {
      await poller.start();
    } catch (_) {
      if (identical(_pollers[id], poller)) _pollers.remove(id);
      rethrow;
    }
  }

  Future<void> _stopWatch(String id) async {
    if (!_isAndroid) {
      _pollers.remove(id)?.cancel();
      return;
    }
    try {
      await _invokeSuccess('stopWatching', {'watchId': id});
    } on PlatformException {
      // 引擎已分离等情况下没有可停止的原生监视。
    } on MissingPluginException {
      // 同上。
    }
  }

  void _dispatch(String id, WatchEvent event) {
    final controller = _streams[id];
    if (controller != null) {
      controller.add(event);
    } else if (!id.startsWith(_streamIdPrefix)) {
      _watchEventCallback?.call(event.path, event.type);
    }
  }

  /// 监视的根路径被删除或移走，原生端 / 轮询已经停止。
  void _finishWatch(String id) {
    _pollers.remove(id);
    _streams.remove(id)?.close();
  }

  @override
  Future<bool> startWatching(
    String path, {
    bool recursive = false,
    List<WatchEventType> events = const [],
  }) {
    final root = absolutePath(path);
    return _succeeds(() => _startWatch(root, root, recursive, events));
  }

  @override
  Future<bool> stopWatching(String path) async {
    final id = absolutePath(path);
    if (_isAndroid) {
      return _invokeSuccess('stopWatching', {'watchId': id});
    }
    final poller = _pollers.remove(id);
    poller?.cancel();
    return poller != null;
  }

  @override
  Future<bool> stopAllWatching() async {
    final stopped = _isAndroid ? await _invokeSuccess('stopAllWatching') : true;
    for (final poller in _pollers.values) {
      poller.cancel();
    }
    _pollers.clear();
    final controllers = _streams.values.toList();
    _streams.clear();
    for (final controller in controllers) {
      unawaited(controller.close());
    }
    return stopped;
  }

  @override
  Future<List<String>> getWatchedPaths() async {
    if (!_isAndroid) {
      return {for (final poller in _pollers.values) poller.root}.toList();
    }
    final result = await _invokeChecked('getWatchedPaths');
    return (result['paths'] as List).cast<String>();
  }

  @override
  Future<bool> isWatching(String path) async {
    final root = absolutePath(path);
    if (!_isAndroid) {
      return _pollers.values.any((poller) => poller.root == root);
    }
    final result = await _invokeChecked('isWatching', {'path': root});
    return result['watching'] as bool;
  }

  // iOS（以及桌面平台）的应用沙盒没有运行时存储权限，下面的权限方法只在 Android 上调用原生端。

  @override
  Future<bool> checkStoragePermissions() async {
    if (!_isAndroid) return true;
    final result = await _invokeChecked('checkStoragePermissions');
    return result['hasPermission'] as bool;
  }

  @override
  Future<bool> requestStoragePermissions() async {
    final granted =
        _isAndroid ? await _invokeSuccess('requestStoragePermissions') : true;
    _permissionResultCallback?.call(granted);
    return granted;
  }

  @override
  Future<bool> shouldShowRequestPermissionRationale() async {
    if (!_isAndroid) return false;
    final result = await _invokeChecked('shouldShowRequestPermissionRationale');
    return result['shouldShow'] as bool;
  }

  @override
  Future<bool> openAppSettings() => _invokeSuccess('openAppSettings');

  @override
  Future<bool> checkPermission(String permission) async {
    if (!_isAndroid) return false;
    final result =
        await _invokeChecked('checkPermission', {'permission': permission});
    return result['hasPermission'] as bool;
  }

  @override
  Future<List<String>> getGrantedPermissions() async {
    if (!_isAndroid) return const [];
    final result = await _invokeChecked('getGrantedPermissions');
    return (result['permissions'] as List).cast<String>();
  }

  @override
  void registerWatchEventCallback(
      void Function(String path, WatchEventType event) callback) {
    if (_isAndroid) _ensureHandler();
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
