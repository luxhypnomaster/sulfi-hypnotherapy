# №18: PARTIAL, APK пока STOP-SHIP

Разработка продолжается в feat/task18-native-background-transfer, draft PR49 (base PR48, НЕ main). Последняя кодовая точка7f6c637; исходная база приложений27 fbdaa7b, Git base506619a. G0/G1 выполнены81b7c71 и повторно не запускаются. Продукционный GAS6, OAuth, ACL, подпись и данные MASTER27/CLIENT27 не изменялись.

G2: реализован отдельный Android headless executor — UIDT34+, dataSync foreground24–33 и ограниченное JobScheduler recovery. Существующие upload intents сохранены, selective install/диарийные медиа и reader-sync передаются той же очередью. Защищены owner/epoch/роли, ручная пауза, неизменность отправляемой редакции, проверяемая докачка, whole SHA, final receipt и повтор запроса с прежним ключом. Это больше, чем onPause fix, но native runtime ещё требует доказательств.

Проверки: текущая адресная серия16 PASS с production JS-domain selective install; analyzer clean перед последними отрицательными тестами. Ранее промежуточный полный Flutter480PASS/2SKIP, CLIENT3PASS, Node47+24PASS, offline contractPASS. Это не финальная проверка будущей пары28: после неё были изменения, полный CI должен проверять точный final source. Google/два физических телефона/OEM NOT_RUN.

CI: compile43660087187 SUCCESS. Probe43662532407 и43663729317 реально построили/установили два изолированных testOnly пакета, но FAILED до передачи. Второй выявил окно Pixel Launcher ANR и тайм-аут первого кадра. Новый прогон43700853248/source4984a7b использует доказанную ранее GLES-конфигурацию720×1280 и отдельную диагностику PID/ANR; результат в момент этой контрольной точки ещё не принят. Нельзя считать установку probe или компиляцию проверкой работы передачи.

Исследование скорости: реально измерены1/15/50MiB в loopback TCP к production JS DOMAIN, отдельно upload/server verification/download; сохранены исходные JSON. Это не Google Drive throughput. Продакшн health был прочитан анонимно трижды, без изменений сервера. Фиксированного ускорения не заявлено.

APK28 не выданы, APK_PAIR_18 отсутствует намеренно. Native MASTER27→28 и CLIENT27→28 с UI-created материалами пока NOT_RUN. Далее Codex должен завершить OS background/pause/network/process tests, data-preservation gates, final CI/build и независимую SHA/signature/config проверку. Только затем — ограниченная приёмка владельца. Повторной авторизации или испытаний старой27 сейчас не требуется.

Приватные отчёты: https://drive.google.com/drive/folders/100klr45KcMk0CNx21nYhoPvwMJ8i8xv- . Folder owner-only проверен повторно. For_Codex public writer не используется для личных отчётов. №17 не перезаписан; production apply/rollback по №17 не выполнялись.
