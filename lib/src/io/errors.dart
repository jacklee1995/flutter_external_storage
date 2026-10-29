import 'dart:io' as io;

import 'package:flutter/services.dart' show PlatformException;

/// 所有失败操作统一使用的错误码（无论失败发生在原生端还是 Dart 端）。
const String operationFailedCode = 'OPERATION_FAILED';

/// 把任意错误转换为 `PlatformException(code: OPERATION_FAILED)`，消息形如 `readFile: <原因>`。
PlatformException operationFailed(String method, Object error) {
  if (error is PlatformException) return error;
  return PlatformException(
    code: operationFailedCode,
    message: '$method: ${describeError(error)}',
    details: error is io.FileSystemException ? error.osError?.errorCode : null,
  );
}

String describeError(Object error) => switch (error) {
      io.FileSystemException(:final osError?, :final path?) =>
        '${osError.message} ($path)',
      io.FileSystemException(:final osError?) => osError.message,
      io.FileSystemException(:final message, :final path?) => '$message ($path)',
      io.FileSystemException(:final message) => message,
      _ => '$error',
    };
