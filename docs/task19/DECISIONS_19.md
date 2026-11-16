# ИСТОРИЯ РЕШЕНИЙ И ТЕХНИЧЕСКИЕ ПОПРАВКИ К РЕДАКЦИИ 0.3
- №18 уже разработал часть background/Google auth по отчётам, но физическое QA осталось частичным. №19 должен audit/reuse, не начинать заново и не объявлять PASS по мокам.
- Версия 0.1/0.2: свести все field observations: очереди, миниатюры 88dp, уведомления, overlay «Дневник», отдельный каталог и лента, future server/transport.
- Решение владельца: 768 KiB = 3×256 KiB; независимый эксперимент сократить global ScriptLock, не механически убрать lock.
- После исследования Auth: современный google_sign_in 7, проблема в неправильном restore/session usage, 401 rejection, ограничениях Credential Manager; не называть SDK устаревшим.
- Supabase выбран первым кандидатом для устойчивых сессий, Postgres и будущих лицензий; Firebase остаётся неиспользуемой альтернативой, не надо параллельно реализовывать.
- JWT Google sub != Supabase UID; миграция требует verified mapping, не email merge. Один refresh coordinator для главного UI и фонового двигателя, иначе конкурентная rotation.
- Важно различать `Google Auth`, `Supabase persistent session`, `app_user_id` и `entitlement`; доказать каждый отдельно.
- 768KiB JSON Base64 > 1MiB, current Router maximum 500k chars: test first; не меняйте protocol production в G0/G1.
- Текущая загрузка блоками не гарантирует независимый repair произвольного segment; Drive resumable sequential and SHA are kept.
- GAS server role MASTER under master Google sub even when user is inside CLIENT; native client-only guard insufficient to guarantee edition; no untrusted client edition flag as authority.
- Задание №19 — комплексная программа/реестр, а first Codex run — только этап 0–1. Separate owner acceptance gates.

Sources:
https://docs.google.com/document/d/1FABRBXaL8wV0fiMtMaS1Exjz12d0kUyE72v0n_s8arw/edit — project procedure;
https://docs.google.com/document/d/1c7I4Ry8RZAk-5yWF1rgy9sdexSJEaCA47OxNRmooPvI/edit — current status;
https://docs.google.com/document/d/1BKn_V9D8fJ0RJSmYtIziObwqtSG_dlaukgVrHcjdrbk/edit — №18 background;
https://github.com/luxhypnomaster/sulfi-hypnotherapy — source;
https://supabase.com/docs/guides/auth/social-login/auth-google — Google OAuth;
https://supabase.com/docs/reference/dart/auth-signinwithidtoken — ID token flow;
https://supabase.com/docs/guides/auth/sessions — token/refresh sessions;
https://supabase.com/docs/guides/database/postgres/row-level-security — RLS;
https://developers.openai.com/api/docs/models/gpt-6.1-sol — model recommendation.
