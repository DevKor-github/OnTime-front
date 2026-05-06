package club.devkor.ontime

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log
import java.text.SimpleDateFormat
import java.util.Locale
import java.util.TimeZone
import org.json.JSONArray
import org.json.JSONObject

class NativeAlarmBootReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "OnTimeNativeAlarm"
        private const val NATIVE_PREF_NAME = "on_time_native_alarm"
        private const val FLUTTER_PREF_NAME = "FlutterSharedPreferences"
        private const val REGISTRY_PREF_KEY = "flutter.scheduled_alarm_registry"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        Log.d(TAG, "NativeAlarmBootReceiver onReceive action=$action")
        if (
            action != Intent.ACTION_BOOT_COMPLETED &&
            action != AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED
        ) {
            Log.d(TAG, "Ignoring boot receiver action=$action")
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
        val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (alarmManager == null) {
            Log.w(TAG, "restorePersistedNativeAlarms skipped: AlarmManager unavailable")
            return
        }
        if (
            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S &&
            !alarmManager.canScheduleExactAlarms()
        ) {
            Log.w(TAG, "restorePersistedNativeAlarms skipped: exact alarm permission denied")
            return
        }
        val rawRegistry = context.getSharedPreferences(FLUTTER_PREF_NAME, Context.MODE_PRIVATE)
            .getString(REGISTRY_PREF_KEY, null)
        if (rawRegistry == null) {
            Log.d(TAG, "restorePersistedNativeAlarms skipped: empty registry")
            return
        }
        val now = System.currentTimeMillis()
        val records = try {
            JSONArray(rawRegistry)
        } catch (error: Exception) {
            Log.w(TAG, "restorePersistedNativeAlarms registry parse failed", error)
            return
        }

        var restoredCount = 0
        var skippedCount = 0
        for (index in 0 until records.length()) {
            val record = records.optJSONObject(index)
            if (record == null) {
                skippedCount += 1
                continue
            }
            if (record.optString("provider") != "androidAlarmManager") {
                skippedCount += 1
                continue
            }
            val scheduleId = record.optString("scheduleId")
            if (scheduleId.isEmpty()) {
                skippedCount += 1
                continue
            }
            val alarmTime = parseAlarmTime(record.optString("alarmTime"))
            if (alarmTime == null) {
                Log.w(TAG, "Skipping restore with unparsable alarmTime scheduleId=$scheduleId")
                skippedCount += 1
                continue
            }
            if (alarmTime <= now) {
                Log.d(TAG, "Skipping restore for past alarm scheduleId=$scheduleId alarmTime=$alarmTime")
                skippedCount += 1
                continue
            }
            val pendingIntent = pendingIntentFor(context, record)
            val showIntent = showIntentFor(context, record)
            if (pendingIntent == null || showIntent == null) {
                Log.w(TAG, "Restore skipped: unable to build alarm pending intents scheduleId=$scheduleId")
                skippedCount += 1
                continue
            }
            val alarmClockInfo = AlarmManager.AlarmClockInfo(alarmTime, showIntent)
            try {
                alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
                restoredCount += 1
                Log.d(
                    TAG,
                    "Restored native alarm scheduleId=$scheduleId alarmTime=$alarmTime",
                )
            } catch (error: SecurityException) {
                skippedCount += 1
                Log.e(TAG, "Restore failed permission denied scheduleId=$scheduleId", error)
            }
        }
        Log.d(
            TAG,
            "restorePersistedNativeAlarms complete restored=$restoredCount " +
                "skipped=$skippedCount total=${records.length()}",
        )
    }

    private fun pendingIntentFor(context: Context, record: JSONObject): PendingIntent? {
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
            "nativeAlarmId" to requestCode.toString(),
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

    private fun showIntentFor(context: Context, record: JSONObject): PendingIntent? {
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
            "nativeAlarmId" to requestCode.toString(),
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
        extras["title"] = record.optString("scheduleTitle", "")
        extras["body"] = "It is time to get ready."
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
