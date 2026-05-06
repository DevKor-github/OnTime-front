package club.devkor.ontime

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
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
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        restorePersistedNativeAlarms(context)
        context.getSharedPreferences(NATIVE_PREF_NAME, Context.MODE_PRIVATE)
            .edit()
            .putBoolean("boot_completed_since_last_launch", true)
            .apply()
    }

    private fun restorePersistedNativeAlarms(context: Context) {
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
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
            val alarmClockInfo = AlarmManager.AlarmClockInfo(alarmTime, pendingIntent)
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
        val intent = Intent(context, MainActivity::class.java).apply {
            action = MainActivity.ACTION_SCHEDULE_ALARM
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("type", "schedule_alarm")
            putExtra("scheduleId", scheduleId)
            putExtra("promptVariant", "alarm")
            if (alarmTimeMillis != null) putExtra("alarmTime", alarmTimeMillis.toString())
            if (preparationStartTimeMillis != null) {
                putExtra("preparationStartTime", preparationStartTimeMillis.toString())
            }
            val payloadKeys = payload?.keys()
            while (payloadKeys?.hasNext() == true) {
                val key = payloadKeys.next()
                payload.opt(key)?.let { value -> putExtra(key, value.toString()) }
            }
        }
        return PendingIntent.getActivity(
            context,
            requestCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
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
