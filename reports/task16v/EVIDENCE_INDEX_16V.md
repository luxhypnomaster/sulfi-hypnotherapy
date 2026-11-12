# №16-В — индекс доказательств

Вход: Drive ZIP1EghY5gKAbkySyPx90IJ7a719xorHuBQR; полный immutable пакет в docs/task16v, MANIFEST8SHA verified; baseline ZIP digest в BASELINE_FREEZE_16V.json.

Git baseline24 cbe05240d463b9dafbe9a12ee831c967bdbf6113; source25 012f7f69b7ad99c0d44f2a442d9649aa1481117e. Separate hotfix branch и [PR46](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/46); [PR45](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/45) preserved, no merge.

## Audit / code

- ROOT_CAUSE_16V.md: факты/гипотезы/UNKNOWN owner, partial legacy-filter RCA.
- DIFF_AUDIT_16V.md + APK24_TO25_APP.diff + STORAGE_SOURCE_COMPARISON.json.
- APK24_APK25_READBACK_16V.json + BINARY_METADATA_16V.json: real apksigner/aapt/permissions/config.
- NATIVE_DEX_COMPARISON_16V.json + SQFLITE_NATIVE_DEX_16V.txt:17equalDEX, exact RW/RO native overload.
- ENGINE_LIBRARY_COMPARISON_16V.json + DARTJNI_ELF_COMPARISON_16V.json + DARTJNI_BYTE_DIFF_16V.json: engine/SQLite equality; JNI difference only build-id.
- DEPENDENCY_SAFETY_16V.md: code/native controlled corruption risk, not owner diagnosis.
- REMOTE_BASELINES_16V.json + FINAL_BOUNDARIES_16V.json: main/PR45/assets preserved.

## Regressions

TESTS_16V.md, FLUTTER_SUMMARY_16V.json, logs/*.log/jsonl. RED/GREEN legacy scope regression source `test/task16v_legacy_draft_visibility_test.dart`; source-only patch3Dart files. Read-only copy tool `scripts/task16v/readonly_inventory.py`,10local tests (9в последнем CI) including WAL/hot rollback journal and unchanged source bytes. Test fixtures explicitly not real Google users.

## Native UI / runtime

UPGRADE_REPRO_16V.md + NATIVE_UI_UPGRADE_RUN*.json + screenshots/XML. Failed and cancelled runs retained and not counted as PASS. GHA private logs contain SHA-verified chunks because artifact quota exhausted; no old artifacts deleted.

- https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43254064338 — invalid empty setup, not preservation evidence.
- https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43255433079 — regression job434PASS; native blocked.
- https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43257458828 — regression PASS; native correctly BLOCKED.
- https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43259518712 — real3UI imports shown, naming mismatch/recorder environment failure; helper corruption mechanism reproduced.
- https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43262343945 — optional IME setup failure, no MASTER baseline; no update PASS.
- https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43265893487 — accepted populated UI core24→25/cold proof; INVENTORY_*_UI_16V.json,3audio/2modules/template/current/history unchanged. Diary empty не считается PASS.
- https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43269227639 — final full regression CI,434Flutter+1SKIP,3CLIENT,46+24Node,9Python/analyze/format PASS. App tree unchanged since this source.
- https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43273089509 — final follow-up UI driver blocked; no populated update acceptance, RUN12 retained. Do not substitute this failed setup for run8 evidence.

Основной harness не вставляет SQLite rows. Отдельный helper corruption fixture не касается базы Sulfi. Native APK24/25 hashes/cert сохранены; не создавалась Sulfi APK26. Test-helper APK/key не распространяются и не включены в evidence archive.

## Owner / доставка

OWNER_RECOVERY_PLAN_16V.md, RECOVERY_LIMITATIONS_16V.md, SAFE_READONLY_DIAGNOSTIC.md, ACQUISITION_OPTIONS_16V.md: физические данные UNKNOWN, отдельное согласование доступа, никаких небезопасных инструкций. ACCEPTANCE_16V.csv сохраняет все35критериев, Code/Native/Owner отдельно. Итог BLOCKED_STOP_SHIP.

[Существующая папка отчётов№16](https://drive.google.com/drive/folders/1jVvv6kEm5uUWol92QvJDwqbDkl5oz-5z): только новые файлы16V. DRIVE_UPLOADS_16V.json + DRIVE_READBACK_16V.json фиксируют IDs/parent/размер/SHA чтения. EVIDENCE_16V.zip и SHA256SUMS_16V.txt — дополнительный неизменный комплект без APK и без личных материалов. Наличие ZIP не означает восстановление владельца.

## Комплект

EVIDENCE_16V.zip содержит reports/task16v, immutable docs/task16v, scripts/task16v, узкий product patch, regression source и workflow. Исключены APK/JKS/реальные БД/аудио/токены, generated delivery receipts и повторяющиеся PNG запусков6/7/11/12 (XML/JSON и representative failure PNG оставлены). EVIDENCE_MANIFEST_16V.json внутри ZIP перечисляет каждый включённый файл с SHA256/размером. SHA256SUMS_16V.txt проверяет целый ZIP. Позднейшие DRIVE_READBACK/DELIVERY receipts являются отдельными файлами, не рекурсивной частью архива.
