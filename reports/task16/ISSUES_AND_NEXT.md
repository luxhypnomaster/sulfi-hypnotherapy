# Незавершённое и точка продолжения

Дата: 10.11.2026 UTC. Ветка: feat/task16-alchemist-full-server. Контрольная точка отчёта: ae18d11bb0208bb7461574df152fa98b55c2fe2d.

Приложение/APK source: 953d5bc4a47c0c26d054e1c8c3a2ac9f8b486822. [CI 42819404870](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42819404870). [Настоящий deploy 42820498828](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/42820498828), стадия VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED. Ошибка/ограничение: `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`. Старый «Сульфи — дневник» не изменялся.

Полный локальный Flutter: 418 PASS, анализ без замечаний. Node нового сервера: 30 PASS; старого:24 PASS. Контролируемый Drive-адаптер в Node/localhost НЕ является живым Google Drive. Снимки UI — рендер Flutter, не установленный Android.


1. Актуальный cloud blocker: `GOOGLE_RUNTIME_HTTP403_ANONYMOUS_OWNER_HTTP200_CONSENT_HTML`; стадия VERSION_2_DEPLOYED_RUNTIME_CONSENT_NOT_VERIFIED, real run42820498828. Не требовать повторного clasp login, ПК или ручного копирования JS. Если это runtime Google consent/Cloud API capability, устранять только точную подтверждённую причину через поддерживаемый owner flow на телефоне; ни grant коннектора, ни переключатель Apps Script API не заменяют consent.
2. Отдельно отсутствует legitimate Android Google web OAuth client ID. Нужна привязка Android packages/certificate к действующему Google OAuth проекту и web audience; не использовать installed clasp client или вымышленные IDs. Без него SDK login/master mutation в APK BLOCKED. Автоматически установить публичный /exec допустимо только после реальных health+storage readbacks.
3. После разрешения cloud gate — create-once продолжить существующий scriptId, push/readback только проверенного source, version/deployment update, private bootstrap41+replay. Не создавать второй Script и не трогать старый дневник. Если проект создан, ориентироваться на persisted marker и verified ID, не на догадки.
4. Настоящий E2E с синтетическими PNG, multiMB audio, MP4, ZIP через master services/server/private Drive/client installer; SHA, interrupted resume, exact ContentLink, private denial, withdrawal/offline retention, metadata-only. Localhost tests уже выполнены и не заменяют это.
5. Обе connected APK одной версии/SHA, затем физическая приёмка: вход Google, обновление поверх, существующая библиотека/история/диктофон, дневник офлайн/очередь/синхронизация, установка модуля, video/audio/background/lock/reconnect/low space. Пока NOT_RUN.
6. G3 конфликтная side-by-side legacy migration остаётся fail-closed по разрешённой ТЗ политике. Не включать замену старых bytes ради формальной полноты; требуется отдельное доказанное inventory+backup+reconciliation.

Продолжать №16, не создавать №17. Не повторять C0; PREFLIGHT.md неизменён. Рабочая ветка feat/task16-alchemist-full-server, PROGRESS.md хранит checkpoints и фактические результаты. Новый blocker не отменяет завершённые независимые проверки/разработку.

## Проверенная граница продолжения

Повторный clasp login/перенос refresh token НЕ нужен. Новый Script уже создан, полный код и версия2 опубликованы; root/bootstrap пока не вызывался. Остаток — lawful authorization/execution нового Web App и настоящий JSON health, затем owner bootstrap41/replay, live negatives и E2E. С телефона владелец может открыть фактический URL нового Web App в своём Google-аккаунте, если Google покажет штатное разрешение именно этому проекту; не предполагаем, что prompt обязательно доступен. Код в редактор вручную не переносить. Подменять это копированием CI credentials в APK нельзя. Android web OAuth audience — отдельная отсутствующая публичная конфигурация, не пароль.
