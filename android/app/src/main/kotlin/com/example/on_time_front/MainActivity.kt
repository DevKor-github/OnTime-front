package com.example.on_time_front

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var methodChannel: MethodChannel? = null

    companion object {
        private const val CHANNEL_NAME = "on_time_front/native_alarm"
        const val ACTION_SCHEDULE_ALARM = "on_time_front.SCHEDULE_ALARM"
        private var launchPayload: Map<String, String>? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        payloadFromIntent(intent)?.let { launchPayload = it }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        )
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCapabilities" -> result.success(
                    mapOf(
                        "supportsNativeAlarm" to true,
                        "nativeAlarmProvider" to "androidAlarmManager",
                        "fallbackProvider" to "localNotification",
                    ),
                )
                "checkPermission" -> result.success("granted")
                "requestPermission" -> result.success("granted")
                "scheduleNativeAlarm" -> scheduleNativeAlarm(call, result)
                "cancelNativeAlarm" -> cancelNativeAlarm(call, result)
                "getLaunchPayload" -> {
                    result.success(launchPayload)
                    launchPayload = null
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        payloadFromIntent(intent)?.let {
            launchPayload = it
            methodChannel?.invokeMethod("alarmLaunch", it)
        }
    }

    private fun scheduleNativeAlarm(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.error("invalidArguments", "Missing alarm arguments", null)
            return
        }

        val triggerAtMillis = (args["alarmTime"] as? Number)?.toLong()
        val scheduleId = args["scheduleId"]?.toString()
        if (triggerAtMillis == null || scheduleId.isNullOrEmpty()) {
            result.error("invalidArguments", "Missing scheduleId or alarmTime", null)
            return
        }
        if (triggerAtMillis <= System.currentTimeMillis()) {
            result.error("invalidArguments", "Cannot schedule a past alarm", null)
            return
        }

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (alarmManager == null) {
            result.error("unsupported", "AlarmManager is unavailable", null)
            return
        }

        val pendingIntent = pendingIntentFor(args, PendingIntent.FLAG_UPDATE_CURRENT)
        val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, pendingIntent)
        alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
        result.success(null)
    }

    private fun cancelNativeAlarm(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.success(null)
            return
        }
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val pendingIntent = pendingIntentFor(args, PendingIntent.FLAG_NO_CREATE)
        if (alarmManager != null && pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
        result.success(null)
    }

    private fun pendingIntentFor(args: Map<*, *>, lookupFlag: Int): PendingIntent? {
        val requestCode = (args["nativeAlarmId"] as? Number)?.toInt()
            ?: args["scheduleId"].toString().hashCode()
        val intent = Intent(this, MainActivity::class.java).apply {
            action = ACTION_SCHEDULE_ALARM
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("type", "schedule_alarm")
            putExtra("scheduleId", args["scheduleId"]?.toString())
            putExtra("promptVariant", "alarm")
            putExtra("alarmTime", args["alarmTime"]?.toString())
            putExtra("preparationStartTime", args["preparationStartTime"]?.toString())

            val payload = args["payload"] as? Map<*, *>
            payload?.forEach { (key, value) ->
                if (key != null && value != null) {
                    putExtra(key.toString(), value.toString())
                }
            }
        }
        val flags = lookupFlag or PendingIntent.FLAG_IMMUTABLE
        return PendingIntent.getActivity(this, requestCode, intent, flags)
    }

    private fun payloadFromIntent(intent: Intent?): Map<String, String>? {
        if (intent?.action != ACTION_SCHEDULE_ALARM) return null
        val extras = intent.extras ?: return null
        val payload = mutableMapOf<String, String>()
        for (key in extras.keySet()) {
            extras.get(key)?.let { payload[key] = it.toString() }
        }
        payload["type"] = "schedule_alarm"
        payload["promptVariant"] = "alarm"
        return payload
    }
}
