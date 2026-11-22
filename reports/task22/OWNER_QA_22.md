# OWNER QA — будущие действия, не выполнялись в №22

Кодовая точка `a5a4c771ab3f9fc9030d46fd6bb41a6a11ea1dde`; ветка `feat/task22-server-ratings-admin`, base PR52 `40b7c59e67921f456c3c5a4e943bd40f7232f336` → PR51 `a7c29a7b478b6c3b001d70d3158b4a65d57b3c50`. PR51/52 OPEN DRAFT, не merged. main `b88637a105b2182c7b836311ebb3de7ad037b08f` не менялся. Draft PR22: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/54.

Сейчас действий на телефонах не требуется. APK, bundles, Gradle, signing, эмуляторы и физические испытания в №22 DEFERRED_BY_OWNER. Ни один шаг ниже не объявлен PASS.

## До live включения
Review Draft PR/stack51→52→22; закрыть ISSUES и SOURCE/backup/restore/rollback gates SERVER_BASELINE. Runtime22/metadata оставить OFF до реального подходящего API. Отдельно согласовать production policy и значения; до этого weighted=null. Не менять provider/OAuth/ACL только ради демонстрации.

## После следующих кодовых этапов, при отдельной команде на release
1. Закрепить final source, полный regression, прежний защищённый signing. Новый versionCode>28 без новой подписи/packageID. Независимые SHA/certificate/package/version readbacks обеих APK. Никакой установки неподтверждённых APK.
2. На disposable emulator/копиях до владельца: штатные MASTER/CLIENT upgrades с библиотекой/SQLite/WAL/капсулами/историей/черновиками/очередью/аккаунтом; сравнить media hashes, row counts, restored pointers. Не uninstall/clear/downgrade.
3. Два реальных аккаунта: cold/silent restore,1час, ручной logout, revoked token, A→B и роль; private diary/queue/media другого аккаунта не видны, не удалены. Synthetic identities — не PASS.
4. Автор публикует exact module3tracks→program→ordered course и diary ContentLink; клиент получает только допустимые dependencies, SHA/receipt/dedup; locked/missing next не перескакивает курсор. Offline playback точной редакции, личные forks/history не заменены.
5. Background/lock/network-loss/resume/pause/cancel/process-death с queue18 и реальными системными уведомлениями; активный audio/transfer не вытесняется control metadata. Force-stop/reboot/OEM restrictions отдельно, без обещаний обхода Android.
6. Feedback: offline local default,skip завершает history/cursor; opt-in/retry/correct/revoke; program/course direct vs partial/unknown/context,N1/pro и self-test. Rating-only update без media download. OWNER preview/validate/publish/rollback на безопасных данных.
7. Seven management views: real metric source/time, unknown quotas, error precedence,5paired sections+2single dashboards, крупный шрифт/TalkBack9:16. Screenshot Flutter — не этот пункт.

Первые решения владельца потребуются только для конкретного reviewable live diff/гейта или отдельного release этапа. ПК/повторная OAuth-авторизация сейчас не запрашивается. Нет нового номерного ТЗ от Codex.
