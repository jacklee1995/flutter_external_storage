package tech.thispage.external_storage

import android.os.FileObserver
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper
import java.io.File

/**
 * 基于 inotify (FileObserver) 的文件监视。
 *
 * 每个监视有独立的 id，事件带发生变化的完整路径。递归监视会订阅每个子目录，之后新建或
 * 移入的子目录自动加入。监视根被删除、移走或所在卷被卸载后监视结束，并回调
 * [Listener.onWatchDone]。[Listener] 的回调都在主线程执行。
 *
 * 同一个 inode 上的多个 FileObserver 会共用 inotify 的 watch descriptor，后注册的会让先注册的
 * 收不到事件，停止任意一个也会停掉全部。所以每个目录只创建一个 FileObserver（[Node]），
 * 由所有订阅它的监视共享。
 */
class FileSystemWatcher(private val listener: Listener) {
    interface Listener {
        fun onEvent(event: Map<String, Any>)
        fun onWatchDone(watchId: String)
    }

    companion object {
        const val EVENTS_ALL = FileObserver.ALL_EVENTS
        private const val IN_UNMOUNT = 0x2000
        private const val IN_ISDIR = 0x40000000
        private const val SELF_EVENTS = FileObserver.DELETE_SELF or FileObserver.MOVE_SELF
        private const val GONE_EVENTS = FileObserver.DELETE or FileObserver.MOVED_FROM
        private const val NEW_EVENTS = FileObserver.CREATE or FileObserver.MOVED_TO

        // 列目录本身就会触发目录的 OPEN / CLOSE_NOWRITE。如果转发这些事件，
        // "收到事件就刷新列表" 的 App 会陷入死循环，所以目录自身只报告这几种事件。
        private const val DIR_SELF_EVENTS = SELF_EVENTS or FileObserver.ATTRIB

        /** inotify 一次回调可能带多个事件位，拆成单个事件，便于 Dart 端按枚举解析。 */
        fun splitEvents(mask: Int): List<Int> =
            (0 until 12).map { 1 shl it }.filter { (mask and it) != 0 }

        private fun keyOf(file: File): String =
            runCatching { file.canonicalPath }.getOrDefault(file.absolutePath)
    }

    private class Watch(val id: String, val root: File, val recursive: Boolean, val mask: Int) {
        val rootKey = keyOf(root)

        /** 订阅的目录：节点 key（规范路径）-> 本监视看到的路径。 */
        val dirs = HashMap<String, File>()

        /** 为 false 后不再订阅新的子目录。 */
        @Volatile var active = true

        /** 被主动停止，尚未投递的事件直接丢弃。 */
        @Volatile var cancelled = false

        // 根自身的删除/移动用于结束监视；递归监视还需要知道子目录的增删。
        val observerMask = mask or SELF_EVENTS or (if (recursive) NEW_EVENTS or GONE_EVENTS else 0)
    }

    private class Node(val key: String) {
        val file = File(key)
        val subscribers = LinkedHashSet<Watch>()
        var observer: Observer? = null
        var mask = 0
    }

    @Suppress("DEPRECATION") // FileObserver(File, Int) 需要 API 29；String 版本在所有版本上都可用。
    private class Observer(
        val file: File,
        mask: Int,
        private val handler: (Observer, Int, String?) -> Unit,
    ) : FileObserver(file.path, mask) {
        val isDirectory = file.isDirectory
        override fun onEvent(event: Int, path: String?) = handler(this, event, path)
    }

    private val lock = Any()
    private val watches = HashMap<String, Watch>()
    private val nodes = HashMap<String, Node>()
    private val mainHandler = Handler(Looper.getMainLooper())
    private val worker = HandlerThread("ExternalStorageWatcher").apply { start() }
    private val workerHandler = Handler(worker.looper)

    /** @throws IllegalArgumentException 路径不存在或不可读 */
    fun start(id: String, path: String, recursive: Boolean, mask: Int) {
        val root = File(path).absoluteFile
        require(root.exists()) { "Path does not exist: $path" }
        require(root.canRead()) { "Cannot read path: $path" }
        val eventMask = if (mask == 0) EVENTS_ALL else mask and EVENTS_ALL
        val watch = Watch(id, root, recursive && root.isDirectory, eventMask)
        synchronized(lock) {
            watches.remove(id)?.let { cancelLocked(it) }
            watches[id] = watch
            subscribeLocked(watch, watch.rootKey, root)
        }
        if (watch.recursive) workerHandler.post { addSubtree(watch, root) }
    }

    fun stop(id: String): Boolean = synchronized(lock) {
        val watch = watches.remove(id) ?: return false
        cancelLocked(watch)
        true
    }

    fun stopAll() = synchronized(lock) {
        watches.values.forEach { cancelLocked(it) }
        watches.clear()
    }

    fun watchedPaths(): List<String> =
        synchronized(lock) { watches.values.map { it.root.path }.distinct() }

    fun isWatching(path: String): Boolean {
        val target = File(path).absoluteFile.path
        return synchronized(lock) { watches.values.any { it.root.path == target } }
    }

    fun dispose() {
        stopAll()
        workerHandler.removeCallbacksAndMessages(null)
        worker.quitSafely()
        mainHandler.removeCallbacksAndMessages(null)
    }

    /** 在工作线程订阅 [dir] 下的所有子目录（跟随链接，但同一目录只进入一次）。 */
    private fun addSubtree(watch: Watch, dir: File) {
        val visited = HashSet<String>()
        fun visit(current: File) {
            val key = keyOf(current)
            if (!visited.add(key)) return
            synchronized(lock) {
                if (!watch.active) return
                subscribeLocked(watch, key, current)
            }
            current.listFiles()?.forEach { if (it.isDirectory) visit(it) }
        }
        visit(dir)
    }

    private fun onObserverEvent(observer: Observer, rawEvent: Int, name: String?) {
        val isSelf = name.isNullOrEmpty()
        val events = splitEvents(
            if (isSelf && observer.isDirectory) rawEvent and DIR_SELF_EVENTS else rawEvent
        )
        val isDirectory = if (isSelf) observer.isDirectory else (rawEvent and IN_ISDIR) != 0
        synchronized(lock) {
            val node = nodes[observer.file.path] ?: return
            if (node.observer !== observer) return
            for (watch in node.subscribers.toList()) {
                val dir = watch.dirs[node.key] ?: continue
                val target = if (name.isNullOrEmpty()) dir else File(dir, name)
                events.filter { (watch.mask and it) != 0 }
                    .forEach { post(watch, it, target, isDirectory) }

                when {
                    isSelf && (rawEvent and (SELF_EVENTS or IN_UNMOUNT)) != 0 ->
                        if (node.key == watch.rootKey) endLocked(watch)
                        else unsubscribeLocked(watch, node.key)
                    !isSelf && isDirectory && watch.recursive && (rawEvent and NEW_EVENTS) != 0 ->
                        workerHandler.post { addSubtree(watch, target) }
                    !isSelf && isDirectory && watch.recursive && (rawEvent and GONE_EVENTS) != 0 ->
                        unsubscribeTreeLocked(watch, "${node.key}/$name")
                }
            }
        }
    }

    private fun post(watch: Watch, event: Int, target: File, isDirectory: Boolean) {
        val payload = mapOf<String, Any>(
            "watchId" to watch.id,
            "watchedPath" to watch.root.path,
            "path" to target.path,
            "eventType" to event,
            "isDirectory" to isDirectory,
        )
        mainHandler.post { if (!watch.cancelled) listener.onEvent(payload) }
    }

    /** 根被删除 / 移走 / 卸载：监视自然结束，已排队的事件照常投递。 */
    private fun endLocked(watch: Watch) {
        if (watches[watch.id] === watch) watches.remove(watch.id)
        closeLocked(watch)
        mainHandler.post { if (!watch.cancelled) listener.onWatchDone(watch.id) }
    }

    private fun cancelLocked(watch: Watch) {
        watch.cancelled = true
        closeLocked(watch)
    }

    private fun closeLocked(watch: Watch) {
        watch.active = false
        watch.dirs.keys.toList().forEach { unsubscribeLocked(watch, it) }
    }

    private fun subscribeLocked(watch: Watch, key: String, file: File) {
        val node = nodes.getOrPut(key) { Node(key) }
        node.subscribers.add(watch)
        watch.dirs[key] = file
        refreshLocked(node)
    }

    private fun unsubscribeLocked(watch: Watch, key: String) {
        watch.dirs.remove(key)
        val node = nodes[key] ?: return
        if (!node.subscribers.remove(watch)) return
        if (node.subscribers.isEmpty()) {
            node.observer?.stopWatching()
            nodes.remove(key)
        } else {
            refreshLocked(node)
        }
    }

    private fun unsubscribeTreeLocked(watch: Watch, key: String) {
        val prefix = "$key/"
        watch.dirs.keys.filter { it == key || it.startsWith(prefix) }
            .forEach { unsubscribeLocked(watch, it) }
    }

    /** FileObserver 创建后不能修改掩码，订阅者的掩码合集变化时重建。 */
    private fun refreshLocked(node: Node) {
        val mask = node.subscribers.fold(0) { acc, watch -> acc or watch.observerMask }
        if (mask == node.mask && node.observer != null) return
        node.observer?.stopWatching()
        node.observer = Observer(node.file, mask, ::onObserverEvent).also { it.startWatching() }
        node.mask = mask
    }
}
