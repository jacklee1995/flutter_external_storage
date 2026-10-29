package tech.thispage.external_storage

import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue
import kotlin.test.fail
import org.mockito.Mockito

/*
 * Run with `./gradlew :external_storage:testDebugUnitTest` from `example/android/`.
 */
internal class ExternalStoragePluginTest {
    private val handled = ExternalStoragePlugin.IO_METHODS + ExternalStoragePlugin.MAIN_METHODS

    /** Every method the Dart side invokes must have a native handler (regression: MissingPluginException). */
    @Test
    fun everyDartMethodHasNativeHandler() {
        val dartSource = locateDartChannel().readText()
        val invoked = Regex("""(?:_invoke\w*|invoke\w*Method(?:<[^>]*>)?)\(\s*'(\w+)'""")
            .findAll(dartSource)
            .map { it.groupValues[1] }
            .toSet()

        assertTrue(invoked.size >= 10, "Parsed too few methods ($invoked); regex is out of date")
        val missing = invoked - handled
        assertTrue(missing.isEmpty(), "Dart methods without a native handler: $missing")
    }

    @Test
    fun ioAndMainMethodSetsDoNotOverlap() {
        val overlap = ExternalStoragePlugin.IO_METHODS intersect ExternalStoragePlugin.MAIN_METHODS
        assertTrue(overlap.isEmpty(), "Methods registered on both threads: $overlap")
    }

    @Test
    fun unknownMethodIsNotImplemented() {
        val result = Mockito.mock(MethodChannel.Result::class.java)
        ExternalStoragePlugin().onMethodCall(MethodCall("doesNotExist", null), result)
        Mockito.verify(result).notImplemented()
    }

    /** Dart's WatchEventType.fromValue only accepts single event bits. */
    @Test
    fun combinedInotifyMaskIsSplitIntoSingleEvents() {
        val inIsDir = 0x40000000
        assertEquals(listOf(0x100), FileSystemWatcher.splitEvents(0x100 or inIsDir))
        assertEquals(listOf(0x2, 0x8), FileSystemWatcher.splitEvents(0x2 or 0x8))
        assertEquals(12, FileSystemWatcher.splitEvents(FileSystemWatcher.EVENTS_ALL).size)
        assertTrue(FileSystemWatcher.splitEvents(0x8000).isEmpty(), "IN_IGNORED is not an event")
    }

    private fun locateDartChannel(): File {
        val relative = "lib/src/external_storage_method_channel.dart"
        var dir: File? = File("").absoluteFile
        while (dir != null) {
            File(dir, relative).takeIf { it.isFile }?.let { return it }
            dir = dir.parentFile
        }
        fail("Cannot find $relative from ${File("").absolutePath}")
    }
}
