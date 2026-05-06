package club.devkor.ontime

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import org.json.JSONArray
import org.json.JSONObject

class NativeAlarmBootReceiver : BroadcastReceiver() {
    companion object {
        private const val NATIVE_PREF_NAME = "on_time_native_alarm"
        private const val FLUTTER_PREF_NAME = "FlutterSharedPreferences"
        private const val REGISTRY_PREF_KEY = "flutter.scheduled_alarm_registry"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (
            action != Intent.ACTION_BOOT_COMPLETED &&
            action != AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED
        ) {
            return
        }
        restorePersistedNativeAlarms(context)
        if (action == Intent.ACTION_BOOT_COMPLETED) {
            context.getSharedPreferences(NATIVE_PREF_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean("boot_completed_since_last_launch", true)
                .apply()
        }
    }

    private fun restorePersistedNativeAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            return
        }
        val rawRegistry = context.getSharedPreferences(FLUTTER_PREF_NAME, Context.MODE_PRIVATE)
            .getString(REGISTRY_PREF_KEY, null)
            ?: return
        val now = System.currentTimeMillis()
        val records = try {
            JSONArray(rawRegistry)
        } catch (_: Exception) {
            return
        }

        for (index in 0 until records.length()) {
            val record = records.optJSONObject(index) ?: continue
            if (record.optString("provider") != "androidAlarmManager") continue
            val scheduleId = record.optString("scheduleId")
            if (scheduleId.isEmpty()) continue
            val alarmTime = parseAlarmTime(record.optString("alarmTime")) ?: continue
            if (alarmTime <= now) continue
            val pendingIntent = pendingIntentFor(context, record)
            val showIntent = showIntentFor(context, record)
            val alarmClockInfo = AlarmManager.AlarmClockInfo(alarmTime, showIntent)
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
        }
    }

    private fun pendingIntentFor(context: Context, record: JSONObject): PendingIntent {
        val scheduleId = record.optString("scheduleId")
        val requestCode = if (record.has("nativeAlarmId") && !record.isNull("nativeAlarmId")) {
            record.optInt("nativeAlarmId")
        } else {
            scheduleId.hashCode()
        }
        val alarmTimeMillis = parseAlarmTime(record.optString("alarmTime"))
        val preparationStartTimeMillis = parseAlarmTime(record.optString("preparationStartTime"))
        val payload = record.optJSONObject("payload")
        val extras = mutableMapOf(
            "type" to "schedule_alarm",
            "scheduleId" to scheduleId,
            "promptVariant" to "alarm",
        )
        if (alarmTimeMillis != null) extras["alarmTime"] = alarmTimeMillis.toString()
        if (preparationStartTimeMillis != null) {
            extras["preparationStartTime"] = preparationStartTimeMillis.toString()
        }
        val payloadKeys = payload?.keys()
        while (payloadKeys?.hasNext() == true) {
            val key = payloadKeys.next()
            payload.opt(key)?.let { value -> extras[key] = value.toString() }
        }
        extras["title"] = record.optString("scheduleTitle", "")
        extras["body"] = "It is time to get ready."
        return NativeAlarmReceiver.alarmPendingIntentForRecord(
            context,
            requestCode,
            extras,
            PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun showIntentFor(context: Context, record: JSONObject): PendingIntent {
        val scheduleId = record.optString("scheduleId")
        val requestCode = if (record.has("nativeAlarmId") && !record.isNull("nativeAlarmId")) {
            record.optInt("nativeAlarmId")
        } else {
            scheduleId.hashCode()
        }
        val extras = mutableMapOf(
            "type" to "schedule_alarm",
            "scheduleId" to scheduleId,
            "promptVariant" to "alarm",
        )
        parseAlarmTime(record.optString("alarmTime"))?.let {
            extras["alarmTime"] = it.toString()
        }
        parseAlarmTime(record.optString("preparationStartTime"))?.let {
            extras["preparationStartTime"] = it.toString()
        }
        val payload = record.optJSONObject("payload")
        val payloadKeys = payload?.keys()
        while (payloadKeys?.hasNext() == true) {
            val key = payloadKeys.next()
            payload.opt(key)?.let { value -> extras[key] = value.toString() }
        }
        return NativeAlarmReceiver.activityPendingIntentForExtras(
            context,
            requestCode,
            extras,
            PendingIntent.FLAG_UPDATE_CURRENT,
        )
    }

    private fun parseAlarmTime(value: String?): Long? {
        if (value.isNullOrBlank()) return null
        value.toLongOrNull()?.let { return it }
        val normalizedValue = value.replace(Regex("\\.(\\d{3})\\d+"), ".$1")
        val patterns = listOf(
            "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'",
            "yyyy-MM-dd'T'HH:mm:ss'Z'",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
        )
        for (pattern in patterns) {
            try {
                val format = SimpleDateFormat(pattern, Locale.US)
                if (pattern.endsWith("'Z'")) {
                    format.timeZone = TimeZone.getTimeZone("UTC")
                }
                return format.parse(normalizedValue)?.time
            } catch (_: Exception) {
                continue
            }
        }
        return null
    }
}
