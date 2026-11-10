# C1 ACTIVE — not deployable yet

Catalog.js, Storage.js, Transfer.js are actual GAS-compatible domain modules, tested by VM execution in Node. They require production adapters. They are NOT a full server and must not be deployed alone.

Remaining mandatory C1: Drive persistent transactional registry/index shards/receipts and crash reconciliation, Google JWT signature+subject grants binding, GAS doGet/doPost routing, real Drive resumable/range/stream hash adapter with bounded memory, diary/package operations, all required catalog operations and public projection validation, fault/security tests. Catalog mutation currently calls commit then receipt separately: atomicity across process death remains unresolved and must be fixed before publish. Storage unit test validates40named registry paths; live tree not created. Transfer verifies adapter hash but production incremental hash and session-reconcile adapter not implemented. No claim of large actual video transfer.

C0 preflight preserved before these models. CLASPRC_JSON absent; no real GAS/Drive bootstrap/deployment. Old server/google_apps_script untouched. Flutter adaptation C3 not started. Full scope147 unchanged.

Update: AtomicStore.js now provides immutable index/receipt shards + one atomic root pointer; crash-before-pointer fixture retains old object and no new receipt. Catalog domain uses begin/commitTransaction/rollback around object+receipt. GasFiles.js supplies actual private Drive JSON snapshot/readback +ScriptProperties root pointer with effective permissions checks. This adapter still needs GAS execution tests and bootstrap binding; not a complete runtime. Previous separate-commit receipt defect is addressed locally, not proven in live GAS.
