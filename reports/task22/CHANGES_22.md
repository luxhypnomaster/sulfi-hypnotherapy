# Изменения №22

Кодовая точка `a5a4c771ab3f9fc9030d46fd6bb41a6a11ea1dde`; ветка `feat/task22-server-ratings-admin`, base PR52 `40b7c59e67921f456c3c5a4e943bd40f7232f336` → PR51 `a7c29a7b478b6c3b001d70d3158b4a65d57b3c50`. PR51/52 OPEN DRAFT, не merged. main `b88637a105b2182c7b836311ebb3de7ad037b08f` не менялся. Draft PR22: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/54.

| Область | Файлы | Получившееся поведение |
|---|---|---|
| Durable server | experimental/project_store22,server_jobs22 | Одна операция на owner/request; immutable result и receipt атомарны; lease/fencing, ошибки и retry bounded |
| Backup | experimental/backup22 | Полный candidate SQLite snapshot+immutable media, AES-GCM, readback, фактический isolated cold restore; overwrite запрещён |
| IAM | experimental/identity_roles22,google_bridge22 | Verified issuer/sub UID, legacy subject сохранён в job processing, роль OWNER нельзя назначить произвольно; issuer alias Google нормализуется после verifier |
| Ratings | experimental/rating_calculator22,ratings22 | Три поля; direct cohorts vs context; 1/5/10/30/500 fixtures; policy/strategy registry и immutable versions; rollback пересчитывает текущее consented evidence |
| API | experimental/project_runtime22,catalog22 | Additive negotiated protocol22;7 overview секций; exact course refs; batch/category/job/policy endpoints; исходный Router не изменён |
| Cache/queue | lib/services/project22_runtime,session_controller,alchemist_work_queue | Флаг OFF, прежний broker/queue18, immutable scoped cache/hash, metadata приоритет только перед ожидающим файлом, 403 скрывает admin data |
| Feedback/playback | feedback22_store,playback22_evidence,session_engine | Только интервалы реального transport position; seek/pause не внимание/слушание; private notes не попадают в payload; отдельное согласие |
| Courses | course22_store,course22_editor,course22_screen | Локальный author draft, drag refs, серверная квитанция, readiness с проверкой медиа, точный курсор, отдельный optional course review |
| Management | admin22_screen,catalog22_batch_screen,rating_policy22_screen |7 секций,5 paired tabs+2 single dashboards, honest unknown, typed parameters без eval, persisted batch intent и parent/archive категории |
| Links/origins | diary_content_link,templates_screen | В flag22 отсутствующий exact source не даёт dead install CTA; official deletion tombstone; legacy flag-OFF behavior сохранён |

Нет изменений к production GAS/src, старому Google дневнику, android/third_party, signing, OAuth, workflows, pubspec/lock и versionCode. В production это не подключено. Нет реальной миграции пользовательской SQLite: новые записи только отдельные app_settings namespaces на штатной схеме9. Новые mutable server таблицы существуют только в disposable candidate SQLite.

Контрольные коммиты:0cc1e6d inputs/G0;f8ba3bd initial server/UI;ce8f4a9 safety recovery;772cc39 Flutter+editor;402346c courses/control;0adcb4d batch;54c1932 lint/source freeze;9113800 receipt/revoke monotonicity;52ea01c derived overview cache и format-only metadata_runtime. История не переписывалась. После перезапуска /dev/shm незакоммиченные дополнения восстановлены и протестированы заново; потерянные старые logs не выдаются за final evidence.

Дополнительные checkpoints:9113800 receipts/revoke;52ea01c cached overview + explicit invalidation; a5a4c77 deterministic mini-KPI order. Послеa5a4c77 код заморожен, только docs/delivery.
