import 'package:external_storage/external_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 通过方法通道调用原生端的部分：存储卷、权限（Android）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tech.thispage.external_storage');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final log = <MethodCall>[];

  setUp(() {
    messenger.setMockMethodCallHandler(channel, (MethodCall call) async {
      log.add(call);
      switch (call.method) {
        case 'getAllStorageDevices':
          return [
            {
              'path': '/storage/emulated/0',
              'name': '内部共享存储空间',
              'isPrimary': true,
              'isRemovable': false,
              'totalSize': 1024 * 1024 * 1024,
              'availableSize': 512 * 1024 * 1024,
              'isReadOnly': false,
              'description': '内部共享存储空间',
            },
            {
              'path': '/storage/1A2B-3C4D',
              'name': 'SanDisk SD card',
              'isRemovable': true,
              'totalSize': 2048,
              'availableSize': 1024,
              'isReadOnly': false,
              'uuid': '1A2B-3C4D',
              'description': 'SanDisk SD card',
            },
          ];
        case 'checkStoragePermissions':
        case 'checkPermission':
          return {'hasPermission': true};
        case 'requestStoragePermissions':
          return {'success': false};
        case 'shouldShowRequestPermissionRationale':
          return {'shouldShow': true};
        case 'getGrantedPermissions':
          return {
            'permissions': ['android.permission.MANAGE_EXTERNAL_STORAGE']
          };
        default:
          return {'success': true};
      }
    });
  });

  tearDown(() {
    log.clear();
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('getAllStorageDevices parses volumes', () async {
    final devices =
        await MethodChannelExternalStorage(isAndroid: true).getAllStorageDevices();
    expect(devices, hasLength(2));
    expect(devices[0].isPrimary, isTrue);
    expect(devices[0].uuid, isNull);
    expect(devices[1].isPrimary, isFalse);
    expect(devices[1].uuid, '1A2B-3C4D');
    expect(devices[1].description, 'SanDisk SD card');
    expect(log.single, isMethodCall('getAllStorageDevices', arguments: null));
  });

  group('Android permissions use the native side', () {
    late MethodChannelExternalStorage platform;
    setUp(() => platform = MethodChannelExternalStorage(isAndroid: true));

    test('checkStoragePermissions', () async {
      expect(await platform.checkStoragePermissions(), isTrue);
      expect(log.single, isMethodCall('checkStoragePermissions', arguments: null));
    });

    test('requestStoragePermissions reports the result to the callback',
        () async {
      bool? reported;
      platform.registerPermissionResultCallback((granted) => reported = granted);
      expect(await platform.requestStoragePermissions(), isFalse);
      expect(reported, isFalse);
      expect(log.single,
          isMethodCall('requestStoragePermissions', arguments: null));
    });

    test('rationale, specific and granted permissions', () async {
      expect(await platform.shouldShowRequestPermissionRationale(), isTrue);
      expect(await platform.checkPermission('android.permission.X'), isTrue);
      expect(log.last,
          isMethodCall('checkPermission', arguments: {'permission': 'android.permission.X'}));
      expect(await platform.getGrantedPermissions(),
          ['android.permission.MANAGE_EXTERNAL_STORAGE']);
      expect(await platform.openAppSettings(), isTrue);
    });

    test('native errors propagate as PlatformException', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'PERMISSION_NOT_DECLARED');
      });
      await expectLater(
        platform.requestStoragePermissions(),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'PERMISSION_NOT_DECLARED')),
      );
    });
  });

  group('iOS has no storage permission', () {
    late MethodChannelExternalStorage platform;
    setUp(() => platform = MethodChannelExternalStorage(isAndroid: false));

    test('permission checks succeed without calling the native side', () async {
      bool? reported;
      platform.registerPermissionResultCallback((granted) => reported = granted);

      expect(await platform.checkStoragePermissions(), isTrue);
      expect(await platform.requestStoragePermissions(), isTrue);
      expect(reported, isTrue);
      expect(await platform.shouldShowRequestPermissionRationale(), isFalse);
      expect(await platform.checkPermission('android.permission.CAMERA'), isFalse);
      expect(await platform.getGrantedPermissions(), isEmpty);
      expect(log, isEmpty);
    });

    test('openAppSettings still opens the native settings page', () async {
      expect(await platform.openAppSettings(), isTrue);
      expect(log.single, isMethodCall('openAppSettings', arguments: null));
    });
  });
}
