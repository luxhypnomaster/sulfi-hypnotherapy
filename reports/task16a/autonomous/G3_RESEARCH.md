# №16 — G3: инвентаризация и миграция только в sandbox

Основа: c895291 (код APK24 — cbe05240d463b9dafbe9a12ee831c967bdbf6113). Реальная база владельца не открывалась. Изменений в lib/, Android package/version/signature и запуске приложения нет. Прототип импортируется только тестами из tool/task16/g3_sandbox.dart.

## Обнаруженная граница

В audio_assets одна строка на logical ID; SqliteLibraryRepository.save запрещает замену байтов тем же ID. Это необходимая защита: SessionController.asset(id), preview и playback разрешают текущую строку, а история хранит snapshot.audioMetadata[id].contentHash. Простое снятие запрета подменило бы звук в старых сессиях. content_revisions уже сохраняет immutable снимки, startup сохраняет их байты, но точного разрешения всех читателей ещё нет.

Revision ID — hash канонических metadata/dependencies, а blob SHA — hash аудиобайтов; это разные значения. Одного blob SHA недостаточно для установления старой metadata-ревизии. При двух metadata-ревизиях с одинаковыми байтами и без однозначного frozen proof прототип отказывается угадывать.

## Реализованный эксперимент

1. Read-only inventory: audio_assets, content_revisions, current_draft, session_runs, session_templates, module_definitions; hash/size физических asset_* файлов без следования symlink. Plan fingerprint привязан к строкам и именам/байтам. Active sessions, неизвестная/неоднозначная история, пропавшие или неверные bytes — blocker.
2. Dry-run: две ревизии одного logical ID, два проверенных blob, две привязки; writesToSource=0. Результат и фактический fingerprint — G3_DRY_RUN.json. Фикстура каждый запуск новая; fingerprint не является fingerprint базы владельца.
3. Apply только в новый системный временный каталог с маркером. VACUUM INTO создаёт source-backup.sqlite; отдельная candidate.sqlite проверяется по fingerprint. Blob-копии адресованы SHA и проверяются после копирования. В одной sandbox-транзакции создаются g3_revisions, g3_refs и g3_heads; immutable revisions защищены от UPDATE/DELETE. Старые строки остаются нетронутыми.
4. exact(logicalId, revisionId, blobSha) проверяет immutable metadata, logical ID, размер и SHA файла. Нет fallback на текущую head. Переключение experimental head на B не меняет history A. Изменённые byte-файлы отвергаются.
5. Rollback создаёт ещё одну копию backup, проверенную SQLite integrity_check; никакие файлы не удаляются и база-источник не заменяется. Injected pre-commit failure не меняет исходные history/audio.

## Проверено

7 новых тестов и 3 существующих boundary-теста: 10 PASS. flutter analyze --fatal-infos: No issues found. Проверены сохранность источника, A/B, exact playback bytes (не слышимый звук), неизменяемость строк, stale plan, active session, неоднозначная история/metadata, tampered blob, инъекция сбоя, rollback и SQLite integrity. Это Flutter/FFI fixture-тесты, не проверка Android migration на настоящей базе.

## Обязательные читатели перед интеграцией

| Участок | Что необходимо |
|---|---|
| SessionPlan/Step и current_draft | Явная exact RevisionKey; существующие текущие refs фиксировать без угадывания |
| SessionController.asset/duration/snapshotForStart/playback | Resolver logical+revision+blob; отсутствие exact bytes блокирует запуск, не выбирает head |
| History repeat/resume/template from run | Frozen snapshot, отдельно авторская metadata и личные записи |
| Preview/Library/UI selection | Список ревизий, осознанный выбор текущей; preview выбранных bytes |
| Module/template dependencies | Транзитивная exact closure, два разных track revisions в одной сессии |
| Capsule export/merge и Alchemist install | Перенос всех выбранных ревизий и байтов; конфликт head не перезаписывает immutable refs |
| Startup ownership/delete | Retained refs и recordings; никаких GC по одной лишь текущей строке |
| Backup/recovery | Consistent DB+bytes snapshot, процессный lock, crash recovery и работа без свободного места |

## Безопасная последовательность внедрения

До physical QA можно принять только исследования/тесты и продолжать точный resolver отдельным PR. Продуктовую схему не мигрировать, save guard не снимать. Перед дальнейшим применением: полный reader checklist, проверенные backup+restore на disposable копии, отсутствие active runs и конкурентной записи, crash/no-space matrix, затем отдельное разрешение владельца и физическая приёмка. Этот прототип не является готовым мигратором пользовательских данных. При ambiguities нужен ручной выбор, никакого автоматического перепривязывания истории.

Повторить безопасно: flutter test test/task16_g3_sandbox_test.dart test/task15_revision_boundary_test.dart --reporter expanded. Скрипт не принимает путь к пользовательской базе и не включён в приложение. Production rollout/GC/восстановление поверх настоящей базы: NOT_RUN и не разрешены этой работой.
