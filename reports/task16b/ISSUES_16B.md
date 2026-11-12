# №16-Б — оставшиеся препятствия и действия

Дата: 12.11.2026. Source `012f7f69b7ad99c0d44f2a442d9649aa1481117e`, ветка `fix/task16b-auth-transfer-publication`, [draft PR45](https://github.com/luxhypnomaster/sulfi-hypnotherapy/pull/45).

| Пункт | Статус | Что требуется |
|---|---|---|
| APK25 реальные MASTER/CLIENT login,refresh,оба entrypoints | NOT_RUN_OWNER | Владелец и второй пользователь: установить APK25 поверх прежних,пройти PHONE_QA_16B.md |
| Полный Элман3tracks → catalog → diary link → client → offline sound | BLOCKED_OWNER_DEVICE_TEST | Реальные файлы и два телефона;начальные входы APK24 уже подтверждены,не повторять их как новый полный успех |
| Wi-Fi/mobile/DNS/TLS/network switch и p50/p95 реального Drive | BLOCKED_PHYSICAL_NETWORK_MEASUREMENT | Записать тип сети,время,стадию,bytes,code/trace;не передавать ID token/пароль |
| Новые signed JWT diagnostic codes/trace response в production | BLOCKED_OWNER_DEPLOY_APPROVAL | Отдельно разрешить deployment конкретного проверенного source;старый deployment6 пока сохранить |
| Private draft APK download для посторонних тестировщиков | ACCESS_LIMITATION | Владелец скачивает после GitHub login и передаёт APK через Quick Share;публичный релиз/доступ к исходникам не включались |
| Старые unbound pending upload records | SAFE_QUARANTINE | Сохранены;нет автоматической передачи под вновь выбранным аккаунтом. Явная новая постановка из своей карточки создаёт bound task/reconciles committed media |
| Same logical ID с другими аудиобайтами | EXISTING_G3_LIMITATION | Fail-closed guard сохранён;исследовательский PR43 не объединён,реальная база пользователя не мигрировалась |
| Background content upload | DOCUMENTED_COOPERATIVE_PAUSE | На paused/detached приложение ставит передачу на паузу после текущего запроса. Нет обещания непрерывной foreground service загрузки. Возобновить явно |

Исходная причина DNS errno7 конкретных телефонов остаётся кандидатом,а не доказанным лимитом GAS. Сохранность local originals и bounded retries подтверждены тестами,но фактическую радиосеть ими не заменяли. Отмена ожидания не снимает уже успевшую подтвердиться публикацию: для отзыва использовать существующее действие в карточке.

Код и отчётность №16-Б не закрывают автоматически старые147 критериев №16. Их исходные файлы сохранены; DELTA_147_16B.md добавляет новые факты без массового перевыставления PASS. Матрица80 новых требований содержит отдельные Code/Emulator/Live/Owner поля.
