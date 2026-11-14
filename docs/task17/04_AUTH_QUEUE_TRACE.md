# №17 — минимальная безопасная трассировка AUTH → ROLE → QUEUE → SERVER

Цель — локализовать разрыв по событиям, а не строить новый мониторинговый продукт. Только debug/QA opt-in, кольцевой буфер небольшой фиксированной длины, ограниченный TTL, экспорт пользователем по явному действию с маскированием. Не писать токены/секреты, bearer, cookie, Google ID token, полные sub/email, личный текст, имена пользовательских файлов, Drive URL и payload медиа. Если нужна телеметрия серверного запроса, использовать заранее проверенный correlation/trace ID и код операции.

## Этапы событий

`SESSION_RESTORE_START` → `SESSION_RESTORE_OK|NEEDS_USER|OFFLINE|ERROR` → `TOKEN_REFRESH_START` → `TOKEN_REFRESH_OK|DENIED|ERROR` → `SERVER_WHOAMI_START` → `SERVER_WHOAMI_MASTER|CLIENT|DENIED|UNKNOWN` → `QUEUE_OWNER_MATCH|MISMATCH|UNBOUND` → `QUEUE_WAITING|PAUSE_USER|PAUSE_LIFECYCLE|PAUSE_AUTH|PAUSE_NETWORK` → `RESUME_REQUESTED|RESUME_ALLOWED|RESUME_DENIED:<reason>` → `HTTP_REQUEST_START:<operation>` → `HTTP_STATUS:2xx|401|403|redirect|DNS|TLS|5xx|timeout` → `SERVER_COMMIT_CONFIRMED|UNCERTAIN|DENIED`.

Данные событий: безопасный traceId, локальный монотонный timestamp/duration, build/version, operation class (diary/catalog/download), taskId и revision как локальный opaque ref, owner fingerprint из неперсонального HMAC/hash с секретом недоступным для export (или просто сравнение owner_equal boolean), source screen, app lifecycle, explicit vs implicit transition, count bounded retries, bytes_sent/total_known, last safe error. Дамп редактируется до показа. Не засекреченные полные task IDs, если они раскрывают сведения, не включать. Сервер должен принимать и возвращать безопасный correlation ID без отражения credential.

## Матрица обработки

| Событие | Клиент | Сервер | Очередь |
|---|---|---|---|
| Первый login | Google chooser после действия человека | Verify token, `sub`, роль | Только owner-bound задачи |
| Expired short-lived credential | Silent refresh / bounded retry | `401` без раскрытия | `WAITING_AUTH`, не `USER_PAUSED`, не удалять |
| Verified subject same, new token | Сохранить session | Проверить права на операцию | owner match, допустим resume |
| Role declined | Показать права/denied | `403`, не refresh-loop | WAITING_PERMISSION / DENIED |
| Network/DNS/TLS drop | UI offline и backoff | Запрос мог не дойти | WAITING_NETWORK, bytes/attempt accurate |
| Explicit sign-out | Зафиксировать signed-out intent | Revoke/deny as contract allows | PAUSED_OWNER until explicit login |
| Other account | Интерактивно по выбору | Проверить новое `sub` | Old tasks quarantined; no leak |
| Android background | Не обещать foreground upload | In-flight request may finish | PAUSE_REQUESTED → PAUSED_LIFECYCLE |
| Server receipt lost | Query authoritative status before retry | Idempotent commit, one revision | No duplicate publish |
| Server verify has zero media bytes | Show stage, not fake 0% | Verify manifest/content | VERIFYING_SERVER, no 0/0 progress bar |

## Что считать доказанной первопричиной

Не «похоже на авторизацию», а воспроизводимое условие и конкретный code path: например `same_verified_sub=true`, `session_restore_ok=true`, `queue_owner_match=false` из-за сравнения token/accountHash; или `server role valid`, но `PAUSED_USER` выставлен по app lifecycle и resume no-op; или запрос реально стартует и 401/redirect/timeout. В отчёте указать точный файл/функцию/ветку и тест, красный до патча и зелёный после. Любая другая выявленная причина допускается только с evidence.

## Отладочная индикация

На `Подключение и права`/в `Вашем пространстве`: `Аккаунт: вошёл / восстановление / вышел / нужна авторизация`, `Роль: проверена сервером / ожидает / нет доступа`; отдельно в очереди `Ожидает сеть / проверяет сервер / пауза пользователем / смена владельца`. Кнопка «Скопировать диагностический отчёт» debug-only без секретов. Избегать постоянного быстрого polling; экономный backoff и события connectivity.
