# №17 — контрольная точка: native PASS, проверенная пара27

Исходник приложений: `fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568`, версия **0.4.19+27**. Ветка `fix/task17-stable-auth-queue`, draft PR48; PR47 и PR48 не объединены в main. Последующие изменения касаются диагностики, тестового стенда и отчётов: исходники `lib`, `android`, `third_party`, `test`, `server`, `pubspec.yaml` и `pubspec.lock` сохранены относительно проверенного приложения.

## Завершено

- MASTER26→27: run43614090740/job132505244736, driver45aca0c, **13 PASS**, legacy Google draft NOT_RUN; весь run SUCCESS.
- MASTER25→27 run43583577375:13 PASS; CLIENT25→27 run43548636228:12 PASS. Оба legacy Google NOT_RUN.
- Причина наблюдаемого прекращения QEMU доказана монитором: SIGSEGV-11 до candidate/cleanup, не recorded OOM kill. Точная функция неизвестна. Проверенный обход — официальный Emulator37.2.12, SHA архива закреплён; готовность SDK проверяется до baseline.
- Устранены две подтверждённые ошибки UI-драйвера без ослабления assert: route editor vs search и bounded exact readback при transient-пустом accessibility tree.
- Delivery43615276560 SUCCESS; private draft445425835. Обе APK независимо скачаны обратно и прошли apksigner/aapt/SHA/compiled config/DEX guard. `APK_PAIR_17.json` — фактические hashes и URL. APK на Drive нет.
- Полный verify исходникаfbd уже PASS:469 Flutter,3 CLIENT,47 Node+24legacy, schema/analyze/format. Повторные полные CI ради harness/docs не запускались.
- Main b88637a: только ранее разрешённые3inspectfiles. Admin43584729310: version6, HEADsame,23files. Feature-only безопасный HEAD rollback planner/11Node тестов; production apply/rollback не выполнялись.

## Не повторять

Не перестраивать, не переподписывать и не смешивать APK27 с старым85ff507. Не повторять большой E2E или native без новой ошибки/гипотезы. Старые failed receipts и APK сохранены. Не deploy GAS, не переносить PR48 целиком, не менять OAuth/ACL/signing/main и данные владельца.

## Следующий безопасный шаг

PHONE_QA_17.md: GitHub owner login в Chrome → MASTER27 обычным обновлением поверх26 → проверить прежние материалы до Google → CLIENT27 на втором телефоне → настоящие два аккаунта и сценарий module3tracks → catalog → diary ContentLink → selective install → слышимое offline.

Физическая приёмка и legacy Google drafts NOT_RUN. Серверная короткая запись без blocks BLOCKED_OWNER_APPROVAL; план и diff сохранены, разрешение не получено. №17 остаётся PARTIAL, не закрывать и не создавать №18.
