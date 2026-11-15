package ru.sulfi.sulfi_hypnotherapy.transfer

import org.junit.Assert.*
import org.junit.Test

class JobOwnershipTest {
    @Test fun watchdogThatDidNotStartTheEngineCannotStopTheTransfer() {
        val o = JobOwnership(); val primary = JobSchedule(1801,"user"); val watchdog = JobSchedule(1802,"recovery")
        o.claim(primary, 7)
        assertFalse(o.takeForStop(watchdog, 7))
        assertTrue(o.owns(primary, 7))
    }
    @Test fun stoppedOldScheduleWithReusedJobIdCannotCancelANewRun() {
        val o = JobOwnership(); val old = JobSchedule(1801,"old"); val fresh = JobSchedule(1801,"fresh")
        o.claim(old, 1); o.claim(fresh, 2)
        assertFalse(o.takeForStop(old, 2))
        assertTrue(o.owns(fresh, 2))
    }
    @Test fun lateFinishOrTimeoutCannotReleaseNewExecution() {
        val o = JobOwnership(); val key = JobSchedule(1802,"same-schedule")
        o.claim(key, 1); o.claim(key, 2)
        assertFalse(o.release(key, 1))
        assertTrue(o.owns(key, 2))
        assertTrue(o.release(key, 2)); assertFalse(o.takeForStop(key, 2))
    }
    @Test fun legitimateOwnedStopIsConsumedExactlyOnce() {
        val o = JobOwnership(); val key = JobSchedule(1801,"user")
        o.claim(key, 5)
        assertTrue(o.takeForStop(key, 5))
        assertFalse(o.takeForStop(key, 5)); assertFalse(o.release(key, 5))
    }
}
