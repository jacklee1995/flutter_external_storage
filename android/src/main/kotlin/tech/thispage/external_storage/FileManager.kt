package tech.thispage.external_storage

import android.content.Context
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.DocumentsContract
import java.io.*
import java.nio.channels.FileChannel
import java.security.MessageDigest
import kotlin.math.min

class FileManager(private val context: Context) {
    companion object {
        private const val BUFFER_SIZE = 8192
    }

    /**
     * 读取文件内容
     */
    fun readFile(path: String, offset: Long = 0, length: Long = -1): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        var inputStream: FileInputStream? = null
        
        try {
            val file = File(path)
            if (!file.exists() || !file.isFile) {
                result["success"] = false
                result["error"] = "File does not exist or is not a file"
                return result
            }

            inputStream = FileInputStream(file)
            
            // 处理偏移量
            if (offset > 0) {
                inputStream.skip(offset)
            }
            
            // 确定读取长度
            val fileLength = file.length()
            val readLength = if (length > 0) min(length, fileLength - offset) else fileLength - offset
            
            // 读取数据
            val buffer = ByteArray(readLength.toInt())
            val bytesRead = inputStream.read(buffer)
            
            result["success"] = true
            result["data"] = buffer.copyOf(bytesRead)
            result["bytesRead"] = bytesRead
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        } finally {
            inputStream?.close()
        }
        
        return result
    }

    /**
     * 写入文件内容
     */
    fun writeFile(path: String, data: ByteArray, append: Boolean = false): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        var outputStream: FileOutputStream? = null
        
        try {
            val file = File(path)
            
            // 确保父目录存在
            file.parentFile?.mkdirs()
            
            outputStream = FileOutputStream(file, append)
            outputStream.write(data)
            outputStream.flush()
            
            result["success"] = true
            result["bytesWritten"] = data.size
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        } finally {
            outputStream?.close()
        }
        
        return result
    }

    /**
     * 复制文件
     */
    fun copyFile(sourcePath: String, targetPath: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        var sourceChannel: FileChannel? = null
        var targetChannel: FileChannel? = null
        
        try {
            val sourceFile = File(sourcePath)
            val targetFile = File(targetPath)
            
            if (!sourceFile.exists()) {
                result["success"] = false
                result["error"] = "Source file does not exist"
                return result
            }
            
            // 确保目标父目录存在
            targetFile.parentFile?.mkdirs()
            
            sourceChannel = FileInputStream(sourceFile).channel
            targetChannel = FileOutputStream(targetFile).channel
            
            val transferred = targetChannel.transferFrom(sourceChannel, 0, sourceFile.length())
            
            result["success"] = true
            result["bytesTransferred"] = transferred
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        } finally {
            sourceChannel?.close()
            targetChannel?.close()
        }
        
        return result
    }

    /**
     * 移动文件
     */
    fun moveFile(sourcePath: String, targetPath: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val sourceFile = File(sourcePath)
            val targetFile = File(targetPath)
            
            if (!sourceFile.exists()) {
                result["success"] = false
                result["error"] = "Source file does not exist"
                return result
            }
            
            // 确保目标父目录存在
            targetFile.parentFile?.mkdirs()
            
            // 尝试直接重命名
            if (sourceFile.renameTo(targetFile)) {
                result["success"] = true
                return result
            }
            
            // 如果重命名失败，尝试复制后删除
            val copyResult = copyFile(sourcePath, targetPath)
            if (copyResult["success"] as Boolean) {
                sourceFile.delete()
                result["success"] = true
            } else {
                result["success"] = false
                result["error"] = copyResult["error"] as? String ?: "Unknown error"
            }
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }

    /**
     * 删除文件
     */
    fun deleteFile(path: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val file = File(path)
            
            if (!file.exists()) {
                result["success"] = false
                result["error"] = "File does not exist"
                return result
            }
            
            if (!file.isFile) {
                result["success"] = false
                result["error"] = "Path is not a file"
                return result
            }
            
            result["success"] = file.delete()
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }

    /**
     * 获取文件信息
     */
    fun getFileInfo(path: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val file = File(path)
            
            if (!file.exists()) {
                result["success"] = false
                result["error"] = "File does not exist"
                return result
            }
            
            val info = HashMap<String, Any>()
            info["name"] = file.name
            info["path"] = file.absolutePath
            info["size"] = file.length()
            info["lastModified"] = file.lastModified()
            info["isDirectory"] = file.isDirectory
            info["isFile"] = file.isFile
            info["canRead"] = file.canRead()
            info["canWrite"] = file.canWrite()
            info["canExecute"] = file.canExecute()
            info["isHidden"] = file.isHidden()
            
            result["success"] = true
            result["info"] = info
            
        } catch (e: Exception) {
            e.printStackTrace()
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }

    /**
     * 计算文件 MD5
     */
    fun calculateMD5(path: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        var inputStream: FileInputStream? = null
        
        try {
            val file = File(path)
            
            if (!file.exists() || !file.isFile) {
                result["success"] = false
                result["error"] = "File does not exist or is not a file"
                return result
            }
            
            inputStream = FileInputStream(file)
            val buffer = ByteArray(BUFFER_SIZE)
            val md5Digest = MessageDigest.getInstance("MD5")
            var bytesRead: Int
            
            while (inputStream.read(buffer).also { bytesRead = it } != -1) {
                md5Digest.update(buffer, 0, bytesRead)
            }
            
            val md5Bytes = md5Digest.digest()
            val md5String = md5Bytes.joinToString("") { 
                String.format("%02x", it) 
            }
            
            result["success"] = true
            result["md5"] = md5String
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        } finally {
            inputStream?.close()
        }
        
        return result
    }

    /**
     * 创建文件
     */
    fun createFile(path: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val file = File(path)
            
            if (file.exists()) {
                result["success"] = false
                result["error"] = "File already exists"
                return result
            }
            
            // 确保父目录存在
            file.parentFile?.mkdirs()
            
            result["success"] = file.createNewFile()
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }

    /**
     * 检查文件是否存在
     */
    fun exists(path: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val file = File(path)
            result["success"] = true
            result["exists"] = file.exists()
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }

    /**
     * 获取文件 MIME 类型
     */
    fun getMimeType(path: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        
        try {
            val file = File(path)
            if (!file.exists() || !file.isFile) {
                result["success"] = false
                result["error"] = "File does not exist or is not a file"
                return result
            }
            
            val mimeType = context.contentResolver.getType(Uri.fromFile(file))
            result["success"] = true
            result["mimeType"] = mimeType ?: ""
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }
        
        return result
    }

    /**
     * 截断文件
     */
    fun truncateFile(path: String, size: Long): HashMap<String, Any> {
        val result = HashMap<String, Any>()
        var randomAccessFile: RandomAccessFile? = null
        
        try {
            val file = File(path)
            if (!file.exists() || !file.isFile) {
                result["success"] = false
                result["error"] = "File does not exist or is not a file"
                return result
            }
            
            randomAccessFile = RandomAccessFile(file, "rw")
            randomAccessFile.setLength(size)
            
            result["success"] = true
            
        } catch (e: Exception) {
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        } finally {
            randomAccessFile?.close()
        }
        
        return result
    }
}
