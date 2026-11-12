# №16-Б — контрольная точка, не финальная приёмка

12.11.2026. Ветка fix/task16b-auth-transfer-publication; source 012f7f69b7ad99c0d44f2a442d9649aa1481117e; draft PR https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/45 .

G0 аудит сохранён. Реализованы кандидатные исправления G1–G4: официальный restore/refresh Google, owner-bound idempotent transport, app-lifetime runner существующей очереди, каталог отдельно от дневникового анонса, точные ссылки, локальная обложка/категории/автосохранение. Проверены контролируемый 3-track путь, ошибка обложки, возобновление после потерянного ответа, 401/403/network разделение и реальные Flutter render снимки.

Локальный предыдущий полный прогон 432 PASS. Последний коммит дополнительно проверен targeted tests и flutter analyze; окончательный exact-source полный CI https://github.com/luxhypnomaster/sulfi-hypnotherapy/actions/runs/43162781960 ещё выполняется. Client edition targeted 3 PASS. Node server46 + старый дневник24 + JSON contracts13 schemas/4 fixtures/10 negatives PASS.

Осталось дождаться exact-source CI, выполнить ручной private pair build workflow для этого же source, получить и проверить обе подписанные APK25, затем native emulator update24→25 (фикстуры включают audio/history/template/diary) и итоговые отчёты/матрицу. APK25 в этой контрольной точке ещё не объявлены собранными.

GAS6/source1a0cf8e5a60144075eec793767953586bfa319a2 не изменён. Main0800f34 и исходные APK24 сохранены. Права Google Drive и signing не менялись. Новый JWT/trace backend code остаётся только кандидатом до отдельного разрешения владельца на точную ревизию. Реальная приёмка APK25 на двух телефонах NOT_RUN; первоначальные APK24 входы подтверждены владельцем, но полный путь Элмана не пройден.
