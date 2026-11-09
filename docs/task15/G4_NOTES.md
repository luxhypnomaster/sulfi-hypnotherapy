# G4 — локальный дневник

Шесть категорий, независимые priority/urgent и publication lifecycle хранятся в optional extra.publication, неизвестные root/nested поля сохраняются. Legacy readingState не переписан. Новый DiaryReadStore использует namespaced app_settings, reader UUID/entry/cycle, индивидуальные textEnd/page/audio intervals. Schema9 и импорт аудиофайлов не изменены. Quiet edit не сбрасывает read; частичный прогресс другой редакции автоматически не переносится.

На последней фактической странице есть «Дочитано» после содержимого: открытие и перелистывание назад не подтверждают чтение. EOF общего PreviewPlayer теперь доступен DiaryAudio; natural heard intervals проверяются с elapsed time и seekEpoch, сам seek-to-end не завершает чтение. Mixed требует обе части. Частичный прогресс сериализуется локально. Reader-owned audio живёт в контроллере; превью отдельное, без read side effects.

Home использует прежний DiaryHomeMessage и заставку; currentEntry выбирает непрочитанное активное, newest first, далее normal/high alternation. Курсор меняется только после возврата из чтения, не во время build. Manual close/UTC expiry исключают Home, но публикации остаются в архиве. Авторские controls меняют локальный draft; они явно не изображают успешную синхронизацию. Новые metadata/ContentLink заблокированы перед legacy API.

ContentLink picker выбирает настоящий immutable ключ ContentRevisionStore. DiffPlan metadata/reorder/reannounce=0 binary, новая image=1. Public future projection не раскрывает localPath/Drive locator/read state/private root. G5 проверяет отдельный FakeProvider.

UI_BLOCKER K-008: медиавитрина и Home preview не получили утверждённого layout. Новый художественный вариант не создавался; реальный DiaryReader preview работает, Home media preview не заявлен DONE. DAY-20 PARTIAL.

Тесты: g5-tests.log повтор G4 8 PASS после исправления initial Future fake-zone deadlock; g4-retest.log 38 PASS (8 новых +30 прежних мультимедиа); первые legacy ошибки uninitialized controller устранены и повторены. Остальные legacy publishing/transport тесты проходили; весь набор повторится один раз наG6. Физический звук/фокус/блокировка Android — NOT_RUN.
