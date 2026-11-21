# №21 — checkpoint G0, 2026-11-21

Архив SHA/CRC/8manifest entries PASS, прочитаны все9файлов. PR51 HEAD a7c29a7b478b6c3b001d70d3158b4a65d57b3c50; code source9e89802. Новая stacked ветка feat/task21-runtime-sandbox. PR48/49/50/51 не считаются merged.

G0 audit → G1 sandbox contract+durable storage → G2 runtime handshake/queue/UI → G3 config/selected static preview → G4 tests/native-readiness → G5 reports/PR/Drive.

Запрещены production GAS6/OAuth/ACL/main/signing/user data и Auth19 ON. Native Gradle только после пригодного preflight; известные CI0steps/KVM ограничения не повторять вслепую. Старые APK28 и исходники №20 сохраняются.

## G1 checkpoint
Реальный sandbox SQLite/WAL/FULL + immutable triggers, CAS+receipt transaction, readback, SIGKILL rollback, lost-response replay, cross-connection writers, scopes/401/403, separate vitrine stream. Targeted Node13PASS на первой версии; расширен expiry check, повтор адресных тестов далее. Runtime factory UI/headless source добавлен за SULFI_METADATA_V1=false; gateway требует nonce/binding/schema/hash/atomic capabilities. Runtime real-loopback4tests PASS: six intents/equalHEAD/config MASTER→CLIENT/lostresponse/retention/offline/corrupt/403/defaultOFF. Это synthetic staging, не Google. Static preview и очередной priority gate в работе.


## G2/G3 checkpoint, 2026-11-21 (после возобновления)

10 новых targeted Flutter PASS, прежние runtime+admin+widgets14PASS. Analyzer No issues; full Node62PASS (8новых SQLite runtime tests). Два unused imports устранены. Тестовый HTTP400 harness исправлен private loopback override, production TLS не менялся. Проверка сети обнаружила permanent error suppression при временном сбое capability: теперь20sec cooldown и retryable503, 401/403 сохраняют верный auth/role статус; новый real HTTP тест PASS. Сохранён readerScope namespace настроек20.

Static preview показывает выбранный unsaved draft через тот же DiaryPublicationSlide/Home;35sec без ротации/save/read/media/network. Screenshot — Flutter render720×1280, не Android. Queue control priority применяется только между задачами; активный файл/checkpoint8192/owner не меняются. G4: полный Flutter + два Android bundles, cheap native preflight, no blind Gradle/CI retry. G5 ещё предстоит.
