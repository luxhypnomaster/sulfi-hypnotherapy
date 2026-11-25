# Матрица18 критериев №26

Составлена 2026-11-25T13:16:51.057788+00:00. Formal evidence runs=1 означает один выбранный приёмочный результат; вся история повторов отдельно TEST_RUNS.json. LOCAL не приравнивается к LIVE/OWNER.

| ID | Статус | Уровень | Фактический результат |
|---|---|---|---|
| T26-01 | BLOCKED | LIVE | NRZ_TOKEN absent; CLI absent; no authenticated readback |
| T26-02 | PASS | LOCAL | Base PR54 ff32a0f; draft dependencies audited; only new26 paths |
| T26-03 | BLOCKED | LIVE | No resource was created; pure reconcile tests reuse/ambiguity/SQL quota PASS |
| T26-04 | PARTIAL | LOCAL | 36 unique new local tests; curated build/HTTP200/404/405 PASS; live HTTPS NOT_RUN |
| T26-05 | BLOCKED | LIVE | Documented official rollback + observed serving readback plan; no live deploy |
| T26-06 | PARTIAL | LOCAL | Local HTTP errors sanitized; no secret logs; provider deployment logs NOT_RUN |
| T26-07 | BLOCKED | LIVE | No resources/state readback, cannot measure sleep or latency |
| T26-08 | BLOCKED | LIVE | Budget guard unit tests PASS; plan/rates/credit/residual/owner cap unverified |
| T26-09 | PARTIAL | LIVE | Official docs200; anonymous API401; staging endpoint absent; region/OWNER routes NOT_RUN |
| T26-10 | PARTIAL | LOCAL | Reproducible whitelist bundle and runbook; IDs unavailable, CLI validation NOT_RUN |
| T26-11 | PASS | LOCAL | Only new26 paths, no secret values, no production/GAS/Android/main mutations |
| T26-12 | PARTIAL | LOCAL | Local crypto/HTTP/adapter tests PASS; real provider Function/ACL NOT_RUN |
| T26-13 | PARTIAL | LOCAL | PGlite actual SQL uniqueness/install binding/idempotency PASS; live NOT_RUN |
| T26-14 | PARTIAL | LOCAL | Current SQL roleVersion/revocation/CLIENT deny PASS; full IAM hierarchy integration OPEN |
| T26-15 | PARTIAL | LOCAL | Actual local SQL durability+fake fencedKV PASS; real noCAS =>ORDERING_NOT_PROVEN |
| T26-16 | PARTIAL | LOCAL | Reused dependency verifier+SQL immutable/receipt PASS; real KV/ratings adapter not bound |
| T26-17 | BLOCKED | LIVE | Local no-SQL counters PASS only; real no-wake/BFU/usage NOT_RUN |
| T26-18 | PASS | LOCAL | Core source boundary, adapters and delayed/out-of-order writes contracts PASS |
