# №22 — ОБЯЗАТЕЛЬНОЕ УТОЧНЕНИЕ v1.5: три рейтинга и заменяемая версия расчётной политики

Нормативная опора: S-X-RATING-001 v0.6 §9; прямое решение владельца в текущем чате. Этот файл ИМЕЕТ ПРИОРИТЕТ перед любыми более ранними упоминаниями только 2 отображаемых рейтингов либо жестко зашитых весов в №22.

## Цель без затяжной математической разработки
Codex НЕ должен самостоятельно выбирать «лучший» коэффициент, симулировать справедливость рейтингов на 100 сценариях как обязательный предполётный блок или ждать утверждения финальной формулы. Он должен сделать программно правильную *архитектуру* со сменными стратегиями и настройками, сохранить объективные evidence, запустить контролируемые fixtures и вывести расчёт в production только когда owner утвердит policy.

## Три отображаемых рейтинга для COURSE / PROGRAM / MODULE / TRACK
1. `consumerDirect`: среднее из **прямых**, добровольных CLIENT-отзывов именно об этом logical contentId + ratingEpochId. Реальные `N`, среднее, распределение, времени обновления; `null` при N=0.
2. `professionalDirect`: то же для SERVER-VERIFIED_PRO, строго отдельно от CLIENT и от AUTHOR_SELF_TEST. Один факт работы в PRO приложении не подтверждает квалификацию. Реальные N; `null` при N=0.
3. `weighted`: VERSIONED computed score, потенциально объединяющий оба прямых cohort и реальные косвенные свидетельства с экспозициями. До согласования производственного алгоритма — `value:null,status:NOT_CALIBRATED`; в изолированном benchmark допустим отдельный experimental score с явным `EXPERIMENTAL`, который не публикуется клиенту. Нельзя выдумывать рабочие веса.

Сохранять также `direct vs indirect` как **тип доказательства**, а не как отдельную четвертую headline-оценку. ADMIN видит source breakdown, inherited context, N, freshness, confidence, policy hash, историю. Одно голосование по курсу не создаёт отдельных прямых голосов всем программам, одна программа не создает module/track direct; косвенное влияние только через реальные прослушанные occurrence с root-feedback dedup.

## Интерфейс расчётчика и независимая настройка
- Вынести `RatingCalculator`/`RatingStrategy` в отдельный чистый deterministic и тестируемый backend-модуль с интерфейсом `(target, evidence, immutable RatingPolicy) -> WeightedRatingResult`. API, хранения отзывов, Android code и Flutter views не должны содержать числовые формулы и magic weights.
- Дать `strategy registry` с `algorithmId`, `algorithmVersion`, `parameterSchemaVersion`; раздельные typed config fields/матрицы для target type, ancestor hops/edge type, source type, verified PRO multiplier, direct/indirect ratio/cap, repeated root N, partial exposure, small N/confi­dence. Хранение числа коэффициентов и вариантов не равно утверждению их значений.
- `RatingPolicy` immutable-versioned: `policyId`, `configVersion`, `hash`, `schemaVersion`, `algorithmVersion`, `actor/approvedBy`, `status: draft/validated/staged/active/retired`, `createdAt/effectiveAt`, scope and audit. Проверять схему/диапазоны и запрещать arbitrary executable JS/code from UI.
- Возможность поменять **коэффициенты** без пересборки APK/кода через owner-controlled configuration; возможность заменить **саму формулу** через версионируемый кодовый plugin/strategy и обновление server code, без разрушения исторических данных. Не обещать, что UI сможет безопасно произвольно редактировать любую математическую функцию.
- Предусмотреть расширение значения алгоритма при малой/большой выборке через config/strategy. Смена policy не трогает raw reviews, contentRevision, ratingEpochId, установленные assets, SessionRun.

## MASTER «Управление → Статистика и отзывы → Модель рейтинга»
- Просмотр трех рейтингов, raw N по аудиториям, evidence confidence, расхождения и источники.
- OWNER: active-policy read, history, clone draft, edit allowed numeric parameters, preview/shadow simulation with synthetic fixtures and permitted aggregate data, side-by-side diff, staged validation, confirm atomic publish, audit, rollback to previous policy. Точная отрисовка может оставаться рабочим UI согласно S-D-ADM-001; не блокировать серверный контракт отсутствием финального макета.
- LEAD_ADMIN: read/preview/draft; publish только при явном `ratingPolicy.publish` owner-issued grant (пока OPEN). ORDINARY ADMIN: read/preview без publish; CLIENT — no admin operations. SERVER проверяет ACL, не полагается на скрытую кнопку.
- Не допускать `eval`, произвольных формул/скриптов из UI, клиентского прямого изменения server policy. Для смены всей математической функции — PR/Codex code review и отдельный deploy; владелец может переключать только подготовленные validated strategy versions.

## Опубликование и пересчёт
- Новый policy version запускает конечную idempotent/coalesced recomputation queue с лимитами нагрузки, журналом и progress. До завершения показывать verified lastGood и устаревший policyVersion.
- Атомарное переключение рейтингового active pointer/head только после verified hash+readback; ratingsRevision/hash обновляется независимо от content snapshot/media; rollback на lastGood без удаления исходных оценок. GET карточки не пересчитывает историю и не делает сеть на каждый экран.
- Простейший safe path в большом №22: обеспечить object model, registry, config/version validation, prototype calc+test fixtures, API draft/preview/activate+rollback, отдельные consumerDirect/professionalDirect aggregates, frontend read UI (минимальная админ-панель). Если нет времени на full UI — завершить backend contracts и не заявлять его PASS.

## Тесты (добавить к общей матрице)
T22-053: `consumerDirect=4.0,N=5`; `professionalDirect=null,N=0`; `weighted NOT_CALIBRATED` → три корректные поля, нет нулевой звезды PRO.
T22-054: `professionalDirect=5,N=1`, `consumerDirect=3,N=10`, `AUTHOR_SELF_TEST=5,N=1` → категории раздельны, авторский тест не повышает внешний рейтинг, никаких вымышленных weighted N.
T22-055: две версии config/strategy на одинаковых independent evidence дают воспроизводимые два weighted mock outcomes, а direct/raw reviews не мутируют; old version полностью воспроизводима.
T22-056: OWNER draft→preview/diff→validate→publish только после verified snapshot; CLIENT/ordinary ADMIN mutation 403 и нет возможности передать JS как формулу.
T22-057: ошибка/незавершенный пересчёт оставляет old active policy/lastGood; rollback восстанавливает предыдущий state без потери аудио, истории, отзывов, независимых cohorts.
T22-058: курс→программа→модуль→трек, повторные occurrence, частичный/нулевой playback, оценка без прямых module/track, N=1 и N=500: отдельно raw direct cohorts, правильно сохранены косвенные root IDs; config допускает разные правила per objectType, без фальшивых прямых оценок.

**Статус:** 3 показателя и структурная сменяемость расчёта — направление OWNER approved. Коэффициенты, релизный математический алгоритм, полномочия LEAD_ADMIN publish, финальный UX — OPEN. Математический анализ и калибровку перенести на отдельный цикл; НЕ останавливать независимую кодовую реализацию.
