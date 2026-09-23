package club.devkor.ontime

fun main() {
    val privateMarker = "private-step-title-do-not-forward"
    val old = mapOf(
        "scheduleId" to "fixture-schedule", "fingerprint" to privateMarker,
        "title" to privateMarker, "body" to privateMarker,
        "alarmTime" to "1234", "preparationStartTime" to "1200",
        "nativeAlarmId" to "42", "alarmLaunchAction" to "startPreparation",
        "alarmLaunchPayloadVersion" to "8", "unknown" to privateMarker,
        "type" to "start-command", "promptVariant" to "bypass-confirmation",
    )
    val clean = requireNotNull(AlarmLaunchPayload.sanitize(old))
    check(clean == mapOf(
        "scheduleId" to "fixture-schedule", "type" to "schedule_alarm",
        "alarmLaunchPayloadVersion" to "9", "promptVariant" to "alarm",
    ))
    check(!clean.toString().contains(privateMarker))
    check(AlarmLaunchPayload.sanitize(clean) == clean)
    for (id in listOf(null, 5, listOf("id"), "", "  ", "x\ny", "x\u007fy", "x".repeat(513))) {
        check(AlarmLaunchPayload.sanitize(mapOf("scheduleId" to id)) == null)
    }
    check(AlarmLaunchPayload.sanitize(mapOf("scheduleId" to "한글-🙂")) != null)
    val delivery = AlarmLaunchPayload.deliveryExtras(old)
    check(delivery["title"] == privateMarker && delivery["body"] == privateMarker)
    check(delivery["nativeAlarmId"] == "42" && delivery["alarmTime"] == "1234")
    check(!delivery.containsKey("fingerprint") && !delivery.containsKey("alarmLaunchAction"))
    check(AlarmLaunchPayload.sanitize(delivery) == clean)
    val malformed = AlarmLaunchPayload.deliveryExtras(mapOf(
        "scheduleId" to 123, "title" to privateMarker, "nativeAlarmId" to 42,
        "alarmTime" to "not-a-time", "preparationStartTime" to 2.5,
    ))
    // Cancellation ownership survives malformed routing; content does not.
    check(malformed == mapOf("nativeAlarmId" to "42"))
    println("Android launch privacy contract passed (legacy, malformed, idempotent, delivery separation)")
}
