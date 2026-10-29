import 'dart:async';
import 'dart:io' as io;
import 'dart:isolate';

import '../enums/watch_event_type.dart';
import '../models/watch_event.dart';

/// 轮询实现的文件监视，用于没有原生监视的平台（iOS 上 dart:io 不支持 watch）。
///
/// 每隔 [interval] 对比一次快照，产生 create / modify / delete 事件；
/// 根路径被删除时产生 deleteSelf 并结束（调用 [onDone]）。
/// 重命名会表现为 delete + create。
class PollingWatcher {
  PollingWatcher(
    this.root, {
    required this.recursive,
    required this.mask,
    required this.interval,
    required this.onEvent,
    required this.onDone,
  });

  final String root;
  final bool recursive;
  final int mask;
  final Duration interval;
  final void Function(WatchEvent event) onEvent;
  final void Function() onDone;

  Map<String, _Entry> _last = const {};
  Timer? _timer;
  bool _cancelled = false;

  /// 根路径不存在时抛出 [io.FileSystemException]。
  Future<void> start() async {
    final snapshot = await _snapshot(root, recursive);
    if (snapshot == null) {
      throw io.FileSystemException('Path does not exist', root);
    }
    _last = snapshot;
    _schedule();
  }

  /// 停止监视，不会调用 [onDone]。
  void cancel() {
    _cancelled = true;
    _timer?.cancel();
  }

  void _schedule() {
    if (!_cancelled) _timer = Timer(interval, _poll);
  }

  Future<void> _poll() async {
    final Map<String, _Entry>? current;
    try {
      current = await _snapshot(root, recursive);
    } catch (_) {
      _schedule();
      return;
    }
    if (_cancelled) return;
    if (current == null) {
      _emit(WatchEventType.deleteSelf, root, _last[root]?.isDirectory ?? true);
      cancel();
      onDone();
      return;
    }
    _diff(_last, current);
    _last = current;
    _schedule();
  }

  void _diff(Map<String, _Entry> before, Map<String, _Entry> after) {
    after.forEach((path, entry) {
      final old = before[path];
      if (old == null) {
        _emit(WatchEventType.create, path, entry.isDirectory);
      } else if (old.isDirectory != entry.isDirectory) {
        _emit(WatchEventType.delete, path, old.isDirectory);
        _emit(WatchEventType.create, path, entry.isDirectory);
      } else if (!entry.isDirectory &&
          (old.size != entry.size || old.modified != entry.modified)) {
        _emit(WatchEventType.modify, path, false);
      }
    });
    before.forEach((path, entry) {
      if (!after.containsKey(path)) {
        _emit(WatchEventType.delete, path, entry.isDirectory);
      }
    });
  }

  void _emit(WatchEventType type, String path, bool isDirectory) {
    if (_cancelled || (mask & type.value) == 0) return;
    onEvent(WatchEvent(
      type: type,
      path: path,
      watchedPath: root,
      isDirectory: isDirectory,
    ));
  }
}

class _Entry {
  const _Entry(this.isDirectory, this.size, this.modified);

  _Entry.of(io.FileStat stat)
      : this(stat.type == io.FileSystemEntityType.directory, stat.size,
            stat.modified.microsecondsSinceEpoch);

  final bool isDirectory;
  final int size;
  final int modified;
}

Future<Map<String, _Entry>?> _snapshot(String root, bool recursive) =>
    Isolate.run(() => _snapshotSync(root, recursive));

/// 根路径不存在时返回 null。不跟随符号链接进入子目录，避免循环。
Map<String, _Entry>? _snapshotSync(String root, bool recursive) {
  final rootStat = io.FileStat.statSync(root);
  if (rootStat.type == io.FileSystemEntityType.notFound) return null;
  final entries = <String, _Entry>{root: _Entry.of(rootStat)};
  if (rootStat.type != io.FileSystemEntityType.directory) return entries;

  void walk(String dir) {
    final List<io.FileSystemEntity> children;
    try {
      children = io.Directory(dir).listSync(followLinks: false);
    } on io.FileSystemException {
      return;
    }
    for (final child in children) {
      final stat = io.FileStat.statSync(child.path);
      if (stat.type == io.FileSystemEntityType.notFound) continue;
      entries[child.path] = _Entry.of(stat);
      if (recursive && child is io.Directory) walk(child.path);
    }
  }

  walk(root);
  return entries;
}
