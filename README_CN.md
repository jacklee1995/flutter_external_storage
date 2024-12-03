# external_storage

- 作者：李俊才（jcLee95）
- ![jcLee95](https://raw.githubusercontent.com/jacklee1995/flutter_external_storage/refs/heads/master/jclee95_64x64.ico)
- 邮箱：[291148484@163.com](291148484@163.com)
- 描述：一个功能强大的 Flutter 安卓外部存储管理插件，提供完整的文件系统操作、存储设备管理、文件监视和权限处理功能。
- 协议：[LICENSE](https://github.com/jacklee1995/flutter_external_storage/blob/master/LICENSE)
- English：[README.md](https://github.com/jacklee1995/flutter_external_storage/blob/master/README_CN.md)

## 功能特点

- 📱 支持多存储设备管理
- 📂 完整的文件和目录操作
- 👀 实时文件系统监视
- 🔒 完善的权限管理
- 🛠 丰富的文件工具方法
- ⚡ 高性能文件操作
- 🎯 类型安全的 API

## 安装

将以下依赖添加到你的 `pubspec.yaml` 文件中：

```yaml
dependencies:
  external_storage: ^最新版本
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
        <!-- 文件提供者 -->
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


## 使用指南

### 存储设备管理

```dart
// 获取所有存储设备
final devices = await storage.getAllStorageDevices();
for (var device in devices) {
  print('设备名称: ${device.name}');
  print('总空间: ${device.totalSize}');
  print('可用空间: ${device.availableSize}');
  print('使用率: ${device.usagePercentage}%');
}
```

### 文件操作

```dart
// 读取文件
final bytes = await storage.readFile('/storage/emulated/0/test.txt');
final content = String.fromCharCodes(bytes);

// 写入文件
final data = Uint8List.fromList('Hello World'.codeUnits);
final bytesWritten = await storage.writeFile('/storage/emulated/0/test.txt', data);

// 复制文件
await storage.copyFile(
  '/storage/emulated/0/source.txt',
  '/storage/emulated/0/backup/source.txt'
);

// 获取文件信息
final info = await storage.getFileInfo('/storage/emulated/0/test.txt');
print('文件名: ${info.name}');
print('大小: ${info.size}');
print('修改时间: ${info.lastModified}');
```

### 目录操作

```dart
// 创建目录
await storage.createDirectory('/storage/emulated/0/MyApp', recursive: true);

// 列出目录内容
final entries = await storage.listDirectory('/storage/emulated/0/Download');
for (var entry in entries) {
  if (entry.isFile) {
    print('文件: ${entry.name}');
  } else {
    print('目录: ${entry.name}');
  }
}

// 获取目录信息
final dirInfo = await storage.getDirectoryInfo('/storage/emulated/0/Pictures');
print('文件数量: ${dirInfo.fileCount}');
print('子目录数量: ${dirInfo.directoryCount}');
print('总空间: ${dirInfo.totalSpace}');
```

### 文件监视

```dart
// 设置监视器
storage.registerWatchEventCallback((path, event) {
  switch (event) {
    case WatchEventType.create:
      print('新建: $path');
      break;
    case WatchEventType.modify:
      print('修改: $path');
      break;
    case WatchEventType.delete:
      print('删除: $path');
      break;
  }
});

// 开始监视目录
await storage.startWatching(
  '/storage/emulated/0/Download',
  recursive: true,
  events: [
    WatchEventType.create,
    WatchEventType.modify,
    WatchEventType.delete,
  ],
);

// 获取所有被监视的路径
final watchedPaths = await storage.getWatchedPaths();
print('正在监视的路径: $watchedPaths');

// 停止监视特定目录
await storage.stopWatching('/storage/emulated/0/Download');
```

### 权限管理

```dart
// 权限检查与请求
if (!await storage.checkStoragePermissions()) {
  final granted = await storage.requestStoragePermissions();
  if (!granted) {
    if (await storage.shouldShowRequestPermissionRationale()) {
      // 显示权限说明
      showPermissionDialog();
    } else {
      // 引导用户前往设置页面
      await storage.openAppSettings();
    }
  }
}

// 检查特定权限
final hasImagePermission = await storage.checkPermission(
  'android.permission.READ_MEDIA_IMAGES'
);

// 获取已授予的权限列表
final grantedPermissions = await storage.getGrantedPermissions();
print('已授予的权限: $grantedPermissions');
```

### 工具方法

```dart
import 'package:external_storage/src/utils/path_utils.dart';

// 路径处理
final normalizedPath = PathUtils.normalize('/storage/emulated/0/./test/../docs');
final fileName = PathUtils.basename('/storage/emulated/0/test.txt');
final extension = PathUtils.extension('/storage/emulated/0/test.txt');

// 路径检查
final isHidden = PathUtils.isHidden('.hidden_file');
final readableSize = PathUtils.getReadableSize(1024 * 1024); // "1.00 MB"

// 路径组合
final fullPath = PathUtils.join(['/storage/emulated/0', 'Download', 'test.txt']);
```

## 数据模型

### StorageDevice
存储设备信息模型，包含：
- 设备路径
- 设备名称
- 是否可移除
- 总容量
- 可用容量
- 是否只读

### FileInfo
文件信息模型，包含：
- 文件名
- 文件路径
- 文件大小
- 修改时间
- 文件类型
- 权限信息

### DirectoryInfo
目录信息模型，包含：
- 目录名
- 目录路径
- 父目录
- 空间信息
- 文件计数
- 权限信息

## 注意事项

1. Android 10 (API 29) 及以上版本需要适配分区存储
2. 某些操作可能需要特殊权限：
   - `MANAGE_EXTERNAL_STORAGE` 用于完整的文件访问
   - `READ_MEDIA_*` 权限用于访问媒体文件
3. 文件监视功能会消耗系统资源，建议：
   - 限制监视的目录数量
   - 不使用时及时停止监视
   - 避免监视系统目录
4. 大文件操作建议：
   - 使用异步方法
   - 实现进度回调
   - 考虑分块处理
5. 权限处理建议：
   - 在使用前检查权限
   - 提供清晰的权限说明
   - 实现优雅的降级策略

## 许可证

此项目基于 MIT 许可证开源。



