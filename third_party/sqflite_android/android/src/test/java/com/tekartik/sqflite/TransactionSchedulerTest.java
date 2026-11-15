package com.tekartik.sqflite;
import org.junit.Test;
public final class TransactionSchedulerTest {
    @Test public void transactionOwnerAndForeignConnectionSchedulingInvariants() {
        SchedulerInvariantCheck.main(new String[]{});
    }
}
