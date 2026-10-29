import 'dart:convert';
import 'dart:io';

import 'package:external_storage/external_storage.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// 文件操作由 dart:io 实现，可以直接在 `flutter test` 中针对真实文件验证。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tmp;
  late MethodChannelExternalStorage storage;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('external_storage_file_');
    storage = MethodChannelExternalStorage(isAndroid: false);
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  String at(String relative) => p.join(tmp.path, relative);

  Matcher operationFailed(String method) => isA<PlatformException>()
      .having((e) => e.code, 'code', 'OPERATION_FAILED')
      .having((e) => e.message, 'message', startsWith('$method: '));

  group('read / write', () {
    test('round-trips UTF-8 content and creates parent directories', () async {
      final file = at('a/b/hello.txt');
      final data = Uint8List.fromList(utf8.encode('Hello, 世界'));

      expect(await storage.writeFile(file, data), data.length);
      expect(utf8.decode(await storage.readFile(file)), 'Hello, 世界');
    });

    test('append adds to the end', () async {
      final file = at('log.txt');
      await storage.writeFile(file, Uint8List.fromList([1, 2]));
      await storage.writeFile(file, Uint8List.fromList([3]), append: true);
      expect(await storage.readFile(file), [1, 2, 3]);
    });

    test('offset and length select a range', () async {
      final file = at('range.bin');
      await storage.writeFile(file, Uint8List.fromList([1, 2, 3, 4, 5]));

      expect(await storage.readFile(file, offset: 1, length: 2), [2, 3]);
      expect(await storage.readFile(file, offset: 3), [4, 5]);
      expect(await storage.readFile(file, offset: 4, length: 10), [5]);
      expect(await storage.readFile(file, offset: 10), isEmpty);
      expect(await storage.readFile(file, length: 0), isEmpty);
    });

    test('reading a missing file or a directory throws OPERATION_FAILED',
        () async {
      await expectLater(
          storage.readFile(at('missing.txt')), throwsA(operationFailed('readFile')));
      await expectLater(
          storage.readFile(tmp.path), throwsA(operationFailed('readFile')));
    });

    test('writing to a directory path throws OPERATION_FAILED', () async {
      await expectLater(storage.writeFile(tmp.path, Uint8List(1)),
          throwsA(operationFailed('writeFile')));
    });
  });

  group('copy / move / delete', () {
    test('copyFile copies and overwrites an existing target', () async {
      File(at('src.txt')).writeAsStringSync('new');
      File(at('dst.txt')).writeAsStringSync('old content');

      expect(await storage.copyFile(at('src.txt'), at('dst.txt')), isTrue);
      expect(File(at('dst.txt')).readAsStringSync(), 'new');
      expect(File(at('src.txt')).existsSync(), isTrue);
    });

    test('copyFile onto itself fails without losing data', () async {
      File(at('same.txt')).writeAsStringSync('keep me');
      expect(await storage.copyFile(at('same.txt'), at('same.txt')), isFalse);
      expect(File(at('same.txt')).readAsStringSync(), 'keep me');
    });

    test('copyFile / moveFile / deleteFile return false for a missing source',
        () async {
      expect(await storage.copyFile(at('nope'), at('x')), isFalse);
      expect(await storage.moveFile(at('nope'), at('x')), isFalse);
      expect(await storage.deleteFile(at('nope')), isFalse);
    });

    test('moveFile moves into a new directory', () async {
      File(at('m.txt')).writeAsStringSync('m');
      expect(await storage.moveFile(at('m.txt'), at('sub/dir/m.txt')), isTrue);
      expect(File(at('m.txt')).existsSync(), isFalse);
      expect(File(at('sub/dir/m.txt')).readAsStringSync(), 'm');
    });

    test('deleteFile refuses directories', () async {
      Directory(at('dir')).createSync();
      expect(await storage.deleteFile(at('dir')), isFalse);
      expect(Directory(at('dir')).existsSync(), isTrue);
    });
  });

  group('file metadata', () {
    test('getFileInfo describes files and directories', () async {
      File(at('info.txt')).writeAsStringSync('12345');
      final info = await storage.getFileInfo(at('info.txt'));

      expect(info.name, 'info.txt');
      expect(info.path, p.normalize(p.absolute(at('info.txt'))));
      expect(info.size, 5);
      expect(info.isFile, isTrue);
      expect(info.isDirectory, isFalse);
      expect(info.canRead, isTrue);
      expect(info.canWrite, isTrue);
      expect(info.isHidden, isFalse);
      expect(DateTime.now().difference(info.lastModified).inMinutes, lessThan(5));

      final dirInfo = await storage.getFileInfo(tmp.path);
      expect(dirInfo.isDirectory, isTrue);
      expect(dirInfo.isFile, isFalse);
    });

    test('getFileInfo marks dot files as hidden and throws for missing paths',
        () async {
      File(at('.hidden')).writeAsStringSync('');
      expect((await storage.getFileInfo(at('.hidden'))).isHidden, isTrue);
      await expectLater(storage.getFileInfo(at('missing')),
          throwsA(operationFailed('getFileInfo')));
    });

    test('calculateMD5 matches known digests', () async {
      File(at('hello.txt')).writeAsStringSync('hello');
      File(at('empty.txt')).writeAsStringSync('');

      expect(await storage.calculateMD5(at('hello.txt')),
          '5d41402abc4b2a76b9719d911017c592');
      expect(await storage.calculateMD5(at('empty.txt')),
          'd41d8cd98f00b204e9800998ecf8427e');
      await expectLater(storage.calculateMD5(at('missing')),
          throwsA(operationFailed('calculateMD5')));
    });

    test('createFile creates parents and refuses existing paths', () async {
      expect(await storage.createFile(at('new/dir/file.txt')), isTrue);
      expect(File(at('new/dir/file.txt')).lengthSync(), 0);
      expect(await storage.createFile(at('new/dir/file.txt')), isFalse);
      expect(await storage.createFile(at('new')), isFalse);
    });

    test('fileExists is true for files and directories', () async {
      File(at('f.txt')).writeAsStringSync('');
      expect(await storage.fileExists(at('f.txt')), isTrue);
      expect(await storage.fileExists(tmp.path), isTrue);
      expect(await storage.fileExists(at('missing')), isFalse);
    });

    test('getMimeType uses magic numbers first, then the extension', () async {
      const pngHeader = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0, 0, 0, 0];
      File(at('picture.bin')).writeAsBytesSync(pngHeader);
      File(at('notes.txt')).writeAsStringSync('plain text');
      File(at('data.unknownext')).writeAsStringSync('???');

      expect(await storage.getMimeType(at('picture.bin')), 'image/png');
      expect(await storage.getMimeType(at('notes.txt')), 'text/plain');
      expect(await storage.getMimeType(at('data.unknownext')), isNull);
      await expectLater(storage.getMimeType(at('missing.png')),
          throwsA(operationFailed('getMimeType')));
    });

    test('truncateFile shrinks and extends', () async {
      File(at('t.bin')).writeAsBytesSync([1, 2, 3, 4]);
      expect(await storage.truncateFile(at('t.bin'), 2), isTrue);
      expect(File(at('t.bin')).readAsBytesSync(), [1, 2]);
      expect(await storage.truncateFile(at('t.bin'), 4), isTrue);
      expect(File(at('t.bin')).readAsBytesSync(), [1, 2, 0, 0]);
      expect(await storage.truncateFile(at('missing'), 0), isFalse);
    });
  });
}
