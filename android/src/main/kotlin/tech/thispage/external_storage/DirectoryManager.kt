package tech.thispage.external_storage

import android.content.Context
import android.os.Environment
import android.os.StatFs
import android.util.Log
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

class DirectoryManager(private val context: Context) {
    companion object {
        private const val DATE_FORMAT = "yyyy-MM-dd HH:mm:ss"
    }

    /**
     * 列出目录内容
     */
    fun listDirectory(path: String, recursive: Boolean = false): Map<String, Any> {
        val result = HashMap<String, Any>()
        try {
            val entries = mutableListOf<Map<String, Any>>()
            val directory = File(path)
            
            if (!directory.exists() || !directory.isDirectory) {
                result["entries"] = entries
                return result
            }
    
            directory.listFiles()?.forEach { file ->
                try {
                    entries.add(mapOf(
                        "name" to (file.name ?: ""),
                        "path" to (file.absolutePath ?: ""),
                        "size" to (file.length() ?: 0L),
                        "lastModified" to (file.lastModified() ?: 0L),
                        "isDirectory" to file.isDirectory,
                        "isFile" to file.isFile,
                        "canRead" to file.canRead(),
                        "canWrite" to file.canWrite(),
                        "canExecute" to file.canExecute(),
                        "isHidden" to file.isHidden()
                    ))
                } catch (e: Exception) {
                    Log.e("DirectoryManager", "Error processing file: ${file.absolutePath}", e)
                }
            }
            
            result["entries"] = entries
        } catch (e: Exception) {
            Log.e("DirectoryManager", "Error listing directory: $path", e)
            result["entries"] = listOf<Map<String, Any>>()
        }
        return result
    }

    private fun listDirectoryContents(
        directory: File,
        entries: MutableList<HashMap<String, Any>>,
        recursive: Boolean,
        basePath: String = directory.path
    ) {
        directory.listFiles()?.forEach { file ->
            val entry = HashMap<String, Any>()
            entry["name"] = file.name
            entry["path"] = file.absolutePath
            entry["relativePath"] = file.absolutePath.substring(basePath.length + 1)
            entry["isDirectory"] = file.isDirectory
            entry["isFile"] = file.isFile
            entry["isHidden"] = file.isHidden()
            entry["lastModified"] = SimpleDateFormat(DATE_FORMAT, Locale.getDefault())
                .format(Date(file.lastModified()))
            entry["canRead"] = file.canRead()
            entry["canWrite"] = file.canWrite()
            entry["canExecute"] = file.canExecute()

            if (file.isFile) {
                entry["size"] = file.length()
            }

            entries.add(entry)

            if (recursive && file.isDirectory) {
                listDirectoryContents(file, entries, true, basePath)
            }
        }
    }

    /**
     * 创建目录
     */
    fun createDirectory(path: String, recursive: Boolean = false): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        try {
            val directory = File(path)
            
            if (directory.exists()) {
                result["success"] = false
                result["error"] = "Directory already exists"
                return result
            }
            
            val success = if (recursive) {
                directory.mkdirs()
            } else {
                directory.mkdir()
            }
            
            result["success"] = success
            if (!success) {
                result["error"] = "Failed to create directory"
            }
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        return result
    }

    /**
     * 删除目录
     */
    fun deleteDirectory(path: String, recursive: Boolean = false): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val directory = File(path)
            
            if (!directory.exists()) {
                result["success"] = false
                result["error"] = "Directory does not exist"
                return result
            }
            
            if (!directory.isDirectory) {
                result["success"] = false
                result["error"] = "Path is not a directory"
                return result
            }
            
            val success = if (recursive) {
                directory.deleteRecursively()
            } else {
                directory.delete()
            }
            
            result["success"] = success
            if (!success) {
                result["error"] = "Failed to delete directory"
            }
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }

    /**
     * 移动目录
     */
    fun moveDirectory(sourcePath: String, targetPath: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val sourceDir = File(sourcePath)
            val targetDir = File(targetPath)
            
            if (!sourceDir.exists()) {
                result["success"] = false
                result["error"] = "Source directory does not exist"
                return result
            }
            
            if (!sourceDir.isDirectory) {
                result["success"] = false
                result["error"] = "Source path is not a directory"
                return result
            }
            
            if (targetDir.exists()) {
                result["success"] = false
                result["error"] = "Target directory already exists"
                return result
            }
            
            // 确保目标父目录存在
            targetDir.parentFile?.mkdirs()
            
            val success = sourceDir.renameTo(targetDir)
            result["success"] = success
            if (!success) {
                result["error"] = "Failed to move directory"
            }
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }

    /**
     * 复制目录
     */
    fun copyDirectory(sourcePath: String, targetPath: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val sourceDir = File(sourcePath)
            val targetDir = File(targetPath)
            
            if (!sourceDir.exists()) {
                result["success"] = false
                result["error"] = "Source directory does not exist"
                return result
            }
            
            if (!sourceDir.isDirectory) {
                result["success"] = false
                result["error"] = "Source path is not a directory"
                return result
            }
            
            if (targetDir.exists()) {
                result["success"] = false
                result["error"] = "Target directory already exists"
                return result
            }
            
            copyDirectoryContents(sourceDir, targetDir)
            result["success"] = true
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }

    private fun copyDirectoryContents(source: File, target: File) {
        target.mkdirs()
        
        source.listFiles()?.forEach { file ->
            val targetFile = File(target, file.name)
            
            if (file.isDirectory) {
                copyDirectoryContents(file, targetFile)
            } else {
                file.inputStream().use { input ->
                    targetFile.outputStream().use { output ->
                        input.copyTo(output)
                    }
                }
            }
        }
    }

    /**
     * 获取目录信息
     */
    fun getDirectoryInfo(path: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val directory = File(path)
            
            if (!directory.exists()) {
                result["success"] = false
                result["error"] = "Directory does not exist"
                return result
            }
            
            if (!directory.isDirectory) {
                result["success"] = false
                result["error"] = "Path is not a directory"
                return result
            }
            
            val stats = StatFs(directory.path)
            
            result["success"] = true
            result["path"] = directory.absolutePath
            result["name"] = directory.name
            result["parent"] = directory.parent
            result["lastModified"] = SimpleDateFormat(DATE_FORMAT, Locale.getDefault())
                .format(Date(directory.lastModified()))
            result["canRead"] = directory.canRead()
            result["canWrite"] = directory.canWrite()
            result["canExecute"] = directory.canExecute()
            result["isHidden"] = directory.isHidden()
            result["totalSpace"] = stats.totalBytes
            result["freeSpace"] = stats.freeBytes
            result["usableSpace"] = stats.availableBytes
            
            // 计算子项数量
            val children = directory.listFiles()
            result["fileCount"] = children?.count { it.isFile } ?: 0
            result["directoryCount"] = children?.count { it.isDirectory } ?: 0
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }

    /**
     * 检查目录是否为空
     */
    fun isDirectoryEmpty(path: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val directory = File(path)
            
            if (!directory.exists()) {
                result["success"] = false
                result["error"] = "Directory does not exist"
                return result
            }
            
            if (!directory.isDirectory) {
                result["success"] = false
                result["error"] = "Path is not a directory"
                return result
            }
            
            result["success"] = true
            result["isEmpty"] = directory.listFiles()?.isEmpty() ?: true
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }

    /**
     * 获取目录大小
     */
    fun getDirectorySize(path: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val directory = File(path)
            
            if (!directory.exists()) {
                result["success"] = false
                result["error"] = "Directory does not exist"
                return result
            }
            
            if (!directory.isDirectory) {
                result["success"] = false
                result["error"] = "Path is not a directory"
                return result
            }
            
            result["success"] = true
            result["size"] = calculateDirectorySize(directory)
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }

    private fun calculateDirectorySize(directory: File): Long {
        var size = 0L
        
        directory.listFiles()?.forEach { file ->
            size += if (file.isDirectory) {
                calculateDirectorySize(file)
            } else {
                file.length()
            }
        }
        
        return size
    }

    /**
     * 检查目录是否存在
     */
    fun exists(path: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val directory = File(path)
            result["success"] = true
            result["exists"] = directory.exists() && directory.isDirectory
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }
}