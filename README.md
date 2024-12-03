# external_storage

- Author: Juncai Li (jcLee95)
- Email: [291148484@163.com](291148484@163.com)
- Description: A powerful Flutter Android external storage management plugin that provides complete file system operations, storage device management, file monitoring, and permission handling functionality.
- License: [LICENSE](./LICENSE)
- 中文：[./README_CN.md]

## Features

- 📱 Multi-storage device management
- 📂 Complete file and directory operations
- 👀 Real-time file system monitoring
- 🔒 Comprehensive permission management
- 🛠 Rich file utility methods
- ⚡ High-performance file operations
- 🎯 Type-safe API

## Installation

Add this dependency to your `pubspec.yaml` file:

```yaml
dependencies:
  external_storage: ^latest_version
```

## Configuration

Add the following permissions to your `AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Android 13+ (API 33+) Granular storage permissions -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
    
    <!-- Android 14+ (API 34+) Photo and video access permissions -->
    <uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />

    <!-- Storage permissions for Android 10 and below -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />

    <!-- All files access permission (requires manual grant in system settings) -->
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />

    <application
        android:label="external_storage_example"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- File provider -->
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileProvider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
    </application>
</manifest>
```

## Usage Guide

### Storage Device Management

```dart
// Get all storage devices
final devices = await storage.getAllStorageDevices();
for (var device in devices) {
  print('Device name: ${device.name}');
  print('Total space: ${device.totalSize}');
  print('Available space: ${device.availableSize}');
  print('Usage: ${device.usagePercentage}%');
}
```

### File Operations

```dart
// Read file
final bytes = await storage.readFile('/storage/emulated/0/test.txt');
final content = String.fromCharCodes(bytes);

// Write file
final data = Uint8List.fromList('Hello World'.codeUnits);
final bytesWritten = await storage.writeFile('/storage/emulated/0/test.txt', data);

// Copy file
await storage.copyFile(
  '/storage/emulated/0/source.txt',
  '/storage/emulated/0/backup/source.txt'
);

// Get file info
final info = await storage.getFileInfo('/storage/emulated/0/test.txt');
print('File name: ${info.name}');
print('Size: ${info.size}');
print('Last modified: ${info.lastModified}');
```

### Directory Operations

```dart
// Create directory
await storage.createDirectory('/storage/emulated/0/MyApp', recursive: true);

// List directory contents
final entries = await storage.listDirectory('/storage/emulated/0/Download');
for (var entry in entries) {
  if (entry.isFile) {
    print('File: ${entry.name}');
  } else {
    print('Directory: ${entry.name}');
  }
}

// Get directory info
final dirInfo = await storage.getDirectoryInfo('/storage/emulated/0/Pictures');
print('File count: ${dirInfo.fileCount}');
print('Directory count: ${dirInfo.directoryCount}');
print('Total space: ${dirInfo.totalSpace}');
```

### File Monitoring

```dart
// Set up monitor
storage.registerWatchEventCallback((path, event) {
  switch (event) {
    case WatchEventType.create:
      print('Created: $path');
      break;
    case WatchEventType.modify:
      print('Modified: $path');
      break;
    case WatchEventType.delete:
      print('Deleted: $path');
      break;
  }
});

// Start watching directory
await storage.startWatching(
  '/storage/emulated/0/Download',
  recursive: true,
  events: [
    WatchEventType.create,
    WatchEventType.modify,
    WatchEventType.delete,
  ],
);

// Get all watched paths
final watchedPaths = await storage.getWatchedPaths();
print('Watching paths: $watchedPaths');

// Stop watching specific directory
await storage.stopWatching('/storage/emulated/0/Download');
```

### Permission Management

```dart
// Permission check and request
if (!await storage.checkStoragePermissions()) {
  final granted = await storage.requestStoragePermissions();
  if (!granted) {
    if (await storage.shouldShowRequestPermissionRationale()) {
      // Show permission explanation
      showPermissionDialog();
    } else {
      // Guide user to settings page
      await storage.openAppSettings();
    }
  }
}

// Check specific permission
final hasImagePermission = await storage.checkPermission(
  'android.permission.READ_MEDIA_IMAGES'
);

// Get granted permissions list
final grantedPermissions = await storage.getGrantedPermissions();
print('Granted permissions: $grantedPermissions');
```

### Utility Methods

```dart
import 'package:external_storage/src/utils/path_utils.dart';

// Path processing
final normalizedPath = PathUtils.normalize('/storage/emulated/0/./test/../docs');
final fileName = PathUtils.basename('/storage/emulated/0/test.txt');
final extension = PathUtils.extension('/storage/emulated/0/test.txt');

// Path checking
final isHidden = PathUtils.isHidden('.hidden_file');
final readableSize = PathUtils.getReadableSize(1024 * 1024); // "1.00 MB"

// Path combination
final fullPath = PathUtils.join(['/storage/emulated/0', 'Download', 'test.txt']);
```

## Data Models
...(keep original content)

## Notes

1. Android 10 (API 29) and above need to adapt to scoped storage
2. Some operations may require special permissions:
   - `MANAGE_EXTERNAL_STORAGE` for complete file access
   - `READ_MEDIA_*` permissions for media file access
3. File monitoring features consume system resources, recommendations:
   - Limit the number of monitored directories
   - Stop monitoring when not in use
   - Avoid monitoring system directories
4. Large file operation recommendations:
   - Use asynchronous methods
   - Implement progress callbacks
   - Consider chunked processing
5. Permission handling recommendations:
   - Check permissions before use
   - Provide clear permission explanations
   - Implement graceful degradation strategies

## License

This project is open-sourced under the MIT License.
