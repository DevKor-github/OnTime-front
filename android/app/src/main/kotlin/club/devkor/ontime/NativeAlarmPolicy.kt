package club.devkor.ontime

object NativeAlarmPolicy {
    const val ANDROID_FULL_SCREEN_ALARM_APPROVED = false

    fun isAndroidFullScreenAlarmApproved(): Boolean {
        return ANDROID_FULL_SCREEN_ALARM_APPROVED
    }
}
