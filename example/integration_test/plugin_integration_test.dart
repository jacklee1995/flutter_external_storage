import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:external_storage/external_storage.dart';
import 'package:path/path.dart' as path;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  final storage = ExternalStorage();
  const testDir = '/storage/emulated/0/Download/external_storage_test';
  final testFile = path.join(testDir, 'test.txt');
  const testContent = 'Hello, External Storage!';

  setUpAll(() async {
    // 确保有存储权限
    final hasPermission = await storage.checkStoragePermissions();
    if (!hasPermission) {
      final granted = await storage.requestStoragePermissions();
      expect(granted, true, reason: '未能获取存储权限');
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

      for (var device in devices) {
        expect(device.path, isNotEmpty);
        expect(device.totalSize, greaterThan(0));
        expect(device.availableSize, greaterThanOrEqualTo(0));
      }
    });
  });

  group('File Operation Tests', () {
    test('Create and write file', () async {
      final data = Uint8List.fromList(testContent.codeUnits);
      final bytesWritten = await storage.writeFile(testFile, data);
      expect(bytesWritten, equals(testContent.length));

      final exists = await storage.fileExists(testFile);
      expect(exists, true);
    });

    test('Read file', () async {
      final content = await storage.readFile(testFile);
      expect(
        String.fromCharCodes(content),
        equals(testContent),
      );
    });

    test('Get file info', () async {
      final info = await storage.getFileInfo(testFile);
      expect(info.name, equals(path.basename(testFile)));
      expect(info.size, equals(testContent.length));
      expect(info.isFile, true);
      expect(info.isDirectory, false);
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
  });

  group('Permission Tests', () {
    test('Check and request permissions', () async {
      final hasPermission = await storage.checkStoragePermissions();
      expect(hasPermission, true);

      final shouldShow = await storage.shouldShowRequestPermissionRationale();
      expect(shouldShow, isA<bool>());

      final permissions = await storage.getGrantedPermissions();
      expect(permissions, isNotEmpty);
    });
  });

  group('Error Handling Tests', () {
    test('Handle invalid path', () async {
      try {
        await storage.readFile('/invalid/path');
        fail('Should throw an exception');
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('Handle file already exists', () async {
      final existingFile = path.join(testDir, 'existing.txt');
      await storage.writeFile(
        existingFile,
        Uint8List.fromList([0]),
      );

      try {
        await storage.moveFile(testFile, existingFile);
        fail('Should throw an exception');
      } catch (e) {
        expect(e, isNotNull);
      }
    });
  });
}
