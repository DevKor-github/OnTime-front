package club.devkor.ontime

import android.animation.ValueAnimator
import android.app.Activity
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.RectF
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.graphics.drawable.Drawable
import android.media.AudioAttributes
import android.media.Ringtone
import android.media.RingtoneManager
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.view.Gravity
import android.view.View
import android.view.WindowInsets
import android.view.WindowInsetsController
import android.view.WindowManager
import android.view.animation.LinearInterpolator
import android.widget.LinearLayout
import android.widget.Space
import android.widget.TextView
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone

class AlarmRingingActivity : Activity() {
    private val handler = Handler(Looper.getMainLooper())
    private var ringtone: Ringtone? = null
    private var vibrator: Vibrator? = null
    private var stopped = false
    private var requestCode = 1
    private var payload = emptyMap<String, String>()
    private lateinit var statusView: TextView
    private var dialView: AlarmDialView? = null

    private val autoStopRunnable = Runnable {
        stopRinging(showStoppedState = true)
    }

    private val dismissReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != NativeAlarmReceiver.ACTION_ALARM_DISMISSED) return
            val dismissedId = intent.getIntExtra("nativeAlarmId", -1)
            if (dismissedId == requestCode) {
                NativeLog.d(TAG, "AlarmRingingActivity received dismiss broadcast requestCode=$requestCode")
                dismissAlarm()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        NativeLog.d(TAG, "AlarmRingingActivity onCreate ${NativeLog.summarizeIntent(intent)}")
        if (!NativeAlarmPolicy.isAndroidFullScreenAlarmApproved()) {
            NativeLog.d(TAG, "AlarmRingingActivity finishing: full-screen alarm approval is disabled")
            finish()
            return
        }
        configureWindow()
        capturePayload(intent)
        buildContent()
        registerDismissReceiver()
        startRinging()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        NativeLog.d(TAG, "AlarmRingingActivity onNewIntent ${NativeLog.summarizeIntent(intent)}")
        setIntent(intent)
        if (intent.action == NativeAlarmReceiver.ACTION_DISMISS_ALARM) {
            dismissAlarm()
            return
        }
        capturePayload(intent)
        buildContent()
        startRinging()
    }

    override fun onDestroy() {
        stopRinging(showStoppedState = false)
        try {
            unregisterReceiver(dismissReceiver)
        } catch (_: Exception) {
        }
        super.onDestroy()
    }

    private fun configureWindow() {
        @Suppress("DEPRECATION")
        window.setFlags(
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
            WindowManager.LayoutParams.FLAG_FULLSCREEN,
        )
        @Suppress("DEPRECATION")
        window.decorView.systemUiVisibility =
            View.SYSTEM_UI_FLAG_FULLSCREEN or
                View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION or
                View.SYSTEM_UI_FLAG_LAYOUT_STABLE
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            window.setDecorFitsSystemWindows(false)
            window.insetsController?.let { controller ->
                controller.hide(WindowInsets.Type.statusBars() or WindowInsets.Type.navigationBars())
                controller.systemBarsBehavior =
                    WindowInsetsController.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
            }
        }
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
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
        )
    }

    private fun capturePayload(intent: Intent?) {
        val extras = mutableMapOf<String, String>()
        val rawExtras = intent?.extras
        if (rawExtras != null) {
            for (key in rawExtras.keySet()) {
                rawExtras.get(key)?.let { extras[key] = it.toString() }
            }
        }
        extras["type"] = "schedule_alarm"
        extras["promptVariant"] = "alarm"
        requestCode = extras["nativeAlarmId"]?.toIntOrNull()
            ?: extras["scheduleId"]?.hashCode()
            ?: 1
        payload = extras
    }

    private fun buildContent() {
        val scheduleTitle = payload["title"]?.takeIf { it.isNotBlank() }
            ?: "OnTime alarm"
        val body = payload["body"]?.takeIf { it.isNotBlank() }
            ?: "It is time to get ready."

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), 0, dp(24), dp(40))
            setBackgroundColor(BACKGROUND_COLOR)
        }
        val contentArea = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        val newDialView = AlarmDialView(
            this,
            alarmDisplayTime(payload["alarmTime"]),
        )
        dialView = newDialView
        val titleView = TextView(this).apply {
            text = scheduleTitle
            setTextColor(PRIMARY_TEXT_COLOR)
            textSize = 40f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            includeFontPadding = false
            maxLines = 2
        }
        statusView = TextView(this).apply {
            text = body
            setTextColor(SECONDARY_TEXT_COLOR)
            textSize = 18f
            gravity = Gravity.CENTER
            includeFontPadding = false
            maxLines = 2
        }
        val startButton = buildStartButton()
        val dismissButton = buildDismissButton()

        contentArea.addView(Space(this), LinearLayout.LayoutParams(1, dp(140)))
        contentArea.addView(
            newDialView,
            LinearLayout.LayoutParams(dp(282), dp(282)).apply {
                gravity = Gravity.CENTER_HORIZONTAL
            },
        )
        contentArea.addView(titleView, fullWidthWrapHeight(topMargin = dp(26)))
        contentArea.addView(statusView, fullWidthWrapHeight(topMargin = dp(8)))

        root.addView(
            contentArea,
            LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                0,
                1f,
            ),
        )
        root.addView(startButton, actionButtonParams())
        root.addView(dismissButton, actionButtonParams(topMargin = dp(16)))
        setContentView(root)
    }

    private fun buildStartButton(): TextView {
        return TextView(this).apply {
            text = "Start preparing"
            setTextColor(BUTTON_TEXT_COLOR)
            textSize = 20f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            includeFontPadding = false
            isClickable = true
            isFocusable = true
            setMinimumHeight(dp(64))
            background = roundedBackground(PRIMARY_BLUE, PRIMARY_BLUE, dp(8), 0)
            setOnClickListener { startPreparing() }
        }
    }

    private fun buildDismissButton(): TextView {
        return TextView(this).apply {
            text = "Dismiss"
            setTextColor(PRIMARY_TEXT_COLOR)
            textSize = 20f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            includeFontPadding = false
            isClickable = true
            isFocusable = true
            setMinimumHeight(dp(64))
            background = roundedBackground(BACKGROUND_COLOR, BUTTON_BORDER_COLOR, dp(8), dp(2))
            setOnClickListener { dismissAlarm() }
        }
    }

    private fun fullWidthWrapHeight(topMargin: Int = 0): LinearLayout.LayoutParams {
        return LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            setMargins(0, topMargin, 0, 0)
        }
    }

    private fun actionButtonParams(topMargin: Int = 0): LinearLayout.LayoutParams {
        val availableWidth = resources.displayMetrics.widthPixels - dp(48)
        val targetWidth = minOf(availableWidth, dp(360))
        return LinearLayout.LayoutParams(
            targetWidth,
            dp(64),
        ).apply {
            gravity = Gravity.CENTER_HORIZONTAL
            setMargins(0, topMargin, 0, 0)
        }
    }

    private fun roundedBackground(
        fillColor: Int,
        strokeColor: Int,
        radius: Int,
        strokeWidth: Int,
    ): GradientDrawable {
        return GradientDrawable().apply {
            shape = GradientDrawable.RECTANGLE
            setColor(fillColor)
            cornerRadius = radius.toFloat()
            if (strokeWidth > 0) {
                setStroke(strokeWidth, strokeColor)
            }
        }
    }

    private fun registerDismissReceiver() {
        val filter = IntentFilter(NativeAlarmReceiver.ACTION_ALARM_DISMISSED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(dismissReceiver, filter, RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(dismissReceiver, filter)
        }
    }

    private fun startRinging() {
        stopped = false
        statusView.text = payload["body"]?.takeIf { it.isNotBlank() }
            ?: "It is time to get ready."
        startRingtone()
        startVibration()
        dialView?.startPulseAnimation()
        handler.removeCallbacks(autoStopRunnable)
        handler.postDelayed(autoStopRunnable, MAX_RING_DURATION_MS)
        NativeLog.d(
            TAG,
            "AlarmRingingActivity ringing started requestCode=$requestCode " +
                "scheduleId=${payload["scheduleId"]}",
        )
    }

    private fun startRingtone() {
        val alarmUri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
        ringtone = RingtoneManager.getRingtone(this, alarmUri)?.apply {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                audioAttributes = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build()
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
                isLooping = true
            }
            play()
        }
    }

    private fun startVibration() {
        vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(VibratorManager::class.java)
            manager?.defaultVibrator
        } else {
            @Suppress("DEPRECATION")
            getSystemService(Context.VIBRATOR_SERVICE) as? Vibrator
        }
        val pattern = longArrayOf(0, 700, 400, 700, 1200)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            vibrator?.vibrate(
                VibrationEffect.createWaveform(pattern, 0),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
        } else {
            @Suppress("DEPRECATION")
            vibrator?.vibrate(pattern, 0)
        }
    }

    private fun stopRinging(showStoppedState: Boolean) {
        handler.removeCallbacks(autoStopRunnable)
        ringtone?.stop()
        ringtone = null
        vibrator?.cancel()
        dialView?.stopPulseAnimation()
        if (!stopped && showStoppedState) {
            statusView.text = "Alarm stopped. You can still start preparing."
        }
        stopped = true
        NativeLog.d(TAG, "AlarmRingingActivity ringing stopped requestCode=$requestCode")
    }

    private fun startPreparing() {
        stopRinging(showStoppedState = false)
        NativeAlarmReceiver.cancelAlarmNotification(this, requestCode)
        val launchPayload = payload.toMutableMap().apply {
            put("alarmLaunchAction", "startPreparation")
        }
        NativeLog.d(
            TAG,
            "AlarmRingingActivity start preparing handoff requestCode=$requestCode " +
                "scheduleId=${launchPayload["scheduleId"]}",
        )
        startActivity(NativeAlarmReceiver.flutterLaunchIntentFromExtras(this, launchPayload))
        finish()
    }

    private fun dismissAlarm() {
        stopRinging(showStoppedState = false)
        NativeAlarmReceiver.cancelAlarmNotification(this, requestCode)
        finish()
    }

    private fun alarmDisplayTime(value: String?): String {
        val millis = parseAlarmTimeMillis(value) ?: System.currentTimeMillis()
        return SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(millis))
    }

    private fun parseAlarmTimeMillis(value: String?): Long? {
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

    private fun dp(value: Int): Int {
        return (value * resources.displayMetrics.density).toInt()
    }

    private class AlarmDialView(
        context: Context,
        private val timeText: String,
    ) : View(context) {
        private val paint = Paint(Paint.ANTI_ALIAS_FLAG)
        private val arcBounds = RectF()
        private var pulseAnimator: ValueAnimator? = null
        private var pulseProgress = 0f
        private var pulsing = false
        private val bellDrawable: Drawable? = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            context.getDrawable(R.drawable.alarm_bell_icon)
        } else {
            @Suppress("DEPRECATION")
            context.resources.getDrawable(R.drawable.alarm_bell_icon)
        }

        fun startPulseAnimation() {
            if (pulseAnimator?.isStarted == true) return
            pulsing = true
            pulseAnimator = ValueAnimator.ofFloat(0f, 1f).apply {
                duration = PULSE_DURATION_MS
                repeatCount = ValueAnimator.INFINITE
                interpolator = LinearInterpolator()
                addUpdateListener { animator ->
                    pulseProgress = animator.animatedValue as Float
                    invalidate()
                }
                start()
            }
        }

        fun stopPulseAnimation() {
            pulseAnimator?.cancel()
            pulseAnimator = null
            pulseProgress = 0f
            pulsing = false
            invalidate()
        }

        override fun onDetachedFromWindow() {
            pulseAnimator?.cancel()
            pulseAnimator = null
            super.onDetachedFromWindow()
        }

        override fun onDraw(canvas: Canvas) {
            super.onDraw(canvas)
            val density = resources.displayMetrics.density
            val scaledDensity = resources.displayMetrics.scaledDensity
            val centerX = width / 2f
            val centerY = height / 2f

            drawPulseRings(canvas, centerX, centerY, density)

            paint.style = Paint.Style.FILL
            paint.color = DIAL_FILL_COLOR
            canvas.drawCircle(centerX, centerY, 118f * density, paint)

            paint.color = RING_TRACK_COLOR
            paint.style = Paint.Style.STROKE
            paint.strokeCap = Paint.Cap.ROUND
            paint.strokeWidth = 20.48f * density
            arcBounds.set(
                centerX - 115.2f * density,
                centerY - 115.2f * density,
                centerX + 115.2f * density,
                centerY + 115.2f * density,
            )
            canvas.drawArc(arcBounds, 0f, 360f, false, paint)

            paint.color = PRIMARY_BLUE
            canvas.drawArc(arcBounds, 0f, 360f, false, paint)

            drawBellIcon(canvas, centerX, centerY - 40f * density, density)

            paint.reset()
            paint.isAntiAlias = true
            paint.color = PRIMARY_TEXT_COLOR
            paint.textAlign = Paint.Align.CENTER
            paint.typeface = Typeface.create(Typeface.DEFAULT, Typeface.NORMAL)
            paint.textSize = 60f * scaledDensity
            canvas.drawText(timeText, centerX, centerY + 52f * density, paint)
        }

        private fun drawPulseRings(
            canvas: Canvas,
            centerX: Float,
            centerY: Float,
            density: Float,
        ) {
            paint.style = Paint.Style.STROKE
            paint.strokeCap = Paint.Cap.ROUND
            paint.strokeWidth = 8f * density

            if (!pulsing) {
                paint.color = Color.argb(STATIC_PULSE_ALPHA, 45, 98, 255)
                canvas.drawCircle(centerX, centerY, 136f * density, paint)
                paint.color = Color.argb(STATIC_INNER_PULSE_ALPHA, 45, 98, 255)
                canvas.drawCircle(centerX, centerY, 118f * density, paint)
                return
            }

            drawAnimatedPulseRing(canvas, centerX, centerY, density, pulseProgress)
            drawAnimatedPulseRing(
                canvas,
                centerX,
                centerY,
                density,
                (pulseProgress + 0.5f) % 1f,
            )
        }

        private fun drawAnimatedPulseRing(
            canvas: Canvas,
            centerX: Float,
            centerY: Float,
            density: Float,
            phase: Float,
        ) {
            val radius = (PULSE_BASE_RADIUS_DP + PULSE_EXPANSION_DP * phase) * density
            val alpha = (PULSE_START_ALPHA * (1f - phase)).toInt().coerceIn(0, 255)
            paint.color = Color.argb(alpha, 45, 98, 255)
            canvas.drawCircle(centerX, centerY, radius, paint)
        }

        private fun drawBellIcon(
            canvas: Canvas,
            centerX: Float,
            centerY: Float,
            density: Float,
        ) {
            val iconWidth = 53.333f * density
            val iconHeight = 53.467f * density
            val left = (centerX - iconWidth / 2f).toInt()
            val top = (centerY - iconHeight / 2f).toInt()
            bellDrawable?.setBounds(
                left,
                top,
                (left + iconWidth).toInt(),
                (top + iconHeight).toInt(),
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                bellDrawable?.setTint(PRIMARY_BLUE)
            }
            bellDrawable?.draw(canvas)
        }
    }

    companion object {
        private const val TAG = "OnTimeNativeAlarm"
        private const val MAX_RING_DURATION_MS = 60_000L
        private const val PULSE_DURATION_MS = 1_600L
        private const val PULSE_BASE_RADIUS_DP = 126f
        private const val PULSE_EXPANSION_DP = 18f
        private const val PULSE_START_ALPHA = 90
        private const val STATIC_PULSE_ALPHA = 30
        private const val STATIC_INNER_PULSE_ALPHA = 48
        private val BACKGROUND_COLOR = Color.WHITE
        private val PRIMARY_BLUE = Color.rgb(45, 98, 255)
        private val DIAL_FILL_COLOR = Color.rgb(247, 249, 255)
        private val RING_TRACK_COLOR = Color.rgb(226, 231, 244)
        private val PRIMARY_TEXT_COLOR = Color.rgb(17, 19, 28)
        private val SECONDARY_TEXT_COLOR = Color.rgb(88, 91, 106)
        private val BUTTON_TEXT_COLOR = Color.WHITE
        private val BUTTON_BORDER_COLOR = Color.rgb(206, 212, 229)
    }
}
