# №17 — подтверждённые причины и границы доказательств

Проверяемый исходник приложений: `fbdaa7b0b51f9b742a0c5db84f5ef50ba4375568`, `fix/task17-stable-auth-queue`, draft PR48. База — PR47 `25ecdf984a831a288bf85e14119a5e054144ccf9`, не объединённый с main. Аудит выполнен до исправлений: a7c5035. Исходные RED сохранены, старые отчёты №16 не переписывались.

## Воспроизведённые дефекты

| Причина | До исправления и доказательство | Исправление и проверка |
|---|---|---|
| Lifecycle ошибочно считался ручной паузой | `AlchemistWorkQueue.pauseAll` вызывал pause с USER_PAUSED. Если пауза наступала до dispatch, `_stops` прерывал задачу до увеличения attempts: 0 попыток и 0 запросов. `G0_RED.log`: ожидался LIFECYCLE_PAUSED, получен USER_PAUSED. | Отдельные lifecycle/owner/user коды; prepare проверяет identity/роль до передачи. `task17_root_cause_test.dart`, `task17_queue_test.dart`. |
| Холодное восстановление принималось за смену аккаунта | `AlchemistApi.call` запоминал public scope до await credential. Silent restore устанавливал собственный verified scope; guard выбрасывал ACCOUNT_CHANGED до HTTP. Второй RED в G0. | Первичная привязка допускается один раз перед первым HTTP при неизменном generation; существующий owner и logout epoch по-прежнему защищены. |
| Каталог запоминал анонимный credential | `SessionController.alchemistApi(authenticated:false)` создавался до входа и навсегда сохранял null вместо общей функции получения credential. `CATALOG_SESSION_RED_17.log`: ожидался controlled credential, получен null. | Динамический источник credential и единый endpoint/identity с дневником. `task17_catalog_session_test.dart` проверяет также logout. |
| Resume мог исчезать во время cooperative pause | Enqueue молча возвращался при уже активной задаче; восстановление worker могло маркировать живой worker как APP_RESTART. | Observable QueueEnqueueResult, отложенный Resume после текущего запроса, process runnerEpoch отдельно от Google owner. Controlled тест удерживает реальный async запрос, запрашивает pause/resume и проверяет следующий dispatch. |
| SDK сам открывал лишний путь выбора аккаунта | Android google_sign_in_android7.2.18 после authorized/auto-select вызова делал fallback `filterToAuthorized:false, autoSelectEnabled:false` даже при automatic restore. Это конкретный путь к picker, но не доказательство времени 15 минут на телефоне. | Узкий fork удаляет только второй fallback; explicit authenticate сохранён. `task17_google_android_test.dart` вызывает настоящий Dart adapter с контролируемой SDK-границей и проверяет ровно один authorized запрос. Native Credential Manager/Google на реальном устройстве ещё NOT_RUN. |
| Reader называл публикацию черновиком | `diaryMeta` проверял number==null. GAS6 уже возвращает entry.status=published, но number может отсутствовать. | Заголовок зависит от статуса. Никакого вымышленного номера и миграции не требуется. `task17_diary_test.dart`. |
| Ложная отметка «есть черновик» | Сравнивался raw media map: private localPath и public locator различались при одинаковых проверенных байтах. | Семантический fingerprint учитывает hash/MIME/размер и авторские правки, не физический путь. Для непроверенных медиа остаётся консервативное сравнение. |
| Курсор каталожной формы терял фокус | Автосохранение каждые500мс выставляло busy и disabled полей. | Фоновое сохранение не отключает поле и не пересоздаёт контроллер. Widget-тест удерживает focus, selection и composing range после autosave. |
| Надпись показывала старую версию | `space_sheet.dart` содержал буквальное0.4.12+17. | Чтение versionName/versionCode/applicationId из существующего read-only Android diagnostics channel; подпись/Back handler не менялись. |
| Сервер отклоняет короткую запись | Точный Diary.js deployed-source1a0cf8... позволяет blocks=[] при нормализации, но entry.publish требует substantive block. Новый regression на точном старом коде RED (`GAS6_SHORT_ONLY_RED_17.log`). | Подготовлен минимальный diff: непустое message.trim() также считается содержимым. Candidate controlled GREEN. **НЕ deployed; LIVE BLOCKED_OWNER_APPROVAL**. Нельзя подменять сообщение фиктивным блоком или кнопкой. |

## Общая identity и очередь

Один GoogleDiaryIdentity → DiaryController → AlchemistDiaryApi → server auth.whoami. Каталог, publisher, CLIENT installer берут credential/scope/generation из того же источника. Owner binding до изменений уже был SHA(endpoint|scope), а scope — SHA(endpoint+server-verified sub); он не был хешем токена или email. Алгоритм и старые owner значения сохранены. Новая runnerEpoch — только локальный маркер жизненного цикла worker, не аккаунт и не credential.

Три уровня повторной публикации: UI блокируется до durable enqueue; существующий app_settings outbox атомарно хранит owner+редакцию; сервер получает прежний requestId и возвращает receipt. В controlled Dart→JS тесте ответ catalog.publish теряется ПОСЛЕ реального commit доменной логики. Клиент делает catalog.get, затем повторяет тот же requestId. Каталог и дневник — разные явные операции: дневниковый анонс больше не размещает материал в каталоге скрытым действием.

## Чего доказательства не утверждают

Нет trace с телефона владельца для каждого старого эпизода. Поэтому нельзя объявить одну причину объяснением всех симптомов. Из актуального паспорта сохранён исторический факт одной доставки текста+изображения MASTER26→CLIENT25; это не приёмка каталога, обновлённого SDK или №17.

Read-only live serverVersion вернул HTTP200/source1a0cf8e5a60144075eec793767953586bfa319a2/policy2/fullSourceReady. Историческое развёртывание этого source — version6. Endpoint не раскрывает числовую admin version; последующий отдельно разрешённый inspect43584729310 подтвердил deployment version6, HEAD и23файла (SERVER_ADMIN_RESULT_17.md). Новое развёртывание, bootstrap, ACL и OAuth не выполнялись.

Диагностика QA выключена по умолчанию, opt-in только debug, RAM200 событий/TTL20мин, экспорт явной кнопкой. В нём нет token/sub/email/URL/личного текста/файлов или media payload; owner сравнивается boolean. Старые owner-трассы не выдумываются.

## Дополнительная регрессия полного CI

Первый полный прогон43513716062:457PASS/11FAIL. Десять ожиданий относились к старым local mode labels — они сохранены для offline legacy режима; connected server role по-прежнему выводится отдельно. Один настоящий дефект обнаружен исходным `task16v_legacy_draft_visibility_test.dart`: `_verifyIdentity` сама увеличивала generation при подтверждённой смене subject, а затем считала своё увеличение внешним logout после записи hint. Счётчик собственной проверенной смены теперь учитывается явно; более поздний logout всё ещё отменяет ответ. Исходный legacy-scope тест GREEN,4 auth/late logout guard GREEN. APK build/native первого CI не запускались благодаря gate.

## Дополнительный авторский статус при устаревшем feed cache

`DiaryScreen.row` уже выводил заголовок/иконку published по авторскому подтверждённому объекту, но нижнюю подпись выбирал только по наличию reader-feed snapshot. После завершения queue→authorRepository.load без feed.refresh получалось противоречие «Опубликовано / Черновик». Новый widget regression создаёт сохранённый авторский published объект и пустой reader cache: настоящий RED до изменения, GREEN после. Нижняя подпись теперь использует уже вычисленный confirmed; изменения автора по-прежнему определяются отдельным semantic fingerprint. Всего6 новых UI/unit PASS. Пара изsource85ff остаётся в карантине, не выдавалась; перед окончательной выдачей нужен проверенный build с этим исправлением. Старые APK25/26/подпись и данные не затрагиваются.

## Продолжение: подтверждённый crash эмулятора MASTER26

Run43610436406: настоящий QEMU PID3080 завершился SIGSEGV (-11) до установки27 и до cleanup; обёртка не получала stop, cgroup oom_kill до/после0. CONFIRMED_SIGNAL_17.json содержит фактический receipt. Это host crash37.2.13, а не доказанный дефект миграции27. Точная faulting function без stack UNKNOWN.

Официальный pinned Emulator37.2.12 + проверка SHA/ready barrier и адресные исправления route/exact input readback позволили завершить43614090740 SUCCESS:13native PASS. Детали/неуспешные предшественники сохранены в TESTS_17.md и CODEX_EFFICIENCY_17.md. Критерии и байты APK не изменены. Legacy Google drafts и физическая приёмка NOT_RUN.
