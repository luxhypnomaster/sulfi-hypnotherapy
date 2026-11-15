"""Build-only candidate: original vendor files are NEVER edited by this script."""
import pathlib,os,hashlib
root=pathlib.Path(os.environ['RUNNER_TEMP'])/'task18-sqlite-probe'
base=pathlib.Path('third_party/sqflite_android/android/src/main/java/com/tekartik/sqflite')
s=(base/'DatabaseWorkerPool.java').read_text()
old='''    @Override
    public void post(DatabaseTask task) {
        handler.post(task.runnable);
    }
'''
new='''    private final TransactionScheduler transactions = new TransactionScheduler();

    @Override
    public void post(DatabaseTask task) {
        // A foreign connection must not block this only native thread while
        // its transaction owner's COMMIT is still waiting for the same thread.
        handler.post(() -> {
            transactions.offer(task);
            DatabaseTask next;
            while ((next = transactions.next()) != null) {
                try { next.runnable.run(); }
                finally { transactions.completed(next); }
            }
        });
    }
'''
promoted='0dc55be0efd1a2b045941ebcbf4c1b3b9dd3722c5884bba1f165993e5fba9efb'
if hashlib.sha256(s.encode()).hexdigest()==promoted:
 assert (base/'TransactionScheduler.java').read_bytes()==pathlib.Path('scripts/task18/sqlite_probe/TransactionScheduler.java').read_bytes(),'SCHEDULER_CANDIDATE_MISMATCH'
else:
 assert s.count(old)==1,'UNREVIEWED_VENDOR_SOURCE_STOP'
 s=s.replace(old,new)
# Native close must release the scheduling owner, even if upstream's Java
# transaction counter was not reset on close. No rollback/reset is invented.
s=s.replace('return database.isInTransaction();','return database.isInTransaction() && database.getWritableDatabase().isOpen();')
(root/'DatabaseWorkerPool.java').write_text(s)
(root/'Database.java').write_text('''package com.tekartik.sqflite;
import android.database.sqlite.SQLiteDatabase;
class Database { int id; boolean isInTransaction(){return false;} SQLiteDatabase getWritableDatabase(){return null;} }
''')
(root/'Nullable.java').write_text('package androidx.annotation; public @interface Nullable {}\n')
