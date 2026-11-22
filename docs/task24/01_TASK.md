# №24 — Быстрые согласованные UX/навигационные исправления (без новой продуктовой разработки)

## Цель
Автономно закрыть проверяемые «давние хвосты» на существующих MASTER/CLIENT экранах. Не вводить новую функцию или макет, если решение уже реализовано и проходит тесты. Уважать дизайн исходных экранов и 9:16.

## Workstreams
A. F-038 navigation: repeated tap of queue/transfer overlay while its page open must not stack same route; Android hardware back/gesture/UI back returns to semantic logical parent, not through every previous read diary entry. Prev/Next within diary posts should replace sibling content in same logical context, while page navigation within a post remains independent. Preserve deep-link and pending state; no extra Google sign-in. Isolate changes to routing layer/tests. Existing PR49 and PR51 may already contain partial work: audit first and fix only failure cases, avoid conflict with task21 diary preview.
B. K-025: two identically named library module occurrences A/B; editing only A must mark only A '(Изменено)' and not B. After reverting A to matching original no 'changed' marker. Compare stable IDs/occurrence/exact content, not display titles or global template flag. Preserve approved yellow marker + fuchsia italic for actual changed occurrence; tests include duplicate names and user personal forks.
C. K-029: one understandable 'На главную' action from completed session history; route to genuine Home without unexpected stack. Verify existing implementation first. K-026/K-027: audit prior task13 accepted timer bright yellow and Phase→Module→Track indentation; only fix verifiable regressions. No new aesthetic reinterpretation.
D. K-030 AUTHOR/CLIENT shield: audit whether existing master view already has correct UI separation without confusing server roles; only regression fix if failing. No new auth/permissions.
E. K-037 offline local draft access: verify local drafts remain navigable when no Google session; do not edit diary editor implementation owned by task21 unless isolated test proves regression and safe ownership can be coordinated. If conflict, add failing test + patch proposal, not conflicting commit.

## Boundaries
No editing GAS/production server, global auth state, DB schema/storage, native Gradle/signing, import/export (owned Task23), catalog/ratings/courses/admin panel (owned Task21/22), and no image generation. No data deletion. Avoid touching `lib/ui/diary_home*` and other task21 paths if active. Real device QA is owner-gated, report NOT_RUN.

## Outputs
Isolated `feat/task24-local-ux-navigation` draft PR; tests for each fixed issue and preserved legacy behavior; before/after pixel/layout evidence if widgets modified, readable changelog with source and status (ALREADY_DONE/REGRESSION_FIXED/PARTIAL/BLOCKED). GitHub CI billing constraint does not block local Flutter tests.
