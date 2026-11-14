# №17 — протокол проверок

Источник приложений `fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568`. [CI](https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43548636228); verify=success, build=success. Точные raw logs и JSON receipts хранятся рядом; счётчики предыдущих прогонов не суммируются как независимые тесты.

## CODE / CONTROLLED

- G0: production-path RED lifecycle USER_PAUSED, cold restore ACCOUNT_CHANGED и frozen null catalog credential; исправления GREEN. ROOT_CAUSE_17.md содержит файлы/тесты и пределы доказательства.
- G1: адресный набор13PASS; SDK-boundary test проверяет один authorized/autoSelect запрос и отсутствие unapproved fallback. Persistent logout и late SDK race проверены отдельно.
- G2/G3: пересекающийся адресный набор19PASS: atomic enqueue,5 taps/restart, Resume during HTTP, owner isolation,401/403/network, late restore, durable diary, потерянный ответ реального JS commit. Dart→production-domain JS loopback — CONTROLLED, а не Google/Drive LIVE.
- G4: шесть новых unit/widget проверок, включая последний RED→GREEN published-author label при пустом feed. Focus/selection/composing и editable profile, category IDs, preview всех страниц без read-state writes,5 taps→один review, ошибка enqueue сохраняет точный draft/editor.
- Прежний catalog font200%+keyboard тест и отдельный MediaQuery preview200% PASS; PREVIEW_200_TEST_17.diff делает дополнительный вариант воспроизводимым.
- Финальный verify: lockfile pub get, schema/contract fixtures, Node backend suites, dart format, flutter analyze, полный Flutter набор, CLIENT compile-time tests. Финальный raw log подтверждает469FlutterPASS/0FAIL,3CLIENT tests,47Node и24legacy; CI_FINAL_RESULTS_17.json хранит счётчики и SHA лога. Pipeline целиком FAILURE из-за двух MASTER native lanes, а не verify.
- Security delivery guard:9Python tests PASS (public repo/release, untested trees, pending/failed build/native, missing lane, existing assets отвергаются).
- Отдельный review-only серверный инструмент:8Node tests PASS, Git-source dry-run23files с единственным изменением Diary. Google API/deploy не запускались.

## Native Android35

| Lane | Результат | Cases |
|---|---|---|
| MASTER25→27 | failure | install_baseline=BLOCKED; driver=BLOCKED |
| MASTER26→27 | failure | install_baseline=PASS; ui_import_1=PASS; ui_import_2=PASS; ui_import_3=PASS; ui_module_elman=PASS; ui_module_pause=BLOCKED; driver=BLOCKED |
| CLIENT25→27 | success | install_baseline=PASS; ui_import_1=PASS; ui_import_2=PASS; ui_import_3=PASS; ui_module_elman=PASS; ui_module_pause=PASS; ui_template=PASS; ui_history=PASS; ui_diary_auth_boundary=NOT_RUN; beforeBaseline_inventory=PASS; native_update_to27=PASS; ui_afterCandidate=PASS; cold_restart27=PASS |

Baseline материалы создаёт Android UI:3WAV files (два одинаковых display title),2модуля с положительной паузой, программа, текущая конфигурация, история. Затем native upgrade/cold restart, exact rows/media SHA/integrity и UI видимость. AudioTrack — подтверждение состояния native аудио, **не человеческой слышимости**. SQL только read-only; Google identities не подделываются. Legacy Google drafts недоступны без настоящего входа: NOT_RUN. Новый offline MASTER draft после upgrade отдельный case.

Локально /dev/kvm отсутствует; установки ненужного local emulator не выполнялись. Все реальные native установки — disposable GitHub CI, не телефон владельца.

## Неуспехи и повторы

Полная хронология с причинами в CODEX_EFFICIENCY_17.md. Старые fail receipts сохранены, новые PASS не стирают историю. Нельзя считать blocked driver с пустой baseline доказательством успешной миграции.

## LIVE / OWNER

Read-only health существующего GAS HTTP200/source совпал с исторической6. Число active deployment через admin API NOT_RUN. Нет LIVE deployment патча, новой тестовой публикации через Google аккаунт или доступа к устройствам владельца. Реальные2Google,15/30/60мин, network/provider revoke, offline hearing3tracks — NOT_RUN. Старое подтверждение владельца diary26→client25 — отдельное историческое наблюдение, не Task17 PASS.
