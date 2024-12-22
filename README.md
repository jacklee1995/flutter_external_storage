# external_storage

![alt text](https://raw.githubusercontent.com/jacklee1995/flutter_external_storage/refs/heads/master/flutter_external_storage.png)

- Author: Li Juncai (jcLee95)
- [![jcLee95](https://raw.githubusercontent.com/jacklee1995/flutter_external_storage/refs/heads/master/jclee95_64x64.ico)](https://jclee95.blog.csdn.net)
- Email: [291148484@163.com](291148484@163.com)
- Description: A powerful Flutter Android external storage management plugin that provides comprehensive file system operations, storage device management, file monitoring, and permission handling.
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

### Key Features

The External Storage plugin offers rich file and storage management capabilities, including but not limited to:

File Operations: Reading, writing, copying, moving, and deleting files
Directory Management: Creating, listing, copying, and monitoring directories
Storage Device Information: Retrieving detailed storage device information
File System Monitoring: Real-time listening to file and directory changes
Permission Management: Simplifying storage permission application and management

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

Add the following permissions to your `AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Android 13+ (API 33+) Granular Storage Permissions -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
    
    <!-- Android 14+ (API 34+) Photo and Video Access Permissions -->
    <uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />

    <!-- Storage Permissions for Android 10 and below -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />

    <!-- All File Access Permission (Requires manual user authorization in system settings) -->
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />

    <application
        android:label="external_storage_example"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- File Provider (Optional) -->
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
    List<StorageDevice> devices = await externalStorage.getAllStorageDevices();
    devices.forEach((device) {
      print('Device Path: ${device.path}');
      print('Device Name: ${device.name}');
      print('Total Space: ${device.totalSize} bytes');
      print('Available Space: ${device.availableSize} bytes');
    });
  } catch (e) {
    print('Failed to get storage devices: $e');
  }
}
```

### File Operations

#### Reading a File

```dart
Future<void> readFileContent() async {
  try {
    Uint8List fileData = await externalStorage.readFile('/path/to/file');
    print('File Content: $fileData');
  } catch (e) {
    print('Failed to read file: $e');
  }
}
```

#### Writing to a File

```dart
Future<void> writeFileContent() async {
  try {
    Uint8List data = Uint8List.fromList('Hello, External Storage!'.codeUnits);
    int bytesWritten = await externalStorage.writeFile('/path/to/file', data);
    print('Wrote $bytesWritten bytes');
  } catch (e) {
    print('Failed to write file: $e');
  }
}
```

### Directory Operations

#### Listing Directory Contents

```dart
Future<void> listDirectoryContents() async {
  try {
    List<FileInfo> files = await externalStorage.listDirectory('/path/to/directory');
    files.forEach((file) {
      print('File Name: ${file.name}');
      print('File Path: ${file.path}');
      print('File Size: ${file.size} bytes');
    });
  } catch (e) {
    print('Failed to list directory contents: $e');
  }
}
```

### File System Monitoring

#### Listening to File System Events

```dart
Future<void> watchDirectory() async {
  try {
    await externalStorage.startWatching(
      '/path/to/watch',
      recursive: true,
      events: [
        WatchEventType.create,
        WatchEventType.delete,
        WatchEventType.modify
      ],
    );

    externalStorage.registerWatchEventCallback((path, event) {
      print('File System Event: $path, Event Type: ${event.name}');
    });
  } catch (e) {
    print('Failed to watch directory: $e');
  }
}
```

### Permission Management

#### Checking and Requesting Storage Permissions

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
  } catch (e) {
    print('Permission management failed: $e');
  }
}
```

## Advanced Features

External Storage provides additional advanced features such as file MD5 calculation, MIME type retrieval, file attribute checking, etc. It is recommended to consult the API documentation for more detailed information.

## Precautions

When using External Storage, please note:

Ensure handling of potential exception scenarios
Follow best practices when using file and directory operations
Pay attention to cross-platform compatibility
Additional permission configurations may be required on some platforms

## License

This plugin follows the MIT License. Please refer to the project license file for detailed information.

## Contribution

Welcome to submit issues and pull requests through the GitHub repository to collectively improve the External Storage plugin.
