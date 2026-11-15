# №18 — экономия и provenance продолжения

Расход/проценты пользовательского лимита неизвестны; они не рассчитываются. CI_RUNS_CURRENT_18.json — только реальные GitHub runs и wall-clock, не биллинг.

После возврата пользователя сверены уже запущенные5runs, повторно не отправлялись: MASTER-only cached normal upgradeAPI35; full probes33/35/36; legacy-only34. Все используют точный проверенный исходник DE408 и кешированные APK. CLIENT13PASS, fullverify489Flutter/3CLIENT/47+24Node и fullAPI34 11PASS повторно не запускались. Широкаяverify заново выполнялась только после настоящего shipping-code изменения, а не изменения отчёта.

MASTER reroute обоснован новым evidence: прежний API34 hostQEMU SIGSEGV до update/безOOM. Та же подпись/APK/UI-created baseline/15data gates, официальный AOSP API35. Нет послабления критериев и слепого повтора того же API34. Реальные owner устройства не затрагивались.

Доставочный guard усилен8локальными adversarial Python tests; только scripts/reports/workflow delivery, shipping inputs неизменны. Перед реальным append helper заново проверяет actual passed jobs, receipt SHA/source/driver/полный набор cases, каждый APK/cert/config, закрытость existing draft и неизменность27. Новая подпись/сборка/полные тесты ради скачивания не требуются.

Production GAS/OAuth/ACL/main не менялись; платные сервисы, удаление Actions artifacts и публичное открытие репозитория не применялись. APK28 не загружается на Drive по умолчанию.

## Актуальный native итог
Все5cached продолжений завершились SUCCESS: MASTER15; full33/35/36 по10; legacyboth. Дополнительных сборок/подписаний/полных suites не выполнялось. Delivery запущен после шести green gates, не заранее.

Delivery: firstattemptfailedobsoleteSDKtools, secondfailedrepositoryroottrailingSlash404; bothbeforeappend and documented. Narrowfixeswith9tests. Third43765843573SUCCESS restoredsameAPKcache,noapprebuild/signing/native/full-suite repeats. Onlynew28assets appendedtoprivateexistingdraft, original27kept.
