package tech.thispage.external_storage

import android.content.Context
import android.util.Log

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

class ExternalStoragePlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var storageInfoManager: StorageInfoManager
    private lateinit var fileManager: FileManager
    private lateinit var directoryManager: DirectoryManager
    private lateinit var fileSystemWatcher: FileSystemWatcher

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "tech.thispage.external_storage")
        context = binding.applicationContext
        
        // 初始化各个管理器
        storageInfoManager = StorageInfoManager(context)
        fileManager = FileManager(context)
        directoryManager = DirectoryManager(context)
        fileSystemWatcher = FileSystemWatcher(context)
        
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            // 存储设备相关方法
            "getAllStorageDevices" -> {
                result.success(storageInfoManager.getAllStorageDevices())
            }

            // 文件操作相关方法
            "readFile" -> {
                val path = call.argument<String>("path") ?: ""
                val offset = call.argument<Long>("offset") ?: 0
                val length = call.argument<Long>("length") ?: -1
                result.success(fileManager.readFile(path, offset, length))
            }
            "writeFile" -> {
                val path = call.argument<String>("path") ?: ""
                val data = call.argument<ByteArray>("data") ?: ByteArray(0)
                val append = call.argument<Boolean>("append") ?: false
                result.success(fileManager.writeFile(path, data, append))
            }
            "copyFile" -> {
                val sourcePath = call.argument<String>("sourcePath") ?: ""
                val targetPath = call.argument<String>("targetPath") ?: ""
                result.success(fileManager.copyFile(sourcePath, targetPath))
            }
            "moveFile" -> {
                val sourcePath = call.argument<String>("sourcePath") ?: ""
                val targetPath = call.argument<String>("targetPath") ?: ""
                result.success(fileManager.moveFile(sourcePath, targetPath))
            }
            "deleteFile" -> {
                val path = call.argument<String>("path") ?: ""
                result.success(fileManager.deleteFile(path))
            }
            "getFileInfo" -> {
                val path = call.argument<String>("path") ?: ""
                result.success(fileManager.getFileInfo(path))
            }
            "calculateMD5" -> {
                val path = call.argument<String>("path") ?: ""
                result.success(fileManager.calculateMD5(path))
            }
            "createFile" -> {
                val path = call.argument<String>("path") ?: ""
                result.success(fileManager.createFile(path))
            }
            "fileExists" -> {
                val path = call.argument<String>("path") ?: ""
                result.success(fileManager.exists(path))
            }
            "getMimeType" -> {
                val path = call.argument<String>("path") ?: ""
                result.success(fileManager.getMimeType(path))
            }
            "truncateFile" -> {
                val path = call.argument<String>("path") ?: ""
                val size = call.argument<Long>("size") ?: 0
                result.success(fileManager.truncateFile(path, size))
            }

            // 目录操作相关方法
            "listDirectory" -> {
                val path = call.argument<String>("path") ?: ""
                val recursive = call.argument<Boolean>("recursive") ?: false
                result.success(directoryManager.listDirectory(path, recursive))
            }
            "createDirectory" -> {
                val path = call.argument<String>("path")!!
                val recursive = call.argument<Boolean>("recursive") ?: false
                Log.d("ExternalStorage", "Creating directory: $path (recursive: $recursive)")
                
                val createResult = directoryManager.createDirectory(path, recursive)
                Log.d("ExternalStorage", "Create directory result: $createResult")
                
                result.success(createResult)
            }
            "deleteDirectory" -> {
                val path = call.argument<String>("path") ?: ""
                val recursive = call.argument<Boolean>("recursive") ?: false
                result.success(directoryManager.deleteDirectory(path, recursive))
            }
            "moveDirectory" -> {
                val sourcePath = call.argument<String>("sourcePath") ?: ""
                val targetPath = call.argument<String>("targetPath") ?: ""
                result.success(directoryManager.moveDirectory(sourcePath, targetPath))
            }
            "copyDirectory" -> {
                val sourcePath = call.argument<String>("sourcePath") ?: ""
                val targetPath = call.argument<String>("targetPath") ?: ""
                result.success(directoryManager.copyDirectory(sourcePath, targetPath))
            }
            "getDirectoryInfo" -> {
                val path = call.argument<String>("path") ?: ""
                result.success(directoryManager.getDirectoryInfo(path))
            }
            "isDirectoryEmpty" -> {
                val path = call.argument<String>("path") ?: ""
                result.success(directoryManager.isDirectoryEmpty(path))
            }
            "getDirectorySize" -> {
                val path = call.argument<String>("path") ?: ""
                result.success(directoryManager.getDirectorySize(path))
            }
            "directoryExists" -> {
                val path = call.argument<String>("path") ?: ""
                result.success(directoryManager.exists(path))
            }

            // 文件系统监听相关方法
            "startWatching" -> {
                val path = call.argument<String>("path") ?: ""
                val recursive = call.argument<Boolean>("recursive") ?: false
                val eventMask = call.argument<Int>("eventMask") ?: FileSystemWatcher.EVENTS_ALL
                
                fileSystemWatcher.startWatching(
                    path = path,
                    recursive = recursive,
                    eventMask = eventMask
                ) { event -> // 接收 WatchEvent 类型的参数
                    // 将事件通过 channel 发送到 Flutter 端
                    channel.invokeMethod("onFileSystemEvent", event.toMap())
                }
                result.success(mapOf("success" to true))
            }
            "stopWatching" -> {
                val path = call.argument<String>("path") ?: ""
                fileSystemWatcher.stopWatching(path)
                result.success(mapOf("success" to true))
            }

            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        fileSystemWatcher.dispose()
    }
}