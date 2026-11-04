# Аудит до изменения v4.1 — 2026-11-04

Исходное состояние: cc2492b, feature/v4-modules-recorder-background; develop 505a7f2, main dcec7ed. Новая изолированная ветка feature/v41-final-player создана от develop и fast-forward до уже реализованной V4; main/develop не изменены. Пакет получен через подключённый Google Drive по ссылке владельца, облачный оригинал не изменён. Базовые MD BASELINE_V4 побайтно совпадают с ранее прочитанными docs/v4. Пользовательские current-скриншоты в Git не копируются.

| Подсистема | До работы | Доказательства / действие |
|---|---|---|
| Модель и миграции | DONE (автотесты), устройство NOT TESTED | SQLite v3, v4_models_recording_test + session_storage_test, полный snapshot и independent copies; не переписывать |
| Конструктор/модули | DONE/PARTIAL | modular_structure_screen, module_catalog, независимые повторения; UI рекомендаций отсутствует; проверить сохранение disabled |
| Библиотека/импорт | DONE, native NOT TESTED | library_service и library_screen, приватные копии; picker/decoder требуют Android |
| Диктофон | DONE, native NOT TESTED | record/AAC, pause/resume/finish/save и error-stop; injected backend tests |
| Фон/MediaSession | PARTIAL | service-backed engine, wake lock/media state, native lock screen/focus не проверены |
| Главная/история/контакты | DONE/PARTIAL | реальный полноширинный список, Telegram/email, full-plan repeat; устройство и визуальная приёмка остаются |
| Плеер v4.1 | MISSING | RunScreen V4: нет утверждённой колбы, 6 переходов, seek, общего forecast, current-module context; реализовать |
| Движок v4.1 | PARTIAL | нет seek в SessionTransport, навигации module/phase/track, completed IDs и dynamic total; next из paused возобновляет run — исправить |
| Дневник | BLOCKED / DEFERRED BY OWNER | существующего кода/данных дневника нет; не реализовывать |

## Базовая проверка

flutter pub get --enforce-lockfile PASS; flutter analyze --fatal-infos PASS (No issues found); flutter test PASS (100). Логи /workspace/scratch/v41-baseline-*.log. Предыдущий APK V4 cc2492b успешно собран CI; новый v4.1 пока не собирался. Android устройства/эмулятора нет; это не приёмка нативного звука.

## Политика реализации

Сначала service-backed timeline/nav/forecast и проверка сохранения paused/frozenPlan, затем настоящий Flutter UI. Орнаменты берутся из утверждённого PNG через Canvas source rectangles/clipping; текст/списки/время/кнопки/жидкость рисуются динамически. Новые графические концепты и дневник не добавляются.
