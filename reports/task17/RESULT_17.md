# №17 — промежуточный результат, приёмка не завершена

Состояние: Полный verify PASS:468 Flutter tests, CLIENT variant,47 Node и legacy backend/schema/analyze/format. Native upgrade пока не запускался: сборка повторяется после подтверждённой ошибки доступа к официальной Kotlin-зависимости. APK27 ещё не выданы. Google-входы на двух телефонах и LIVE публикации №17 не проверены.

- Код: `85ff50736c6be28bda55cf759f232d8347f3ad3e`, ветка `fix/task17-stable-auth-queue`, [draft PR48](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/48). База PR47 не merged; main0800f34... не изменён.
- [Полный CI и native gate](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43513716062). Зарезервировано0.4.19+27, packages и ключ подписи прежние.
- Существующий GAS: deployed-source1a0cf8e5a60144075eec793767953586bfa319a2, историческая version6; read-only health200. Новый сервер не создавался, deployment не изменён.
- G0: подтверждены независимые причины нулевых попыток, pause/resume и каталожного credential, описаны в ROOT_CAUSE_17. G1: общая сессия, single-flight silent restore, сохранённый logout intent, защита другого owner и локальные offline drafts. Физическая устойчивость15/30/60мин пока NOT_RUN.
- G2: существующая durable очередь; атомарный intent, Resume, server readback перед повтором неопределённого commit, прежние requestId/receipts и изоляция owner.
- G3: отдельные каталог и дневник, reader published без номера, сравнение реальных правок. Controlled модуль3треков+программа/template IDs+ContentLink+CLIENT install. Короткая запись без блоков требует отдельного согласования server diff; он НЕ развёрнут.
- G4: предпросмотр всех страниц, переход к точной задаче, причины ожидания/паузы, жёлтый индикатор/щит, shared Google panel, версия устройства, исправленный autosave, сохранённый профиль и защита от новых дублей категорий.
- G5: build attempt1 FAILED до компиляции приложения; оба официальных POM теперьHTTP200, один bounded повтор только failed jobs. Пока PENDING — нельзя выдавать APK до фактических native checks, проверки подписи, raw download SHA и целостности данных.

Ограничения: нет реальных Google-пользователей/физических телефонов в среде; нет разрешения на production GAS diff. Пользовательские базы/медиа, исходные №16/16А/16Б/16В/16Г, старые APK и их отчёты сохранены. Отчёты №17 размещаются отдельно и будут обновлены после CI.
