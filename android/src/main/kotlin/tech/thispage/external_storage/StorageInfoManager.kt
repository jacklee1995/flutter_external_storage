package tech.thispage.external_storage

import android.content.Context
import android.os.Environment
import android.os.storage.StorageManager
import android.os.StatFs
import java.io.File

class StorageInfoManager(private val context: Context) {
    // 获取所有外部存储设备信息
    fun getAllStorageDevices(): List<HashMap<String, Any>> {
        val devices = mutableListOf<HashMap<String, Any>>()
        
        try {
            val storageManager = context.getSystemService(Context.STORAGE_SERVICE) as StorageManager
            
            // 获取所有存储卷
            val volumes = storageManager.storageVolumes
            
            for (volume in volumes) {
                // 跳过未挂载的存储卷
                if (!volume.state.equals(Environment.MEDIA_MOUNTED)) {
                    continue
                }
                
                // 获取存储卷路径
                val path = volume.directory?.path ?: continue
                
                // 获取存储信息
                val info = getStorageInfo(path, volume.isPrimary, volume.isRemovable)
                if (info != null) {
                    devices.add(info)
                    println("Added storage volume: $info")
                }
            }
            
        } catch (e: Exception) {
            e.printStackTrace()
            // 如果使用 StorageManager 失败，回退到传统方法
            fallbackToLegacyMethod(devices)
        }
        
        println("Final storage devices: $devices")
        return devices
    }

    private fun getStorageInfo(
        path: String, 
        isPrimary: Boolean, 
        isRemovable: Boolean
    ): HashMap<String, Any>? {
        val file = File(path)
        if (!file.exists() || !file.canRead()) {
            return null
        }

        return try {
            val stat = StatFs(path)
            HashMap<String, Any>().apply {
                put("path", path)
                put("name", when {
                    isPrimary -> "内部存储"
                    isRemovable -> "SD卡"
                    else -> "外部存储"
                })
                put("isRemovable", isRemovable)
                put("totalSize", stat.blockSizeLong * stat.blockCountLong)
                put("availableSize", stat.blockSizeLong * stat.availableBlocksLong)
                put("isReadOnly", !file.canWrite())
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    // 传统方法作为备用
    private fun fallbackToLegacyMethod(devices: MutableList<HashMap<String, Any>>) {
        println("Falling back to legacy storage detection method")
        
        // 1. 添加内部存储
        val internalStorage = Environment.getExternalStorageDirectory().path
        getStorageInfo(internalStorage, true, false)?.let { 
            devices.add(it)
            println("Added internal storage: $it")
        }

        // 2. 检查可能的外部存储路径
        val potentialPaths = listOf(
            "/storage/sdcard1",  // 常见的SD卡路径
            "/storage/usbdisk",  // 常见的USB存储路径
            "/storage/usbotg"    // USB OTG路径
        )

        for (path in potentialPaths) {
            val file = File(path)
            if (file.exists() && file.canRead() && !file.path.startsWith(internalStorage)) {
                getStorageInfo(path, false, true)?.let {
                    devices.add(it)
                    println("Added external storage: $it")
                }
            }
        }

        // 3. 扫描 /storage 目录
        try {
            File("/storage").listFiles()?.forEach { file ->
                if (file.isDirectory && 
                    file.canRead() && 
                    !file.path.contains("emulated") && 
                    !file.path.contains("self") &&
                    !file.path.contains("sdcard0") &&
                    !file.canonicalPath.startsWith(internalStorage) &&
                    isValidStoragePath(file.path)) { // 添加路径有效性检查
                    
                    getStorageInfo(file.path, false, true)?.let {
                        devices.add(it)
                        println("Added storage from /storage scan: $it")
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    // 检查路径是否可用
    private fun isValidStoragePath(path: String): Boolean {
        val file = File(path)
        return file.exists() && 
               file.canRead() && 
               try {
                   StatFs(path).blockCountLong > 0
               } catch (e: Exception) {
                   false
               }
    }
}