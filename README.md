# external_storage

![alt text](https://raw.githubusercontent.com/jacklee1995/flutter_external_storage/refs/heads/master/flutter_external_storage.png)

- Author: Li Juncai (jcLee95)
- [![jcLee95](https://raw.githubusercontent.com/jacklee1995/flutter_external_storage/refs/heads/master/jclee95_64x64.ico)](https://jclee95.blog.csdn.net)
- Email: [291148484@163.com](291148484@163.com)
- Description: A Flutter storage plugin for Android and iOS: storage volumes (including SD card / USB drive UUIDs), file and directory operations, file system watching and storage permission handling.
- License: [LICENSE](https://github.com/jacklee1995/flutter_external_storage/blob/master/LICENSE)
- 中文版：[README_CN.md](https://github.com/jacklee1995/flutter_external_storage/blob/master/README_CN.md)

## Introduction

External Storage is a powerful and easy-to-use Flutter plugin designed for cross-platform file and storage management. The library provides a comprehensive set of APIs for handling file and directory operations on external storage devices, supporting various file system interaction scenarios.

### Feature Highlights

- 📱 Multi-storage device management
- 📂 Complete file and directory operations
- 👀 Real-time file system monitoring
- 🔒 Comprehensive permission management
- 🛠 Rich file utility methods
- ⚡ High-performance file operations
- 🎯 Type-safe API

### Platform support

| | Android | iOS |
| --- | --- | --- |
| Minimum version | Android 5.0 (API 21) | iOS 13 |
| `getAllStorageDevices()` | Internal storage, SD cards, USB OTG drives (with UUID) | The app's data volume; `path` is the app's Documents directory |
| File and directory operations | Yes | Yes (inside the app sandbox) |
| `watch()` / `startWatching()` | inotify: every `WatchEventType`, recursive | Polling (1 s): `create`, `modify`, `delete`, `deleteSelf` |
| Storage permissions | Runtime permissions / All files access | Not needed, always granted |

File and directory operations are implemented with `dart:io`, so both platforms share one
implementation. They run on Dart's I/O threads (large listings, MD5 and directory sizes in a background
isolate) and never pass file contents through a platform channel. Only storage volume information,
permissions and Android's inotify watcher are native.

## Installation

Add the following dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  external_storage: ^latest_version
```

Then execute the Flutter package retrieval command:

```bash
flutter pub get
```

Or directly install the latest version using the add command:

```sh
flutter pub add external_storage
```

## Configuration

Requirements: Flutter 3.32+ / Dart 3.8+.

### Android

The plugin already merges `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE` for Android 10 and below.
On Android 11+ (API 30+), accessing the whole external storage (including SD cards and USB drives)
requires *All files access*. **Because Google Play restricts this permission, the plugin does not
declare it for you; add it to your app's `android/app/src/main/AndroidManifest.xml`:**

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission
        android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
        tools:ignore="ScopedStorage" />
    ...
</manifest>
```

If it is missing, `requestStoragePermissions()` throws a `PlatformException` with code `PERMISSION_NOT_DECLARED`.

| Android version | `checkStoragePermissions()` checks | `requestStoragePermissions()` does |
| --- | --- | --- |
| 11+ (API 30+) | `MANAGE_EXTERNAL_STORAGE` | Opens the system *All files access* page; resolves when the user returns |
| 6 – 10 (API 23–29) | `READ/WRITE_EXTERNAL_STORAGE` | Shows the runtime permission dialog |
| 5.x (API 21–22) | granted at install time | Returns `true` |

### iOS

No configuration or permission is needed: an iOS app can always read and write its own sandbox, so
`checkStoragePermissions()` and `requestStoragePermissions()` return `true`.

`getAllStorageDevices()` returns one device for the app's data volume. Its `path` is the app's
Documents directory, which is the place for user-visible files. To make those files show up in the
Files app (*On My iPhone › your app*), add this to `ios/Runner/Info.plist`:

```xml
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

USB drives and SD card readers connected to an iPhone or iPad are not reachable by path. Apps can only
open files on them through the system document picker (`UIDocumentPickerViewController`).

Refer to the provided example project for detailed information.

## Basic Usage

### Initialization

```dart
import 'package:external_storage/external_storage.dart';

final externalStorage = ExternalStorage();
```

### Storage Device Information

Retrieve all available storage devices:

```dart
Future<void> getStorageDevices() async {
  try {
    final devices = await externalStorage.getAllStorageDevices();
    for (final device in devices) {
      print('Device Path: ${device.path}');
      print('Device Name: ${device.name}'); // localized by the system, e.g. "SanDisk SD card"
      print('Total Space: ${device.totalSize} bytes');
      print('Available Space: ${device.availableSize} bytes');
      print('UUID: ${device.uuid}'); // e.g. 1A2B-3C4D, null for primary storage
    }
  } catch (e) {
    print('Failed to get storage devices: $e');
  }
}
```

#### Identifying an external drive (SD card / USB)

Android has no drive letters. The closest equivalent is the volume **UUID** (file-system serial,
e.g. `1A2B-3C4D`), which stays the same for a given card across devices; the mount path is usually
`/storage/<UUID>`.

```dart
final devices = await externalStorage.getAllStorageDevices();
for (final d in devices.where((d) => d.isRemovable)) {
  print('${d.description ?? d.name}: uuid=${d.uuid}, path=${d.path}');
}
```

`description` is the system-provided label (e.g. "SanDisk SD card", "USB drive").

### File Operations

```dart
import 'dart:convert';
import 'dart:typed_data';

// Android: /storage/emulated/0, iOS: the app's Documents directory
final device = (await externalStorage.getAllStorageDevices())
    .firstWhere((d) => d.isPrimary);
final file = '${device.path}/Download/notes.txt';

// Writing (parent directories are created automatically)
final bytes = Uint8List.fromList(utf8.encode('Hello, External Storage! 你好'));
final written = await externalStorage.writeFile(file, bytes);
await externalStorage.writeFile(file, bytes, append: true);

// Reading the whole file or a range
final content = utf8.decode(await externalStorage.readFile(file));
final header = await externalStorage.readFile(file, offset: 0, length: 16);

// Copy / move (moving across volumes, e.g. to an SD card, falls back to copy + delete)
await externalStorage.copyFile(file, '${device.path}/Download/notes_copy.txt');
await externalStorage.moveFile(file, '${device.path}/Documents/notes.txt');

// Metadata
final info = await externalStorage.getFileInfo('${device.path}/Documents/notes.txt');
print('${info.size} bytes, modified ${info.lastModified}, writable: ${info.canWrite}');
final md5 = await externalStorage.calculateMD5(info.path);
final mime = await externalStorage.getMimeType(info.path); // text/plain
```

Use `utf8.encode` / `utf8.decode` for text; `String.codeUnits` breaks non-Latin text.

### Directory Operations

```dart
final dir = '${device.path}/Download/my_app';
await externalStorage.createDirectory(dir, recursive: true);

// Direct children, or the whole tree with recursive: true
final entries = await externalStorage.listDirectory(dir);
for (final entry in entries) {
  print('${entry.isDirectory ? 'DIR ' : 'FILE'} ${entry.name} ${entry.size}');
}

final dirInfo = await externalStorage.getDirectoryInfo(dir); // counts + volume space
final size = await externalStorage.getDirectorySize(dir);
await externalStorage.copyDirectory(dir, '$dir-backup');
await externalStorage.deleteDirectory('$dir-backup', recursive: true);
```

### File System Monitoring

`watch()` returns a stream. Watching starts when you listen and stops when you cancel the
subscription, and several paths can be watched at the same time. Each event carries the full path of
the changed entry:

```dart
final subscription = externalStorage.watch(
  '/storage/emulated/0/Download',
  recursive: true,
  events: [WatchEventType.create, WatchEventType.delete, WatchEventType.modify],
).listen(
  (event) => print('${event.type.name}: ${event.path} (dir: ${event.isDirectory})'),
  onError: (Object e) => print('Cannot watch: $e'), // e.g. the path does not exist
  onDone: () => print('Watched directory was deleted or moved'),
);

// later
await subscription.cancel();
```

- An empty `events` list means all events. On Android, avoid subscribing to `open` / `access` /
  `closeNoWrite` if you reload a listing on every event: reading a directory produces these events.
- On iOS, changes are detected by polling every second, so only `create`, `modify`, `delete` and
  `deleteSelf` are reported and a rename shows up as `delete` + `create`.
- The older `startWatching()` / `registerWatchEventCallback()` API still works and now also passes
  the full path of the changed entry.

### Permission Management

```dart
Future<void> manageStoragePermissions() async {
  try {
    bool hasPermission = await externalStorage.checkStoragePermissions();
    if (!hasPermission) {
      bool permissionGranted = await externalStorage.requestStoragePermissions();
      if (permissionGranted) {
        print('Storage permission granted');
      } else {
        print('Storage permission denied');
      }
    }
  } on PlatformException catch (e) {
    // NO_ACTIVITY / REQUEST_IN_PROGRESS / PERMISSION_NOT_DECLARED
    print('Permission management failed: ${e.code} ${e.message}');
  }
}
```

If the user denies, call `openAppSettings()` to open the app's system settings page. On iOS both
methods return `true` immediately.

### Error Handling

- Methods that return data (`readFile`, `getFileInfo`, `calculateMD5`, `getDirectoryInfo`, …) throw a
  `PlatformException` with code `OPERATION_FAILED` and a message such as
  `readFile: File does not exist or is not a file (/path)`.
- Methods that return `bool` (`copyFile`, `deleteDirectory`, …) return `false` on failure.
- `listDirectory()` returns an empty list when the path is not a readable directory.

### Testing

File and directory operations use `dart:io`, so they work in a plain `flutter test` against real
files (for example in `Directory.systemTemp`). On the host there is no storage permission model, so the
permission checks return `true`.

`getAllStorageDevices()` and `openAppSettings()` need the native side. In a plain `flutter test` they
throw `MissingPluginException`, because no native plugins are loaded on the host Dart VM.

- **Unit / widget tests**: mock `ExternalStorage` (see `example/test/widget_test.dart`) or set
  `ExternalStoragePlatform.instance` to a fake implementation.
- **On-device tests**: use [`integration_test`](https://docs.flutter.dev/testing/integration-tests),
  see `example/integration_test/plugin_integration_test.dart`:

```sh
cd example
# All files access can't be tapped through in automated tests; pre-grant it with adb
adb shell appops set --uid tech.thispage.external_storage_example MANAGE_EXTERNAL_STORAGE allow
flutter test integration_test
```

## Advanced Features

- `calculateMD5()` hashes in a background isolate, so large files don't block the UI.
- `getMimeType()` checks the file header (magic numbers) first and the extension second, so a PNG
  saved as `.bin` is still reported as `image/png`.
- `FileInfo.canRead` / `canWrite` / `canExecute` use `access(2)`, the same check as
  `java.io.File.canRead()`. On Android 11+ shared storage the permission bits alone are not reliable.
- `PathUtils` offers path helpers such as `sanitizeFilename()`, `hasIllegalChars()` (characters that
  FAT32 / exFAT SD cards reject) and `getReadableSize()`.

## Precautions

- On Android 11+, `Android/data` and `Android/obb` of other apps stay inaccessible even with All files
  access; recursive listings skip them.
- Recursive watching on Android uses one inotify watch per directory. Very large trees can reach the
  system limit (`fs.inotify.max_user_watches`).
- Cancel `watch()` subscriptions you no longer need, especially on iOS where watching polls.
- The deprecated `FileMode` enum has the same name as `dart:io`'s `FileMode`. If you import both
  libraries and use `FileMode`, add `hide FileMode` to the `external_storage` import.

## License

This plugin follows the MIT License. Please refer to the project license file for detailed information.

## Contribution

Welcome to submit issues and pull requests through the GitHub repository to collectively improve the External Storage plugin.
