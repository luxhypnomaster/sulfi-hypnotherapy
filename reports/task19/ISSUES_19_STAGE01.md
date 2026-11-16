# №19 G0–G1 — остаток

1. LIVE BLOCKED: нет предоставленного/подтверждённого Supabase staging config; repo variables read403. OWNER_SETUP готов, нужны только публичные параметры. Никаких секретов в чат.
2. CI BLOCKED: GitHub runner не запущен из-за account billing/spending annotation. Не повторять вслепую; платежи/лимиты/репозиторий не менялись.
3. APK/native runtime BLOCKED: local assembly потерял daemon/OOM observed; KVM отсутствует. 4native source файла компилируются и28JVM tests PASS, но это не Keystore/runtime/installer доказательство. Прототипные APK не распространять как готовый вход.
4. Owner trigger UNKNOWN: source401/sameID path reproduced, но не известна причина реального picker. Нужен sanitized trace caller/stage/status/code/expiry/epoch, без tokens/email/private text.
5. PKCE custom scheme может перехватываться другим приложением для отказа доставки. PKCE+nonce защищают exchange; production App Links и live callback compatibility — отдельный gate.
6. Remote refresh/local fsync не атомарны. Recovery после lost response зависит от Supabase reuse policy; при revoked честный terminal state. Live rotation/crash tests NOT_RUN.
7. Supabase UID != Google sub != будущий app_user_id. Bridge/RLS/licences/legacy links не созданы, никаких прав или публикаций по SupabaseJWT в GAS нет.
8. Existing MASTER sub внутри CLIENT получает serverMASTER по текущему GAS contract; edition не security authority. CLIENT sub не может повыситься через локальный flag, existing server unit controls сохранены. Любая новая политика требует G3/owner approval.
9. №18 сохраняет PARTIAL. REG02 owner reports в новом ТЗ признаются как owner statements, а не тестировались здесь повторно.
