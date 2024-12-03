package tech.thispage.external_storage

import android.content.Context
import android.os.FileObserver
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import java.io.File
import java.util.Collections
import java.util.concurrent.ConcurrentHashMap

class FileSystemWatcher(private val context: Context) {
    private val observers = Collections.synchronizedMap(mutableMapOf<String, RecursiveFileObserver>())
    private val callbacks = ConcurrentHashMap<String, (WatchEvent) -> Unit>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val backgroundThread = HandlerThread("FileSystemWatcher").apply { start() }
    private val backgroundHandler = Handler(backgroundThread.looper)
    private var eventMask: Int = EVENTS_ALL

    companion object {
        const val EVENTS_ALL = FileObserver.ALL_EVENTS
        const val EVENTS_ACCESS = FileObserver.ACCESS
        const val EVENTS_MODIFY = FileObserver.MODIFY
        const val EVENTS_ATTRIB = FileObserver.ATTRIB
        const val EVENTS_CLOSE_WRITE = FileObserver.CLOSE_WRITE
        const val EVENTS_CLOSE_NOWRITE = FileObserver.CLOSE_NOWRITE
        const val EVENTS_OPEN = FileObserver.OPEN
        const val EVENTS_MOVED_FROM = FileObserver.MOVED_FROM
        const val EVENTS_MOVED_TO = FileObserver.MOVED_TO
        const val EVENTS_CREATE = FileObserver.CREATE
        const val EVENTS_DELETE = FileObserver.DELETE
        const val EVENTS_DELETE_SELF = FileObserver.DELETE_SELF
        const val EVENTS_MOVE_SELF = FileObserver.MOVE_SELF
    }

    fun startWatching(
        path: String,
        recursive: Boolean = false,
        eventMask: Int = EVENTS_ALL,
        callback: (WatchEvent) -> Unit
    ): HashMap<String, Any> {
        val result = HashMap<String, Any>()

        try {
            val file = File(path)
            if (!file.exists()) {
                result["success"] = false
                result["error"] = "Path does not exist"
                return result
            }

            if (!file.canRead()) {
                result["success"] = false
                result["error"] = "Cannot read path"
                return result
            }

            stopWatching(path)

            backgroundHandler.post {
                try {
                    val observer = RecursiveFileObserver(
                        path = path,
                        eventMask = eventMask,
                        recursive = recursive
                    ) { event -> 
                        mainHandler.post {
                            try {
                                callback(WatchEvent(event, path))
                            } catch (e: Exception) {
                                e.printStackTrace()
                            }
                        }
                    }

                    observer.startWatching()
                    observers[path] = observer
                    callbacks[path] = callback

                    mainHandler.post {
                        result["success"] = true
                        result["watchId"] = path
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                    mainHandler.post {
                        result["success"] = false
                        result["error"] = e.message ?: "Unknown error"
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }

        return result
    }

    fun stopWatching(path: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()

        try {
            observers[path]?.let { observer ->
                backgroundHandler.post {
                    try {
                        observer.stopWatching()
                        observers.remove(path)
                        callbacks.remove(path)
                        mainHandler.post {
                            result["success"] = true
                        }
                    } catch (e: Exception) {
                        e.printStackTrace()
                        mainHandler.post {
                            result["success"] = false
                            result["error"] = e.message ?: "Unknown error"
                        }
                    }
                }
            } ?: run {
                result["success"] = false
                result["error"] = "No observer found for path"
            }
        } catch (e: Exception) {
            e.printStackTrace()
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }

        return result
    }

    private inner class RecursiveFileObserver(
        private val path: String,
        private val eventMask: Int,
        private val recursive: Boolean,
        private val callback: (Int) -> Unit
    ) : FileObserver(path, eventMask) {
        private val childObservers = Collections.synchronizedMap(mutableMapOf<String, RecursiveFileObserver>())

        override fun onEvent(event: Int, path: String?) {
            if (path == null) return

            try {
                val filteredEvent = event and eventMask
                if (filteredEvent == 0) return
                
                mainHandler.post {
                    try {
                        callback(filteredEvent)
                    } catch (e: Exception) {
                        e.printStackTrace()
                    }
                }

                if (recursive && filteredEvent == CREATE) {
                    backgroundHandler.post {
                        try {
                            val newPath = File(this.path, path)
                            if (newPath.isDirectory && newPath.canRead()) {
                                val observer = RecursiveFileObserver(
                                    path = newPath.absolutePath,
                                    eventMask = this.eventMask,
                                    recursive = true,
                                    callback = callback
                                )
                                observer.startWatching()
                                childObservers[newPath.absolutePath] = observer
                            }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        override fun startWatching() {
            try {
                super.startWatching()
                if (recursive) {
                    backgroundHandler.post {
                        try {
                            File(path).walkTopDown()
                                .filter { it.isDirectory && it.canRead() }
                                .forEach { dir ->
                                    if (dir.absolutePath != path) {
                                        val observer = RecursiveFileObserver(
                                            path = dir.absolutePath,
                                            eventMask = this.eventMask,
                                            recursive = true,
                                            callback = callback
                                        )
                                        observer.startWatching()
                                        childObservers[dir.absolutePath] = observer
                                    }
                                }
                        } catch (e: Exception) {
                            e.printStackTrace()
                        }
                    }
                }
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }

        override fun stopWatching() {
            try {
                super.stopWatching()
                childObservers.values.forEach { it.stopWatching() }
                childObservers.clear()
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    data class WatchEvent(
        val eventType: Int,
        val path: String
    ) {
        fun toMap(): Map<String, Any> {
            return mapOf(
                "eventType" to eventType,
                "path" to path,
                "eventName" to getEventName(eventType)
            )
        }

        private fun getEventName(event: Int): String {
            return when (event) {
                EVENTS_ACCESS -> "ACCESS"
                EVENTS_MODIFY -> "MODIFY"
                EVENTS_ATTRIB -> "ATTRIB"
                EVENTS_CLOSE_WRITE -> "CLOSE_WRITE"
                EVENTS_CLOSE_NOWRITE -> "CLOSE_NOWRITE"
                EVENTS_OPEN -> "OPEN"
                EVENTS_MOVED_FROM -> "MOVED_FROM"
                EVENTS_MOVED_TO -> "MOVED_TO"
                EVENTS_CREATE -> "CREATE"
                EVENTS_DELETE -> "DELETE"
                EVENTS_DELETE_SELF -> "DELETE_SELF"
                EVENTS_MOVE_SELF -> "MOVE_SELF"
                else -> "UNKNOWN"
            }
        }
    }

    fun dispose() {
        try {
            stopAllWatching()
            mainHandler.removeCallbacksAndMessages(null)
            backgroundHandler.removeCallbacksAndMessages(null)
            backgroundThread.quitSafely()
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    fun stopAllWatching(): HashMap<String, Any> {
        val result = HashMap<String, Any>()

        try {
            backgroundHandler.post {
                try {
                    observers.forEach { (_, observer) ->
                        observer.stopWatching()
                    }
                    observers.clear()
                    callbacks.clear()
                    mainHandler.post {
                        result["success"] = true
                    }
                } catch (e: Exception) {
                    e.printStackTrace()
                    mainHandler.post {
                        result["success"] = false
                        result["error"] = e.message ?: "Unknown error"
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }

        return result
    }

    fun getWatchedPaths(): HashMap<String, Any> {
        val result = HashMap<String, Any>()

        try {
            result["success"] = true
            result["paths"] = observers.keys.toList()
        } catch (e: Exception) {
            e.printStackTrace()
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }

        return result
    }

    fun isWatching(path: String): HashMap<String, Any> {
        val result = HashMap<String, Any>()

        try {
            result["success"] = true
            result["watching"] = observers.containsKey(path)
        } catch (e: Exception) {
            e.printStackTrace()
            result["success"] = false
            result["error"] = e.message ?: "Unknown error"
        }

        return result
    }
}