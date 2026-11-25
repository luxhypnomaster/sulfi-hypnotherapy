# Следующий безопасный шаг в том же №26

1. Разблокировать protected NRZ_TOKEN, точный workspace и финансовые ограничения; read-only inventory до любых расходов. Не создавать второй проект при возобновлении.
2. Закрыть гарантию доставки SQL→KV без регрессии и provider CLI preflight. Настоящий Onreza adapter пока не выдаёт вымышленную CAS capability. Затем live синтетические тесты и честные sleep/Usage evidence.
3. Расширять тот же staging: адаптировать async PostgreSQL repository к существующему IAM22/Auth19 coordinator, включая OWNER→lead ADMIN→подчинённые роли и audit. Сейчас schema содержит role/grant поля, но полная governance/Auth19 integration и real Google НЕ выполнены и в live не включаются.
4. Связать текущие Catalog22/Ratings22 verified stores с PG и независимыми ratingsRevision/hash без wire changes. Не пропускать неподтверждённый ratings HEAD. Синтетические ограничения current bootstrap не переносить в production домен как окончательную схему.
5. После отдельных приёмочных гейтов — Drive gateway/receipts, полные snapshot dependencies, durable operations22, метрики и scheduler/backup. Не создавать вторую Android очередь. Эти будущие компоненты сейчас НЕ выдаются за реализованные.

GAS6 остаётся baseline, Android и source/ресурсы №25 сохраняются. Никаких автоматических переключений endpoint, миграций пользователей, включения Auth19, production deploy или APK в №26.
