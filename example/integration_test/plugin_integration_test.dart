import 'dart:async';
import 'dart:convert' show utf8;
import 'dart:io' show Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:external_storage/external_storage.dart';
import 'package:path/path.dart' as path;

/// 在真机/模拟器上验证原生端（存储卷、权限、Android 的 inotify 监视）：
///
///   cd example
///   # Android 11+ 的「所有文件访问权限」只能在设置页授予，自动化测试前先用 adb 预授权：
///   adb shell appops set --uid tech.thispage.external_storage_example MANAGE_EXTERNAL_STORAGE allow
///   flutter test integration_test
///
/// Android 上测试目录在 Download 下，iOS 上在 App 的 Documents 目录下。
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final storage = ExternalStorage();
  late String testDir;
  late String testFile;
  const testContent = 'Hello, External Storage! 你好';

  setUpAll(() async {
    final primary =
        (await storage.getAllStorageDevices()).firstWhere((d) => d.isPrimary);
    testDir = Platform.isAndroid
        ? path.join(primary.path, 'Download', 'external_storage_test')
        : path.join(primary.path, 'external_storage_test');
    testFile = path.join(testDir, 'test.txt');

    // 确保有存储权限
    final hasPermission = await storage.checkStoragePermissions();
    if (!hasPermission) {
      final granted = await storage.requestStoragePermissions();
      expect(granted, true, reason: '未能获取存储权限');
    }
    if (await storage.directoryExists(testDir)) {
      await storage.deleteDirectory(testDir, recursive: true);
    }

    // 创建测试目录
    await storage.createDirectory(testDir, recursive: true);
  });

  tearDownAll(() async {
    // 清理测试目录
    if (await storage.directoryExists(testDir)) {
      await storage.deleteDirectory(testDir, recursive: true);
    }
  });

  group('Storage Device Tests', () {
    test('Get all storage devices', () async {
      final devices = await storage.getAllStorageDevices();
      expect(devices, isNotEmpty);
      expect(devices.where((d) => d.isPrimary), hasLength(1));

      for (var device in devices) {
        debugPrint('存储设备: $device');
        expect(device.path, isNotEmpty);
        expect(device.totalSize, greaterThan(0));
        expect(device.availableSize, greaterThanOrEqualTo(0));
        if (device.isRemovable) {
          expect(device.uuid, isNotNull, reason: '可移除卷（SD 卡 / U 盘）应有 UUID');
        }
      }
    });
  });

  group('File Operation Tests', () {
    final contentBytes = utf8.encode(testContent);

    test('Create and write file', () async {
      final bytesWritten =
          await storage.writeFile(testFile, Uint8List.fromList(contentBytes));
      expect(bytesWritten, equals(contentBytes.length));

      final exists = await storage.fileExists(testFile);
      expect(exists, true);
    });

    test('Read file', () async {
      final content = await storage.readFile(testFile);
      expect(utf8.decode(content), equals(testContent));
    });

    test('Get file info', () async {
      final info = await storage.getFileInfo(testFile);
      expect(info.name, equals(path.basename(testFile)));
      expect(info.size, equals(contentBytes.length));
      expect(info.isFile, true);
      expect(info.isDirectory, false);
      // 有存储权限时 access(2) 应报告可读写（Android 11+ 共享存储经由 FUSE）
      expect(info.canRead, true);
      expect(info.canWrite, true);
    });

    test('MIME type', () async {
      expect(await storage.getMimeType(testFile), 'text/plain');
    });

    test('Calculate MD5', () async {
      final md5 = await storage.calculateMD5(testFile);
      expect(md5, isNotEmpty);
    });

    test('Copy file', () async {
      final copyPath = path.join(testDir, 'test_copy.txt');
      final success = await storage.copyFile(testFile, copyPath);
      expect(success, true);

      final exists = await storage.fileExists(copyPath);
      expect(exists, true);
    });

    test('Move file', () async {
      final movePath = path.join(testDir, 'test_moved.txt');
      final success = await storage.moveFile(testFile, movePath);
      expect(success, true);

      final sourceExists = await storage.fileExists(testFile);
      expect(sourceExists, false);

      final targetExists = await storage.fileExists(movePath);
      expect(targetExists, true);
    });
  });

  group('Directory Operation Tests', () {
    test('Create directory', () async {
      final newDir = path.join(testDir, 'new_dir');
      final success = await storage.createDirectory(newDir);
      expect(success, true);

      final exists = await storage.directoryExists(newDir);
      expect(exists, true);
    });

    test('List directory', () async {
      final entries = await storage.listDirectory(testDir);
      expect(entries, isNotEmpty);

      for (var entry in entries) {
        expect(entry.path, startsWith(testDir));
        expect(entry.name, isNotEmpty);
      }
    });

    test('Get directory info', () async {
      final info = await storage.getDirectoryInfo(testDir);
      expect(info.path, equals(testDir));
      expect(info.fileCount, greaterThanOrEqualTo(0));
      expect(info.directoryCount, greaterThanOrEqualTo(0));
      // 卷容量来自原生端（Android StatFs / iOS URL resource values）
      expect(info.totalSpace, greaterThan(0));
      expect(info.usableSpace, greaterThan(0));
    });

    test('Check directory empty', () async {
      final emptyDir = path.join(testDir, 'empty_dir');
      await storage.createDirectory(emptyDir);

      final isEmpty = await storage.isDirectoryEmpty(emptyDir);
      expect(isEmpty, true);
    });

    test('Get directory size', () async {
      final size = await storage.getDirectorySize(testDir);
      expect(size, greaterThanOrEqualTo(0));
    });
  });

  group('File System Watch Tests', () {
    test('Start and stop watching', () async {
      // 开始监视
      final startSuccess = await storage.startWatching(
        testDir,
        recursive: true,
        events: [
          WatchEventType.create,
          WatchEventType.modify,
          WatchEventType.delete,
        ],
      );
      expect(startSuccess, true);

      // 验证正在监视
      final isWatching = await storage.isWatching(testDir);
      expect(isWatching, true);

      // 获取监视的路径
      final watchedPaths = await storage.getWatchedPaths();
      expect(watchedPaths, contains(testDir));

      // 停止监视
      final stopSuccess = await storage.stopWatching(testDir);
      expect(stopSuccess, true);
    });

    test('watch() reports changes in subdirectories with full paths', () async {
      final watchDir = path.join(testDir, 'watched');
      await storage.createDirectory(path.join(watchDir, 'sub'), recursive: true);

      final events = <WatchEvent>[];
      final subscription = storage
          .watch(watchDir, recursive: true, events: [WatchEventType.create])
          .listen(events.add);
      // 监视在订阅后异步启动（Android 订阅子目录、iOS 拍第一张快照）
      await Future<void>.delayed(const Duration(seconds: 2));

      final nested = path.join(watchDir, 'sub', 'nested.txt');
      await storage.writeFile(nested, Uint8List.fromList([1]));

      final deadline = DateTime.now().add(const Duration(seconds: 10));
      while (!events.any((e) => e.path == nested) &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
      await subscription.cancel();

      final created = events.firstWhere((e) => e.path == nested);
      expect(created.type, WatchEventType.create);
      expect(created.watchedPath, watchDir);
      expect(created.isDirectory, isFalse);
      expect(await storage.isWatching(watchDir), isFalse);
    });

    test('watch() ends when the watched directory is deleted', () async {
      final watchDir = path.join(testDir, 'to_delete');
      await storage.createDirectory(watchDir);

      final done = Completer<void>();
      final events = <WatchEvent>[];
      storage.watch(watchDir).listen(events.add, onDone: done.complete);
      await Future<void>.delayed(const Duration(seconds: 2));

      await storage.deleteDirectory(watchDir, recursive: true);
      await done.future.timeout(const Duration(seconds: 10));
      expect(events.map((e) => e.type), contains(WatchEventType.deleteSelf));
    });
  });

  group('Permission Tests', () {
    // 与 README 中的示例相同；在设备上运行时不再出现 MissingPluginException。
    test('检查和请求存储权限', () async {
      bool hasPermission = await storage.checkStoragePermissions();
      if (!hasPermission) {
        hasPermission = await storage.requestStoragePermissions();
      }
      expect(hasPermission, isTrue);
    });

    test('Rationale, granted list and settings', () async {
      final shouldShow = await storage.shouldShowRequestPermissionRationale();
      expect(shouldShow, isA<bool>());

      // iOS 没有 Android 权限，列表为空
      final permissions = await storage.getGrantedPermissions();
      expect(permissions, Platform.isAndroid ? isNotEmpty : isEmpty);

      // 已有权限时请求应立即返回 true，不弹任何界面。
      expect(await storage.requestStoragePermissions(), isTrue);
    });

    test('checkPermission for an undeclared permission is false', () async {
      expect(await storage.checkPermission('android.permission.CAMERA'), isFalse);
    });
  });

  group('Error Handling Tests', () {
    test('Handle invalid path', () async {
      await expectLater(
        storage.readFile('/invalid/path'),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'OPERATION_FAILED')),
      );
    });

    test('Move a missing source returns false', () async {
      final existingFile = path.join(testDir, 'existing.txt');
      await storage.writeFile(existingFile, Uint8List.fromList([0]));

      // testFile 已在 "Move file" 中被移走
      expect(await storage.moveFile(testFile, existingFile), isFalse);
    });

    test('Read range past end of file returns empty data', () async {
      final f = path.join(testDir, 'range.txt');
      await storage.writeFile(f, Uint8List.fromList([1, 2, 3]));
      expect(await storage.readFile(f, offset: 1, length: 1), [2]);
      expect(await storage.readFile(f, offset: 10), isEmpty);
    });
  });
}
