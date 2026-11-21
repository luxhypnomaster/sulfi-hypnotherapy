# CHANGES №20

Draft PR: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/51
Ветка feat/task20-catalog-vitrine. База dca81961146747adc4a3f06107012df429ed747a (не merged PR50), проверенный source 9e898024a51f23c602fe216784b0532e4bee90e4. Checkpoints d402b84 → f1dd4db → 9e89802.

- Isolated server/alchemist/experimental/catalog_snapshot.cjs: whitelist metadata, scoped authorization boundary, exact deps, immutable snapshot/readback, head+receipt CAS adapter, versioned vitrine config. В Router/GAS bundle не подключён.
- CatalogSnapshotSync: SQLite prepared/current, account+package scope, hash/schema/dep verification, deadline, lastGood/cold, older response protection; существующие download jobs AlchemistWorkQueue. SessionController имеет nullable injected transport и путь применения verified config, default null. Legacy catalog UI/API сохраняются до согласованного adapter.
- DiaryReadStore: новый local-only namespace, additive completed-legacy migration, исторические строки/partial audio/outbox не удаляются. DiaryController/AlchemistDiaryApi не создают новый server reader-state sync в localOnly. Старый режим доступен явным compatibility flag и покрыт тестами.
- DiaryCarousel + DiaryHomeBanner: 3/7, 1:1, full cycle/between posts, fair pinned3/4/N1, no cap unread, coalesced boundary, immediate read/revoke/expiry invalidation, own hashed media through existing resolver, existing shared player, real image/right aspect and +N. Геометрия header/board/nav сохранена; прежняя дублирующая строка послания под заголовком убрана.
- DiaryReader: final rendered/scrolled page rule, single fitting page deliberate button, own audio explicit mark without listening, no pause on read notify. ContentLink не считается own audio.
- MASTER sticker «Управление» на существующей кромке и две вкладки. Local saved/draft отдельно от published receipt; server publish disabled без admin adapter. Client route/service protection, lost-response stable request, owner and receipt checks, transactional save/apply. Технические ratio/N ceilings — OPEN proposal.
- Новые unit/SQLite/widget/Node fixtures и UTF8 canonical cross-language golden; действующие legacy/read и CLIENT/provider tests адаптированы под явную совместимость/новое правило, не удалены.

Полный список изменённых путей на source checkpoint:

- docs/task20/00_START_HERE.md
- docs/task20/01_TASK20.md
- docs/task20/02_CONTINUE_AUTONOMOUSLY.md
- docs/task20/03_ACCEPTANCE.csv
- docs/task20/04_SOURCES.md
- docs/task20/05_BOUNDARIES_AND_FALLBACKS.md
- docs/task20/06_CODEX_COMMAND.txt
- docs/task20/07_MANIFEST.json
- lib/models/vitrine_config.dart
- lib/services/alchemist_diary_api.dart
- lib/services/catalog_snapshot_sync.dart
- lib/services/diary_carousel.dart
- lib/services/diary_controller.dart
- lib/services/diary_read_state.dart
- lib/services/session_controller.dart
- lib/services/vitrine_settings.dart
- lib/ui/diary_home.dart
- lib/ui/diary_home_banner.dart
- lib/ui/diary_reader.dart
- lib/ui/home_composition.dart
- lib/ui/vitrine_settings_screen.dart
- reports/task20/BASELINE_20.md
- reports/task20/PROGRESS.md
- server/alchemist/experimental/catalog_snapshot.cjs
- server/alchemist/test/snapshot20.test.mjs
- test/fixtures/task20/snapshot-v1.json
- test/task15_client_test.dart
- test/task15_diary_test.dart
- test/task16_catalog_integration_test.dart
- test/task18_queue_test.dart
- test/task20_admin_test.dart
- test/task20_diary_test.dart
- test/task20_snapshot_test.dart
- test/task20_widget_test.dart

Нулевой diff к базе: android/, third_party/, .github/, pubspec.yaml/lock, lib/data/app_database.dart, lib/auth19/, lib/main_auth19.dart, server/alchemist/src/. Ни applicationId, ни versionCode28, ни signing, ни active GAS6 не изменялись. Ни одна пользовательская база/медиа не была доступна для переписывания. APK28 не заменены.
