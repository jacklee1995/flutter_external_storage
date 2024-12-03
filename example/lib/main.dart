import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show Uint8List, kDebugMode;
import 'package:flutter/material.dart';
import 'package:external_storage/external_storage.dart'
    show ExternalStorage, FileInfo, StorageDevice, WatchEventType;
import 'package:open_file/open_file.dart' show OpenFile, ResultType;
import 'package:path/path.dart' as path;
import 'package:mime/mime.dart' show lookupMimeType;
import 'package:permission_handler/permission_handler.dart'
    show
        Permission,
        PermissionActions,
        PermissionCheckShortcuts,
        PermissionStatusGetters,
        openAppSettings;
import 'package:device_info_plus/device_info_plus.dart' show DeviceInfoPlugin;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'External Storage Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const StorageDemo(),
    );
  }
}

class StorageDemo extends StatefulWidget {
  final ExternalStorage? storage;

  const StorageDemo({super.key, this.storage});

  @override
  StorageDemoState createState() => StorageDemoState();
}

class StorageDemoState extends State<StorageDemo> {
  late final ExternalStorage storage;
  final List<String> _logs = [];
  String _currentPath = '';
  List<FileInfo> _currentEntries = [];
  List<StorageDevice> _devices = [];
  bool _isLoading = false;
  bool _hasPermission = false;
  String _permissionStatus = '未检查';

  // 复制
  FileInfo? _copyItem;
  bool _isCopyOperationActive = false;

  // 剪切
  FileInfo? _cutItem;
  bool _isCutOperationActive = false;

  @override
  void initState() {
    super.initState();
    storage = widget.storage ?? ExternalStorage();
    _initializeStorage();
    // 注册文件系统监听
    storage.registerWatchEventCallback(_onFileSystemEvent);
  }

  Future<void> _initializeStorage() async {
    setState(() {
      _isLoading = true;
      _permissionStatus = '检查权限中...';
    });

    try {
      _addLog('开始检查权限...');
      _hasPermission = await _checkAndRequestPermissions();
      _addLog('权限检查结果: $_hasPermission');

      if (!_hasPermission) {
        _permissionStatus = '权限被拒绝';
        _addLog('未获得存储权限');
        setState(() => _isLoading = false);
        return;
      }

      _permissionStatus = '已获得权限';
      setState(() {});

      // 获取存储设备
      _addLog('获取存储设备列表...');
      _devices = await storage.getAllStorageDevices();
      _addLog('找到 ${_devices.length} 个存储设备');
    } catch (e, s) {
      _permissionStatus = '初始化错误';
      _addLog('初始化错误: $e\n$s');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;

      if (androidInfo.version.sdkInt >= 33) {
        // Android 13+ (API 33+)
        final images = await Permission.photos.request();
        final videos = await Permission.videos.request();
        final audio = await Permission.audio.request();
        final manageStorage = await Permission.manageExternalStorage.request();

        return images.isGranted &&
            videos.isGranted &&
            audio.isGranted &&
            manageStorage.isGranted;
      } else if (androidInfo.version.sdkInt >= 30) {
        // Android 11+ (API 30+)
        if (!await Permission.manageExternalStorage.isGranted) {
          final status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            await openAppSettings();
            return false;
          }
        }
        return true;
      } else {
        // Android 10 及以下版本
        final storage = await Permission.storage.request();
        return storage.isGranted;
      }
    }
    return true;
  }

  Future<void> _loadCurrentDirectory() async {
    setState(() => _isLoading = true);
    try {
      _addLog('开始加载目录: $_currentPath');
      _currentEntries = await storage.listDirectory(_currentPath);
      _addLog('成功加载目录，共 ${_currentEntries.length} 个项目');

      // 开始监听当前目录
      if (_currentPath.isNotEmpty) {
        await storage.startWatching(_currentPath);
        _addLog('开始监听目录: $_currentPath');
      }

      setState(() {});
    } catch (e, s) {
      _addLog('加载目录错误: $e\n堆栈: $s');
      setState(() {
        _currentEntries = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onFileSystemEvent(String path, WatchEventType event) {
    _addLog('文件事件: ${event.name} - $path');
    if (path.startsWith(_currentPath)) {
      _loadCurrentDirectory();
    }
  }

  void _addLog(String message) {
    // 在终端打印日志
    if (kDebugMode) {
      print('StorageDemo: $message');
    }

    setState(() {
      _logs.insert(0, '${DateTime.now().toString()}: $message');
      if (_logs.length > 100) _logs.removeLast();
    });
  }

  Future<void> _cutItemAction(FileInfo item) async {
    setState(() {
      _cutItem = item;
      _isCutOperationActive = true;
    });
    _addLog('剪切: ${item.path}');
  }

  Future<void> _pasteItem() async {
    if (_cutItem == null) return;

    try {
      final newPath = path.join(_currentPath, _cutItem!.name);
      if (_cutItem!.isFile) {
        await storage.moveFile(_cutItem!.path, newPath);
      } else {
        await storage.moveDirectory(_cutItem!.path, newPath);
      }
      _addLog('粘贴: ${_cutItem!.path} 到 $newPath');
      setState(() {
        _cutItem = null;
        _isCutOperationActive = false;
      });
      await _loadCurrentDirectory();
    } catch (e) {
      _addLog('粘贴错误: $e');
    }
  }

  void _cancelCut() {
    setState(() {
      _cutItem = null;
      _isCutOperationActive = false;
    });
    _addLog('取消剪切');
  }

  Future<void> _createTestFile() async {
    try {
      const baseName = 'test';
      const extension = '.txt';
      String testPath = path.join(_currentPath, '$baseName$extension');
      int counter = 1;

      // 检查文件是否存在，如果存在则添加后缀
      while (await storage.fileExists(testPath)) {
        testPath =
            path.join(_currentPath, '${baseName}_$counter$extension'); // 修改这里
        counter++;
      }

      final data = Uint8List.fromList('Hello, World!'.codeUnits);
      final bytesWritten = await storage.writeFile(testPath, data);
      _addLog('创建测试文件: $bytesWritten bytes at $testPath');
      await _loadCurrentDirectory();
    } catch (e) {
      _addLog('创建文件错误: $e');
    }
  }

  Future<void> _createTestDirectory() async {
    try {
      const baseName = 'test_dir';
      String dirPath = path.join(_currentPath, baseName);
      int counter = 1;

      // 检查目录是否存在，如果存在则添加后缀
      while (await storage.directoryExists(dirPath)) {
        dirPath = path.join(_currentPath, '${baseName}_$counter'); // 修改这里
        counter++;
      }

      final created = await storage.createDirectory(dirPath);
      _addLog('创建测试目录: ${created ? '成功' : '失败'} at $dirPath');
      await _loadCurrentDirectory();
    } catch (e) {
      _addLog('创建目录错误: $e');
    }
  }

  Future<void> _showItemInfo(FileInfo item) async {
    try {
      if (item.isFile) {
        _addLog('获取文件信息: ${item.path}');
        final info = await storage.getFileInfo(item.path);
        final md5 = await storage.calculateMD5(item.path);
        _showInfoDialog(
          '文件信息',
          '名称: ${info.name}\n'
              '大小: ${_formatSize(info.size)}\n'
              '修改时间: ${info.lastModified}\n'
              'MD5: $md5',
        );
      } else {
        _addLog('获取目录信息: ${item.path}');
        final info = await storage.getDirectoryInfo(item.path);
        _showInfoDialog(
          '目录信息',
          '名称: ${info.name}\n'
              '文件数量: ${info.fileCount}\n'
              '目录数量: ${info.directoryCount}\n'
              '总空间: ${_formatSize(info.totalSpace)}\n'
              '可用空间: ${_formatSize(info.freeSpace)}',
        );
      }
    } catch (e, s) {
      _addLog('获取信息错误: $e\n堆栈: $s');
    }
  }

  String _formatSize(int bytes) {
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(2)} ${suffixes[i]}';
  }

  Future<void> _showInfoDialog(String title, String content) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(content),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_devices.isEmpty) {
      return const Center(
        child: Text('未找到存储设备'),
      );
    }

    return ListView.builder(
      itemCount: _devices.length,
      itemBuilder: (context, index) {
        final device = _devices[index];
        return ListTile(
          leading: Icon(
            device.isRemovable ? Icons.sd_card : Icons.phone_android,
            color: device.isRemovable ? Colors.green : Colors.blue,
          ),
          title: Text(device.name),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(device.path),
              Text(
                  '可用: ${_formatSize(device.availableSize)} / 总共: ${_formatSize(device.totalSize)}'),
            ],
          ),
          isThreeLine: true,
          onTap: () async {
            try {
              setState(() {
                _currentPath = device.path;
                _isLoading = true;
              });
              await _loadCurrentDirectory();
            } catch (e, s) {
              _addLog('切换目录错误: $e\n堆栈: $s');
            }
          },
        );
      },
    );
  }

  Widget _buildListItem(FileInfo item) {
    return ListTile(
      leading: Icon(
        item.isDirectory ? Icons.folder : Icons.insert_drive_file,
        color: item.isDirectory ? Colors.amber : Colors.blue,
      ),
      title: Text(
        item.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.path,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            item.isFile
                ? _formatSize(item.size)
                : '目录 - ${item.lastModified.toString().split('.')[0]}',
          ),
        ],
      ),
      isThreeLine: true,
      trailing: PopupMenuButton<String>(
        onSelected: (value) async {
          try {
            switch (value) {
              case 'info':
                await _showItemInfo(item);
                break;
              case 'delete':
                final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('确认删除'),
                        content: Text(
                            '确定要删除${item.isFile ? '文件' : '目录'} "${item.name}" 吗？'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('取消'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('确定'),
                          ),
                        ],
                      ),
                    ) ??
                    false;

                if (confirmed) {
                  if (item.isFile) {
                    await storage.deleteFile(item.path);
                  } else {
                    await storage.deleteDirectory(item.path, recursive: true);
                  }
                  _addLog('删除${item.isFile ? '文件' : '目录'}: ${item.name}');
                  await _loadCurrentDirectory();
                }
                break;
            }
          } catch (e, s) {
            _addLog('操作错误: $e\n堆栈: $s');
          }
        },
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'info',
            child: Text('信息'),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Text('删除'),
          ),
        ],
      ),
      onTap: item.isDirectory
          ? () async {
              try {
                setState(() {
                  _currentPath = item.path;
                  _isLoading = true;
                });
                await _loadCurrentDirectory();
              } catch (e, s) {
                _addLog('切换目录错误: $e\n堆栈: $s');
              }
            }
          : () async {
              // 打开文件
              _openFile(item.path);
            },
      onLongPress: () => _showBottomActions(item),
    );
  }

  Future<void> _showBottomActions(FileInfo item) {
    return showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text('详细信息'),
                onTap: () {
                  Navigator.pop(context);
                  _showItemInfo(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_cut),
                title: const Text('剪切'),
                onTap: () {
                  Navigator.pop(context);
                  _cutItemAction(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.content_copy),
                title: const Text('复制'),
                onTap: () {
                  Navigator.pop(context);
                  _copyItemAction(item);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除', style: TextStyle(color: Colors.red)),
                onTap: () async {
                  Navigator.pop(context);
                  final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('确认删除'),
                          content: Text(
                              '确定要删除${item.isFile ? '文件' : '目录'} "${item.name}" 吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text('确定'),
                            ),
                          ],
                        ),
                      ) ??
                      false;

                  if (confirmed) {
                    try {
                      if (item.isFile) {
                        await storage.deleteFile(item.path);
                      } else {
                        await storage.deleteDirectory(item.path,
                            recursive: true);
                      }
                      _addLog('删除${item.isFile ? '文件' : '目录'}: ${item.name}');
                      await _loadCurrentDirectory();
                    } catch (e) {
                      _addLog('删除失败: $e');
                      if (!mounted) return;
                      await _showErrorDialog('删除失败: $e');
                    }
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFile(String filePath) async {
    try {
      _addLog('尝试打开文件: $filePath');

      // 检查文件是否存在
      final file = File(filePath);
      if (!await file.exists()) {
        _addLog('文件不存在: $filePath');
        if (!mounted) return;
        await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('错误'),
            content: const Text('文件不存在'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('确定'),
              ),
            ],
          ),
        );
        return;
      }

      // 尝试获取文件类型
      final mimeType = lookupMimeType(filePath);
      _addLog('文件类型: ${mimeType ?? "未知"}');

      // 打开文件
      final result = await OpenFile.open(
        filePath,
        type: mimeType,
      );

      if (!mounted) return;

      switch (result.type) {
        case ResultType.done:
          _addLog('文件打开成功');
          break;
        case ResultType.fileNotFound:
          _addLog('文件未找到');
          await _showErrorDialog('文件未找到');
          break;
        case ResultType.noAppToOpen:
          _addLog('没有找到可以打开此类型文件的应用');
          await _showErrorDialog('没有找到可以打开此类型文件的应用，请安装相关应用后重试');
          break;
        case ResultType.permissionDenied:
          _addLog('权限被拒绝');
          await _showErrorDialog('没有权限打开文件');
          break;
        case ResultType.error:
          _addLog('打开文件错误: ${result.message}');
          await _showErrorDialog('打开文件失败: ${result.message}');
          break;
      }
    } catch (e, s) {
      _addLog('打开文件异常: $e\n$s');
      if (!mounted) return;
      await _showErrorDialog('打开文件时发生错误: $e');
    }
  }

// 3. 修改 _showErrorDialog 方法，添加 mounted 检查
  Future<void> _showErrorDialog(String message) async {
    if (!mounted) return;
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('错误'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<bool> _handleBackNavigation() async {
    if (_currentPath.isNotEmpty) {
      final isRootPath = _devices.any((device) => device.path == _currentPath);

      if (!isRootPath) {
        await storage.stopWatching(_currentPath);
        _addLog('停止监听目录: $_currentPath');

        final parentDir = path.dirname(_currentPath);
        if (parentDir != _currentPath) {
          if (!mounted) return false;
          setState(() {
            _currentPath = parentDir;
            _loadCurrentDirectory();
          });
          return false;
        }
      } else {
        await storage.stopWatching(_currentPath);
        _addLog('停止监听目录: $_currentPath');

        if (!mounted) return false;
        setState(() {
          _currentPath = '';
        });
        return false;
      }
    }
    return true;
  }

  Future<bool> _showExitDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('退出应用'),
        content: const Text('确定要退出应用吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('确定'),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }

  // 实现复制方法
  Future<void> _copyItemAction(FileInfo item) async {
    setState(() {
      _copyItem = item;
      _isCopyOperationActive = true;
    });
    _addLog('复制: ${item.path}');
  }

  // 实现粘贴方法
  Future<void> _pasteCopiedItem() async {
    if (_copyItem == null) return;

    try {
      String newPath = path.join(_currentPath, _copyItem!.name);
      String originalName = path.basenameWithoutExtension(_copyItem!.name);
      String extension = path.extension(_copyItem!.name);
      int counter = 1;

      // 检查目标路径是否存在，如果存在则添加数字后缀
      while (await storage.fileExists(newPath) ||
          await storage.directoryExists(newPath)) {
        newPath = path.join(_currentPath, '${originalName}_$counter$extension');
        counter++;
      }

      if (_copyItem!.isFile) {
        await storage.copyFile(_copyItem!.path, newPath);
      } else {
        await storage.copyDirectory(_copyItem!.path, newPath);
      }
      _addLog('粘贴: ${_copyItem!.path} 到 $newPath');
      await _loadCurrentDirectory();
    } catch (e, s) {
      _addLog('粘贴错误: $e\n堆栈: $s');
      if (!mounted) return;
      await _showErrorDialog('粘贴失败: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          final shouldShowExitDialog = await _handleBackNavigation();
          if (shouldShowExitDialog) {
            final navContext = context;
            if (!navContext.mounted) return;

            final shouldExit = await _showExitDialog(navContext);
            if (shouldExit && navContext.mounted) {
              Navigator.of(navContext).pop();
            }
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('External Storage Demo'),
          actions: [
            IconButton(
              icon: const Icon(Icons.home),
              onPressed: () {
                setState(() {
                  _currentPath = '';
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _loadCurrentDirectory,
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8.0),
              color:
                  _hasPermission ? Colors.green.shade100 : Colors.red.shade100,
              child: Row(
                children: [
                  Icon(
                    _hasPermission ? Icons.check_circle : Icons.error,
                    color: _hasPermission ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '存储权限状态: $_permissionStatus',
                      style: TextStyle(
                        color: _hasPermission
                            ? Colors.green.shade900
                            : Colors.red.shade900,
                      ),
                    ),
                  ),
                  if (!_hasPermission)
                    ElevatedButton(
                      onPressed: () async {
                        await _initializeStorage();
                      },
                      child: const Text('请求权限'),
                    ),
                ],
              ),
            ),
            Expanded(
              child: _hasPermission
                  ? _currentPath.isEmpty
                      ? _buildDeviceList()
                      : Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                '当前路径: $_currentPath',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ),
                            Expanded(
                              child: _isLoading
                                  ? const Center(
                                      child: CircularProgressIndicator())
                                  : _currentEntries.isEmpty
                                      ? const Center(child: Text('当前目录为空'))
                                      : ListView.builder(
                                          itemCount: _currentEntries.length,
                                          itemBuilder: (context, index) =>
                                              _buildListItem(
                                                  _currentEntries[index]),
                                        ),
                            ),
                            Container(
                              height: 150,
                              decoration: BoxDecoration(
                                border: Border(
                                  top: BorderSide(
                                    color: Theme.of(context).dividerColor,
                                  ),
                                ),
                              ),
                              child: ListView.builder(
                                reverse: true,
                                itemCount: _logs.length,
                                itemBuilder: (context, index) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8.0, vertical: 2.0),
                                  child: Text(
                                    _logs[index],
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                  : const Center(child: Text('需要存储权限才能使用此应用')),
            ),
          ],
        ),
        floatingActionButton: _hasPermission && _currentPath.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_isCutOperationActive) ...[
                    FloatingActionButton(
                      onPressed: _pasteItem,
                      tooltip: '粘贴',
                      child: const Icon(Icons.paste),
                    ),
                    const SizedBox(width: 16),
                    FloatingActionButton(
                      onPressed: _cancelCut,
                      tooltip: '取消',
                      child: const Icon(Icons.cancel),
                    ),
                  ] else if (_isCopyOperationActive) ...[
                    FloatingActionButton(
                      onPressed: _pasteCopiedItem,
                      tooltip: '粘贴',
                      child: const Icon(Icons.paste),
                    ),
                    const SizedBox(width: 16),
                  ],
                  FloatingActionButton(
                    onPressed: _createTestFile,
                    tooltip: '创建测试文件',
                    child: const Icon(Icons.note_add),
                  ),
                  const SizedBox(width: 16),
                  FloatingActionButton(
                    onPressed: _createTestDirectory,
                    tooltip: '创建测试目录',
                    child: const Icon(Icons.create_new_folder),
                  ),
                ],
              )
            : null,
      ),
    );
  }

  @override
  void dispose() {
    storage.unregisterWatchEventCallback();
    storage.stopAllWatching();
    super.dispose();
  }
}
