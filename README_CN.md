# external_storage

![alt text](https://raw.githubusercontent.com/jacklee1995/flutter_external_storage/refs/heads/master/flutter_external_storage.png)

- 作者：李俊才（jcLee95）
- [![jcLee95](https://raw.githubusercontent.com/jacklee1995/flutter_external_storage/refs/heads/master/jclee95_64x64.ico)](https://jclee95.blog.csdn.net)
- 邮箱：[291148484@163.com](291148484@163.com)
- 描述：一个支持 Android 和 iOS 的 Flutter 存储插件：存储卷（含 SD 卡 / U 盘的 UUID）、文件和目录操作、文件监视以及存储权限处理。
- 协议：[LICENSE](https://github.com/jacklee1995/flutter_external_storage/blob/master/LICENSE)
- English：[README.md](https://github.com/jacklee1995/flutter_external_storage/blob/master/README.md)

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

### 平台支持

| | Android | iOS |
| --- | --- | --- |
| 最低版本 | Android 5.0（API 21） | iOS 13 |
| `getAllStorageDevices()` | 内部存储、SD 卡、USB OTG 设备（带 UUID） | App 所在的数据卷，`path` 为 App 的 Documents 目录 |
| 文件和目录操作 | 支持 | 支持（限 App 沙盒内） |
| `watch()` / `startWatching()` | inotify：支持全部 `WatchEventType`，支持递归 | 轮询（每秒）：`create`、`modify`、`delete`、`deleteSelf` |
| 存储权限 | 运行时权限 / 所有文件访问权限 | 不需要，始终视为已授权 |

文件和目录操作基于 `dart:io` 实现，两个平台共用同一套代码。它们在 Dart 的 I/O 线程上执行（大目录列表、
MD5、目录大小在后台 isolate 中计算），文件内容不经过平台通道传输。只有存储卷信息、权限和 Android 的
inotify 监视由原生代码实现。

## 安装

将以下依赖添加到你的 `pubspec.yaml` 文件中：

```yaml
dependencies:
  external_storage: ^1.0.0
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

要求：Flutter 3.32+ / Dart 3.8+。

### Android

插件已自动合并 Android 10 及以下所需的 `READ_EXTERNAL_STORAGE` / `WRITE_EXTERNAL_STORAGE`。
Android 11+（API 30+）访问整个外部存储（包括 SD 卡、U 盘）需要「所有文件访问权限」，
**由于 Google Play 对该权限有审核政策，插件不会替你声明，需在宿主 App 的
`android/app/src/main/AndroidManifest.xml` 中自行添加**：

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android"
    xmlns:tools="http://schemas.android.com/tools">
    <uses-permission
        android:name="android.permission.MANAGE_EXTERNAL_STORAGE"
        tools:ignore="ScopedStorage" />
    ...
</manifest>
```

未声明时 `requestStoragePermissions()` 会抛出 code 为 `PERMISSION_NOT_DECLARED` 的 `PlatformException`。

| Android 版本 | `checkStoragePermissions()` 检查的权限 | `requestStoragePermissions()` 的行为 |
| --- | --- | --- |
| 11+（API 30+） | `MANAGE_EXTERNAL_STORAGE` | 跳转系统「所有文件访问权限」设置页，用户返回 App 后得到结果 |
| 6 – 10（API 23–29） | `READ/WRITE_EXTERNAL_STORAGE` | 弹出系统运行时权限对话框 |
| 5.x（API 21–22） | 安装时授予 | 直接返回 `true` |

### iOS

不需要任何配置或权限：iOS App 始终可以读写自己的沙盒，所以 `checkStoragePermissions()` 和
`requestStoragePermissions()` 都返回 `true`。

`getAllStorageDevices()` 返回 App 所在数据卷这一个设备，`path` 是 App 的 Documents 目录（存放用户可见
文件的位置）。如果希望这些文件出现在「文件」App 中（「我的 iPhone › 你的 App」），在
`ios/Runner/Info.plist` 中添加：

```xml
<key>UIFileSharingEnabled</key>
<true/>
<key>LSSupportsOpeningDocumentsInPlace</key>
<true/>
```

连接到 iPhone / iPad 的 U 盘和读卡器无法通过路径访问，只能通过系统文档选择器
（`UIDocumentPickerViewController`）打开其中的文件。

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
    final devices = await externalStorage.getAllStorageDevices();
    for (final device in devices) {
      print('设备路径: ${device.path}');
      print('设备名称: ${device.name}'); // 系统按当前语言提供，如「SanDisk SD 卡」
      print('总空间: ${device.totalSize} 字节');
      print('可用空间: ${device.availableSize} 字节');
      print('UUID: ${device.uuid}'); // 如 1A2B-3C4D，主存储为 null
    }
  } catch (e) {
    print('获取存储设备失败: $e');
  }
}
```

#### 获取外部磁盘（SD 卡 / U 盘）的「代号」

Android 没有 Windows 那样的盘符。最接近的是卷 **UUID**（文件系统序列号，如 `1A2B-3C4D`），
同一张卡插到不同设备上保持不变；卷的挂载路径通常是 `/storage/<UUID>`。

```dart
final devices = await externalStorage.getAllStorageDevices();
for (final d in devices.where((d) => d.isRemovable)) {
  print('${d.description ?? d.name}: uuid=${d.uuid}, path=${d.path}');
}
```

`description` 为系统提供的卷描述（如 "SanDisk SD 卡"、"USB 存储"）。

### 文件操作

```dart
import 'dart:convert';
import 'dart:typed_data';

// Android 上是 /storage/emulated/0，iOS 上是 App 的 Documents 目录
final device = (await externalStorage.getAllStorageDevices())
    .firstWhere((d) => d.isPrimary);
final file = '${device.path}/Download/notes.txt';

// 写入（自动创建父目录）
final bytes = Uint8List.fromList(utf8.encode('Hello, External Storage! 你好'));
final written = await externalStorage.writeFile(file, bytes);
await externalStorage.writeFile(file, bytes, append: true);

// 读取整个文件或其中一段
final content = utf8.decode(await externalStorage.readFile(file));
final header = await externalStorage.readFile(file, offset: 0, length: 16);

// 复制 / 移动（跨存储卷移动，如移到 SD 卡，会自动改为复制后删除）
await externalStorage.copyFile(file, '${device.path}/Download/notes_copy.txt');
await externalStorage.moveFile(file, '${device.path}/Documents/notes.txt');

// 文件信息
final info = await externalStorage.getFileInfo('${device.path}/Documents/notes.txt');
print('${info.size} 字节，修改于 ${info.lastModified}，可写：${info.canWrite}');
final md5 = await externalStorage.calculateMD5(info.path);
final mime = await externalStorage.getMimeType(info.path); // text/plain
```

文本请使用 `utf8.encode` / `utf8.decode`；`String.codeUnits` 会破坏中文等非拉丁字符。

### 目录操作

```dart
final dir = '${device.path}/Download/my_app';
await externalStorage.createDirectory(dir, recursive: true);

// 直接子项；recursive: true 时包含整个目录树
final entries = await externalStorage.listDirectory(dir);
for (final entry in entries) {
  print('${entry.isDirectory ? '目录' : '文件'} ${entry.name} ${entry.size}');
}

final dirInfo = await externalStorage.getDirectoryInfo(dir); // 子项数量 + 所在卷容量
final size = await externalStorage.getDirectorySize(dir);
await externalStorage.copyDirectory(dir, '$dir-backup');
await externalStorage.deleteDirectory('$dir-backup', recursive: true);
```

### 文件系统监控

`watch()` 返回一个流：开始监听时启动监视，取消订阅时停止，可以同时监视多个路径。
每个事件都带有发生变化的条目的完整路径：

```dart
final subscription = externalStorage.watch(
  '/storage/emulated/0/Download',
  recursive: true,
  events: [WatchEventType.create, WatchEventType.delete, WatchEventType.modify],
).listen(
  (event) => print('${event.type.name}: ${event.path}（目录：${event.isDirectory}）'),
  onError: (Object e) => print('无法监视: $e'), // 例如路径不存在
  onDone: () => print('被监视的目录已被删除或移走'),
);

// 不再需要时
await subscription.cancel();
```

- `events` 为空表示所有事件。在 Android 上如果每收到事件就刷新列表，不要订阅 `open` / `access` /
  `closeNoWrite`：读取目录本身就会产生这些事件。
- iOS 上通过每秒轮询检测变化，只报告 `create`、`modify`、`delete`、`deleteSelf`，重命名表现为
  `delete` + `create`。
- 旧的 `startWatching()` / `registerWatchEventCallback()` 仍然可用，回调中的路径现在也是发生变化的
  条目的完整路径。

### 权限管理

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
  } on PlatformException catch (e) {
    // NO_ACTIVITY / REQUEST_IN_PROGRESS / PERMISSION_NOT_DECLARED
    print('权限管理失败: ${e.code} ${e.message}');
  }
}
```

如果用户拒绝，可调用 `openAppSettings()` 打开本应用的系统设置页。iOS 上这两个方法直接返回 `true`。

### 错误处理

- 返回数据的方法（`readFile`、`getFileInfo`、`calculateMD5`、`getDirectoryInfo` 等）失败时抛出 code 为
  `OPERATION_FAILED` 的 `PlatformException`，消息形如 `readFile: File does not exist or is not a file (/path)`。
- 返回 `bool` 的方法（`copyFile`、`deleteDirectory` 等）失败时返回 `false`。
- `listDirectory()` 在路径不是可读目录时返回空列表。

### 测试

文件和目录操作基于 `dart:io`，可以在普通的 `flutter test` 中直接操作真实文件（例如
`Directory.systemTemp` 下的临时目录）。电脑上没有存储权限的概念，权限检查返回 `true`。

`getAllStorageDevices()` 和 `openAppSettings()` 依赖原生端。在普通的 `flutter test` 中调用会抛出
`MissingPluginException`，因为 `flutter test` 运行在电脑上的 Dart VM 中，没有加载任何原生插件。

- **单元测试 / Widget 测试**：mock `ExternalStorage`（参见 `example/test/widget_test.dart`），
  或用 `ExternalStoragePlatform.instance = 你的 Fake 实现` 替换平台层。
- **真实设备测试**：使用 [`integration_test`](https://docs.flutter.dev/testing/integration-tests)，
  参见 `example/integration_test/plugin_integration_test.dart`：

```sh
cd example
# Android 11+ 的「所有文件访问权限」无法在自动化测试中点击授予，先用 adb 预授权
adb shell appops set --uid tech.thispage.external_storage_example MANAGE_EXTERNAL_STORAGE allow
flutter test integration_test
```

## 高级功能

- `calculateMD5()` 在后台 isolate 中计算，大文件不会卡住 UI。
- `getMimeType()` 先按文件头（魔数）识别，再按扩展名，所以存成 `.bin` 的 PNG 仍会识别为 `image/png`。
- `FileInfo.canRead` / `canWrite` / `canExecute` 使用 `access(2)` 判断，与 `java.io.File.canRead()`
  相同；Android 11+ 的共享存储上只看权限位并不可靠。
- `PathUtils` 提供路径工具，例如 `sanitizeFilename()`、`hasIllegalChars()`（检查 FAT32 / exFAT
  的 SD 卡不允许的字符）、`getReadableSize()`。

## 注意事项

- Android 11+ 上即使有「所有文件访问权限」，也无法访问其他 App 的 `Android/data` 和 `Android/obb`，
  递归列目录时会跳过它们。
- Android 的递归监视为每个子目录占用一个 inotify watch，目录树非常大时可能达到系统上限
  （`fs.inotify.max_user_watches`）。
- 不再需要的 `watch()` 订阅请及时取消，iOS 上的监视是轮询实现的。
- 已弃用的 `FileMode` 枚举与 `dart:io` 的 `FileMode` 同名。同时导入两者并使用 `FileMode` 时，
  在 `external_storage` 的 import 后加上 `hide FileMode`。

## 许可证

本插件遵循 MIT 许可证。详细信息请参见项目许可证文件。

## 贡献

欢迎通过 GitHub 仓库提交问题和拉取请求，共同改进 External Storage 插件。
