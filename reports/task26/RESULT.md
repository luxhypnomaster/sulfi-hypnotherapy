# №26/26-А — актуальное продолжение: PARTIAL / authenticated billing BLOCKED_AUTH

Официальное дополнение26-А прочитано полностью; работа продолжается в PR77 / feat/task26-onreza-staging без новых серверов, Android или платного тарифа. BILLING_RESEARCH.md и BILLING_CAPABILITIES_26A.csv содержат исследование23 показателей, официальные routes/schema/help и отрицательные результаты с раздельными DOCUMENTED/BLOCKED_AUTH/NOT_DOCUMENTED.

Реально установлен официальный CLI0.54.0, checksum PASS, help выполнен. Обнаружены GET /v1/workspace (plan/subscription/periodEnd) и fork-scoped GET /v1/product-forks/{productId}/{forkId}/usage. Общий workspace credit/usage/invoices read contract не найден в изученной публичной поверхности; это не доказательство отсутствия такого API вообще. workspace list — local config, не server readback.

NRZ_TOKEN всё ещё отсутствует: авторизованных billing запросов0, фактических сумм/остатков/задержки reconciliation/сверки с панелью нет. Public app/pricing HTTP200 — не вход владельца. Установка CLI сняла один прежний локальный blocker; основная авторизация остаётся.

Подготовлены переносимый BillingAdapter proposal/prototype, operator-only read-only probe, cache/rights/precision/freshness guards. **16 адресных проверок PASS**, отдельно3 повторные бюджетные проверки официального enum HOBBY PASS; старые36/32 не запускались заново. Mock fixtures обозначены CONTROLLED, неLIVE.

Финансовый gate приведён к26-А: отсутствие Usage API/estimate — warning;10₽ ориентир, guaranteedCap=false. При подтверждённых Hobby/no-paid terms, разрешённых минимальных ресурсах, ограниченной нагрузке и безопасном постсостоянии отсутствие read API не останавливает trial review. Реальный provisioning сейчас не выполняется из-за неподтверждённых доступа/тарифа/условий, а не из-за отсутствия Usage API.

Дополнительная приёмка: T26-19 PARTIAL,20PARTIAL,21BLOCKED,22PASS LOCAL. Общая матрица22: **4PASS LOCAL / 11PARTIAL / 7BLOCKED**. Неизменённые предыдущие статусы не означают новых live PASS. GAS6/main/production/OAuth/ACL/signing/Android/№25 не менялись. Продолжается прежняя Draft PR77, без merge/deploy.

Кодовая контрольная точка26-А и ссылки доставки добавляются в DELIVERY_26A.json. Прежние отчёты/ZIP/доказательства сохранены; ниже исторический снимок26 до дополнения. Прежнее условие обязательного10₽ numerical cap отменено26-А.

---

## Исторический результат до26-А (не текущие финансовые условия)

# №26 — PARTIAL LOCAL / LIVE BLOCKED_OWNER

25.11.2026. Архив11961B, SHA256 `cb8a26d5d14f437e5eeca51fe0630828d450f80a3643ab188c1f0a8d029c57f0`; ZIP CRC и6 manifest entries PASS, все7 файлов прочитаны. Профиль ONREZA§11, IAM§9, HEAD/SNAP и остальные связанные источники получены; provenance в INPUT_AUDIT.

Реализован работающий локальный STAGING-кандидат в `server/alchemist/onreza26`: PostgreSQL authority/сессии/установки/default CLIENT, SQL-outbox, общий ProjectionPublisher, fail-closed JWT+KV, verified immutable public HEAD, idempotent receipt, изолированные адаптеры, самостоятельный Function-entry, воспроизводимый минимальный build context. Старый serializer/проверка dependencies переиспользуются из №20–22. Синтетическая схема не является финальной миграцией полного P22.

**36 новых локальных тестов PASS** в финальном общем прогоне (0FAIL/0SKIP). Прежние адресные/промежуточные прогоны не прибавляются к36. **32 существующих Node регрессии №20–22 PASS**. Проверены настоящие SQL-транзакции/constraint/rollback/reopen на локальном PGlite PostgreSQL WASM; KV является instrumented fake. Это не managed ONREZA, не физический Android и не real Google OAuth.

Матрица18: **3 PASS LOCAL, 9 PARTIAL, 6 BLOCKED**. Полного выполнения live STAGING нет. HTTPS endpoint **не получен**, ресурсов не создавалось, deploy/redeploy/sleep/Usage не проверены. Имя проекта `protocol22-staging` — план, не вымышленный ID.

Причины:
1. NRZ_TOKEN отсутствует в защищённом runtime; CLI тоже отсутствует. Ключ не искался в Drive/чате/логах/Git.
2. Текущие workspace identity, Hobby, ставки, кредит, квоты и остаточный расход не подтверждены административным readback. Лимит10₽ — предложенный, отдельное подтверждение владельца не обнаружено. Финансовый gate STOP; никаких платных действий.
3. Публичный ONREZA KV contract не подтверждает CAS/version fence/упорядоченного writer. Реальный адаптер честно сообщает отсутствие этой capability; HEAD и publisher блокируются. Подменять CAS get+set нельзя. Без provider proof либо отдельно доказанного SQL-mediated delivery решения live HEAD остаётся BLOCKED.

API ONREZA из Codex доступен: один анонимный GET `/v1/projects` →401; документация →200. Это не identity/workspace проверка и не HTTPS health нашего приложения. Регион исходящего узла не установлен; телефон РФ/иностранные маршруты NOT_RUN.

GAS6, production, main, OAuth, signing, Android и ресурсы/ветки/отчёты №25 не изменены. Никаких APK/Gradle/QEMU/сборок Android. №26 нельзя объявлять готовым production или полным Протоколом22.

Следующий шаг владельца: защищённый runtime NRZ_TOKEN после ротации прежнего раскрытого ключа и подтверждение предела до10₽ включённого кредита/0₽ платных обязательств. Затем только read-only inventory, расчёт и новый review гейтов; инструкция в ISSUES и runbook.

Кодовый checkpoint `fa053239d2d8ac91bf9fbaa9158815e20bf67f46`, Draft PR https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/77 .
