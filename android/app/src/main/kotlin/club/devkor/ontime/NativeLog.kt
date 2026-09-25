package club.devkor.ontime

import android.content.Intent
import android.util.Log

object NativeLog {
    fun d(tag: String, message: String) {
        if (BuildConfig.DEBUG) {
            Log.d(tag, message)
        }
    }

    fun w(tag: String, message: String, throwable: Throwable? = null) {
        if (!BuildConfig.DEBUG) return
        if (throwable == null) {
            Log.w(tag, message)
        } else {
            Log.w(tag, message, throwable)
        }
    }

    fun e(tag: String, message: String, throwable: Throwable? = null) {
        if (!BuildConfig.DEBUG) return
        if (throwable == null) {
            Log.e(tag, message)
        } else {
            Log.e(tag, message, throwable)
        }
    }

    fun summarizeIntent(intent: Intent?): String {
        if (intent == null) return "action=null extrasKeys=0"
        val extras = intent.extras
        val values = if (extras == null) {
            null
        } else {
            extras.keySet().associateWith { key -> extras.get(key) }
        }
        return "hasAction=${intent.action != null} ${summarizeMap(values)}"
    }

    fun summarizeMap(values: Map<*, *>?): String {
        if (values == null) return "keys=0"
        // Intent extras may be legacy or attacker-controlled. Never log their values.
        return "keys=${values.size}"
    }
}
