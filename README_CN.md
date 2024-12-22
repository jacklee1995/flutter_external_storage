# external_storage

- 作者：李俊才（jcLee95）
- [![jcLee95](https://raw.githubusercontent.com/jacklee1995/flutter_external_storage/refs/heads/master/jclee95_64x64.ico)](https://jclee95.blog.csdn.net)
- 邮箱：[291148484@163.com](291148484@163.com)
- 描述：一个功能强大的 Flutter 安卓外部存储管理插件，提供完整的文件系统操作、存储设备管理、文件监视和权限处理功能。
- 协议：[LICENSE](https://github.com/jacklee1995/flutter_external_storage/blob/master/LICENSE)
- English：[README.md](https://github.com/jacklee1995/flutter_external_storage/blob/master/README_CN.md)

## 简介

External Storage 是一个强大易用的 Flutter 插件，专为跨平台文件和存储管理而设计。该库提供了一套全面的 API，用于处理外部存储设备上的文件和目录操作，支持多种文件系统交互场景。

### 功能特点

- 📱 支持多存储设备管理
- 📂 完整的文件和目录操作
- 👀 实时文件系统监视
- 🔒 完善的权限管理
- 🛠 丰富的文件工具方法
- ⚡ 高性能文件操作
- 🎯 类型安全的 API

### 主要特性

External Storage 插件提供了丰富的文件和存储管理功能，包括但不限于：

文件操作：读取、写入、复制、移动和删除文件
目录管理：创建、列出、复制和监视目录
存储设备信息：获取存储设备详细信息
文件系统监控：实时监听文件和目录变化
权限管理：简化存储权限申请和管理流程

## 安装

将以下依赖添加到你的 `pubspec.yaml` 文件中：

```yaml
dependencies:
  external_storage: ^latest_version
```

然后执行 Flutter 包获取命令：

```bash
flutter pub get
```

或者也可以直接使用add命令安装最新版本：

```sh
flutter pub add external_storage
```

## 配置

在 `AndroidManifest.xml` 中添加以下权限：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Android 13+ (API 33+) 细分存储权限 -->
    <uses-permission android:name="android.permission.READ_MEDIA_IMAGES" />
    <uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
    
    <!-- Android 14+ (API 34+) 照片和视频访问权限 -->
    <uses-permission android:name="android.permission.READ_MEDIA_VISUAL_USER_SELECTED" />

    <!-- Android 10 及以下版本的存储权限 -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="29" />

    <!-- 所有文件访问权限 (需要用户在系统设置中手动授予) -->
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />

    <application
        android:label="external_storage_example"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <!-- 文件提供者（非必须） -->
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

详细参考给出的示例项目。

## 基本使用

### 初始化

```dart
import 'package:external_storage/external_storage.dart';

final externalStorage = ExternalStorage();
```

### 存储设备信息

获取所有可用存储设备：

```dart
Future<void> getStorageDevices() async {
  try {
    List<StorageDevice> devices = await externalStorage.getAllStorageDevices();
    devices.forEach((device) {
      print('设备路径: ${device.path}');
      print('设备名称: ${device.name}');
      print('总空间: ${device.totalSize} 字节');
      print('可用空间: ${device.availableSize} 字节');
    });
  } catch (e) {
    print('获取存储设备失败: $e');
  }
}
```

### 文件操作

#### 读取文件

```dart
Future<void> readFileContent() async {
  try {
    Uint8List fileData = await externalStorage.readFile('/path/to/file');
    print('文件内容: $fileData');
  } catch (e) {
    print('读取文件失败: $e');
  }
}
```

#### 写入文件

```dart
Future<void> writeFileContent() async {
  try {
    Uint8List data = Uint8List.fromList('Hello, External Storage!'.codeUnits);
    int bytesWritten = await externalStorage.writeFile('/path/to/file', data);
    print('写入 $bytesWritten 字节');
  } catch (e) {
    print('写入文件失败: $e');
  }
}
```

### 目录操作

#### 列出目录内容

```dart
Future<void> listDirectoryContents() async {
  try {
    List<FileInfo> files = await externalStorage.listDirectory('/path/to/directory');
    files.forEach((file) {
      print('文件名: ${file.name}');
      print('文件路径: ${file.path}');
      print('文件大小: ${file.size} 字节');
    });
  } catch (e) {
    print('列出目录内容失败: $e');
  }
}
```

### 文件系统监控

#### 监听文件系统事件

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
      print('文件系统事件: $path, 事件类型: ${event.name}');
    });
  } catch (e) {
    print('监听目录失败: $e');
  }
}
```

### 权限管理

#### 检查和请求存储权限

```dart
Future<void> manageStoragePermissions() async {
  try {
    bool hasPermission = await externalStorage.checkStoragePermissions();
    if (!hasPermission) {
      bool permissionGranted = await externalStorage.requestStoragePermissions();
      if (permissionGranted) {
        print('存储权限已授予');
      } else {
        print('存储权限被拒绝');
      }
    }
  } catch (e) {
    print('权限管理失败: $e');
  }
}
```

## 高级功能

External Storage 还提供了更多高级功能，如文件 MD5 计算、MIME 类型获取、文件属性检查等。建议查阅 API 文档以获取更多详细信息。

## 注意事项

在使用 External Storage 时，请注意：

确保处理可能的异常情况
在使用文件和目录操作时遵循最佳实践
注意跨平台兼容性
在某些平台上可能需要额外的权限配置

## 许可证

本插件遵循 MIT 许可证。详细信息请参见项目许可证文件。

## 贡献

欢迎通过 GitHub 仓库提交问题和拉取请求，共同改进 External Storage 插件。
