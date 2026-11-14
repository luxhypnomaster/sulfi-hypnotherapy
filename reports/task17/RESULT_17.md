# №17 — результат продолжения

Срез: 2026-11-14T03:22:58+00:00. Общая приёмка **PARTIAL, НЕ ЗАКРЫТА**. APK27 НЕ выданы. Собранные бинарники остаются в приватном карантине до полного native gate и независимой проверки скачанных файлов.

## Точные исходники и границы

- Приложения: `fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568`, версия `0.4.19+27`, ветка `fix/task17-stable-auth-queue`, [draft PR48](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/48). PR47 — база, а не объединённый main. Отдельные checkpoint-коммиты G0–G4 и CI-инструменты сохранены в этой ветке.
- [Полный CI / сборка / три native lane](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43548636228): verify **success**, build **success**; состояние всего run — completed/failure. Последующие изменения отчётов/инструмента не подменяют source APK.
- main `0800f34f759686b18f459cd9914d22e7f1f521e9` не изменён. PR45/46/47/48 не считаются автоматически merged.
- Действующий GAS: прежний Script/deployment, историческая version6, health source `1a0cf8e5a60144075eec793767953586bfa319a2`. Read-only health HTTP200. Текущий административный numeric version readback **NOT_RUN**, сам health это число не доказывает. Production write, bootstrap, OAuth и ACL не выполнялись.

## Что изменено

G0: причины повторного входа, нулевых попыток, pause/resume и старого номера версии привязаны к конкретному коду и RED→GREEN тестам в ROOT_CAUSE_17. Наблюдения владельца не подменены реконструированными логами.

G1: общая Google-сессия дневника/каталога/установщика, single-flight silent restore/refresh, сохранённый ручной logout, защита позднего async входа и переключения owner. Узкий фикс официального Android SDK исключает повторный fallback с выбором неавторизованного аккаунта. Это не обещание отсутствия любого системного Google prompt. Локальная работа MASTER без Google отделена от серверной роли.

G2: исправлена существующая очередь: атомарный durable intent, Resume после текущего HTTP, причины ожидания, стабильный server-verified owner, три уровня идемпотентности. При потерянном commit-ответе сначала authoritative GET, затем тот же requestId/receipt. Отмена не снимает публикацию и не удаляет оригиналы.

G3: каталог и дневник публикуются раздельно. Controlled модуль из трёх валидных AAC fixtures и программа используют прежние IDs и точные зависимости; CLIENT устанавливает выборочно и повторно без лишних байтов. ContentLink выбирается из настоящей опубликованной ревизии, авторский текст не превращается в кнопку. Исправлены ложный черновик из-за locator/path и авторский published label при ещё пустом reader-cache.

G4: обязательный предпросмотр всех страниц, переход к точной задаче, сохранение editor/draft при отказе enqueue, честные стадии/байты, жёлтый общий индикатор/щит, единая Google-панель и реальный PackageManager номер. Фокус формы сохраняется при autosave; профиль автора восстанавливается; новые категории не создают case/space дубли, прежние ID не объединяются.

## Android safety

| Обновление | CI outcome | Фактические cases |
|---|---|---|
| MASTER25→27 | failure | install_baseline=BLOCKED; driver=BLOCKED |
| MASTER26→27 | failure | install_baseline=PASS; ui_import_1=PASS; ui_import_2=PASS; ui_import_3=PASS; ui_module_elman=PASS; ui_module_pause=BLOCKED; driver=BLOCKED |
| CLIENT25→27 | success | install_baseline=PASS; ui_import_1=PASS; ui_import_2=PASS; ui_import_3=PASS; ui_module_elman=PASS; ui_module_pause=PASS; ui_template=PASS; ui_history=PASS; ui_diary_auth_boundary=NOT_RUN; beforeBaseline_inventory=PASS; native_update_to27=PASS; ui_afterCandidate=PASS; cold_restart27=PASS |

SQL используется только для чтения копий. Данные создаются через UI, обновление обычное `adb install -r` в disposable CI. Это не устройства владельца. Legacy Google drafts на старых APK требуют настоящего входа: **NOT_RUN**, не заменены SQL-seeding. Новый offline draft после обновления проверяется отдельно. Capsule/SQLite/WAL fault tests отделены от native UI; они не выданы за Google E2E.

## Оставшиеся препятствия

1. GAS6 отклоняет короткий title+message без блоков. Подготовлен one-condition Diary diff, восемь controlled тестов, полный baseline hash dry-run и доверенный инструмент. **LIVE BLOCKED_OWNER_APPROVAL**. Запрос касается только трёх файлов инструмента в main и этого патча/rollback6; не merge всего PR48. Детали SERVER_CHANGE_REQUEST_17.
2. Реальные Google MASTER/CLIENT, ожидание15/30/60мин, публикация реального модуля/программы, ContentLink и слышимое офлайн-воспроизведение на втором телефоне — **OWNER NOT_RUN**. Fake/loopback/native AudioTrack не являются физическим PASS.
3. Ни пользовательские данные, ни старые APK, ни отчёты №16, ни старый дневник не изменены. Подробная матрица содержит все67 исходных критериев и отдельные CODE/CONTROLLED/LIVE/OWNER.

[Отчёты №17](https://drive.google.com/drive/folders/1fXpE8oU3HSE1g89jQppUxFPBgJLh7LqI). Ссылки на APK допустимы только из APK_PAIR_17.json после actual raw readback. В Google Drive APK не загружаются.
