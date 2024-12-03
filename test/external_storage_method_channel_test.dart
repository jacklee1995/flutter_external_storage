import 'package:external_storage/external_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MethodChannelExternalStorage platform = MethodChannelExternalStorage();
  final List<MethodCall> log = <MethodCall>[];
  DateTime testTime = DateTime(2024);

  setUp(() {
    // 设置测试通道处理器
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('tech.thispage.external_storage'),
      (MethodCall methodCall) async {
        log.add(methodCall);
        switch (methodCall.method) {
          case 'getAllStorageDevices':
            return [
              {
                'path': '/storage/emulated/0',
                'name': '内部存储',
                'isRemovable': false,
                'totalSize': 1024 * 1024 * 1024,
                'availableSize': 512 * 1024 * 1024,
                'isReadOnly': false,
              }
            ];

          case 'readFile':
            return {
              'success': true,
              'data': Uint8List.fromList([1, 2, 3, 4]),
              'bytesRead': 4
            };

          case 'writeFile':
            return {'success': true, 'bytesWritten': 4};

          case 'getFileInfo':
            return {
              'success': true,
              'info': {
                'name': 'test.txt',
                'path': '/storage/emulated/0/test.txt',
                'size': 1024,
                'lastModified': testTime.millisecondsSinceEpoch,
                'isDirectory': false,
                'isFile': true,
                'canRead': true,
                'canWrite': true,
                'canExecute': false,
                'isHidden': false,
              }
            };

          case 'getDirectoryInfo':
            return {
              'success': true,
              'name': 'test_dir',
              'path': '/storage/emulated/0/test_dir',
              'parent': '/storage/emulated/0',
              'lastModified': testTime.toIso8601String(),
              'canRead': true,
              'canWrite': true,
              'canExecute': true,
              'isHidden': false,
              'totalSpace': 1024 * 1024,
              'freeSpace': 512 * 1024,
              'usableSpace': 512 * 1024,
              'fileCount': 5,
              'directoryCount': 2,
            };

          case 'listDirectory':
            return {
              'success': true,
              'entries': [
                {
                  'name': 'test.txt',
                  'path': '/storage/emulated/0/test.txt',
                  'size': 1024,
                  'lastModified': testTime.millisecondsSinceEpoch,
                  'isDirectory': false,
                  'isFile': true,
                  'canRead': true,
                  'canWrite': true,
                  'canExecute': false,
                  'isHidden': false,
                }
              ]
            };

          default:
            return {'success': true};
        }
      },
    );
  });

  tearDown(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('tech.thispage.external_storage'), null);
  });

  test('getAllStorageDevices', () async {
    final devices = await platform.getAllStorageDevices();
    expect(devices, isA<List<StorageDevice>>());
    expect(devices.length, 1);
    expect(devices[0].name, '内部存储');
    expect(log, <Matcher>[
      isMethodCall('getAllStorageDevices', arguments: null),
    ]);
  });

  test('readFile', () async {
    final data = await platform.readFile('/test.txt');
    expect(data, isA<Uint8List>());
    expect(data.length, 4);
    expect(log, <Matcher>[
      isMethodCall('readFile',
          arguments: {'path': '/test.txt', 'offset': 0, 'length': -1}),
    ]);
  });

  test('writeFile', () async {
    final bytesWritten =
        await platform.writeFile('/test.txt', Uint8List.fromList([1, 2, 3, 4]));
    expect(bytesWritten, 4);
    expect(log, <Matcher>[
      isMethodCall('writeFile', arguments: {
        'path': '/test.txt',
        'data': [1, 2, 3, 4],
        'append': false
      }),
    ]);
  });

  test('getFileInfo', () async {
    final info = await platform.getFileInfo('/test.txt');
    expect(info, isA<FileInfo>());
    expect(info.name, 'test.txt');
    expect(log, <Matcher>[
      isMethodCall('getFileInfo', arguments: {'path': '/test.txt'}),
    ]);
  });

  test('getDirectoryInfo', () async {
    final info = await platform.getDirectoryInfo('/test_dir');
    expect(info, isA<DirectoryInfo>());
    expect(info.name, 'test_dir');
    expect(info.fileCount, 5);
    expect(info.directoryCount, 2);
    expect(log, <Matcher>[
      isMethodCall('getDirectoryInfo', arguments: {'path': '/test_dir'}),
    ]);
  });

  test('listDirectory', () async {
    final entries = await platform.listDirectory('/test_dir');
    expect(entries, isA<List<FileInfo>>());
    expect(entries.length, 1);
    expect(entries[0].name, 'test.txt');
    expect(log, <Matcher>[
      isMethodCall('listDirectory',
          arguments: {'path': '/test_dir', 'recursive': false}),
    ]);
  });

  test('startWatching', () async {
    final success = await platform.startWatching('/test_dir',
        recursive: true,
        events: [WatchEventType.create, WatchEventType.delete]);
    expect(success, isTrue);
    expect(log, <Matcher>[
      isMethodCall('startWatching', arguments: {
        'path': '/test_dir',
        'recursive': true,
        'eventMask': WatchEventType.create.value | WatchEventType.delete.value,
      }),
    ]);
  });

  test('stopWatching', () async {
    final success = await platform.stopWatching('/test_dir');
    expect(success, isTrue);
    expect(log, <Matcher>[
      isMethodCall('stopWatching', arguments: {'path': '/test_dir'}),
    ]);
  });

  test('watchEventCallback', () async {
    String? receivedPath;
    WatchEventType? receivedEvent;

    platform.registerWatchEventCallback((path, event) {
      receivedPath = path;
      receivedEvent = event;
    });

    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
      'tech.thispage.external_storage',
      const StandardMethodCodec().encodeMethodCall(
        const MethodCall(
          'onFileSystemEvent',
          {
            'path': '/test_dir/new_file.txt',
            'eventType': 256,
          },
        ),
      ),
      (ByteData? data) {},
    );

    expect(receivedPath, '/test_dir/new_file.txt');
    expect(receivedEvent, WatchEventType.create);
  });
}
