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
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build

class NativeAlarmReceiver : BroadcastReceiver() {
    companion object {
        const val ACTION_FIRE_ALARM = "on_time_front.FIRE_ALARM"
        private const val CHANNEL_ID = "native_alarm_channel"
        private const val CHANNEL_NAME = "OnTime alarms"

        fun alarmPendingIntentForArgs(
            context: Context,
            args: Map<*, *>,
            lookupFlag: Int,
        ): PendingIntent? {
            val requestCode = requestCodeFromArgs(args)
            val intent = alarmIntent(context, requestCode).apply {
                putExtra("type", "schedule_alarm")
                putExtra("scheduleId", args["scheduleId"]?.toString())
                putExtra("promptVariant", "alarm")
                putExtra("alarmTime", args["alarmTime"]?.toString())
                putExtra("preparationStartTime", args["preparationStartTime"]?.toString())
                putExtra("title", args["title"]?.toString())
                putExtra("body", args["body"]?.toString())

                val payload = args["payload"] as? Map<*, *>
                payload?.forEach { (key, value) ->
                    if (key != null && value != null) {
                        putExtra(key.toString(), value.toString())
                    }
                }
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
                for ((key, value) in extras) {
                    putExtra(key, value)
                }
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
        ): PendingIntent {
            val requestCode = requestCodeFromArgs(args)
            return PendingIntent.getActivity(
                context,
                requestCode,
                activityIntentFromArgs(context, args),
                lookupFlag or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        fun activityPendingIntentForExtras(
            context: Context,
            requestCode: Int,
            extras: Map<String, String>,
            lookupFlag: Int,
        ): PendingIntent {
            return PendingIntent.getActivity(
                context,
                requestCode,
                activityIntentFromExtras(context, extras),
                lookupFlag or PendingIntent.FLAG_IMMUTABLE,
            )
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

        private fun activityIntentFromArgs(context: Context, args: Map<*, *>): Intent {
            val extras = mutableMapOf<String, String>()
            extras["type"] = "schedule_alarm"
            extras["scheduleId"] = args["scheduleId"]?.toString().orEmpty()
            extras["promptVariant"] = "alarm"
            extras["alarmTime"] = args["alarmTime"]?.toString().orEmpty()
            extras["preparationStartTime"] =
                args["preparationStartTime"]?.toString().orEmpty()

            val payload = args["payload"] as? Map<*, *>
            payload?.forEach { (key, value) ->
                if (key != null && value != null) {
                    extras[key.toString()] = value.toString()
                }
            }
            return activityIntentFromExtras(context, extras)
        }

        private fun activityIntentFromExtras(
            context: Context,
            extras: Map<String, String>,
        ): Intent {
            return Intent(context, MainActivity::class.java).apply {
                action = MainActivity.ACTION_SCHEDULE_ALARM
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
                for ((key, value) in extras) {
                    if (value.isNotEmpty()) {
                        putExtra(key, value)
                    }
                }
                putExtra("type", "schedule_alarm")
                putExtra("promptVariant", "alarm")
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_FIRE_ALARM) return

        val extras = payloadFromIntent(intent)
        val requestCode = intent.getIntExtra(
            "nativeAlarmId",
            extras["scheduleId"]?.hashCode() ?: 1,
        )
        val contentIntent = activityPendingIntentForExtras(
            context,
            requestCode,
            extras,
            PendingIntent.FLAG_UPDATE_CURRENT,
        )

        if (!canPostNotifications(context)) {
            context.startActivity(activityIntentFromExtras(context, extras))
            return
        }

        createNotificationChannel(context)
        val title = extras["title"]
            ?: extras["scheduleTitle"]
            ?: "OnTime"
        val body = extras["body"] ?: "It is time to get ready."
        val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)

        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }

        val notification = builder
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(contentIntent)
            .setAutoCancel(true)
            .setCategory(Notification.CATEGORY_ALARM)
            .setPriority(Notification.PRIORITY_MAX)
            .setVisibility(Notification.VISIBILITY_PUBLIC)
            .setFullScreenIntent(contentIntent, true)
            .setSound(alarmSound)
            .setVibrate(longArrayOf(0, 1000, 500, 1000))
            .build()

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(requestCode, notification)
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

    private fun canPostNotifications(context: Context): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU ||
            context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun createNotificationChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (notificationManager.getNotificationChannel(CHANNEL_ID) != null) return

        val alarmSound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        val audioAttributes = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_ALARM)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val channel = NotificationChannel(
            CHANNEL_ID,
            CHANNEL_NAME,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "OnTime schedule alarm alerts."
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            enableVibration(true)
            setSound(alarmSound, audioAttributes)
        }
        notificationManager.createNotificationChannel(channel)
    }
}
