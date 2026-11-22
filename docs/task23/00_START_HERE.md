# ПРИОРИТЕТНОЕ УТОЧНЕНИЕ ВЛАДЕЛЬЦА (22.11.2026)
НЕ собирать/не выпускать APK по №23. Два/три следующих задания разработки сначала должны быть завершены. Основной фокус №23 — защитить local SQLite/media и регрессионно проверить миграции на копиях/fixtures, подготовить scripts/checklist для поздней совместимой сборки. Любое native build/Gradle/sign/emulator/device указание ниже трактовать как future-only, не исполнять сейчас.

# TASK 23 / START HERE

PROJECT: Sulfi / Alchemic. Repo luxhypnomaster/sulfi-hypnotherapy.
DATE: 2026-11-21. Codex tasks #21 (server integration) and #22 (wide backend/catalog/ratings) may be active.
BASE: PR #51 (task20) draft on top of PR #50, which preserves PR #49/48 lineage; inspect ancestry and newer branches, do not assume merge.
PR #51: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/51
ISSUES: https://drive.google.com/drive/folders/13hLTnJEjQCx_SrNw4lEojOPA-ZPQX4q2
LIVE: Existing GAS6 and APK28 user data. No destructive actions, no re-sign or main merge without separate review.
RULE: A Codex task must not block independently executable work while waiting for live credentials, physical phones or Github billing. No fake PASS.

TASK 23 is an independent parallel track. It must not silently edit or overwrite code from tasks 21 or 22.

Read 01_TASK.md, 02_COORDINATION.md, 03_ACCEPTANCE.csv, 04_SOURCES.md, 05_CODEX_COMMAND.txt. Commit source/test changes only on your own feature branch, provide draft PR and evidence.
Reports: `reports/task23/` and Google Drive For_Codex/Отчёты — Задание 23; never deposit app secrets/private user data in Drive reports.
