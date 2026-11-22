# №24 — база, ancestry и владение файлами

Аудит Git/API от2026-11-22, подробности GITHUB_BASELINE_24.json. Все PR открыты, draft, **не merged**.

| PR | Задание | Точный head |
|---|---|---|
|51|20|a7c29a7b478b6c3b001d70d3158b4a65d57b3c50|
|52|21|40b7c59e67921f456c3c5a4e943bd40f7232f336|
|54|22|ff32a0f86b8fe9c5ffe7e75406d8b3291471d9c2|
|55|23|85fa5321c043ef97b43cb30a88a0909e7edf66f2|

`git merge-base --is-ancestor` подтвердил51→52→54→55. Проверенный код23 `5fae671c9829c021151e3c9e6ed0467692a7867a` — ancestor85fa532; более поздние коммиты23 только отчётность. Remote main `b88637a105b2182c7b836311ebb3de7ad037b08f` не изменён. Общий root-worktree `research/task16-autonomous`/1dc652a и его прежние untracked материалы сохранены.

Собственная ветка `feat/task24-local-ux-navigation` начинается точно с85fa532, draft направлен на `feat/task23-data-integrity-native-qa`. Устаревшая подсказка BASE PR51 внутри ZIP не использована для отката: актуальное поручение владельца требует сохранения21–23. Никакой PR не принят за main и не слит автоматически.

PROTECTED_24.json фиксирует73 изменённых исходных пути21–23, SOURCE_GATE_24.json повторно проверяет SHA и git blob. Все byte-identical. В частности сохранены Task23 storage/capsule fixes и Task21/22 Home/DiaryHome/Banner/Editor/controller/catalog/ratings. Используется существующий DiaryPublicationSlide без правки его кода: readonly-viewer guard расположен в прежнем незатронутом DiaryReader. В DiaryScreen лишь необязательный routing-list IDs; нет правок редактора, save, auth или модели публикаций.

Миграций данных/форматов нет. Никаких изменений SQLite/медиа/ID/owner scope, Gradle/version/signing, production GAS/OAuth/ACL. Новый publicationIds — необязательный параметр виджета маршрута, не SQLite/API поле. Конфликтующих кодовых патчей к protected файлам не потребовалось. При будущем изменении parent веток повторить diff-review, а не автоматически перенести весь стек в main.
