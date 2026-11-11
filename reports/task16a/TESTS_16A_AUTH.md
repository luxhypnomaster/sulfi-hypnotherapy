# Проверки №16-А

11.11.2026. Факты ниже не подменяют физическую Android-приёмку. Историческая матрица №16 (97 PASS / 46 PARTIAL / 3 BLOCKED / 1 NOT_RUN) сохранена как история, не переписана в «всё готово».

| Проверка | Результат | Доказательство / ограничение |
|---|---|---|
| Flutter полный прогон | PASS, 422 | Локальный FLUTTER_TEST_SUMMARY_16A.json; CI43036325914/source74dd63c SUCCESS, 422 PASS, отдельный opt-in live test пропущен |
| Analyzer/formatter | PASS | flutter analyze --fatal-infos; dart format lib test; тот же CI |
| Новые серверные тесты | PASS, 42 | node --test server/alchemist/test/*.test.mjs, включая подпись, aud/exp/iat/nbf/sub, роли, ACL pages, published-only diary и private-draft build gates |
| Старый diary backend | PASS, 24 | CI43036325914, старый код не менялся |
| Контракты / fixedCLIENT | PASS в CI | 13 schemas, contract fixtures/negative cases и отдельный client-edition тест в CI43036325914 |
| Реальный clasp owner / Script | PASS | Trusted-main read-only runs43036313882/43037262461, без вывода credentials/sub |
| Полный ACL Script | PASS | readScriptAcl: Permissions.list до конца, 1 страница, 1 owner. shared summary не используется как разрешение |
| Существующий сервер, version6 | PASS | Deploy43040280601, source1a0cf8e, тот же URL; source/version readback, private41/replay. Прежний промежуточный43039898736 — metadata mismatch, повтор успешно подтверждён |
| Runtime health / exact Web audience | PASS | Read-only43040748550 + независимый RUNTIME_HEALTH_16A.json, policy2/WebID совпадает |
| Anonymous mutation / forged JWT | PASS, live | Отказы в существующем API в deploy43040280601 |
| Действительный Google CI token в normal API | PASS, live rejection | aud CI отличается от Web; API401. Этот токен не используется как Android-user proof |
| Истёкший/будущий/неподписанный JWT | PASS, unit; forged live | Не заявляется реальный истёкший Google Web token, которого нет в окружении |
| Повышение роли через email/JSON/старые grant | PASS, unit | Клиент остаётся CLIENT; grant author запрещён; owner immutable |
| Клиент в master edition / owner в client edition | PASS, unit | task16a_auth_test.dart; реальные APK/SDK NOT_RUN |
| Смена аккаунта/выход | PASS, unit/widget | Pending HTTP сбрасывается без retry/показа чужого тела; роли/редакторы/приватный кэш скрываются, данные не удаляются |
| Local export vs publish | PASS, local | Клиентская копия модуля/капсула экспортируется без сетевого вызова; прежние private author draft строки остаются в БД, но не выдаются клиенту |
| Старые индексы версии4 | PASS, local | Внедрён старый формат grant: ссылка не даёт доступ к материалу, настоящее voice-вложение читается, текст/файлы/ревизии сохранены. Новый индекс grantPolicyVersion2 использует прежний быстрый путь |
| Published ContentLink | PASS, local cross-language | Реальная Flutter→production JS domain→отдельная SQLite установка; снятая standalone карточка недоступна через diary/collection; повторная явная публикация открывает ссылку |
| Raw diary audio | PASS, unit | Сообщение доступно в дневнике; catalog exact reference не создаётся автоматически |
| Официальное происхождение | PASS, local | Отдельная метка сохраняется при reload; canonical SHA не меняется; официальный module нельзя изменить клиентом, личная копия отдельная |
| Реальный Web MASTER Google-вход и публикация | PENDING_REAL_ACCOUNTS | В private proof status MASTER=null; Google CI owner не засчитан |
| Реальный другой Google CLIENT, read/install/deny publish | PENDING_REAL_ACCOUNTS | CLIENT=null, distinctAccounts=false. Unit actors не засчитаны |
| Одна мастерская auth-candidate APK23 | PASS, configured candidate | workflow43037688974 SUCCESS. Подпись/package/version23/compiled endpoint+WebID подтверждены CI; независимый официальный apksigner PASS; GitHub draft и независимое скачивание/SHA PASS. Native login NOT_RUN |
| Финальные две connected APK | BLOCKED_STAGE_C | Не формируются до реальных двух аккаунтов и клиентской установки; build gate не допускает пустой endpoint |
| Два телефона, реальные3трека Элмана → diary → offline | NOT_RUN | Нужны действия владельца по PHONE_QA_16A.md |
| Реальные пользовательские тайминги | NOT_RUN | Не переносить длительность прежнего CI на пользовательскую установку |
| GitHub artifacts upload | BLOCKED_QUOTA | Workflow warning сохранён, старые файлы не удалены; готовится private GitHub draft route |

Разделять: серверная role boundary proof ≠ подтверждённая клиентская установка ≠ приёмка двух телефонов. Даже два успешных auth.verifyPilot оставляют serverTwoAccountCheck PARTIAL_CLIENT_READ_INSTALL_NOT_VERIFIED до отдельного фактического read/install. Никаких фиктивных live PASS.
