import 'dart:io';

import 'package:external_storage/external_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('external_storage_path_'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('exists is true for directories as well as files', () async {
    final file = File(p.join(tmp.path, 'f.txt'))..writeAsStringSync('x');
    expect(await PathUtils.exists(tmp.path), isTrue);
    expect(await PathUtils.exists(file.path), isTrue);
    expect(PathUtils.existsSync(tmp.path), isTrue);
    expect(await PathUtils.exists(p.join(tmp.path, 'missing')), isFalse);
  });

  test('isAccessible accepts empty directories', () async {
    expect(await PathUtils.isAccessible(tmp.path), isTrue);
    expect(PathUtils.isAccessibleSync(tmp.path), isTrue);
    expect(await PathUtils.isAccessible(p.join(tmp.path, 'missing')), isFalse);
  });

  test('hasIllegalChars ignores separators and the root', () {
    expect(PathUtils.hasIllegalChars(p.join(tmp.path, 'dir', 'file.txt')), isFalse);
    expect(PathUtils.hasIllegalChars('/storage/emulated/0/Download'), isFalse);
    expect(PathUtils.hasIllegalChars(p.join(tmp.path, 'what?.txt')), isTrue);
    expect(PathUtils.hasIllegalChars(p.join(tmp.path, 'a<b>')), isTrue);
    expect(PathUtils.hasIllegalChars(p.join(tmp.path, 'tab\tname')), isTrue);
  });

  test('sanitizeFilename replaces illegal characters', () {
    expect(PathUtils.sanitizeFilename('a/b:c*d?.txt'), 'a_b_c_d_.txt');
    expect(PathUtils.sanitizeFilename('报告 2026.pdf'), '报告 2026.pdf');
  });

  test('isHidden checks the leading dot only', () {
    expect(PathUtils.isHidden('/sdcard/.nomedia'), isTrue);
    expect(PathUtils.isHidden('/sdcard/photo.jpg'), isFalse);
    expect(PathUtils.isHidden('.'), isFalse);
    expect(PathUtils.isHidden('..'), isFalse);
  });

  test('getReadableSize', () {
    expect(PathUtils.getReadableSize(512), '512.00 B');
    expect(PathUtils.getReadableSize(1536), '1.50 KB');
    expect(PathUtils.getReadableSize(5 * 1024 * 1024 * 1024), '5.00 GB');
  });
}
