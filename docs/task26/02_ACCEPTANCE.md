# Матрица приёмки №26 (18 критериев)
По каждому: PASS/PARTIAL/BLOCKED/NOT_RUN, уровень LOCAL/LIVE/OWNER, точное свидетельство, ожидаемое/фактическое, timestamp, число повторов. Не выдавать fake/local за live.

| ID | Критерий и обязательное свидетельство |
|---|---|
| T26-01 | Read-only identity, workspace, Hobby, кредит, лимиты/цены; защищённая авторизация, без вывода токена. |
| T26-02 | Git SHA/PR/base/build context; diff не трогает main/GAS6/Android/CI релизов. |
| T26-03 | Один целевой проект и Compute, SQL, Functions/KV; inventory до/после; при повторе прежние IDs. |
| T26-04 | Локальная сборка/тесты, реальный HTTPS /healthz 200, 404/405, безопасный ответ. |
| T26-05 | Повторный deploy в тот же Compute/Function, revision, способ rollback, отсутствие дубликатов. |
| T26-06 | Логи запуска/ошибок доступны, секреты и персональные данные отсутствуют. |
| T26-07 | Sleep/wake Compute и PostgreSQL подтверждены состоянием/метрикой, cold/warm latency; иначе OPEN/BLOCKED. |
| T26-08 | Usage до/после, ставки, timestamp, reconciliation/PENDING; платные обязательства 0, соблюдение лимита. |
| T26-09 | Сетевой маршрут Codex проверен; телефон РФ и зарубежные маршруты отдельно owner pending, если нет доказательств. |
| T26-10 | Воспроизводимые manifest/runbook, паспорт ресурсов, продолжение в том же контуре. |
| T26-11 | Diff/security audit, отсутствие секретов, production/GAS6 неизменны. |
| T26-12 | Валидная, истёкшая, поддельная сессия; отказ KV fail-closed; попытка прямого Compute/forged headers не обходит ACL. |
| T26-13 | KV miss существующего аккаунта восстанавливает его; подтверждённый новый создаётся идемпотентно; неподтверждённый client ID отклонён. |
| T26-14 | Отзыв привилегии при stale KV/JWT, актуальная проверка чувствительных действий; отказ без SQL, если актуальность не доказана. |
| T26-15 | SQL commit gap, retry, дубли/неупорядоченность, очистка только synthetic namespace и rebuild, отсутствие регрессии. |
| T26-16 | HEAD только verified snapshot, неизменный wire contract/revision при идентичной сборке, без private scope leak. |
| T26-17 | Повторные Function-only auth/HEAD с наблюдаемым сном Compute/SQL; latency, BFU и Usage; иначе OPEN/BLOCKED. |
| T26-18 | CORE tests на fake adapter, TTL/miss, задержка/нет CAS, отказы и изоляция; провайдерные зависимости только в адаптерах. |

Частичный gate OPEN-ONR-A/B/C/H/I, TST-ONR-001/007/009–011. Не полная приёмка P22, реального IAM/Google, каталога, Drive, трафика 1,5 ГБ, schedule, backup/restore production. Не выпускать APK.
