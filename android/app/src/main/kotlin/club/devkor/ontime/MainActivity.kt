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

open class MainActivity : FlutterActivity() {
    private var methodChannel: MethodChannel? = null

    companion object {
        private const val TAG = "OnTimeNativeAlarm"
        private const val CHANNEL_NAME = "on_time_front/native_alarm"
        const val ACTION_SCHEDULE_ALARM = "on_time_front.SCHEDULE_ALARM"
        private var launchPayload: Map<String, String>? = null
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NativeLog.d(TAG, "MainActivity onCreate ${NativeLog.summarizeIntent(intent)}")
        configureAlarmLaunchWindow(intent)
        payloadFromIntent(intent)?.let {
            NativeLog.d(TAG, "Captured launch payload from onCreate ${NativeLog.summarizeMap(it)}")
            launchPayload = it
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        NativeLog.d(TAG, "configureFlutterEngine registering method channel")
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL_NAME,
        )
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getCapabilities" -> {
                    val nativeAlarmApproved =
                        NativeAlarmPolicy.isAndroidFullScreenAlarmApproved()
                    val capabilities = mapOf(
                        "supportsNativeAlarm" to nativeAlarmApproved,
                        "nativeAlarmProvider" to if (nativeAlarmApproved) {
                            "androidAlarmManager"
                        } else {
                            "none"
                        },
                        "fallbackProvider" to "localNotification",
                    )
                    NativeLog.d(TAG, "getCapabilities -> $capabilities")
                    result.success(capabilities)
                }
                "checkPermission" -> {
                    val state = exactAlarmPermissionState()
                    NativeLog.d(TAG, "checkPermission -> $state")
                    result.success(state)
                }
                "requestPermission" -> requestExactAlarmPermission(result)
                "scheduleNativeAlarm" -> scheduleNativeAlarm(call, result)
                "cancelNativeAlarm" -> cancelNativeAlarm(call, result)
                "getLaunchPayload" -> {
                    NativeLog.d(TAG, "getLaunchPayload -> ${NativeLog.summarizeMap(launchPayload)}")
                    result.success(launchPayload)
                    launchPayload = null
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        NativeLog.d(TAG, "MainActivity onNewIntent ${NativeLog.summarizeIntent(intent)}")
        setIntent(intent)
        configureAlarmLaunchWindow(intent)
        payloadFromIntent(intent)?.let {
            NativeLog.d(TAG, "Captured launch payload from onNewIntent ${NativeLog.summarizeMap(it)}")
            launchPayload = it
            methodChannel?.invokeMethod("alarmLaunch", it)
        }
    }

    private fun scheduleNativeAlarm(call: MethodCall, result: MethodChannel.Result) {
        if (!NativeAlarmPolicy.isAndroidFullScreenAlarmApproved()) {
            NativeLog.w(TAG, "scheduleNativeAlarm blocked: full-screen alarm approval is disabled")
            result.error(
                "unsupported",
                "Android native alarms require full-screen alarm policy approval",
                null,
            )
            return
        }

        val args = call.arguments as? Map<*, *>
        if (args == null) {
            NativeLog.w(TAG, "scheduleNativeAlarm invalid: missing args")
            result.error("invalidArguments", "Missing alarm arguments", null)
            return
        }

        val triggerAtMillis = (args["alarmTime"] as? Number)?.toLong()
        val scheduleId = args["scheduleId"]?.toString()
        if (triggerAtMillis == null || scheduleId.isNullOrEmpty()) {
            NativeLog.w(TAG, "scheduleNativeAlarm invalid ${NativeLog.summarizeMap(args)}")
            result.error("invalidArguments", "Missing scheduleId or alarmTime", null)
            return
        }
        if (triggerAtMillis <= System.currentTimeMillis()) {
            NativeLog.w(
                TAG,
                "scheduleNativeAlarm rejected past alarm scheduleId=$scheduleId " +
                    "triggerAtMillis=$triggerAtMillis now=${System.currentTimeMillis()}",
            )
            result.error("invalidArguments", "Cannot schedule a past alarm", null)
            return
        }

        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (alarmManager == null) {
            NativeLog.w(TAG, "scheduleNativeAlarm unsupported: AlarmManager unavailable")
            result.error("unsupported", "AlarmManager is unavailable", null)
            return
        }
        if (!canScheduleExactAlarms(alarmManager)) {
            NativeLog.w(TAG, "scheduleNativeAlarm permissionDenied scheduleId=$scheduleId")
            result.error("permissionDenied", "Exact alarm permission denied", null)
            return
        }

        val alarmIntent = NativeAlarmReceiver.alarmPendingIntentForArgs(
            this,
            args,
            PendingIntent.FLAG_UPDATE_CURRENT,
        )
        if (alarmIntent == null) {
            NativeLog.w(
                TAG,
                "scheduleNativeAlarm unable to build broadcast pending intent " +
                    NativeLog.summarizeMap(args),
            )
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
            NativeLog.d(
                TAG,
                "scheduleNativeAlarm setAlarmClock scheduleId=$scheduleId " +
                    "nativeAlarmId=${args["nativeAlarmId"]} triggerAtMillis=$triggerAtMillis " +
                    "now=${System.currentTimeMillis()} operation=broadcast showIntent=activity",
            )
            alarmManager.setAlarmClock(alarmClockInfo, alarmIntent)
        } catch (error: SecurityException) {
            NativeLog.e(TAG, "scheduleNativeAlarm SecurityException scheduleId=$scheduleId", error)
            result.error("permissionDenied", "Exact alarm permission denied", null)
            return
        }
        NativeLog.d(TAG, "scheduleNativeAlarm success scheduleId=$scheduleId")
        result.success(null)
    }

    private fun cancelNativeAlarm(call: MethodCall, result: MethodChannel.Result) {
        val args = call.arguments as? Map<*, *>
        if (args == null) {
            NativeLog.d(TAG, "cancelNativeAlarm skipped: missing args")
            result.success(null)
            return
        }
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        val activityPendingIntent = NativeAlarmReceiver.activityPendingIntentForArgs(
            this,
            args,
            PendingIntent.FLAG_NO_CREATE,
        )
        val legacyBroadcastPendingIntent = NativeAlarmReceiver.alarmPendingIntentForArgs(
            this,
            args,
            PendingIntent.FLAG_NO_CREATE,
        )
        if (alarmManager != null && activityPendingIntent != null) {
            NativeLog.d(
                TAG,
                "cancelNativeAlarm cancel activity operation scheduleId=${args["scheduleId"]} " +
                    "nativeAlarmId=${args["nativeAlarmId"]}",
            )
            alarmManager.cancel(activityPendingIntent)
            activityPendingIntent.cancel()
        }
        if (alarmManager != null && legacyBroadcastPendingIntent != null) {
            NativeLog.d(
                TAG,
                "cancelNativeAlarm cancel legacy broadcast operation scheduleId=${args["scheduleId"]} " +
                    "nativeAlarmId=${args["nativeAlarmId"]}",
            )
            alarmManager.cancel(legacyBroadcastPendingIntent)
            legacyBroadcastPendingIntent.cancel()
        }
        if (alarmManager == null || (activityPendingIntent == null && legacyBroadcastPendingIntent == null)) {
            NativeLog.d(
                TAG,
                "cancelNativeAlarm no-op scheduleId=${args["scheduleId"]} " +
                    "hasAlarmManager=${alarmManager != null} " +
                    "hasActivityPendingIntent=${activityPendingIntent != null} " +
                    "hasLegacyBroadcastPendingIntent=${legacyBroadcastPendingIntent != null}",
            )
        }
        val requestCode = (args["nativeAlarmId"] as? Number)?.toInt()
            ?: args["scheduleId"]?.toString()?.hashCode()
            ?: 1
        NativeAlarmReceiver.cancelAlarmNotification(this, requestCode)
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
        return if (canScheduleExactAlarms(alarmManager)) {
            "granted"
        } else {
            "denied"
        }
    }

    private fun requestExactAlarmPermission(result: MethodChannel.Result) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as? AlarmManager
        if (alarmManager == null) {
            NativeLog.w(TAG, "requestPermission -> unsupported: AlarmManager unavailable")
            result.success("unsupported")
            return
        }
        if (canScheduleExactAlarms(alarmManager)) {
            NativeLog.d(TAG, "requestPermission -> already granted")
            result.success("granted")
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM).apply {
                data = Uri.parse("package:$packageName")
            }
            try {
                NativeLog.d(TAG, "Opening exact alarm permission settings")
                startActivity(intent)
            } catch (error: ActivityNotFoundException) {
                NativeLog.w(TAG, "Unable to open exact alarm permission settings", error)
                result.success("denied")
                return
            }
        }
        val state = exactAlarmPermissionState()
        NativeLog.d(TAG, "requestPermission -> $state")
        result.success(state)
    }

    private fun canScheduleExactAlarms(alarmManager: AlarmManager): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            alarmManager.canScheduleExactAlarms()
    }

    private fun configureAlarmLaunchWindow(intent: Intent?) {
        if (!NativeAlarmPolicy.isAndroidFullScreenAlarmApproved()) return
        if (payloadFromIntent(intent) == null) return
        NativeLog.d(TAG, "configureAlarmLaunchWindow for alarm launch")
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
