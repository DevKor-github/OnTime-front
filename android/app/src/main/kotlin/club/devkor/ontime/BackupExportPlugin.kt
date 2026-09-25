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
import java.io.Closeable
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.io.OutputStream
import java.security.MessageDigest
import java.util.UUID
import java.util.concurrent.Executors

/** Bounded ciphertext transfer. Provider URIs and permissions never cross Dart. */
class BackupExportPlugin : FlutterPlugin, ActivityAware,
    PluginRegistry.ActivityResultListener, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private var channel: MethodChannel? = null
    private var binding: ActivityPluginBinding? = null
    private val main = Handler(Looper.getMainLooper())
    private var active: Attempt? = null
    private var lastReceipt: Pair<String, Map<String, Any>>? = null

    private class Attempt(val id: String, val directory: File, val file: File) {
        @Volatile var cancelled = false
        @Volatile var sink: OutputStream? = null
        @Volatile var saved = false
        var busy = false
        var closingSink = false
        var cleaning = false
        var directoryOwned = false
        val openHandles = mutableSetOf<Closeable>() // io queue only; failed closes stay owned
        var registered = false
        var initialized = false // worker-owned until its main-thread completion
        var sealed = false
        var length = 0L
        var sequence = 0L
        var requestCode: Int? = null
        var pickerPending = false
        var outcome: String? = null
        var exportResult: MethodChannel.Result? = null
        val cancelResults = mutableListOf<MethodChannel.Result>()
    }

    companion object {
        private const val LIMIT = 72L * 1024 * 1024
        private const val CHUNK = 65536
        private val io = Executors.newSingleThreadExecutor()
        // Never queue cancellation behind the provider write it must interrupt.
        private val closes = Executors.newCachedThreadPool()
        private val liveDirectories = mutableSetOf<String>() // io queue only
        private val pendingRequests = mutableSetOf<Int>()
        @Synchronized private fun reserveRequest(): Int? {
            val code = (24000..29999).firstOrNull { it !in pendingRequests } ?: return null
            pendingRequests.add(code)
            return code
        }
        @Synchronized private fun releaseRequest(code: Int) { pendingRequests.remove(code) }
        private fun integer(value: Any?): Long? = when (value) {
            is Int -> value.toLong()
            is Long -> value
            else -> null
        }
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "ontime/backup_export")
        channel?.setMethodCallHandler(this)
        io.execute {
            val root = File(context.noBackupFilesDir, "backup_exports")
            try {
                root.listFiles()?.filter { it.path !in liveDirectories }?.forEach {
                    try { it.deleteRecursively() } catch (_: Exception) { /* Retry startup. */ }
                }
            } catch (_: Exception) { /* Owned operation will report I/O failure. */ }
        }
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        if (call.method == "begin") {
            if (active != null) { fail(result, "export_busy"); return }
            val name = args?.get("suggestedName") as? String
            if (name.isNullOrBlank() || name.length > 200 || name.contains('/') ||
                name.contains('\\') || name.contains('\u0000') || !name.endsWith(".ontimebackup")) {
                fail(result, "export_invalid"); return
            }
            val id = UUID.randomUUID().toString()
            val directory = File(File(context.noBackupFilesDir, "backup_exports"), id)
            active = Attempt(id, directory, File(directory, name))
            result.success(id)
            return
        }
        val id = args?.get("handle") as? String
        if (call.method == "cancel" && id != null && id == lastReceipt?.first) {
            result.success(lastReceipt!!.second); return
        }
        val attempt = active
        if (attempt == null || id != attempt.id) { fail(result, "export_invalid"); return }
        if (call.method == "cancel") { cancel(attempt, result); return }
        if (attempt.cancelled || attempt.outcome != null) { fail(result, "export_cancelled"); return }
        if (attempt.busy || attempt.cleaning || attempt.pickerPending) { fail(result, "export_busy"); return }
        when (call.method) {
            "append" -> {
                val bytes = args["bytes"] as? ByteArray
                val sequence = integer(args["sequence"])
                if (attempt.sealed || bytes == null || bytes.isEmpty() || bytes.size > CHUNK ||
                    sequence == null || sequence != attempt.sequence) {
                    fail(result, "export_invalid"); return
                }
                if (bytes.size > LIMIT - attempt.length) { fail(result, "export_limit"); return }
                work(attempt, result) {
                    checkCancelled(attempt)
                    if (!attempt.initialized) {
                        if (!liveDirectories.add(attempt.directory.path)) throw IOException()
                        attempt.registered = true
                        val parent = attempt.directory.parentFile ?: throw IOException()
                        if (!parent.isDirectory && !parent.mkdirs()) throw IOException()
                        if (!attempt.directory.mkdir()) throw IOException()
                        attempt.directoryOwned = true
                        if (!attempt.file.createNewFile()) throw IOException()
                        attempt.initialized = true
                    }
                    ownedUse(attempt, FileOutputStream(attempt.file, true)) { it.write(bytes) }
                    attempt.length += bytes.size
                    attempt.sequence++
                }
            }
            "seal" -> {
                val length = integer(args["length"])
                val digest = args["sha256"] as? String
                if (attempt.sealed || !attempt.initialized || length == null || length !in 1..LIMIT ||
                    length != attempt.length || digest == null || !digest.matches(Regex("[0-9a-f]{64}"))) {
                    fail(result, "export_invalid"); return
                }
                work(attempt, result, sealed = true) {
                    ownedUse(attempt, FileOutputStream(attempt.file, true)) { it.fd.sync() }
                    val hash = MessageDigest.getInstance("SHA-256")
                    var read = 0L
                    ownedUse(attempt, attempt.file.inputStream()) { source ->
                        val buffer = ByteArray(CHUNK)
                        while (true) {
                            checkCancelled(attempt)
                            val count = source.read(buffer)
                            if (count < 0) break
                            if (count == 0 || count > length - read) throw IOException()
                            hash.update(buffer, 0, count)
                            read += count
                        }
                    }
                    val actual = hash.digest().joinToString("") { "%02x".format(it.toInt() and 255) }
                    if (read != length || actual != digest) throw IOException()
                }
            }
            "export" -> {
                val activity = binding?.activity
                if (!attempt.sealed || activity == null || attempt.exportResult != null) {
                    fail(result, "export_invalid"); return
                }
                val request = reserveRequest()
                if (request == null) { fail(result, "export_busy"); return }
                attempt.requestCode = request
                attempt.pickerPending = true
                attempt.exportResult = result
                try {
                    activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "application/octet-stream"
                        putExtra(Intent.EXTRA_TITLE, attempt.file.name)
                    }, request)
                } catch (_: Exception) {
                    releaseRequest(request)
                    attempt.pickerPending = false
                    attempt.outcome = "failed"
                    finish(attempt)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun work(attempt: Attempt, result: MethodChannel.Result, sealed: Boolean = false, block: () -> Unit) {
        attempt.busy = true
        io.execute {
            var failed = false
            try { block() } catch (_: Exception) { failed = true }
            main.post {
                attempt.busy = false
                if (failed || attempt.cancelled) {
                    if (!attempt.cancelled) attempt.outcome = "failed"
                    fail(result, if (attempt.cancelled) "export_cancelled" else "export_io")
                } else {
                    if (sealed) attempt.sealed = true
                    result.success(true)
                }
                finish(attempt)
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode !in 24000..29999) return false
        releaseRequest(requestCode)
        val attempt = active
        if (attempt == null || requestCode != attempt.requestCode) return false
        if (!attempt.pickerPending) return true
        attempt.pickerPending = false
        if (attempt.cancelled || resultCode == Activity.RESULT_CANCELED) {
            attempt.outcome = "cancelled"
            finish(attempt)
            return true
        }
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null || uri.scheme != "content") {
            attempt.outcome = "failed"; finish(attempt); return true
        }
        writeDocument(attempt, uri)
        return true
    }

    private fun writeDocument(attempt: Attempt, uri: Uri) {
        attempt.busy = true
        io.execute {
            try {
                checkCancelled(attempt)
                val output = context.contentResolver.openOutputStream(uri, "w") ?: throw IOException()
                attempt.sink = output
                ownedUse(attempt, output) { sink ->
                    checkCancelled(attempt)
                    ownedUse(attempt, attempt.file.inputStream()) { source ->
                        val buffer = ByteArray(CHUNK)
                        while (true) {
                            checkCancelled(attempt)
                            val count = source.read(buffer)
                            if (count < 0) break
                            sink.write(buffer, 0, count)
                        }
                    }
                    sink.flush()
                }
                // This fact survives a cancellation racing with the main-thread receipt.
                attempt.saved = true
            } catch (_: Exception) {
                // Never delete/truncate a provider URI as cleanup: ownership is unknown.
            } finally {
                attempt.sink = null
                main.post {
                    attempt.busy = false
                    attempt.outcome = if (attempt.saved) "saved" else if (attempt.cancelled) "cancelled" else "failed"
                    finish(attempt)
                }
            }
        }
    }

    private fun cancel(attempt: Attempt, result: MethodChannel.Result?) {
        result?.let { attempt.cancelResults.add(it) }
        attempt.cancelled = true
        if (attempt.outcome == null) attempt.outcome = "cancelled"
        if (attempt.pickerPending) {
            // No receipt before the picker callback confirms termination.
            try { attempt.requestCode?.let { binding?.activity?.finishActivity(it) } } catch (_: Exception) { }
        }
        val sink = attempt.sink
        if (sink != null && !attempt.closingSink) {
            attempt.closingSink = true
            closes.execute {
                try { sink.close() } catch (_: Exception) { /* Worker determines final I/O outcome. */ }
                main.post { attempt.closingSink = false; finish(attempt) }
            }
        }
        finish(attempt)
    }

    private fun finish(attempt: Attempt) {
        if (active !== attempt || attempt.outcome == null || attempt.busy || attempt.pickerPending ||
            attempt.closingSink || attempt.cleaning) return
        // An append failure keeps ownership until Dart explicitly requests cleanup.
        if (attempt.exportResult == null && attempt.cancelResults.isEmpty() && !attempt.cancelled) return
        attempt.cleaning = true
        io.execute {
            var cleaned = false
            try {
                // A failed close is not a terminal handle. Retry every owned
                // handle, and keep the file and owner if any close still fails.
                for (handle in attempt.openHandles.toList()) {
                    try { handle.close(); attempt.openHandles.remove(handle) } catch (_: Exception) { }
                }
                if (attempt.openHandles.isNotEmpty()) throw IOException()
                cleaned = !attempt.directoryOwned ||
                    ((!attempt.directory.exists() || attempt.directory.deleteRecursively()) &&
                        !attempt.directory.exists())
            } catch (_: Exception) { }
            if (cleaned && attempt.registered) liveDirectories.remove(attempt.directory.path)
            main.post {
                attempt.cleaning = false
                val receipt = mapOf<String, Any>(
                    "outcome" to if (attempt.saved) "saved" else (attempt.outcome ?: "cancelled"),
                    "cleanupUnconfirmed" to !cleaned,
                )
                val replies = attempt.cancelResults.toList()
                attempt.cancelResults.clear()
                val exportReply = attempt.exportResult
                attempt.exportResult = null
                if (cleaned) {
                    lastReceipt = attempt.id to receipt
                    active = null
                }
                exportReply?.success(receipt)
                replies.forEach { it.success(receipt) }
            }
        }
    }

    private fun <T : Closeable, R> ownedUse(attempt: Attempt, handle: T, block: (T) -> R): R {
        attempt.openHandles.add(handle)
        try { return block(handle) }
        finally {
            handle.close()
            attempt.openHandles.remove(handle)
        }
    }

    private fun checkCancelled(attempt: Attempt) { if (attempt.cancelled) throw IOException() }
    private fun fail(result: MethodChannel.Result, code: String) {
        result.error(code, "Backup export did not complete. A partial file may remain at the selected location.", null)
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addActivityResultListener(this)
        active?.takeIf { it.cancelled }?.let { cancel(it, null) }
    }
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivityForConfigChanges() {
        binding?.removeActivityResultListener(this)
        binding = null // Rotation does not establish picker cancellation.
    }
    override fun onDetachedFromActivity() {
        active?.let {
            cancel(it, null)
            // CREATE_DOCUMENT received only a suggested name, never our spool.
            // Removing this listener permanently revokes this selection's ability
            // to start a write. Its request slot stays reserved for a late result.
            // A worker already writing still must return before finish can run.
            it.pickerPending = false
            finish(it)
        }
        binding?.removeActivityResultListener(this)
        binding = null
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        onDetachedFromActivity()
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
