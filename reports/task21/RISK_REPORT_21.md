# RISK REPORT №21

| Риск | Подтверждение / мера | Остаточный статус |
|---|---|---|
| GAS6 не реализует candidate metadata operations | default OFF + verified handshake + legacy API; production source untouched | BLOCKED_OWNER для live enable/deploy |
| Выбор provider и равные гарантии хранения/ACL | реальная SQLite atomicity доказана только в sandbox; небезопасный adapter rejected | Не выбран production provider; новая интеграция требует отдельного решения |
| Потерянный commit response после applied read | RED воспроизведён; stable unconfirmed request/CAS + monotonic applied,2controlled tests | LOCAL исправлено; live не испытано |
| Queue18 большие файлы и metadata | приоритет только на границе dispatch, активный файл/offset8192 сохранён | native/OS и live throughput Task21 NOT_RUN |
| PR46 data visibility / upgrade | no schema/media/bootstrap change; fixture DB/mediaSHA/integrity regression | Реальный native/phone gate не заменён FFI |
| Новая APK с чужой подписью | signing/version/package исходники не меняются, выпуск остановлен | BLOCKED_ENV до прежнего ключа и безопасного runner |
| CI billing |44959026009 runner не выделен,0steps; нет повторного dispatch | BLOCKED_ENV; локальные тесты указаны отдельно |
| Публично редактируемые отчёты | metadata anyone:writer, sanitized evidence + SHA readback | ACL не изменялась; будущую неизменяемость не обещаем |
| Scope/role/Google | synthetic server principal vs реальные аккаунты разделены в отчётах | Google/device/production tests NOT_RUN |

Нет вымышленных quotas/server metrics/процентов лимита. Нет live provider selection, VPN, платного сервиса, GC, новой очереди/каталога, real identity migration или семистрочной панели с фиктивными данными.
