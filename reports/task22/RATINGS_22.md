# F031–034 / три рейтинга №22

Кодовая точка `a5a4c771ab3f9fc9030d46fd6bb41a6a11ea1dde`; ветка `feat/task22-server-ratings-admin`, base PR52 `40b7c59e67921f456c3c5a4e943bd40f7232f336` → PR51 `a7c29a7b478b6c3b001d70d3158b4a65d57b3c50`. PR51/52 OPEN DRAFT, не merged. main `b88637a105b2182c7b836311ebb3de7ad037b08f` не менялся. Draft PR22: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/54.

Приоритет12_THREE_RATINGS_VERSIONED_POLICY и S-X-RATING-001v0.6§9. Raw source: exact contentRevision/execution/manifest/occurrence, consent schema/sequence/source. Public key `type:logicalContentId:ratingEpochId`, а не technical revision. Edits/track replacement не сбрасывают parent epoch. Независимый trackId не наследует чужие оценки. Исторические references разрешаются только при текущем допустимом public материале; wrong target type/revision rejected.

Три headline-поля: `consumerDirect` (только прямые CLIENT,N/mean/distribution), `professionalDirect` (server-verified PRO, отдельно), `weighted` (`null/NOT_CALIBRATED`). AUTHOR_SELF_TEST/неподтверждённый PRO-app hint исключены из внешних cohorts. N0=null; N1 настоящий5,0 и «предварительно». Ни веса, ни клиническая эффективность/гипнотизируемость не утверждены.

Context — не direct vote: только actual completed/partial occurrences; UNKNOWN/NOT_EXPOSED не добавляют сигнал. Root dedup оставляет реальные occurrences, но не умножает независимый N. Course30direct не становится30program votes; program3direct сохраняет3. Optional component ratings — отдельный явный выбор. Local frozen provenance/union position intervals не доказывают внимание и не угадывают пропуски при seek.

Локальная форма по умолчанию без network consent; пропуск не мешает completed history/cursor. При opt-in immutable payload идёт через существующую queue18; исправление/отзыв согласия применяются idempotent sequence/receipt, media/личные заметки не передаются. Revocation не требует продолжающегося доступа к withdrawn материалу. Raw immutable events сохраняются отдельно от consented current aggregate; потребность будущего полного удаления/retention должна быть решена явно.

Чистый `rating_calculator22.cjs`: interface `(target,evidence,immutable policy)->result`; registry with algorithmId/version/parameterSchemaVersion. Две synthetic experimental strategies (mean/median) только для preview, typed per-target source/edge/hop/partial/cap/minimumN/repeatedRootCap. Значения в fixtures — только synthetic тест, не product defaults. Публичный weighted всегда null. Arbitrary formula/eval не принимается.

Immutable policyId/configVersion конфликт при изменении параметров; SHA immutable document стабилен на обычных recompute. OWNER draft→preview/diff→validate→explicit activate/rollback; leadADMIN draft/read/preview, ordinaryADMIN read/preview, publish только OWNER. Lead publish grant остаётся OPEN. Active pointer/hash+receipt atomic; failure оставляет lastGood. Policy rollback считает current consented evidence под прошлой policy, не старые stale feedback bytes. Прямые N/mean и raw/audio/history не мутируют от смены формулы.

Dirty updates bounded32 (явный limit≤1000); ratings overlay имеет собственные revision/hash/scope; нет media reinstall или полного content snapshot на rating-only update. Более1000targets при policy activation требует будущего staged batched compute; сейчас безопасный отказ с lastGood, не скрытый частичный publish. Public snapshot не содержит raw UID/текстов.

MASTER показывает N/source/даты/статус/политику и typed editor; полный execution-revision breakdown/moderation и окончательная анкета/UX ещё не закрыты. Коэффициенты, стратегия production, retention, publish-grant и D-01…D-09 — OPEN и не блокировали независимый код.
