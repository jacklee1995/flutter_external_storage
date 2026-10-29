import 'dart:ffi';
import 'dart:io' as io;

import 'package:ffi/ffi.dart';

typedef _AccessNative = Int32 Function(Pointer<Utf8> path, Int32 mode);
typedef _AccessDart = int Function(Pointer<Utf8> path, int mode);

const int _readOk = 4;
const int _writeOk = 2;
const int _executeOk = 1;

/// 当前进程对某路径的读 / 写 / 执行能力。
typedef AccessFlags = ({bool read, bool write, bool execute});

// Android 11+ 的共享存储由 FUSE 提供，mode 位反映不了 App 的真实访问能力，
// 所以和 java.io.File.canRead() 一样调用 access(2)。
final _AccessDart? _access = _lookupAccess();

_AccessDart? _lookupAccess() {
  if (io.Platform.isWindows) return null;
  try {
    final libc = io.Platform.isAndroid
        ? DynamicLibrary.open('libc.so')
        : DynamicLibrary.process();
    return libc.lookupFunction<_AccessNative, _AccessDart>('access');
  } on Object {
    return null;
  }
}

AccessFlags accessFlags(String path, int mode) {
  final access = _access;
  if (access == null) {
    return (
      read: (mode & 0x100) != 0,
      write: (mode & 0x80) != 0,
      execute: (mode & 0x40) != 0,
    );
  }
  final nativePath = path.toNativeUtf8();
  try {
    return (
      read: access(nativePath, _readOk) == 0,
      write: access(nativePath, _writeOk) == 0,
      execute: access(nativePath, _executeOk) == 0,
    );
  } finally {
    malloc.free(nativePath);
  }
}
