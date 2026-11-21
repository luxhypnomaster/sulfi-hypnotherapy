# ISSUES №21

| ID | Статус | Факт / следующий безопасный шаг |
|---|---|---|
| E21-NATIVE | BLOCKED_ENV | Root117MiB, cgroup8GiB, Gradle cache dangling, noKVM, прежний signing env отсутствует, известный OOM19. Две Flutter bundles PASS, нативный compile/cert/upgrade НЕ выполнялись. Нужен пригодный runner и прежняя signing configuration; без нового debug key/старого APK удаления. |
| E21-CI | BLOCKED_ENV | PR52 CI44959026009 verifyFAILURE0steps, billing/spending annotation. Повторного dispatch нет; source8546 имеет только local proof, [skip ci]. Владелец может независимо решить вопрос billing, без платного обхода. |
| E21-PRODUCTION | BLOCKED_OWNER | Existing GAS6 не умеет candidate metadata ops. Нужен отдельный проверенный provider binding/atomicity+ACL/readback/rollback diff и отдельное разрешение. Не отключать legacy API/не включать flag в действующей паре. |
| E21-OWNER | NOT_RUN | Реальные Google users, два физических телефона, слышимость/offline/OEM/TalkBack и native update. Не подменяются синтетическими тестами. |
| E21-PR46 | PARTIAL | Native storage sources сохранены, Linux data/media retention PASS; историческая физическая причина visibility не установлена этим заданием, новый upgrade gate не пройден. |
| E21-REPORTS | KNOWN RISK | For_Codex/21 anyone:writer. ACL не менялась; только sanitized отчёты с hash readback, без APK/source/secrets/DB. |

Исправлено: runtime factory gap, отсутствующий cached catalog UI path, зависимость config counter от catalog revision, отключённый transport настроек при наличии проверенного backend, permanent transient capability error, неверные metadata-stage подписи, missing static chosen Home preview. Дополнительно подтверждён и устранён cold pending receipt duplication после applied read. Артефакты ошибки и финальные tests сохранены.

Не входили в №21: live backend cutover/provider выбор, весь ADM7, новая role governance, Supabase production/Auth19 enable, payments/квоты/backup/новая файловая инфраструктура. Эти функции не объявляются готовыми. №20 и старые отчёты/данные не удалялись.
