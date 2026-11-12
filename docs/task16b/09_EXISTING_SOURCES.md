# Первичные источники; обязательно сопоставить с фактическим Git
- Папка проекта: https://drive.google.com/drive/folders/1b-FP_emjwE5LpTyx4TFzkbzlffEE7pLl
- For_Codex: https://drive.google.com/drive/folders/1iG5L28UybhIxLayHebggTAyH5cP5IPLJ
- Единственный исходный номерной архив №16: https://drive.google.com/file/d/1QgvwNZcFZjoAVId6no0zEvLzGTyWdZpP/view
- №16-А (Google Auth, роли и E2E): https://docs.google.com/document/d/16hMVySJwkS1kABBDyWXTJ3kfogzNJWayCu4LcFh_224/edit
- Оперативное состояние (на 12.11 включает результаты физического QA): https://docs.google.com/document/d/1c7I4Ry8RZAk-5yWF1rgy9sdexSJEaCA47OxNRmooPvI/edit
- Результаты №16: https://drive.google.com/drive/folders/1jVvv6kEm5uUWol92QvJDwqbDkl5oz-5z
- Результат пары APK24: https://drive.google.com/file/d/1v7XgkHyiWk5XBm2jDQ3XaZvrzhk7w8k0/view
- Автономное продолжение/исследование perf/G3/native: https://drive.google.com/file/d/14vEEKwgNwBxIjVYojSSPQIV673A8l7vg/view
- Стратегия / K/F: https://docs.google.com/document/d/1XZMip9SE5lJ-n73y1zthRI9TQMZ6Tws97uDIH77VgQA/edit ; https://docs.google.com/document/d/14Lcqe6Rn4Q3hxEuHIuYx7nHfUCnCtgm7mNYoXWgj5M4/edit ; https://docs.google.com/document/d/1UEFVm4MkxxCfC8VAYkSMjrtXkAh_wQloPZEAHnjiKgE/edit
- Репозиторий: https://github.com/luxhypnomaster/sulfi-hypnotherapy
- Candidate APK24 (private draft/release, не публичная ссылка): https://github.com/luxhypnomaster/sulfi-hypnotherapy/releases/tag/untagged-9962b11f7ce0aa819785

Состояние reports от 11.11 и телефонная приёмка 12.11 не взаимозаменяемы: прежние отчёты писались до реальных MASTER/CLIENT sign-in, поэтому их NOT_RUN устарели лишь в части первоначального входа/роли, а критический контентный E2E остаётся BLOCKED.

Логические/физические уровни: `20_Библиотека`, `30_Медиа`, `40_Пакеты`, `50_Каталог`, `90_Техническое` — внутри приватного хранилища одного Script. Не создавать новую папку/сервер. Не полагаться только на перечисление на диске: каталог клиентов — управляемые indices + ACL/версии, не raw Drive browsing.
