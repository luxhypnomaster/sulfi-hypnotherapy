# №17 — изменения кандидата

App source fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568; draft PR48 от необъединённого PR47. Точные причины и тесты в ROOT_CAUSE_17.md; checkpoint-коммиты сохранены без переписывания истории.

- G0/G1: opt-in safe trace; единый dynamic credential, server-verified scope, single-flight restore/refresh, persistent manual logout, late-login/owner guards, official Android SDK fork без all-account automatic fallback. Native upstream Kotlin неизменён; лицензия и pins сохранены.
- G2: исправлена существующая durable queue, атомарный enqueue+intent, deferred Resume, отдельные lifecycle/user/owner pauses, stable owner binding, uncertainty GET→same idempotency key/receipt. Нет второй очереди и новых таблиц.
- G3: каталог и дневник раздельно, exact published ContentLink, title+message client payload без фиктивных блоков, semantic draft comparison по content hashes вместо locator/path. Published reader/author статусы сохраняются без number/feed cache. Controlled dependency install сохраняет template IDs.
- G4: mandatory all-page preview→exact task, failed enqueue keeps draft/editor; yellow indicator/shield, accurate known-byte progress, shared Google account panel/real version; autosave focus, author profile and new-category dedupe без удаления прежних IDs.
- G5: candidate0.4.19+27, прежние packages/cert; full verify469Flutter/47Node/24legacy/3CLIENT PASS; native CLIENT25→27 PASS, MASTER lanes BLOCKED до candidate install. Пара НЕ выдана.
- Server: только candidate Diary.js one-condition diff. Он НЕ deployed. Отдельный reviewed main-only tool не перенесён в main и не запускался. SQLite bootstrap/media/IDs/signing/Android Back и production boundaries сохранены.
