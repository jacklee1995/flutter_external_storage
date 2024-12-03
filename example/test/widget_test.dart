import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:external_storage/external_storage.dart';
import 'package:external_storage_example/main.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';

import 'widget_test.mocks.dart';

@GenerateMocks([ExternalStorage])
void main() {
  late MockExternalStorage mockStorage;
  final testTime = DateTime(2024, 12, 1, 21, 4, 22);

  Widget createTestApp(MockExternalStorage storage) {
    return MaterialApp(
      home: StorageDemo(storage: storage),
    );
  }

  setUp(() {
    mockStorage = MockExternalStorage();

    // 基础操作模拟
    when(mockStorage.stopAllWatching()).thenAnswer((_) async => true);
    when(mockStorage.fileExists(any)).thenAnswer((_) async => false);
    when(mockStorage.directoryExists(any)).thenAnswer((_) async => false);
    when(mockStorage.startWatching(any)).thenAnswer((_) async => true);
    when(mockStorage.stopWatching(any)).thenAnswer((_) async => true);

    // 权限检查模拟
    when(mockStorage.checkStoragePermissions()).thenAnswer((_) async => true);

    // 存储设备模拟
    when(mockStorage.getAllStorageDevices()).thenAnswer((_) async => [
          StorageDevice(
            path: '/storage/emulated/0',
            name: 'Internal Storage',
            isRemovable: false,
            totalSize: 64 * 1024 * 1024 * 1024,
            availableSize: 32 * 1024 * 1024 * 1024,
            isReadOnly: false,
          ),
          StorageDevice(
            path: '/storage/sdcard',
            name: 'SD Card',
            isRemovable: true,
            totalSize: 32 * 1024 * 1024 * 1024,
            availableSize: 16 * 1024 * 1024 * 1024,
            isReadOnly: false,
          ),
        ]);

    // 目录列表模拟
    when(mockStorage.listDirectory(any)).thenAnswer((_) async => [
          FileInfo(
            name: 'test.txt',
            path: '/storage/emulated/0/test.txt',
            size: 1024,
            lastModified: testTime,
            isDirectory: false,
            isFile: true,
            canRead: true,
            canWrite: true,
            canExecute: false,
            isHidden: false,
          ),
          FileInfo(
            name: 'test_dir',
            path: '/storage/emulated/0/test_dir',
            size: 0,
            lastModified: testTime,
            isDirectory: true,
            isFile: false,
            canRead: true,
            canWrite: true,
            canExecute: true,
            isHidden: false,
          ),
        ]);
  });

  group('UI Tests', () {
    testWidgets('Initial UI Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      // 验证基础UI元素
      expect(find.text('External Storage Demo'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(find.byIcon(Icons.home), findsOneWidget);
      expect(find.byIcon(Icons.note_add), findsOneWidget);
      expect(find.byIcon(Icons.create_new_folder), findsOneWidget);

      // 验证存储设备列表
      expect(find.text('Internal Storage'), findsOneWidget);
      expect(find.text('SD Card'), findsOneWidget);
    });

    testWidgets('Storage Device Selection Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      // 点击存储设备
      await tester.tap(find.text('Internal Storage'));
      await tester.pumpAndSettle();

      // 验证文件列表
      expect(find.text('test.txt'), findsOneWidget);
      expect(find.text('test_dir'), findsOneWidget);
      expect(find.textContaining('/storage/emulated/0'), findsOneWidget);
    });

    testWidgets('Permission Status Display Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      expect(find.textContaining('存储权限状态'), findsOneWidget);
    });
  });

  group('File Operations Tests', () {
    testWidgets('Create File Test', (WidgetTester tester) async {
      when(mockStorage.writeFile(any, any, append: anyNamed('append')))
          .thenAnswer((_) async => 13);

      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      // 进入存储设备
      await tester.tap(find.text('Internal Storage'));
      await tester.pumpAndSettle();

      // 创建文件
      await tester.tap(find.byIcon(Icons.note_add));
      await tester.pumpAndSettle();

      verify(mockStorage.writeFile(any, any, append: false)).called(1);
    });

    testWidgets('Create Directory Test', (WidgetTester tester) async {
      when(mockStorage.createDirectory(any, recursive: anyNamed('recursive')))
          .thenAnswer((_) async => true);

      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Internal Storage'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.create_new_folder));
      await tester.pumpAndSettle();

      verify(mockStorage.createDirectory(any, recursive: false)).called(1);
    });

    testWidgets('Cut and Paste Test', (WidgetTester tester) async {
      when(mockStorage.moveFile(any, any)).thenAnswer((_) async => true);
      when(mockStorage.moveDirectory(any, any)).thenAnswer((_) async => true);

      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Internal Storage'));
      await tester.pumpAndSettle();

      // 长按打开底部菜单
      await tester.longPress(find.text('test.txt'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('剪切'));
      await tester.pumpAndSettle();

      // 验证剪切操作UI
      expect(find.byIcon(Icons.paste), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsOneWidget);

      // 执行粘贴
      await tester.tap(find.byIcon(Icons.paste));
      await tester.pumpAndSettle();

      verify(mockStorage.moveFile(any, any)).called(1);
    });

    testWidgets('Copy and Paste Test', (WidgetTester tester) async {
      when(mockStorage.copyFile(any, any)).thenAnswer((_) async => true);
      when(mockStorage.copyDirectory(any, any)).thenAnswer((_) async => true);

      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Internal Storage'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('test.txt'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('复制'));
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.paste), findsOneWidget);
      expect(find.byIcon(Icons.cancel), findsNothing);

      // 多次粘贴测试
      await tester.tap(find.byIcon(Icons.paste));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.paste));
      await tester.pumpAndSettle();

      verify(mockStorage.copyFile(any, any)).called(2);
    });
  });

  group('Error Handling Tests', () {
    testWidgets('Copy Operation Error Test', (WidgetTester tester) async {
      when(mockStorage.copyFile(any, any)).thenThrow(Exception('Copy failed'));

      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Internal Storage'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('test.txt'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('复制'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.paste));
      await tester.pumpAndSettle();

      expect(find.text('错误'), findsOneWidget);
      expect(find.text('粘贴失败: Exception: Copy failed'), findsOneWidget);
    });

    testWidgets('Permission Denied Test', (WidgetTester tester) async {
      when(mockStorage.checkStoragePermissions())
          .thenAnswer((_) async => false);

      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      expect(find.text('需要存储权限才能使用此应用'), findsOneWidget);
      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });

  group('File Information Tests', () {
    testWidgets('File Info Dialog Test', (WidgetTester tester) async {
      when(mockStorage.getFileInfo(any)).thenAnswer((_) async => FileInfo(
            name: 'test.txt',
            path: '/storage/emulated/0/test.txt',
            size: 1024,
            lastModified: testTime,
            isDirectory: false,
            isFile: true,
            canRead: true,
            canWrite: true,
            canExecute: false,
            isHidden: false,
          ));

      when(mockStorage.calculateMD5(any))
          .thenAnswer((_) async => 'test-md5-hash');

      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Internal Storage'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('test.txt'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('详细信息'));
      await tester.pumpAndSettle();

      expect(find.text('文件信息'), findsOneWidget);
      expect(find.textContaining('名称: test.txt'), findsOneWidget);
      expect(find.textContaining('大小: 1.00 KB'), findsOneWidget);
      expect(find.textContaining('MD5: test-md5-hash'), findsOneWidget);
    });

    testWidgets('Directory Info Dialog Test', (WidgetTester tester) async {
      when(mockStorage.getDirectoryInfo(any))
          .thenAnswer((_) async => DirectoryInfo(
                name: 'test_dir',
                path: '/storage/emulated/0/test_dir',
                lastModified: testTime,
                fileCount: 5,
                directoryCount: 2,
                totalSpace: 1024 * 1024,
                freeSpace: 512 * 1024,
                usableSpace: 512 * 1024, // 添加可用空间
                canRead: true,
                canWrite: true,
                canExecute: true,
                isHidden: false, // 添加是否隐藏
              ));

      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Internal Storage'));
      await tester.pumpAndSettle();

      await tester.longPress(find.text('test_dir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('详细信息'));
      await tester.pumpAndSettle();

      expect(find.text('目录信息'), findsOneWidget);
      expect(find.textContaining('名称: test_dir'), findsOneWidget);
      expect(find.textContaining('文件数量: 5'), findsOneWidget);
      expect(find.textContaining('目录数量: 2'), findsOneWidget);
      expect(find.textContaining('总空间: 1.00 MB'), findsOneWidget);
      expect(find.textContaining('可用空间: 512.00 KB'), findsOneWidget);
    });
  });

  group('Navigation Tests', () {
    testWidgets('Directory Navigation Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Internal Storage'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('test_dir'));
      await tester.pumpAndSettle();

      verify(mockStorage.listDirectory('/storage/emulated/0/test_dir'))
          .called(1);
    });

    testWidgets('Back Navigation Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Internal Storage'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('test_dir'));
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      verify(mockStorage.stopWatching(any)).called(1);
    });

    testWidgets('Home Navigation Test', (WidgetTester tester) async {
      await tester.pumpWidget(createTestApp(mockStorage));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Internal Storage'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.home));
      await tester.pumpAndSettle();

      expect(find.text('Internal Storage'), findsOneWidget);
      expect(find.text('SD Card'), findsOneWidget);
    });
  });
}
