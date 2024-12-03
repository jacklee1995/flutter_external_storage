
# external_storage

一个功能强大的 Flutter 外部存储管理插件，提供完整的文件系统操作、存储设备管理、文件监视和权限处理功能。

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
  external_storage: ^1.0.0
```

## 权限配置

### Android

在 `android/app/src/main/AndroidManifest.xml` 中添加以下权限：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- 基础存储权限 -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"/>
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"/>
    <!-- Android 10 (API 29) 及以上需要 -->
    <uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE"/>
</manifest>
```

### iOS

在 `ios/Runner/Info.plist` 中添加以下权限描述：

```xml
<key>NSDocumentsFolderUsageDescription</key>
<string>需要访问文档文件夹来管理文件</string>
<key>NSFileProviderDomainUsageDescription</key>
<string>需要访问文件来进行读写操作</string>
```

## 基础用法

### 初始化

```dart
import 'package:external_storage/external_storage.dart';

final storage = ExternalStorage();
```

### 存储设备管理

```dart
// 获取所有存储设备
final devices = await storage.getAllStorageDevices();
for (var device in devices) {
  print('设备名称: ${device.name}');
  print('总空间: ${device.totalSize}');
  print('可用空间: ${device.availableSize}');
  print('是否可移除: ${device.isRemovable}');
}
```

### 文件操作

```dart
// 读取文件
final bytes = await storage.readFile('/storage/emulated/0/test.txt');

// 写入文件
final data = Uint8List.fromList([/* 数据 */]);
final bytesWritten = await storage.writeFile('/path/to/file.dat', data);

// 复制文件
await storage.copyFile('/source/file.txt', '/target/file.txt');

// 移动文件
await storage.moveFile('/old/path.txt', '/new/path.txt');

// 删除文件
await storage.deleteFile('/path/to/delete.txt');

// 获取文件信息
final fileInfo = await storage.getFileInfo('/path/to/file.txt');
print('文件大小: ${fileInfo.size}');
print('修改时间: ${fileInfo.lastModified}');

// 计算文件MD5
final md5 = await storage.calculateMD5('/path/to/file.txt');
```

### 目录操作

```dart
// 列出目录内容
final entries = await storage.listDirectory('/storage/emulated/0/Download');
for (var entry in entries) {
  if (entry.isFile) {
    print('文件: ${entry.name}');
  } else {
    print('目录: ${entry.name}');
  }
}

// 创建目录
await storage.createDirectory('/path/to/new/dir', recursive: true);

// 删除目录
await storage.deleteDirectory('/path/to/dir', recursive: true);

// 获取目录信息
final dirInfo = await storage.getDirectoryInfo('/path/to/dir');
print('文件数量: ${dirInfo.fileCount}');
print('子目录数量: ${dirInfo.directoryCount}');
```

### 文件系统监视

```dart
// 开始监视目录
storage.registerWatchEventCallback((path, event) {
  print('文件变化: $path');
  print('事件类型: ${event.name}');
});

await storage.startWatching(
  '/path/to/watch',
  recursive: true,
  events: [
    WatchEventType.create,
    WatchEventType.modify,
    WatchEventType.delete,
  ],
);

// 停止监视
await storage.stopWatching('/path/to/watch');
```

### 权限管理

```dart
// 检查存储权限
final hasPermission = await storage.checkStoragePermissions();

// 请求存储权限
if (!hasPermission) {
  final granted = await storage.requestStoragePermissions();
  if (!granted) {
    // 显示权限说明
    if (await storage.shouldShowRequestPermissionRationale()) {
      // 显示权限说明UI
    }
    // 打开应用设置页面
    await storage.openAppSettings();
  }
}
```

## 高级用法

### 文件路径工具

```dart
import 'package:external_storage/src/utils/path_utils.dart';

// 规范化路径
final normalizedPath = PathUtils.normalize('/path/./to/../file.txt');

// 获取文件扩展名
final extension = PathUtils.extension('/path/to/file.txt');

// 获取文件名
final basename = PathUtils.basename('/path/to/file.txt');

// 获取父目录
final parent = PathUtils.dirname('/path/to/file.txt');

// 连接路径
final path = PathUtils.join(['path', 'to', 'file.txt']);

// 获取可读的文件大小
final readableSize = PathUtils.getReadableSize(1024 * 1024); // "1.00 MB"
```

### 批量操作

```dart
// 批量复制文件
Future<void> copyFiles(List<String> sources, String targetDir) async {
  for (var source in sources) {
    final fileName = PathUtils.basename(source);
    final target = PathUtils.join([targetDir, fileName]);
    await storage.copyFile(source, target);
  }
}

// 递归删除空目录
Future<void> cleanEmptyDirs(String path) async {
  final entries = await storage.listDirectory(path);
  for (var entry in entries) {
    if (entry.isDirectory) {
      await cleanEmptyDirs(entry.path);
      if (await storage.isDirectoryEmpty(entry.path)) {
        await storage.deleteDirectory(entry.path);
      }
    }
  }
}
```

## 注意事项

1. Android 10 (API 29) 及以上版本需要特殊处理：
   - 需要在 manifest 中声明 `MANAGE_EXTERNAL_STORAGE` 权限
   - 用户需要在系统设置中手动授予所有文件访问权限

2. 文件监视功能会消耗系统资源，建议：
   - 不使用时及时停止监视
   - 避免监视过多目录
   - 适当使用过滤器减少事件数量

3. 大文件操作建议：
   - 使用分块读写避免内存占用过大
   - 在后台线程中执行耗时操作
   - 实现进度回调提供用户反馈

4. 权限处理：
   - 首次使用时主动请求权限
   - 提供清晰的权限使用说明
   - 实现优雅的权限降级处理

## 错误处理

插件的所有方法都会抛出以下异常：

- `FileSystemException`: 文件系统操作错误
- `PermissionException`: 权限相关错误
- `PlatformException`: 平台特定错误

建议使用 try-catch 进行错误处理：

```dart
try {
  await storage.createDirectory('/path/to/dir');
} on FileSystemException catch (e) {
  print('文件系统错误: ${e.message}');
} on PermissionException catch (e) {
  print('权限错误: ${e.message}');
} catch (e) {
  print('其他错误: $e');
}
```

## 性能优化建议

1. 批量操作时使用事务：
   ```dart
   // 批量创建文件
   Future<void> createFiles(List<String> paths) async {
     try {
       for (var path in paths) {
         await storage.createFile(path);
       }
     } catch (e) {
       // 错误处理
     }
   }
   ```

2. 大文件读写使用流操作：
   ```dart
   // 分块读取大文件
   Future<void> readLargeFile(String path) async {
     final fileSize = (await storage.getFileInfo(path)).size;
     var offset = 0;
     const chunkSize = 1024 * 1024; // 1MB chunks
     
     while (offset < fileSize) {
       final chunk = await storage.readFile(
         path,
         offset: offset,
         length: chunkSize,
       );
       // 处理数据块
       offset += chunk.length;
     }
   }
   ```

## 贡献

欢迎提交 Issue 和 Pull Request！

## 许可证

MIT License
```

这个文档提供了：

1. 完整的功能介绍
2. 详细的安装和配置说明
3. 丰富的代码示例
4. 常见问题和注意事项
5. 错误处理指南
6. 性能优化建议

你可以根据实际需求调整内容，添加或删除相关部分。