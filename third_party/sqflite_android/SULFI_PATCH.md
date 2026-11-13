# Pinned Android SQLite safety patch — Task16G

Upstream sqflite_android2.4.5, original MIT LICENSE retained. No version or API
change. Only Database.open/openReadOnly delegate to StorageSafety.open, which
installs a throwing non-destructive corruption callback on both RW and RO.
DefaultDatabaseErrorHandler must never run; no delete/recreate/retry/recovery.
The remaining upstream source is byte-identical (manifest in reports/task16g).

Dart bootstrap validates a derivative copy before RW and disables startup media
GC. Native callback remains active for corruption discovered after preflight.
This does not promise recovery from arbitrary filesystem/hardware failures.
