package tech.thispage.external_storage

import android.content.Context
import android.os.Build
import android.os.Environment
import android.os.StatFs
import android.os.storage.StorageManager
import android.os.storage.StorageVolume
import android.util.Log
import androidx.annotation.RequiresApi
import java.io.File

/**
 * 枚举已挂载的存储卷（内部存储、SD 卡、USB OTG）。
 *
 * - API 30+：StorageVolume.directory
 * - API 24-29：getExternalFilesDirs 反推卷根目录，USB 卷回退到 /storage/<uuid>
 * - API < 24：扫描 /storage
 */
class StorageInfoManager(private val context: Context) {
    companion object {
        private const val TAG = "StorageInfoManager"
    }

    fun getAllStorageDevices(): List<HashMap<String, Any>> {
        val devices = try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) fromStorageVolumes() else legacyScan()
        } catch (e: Exception) {
            Log.w(TAG, "StorageManager enumeration failed, using legacy scan", e)
            legacyScan()
        }
        return devices.distinctBy { it["path"] }
    }

    /** 路径所在卷的容量（字节）。 */
    fun getStorageSpace(path: String): Map<String, Long> {
        val stat = StatFs(path)
        return mapOf(
            "totalSpace" to stat.totalBytes,
            "freeSpace" to stat.freeBytes,
            "usableSpace" to stat.availableBytes,
        )
    }

    @RequiresApi(Build.VERSION_CODES.N)
    private fun fromStorageVolumes(): List<HashMap<String, Any>> {
        val storageManager = context.getSystemService(Context.STORAGE_SERVICE) as StorageManager
        val appDirRoots = appSpecificVolumeRoots()

        return storageManager.storageVolumes
            .filter { it.state == Environment.MEDIA_MOUNTED || it.state == Environment.MEDIA_MOUNTED_READ_ONLY }
            .mapNotNull { volume ->
                val path = volumePath(volume, storageManager, appDirRoots) ?: return@mapNotNull null
                buildInfo(
                    path = path,
                    isPrimary = volume.isPrimary,
                    isRemovable = volume.isRemovable,
                    isReadOnly = volume.state == Environment.MEDIA_MOUNTED_READ_ONLY,
                    uuid = volume.uuid,
                    description = volume.getDescription(context)
                )
            }
    }

    @RequiresApi(Build.VERSION_CODES.N)
    private fun volumePath(
        volume: StorageVolume,
        storageManager: StorageManager,
        appDirRoots: List<File>
    ): String? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return volume.directory?.path
        }
        if (volume.isPrimary) {
            @Suppress("DEPRECATION")
            return Environment.getExternalStorageDirectory().path
        }
        appDirRoots.firstOrNull { storageManager.getStorageVolume(it) == volume }?.let { return it.path }
        // USB OTG 等卷不在 getExternalFilesDirs 中，按惯例挂载在 /storage/<uuid>。
        return volume.uuid?.let { File("/storage", it) }?.takeIf { it.isDirectory }?.path
    }

    /** /storage/XXXX-XXXX/Android/data/<pkg>/files -> /storage/XXXX-XXXX */
    private fun appSpecificVolumeRoots(): List<File> =
        context.getExternalFilesDirs(null).filterNotNull().mapNotNull { dir ->
            val index = dir.absolutePath.indexOf("/Android/")
            if (index > 0) File(dir.absolutePath.substring(0, index)) else null
        }

    private fun legacyScan(): List<HashMap<String, Any>> {
        val devices = mutableListOf<HashMap<String, Any>>()

        @Suppress("DEPRECATION")
        val primary = Environment.getExternalStorageDirectory()
        val primaryReadOnly = Environment.getExternalStorageState() == Environment.MEDIA_MOUNTED_READ_ONLY
        buildInfo(primary.path, isPrimary = true, isRemovable = false, isReadOnly = primaryReadOnly)
            ?.let(devices::add)

        val primaryCanonical = runCatching { primary.canonicalPath }.getOrDefault(primary.path)
        File("/storage").listFiles()
            ?.filter { dir ->
                dir.isDirectory && dir.canRead() &&
                    dir.name != "emulated" && dir.name != "self" && dir.name != "sdcard0" &&
                    !runCatching { dir.canonicalPath }.getOrDefault(dir.path).startsWith(primaryCanonical)
            }
            ?.forEach { dir ->
                buildInfo(
                    dir.path, isPrimary = false, isRemovable = true,
                    isReadOnly = !dir.canWrite(), uuid = dir.name
                )?.let(devices::add)
            }
        return devices
    }

    private fun buildInfo(
        path: String,
        isPrimary: Boolean,
        isRemovable: Boolean,
        isReadOnly: Boolean,
        uuid: String? = null,
        description: String? = null
    ): HashMap<String, Any>? {
        val file = File(path)
        if (!file.exists()) return null

        return try {
            val stat = StatFs(path)
            if (stat.blockCountLong <= 0) return null
            HashMap<String, Any>().apply {
                put("path", path)
                // 优先使用系统按当前语言提供的卷名（如「内部共享存储空间」「SanDisk SD 卡」）。
                put("name", description ?: when {
                    isPrimary -> "内部存储"
                    isRemovable -> "SD卡"
                    else -> "外部存储"
                })
                put("isPrimary", isPrimary)
                put("isRemovable", isRemovable)
                put("totalSize", stat.totalBytes)
                put("availableSize", stat.availableBytes)
                put("isReadOnly", isReadOnly)
                uuid?.let { put("uuid", it) }
                description?.let { put("description", it) }
            }
        } catch (e: Exception) {
            Log.w(TAG, "StatFs failed for $path", e)
            null
        }
    }
}
