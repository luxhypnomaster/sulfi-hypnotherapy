# Физическое хранилище и ACL

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Контрольная точка отчёта: ae18d11bb0208bb7461574df152fa98b55c2fe2d.

Приложение/APK source: 953d5bc4a47c0c26d054e1c8c3a2ac9f8b486822. [CI 42819404870](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42819404870). [Настоящий deploy 42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828), стадия VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED. Ошибка/ограничение: `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`. Старый «Сульфи — дневник» не изменялся.

Полный локальный Flutter: 418 PASS, анализ без замечаний. Node нового сервера: 30 PASS; старого:24 PASS. Контролируемый Drive-адаптер в Node/localhost НЕ является живым Google Drive. Снимки UI — рендер Flutter, не установленный Android.


Закрытый parent «Проект Алхимик» повторно прочитан connector metadata: shared=false/owner-only. Runtime bootstrap также проверяет parent/каждую папку: MIME, exact name, единственный parent, owner, effective permissions; неоднозначные дубли/небезопасный ACL fail-closed. Registry pathKey→ID в private Script Properties; повторное развёртывание использует прежние IDs. Registry и actual blob files дополнительно проверяются на explicit permissions, даже если parent остался private.

Схема: root «Хранилище Сервера Проекта Алхимик» +40папок:00_Система(config/registry/indexes/grants/audit/backups),10_Дневник(entries/images/audio/video/revisions),20_Библиотека(audio_tracks/modules/templates/sessions/collections),30_Медиа(covers/images/audio_other/video_other/immutable_blobs),40_Пакеты(drafts/published/imports/archived),50_Каталог(publications/index_shards/snapshots/tombstones),90_Техническое(pending_uploads/quarantine/temp/gc_candidates).

Общие byte blobs — один physical parent immutable_blobs, разные logical refs без дублирования. Каталог не является Drive-search и не наследует публичность родителя. Private snapshots/receipts физически в registry, поля типов/публикации в отдельном логическом индексе. Не заявляется, что каждый раздел содержит собственную копию аудио. Нет anyone-writer в новом хранилище, нет создания public blob ACL. Shared assets не удаляются послеwithdraw.

Реальный bootstrap41/replay/Drive readback: NOT_VERIFIED / GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML. Unit bootstrap/replay/ambiguous/unsafe ACL PASS; они не доказывают живое дерево. New Script separately verified shared=false/sole owner; first bootstrap never ran because runtime health failed before JSON. Root/folder IDs не выдумываются и не публикуются в общедоступном отчёте до actual readback.
