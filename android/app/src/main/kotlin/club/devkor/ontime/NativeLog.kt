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
        return "action=${intent.action} ${summarizeMap(values)}"
    }

    fun summarizeMap(values: Map<*, *>?): String {
        if (values == null) return "keys=0"
        val scheduleId = values["scheduleId"]?.toString()
        val nativeAlarmId = values["nativeAlarmId"]?.toString()
        val type = values["type"]?.toString()
        val parts = mutableListOf("keys=${values.size}")
        if (!scheduleId.isNullOrBlank()) parts.add("scheduleId=$scheduleId")
        if (!nativeAlarmId.isNullOrBlank()) parts.add("nativeAlarmId=$nativeAlarmId")
        if (!type.isNullOrBlank()) parts.add("type=$type")
        return parts.joinToString(" ")
    }
}
