package tech.thispage.external_storage

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import io.flutter.plugin.common.PluginRegistry

/**
 * 存储权限管理。
 *
 * - API 30+：以「所有文件访问权限」(MANAGE_EXTERNAL_STORAGE) 为准，请求时跳转系统设置页。
 * - API 23-29：运行时请求 READ/WRITE_EXTERNAL_STORAGE。
 * - API < 23：安装时授予。
 *
 * 宿主 App 必须在自己的 AndroidManifest.xml 中声明所需权限，否则请求必然失败。
 */
class PermissionManager(private val context: Context) :
    PluginRegistry.RequestPermissionsResultListener,
    PluginRegistry.ActivityResultListener {

    companion object {
        // FragmentActivity 只接受低 16 位的 requestCode。
        const val REQUEST_CODE_RUNTIME = 0x4553
        const val REQUEST_CODE_MANAGE_STORAGE = 0x4554
        const val MANAGE_EXTERNAL_STORAGE = "android.permission.MANAGE_EXTERNAL_STORAGE"

        private val LEGACY_PERMISSIONS = arrayOf(
            Manifest.permission.READ_EXTERNAL_STORAGE,
            Manifest.permission.WRITE_EXTERNAL_STORAGE,
        )
    }

    class PermissionException(val code: String, message: String) : Exception(message)

    var activity: Activity? = null

    private var pendingCallback: ((Boolean) -> Unit)? = null

    fun hasStoragePermissions(): Boolean = when {
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.R -> Environment.isExternalStorageManager()
        Build.VERSION.SDK_INT >= Build.VERSION_CODES.M ->
            LEGACY_PERMISSIONS.all { isGranted(it) }
        else -> true
    }

    /**
     * 发起权限请求；结果通过 [onResult] 回调（主线程）。
     * 已有权限时立即回调 true。
     */
    @Throws(PermissionException::class)
    fun requestStoragePermissions(onResult: (Boolean) -> Unit) {
        if (hasStoragePermissions()) {
            onResult(true)
            return
        }
        val currentActivity = activity
            ?: throw PermissionException("NO_ACTIVITY", "Permission requests require a foreground Activity.")
        if (pendingCallback != null) {
            throw PermissionException("REQUEST_IN_PROGRESS", "Another permission request is already running.")
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            if (!isDeclaredInManifest(MANAGE_EXTERNAL_STORAGE)) {
                throw PermissionException(
                    "PERMISSION_NOT_DECLARED",
                    "Declare $MANAGE_EXTERNAL_STORAGE in the app's AndroidManifest.xml."
                )
            }
            pendingCallback = onResult
            try {
                currentActivity.startActivityForResult(manageStorageIntent(), REQUEST_CODE_MANAGE_STORAGE)
            } catch (e: Exception) {
                try {
                    currentActivity.startActivityForResult(
                        Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION),
                        REQUEST_CODE_MANAGE_STORAGE
                    )
                } catch (inner: Exception) {
                    pendingCallback = null
                    throw PermissionException("SETTINGS_UNAVAILABLE", inner.message ?: "Cannot open settings.")
                }
            }
        } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            pendingCallback = onResult
            currentActivity.requestPermissions(LEGACY_PERMISSIONS, REQUEST_CODE_RUNTIME)
        } else {
            onResult(true)
        }
    }

    fun shouldShowRequestPermissionRationale(): Boolean {
        // API 30+ 的所有文件访问权限只能在设置页授予，没有运行时说明弹窗。
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R || Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return false
        }
        val currentActivity = activity ?: return false
        return LEGACY_PERMISSIONS.any { currentActivity.shouldShowRequestPermissionRationale(it) }
    }

    fun openAppSettings(): Boolean = try {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, packageUri())
        val launcher = activity
        if (launcher != null) {
            launcher.startActivity(intent)
        } else {
            context.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
        true
    } catch (e: Exception) {
        false
    }

    fun checkPermission(permission: String): Boolean {
        if (permission == MANAGE_EXTERNAL_STORAGE) {
            return Build.VERSION.SDK_INT >= Build.VERSION_CODES.R && Environment.isExternalStorageManager()
        }
        return isGranted(permission)
    }

    /** 返回宿主 App 在 Manifest 中声明且当前已授予的权限。 */
    fun getGrantedPermissions(): List<String> {
        val info = packageInfoWithPermissions() ?: return emptyList()
        val requested = info.requestedPermissions ?: return emptyList()
        return requested.filter { checkPermission(it) }
    }

    /** Activity 解绑时调用，避免悬挂的 Flutter Result。 */
    fun cancelPending() {
        pendingCallback?.invoke(hasStoragePermissions())
        pendingCallback = null
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != REQUEST_CODE_RUNTIME) return false
        deliver(hasStoragePermissions())
        return true
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode != REQUEST_CODE_MANAGE_STORAGE) return false
        deliver(hasStoragePermissions())
        return true
    }

    private fun deliver(granted: Boolean) {
        val callback = pendingCallback ?: return
        pendingCallback = null
        callback(granted)
    }

    private fun isGranted(permission: String): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            context.checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED
        } else {
            isDeclaredInManifest(permission)
        }

    private fun isDeclaredInManifest(permission: String): Boolean =
        packageInfoWithPermissions()?.requestedPermissions?.contains(permission) == true

    @Suppress("DEPRECATION")
    private fun packageInfoWithPermissions(): PackageInfo? = try {
        val pm = context.packageManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            pm.getPackageInfo(
                context.packageName,
                PackageManager.PackageInfoFlags.of(PackageManager.GET_PERMISSIONS.toLong())
            )
        } else {
            pm.getPackageInfo(context.packageName, PackageManager.GET_PERMISSIONS)
        }
    } catch (e: Exception) {
        null
    }

    private fun manageStorageIntent(): Intent =
        Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION, packageUri())

    private fun packageUri(): Uri = Uri.parse("package:${context.packageName}")
}
