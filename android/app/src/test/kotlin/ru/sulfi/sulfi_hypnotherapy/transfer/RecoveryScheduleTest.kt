package ru.sulfi.sulfi_hypnotherapy.transfer

import org.junit.Assert.*
import org.junit.Test

class RecoveryScheduleTest {
    @Test fun crashWatchdogKeepsTwoMinuteBudgetAndAddsBoundedBatchDeadline() {
        assertEquals(RecoverySchedule(120000L, 130000L), recoverySchedule(120000L, true, false, false))
    }
    @Test fun offlineWaitHasNoDeadlineOrWakePolling() {
        assertEquals(RecoverySchedule(30000L, null), recoverySchedule(0L, false, false, false))
    }
    @Test fun unmeteredPolicyCannotGainDeadlineOnMeteredNetwork() {
        assertNull(recoverySchedule(60000L, true, true, true).deadlineMs)
        assertEquals(70000L, recoverySchedule(60000L, true, false, true).deadlineMs)
    }
    @Test fun explicitAnyNetworkAllowsMeteredButDoesNotOverrideOriginalBackoff() {
        assertEquals(RecoverySchedule(900000L, 910000L), recoverySchedule(Long.MAX_VALUE, true, true, false))
        assertEquals(RecoverySchedule(30000L, 40000L), recoverySchedule(-1L, true, false, false))
    }
}
