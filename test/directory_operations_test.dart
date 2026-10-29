import 'dart:io';

import 'package:external_storage/external_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('tech.thispage.external_storage');

  late Directory tmp;
  late MethodChannelExternalStorage storage;

  String at(String relative) => p.join(tmp.path, relative);

  /// root/
  ///   a.txt (3 bytes)
  ///   sub/
  ///     b.txt (5 bytes)
  ///     deeper/
  ///       c.txt (7 bytes)
  void createTree(String root) {
    File(p.join(root, 'a.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('aaa');
    File(p.join(root, 'sub', 'b.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('bbbbb');
    File(p.join(root, 'sub', 'deeper', 'c.txt'))
      ..createSync(recursive: true)
      ..writeAsStringSync('ccccccc');
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('external_storage_dir_');
    storage = MethodChannelExternalStorage(isAndroid: false);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    tmp.deleteSync(recursive: true);
  });

  group('listDirectory', () {
    test('lists direct children', () async {
      createTree(at('root'));
      final entries = await storage.listDirectory(at('root'));
      expect(entries.map((e) => e.name), unorderedEquals(['a.txt', 'sub']));
      final sub = entries.singleWhere((e) => e.name == 'sub');
      expect(sub.isDirectory, isTrue);
      expect(sub.path, p.join(p.normalize(p.absolute(at('root'))), 'sub'));
    });

    test('recursive listing includes nested entries', () async {
      createTree(at('root'));
      final entries = await storage.listDirectory(at('root'), recursive: true);
      expect(
        entries.map((e) => p.relative(e.path, from: at('root'))),
        unorderedEquals([
          'a.txt',
          'sub',
          p.join('sub', 'b.txt'),
          p.join('sub', 'deeper'),
          p.join('sub', 'deeper', 'c.txt'),
        ]),
      );
      final c = entries.singleWhere((e) => e.name == 'c.txt');
      expect(c.size, 7);
      expect(c.isFile, isTrue);
    });

    test('returns an empty list for missing paths and files', () async {
      File(at('file.txt')).writeAsStringSync('x');
      expect(await storage.listDirectory(at('missing')), isEmpty);
      expect(await storage.listDirectory(at('file.txt')), isEmpty);
    });
  });

  group('create / delete', () {
    test('createDirectory honours recursive and refuses existing paths',
        () async {
      expect(await storage.createDirectory(at('x/y')), isFalse);
      expect(await storage.createDirectory(at('x/y'), recursive: true), isTrue);
      expect(Directory(at('x/y')).existsSync(), isTrue);
      expect(await storage.createDirectory(at('x/y'), recursive: true), isFalse);
    });

    test('deleteDirectory needs recursive for non-empty directories', () async {
      createTree(at('root'));
      expect(await storage.deleteDirectory(at('root')), isFalse);
      expect(Directory(at('root')).existsSync(), isTrue);
      expect(await storage.deleteDirectory(at('root'), recursive: true), isTrue);
      expect(Directory(at('root')).existsSync(), isFalse);
    });

    test('deleteDirectory refuses files and missing paths', () async {
      File(at('file.txt')).writeAsStringSync('x');
      expect(await storage.deleteDirectory(at('file.txt'), recursive: true),
          isFalse);
      expect(File(at('file.txt')).existsSync(), isTrue);
      expect(await storage.deleteDirectory(at('missing')), isFalse);
    });
  });

  group('move / copy', () {
    test('moveDirectory moves the whole tree', () async {
      createTree(at('root'));
      expect(await storage.moveDirectory(at('root'), at('moved/root')), isTrue);
      expect(Directory(at('root')).existsSync(), isFalse);
      expect(File(at('moved/root/sub/deeper/c.txt')).readAsStringSync(),
          'ccccccc');
    });

    test('copyDirectory copies the whole tree and keeps the source', () async {
      createTree(at('root'));
      expect(await storage.copyDirectory(at('root'), at('copy')), isTrue);
      expect(File(at('copy/sub/b.txt')).readAsStringSync(), 'bbbbb');
      expect(File(at('root/sub/b.txt')).existsSync(), isTrue);
    });

    test('move and copy refuse existing targets', () async {
      createTree(at('root'));
      Directory(at('target')).createSync();
      expect(await storage.moveDirectory(at('root'), at('target')), isFalse);
      expect(await storage.copyDirectory(at('root'), at('target')), isFalse);
      expect(Directory(at('target')).listSync(), isEmpty);
    });

    test('move and copy refuse a target inside the source', () async {
      createTree(at('root'));
      expect(await storage.moveDirectory(at('root'), at('root/sub/inner')),
          isFalse);
      expect(await storage.copyDirectory(at('root'), at('root/inner')), isFalse);
      expect(Directory(at('root/inner')).existsSync(), isFalse);
      expect(File(at('root/a.txt')).existsSync(), isTrue);
    });

    test('move and copy return false for a missing source', () async {
      expect(await storage.moveDirectory(at('missing'), at('a')), isFalse);
      expect(await storage.copyDirectory(at('missing'), at('b')), isFalse);
    });
  });

  group('directory metadata', () {
    test('getDirectoryInfo counts children and reports volume space', () async {
      createTree(at('root'));
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getStorageSpace');
        return {'totalSpace': 1000, 'freeSpace': 400, 'usableSpace': 300};
      });

      final info = await storage.getDirectoryInfo(at('root'));
      expect(info.name, 'root');
      expect(info.path, p.normalize(p.absolute(at('root'))));
      expect(info.parent, p.normalize(p.absolute(tmp.path)));
      expect(info.fileCount, 1);
      expect(info.directoryCount, 1);
      expect(info.totalSpace, 1000);
      expect(info.freeSpace, 400);
      expect(info.usableSpace, 300);
      expect(info.canRead, isTrue);
    });

    test('getDirectoryInfo reports zero space without a native side', () async {
      final info = await storage.getDirectoryInfo(tmp.path);
      expect(info.totalSpace, 0);
      expect(info.fileCount, 0);
    });

    test('getDirectoryInfo throws for files', () async {
      File(at('file.txt')).writeAsStringSync('x');
      await expectLater(
        storage.getDirectoryInfo(at('file.txt')),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', 'OPERATION_FAILED')),
      );
    });

    test('isDirectoryEmpty, getDirectorySize and directoryExists', () async {
      createTree(at('root'));
      Directory(at('empty')).createSync();
      File(at('file.txt')).writeAsStringSync('x');

      expect(await storage.isDirectoryEmpty(at('empty')), isTrue);
      expect(await storage.isDirectoryEmpty(at('root')), isFalse);
      expect(await storage.getDirectorySize(at('root')), 3 + 5 + 7);
      expect(await storage.getDirectorySize(at('empty')), 0);
      expect(await storage.directoryExists(at('root')), isTrue);
      expect(await storage.directoryExists(at('file.txt')), isFalse);
      expect(await storage.directoryExists(at('missing')), isFalse);
      await expectLater(storage.isDirectoryEmpty(at('missing')),
          throwsA(isA<PlatformException>()));
      await expectLater(storage.getDirectorySize(at('file.txt')),
          throwsA(isA<PlatformException>()));
    });
  });
}
