package club.devkor.ontime

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.InputStream
import java.io.IOException
import java.util.UUID
import java.util.concurrent.Executors

/** Narrow backup reader. The URI and its transient permission never cross Dart. */
class BackupImportPlugin : FlutterPlugin, ActivityAware,
    PluginRegistry.ActivityResultListener, MethodChannel.MethodCallHandler {
    private lateinit var context: Context
    private var channel: MethodChannel? = null
    private var binding: ActivityPluginBinding? = null
    private val main = Handler(Looper.getMainLooper())
    private var active: Attempt? = null
    private var lastClosed: String? = null

    private class Attempt(val id: String, val requestCode: Int) {
        @Volatile var cancelled = false
        @Volatile var stream: InputStream? = null
        var pick: MethodChannel.Result? = null
        var busy = false
        var closing = false
        var closeFailure = false
        var closeResult: MethodChannel.Result? = null
        var consumed = 0L
        var eof = false
        var picked = false
    }
    companion object {
        private const val LIMIT = 72L * 1024 * 1024
        private const val CHUNK = 65536
        // Reuse only after Android has delivered that selection's terminal
        // callback. Cancelled pickers with a late callback keep their slot.
        private val pendingRequests = mutableSetOf<Int>()
        @Synchronized private fun reserveRequest(): Int? {
            val code = (18000..23999).firstOrNull { it !in pendingRequests } ?: return null
            pendingRequests.add(code)
            return code
        }
        @Synchronized private fun releaseRequest(code: Int) { pendingRequests.remove(code) }
        private val reads = Executors.newSingleThreadExecutor()
        // Cancellation cannot be queued behind a blocking provider read.
        private val closes = Executors.newSingleThreadExecutor()
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "ontime/backup_import")
        channel?.setMethodCallHandler(this)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method == "begin") {
            if (active != null) { fail(result, "import_busy"); return }
            val code = reserveRequest()
            if (code == null) { fail(result, "import_busy"); return }
            val attempt = Attempt(UUID.randomUUID().toString(), code)
            active = attempt
            result.success(attempt.id)
            return
        }
        val id = call.argument<String>("handle")
        if (call.method == "close" && id != null && id == lastClosed) {
            result.success(true); return
        }
        val attempt = active
        if (attempt == null || id != attempt.id) { fail(result); return }
        when (call.method) {
            "pick" -> {
                val activity = binding?.activity
                if (activity == null || attempt.picked || attempt.cancelled) { fail(result); return }
                attempt.picked = true
                attempt.pick = result
                try {
                    activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE)
                        type = "*/*"
                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    }, attempt.requestCode)
                } catch (_: Exception) { releaseRequest(attempt.requestCode); attempt.pick = null; fail(result) }
            }
            "read" -> {
                val rawMaximum = call.argument<Any?>("maxBytes")
                val maximum = when (rawMaximum) {
                    is Int -> rawMaximum.toLong()
                    is Long -> rawMaximum
                    else -> null
                }
                if (maximum == null || maximum !in 1..CHUNK.toLong() || attempt.busy ||
                    attempt.cancelled || attempt.stream == null || attempt.pick != null) {
                    fail(result); return
                }
                if (attempt.eof) {
                    result.success(mapOf("bytes" to ByteArray(0), "eof" to true)); return
                }
                attempt.busy = true
                val size = minOf(maximum, LIMIT - attempt.consumed + 1L).toInt()
                reads.execute {
                    var bytes: ByteArray? = null
                    var eof = false
                    var error: String? = null
                    try {
                        if (attempt.cancelled) throw IOException()
                        val buffer = ByteArray(size)
                        val count = attempt.stream!!.read(buffer)
                        when {
                            count < 0 -> { bytes = ByteArray(0); eof = true }
                            count == 0 -> error = "import_io"
                            count.toLong() > LIMIT - attempt.consumed -> error = "import_limit"
                            else -> bytes = if (count == size) buffer else buffer.copyOf(count)
                        }
                    } catch (_: Exception) { error = "import_io" }
                    main.post {
                        attempt.busy = false
                        if (attempt.cancelled) fail(result, "import_cancelled")
                        else if (error != null) fail(result, error!!)
                        else {
                            attempt.consumed += bytes!!.size
                            attempt.eof = eof
                            result.success(mapOf("bytes" to bytes, "eof" to eof))
                        }
                        finishClose(attempt)
                    }
                }
            }
            "close" -> close(attempt, result)
            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?): Boolean {
        if (requestCode !in 18000..23999) return false
        releaseRequest(requestCode)
        val attempt = active
        if (attempt == null || requestCode != attempt.requestCode) return false
        val reply = attempt.pick ?: return true
        attempt.pick = null
        if (attempt.cancelled) { fail(reply, "import_cancelled"); return true }
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK) { reply.success(null); return true }
        if (uri == null) { fail(reply); return true }
        attempt.busy = true
        reads.execute {
            var length: Long? = null
            var failure: String? = null
            try {
                context.contentResolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
                    val column = cursor.getColumnIndex(OpenableColumns.SIZE)
                    if (column >= 0 && cursor.moveToFirst() && !cursor.isNull(column)) {
                        val size = cursor.getLong(column)
                        if (size >= 0) length = size // Unknown/negative is not an allocation size.
                    }
                }
                if (length != null && length!! > LIMIT) failure = "import_limit"
                else if (!attempt.cancelled) {
                    val opened = context.contentResolver.openInputStream(uri) ?: throw IOException()
                    attempt.stream = opened
                    // close() may have raced the provider's blocking open call.
                    if (attempt.cancelled) {
                        opened.close()
                        attempt.stream = null
                    }
                }
            } catch (_: Exception) { failure = "import_io" }
            main.post {
                attempt.busy = false
                if (attempt.cancelled) fail(reply, "import_cancelled")
                else if (failure != null) fail(reply, failure!!)
                else reply.success(mapOf("length" to length))
                finishClose(attempt)
            }
        }
        return true
    }

    private fun close(attempt: Attempt, result: MethodChannel.Result?) {
        if (attempt.closeResult != null) { if (result != null) fail(result, "import_busy"); return }
        attempt.closeResult = result
        attempt.cancelled = true
        if (!attempt.picked) releaseRequest(attempt.requestCode)
        attempt.pick?.let { fail(it, "import_cancelled") }
        attempt.pick = null
        try { binding?.activity?.finishActivity(attempt.requestCode) } catch (_: Exception) { }
        if (attempt.closing) return
        attempt.closing = true
        attempt.closeFailure = false
        closes.execute {
            try { attempt.stream?.close(); attempt.stream = null }
            catch (_: Exception) { attempt.closeFailure = true }
            main.post { attempt.closing = false; finishClose(attempt) }
        }
    }

    private fun finishClose(attempt: Attempt) {
        if (!attempt.cancelled || attempt.busy || attempt.closing) return
        // An open that returned after the first close needs another actual close.
        if (attempt.stream != null && !attempt.closeFailure) {
            val reply = attempt.closeResult
            attempt.closeResult = null
            close(attempt, reply)
            return
        }
        val reply = attempt.closeResult
        attempt.closeResult = null
        if (attempt.closeFailure) { if (reply != null) fail(reply); return }
        if (active === attempt) active = null
        lastClosed = attempt.id
        reply?.success(true)
    }

    private fun fail(result: MethodChannel.Result, code: String = "import_io") {
        result.error(code, "Backup input could not be read.", null)
    }
    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        this.binding = binding
        binding.addActivityResultListener(this)
    }
    override fun onDetachedFromActivityForConfigChanges() = detachActivity()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) = onAttachedToActivity(binding)
    override fun onDetachedFromActivity() = detachActivity()
    private fun detachActivity() {
        active?.let { close(it, null) }
        binding?.removeActivityResultListener(this)
        binding = null
    }
    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        active?.let { close(it, null) }
        channel?.setMethodCallHandler(null)
        channel = null
    }
}
