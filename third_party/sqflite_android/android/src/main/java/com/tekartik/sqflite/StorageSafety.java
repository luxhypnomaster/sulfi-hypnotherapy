package com.tekartik.sqflite;

import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteDatabaseCorruptException;

/** Narrow local patch to upstream2.4.5. Never delegate to DefaultDatabaseErrorHandler.
 * Throwing also prevents SQLiteDatabase.open() from retrying a corrupt open.
 * Kept independent so the exact production callback can run in native fault QA.
 */
public final class StorageSafety {
    private StorageSafety() {}

    public static SQLiteDatabase open(String path, int flags) {
        return SQLiteDatabase.openDatabase(path, null, flags, database -> {
            // Do not delete/close/recreate/restore the database or any sidecar.
            throw new SQLiteDatabaseCorruptException("SULFI_STORAGE_CORRUPT_NO_RESET");
        });
    }
}
