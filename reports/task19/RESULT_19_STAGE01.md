# №19 G0–G1 — PARTIAL, только изолированный прототип

АрхивЗадание_19.zip SHA256591271cc99ee485c2fad775b0077b756c5c37ecf7401a19f97652f7d4f913b3f совпал,6файлов прочитаны, manifest/CRC PASS. БазаGit363a024 отнеобъединённогоPR49, sourceAPK28de408f1. Веткаfeat/task19-auth-stage01, отдельныйworktree. Последние№18CIзавершены; егоruntime/source сохранены, чужой research16worktree и егоuntrackedfiles не трогались.

G0: составлен фактический call graph и кандидатный401/samecachedID path с controlled unit reproduction. Точная причина picker на телефоне не доказана, требуетсяownertrace. СвереныGoogle7.2.0/fork7.2.18, packages/SHA1/publicWebaudience поисторическойрегистрации/неизменнымAPK28digest; текущийGoogleConsoleTesting/scopes не выдаётсяза проверенный. СравненыофициальныеPKCEиnativeID+access flows. InventorylegacyGoogle sub иplan immutableapp_user_id подготовлен без миграции.

G1: реализован отдельный PKCE/S256 Supabase Auth REST prototype, single native refresh broker, KeystoreAES-GCM/AtomicFile+per-install OSlock, readygate, restore/401refresh/revoked/offline/backendstates, local logout, strictcallbacks/replay denial, nativeworker allowlist/pinneduid+epoch. Same-owner token refresh не меняет authorityepoch. DartonAuthStateChange обработанonError. FlagdefaultOFF; .auth19packages и отдельныйentrypoint, оригинальныйmain/GoogleSDK/auth/SQLite/transferMain не переписаны.

Не предоставлена конфигурация staging Supabase: liveLogin/refresh/2аккаунта/2телефона BLOCKED, OWNER_SETUP_19.mdготов. PrototypeнеподключёнкGAS: нуженfutureG3bridge, нельзяподставлятьSupabaseJWTвстарыйGoogleissuer verifier. G2+billing/Storage/migrations/catalog/UX/transport768KiB/locks не выполнялись.

Фактические тесты:493Flutter+2skips, targeted5, Node47+24, JVMinitial17/24; latestnativechecks/localbuildstatus см.TESTS. CI43949403640 не стартовал из-заGitHubbilling/spendingerror, не sourcefailure. ПовторCI/платежи/productiondeploy не запускались. ЛокальноAndroidcode компилируетсясоSDK36/Flutterembedding; Gradlebuild исследуется. Keystore/emulator/Googlephone не объявленыPASS.

GAS6, main, OAuthACL, signing keys, опубликованные материалы и личные данные не изменены. РабочиеMASTER28/CLIENT28 не заменены. Отчёты/исходники в featurebranch; draftPR будет создан после финальной локальной проверки. Это не завершение всего№19 и не разрешение наcutover.
