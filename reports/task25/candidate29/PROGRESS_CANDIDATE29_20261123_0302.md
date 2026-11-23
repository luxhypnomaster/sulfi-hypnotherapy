# №25 · подготовка APK29 · промежуточная точка 2026-11-23 03:02 UTC

Это промежуточный отчёт, не финальный PASS и не разрешение устанавливать APK.

Приложения: закреплённый проверенный код737ea741636e9abe7c20353d9d5b8301cf44a5bb. Draft PR57 https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/57 ; цепочка20–25 не объединена с main. Изменения только инструментов/отчётов в feature-ветке21681b4; runtime335/native31 сохранены. Действующий GAS6, OAuth/ACL, ключ, старые APK и данные сохранены.

Исходная регрессия:574Flutter PASS/2SKIP, CLIENT1, Node114, Python53; относится к тем же исходникам приложений. Новые инструменты:45Python PASS, actionlint PASS; fixtureJava17/d8 Android36 PASS. Чистый checkout737 + настоящий Flutter pubget: все31 nativeSHA совпали. Это не native Android PASS.

Доверенная main получила через обычные узкие PR59–63 только4файла:2workflow +2скрипта. Ни одной записи напрямую в main, обхода защиты или mergePR51–57. Main0e1d1950f504f7b0cc826a5308a78239d68ddb48, protected=true; owner-readback branch protection сохранён без повторных закрытых AdministrationAPI.

Текущая сборка: https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/45103325755 . Состояние03:02: доверие/наличие прежних4bindings/доступ кэталону PASS, подготовкаSDK. Ключ никогда не попадает в задачу Gradle/app; отдельный signer обрабатываетAPK как данные. Подписанные файлы сначала карантинные. Выдача только после независимой проверки и native28→29 для обеихредакций API34/36.

Предыдущие реальные остановки и исправления:45100730089 — устаревшийSDK tools (PR60);45101058374 — токенread не читает draft28 (PR61:GET-onlybaselinejob, actualCI PASS45101750589);45101750589 — ignored GeneratedPluginRegistrant доpubget (PR62, чистыйcheckout доказан);45102506987 — SDK безтега вернул0.0.0-unknown (PR63 официальный3.47.9 +строгийSHA +реальный versionJSON, безподмены/upgrade). Не повторялись безизменённой диагностической гипотезы. Все журналы/RED-GREEN в PR57 reports/task25/candidate29.

Эталонная пара28 независимо скачана: пакетыMASTER ru.sulfi.sulfi_hypnotherapy иCLIENT .clienttest, min24,target36,arm64/armv7/x86_64, сертификат0b7435682d27200e630d5837d40457fa64e905d8c43c4ea692c7e1a2d810afc6 совпадает. Повторного inspect45096588062 небыло. Планкандидатов0.4.21+29; фактический установленныйcode владельца UNKNOWN.

Следующий безопасный шаг Codex: прочитать фактический результат45103325755; приSUCCESS запустить main sulfi-candidates25-verify.yml, confirmation VERIFY_DISPOSABLE_ANDROID_ONLY, build_run45103325755. Припроблеме сначала доказанная причина, потомминимальный исправленныйPR; нереинициализировать ключ/данные. При nativeошибке переиспользовать те же подписанныеbytes безновой сборки. Физические Google/два телефона/слышимость NOT_RUN; владелец отдельно разрешает испытание своегоустройства после гейтов. Исторический24→25rootcause UNKNOWN, невыдаётся заисправленный.
