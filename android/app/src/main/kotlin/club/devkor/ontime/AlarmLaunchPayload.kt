package club.devkor.ontime

/** A launch is only a hint to open the current DB-backed confirmation screen. */
object AlarmLaunchPayload {
    fun sanitize(source: Map<*, *>?): Map<String, String>? {
        val id = source?.get("scheduleId") as? String ?: return null
        if (id.isBlank() || id.length > 512 || id.any { it.code < 32 || it.code == 127 }) {
            return null
        }
        val identity = source["storeIncarnation"]
        if (source.containsKey("storeIncarnation") &&
            (identity !is String || !Regex("^[a-fA-F0-9-]{32,36}$").matches(identity))) {
            return null
        }
        return mutableMapOf(
            "type" to "schedule_alarm",
            "scheduleId" to id,
            "alarmLaunchPayloadVersion" to "10",
            "promptVariant" to "alarm",
        ).apply { if (identity is String) put("storeIncarnation", identity) }
    }

    /** Provider display fields are never forwarded to Flutter as a route. */
    fun deliveryExtras(source: Map<*, *>?): Map<String, String> {
        val result = sanitize(source)?.toMutableMap() ?: mutableMapOf()
        for (key in listOf("nativeAlarmId", "alarmTime", "preparationStartTime")) {
            val value = source?.get(key)
            val number = when (value) {
                is String -> value.toLongOrNull()
                is Byte, is Short, is Int, is Long -> (value as Number).toLong()
                else -> null
            }
            if (number != null) result[key] = number.toString()
        }
        // Do not show arbitrary content for a malformed/orphan launch identity.
        if (result.containsKey("scheduleId")) {
            for (key in listOf("title", "body")) {
                (source?.get(key) as? String)?.let { result[key] = it }
            }
        }
        return result
    }
}
