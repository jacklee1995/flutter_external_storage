# Changelog

All notable changes to the `external_storage` plugin will be documented in this file.
本文档记录了 `external_storage` 插件的所有重要更新。

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-10-29

### Added

- **iOS support** (iOS 13+, CocoaPods and Swift Package Manager, privacy manifest included):
  storage volume information (the app's Documents directory and its capacity), `openAppSettings`,
  every file and directory operation, and file watching. iOS has no storage permission, so the
  permission checks return `true`. 新增 iOS 支持。
- `watch()` returns a `Stream<WatchEvent>`: watching starts on listen and stops on cancel, several
  watches can run at once, and the stream ends when the watched path is deleted or moved.
  `WatchEvent` gained `watchedPath` and `isDirectory`. 新增基于 Stream 的 `watch()`。
- `WatchEventType.maskOf`, `WatchEventType.fromMask` and `WatchEventType.allMask`.
- Native permission handling (Android 11+: All files access settings page; Android 6–10: runtime
  permissions). 原生权限处理。
- `StorageDevice.uuid`, `StorageDevice.description` and `StorageDevice.isPrimary`.
- Methods returning data (`readFile`, `getFileInfo`, `calculateMD5`, …) throw a
  `PlatformException` (`OPERATION_FAILED`) with the error message instead of a type error.

### Changed

- File and directory operations are implemented with `dart:io` and shared by Android and iOS
  instead of going through Kotlin. File contents no longer cross the platform channel, operations run
  concurrently, recursive listings / MD5 / directory sizes run in a background isolate, and the
  operations work in a plain `flutter test`. 文件和目录操作改用 `dart:io` 实现，两个平台共用。
- Events from `startWatching` now report the full path of the changed entry instead of the watched
  directory. 监视事件现在给出发生变化的文件的完整路径。
- `getMimeType` checks the file header (magic numbers) before the extension.
- `FileInfo.canRead` / `canWrite` / `canExecute` use `access(2)`, like `java.io.File`.
- `moveDirectory` falls back to copy + delete when moving across volumes (e.g. to an SD card).
- `StorageDevice.name` uses the system's localized volume label when available; `isReadOnly`
  reflects whether the volume is mounted read-only rather than whether the app may write to it.
- `readFile(length: 0)` returns no data (it used to read to the end of the file).
- `getDirectorySize` no longer follows symbolic links.
- `FileMode` is deprecated: no API uses it and it clashes with `dart:io`'s `FileMode`.
- A pending permission request survives the Activity being recreated by a configuration change.
- **The plugin no longer declares `MANAGE_EXTERNAL_STORAGE`** (nor `READ_MEDIA_*`); apps that need
  Android 11+ full access must declare it themselves (see README). 插件不再替宿主声明
  `MANAGE_EXTERNAL_STORAGE`，需在 App 中自行声明。
- Android: AGP 9.1, Kotlin 2.4, compileSdk 36, Java 17. Dart: SDK ^3.8.0, Flutter >= 3.32.
  New dependencies: `crypto`, `mime`, `ffi`.
- Removed duplicate internal Dart files (public API unchanged).

### Fixed

- `checkStoragePermissions`, `requestStoragePermissions`, `shouldShowRequestPermissionRationale`,
  `openAppSettings`, `checkPermission`, `getGrantedPermissions`, `stopAllWatching`,
  `getWatchedPaths` and `isWatching` threw `MissingPluginException` because they had no native
  implementation. 以上方法此前没有原生实现，调用即抛出 `MissingPluginException`，现已全部实现。
- `startWatching` / `stopWatching` / `stopAllWatching` returned an empty result (the native side
  filled it in asynchronously); `startWatching` with no `events` now watches all events instead of none.
- Watching: a single file never produced events; directories moved into a recursively watched tree
  were not watched; two watches on the same directory stopped each other (Android shares one inotify
  descriptor per inode); combined inotify flags could make `WatchEventType.fromValue` throw.
- `getAllStorageDevices` crashed on Android 7–10 (`StorageVolume.directory` is API 30+).
- `readFile` crashed on empty files / offsets past EOF and could return partial data.
- Integer arguments (`offset`, `length`, `size`) could throw `ClassCastException` on the native side.
- `listDirectory(recursive: true)` ignored `recursive`.
- `getMimeType` always returned an empty string.
- `copyFile` onto the same file truncated it; `copyDirectory` / `moveDirectory` into a subdirectory
  of the source recursed until the disk was full; symbolic link cycles could recurse forever.
- `PathUtils.exists` returned `false` for directories, `PathUtils.isAccessible` returned `false` for
  empty directories, and `PathUtils.hasIllegalChars` treated every path separator as illegal.

## [0.0.1] - 2024-12-03

### Added

- 首次发布核心功能：
  - 存储设备管理（列出设备、获取存储信息）
  - 文件操作（读取、写入、复制、移动、删除）
  - 目录操作（列表、创建、删除、信息）
  - 文件系统监视（监控目录变化）
  - 权限管理（请求和检查存储权限）
  - 路径工具（规范化、连接、分割路径）
- 完整的数据模型：
  - `StorageDevice` 存储设备信息
  - `FileInfo` 文件元数据
  - `DirectoryInfo` 目录详情
  - `WatchEvent` 文件系统事件
- Android 平台接口实现
- 原生通信的方法通道实现
- 空安全支持
- 文档和示例代码
