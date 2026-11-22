# Autonomy / risk rules
* First read PR51 and branch state plus #21/#22; create isolated feature branch; if another task changed same path, test separately and hand off patch rather than overwrite.
* Focus on restoring user trust: prevent data wipe and preserve user-created/audio/history/saved drafts even if a debug APK fails. Test copies only; no personal real-data contents uploaded to AI or reports.
* No manual editing of production SQLite; no uninstall/clear-storage/downgrade, no replacing APK28 or credentials. No GAS changes, no main merge.
* Do not generate native artifacts. Document expected signing certificate identity from existing verified public metadata if available; do not touch signing secret. New APK artifacts belong to a later release task.
* Native builds and physical QA are deliberately DEFERRED BY OWNER, not BLOCKED. CI billing 0steps may be documented but no build/retry should be scheduled. Continue data integrity and unit tests.
* Preserve backwards compatibility for exported capsules and precise module/track origins; additive schema only, controlled migration.
