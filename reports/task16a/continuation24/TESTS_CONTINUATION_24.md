# Проверки продолжения №16/16-А, сборка24

| Проверка | Статус | Доказательство |
|---|---|---|
| Совместимость старых капсул и новые метки | PASS | target34теста; первая регрессия3случая устранена и отдельно сохранена REGRESSION_REPAIR_24.json |
| Полный Flutter | PASS,424 | CI43070740850/sourcecbe0524 |
| Node нового сервера/CI | PASS,43 | CI43070740850; runtime backend не менялся |
| Старый backend | PASS,24 | Тот же CI; код старого дневника не менялся |
| Analyzer/format/contracts/fixedCLIENT | PASS | Тот же CI |
| Master+Client APK24 один SHA | PASS | Build43072088028, sourcecbe0524, разные постоянные packageId |
| Реальный compiled endpoint+WebID | PASS | Обе kernel_blob.bin проверены CI и после независимого скачивания |
| Действительная стабильная подпись | PASS | CI и независимый apksigner обеих APK, прежние SHA1/SHA256 |
| Размер/SHA GitHub assets | PASS | Обе скачанные APK совпали с CI и server-side GitHub digest, APK_PAIR_24.json |
| Конфликтующая промежуточная версия | FAIL_REPAIRED | Source1a5 не прошёл3legacyтеста, не выпущен; corrected cbe полный PASS |
| Existing server6/exact audience/private ACL | PASS,read-only | runs43069660391/43079763564; без deploy/bootstrap |
| Google-вход двух настоящих людей | BLOCKED | Реальные MASTER/CLIENT proof отсутствуют, нужны телефоны; fixture не считается |
| Элман3реальныхтрека → diary → client → offline | NOT_RUN | PHONE_QA_24.md — шаги владельца/клиента |
| Действительная установка поверх с файлами | NOT_RUN | Package/cert/DB-compatible tests PASS, реальный телефон не проверялся |
| Реальное скачивание на Android | NOT_RUN | Серверные файлы и скачивание в execution workspace PASS; нужен клик владельца на телефоне |

Полная147-строчная матрица ACCEPTANCE_CURRENT_24.md/JSON. Старые отчёты/PREFLIGHT не перезаписаны. Ни токены, ни owner sub, ни signing key не включены.
