# Приёмка №26 + официальное дополнение №26-А

Обновлено 2026-11-25T13:46:24.496315+00:00. Прежние18 свидетельств сохранены в Git/evidence bundle26. Финансовое условие T26-08 заменено согласно26-А; отсутствие Usage API не блокирует остальные испытания.

| ID | Статус | Уровень | Фактический результат |
|---|---|---|---|
| T26-01 | BLOCKED | LIVE | NRZ_TOKEN absent; official CLI0.54.0 checksum/help available; no authenticated workspace/plan readback |
| T26-02 | PASS | LOCAL | Base PR54 ff32a0f; draft dependencies audited; only new26 paths |
| T26-03 | BLOCKED | LIVE | No resource was created; pure reconcile tests reuse/ambiguity/SQL quota PASS |
| T26-04 | PARTIAL | LOCAL | 36 unique new local tests; curated build/HTTP200/404/405 PASS; live HTTPS NOT_RUN |
| T26-05 | BLOCKED | LIVE | Documented official rollback + observed serving readback plan; no live deploy |
| T26-06 | PARTIAL | LOCAL | Local HTTP errors sanitized; no secret logs; provider deployment logs NOT_RUN |
| T26-07 | BLOCKED | LIVE | No resources/state readback, cannot measure sleep or latency |
| T26-08 | BLOCKED | LIVE | Updated gate tests PASS; Usage API absence is not a blocker; current authenticated tariff/payment terms unverified |
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
| T26-19 | PARTIAL | LOCAL | Official CLI/OpenAPI inspected; 23 metrics mapped; live workspace data BLOCKED_AUTH |
| T26-20 | PARTIAL | LOCAL | Operator probe, typed schema excerpts, CLI help verified; authenticated response/schema correspondence NOT_RUN |
| T26-21 | BLOCKED | LIVE | No protected token; no baseline or load generated; latency and panel check NOT_RUN |
| T26-22 | PASS | LOCAL | Contract/capability map/prototype/cache/access/precision and financial gate;16targeted tests PASS; no production integration |
