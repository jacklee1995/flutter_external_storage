import 'package:flutter_test/flutter_test.dart';
import 'package:external_storage/external_storage.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockExternalStoragePlatform
    with MockPlatformInterfaceMixin
    implements ExternalStoragePlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final ExternalStoragePlatform initialPlatform =
      ExternalStoragePlatform.instance;

  test('$MethodChannelExternalStorage is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelExternalStorage>());
  });

  test('getPlatformVersion', () async {
    ExternalStorage externalStoragePlugin = ExternalStorage();
    MockExternalStoragePlatform fakePlatform = MockExternalStoragePlatform();
    ExternalStoragePlatform.instance = fakePlatform;

    expect(await externalStoragePlugin.getPlatformVersion(), '42');
  });
}
