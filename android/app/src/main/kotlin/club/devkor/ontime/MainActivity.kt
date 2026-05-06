package club.devkor.ontime

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
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
        configureAlarmLaunchWindow(intent)
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
                "checkPermission" -> result.success(exactAlarmPermissionState())
                "requestPermission" -> requestExactAlarmPermission(result)
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
        configureAlarmLaunchWindow(intent)
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
        if (!canScheduleExactAlarms(alarmManager)) {
            result.error("permissionDenied", "Exact alarm permission denied", null)
            return
        }

        val pendingIntent = NativeAlarmReceiver.alarmPendingIntentForArgs(
            this,
            args,
            PendingIntent.FLAG_UPDATE_CURRENT,
        )
        if (pendingIntent == null) {
            result.error("invalidArguments", "Unable to build alarm intent", null)
            return
        }
        val showIntent = NativeAlarmReceiver.activityPendingIntentForArgs(
            this,
            args,
            PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val alarmClockInfo = AlarmManager.AlarmClockInfo(triggerAtMillis, showIntent)
        try {
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
        } catch (_: SecurityException) {
            result.error("permissionDenied", "Exact alarm permission denied", null)
            return
        }
        result.success(null)
    }

    private fun cancelNativeAlarm(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            result.success(null)
            return
        }
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val pendingIntent = NativeAlarmReceiver.alarmPendingIntentForArgs(
            this,
            args,
            PendingIntent.FLAG_NO_CREATE,
        )
        if (alarmManager != null && pendingIntent != null) {
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
        }
        result.success(null)
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

    private fun exactAlarmPermissionState(): String {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
            ?: return "unsupported"
        return if (canScheduleExactAlarms(alarmManager)) "granted" else "denied"
    }

    private fun requestExactAlarmPermission(result: MethodChannel.Result) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (alarmManager == null) {
            result.success("unsupported")
            return
        }
        if (canScheduleExactAlarms(alarmManager)) {
            result.success("granted")
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:$packageName")
            }
            try {
                startActivity(intent)
            } catch (_: ActivityNotFoundException) {
                result.success("denied")
                return
            }
        }
        result.success(exactAlarmPermissionState())
    }

    private fun canScheduleExactAlarms(alarmManager: AlarmManager): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
    }

    private fun configureAlarmLaunchWindow(intent: Intent?) {
        if (payloadFromIntent(intent) == null) return
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON,
            )
        }
    }
}
