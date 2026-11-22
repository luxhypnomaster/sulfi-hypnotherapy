# Приёмочная матрица №22 v1.7 — все58 критериев

Кодовая точка `a5a4c771ab3f9fc9030d46fd6bb41a6a11ea1dde`; ветка `feat/task22-server-ratings-admin`, base PR52 `40b7c59e67921f456c3c5a4e943bd40f7232f336` → PR51 `a7c29a7b478b6c3b001d70d3158b4a65d57b3c50`. PR51/52 OPEN DRAFT, не merged. main `b88637a105b2182c7b836311ebb3de7ad037b08f` не менялся. Draft PR22: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/54.

PASS означает только явно указанный LOCAL/synthetic STAGING, не production/phone acceptance. BLOCKED live не останавливал другие tracks. NATIVE DEFERRED_BY_OWNER не environment failure.

Counts: {'PASS': 47, 'BLOCKED': 2, 'PARTIAL': 7, 'DEFERRED_BY_OWNER': 2}

| ID | Статус/уровень | Доказательство/ограничение |
|---|---|---|
| T22-001 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-002 | BLOCKED · LIVE | node-full-final; SERVER_BASELINE_22: backup/readback/restore actual GAS+Drive not proven; local candidate restore PASS |
| T22-003 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-004 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-005 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-006 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-007 | PARTIAL · LOCAL | task22_priority_test; flutter-full-final: 15MiB file+dispatch/HTTP proven; native audio/lock deferred |
| T22-008 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-009 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-010 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-011 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-012 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-013 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-014 | PARTIAL · LOCAL/LIVE | TESTS_22; OWNER_QA_22: existing coordinator/unit preservation; real Google cold/hour revoke NOT_RUN |
| T22-015 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-016 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-017 | PARTIAL · LOCAL | course22_store; ISSUES_22 REV22: immutable refs/update plan only; automatic official rematerialization not implemented |
| T22-018 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-019 | BLOCKED · LIVE | SOURCE_PURITY_22; SERVER_BASELINE_22: candidate not bound to GAS; no unsafe production deploy |
| T22-020 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-021 | PARTIAL · LOCAL | task22_models_test; course22_screen: cursor/readiness/execution-binding tested; complete course network/media/playback E2E not run |
| T22-022 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-023 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-024 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-025 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-026 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-027 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-028 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-029 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-030 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-031 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-032 | PARTIAL · LOCAL | admin22_screen; RATINGS_22: three ratings/N/time/lastGood available; full revision/moderation/source dashboard incomplete |
| T22-033 | PARTIAL · LOCAL | task22_widgets_test; ISSUES_22 ADMIN22: 7real candidate counters/routes; settings/role definitions editor incomplete |
| T22-034 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-035 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-036 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: explicit navigation defines5 paired sections(1/2/4/6/7),2single; older wording four contradicts explicit list |
| T22-037 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-038 | PARTIAL · LOCAL/LIVE | task22-core; SERVER_BASELINE_22: complete candidate SQLite/media restore PASS; actual private Drive production backup not verified |
| T22-039 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-040 | DEFERRED_BY_OWNER · NATIVE | OWNER_QA_22: Android background/lock/OEM physical tests explicitly deferred v1.7 |
| T22-041 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: fixtures/preservation and future upgrade plan PASS; actual native upgrade deferred |
| T22-042 | DEFERRED_BY_OWNER · OWNER/LIVE | OWNER_QA_22; SERVER_BASELINE_22: no real Google users or two phones; candidate live binding also pending |
| T22-043 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: inspect-only release checklist PASS; actual native/APK DEFERRED_BY_OWNER |
| T22-044 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: levels separated; CI billing0steps never PASS |
| T22-045 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: protected scope diff, no STT/PRO/MERIT/Taro/medical efficacy claims |
| T22-046 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-047 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-048 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-049 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-050 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-051 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-052 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-053 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-054 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-055 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-056 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-057 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |
| T22-058 | PASS · LOCAL | logs/flutter-full-final.log; logs/node-full-final.log: candidate test evidence only; not live/native proof |

Полный исходный текст каждого критерия сохранён в ACCEPTANCE_22.csv. Между старым T22-036 «four» и explicit7section list приоритет точной навигации:5paired+2single. Нет TOTAL PROD PASS или придуманного процента готовности.
