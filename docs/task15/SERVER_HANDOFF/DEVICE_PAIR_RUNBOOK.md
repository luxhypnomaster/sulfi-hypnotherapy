# Физическая приёмка двух телефонов — NOT_RUN

Предварительно закрыть G3 и настроить подтверждённый staging server отдельным ТЗ. Сейчас APK не соединены живым облаком. Локальные fixture-тесты не означают, что этот сценарий уже выполнен.

1. A: экспортировать backup личных данных штатным способом в выбранное владельцем место. Установить author/test поверх прежнего приложения БЕЗ удаления. Проверить package, постоянный cert SHA и build18. Проверить сохранность4треков/шаблонов/истории. При конфликте НЕ удалять, записать diagnostics.
2. B: установить отдельный «Сульфи — клиент (тест)» .clienttest. Проверить отсутствие author/editor/publish/login controls, shield не повышает привилегии. Проверить отказ прямого write API без grant.
3. A: создать text+PNG+AAC+exact ContentLink; preview не публикует и не меняет read. Опубликовать в staging, записать manifest revision/ETag/cycle/blob count.
4. B: получить feed/media; отключить сеть; открыть/закрыть — unread; дочитать последний лист, аудио pause/seek-to-end не equals read; реально дослушать. Mixed read только после обеих частей. Закрыть приложение/перезапустить — partial/read сохранены только уB.
5. B: ContentLink → exact package install → прежний плеер; порядок3audio+2pause и SHA совпадают. A history/reader state/manifest не изменены.
6. A: quiet title/category/order edit: uploads0, Bread не сброшен. Заменить1картинку: upload1, старыйblob retained. Параллельная правка со старым If-Match →412; retry samekey/body не дублирует commit.
7. A: «Показать снова как новое»: новыйcycle, unchangedmedia uploads0. B sync →unread. Amanualclose / timed UTC expiry / earlier ofboth →BHomeнепоказывает, архивсохранён.
8. Проверить 320/360/412, textscale1/1.3/1.6, шторку/блокировку/background/audio focus/наушники/звонок/микрофон, реальный SAF save/import и duplicate filename suffix.
9. Записать моделиAndroid/OS/appversion/SHA, screenshots/video/counters/UTC timestamps без личных токенов. Owner подписывает PASS/FAIL по пунктам; remote/physical результаты хранятся отдельно от локальных.
