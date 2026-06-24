package club.devkor.ontime

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

class NativeAlarmReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "OnTimeNativeAlarm"
        private const val ALARM_CHANNEL_ID = "on_time_alarm"
        private const val ALARM_CHANNEL_NAME = "OnTime alarms"
        private const val NOTIFICATION_ID_OFFSET = 730000

        const val ACTION_FIRE_ALARM = "on_time_front.FIRE_ALARM"
        const val ACTION_DISMISS_ALARM = "on_time_front.DISMISS_ALARM"
        const val ACTION_ALARM_DISMISSED = "on_time_front.ALARM_DISMISSED"

        fun alarmPendingIntentForArgs(
            context: Context,
            args: Map<*, *>,
            lookupFlag: Int,
        ): PendingIntent? {
            val requestCode = requestCodeFromArgs(args)
            val intent = alarmIntent(context, requestCode).apply {
                putAlarmExtrasFromArgs(args)
            }
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                lookupFlag or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun alarmPendingIntentForRecord(
            context: Context,
            requestCode: Int,
            extras: Map<String, String>,
            lookupFlag: Int,
        ): PendingIntent {
            val intent = alarmIntent(context, requestCode).apply {
                putAlarmExtras(extras)
            }
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                lookupFlag or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun activityPendingIntentForArgs(
            context: Context,
            args: Map<*, *>,
            lookupFlag: Int,
        ): PendingIntent? {
            val requestCode = requestCodeFromArgs(args)
            return PendingIntent.getActivity(
                context,
                requestCode,
                ringingIntentFromArgs(context, args),
                lookupFlag or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun activityPendingIntentForExtras(
            context: Context,
            requestCode: Int,
            extras: Map<String, String>,
            lookupFlag: Int,
        ): PendingIntent? {
            return PendingIntent.getActivity(
                context,
                requestCode,
                ringingIntentFromExtras(context, extras),
                lookupFlag or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun dismissPendingIntentForExtras(
            context: Context,
            requestCode: Int,
            extras: Map<String, String>,
            lookupFlag: Int,
        ): PendingIntent {
            val intent = Intent(context, NativeAlarmReceiver::class.java).apply {
                action = ACTION_DISMISS_ALARM
                putExtra("nativeAlarmId", requestCode)
                putAlarmExtras(extras)
            }
            return PendingIntent.getBroadcast(
                context,
                requestCode,
                intent,
                lookupFlag or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun flutterLaunchIntentFromExtras(
            context: Context,
            extras: Map<String, String>,
        ): Intent {
            return Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_SCHEDULE_ALARM
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                putAlarmExtras(extras)
            }
        }

        fun ringingIntentFromExtras(
            context: Context,
            extras: Map<String, String>,
        ): Intent {
            return Intent(context, AlarmRingingActivity::class.java).apply {
                action = ACTION_FIRE_ALARM
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NO_USER_ACTION
                putAlarmExtras(extras)
            }
        }

        fun cancelAlarmNotification(context: Context, requestCode: Int) {
            val manager = context.getSystemService(NotificationManager::class.java)
            manager?.cancel(notificationId(requestCode))
            NativeLog.d(TAG, "Alarm notification canceled requestCode=$requestCode")
        }

        fun notificationId(requestCode: Int): Int {
            return NOTIFICATION_ID_OFFSET + (requestCode and 0x0fffffff)
        }

        private fun requestCodeFromArgs(args: Map<*, *>): Int {
            return (args["nativeAlarmId"] as? Number)?.toInt()
                ?: args["scheduleId"].toString().hashCode()
        }

        private fun alarmIntent(context: Context, requestCode: Int): Intent {
            return Intent(context, NativeAlarmReceiver::class.java).apply {
                action = ACTION_FIRE_ALARM
                putExtra("nativeAlarmId", requestCode)
            }
        }

        private fun ringingIntentFromArgs(context: Context, args: Map<*, *>): Intent {
            val extras = mutableMapOf<String, String>()
            extras["type"] = "schedule_alarm"
            extras["scheduleId"] = args["scheduleId"]?.toString().orEmpty()
            extras["promptVariant"] = "alarm"
            extras["alarmTime"] = args["alarmTime"]?.toString().orEmpty()
            extras["preparationStartTime"] =
                args["preparationStartTime"]?.toString().orEmpty()
            extras["nativeAlarmId"] = requestCodeFromArgs(args).toString()
            args["title"]?.toString()?.let { extras["title"] = it }
            args["body"]?.toString()?.let { extras["body"] = it }

            val payload = args["payload"] as? Map<*, *>
            payload?.forEach { (key, value) ->
                if (key != null && value != null) {
                    extras[key.toString()] = value.toString()
                }
            }
            return ringingIntentFromExtras(context, extras)
        }

        private fun Intent.putAlarmExtrasFromArgs(args: Map<*, *>) {
            putExtra("type", "schedule_alarm")
            putExtra("scheduleId", args["scheduleId"]?.toString())
            putExtra("promptVariant", "alarm")
            putExtra("alarmTime", args["alarmTime"]?.toString())
            putExtra("preparationStartTime", args["preparationStartTime"]?.toString())
            putExtra("nativeAlarmId", requestCodeFromArgs(args).toString())
            putExtra("title", args["title"]?.toString())
            putExtra("body", args["body"]?.toString())

            val payload = args["payload"] as? Map<*, *>
            payload?.forEach { (key, value) ->
                if (key != null && value != null) {
                    putExtra(key.toString(), value.toString())
                }
            }
        }

        private fun Intent.putAlarmExtras(extras: Map<String, String>) {
            for ((key, value) in extras) {
                if (value.isNotEmpty()) {
                    putExtra(key, value)
                }
            }
            putExtra("type", "schedule_alarm")
            putExtra("promptVariant", "alarm")
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        NativeLog.d(TAG, "NativeAlarmReceiver onReceive ${NativeLog.summarizeIntent(intent)}")
        when (intent.action) {
            ACTION_FIRE_ALARM -> handleFireAlarm(context, intent)
            ACTION_DISMISS_ALARM -> handleDismissAlarm(context, intent)
        }
    }

    private fun handleFireAlarm(context: Context, intent: Intent) {
        val extras = payloadFromIntent(intent)
        val requestCode = intent.getIntExtra(
            "nativeAlarmId",
            extras["nativeAlarmId"]?.toIntOrNull()
                ?: extras["scheduleId"]?.hashCode()
                ?: 1,
        )
        NativeLog.d(
            TAG,
            "Native alarm broadcast fired requestCode=$requestCode " +
                "scheduleId=${extras["scheduleId"]} alarmTime=${extras["alarmTime"]}",
        )
        postAlarmNotification(context, requestCode, extras)
    }

    private fun handleDismissAlarm(context: Context, intent: Intent) {
        val extras = payloadFromIntent(intent)
        val requestCode = intent.getIntExtra(
            "nativeAlarmId",
            extras["nativeAlarmId"]?.toIntOrNull()
                ?: extras["scheduleId"]?.hashCode()
                ?: 1,
        )
        cancelAlarmNotification(context, requestCode)
        context.sendBroadcast(Intent(ACTION_ALARM_DISMISSED).apply {
            setPackage(context.packageName)
            putExtra("nativeAlarmId", requestCode)
            putExtra("scheduleId", extras["scheduleId"])
        })
        NativeLog.d(
            TAG,
            "Native alarm dismissed requestCode=$requestCode scheduleId=${extras["scheduleId"]}",
        )
    }

    private fun postAlarmNotification(
        context: Context,
        requestCode: Int,
        extras: Map<String, String>,
    ) {
        val manager = context.getSystemService(NotificationManager::class.java)
        if (manager == null) {
            NativeLog.w(TAG, "Alarm notification skipped: NotificationManager unavailable")
            return
        }
        if (!canPostNotifications(context)) {
            NativeLog.w(
                TAG,
                "Alarm notification skipped: notification permission denied " +
                    "scheduleId=${extras["scheduleId"]}",
            )
            return
        }
        ensureAlarmChannel(manager)
        val contentIntent = activityPendingIntentForExtras(
            context,
            requestCode,
            extras,
            PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val dismissIntent = dismissPendingIntentForExtras(
            context,
            requestCode,
            extras,
            PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val title = extras["title"]?.takeIf { it.isNotBlank() } ?: "OnTime alarm"
        val body = extras["body"]?.takeIf { it.isNotBlank() } ?: "It is time to get ready."
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, ALARM_CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_MAX)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(contentIntent)
            .addAction(
                Notification.Action.Builder(
                    context.applicationInfo.icon,
                    "Dismiss",
                    dismissIntent,
                ).build(),
            )
            .build()
        manager.notify(notificationId(requestCode), notification)
        NativeLog.d(
            TAG,
            "Alarm notification posted requestCode=$requestCode " +
                "scheduleId=${extras["scheduleId"]}",
        )
    }

    private fun ensureAlarmChannel(manager: NotificationManager) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val existing = manager.getNotificationChannel(ALARM_CHANNEL_ID)
        if (existing != null) {
            NativeLog.d(TAG, "Alarm notification channel already exists")
            return
        }
        val channel = NotificationChannel(
            ALARM_CHANNEL_ID,
            ALARM_CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "OnTime schedule alarm alerts."
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            setBypassDnd(true)
        }
        manager.createNotificationChannel(channel)
        NativeLog.d(TAG, "Alarm notification channel created")
    }

    private fun canPostNotifications(context: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun payloadFromIntent(intent: Intent): Map<String, String> {
        val payload = mutableMapOf<String, String>()
        val extras = intent.extras
        if (extras != null) {
            for (key in extras.keySet()) {
                extras.get(key)?.let { payload[key] = it.toString() }
            }
        }
        payload["type"] = "schedule_alarm"
        payload["promptVariant"] = "alarm"
        return payload
    }
}
