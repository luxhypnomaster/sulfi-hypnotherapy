# №17 — источники, преемственность и границы

## Обязательные живые документы

- Оперативное состояние (QA фрагменты 29–42): https://docs.google.com/document/d/1c7I4Ry8RZAk-5yWF1rgy9sdexSJEaCA47OxNRmooPvI/edit
- Реестр концепций K (особенно K-003, 006, 017, 037–045): https://docs.google.com/document/d/14Lcqe6Rn4Q3hxEuHIuYx7nHfUCnCtgm7mNYoXWgj5M4/edit
- Реестр функций F (F-011–F-022): https://docs.google.com/document/d/1UEFVm4MkxxCfC8VAYkSMjrtXkAh_wQloPZEAHnjiKgE/edit
- Roadmap / отложенное: https://docs.google.com/document/d/1j7rf4-VzCTVobAB-wX70oBQGtrRaG39sPah-Ore6eDY/edit
- №16-А серверная Google Identity и роли: https://docs.google.com/document/d/16hMVySJwkS1kABBDyWXTJ3kfogzNJWayCu4LcFh_224/edit
- №16-Г отчёт: https://drive.google.com/file/d/1sv19PxBR_vg2XmVeJqev0pl92V6HegWB/view
- №16-Г issues: https://drive.google.com/file/d/1e5HnBSIQcCP7R_X2vx2UDcqC_IIS55Jv/view
- №16-Г owner QA: https://drive.google.com/file/d/1AuXMbU1k3B5PHmsEVp0iAGw5YdU1Bc45/view
- Отчёты №16: https://drive.google.com/drive/folders/1jVvv6kEm5uUWol92QvJDwqbDkl5oz-5z
- Основное архивное №16: https://drive.google.com/file/d/1QgvwNZcFZjoAVId6no0zEvLzGTyWdZpP/view
- №16-Г дополнение: https://drive.google.com/file/d/1Ex8oDs-nfKAnT5VDwjW00uihbTTPUfOs/view

## Сопоставление требований

| №17 | Ранее | Суть |
|---|---|---|
| G0–G1 | K-039/K-045; F-022; №16-А/Б/Г | Google identity, silent restore, один coherent auth state, server role |
| G2 | K-039/K-040/K-042; №16-Б | owner-bound task, `USER_PAUSED`/`WAITING`, retry/commit/dedupe |
| G3 diary | K-001/K-003/K-006/K-017/K-037/K-042; F-011–F-018 | offline drafts, short-only post, preview, publish, status, content link |
| G3 catalog | K-016/K-017/K-043; F-019/F-020/F-021 | модуль/программа, манифест, 3 трека, выборочная установка CLIENT |
| G4 home | K-030/K-044/POST-13 | кислотно-жёлтый щит, Google account в `Ваше пространство` |
| G4 lists | K-040/K-041 | статус/прогресс, без тяжёлой карточной микро-ленты |
| G4 categories | K-043 | existing category lookup и не создавать новые дубли, без admin CRUD |
| G5 | №16-В/Г | сохранность SQLite, APK, two-device QA, owner acceptance |

## Запрет на ложные дефекты

Текст «Добавь себе в библиотеку» в одной уже дошедшей до CLIENT записи — **короткое послание автора**, не сломанная кнопка. Не заменять его CTA. Иконка Android Back уже правильно возвращается по context stack: не переделывать её. Клиентская запись с картинкой получила данные реально — не объявлять весь diary publish неисправным. Отображение «Черновик» у читателя подтверждённой версии требует исправления.

## Отложено, НЕ в №17

- Полноценная «Стена Сульфи»: пользовательские публикации, комментарии, реакции, модерация, социальная модель.
- Мультимедийная микро-лента: миниатюры, автозагрузка, аудио прямо в списке — следующий клиентский UX этап, но структура diary должна оставаться расширяемой.
- Полный удалённый администратор каталога категорий (rename/merge/reassign/delete) — отдельное ТЗ; в №17 не портить categoryId и защитить новые duplicate names.
- Новые платные и профессиональные visibility/entitlement, оплата, сайт, курсы/опросники и новые обложки. Можно оставить расширяемые модели, но не создавать фиктивные ACL.
- Новый хостинг/собственный сервер, миграция off GAS, смена auth-provider. Рассмотреть только после причинно подтверждённых ограничений GAS в текущем цикле.

## Принцип приёмки

Исторические отчёты №16 — доказательства текущей частичной функциональности, а не отчёт по №17. Codex обязан сослаться на точную прежнюю матрицу, указать что унаследовано/изменено/не трогалось/осталось BLOCKED, не допускать подмены физической проверки synthetic fixture.
