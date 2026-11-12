# №16-Б — каталог и дневниковые анонсы

Дата: 12.11.2026. Ветка: `fix/task16b-auth-transfer-publication`. Кандидат приложения: `012f7f69b7ad99c0d44f2a442d9649aa1481117e`. Draft PR: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/45 . Продолжение №16/16-А, не №17.

Новый test/task16b_announcement_e2e_test.dart запускает реальный production JS domain в Node и реальные Dart catalog/diary/install сервисы через loopback. Контролируемая сеть сначала рвёт media.beginUpload: локальный дневниковый draft сохраняется, feed остаётся пустым. После восстановления проверяются отдельная PNG-обложка + три точных трека, публикация каталога и только затем дневника. Повторный Prepare до публикации возвращает тот же draft. Новый анонс опубликованного материала получает новый diary ID и прежний exact ContentLink; число uploaded bytes не увеличивается. CLIENT устанавливает три трека; повторный install не скачивает неизменные blobs. Локальные файлы существуют после теста установки.

Существующий test/task16_catalog_integration_test.dart дополнительно проверяет реальный JS/Dart контракт: потерянный publish response с сохранённым idempotency request, metadata-only retry, 3-track graph, шаблон, сборку, ZIP, отзыв публикации, media/video download, точные SHA и сохранность установленной копии. Исходные функции не переписаны.

Это CODE/CONTROLLED_SERVICE PASS. Google consent, private Drive data plane, реальный «Индукция Элмана вариант 2» владельца и воспроизведение на телефоне не подменяются этими тестами. Пользовательские исходники для теста не копировались.
