package ru.sulfi.sulfi_hypnotherapy.transfer

/** A scheduler execution owns only the headless run it actually started. */
internal data class JobSchedule(val id: Int, val nonce: String)
internal class JobOwnership {
    private val owners = mutableMapOf<JobSchedule, Int>()
    fun claim(schedule: JobSchedule, run: Int) { owners[schedule] = run }
    fun owns(schedule: JobSchedule, run: Int) = owners[schedule] == run
    fun release(schedule: JobSchedule, run: Int): Boolean {
        if (!owns(schedule, run)) return false
        owners.remove(schedule)
        return true
    }
    fun takeForStop(schedule: JobSchedule, activeRun: Int): Boolean =
        owners.remove(schedule) == activeRun
}
