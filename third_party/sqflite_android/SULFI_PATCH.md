# Pinned Android SQLite safety patch — Task16G

Upstream sqflite_android2.4.5, original MIT LICENSE retained. No version or API
change. Only Database.open/openReadOnly delegate to StorageSafety.open, which
installs a throwing non-destructive corruption callback on both RW and RO.
DefaultDatabaseErrorHandler must never run; no delete/recreate/retry/recovery.
The Task16G baseline manifest remains preserved in reports/task16g; Task18 adds the scheduling change described below.

Dart bootstrap validates a derivative copy before RW and disables startup media
GC. Native callback remains active for corruption discovered after preflight.
This does not promise recovery from arbitrary filesystem/hardware failures.

## Task18: single-thread transaction ownership
The existing one-thread executor defers SQL from another database connection
until the current transaction owner can run its COMMIT/ROLLBACK. Otherwise a
foreign SQLite lock wait blocks the same native thread needed for that COMMIT.
TransactionScheduler is process-local SQL scheduling, not a second transfer
queue. No thread-count/busy_timeout/WAL/schema/data migration change. Native
close releases ownership when its database is no longer open. The corruption
callback and StorageSafety.java are unchanged.

Candidate source was tested against real Android SQLite: both commits completed,
2rows and integrity_check=ok (run43739426806; run-level failure was an observer
assumption about unchanged default busy_timeout2500, not these functional checks).
Five standalone JVM invariants passed. Fresh normal APK/background/upgrade gates
remain required before candidate issuance.
