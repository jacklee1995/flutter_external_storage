import 'package:external_storage/external_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class FakeExternalStoragePlatform extends ExternalStoragePlatform
    with MockPlatformInterfaceMixin {
  bool hasPermission = false;
  bool grantOnRequest = true;
  int requestCount = 0;

  @override
  Future<bool> checkStoragePermissions() async => hasPermission;

  @override
  Future<bool> requestStoragePermissions() async {
    requestCount++;
    hasPermission = grantOnRequest;
    return grantOnRequest;
  }

  (String, bool, List<WatchEventType>)? watchRequest;

  @override
  Stream<WatchEvent> watch(String path,
      {bool recursive = false, List<WatchEventType> events = const []}) {
    watchRequest = (path, recursive, events);
    return Stream.value(WatchEvent(
      type: WatchEventType.create,
      path: '$path/new.txt',
      watchedPath: path,
    ));
  }

  @override
  Future<List<StorageDevice>> getAllStorageDevices() async => [
        StorageDevice(
          path: '/storage/1A2B-3C4D',
          name: 'SD卡',
          isRemovable: true,
          totalSize: 100,
          availableSize: 40,
          isReadOnly: false,
          uuid: '1A2B-3C4D',
        ),
      ];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final initialPlatform = ExternalStoragePlatform.instance;

  test('MethodChannelExternalStorage is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelExternalStorage>());
  });

  group('ExternalStorage delegates to the platform', () {
    late FakeExternalStoragePlatform fake;
    late ExternalStorage storage;

    setUp(() {
      fake = FakeExternalStoragePlatform();
      ExternalStoragePlatform.instance = fake;
      storage = ExternalStorage();
    });

    tearDown(() => ExternalStoragePlatform.instance = initialPlatform);

    test('check then request permission', () async {
      expect(await storage.checkStoragePermissions(), isFalse);
      expect(await storage.requestStoragePermissions(), isTrue);
      expect(await storage.checkStoragePermissions(), isTrue);
      expect(fake.requestCount, 1);
    });

    test('denied request', () async {
      fake.grantOnRequest = false;
      expect(await storage.requestStoragePermissions(), isFalse);
    });

    test('storage devices expose uuid and usage', () async {
      final device = (await storage.getAllStorageDevices()).single;
      expect(device.uuid, '1A2B-3C4D');
      expect(device.usedSize, 60);
      expect(device.usagePercentage, 60);
    });

    test('watch forwards path, recursion and event filter', () async {
      final events = await storage
          .watch('/storage/1A2B-3C4D', recursive: true, events: [WatchEventType.create])
          .toList();
      expect(events.single.path, '/storage/1A2B-3C4D/new.txt');
      final (path, recursive, filter) = fake.watchRequest!;
      expect(path, '/storage/1A2B-3C4D');
      expect(recursive, isTrue);
      expect(filter, [WatchEventType.create]);
    });
  });

  group('WatchEventType masks', () {
    test('maskOf and fromMask round-trip', () {
      final events = [WatchEventType.create, WatchEventType.delete];
      final mask = WatchEventType.maskOf(events);
      expect(mask, 256 | 512);
      expect(WatchEventType.fromMask(mask), events);
      expect(WatchEventType.maskOf(const []), 0);
      expect(WatchEventType.fromMask(WatchEventType.allMask),
          WatchEventType.values);
    });
  });

  test('usagePercentage is 0 for an empty volume', () {
    final device = StorageDevice(
      path: '/x',
      name: 'x',
      isRemovable: false,
      totalSize: 0,
      availableSize: 0,
      isReadOnly: true,
    );
    expect(device.usagePercentage, 0);
  });
}
