# №16-Б — фактические проверки

Дата: 12.11.2026. Source `012f7f69b7ad99c0d44f2a442d9649aa1481117e`, ветка `fix/task16b-auth-transfer-publication`, [draft PR45](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/45).

| Проверка | Факт | Доказательство |
|---|---|---|
| Exact-source GitHub Actions checks | PASS,433 Flutter tests,0 failures | https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43162781960 ; logs/CI_EVIDENCE_16B.txt |
| Локальный полный прогон того же source | PASS,433 tests,0 failures;1 opt-in live test SKIPPED | logs/FLUTTER_SUMMARY_16B.json; logs/FLUTTER_FULL_16B.jsonl.gz |
| Client edition compile/contract | PASS,3 tests | logs/CLIENT_16B.log |
| Flutter analyze / format | PASS,0 issues;172 files unchanged by format | logs/ANALYZE_16B.log; logs/FORMAT_16B.log |
| Production Alchemist JS domain/security | PASS,46 Node tests | logs/NODE_16B.log |
| Старый дневник regression | PASS,24 Node tests, исходный дневник не изменён | logs/OLD_DIARY_NODE_16B.log |
| Schemas/contracts | PASS,13 schemas,4 fixtures,10 negatives | logs/SCHEMAS_16B.log |
| Candidate GAS source assembly | PASS offline,без cloud operations | logs/GAS_BUILD_16B.log |
| Google SDK restore +401/403/network/scope | PASS controlled unit tests,не реальный Google user | logs/REJECTED_TOKEN_16B.log; test/task16b_auth_transport_test.dart |
| Перезапуск очереди/пауза/отмена/owner fence | PASS real SQLite + worker test | test/task16b_queue_catalog_test.dart |
| Потерянный chunk receipt → authoritative resume | PASS;600000 bytes,первый accepted reply потерян,подтверждённые байты не повторены | тот же тест; TRANSFER_TRACE_16B.json |
| Catalog→diary→client exact3tracks | PASS actual Dart/production JS loopback;cover failure + retry + no repeated upload/install | logs/COVER_SERVER_16B.log; test/task16b_announcement_e2e_test.dart |
| Локальная обложка/категории/реальная отрисовка | PASS с декодированным PNG | screens/task16b-cover-local.png; category-selection.png |
| Узкие экраны/шрифты | PASS11 widget tests,320/360/412 и1.0/1.3/1.6 | logs/RESPONSIVE_16B.log |
| Очередь реальный Flutter widget | PASS synthetic tasks,не живой upload | logs/QUEUE_RENDER_16B.log; screens/task16b-queue-details.png |
| HTTP connection benchmark | PASS measured loopback20 requests:20→1 connections | PERFORMANCE_16B.json |
| Действующий GAS6 health/role evidence | PASS read-only health;PARTIAL full install | SERVER_STATUS_G0.json;read-only run43156961962 |

Подробности APK/подписей/скачивания — APK_INFO_16B.md, эмулятора — EMULATOR_16B.md. CI не заменяет Google consent/Testing, сеть физического телефона и звук. Полный большой live E2E прежнего №16 не повторялся ради отчёта. Новые live backend diagnostics не проверены: deployment запрещён до отдельного согласования.

Промежуточные прогоны находили реальный narrow toolbar overflow и дефекты новых тестовых фикстур; исправления подтверждены повторными targeted и окончательным полным exact-source CI. Старые failed/cancelled runs сохраняются; успешным объявлен только указанный итоговый run.

## Native подтверждения

- Smoke43165399224:6 PASS/2 BLOCKED,реальное update24→25 сохраняет audio/history/template/diary,CLIENT sandbox и capsule UI export/import PASS.
- Сравнение43194766281:library playback подтверждён на24 и25,session оставался BLOCKED из-за искусственного counter invariant.
- Counter reproduction:1 дополнительный локальный тест PASS.
- Corrected probe43196379265:7 PASS/1 BLOCKED;на24 и25 реальные AudioTrack library/session и screen-off=true. Один оставшийся navigation expectation не принят.
- Физические Google users,Wi-Fi/mobile и слышимость реальных3треков владельцем NOT_RUN.

Реальные raw/structured результаты: EMULATOR_16B.json,PLAYBACK_PROBE_16B.json,PLAYBACK_PROBE_CORRECTED_16B.json. APK25 не пересобирались после первоначальной подписанной пары;изменялись только test harness и отчёты,app source tree сохраняет012f7f.
