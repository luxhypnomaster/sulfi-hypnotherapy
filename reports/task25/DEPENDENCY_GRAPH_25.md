# №25 — проверенная зависимость исходников

Репозиторий luxhypnomaster/sulfi-hypnotherapy: API owner совпадает, фактическая видимость PUBLIC, default main. Видимость не менялась. Main b88637a105b2182c7b836311ebb3de7ad037b08f содержит серверные/операционные файлы, но не Flutter lib/android. Это не потеря локального стека.

PR51 → PR52 → PR54 → PR55 → PR56 → **draft PR57**: https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/57 . Проверка ancestry и имён баз — GITHUB_BASELINE_25.json; все предыдущие PR open/draft/unmerged, не были объединены автоматически.

| PR | HEAD на предполётной проверке | Назначение |
|---|---|---|
|51|a7c29a7b478b6c3b001d70d3158b4a65d57b3c50|№20, каталог/локальная витрина|
|52|40b7c59e67921f456c3c5a4e943bd40f7232f336|№21, runtime/defaultOFF|
|54|ff32a0f86b8fe9c5ffe7e75406d8b3291471d9c2|№22, server candidate/ratings/courses|
|55|85fa5321c043ef97b43cb30a88a0909e7edf66f2|№23, local data/capsule safety|
|56|d0a6d9a6daaeca215992e0b771a2332502ecee41|№24, UX/навигация|
|57 code|737ea741636e9abe7c20353d9d5b8301cf44a5bb|№25, интеграционные тесты/source gate|

Приложение №24 d04170271e9e9f3d9d10d28fdb4a49cf0494a1e0; данные №23 5fae671c9829c021151e3c9e6ed0467692a7867a; №22 a5a4c771ab3f9fc9030d46fd6bb41a6a11ea1dde. Все являются предками №25. Source-tree IDs lib/android/third_party/server/.github записаны независимо в SOURCE_TREES_25.json: у PR56 и №25 они побайтово одинаковы. Проверены docs-only хвосты: runtime №24→PR56→№25 не менялся. Это интеграция уже зависимой цепочки, не новый merge и не cherry-pick.

Новая ветка feat/task25-integration-native-gates создана строго от d0a6d9a. Изменения ограничены test/task25_integration_test.dart, scripts/task25, docs/task25, reports/task25 и индексами README/BACKLOG. Все335 protected runtime-файлов и31 native/config pin сохранены; новых runtime путей нет. Нет схемы10, второго каталога/очереди/сервера/хранилища, новых зависимостей или API.

Старые source guards №23/24 описывают их собственный scope; не ослаблялись ради путей №25. Новый source_gate.py проверяет актуальный отдельный этап. При движении родительского HEAD перед будущим merge снова сравнить SHA/ancestry/diff; не автоперебазировать draft stack.

Исторические P0 материалы сохраняются: PR46 https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/46 (owner24→25 UNKNOWN), PR47 https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/47 (no-delete/bootstrap safety), PR49 https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/49 (подписанная историческая пара28 и native evidence). Эти отчёты не являются проверкой новых APK.
