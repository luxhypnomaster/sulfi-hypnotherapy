package ru.sulfi.sulfi_hypnotherapy.transfer

/** Scheduling hints only. Android still enforces stopped/restricted/quota state. */
data class RecoverySchedule(val minimumMs: Long, val deadlineMs: Long?)
fun recoverySchedule(delayMs: Long, available: Boolean, metered: Boolean, unmeteredOnly: Boolean): RecoverySchedule {
    val minimum = delayMs.coerceIn(30000L, 900000L)
    // Never turn an offline/metered policy wait into a repeating deadline poll.
    // If connectivity changes later the Dart lease rechecks it before HTTP.
    val allowedNow = available && (!unmeteredOnly || !metered)
    return RecoverySchedule(minimum, if (allowedNow) minimum + 10000L else null)
}
