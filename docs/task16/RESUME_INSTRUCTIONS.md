# Продолжение №16 после квот/таймаута

Эта редакция №16 заменяет staging-only V1. НЕ возвращаться к старому прототипу. Новый проект строго «Сервер Проекта Алхимик». При повторном запуске:

1. Прочитать последнюю редакцию `CONTENT_CATALOG_AND_STORAGE.md` и `PREFLIGHT_AUDIT.md`, затем `For_Codex/Отчёты — Задание 16/PROGRESS.md`, Git branch `feat/task16-alchemist-full-server`, last commit SHA, CI; убедиться, какие C0–C5 подтверждены.
2. Продолжать НЕПРОВЕРЕННЫЙ пункт, начиная с рабочего source; не откатывать выполненный сервер, не создавать второй GAS проект с тем же именем. Дедупликация по сохраненному scriptId.
3. При отсутствии OAuth у Codex использовать GitHub Actions + `clasp` по `GITHUB_ACTIONS_DEPLOYMENT.md`; workflow готовить даже без GitHub Secret. Не делать серию бесполезных API 401, закончить backend Flutter, tests, deploy scripts. При `GITHUB_SECRET_MISSING` оставить cloud deploy BLOCKED и сообщить владельцу одну безопасную телефонную операцию, не требовать ПК и не обходить OAuth.
4. Не выдавать Node fixtures за live cloud, а локальные APK — за проверенные на телефоне.

## CATALOG / DRIVE TREE CONTINUATION

On resume reread `CONTENT_CATALOG_AND_STORAGE.md`, verify the catalog UI/publish/index/download stages and folder bootstrap integration have not been skipped. Separate fake/mocked checks from live; resume from precise failed stage. Never re-create tree blindly.
