# Воспроизводимые consumer tests

flutter test --no-pub test/task15_client_test.dart --reporter expanded
flutter test --no-pub test/task5_client_build_test.dart test/task15_client_test.dart --dart-define=SULFI_EDITION=client
flutter test --no-pub test/task15_diary_test.dart
python3 scripts/task15_contract_check.py

Dart production-domain boundary: DiaryContractProvider + diaryPublicManifest + DiaryDiffPlan + cacheContractDiary + DiaryContractOutbox. FakePublicationServer находится только в test/support, не подключён по умолчанию к APK.

Два SQLite/temp sandbox, реальный AAC/PNG bytes, выбранный ZIP3audio2pause; same canonical index для picker/ZIP; immutable snapshots; private author draft не попадает вfeed; offline outbox сохраняется и повторяется с прежнимkey; ETag conflict412; retryidempotent; samekey/differentbody409; clientwrite403; privateunreferencedblob403, SHA mismatch rejected; media no URL/localPath; read толькоclient; quieteditreadunchanged, reannounceunread, expiredretainedarchive. Existing DiaryAudio callback test отдельно доказывает EOF/seek правила; e2e completion deterministic fixture.

Ограничения: fake grants не являются real OAuth; whole-snapshot fake feed, не live multi-page adapter; реальные HTTP, Google ACL, Android decoder/focus/двухтелефонная синхронизация НЕ запускались. Same-ID audio v1/v2 blocked G3. Schemas не проверяют computed digest сами: domain ContentRevision.fromMap проверяет canonical SHA. Не объявлять server-ready на основании этих тестов.
