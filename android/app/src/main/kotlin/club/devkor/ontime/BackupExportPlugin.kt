package club.devkor.ontime

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/** Exports only the already encrypted container. No destination or grant is retained. */
class BackupExportPlugin : FlutterPlugin, ActivityAware,
    PluginRegistry.ActivityResultListener, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private var channel: MethodChannel? = null
    private var binding: ActivityPluginBinding? = null
    private val main = Handler(Looper.getMainLooper())
    private var active: Attempt? = null

    private class Attempt(
        val result: MethodChannel.Result,
        val requestCode: Int,
        val directory: File,
        val file: File,
    ) {
        @Volatile var interrupted = false
        var finishing = false
        var writing = false
    }

    companion object {
        // A single queue also orders cleanup from an old engine before a new export.
        private val io = Executors.newSingleThreadExecutor()
        private val requestCodes = AtomicInteger(24000)
        private val liveDirectories = mutableSetOf<String>() // Accessed only on io.
        private const val FAILURE = "Backup could not be saved. An incomplete file may remain in the selected location."
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "ontime/backup_export")
        channel?.setMethodCallHandler(this)
        io.execute {
            val root = File(context.noBackupFilesDir, "backup_exports")
            try {
                root.listFiles()?.filter { it.path !in liveDirectories }?.forEach {
                    try { it.deleteRecursively() } catch (_: Exception) { /* Retry next startup. */ }
                }
            } catch (_: Exception) { /* Export will report any inaccessible staging directory. */ }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "export") { result.notImplemented(); return }
        if (active != null) {
            result.error("export_busy", "A backup export is already in progress.", null)
            return
        }
        val args = call.arguments as? Map<*, *>
        val bytes = args?.get("encryptedBytes") as? ByteArray
        val name = args?.get("suggestedName") as? String
        if (bytes == null || bytes.isEmpty() || name.isNullOrBlank() ||
            name.length > 200 || name.contains('/') || name.contains('\\') ||
            !name.endsWith(".ontimebackup") || binding == null) {
            result.error("export_failed", "Backup export is unavailable.", null)
            return
        }
        // Never reuse an ID in this process: an abandoned picker may return late.
        // Activity request codes must fit in 16 bits. Exhaustion requires a new process.
        if (requestCodes.get() >= 65535) {
            result.error("export_failed", "Please restart OnTime before exporting another backup.", null)
            return
        }
        val directory = File(File(context.noBackupFilesDir, "backup_exports"), UUID.randomUUID().toString())
        val attempt = Attempt(result, requestCodes.incrementAndGet(), directory, File(directory, name))
        active = attempt
        io.execute {
            try {
                liveDirectories.add(directory.path)
                if (!directory.mkdirs()) throw IOException()
                FileOutputStream(attempt.file).use { stream ->
                    stream.write(bytes)
                    stream.flush()
                    stream.fd.sync()
                }
                if (!attempt.file.readBytes().contentEquals(bytes)) throw IOException()
                main.post {
                    if (active === attempt && !attempt.finishing && !attempt.interrupted) {
                        try {
                            val activity = binding?.activity ?: throw IOException()
                            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                                addCategory(Intent.CATEGORY_OPENABLE)
                                type = "application/octet-stream"
                                putExtra(Intent.EXTRA_TITLE, name)
                            }
                            activity.startActivityForResult(intent, attempt.requestCode)
                        } catch (_: Exception) { finish(attempt, failed = true) }
                    }
                }
            } catch (_: Exception) {
                main.post { finish(attempt, failed = true) }
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        val attempt = active ?: return false
        if (requestCode != attempt.requestCode) return false
        if (attempt.finishing || attempt.writing) return true
        if (resultCode == Activity.RESULT_CANCELED) { finish(attempt, outcome = "cancelled"); return true }
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || uri.scheme != "content") {
            finish(attempt, failed = true)
            return true
        }
        attempt.writing = true
        writeDocument(attempt, uri)
        return true
    }

    private fun writeDocument(attempt: Attempt, uri: Uri) {
        io.execute {
            try {
                if (attempt.interrupted) throw IOException()
                val output = context.contentResolver.openOutputStream(uri, "w") ?: throw IOException()
                output.use { sink ->
                    attempt.file.inputStream().use { source ->
                        val buffer = ByteArray(64 * 1024)
                        while (true) {
                            if (attempt.interrupted) throw IOException()
                            val count = source.read(buffer)
                            if (count < 0) break
                            sink.write(buffer, 0, count)
                        }
                    }
                    sink.flush()
                } // close must succeed before saved is reported.
                main.post { finish(attempt, outcome = "saved") }
            } catch (_: Exception) {
                // A provider URI alone does not prove ownership/new creation. Never delete it.
                main.post { finish(attempt, failed = true) }
            }
        }
    }

    private fun finish(attempt: Attempt, outcome: String? = null, failed: Boolean = false) {
        if (active !== attempt || attempt.finishing) return
        attempt.finishing = true
        // Once write/flush/close has completed, later Activity teardown must not
        // turn a known saved file into a failure. Dart guards its own DB generation.
        val interruptedBeforeReceipt = attempt.interrupted
        io.execute {
            // Startup retries failed local cleanup; an external saved copy remains saved.
            try { attempt.directory.deleteRecursively() } catch (_: Exception) { /* Retry next startup. */ }
            liveDirectories.remove(attempt.directory.path)
            main.post {
                if (active !== attempt) return@post
                active = null
                if (failed || interruptedBeforeReceipt) {
                    attempt.result.error("export_failed", FAILURE, null)
                } else {
                    attempt.result.success(outcome ?: "cancelled")
                }
            }
        }
    }

    private fun detachActivity() {
        binding?.removeActivityResultListener(this)
        binding = null
        active?.let {
            it.interrupted = true
            finish(it, failed = true)
        }
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addActivityResultListener(this)
    }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivityForConfigChanges() = detachActivity()
    override fun onDetachedFromActivity() = detachActivity()
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        detachActivity()
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
