package tech.thispage.external_storage

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * 原生端只负责 Dart (dart:io) 做不到的事：枚举存储卷、卷容量、存储权限、inotify 文件监视。
 * 文件和目录的读写、复制等操作都在 Dart 侧完成。
 */
class ExternalStoragePlugin : FlutterPlugin, MethodCallHandler, ActivityAware,
    FileSystemWatcher.Listener {
    companion object {
        const val CHANNEL = "tech.thispage.external_storage"
        private const val TAG = "ExternalStorage"

        /** 可能阻塞（StatFs 访问慢速 U 盘等），在后台线程执行。 */
        val IO_METHODS = setOf("getAllStorageDevices", "getStorageSpace")

        /** 必须在主线程执行（依赖 Activity 或监视器状态）。 */
        val MAIN_METHODS = setOf(
            "startWatching", "stopWatching", "stopAllWatching", "getWatchedPaths", "isWatching",
            "checkStoragePermissions", "requestStoragePermissions",
            "shouldShowRequestPermissionRationale", "openAppSettings",
            "checkPermission", "getGrantedPermissions",
        )
    }

    private lateinit var channel: MethodChannel
    private lateinit var storageInfoManager: StorageInfoManager
    private lateinit var fileSystemWatcher: FileSystemWatcher
    private lateinit var permissionManager: PermissionManager
    private lateinit var ioExecutor: ExecutorService
    private val mainHandler = Handler(Looper.getMainLooper())
    private var activityBinding: ActivityPluginBinding? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val context: Context = binding.applicationContext
        storageInfoManager = StorageInfoManager(context)
        fileSystemWatcher = FileSystemWatcher(this)
        permissionManager = PermissionManager(context)
        ioExecutor = Executors.newCachedThreadPool()

        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        fileSystemWatcher.dispose()
        ioExecutor.shutdown()
    }

    // region ActivityAware
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activityBinding = binding
        permissionManager.activity = binding.activity
        binding.addRequestPermissionsResultListener(permissionManager)
        binding.addActivityResultListener(permissionManager)
    }

    // 配置变更（旋转、切换深色模式等）时 Activity 会重建：保留进行中的权限请求，
    // 结果会投递给重建后的 Activity。
    override fun onDetachedFromActivityForConfigChanges() = detachActivity(cancelPending = false)

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onDetachedFromActivity() = detachActivity(cancelPending = true)

    private fun detachActivity(cancelPending: Boolean) {
        activityBinding?.removeRequestPermissionsResultListener(permissionManager)
        activityBinding?.removeActivityResultListener(permissionManager)
        activityBinding = null
        permissionManager.activity = null
        if (cancelPending) permissionManager.cancelPending()
    }
    // endregion

    // region FileSystemWatcher.Listener
    override fun onEvent(event: Map<String, Any>) {
        channel.invokeMethod("onFileSystemEvent", event)
    }

    override fun onWatchDone(watchId: String) {
        channel.invokeMethod("onWatchDone", mapOf("watchId" to watchId))
    }
    // endregion

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            in IO_METHODS -> ioExecutor.execute {
                val outcome = runCatching { handleIo(call) }
                mainHandler.post { reply(call, result, outcome) }
            }
            in MAIN_METHODS -> {
                try {
                    handleMain(call, result)
                } catch (e: PermissionManager.PermissionException) {
                    result.error(e.code, e.message, null)
                } catch (e: Exception) {
                    reply(call, result, kotlin.Result.failure(e))
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun reply(call: MethodCall, result: Result, outcome: kotlin.Result<Any?>) {
        outcome
            .onSuccess { result.success(it) }
            .onFailure { e ->
                Log.e(TAG, "${call.method} failed", e)
                result.error("NATIVE_ERROR", "${call.method}: ${e.message}", e.javaClass.name)
            }
    }

    private fun handleIo(call: MethodCall): Any? = when (call.method) {
        "getAllStorageDevices" -> storageInfoManager.getAllStorageDevices()
        "getStorageSpace" -> storageInfoManager.getStorageSpace(call.path())
        else -> throw IllegalStateException("Unhandled IO method ${call.method}")
    }

    private fun handleMain(call: MethodCall, result: Result) {
        when (call.method) {
            "startWatching" -> result.success(startWatching(call))
            "stopWatching" -> result.success(
                mapOf("success" to fileSystemWatcher.stop(call.watchId()))
            )
            "stopAllWatching" -> {
                fileSystemWatcher.stopAll()
                result.success(mapOf("success" to true))
            }
            "getWatchedPaths" -> result.success(
                mapOf("success" to true, "paths" to fileSystemWatcher.watchedPaths())
            )
            "isWatching" -> result.success(
                mapOf("success" to true, "watching" to fileSystemWatcher.isWatching(call.path()))
            )

            "checkStoragePermissions" -> result.success(
                mapOf("hasPermission" to permissionManager.hasStoragePermissions())
            )
            "requestStoragePermissions" -> permissionManager.requestStoragePermissions { granted ->
                result.success(mapOf("success" to granted))
            }
            "shouldShowRequestPermissionRationale" -> result.success(
                mapOf("shouldShow" to permissionManager.shouldShowRequestPermissionRationale())
            )
            "openAppSettings" -> result.success(mapOf("success" to permissionManager.openAppSettings()))
            "checkPermission" -> result.success(
                mapOf("hasPermission" to permissionManager.checkPermission(call.string("permission")))
            )
            "getGrantedPermissions" -> result.success(
                mapOf("permissions" to permissionManager.getGrantedPermissions())
            )

            else -> result.notImplemented()
        }
    }

    private fun startWatching(call: MethodCall): Map<String, Any> = try {
        fileSystemWatcher.start(
            id = call.watchId(),
            path = call.path(),
            recursive = call.recursive(),
            mask = call.long("eventMask")?.toInt() ?: 0,
        )
        mapOf("success" to true)
    } catch (e: IllegalArgumentException) {
        mapOf("success" to false, "error" to (e.message ?: "Cannot watch path"))
    }
}

private fun MethodCall.string(key: String): String =
    argument<String>(key) ?: throw IllegalArgumentException("Missing argument '$key'")

private fun MethodCall.path(): String = string("path")

/** 旧版 Dart 端只传 path，以 path 作为监视 id。 */
private fun MethodCall.watchId(): String = argument<String>("watchId") ?: path()

private fun MethodCall.recursive(): Boolean = argument<Boolean>("recursive") ?: false

/** Dart int 在通道上可能是 Int 或 Long，统一按 Number 读取。 */
private fun MethodCall.long(key: String): Long? = argument<Number>(key)?.toLong()
