# Предполётная карта и границы №25

## Цель
Не новые крупные функции и не отдельный PRO MA; это объединение накопленных результатов и проверочная двухвариантная Android-сборка с жизненно важным контролем сохранности локальной информации.

## Затрагиваемые системы и подтверждённые границы
- Продукт MASTER/CLIENT: общий Flutter/Dart codebase и editions; неизменные package IDs. Синтетическая локальная жизнь приложения должна работать offline/без принудительного Google chooser.
- Локальная SQLite schema9, аудио, файлы, черновики, дневник, history, capsules schema1, recovery/copy-only guard №23. Фактический диагноз owner MASTER24→25 остаётся UNKNOWN.
- Рабочая очередь/фоновые операции, авторизация и secure session, no-duplicate routing №24.
- Каталог HEAD/snapshot и preview №20–21, server/ratings/courses №22: client/server candidate с SULFI_PROJECT22/defaultOFF, нет производственного GAS adapter и live private backup. НЕ включать новые серверные возможности в production ради прохождения сборки.
- MASTER/CLIENT full APK candidate, CI runner, защищённый test signing и future owner QA.
- Отдельная MA professional app и редакционный MASTER — не смешивать права; проект master-alchemica не редактировать.

## Решение A/B/C
A (сейчас): line-by-line review stacked ancestry; локальные тесты и сохранность; source gate; безопасная интеграция на отдельной ветке; Android build в пригодном окружении после hard gates; независимая проверка APK; синтетическое normal-upgrade QA.
B (контракт сейчас): status/evidence for live backend, signed candidate revision, immutable package/build manifest, rating NOT_CALIBRATED and flags OFF; ничего не активировать на живом сервисе.
C (отложить): live production GAS adapter и full backup/restore, реальные Google-пары, владелец-устройство/дневники, PRO/MA, полный ratings policy, массовый курсный deployment, UX owner-final, Play/RuStore публикация — отдельный scope/разрешение. Не менять архитектуру ради неутверждённой функции.

## Границы готовности
1) **INTEGRATION_READY**: источник/дерево/тесты и согласованность веток подтверждены.
2) **NATIVE_CANDIDATE**: каждый APK реально собран и проверен собственной подписью/identity/version, + synthetic install-r gate PASS при наличии Android.
3) **OWNER_DEVICE_ACCEPTED**: только отдельное испытание владельца — НЕ достигать автоматически.
4) **SERVER_PROD_READY**: только после live ACL/backup/restore/readback/rollback/real OAuth, №22 сейчас BLOCKED_LIVE.
Не смешивать метки.

## Актуальность платформы
На 22.11.2026 по официальному Android Developers для Google Play новых мобильных приложений/апдейтов target API 36+; текущий source план API36, но скрипт должен проверить реальные compileSdk/targetSdk/debug restrictions и актуальные SDK/Play/RuStore требования непосредственно перед финальным выходом. https://developer.android.com/google/play/requirements/target-sdk. Пробная APK, устанавливаемая вручную, не равна готовности к магазину. Документ не разрешает менять SDK/Gradle по умолчанию.
