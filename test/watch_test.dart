import 'dart:async';
import 'dart:io';

import 'package:external_storage/external_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

Future<void> eventually(bool Function() condition,
    {Duration timeout = const Duration(seconds: 10)}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) fail('Timed out waiting for events');
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}

/// 订阅后监视异步启动（先拍一张快照），之后的变化才会产生事件。
Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 400));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('polling watcher (platforms without native watching, e.g. iOS)', () {
    late Directory tmp;
    late String root;
    late MethodChannelExternalStorage storage;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('external_storage_watch_');
      root = p.normalize(p.absolute(tmp.path));
      storage = MethodChannelExternalStorage(
        isAndroid: false,
        pollingInterval: const Duration(milliseconds: 50),
      );
    });

    tearDown(() async {
      await storage.stopAllWatching();
      if (tmp.existsSync()) tmp.deleteSync(recursive: true);
    });

    test('reports create, modify and delete with the full path', () async {
      final events = <WatchEvent>[];
      final subscription = storage.watch(root).listen(events.add);
      await settle();

      final file = File(p.join(root, 'a.txt'))..writeAsStringSync('1');
      await eventually(() => events.any((e) => e.type == WatchEventType.create));
      file.writeAsStringSync('22');
      await eventually(() => events.any((e) => e.type == WatchEventType.modify));
      file.deleteSync();
      await eventually(() => events.any((e) => e.type == WatchEventType.delete));
      await subscription.cancel();

      expect(
        events.firstWhere((e) => e.type == WatchEventType.create),
        WatchEvent(
          type: WatchEventType.create,
          path: file.path,
          watchedPath: root,
          isDirectory: false,
        ),
      );
      expect(await storage.getWatchedPaths(), isEmpty);
    });

    test('only recursive watches see nested changes', () async {
      Directory(p.join(root, 'sub')).createSync();
      final flat = <WatchEvent>[];
      final deep = <WatchEvent>[];
      final s1 = storage.watch(root).listen(flat.add);
      final s2 = storage.watch(root, recursive: true).listen(deep.add);
      await settle();

      File(p.join(root, 'sub', 'nested.txt')).writeAsStringSync('x');
      await eventually(() => deep.any((e) => e.path.endsWith('nested.txt')));
      await settle();
      expect(flat, isEmpty);
      await s1.cancel();
      await s2.cancel();
    });

    test('filters events by type', () async {
      final events = <WatchEvent>[];
      final subscription =
          storage.watch(root, events: [WatchEventType.delete]).listen(events.add);
      await settle();

      final file = File(p.join(root, 'b.txt'))..writeAsStringSync('x');
      await settle();
      file.deleteSync();
      await eventually(() => events.isNotEmpty);
      expect(events.map((e) => e.type), everyElement(WatchEventType.delete));
      await subscription.cancel();
    });

    test('deleting the watched directory ends the stream with deleteSelf',
        () async {
      final dir = Directory(p.join(root, 'watched'))..createSync();
      final events = <WatchEvent>[];
      final done = Completer<void>();
      storage.watch(dir.path).listen(events.add, onDone: done.complete);
      await settle();

      dir.deleteSync(recursive: true);
      await done.future.timeout(const Duration(seconds: 10));
      expect(events.last.type, WatchEventType.deleteSelf);
      expect(events.last.isDirectory, isTrue);
      expect(await storage.isWatching(dir.path), isFalse);
    });

    test('watching a missing path emits an error and closes', () async {
      final error = Completer<Object>();
      final done = Completer<void>();
      storage
          .watch(p.join(root, 'missing'))
          .listen((_) {}, onError: error.complete, onDone: done.complete);

      expect(
        await error.future,
        isA<PlatformException>().having((e) => e.code, 'code', 'OPERATION_FAILED'),
      );
      await done.future;
    });

    test('stopAllWatching ends active streams', () async {
      final done = Completer<void>();
      storage.watch(root).listen((_) {}, onDone: done.complete);
      await settle();
      expect(await storage.getWatchedPaths(), [root]);

      expect(await storage.stopAllWatching(), isTrue);
      await done.future.timeout(const Duration(seconds: 5));
      expect(await storage.getWatchedPaths(), isEmpty);
    });

    test('legacy startWatching delivers to the registered callback', () async {
      final received = <(String, WatchEventType)>[];
      storage.registerWatchEventCallback((path, type) => received.add((path, type)));

      expect(await storage.startWatching(tmp.path), isTrue);
      expect(await storage.isWatching(tmp.path), isTrue);
      final file = File(p.join(root, 'legacy.txt'))..writeAsStringSync('x');
      await eventually(() => received.isNotEmpty);
      expect(received.first, (file.path, WatchEventType.create));

      expect(await storage.stopWatching(tmp.path), isTrue);
      expect(await storage.isWatching(tmp.path), isFalse);
      expect(await storage.stopWatching(tmp.path), isFalse);
      expect(await storage.startWatching(p.join(root, 'missing')), isFalse);
      storage.unregisterWatchEventCallback();
    });
  });

  group('Android native watcher', () {
    const channel = MethodChannel('tech.thispage.external_storage');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    final log = <MethodCall>[];
    final root = p.normalize(p.absolute('/data/watched'));
    Map<String, Object?> startResult = {'success': true};

    Future<void> fromNative(String method, Map<String, Object?> arguments) =>
        messenger.handlePlatformMessage(
          channel.name,
          const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
          (_) {},
        );

    Future<void> flush() => Future<void>.delayed(Duration.zero);

    setUp(() {
      startResult = {'success': true};
      messenger.setMockMethodCallHandler(channel, (call) async {
        log.add(call);
        return switch (call.method) {
          'startWatching' => startResult,
          'getWatchedPaths' => {'success': true, 'paths': [root]},
          'isWatching' => {'success': true, 'watching': true},
          _ => {'success': true},
        };
      });
    });

    tearDown(() {
      log.clear();
      messenger.setMockMethodCallHandler(channel, null);
    });

    test('watch() uses its own id and receives the native events', () async {
      final storage = MethodChannelExternalStorage(isAndroid: true);
      final events = <WatchEvent>[];
      final done = Completer<void>();
      storage
          .watch(root, recursive: true, events: [WatchEventType.create])
          .listen(events.add, onDone: done.complete);
      await flush();

      final start = log.single;
      final id = (start.arguments as Map)['watchId'] as String;
      expect(start, isMethodCall('startWatching', arguments: {
        'watchId': id,
        'path': root,
        'recursive': true,
        'eventMask': WatchEventType.create.value,
      }));

      await fromNative('onFileSystemEvent', {
        'watchId': id,
        'watchedPath': root,
        'path': p.join(root, 'new'),
        'eventType': WatchEventType.create.value,
        'isDirectory': true,
      });
      await flush();
      expect(events.single, WatchEvent(
        type: WatchEventType.create,
        path: p.join(root, 'new'),
        watchedPath: root,
        isDirectory: true,
      ));

      await fromNative('onWatchDone', {'watchId': id});
      await done.future;
      expect(log.where((c) => c.method == 'stopWatching'), isEmpty);
    });

    test('cancelling the subscription stops the native watch', () async {
      final storage = MethodChannelExternalStorage(isAndroid: true);
      final subscription = storage.watch(root).listen((_) {});
      await flush();
      final id = (log.single.arguments as Map)['watchId'];

      await subscription.cancel();
      expect(log.last, isMethodCall('stopWatching', arguments: {'watchId': id}));
    });

    test('a native start failure becomes a stream error', () async {
      startResult = {'success': false, 'error': 'Path does not exist: /x'};
      final storage = MethodChannelExternalStorage(isAndroid: true);
      final error = Completer<Object>();
      storage.watch(root).listen((_) {}, onError: error.complete);

      expect(
        await error.future,
        isA<PlatformException>()
            .having((e) => e.code, 'code', 'OPERATION_FAILED')
            .having((e) => e.message, 'message', contains('Path does not exist')),
      );
    });

    test('startWatching events reach the legacy callback', () async {
      final storage = MethodChannelExternalStorage(isAndroid: true);
      String? path;
      WatchEventType? type;
      storage.registerWatchEventCallback((p0, t) {
        path = p0;
        type = t;
      });

      expect(await storage.startWatching(root), isTrue);
      expect(log.single, isMethodCall('startWatching', arguments: {
        'watchId': root,
        'path': root,
        'recursive': false,
        'eventMask': 0,
      }));

      await fromNative('onFileSystemEvent', {
        'watchId': root,
        'path': p.join(root, 'a.txt'),
        'eventType': WatchEventType.delete.value,
      });
      expect(path, p.join(root, 'a.txt'));
      expect(type, WatchEventType.delete);

      // 旧版原生端发送的事件没有 watchId。
      await fromNative('onFileSystemEvent', {'path': '/x', 'eventType': 256});
      expect(type, WatchEventType.create);

      expect(await storage.stopWatching(root), isTrue);
      expect(log.last, isMethodCall('stopWatching', arguments: {'watchId': root}));
    });

    test('watch queries are answered by the native side', () async {
      final storage = MethodChannelExternalStorage(isAndroid: true);
      expect(await storage.getWatchedPaths(), [root]);
      expect(await storage.isWatching(root), isTrue);
      expect(log.last, isMethodCall('isWatching', arguments: {'path': root}));
      expect(await storage.stopAllWatching(), isTrue);
    });
  });
}
