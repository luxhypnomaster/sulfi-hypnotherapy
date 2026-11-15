# №18 — фактические проверки G2

G0/G1 до реализации:81b7c71. Анализатор после текущих изменений — No issues. Первая адресная серия:12 PASS (новые4 queue и прежние queue/auth17). Расширенная серия:16 PASS —4 queue18,3 download18,4 queue17,4 auth17,1 Dart→production JS domain→selective client install16. Это CODE/CONTROLLED, не Android/Google/OWNER.

Новый crash-tail regression сначала RED: после truncate random-access cursor оставался в старом EOF, итоговый SHA расходился. Добавлено точное setPosition(confirmedOffset) до append. Узкая серия3 PASS, затем объединённая16 PASS. Коррупция подтверждённого префикса останавливает загрузку до сети/установки, байты сохраняются. Неподдерживаемый chunk API даёт CHUNK_RESUME_UNAVAILABLE без скрытого full-download fallback. Ранее успешная source27 проверка не подменяет эти результаты.

Промежуточная ошибка команды dart fix: интерфейс принимает один путь, исправлено адресным запуском. Две WIP-синтаксические ошибки closures/signature выявлены analyze, исправлены до CI. Неуспешная компиляция loading5 тестов не названа PASS; итоговая реально исполненная серия16 PASS.

Native Kotlin/Android OS lifecycle, API34/35/36, native27→28 обеих APK, реальные Google/две физические установки — NOT_RUN. Выдача APK28 пока заблокирована safety gate. Текущий CI только targeted compile без подписи/APK; полный suite запускать после завершения G2, не повторять вслепую.

## Второй implementation checkpoint

Upload lost-ack test: реальный MediaTransfer отправляет блок, controlled transport теряет ответ после принятия, клиент сначала выполняет beginUpload с ТЕМ ЖЕ requestId, затем повторяет тот же offset. Ровно2 новых блока для400001bytes,3HTTP upload попытки, повторная операция использует descriptor/старый receipt без передачи байтов.1новый тест + прежний production JS-domain integration PASS2. Обновлённые queue/download18 PASS7. Analyzer clean после исправления typed video-probe record.

Targeted native compile43658921493 наc94e668: FAIL до APK:2 Kotlin Int→Long errors у JobInfo.NETWORK_BYTES_UNKNOWN. Исправлено toLong для обоих аргументов, без ослабления OS policy. Следующий адресный compile сохранён отдельным запуском; Google/signing secrets не требуются. Изменения послеc94: async native media probe вне main thread, role-change invalidates authority epoch, typed video codec probe, finalizeDownload receipt validation и upload uncertainty reconciliation. Native lifecycle/upgrade/реальный Google пока NOT_RUN.

## Актуальная контрольная точка7f6c637 (15.11.2026)

Текущая адресная серия16PASS:8queue18,4download18,2mutation recovery18,1upload lost-ack18,1production JS-domain selective install. Фактический stdout с SHA/протоколом сохранён в evidence/G2_TARGETED_16.log; RED immutable editor — evidence/EDITOR_IMMUTABILITY_RED.log. У503после3HTTP попыток сохраняются2сетевых повтора и503 даже при отсутствии successful reply. Неверный finalize receipt не даёт success; повтор использует уже проверенные байты. Периодический reader sync не снимает USER_PAUSED. Анализатор актуального кода clean.

До перезапуска managed environment реально выполнены промежуточные Flutter480PASS/2SKIP, CLIENT3PASS, Node alchemist47PASS + legacy24PASS, offline contract13schemas/4fixtures/negativePASS. Временные полные локальные logs не пережили runtime restart; tool stdout с результатами остаётся в истории выполнения. Это НЕ финальная точная проверка будущей APK: после неё исправлены дополнительные дефекты, поэтому final CI ещё обязателен. Performance JSON1/15/50MiB сохранились вGit0ed382c; benchmark opt-in.

CI compile43660087187 SUCCESS; два full testOnly builds/installs в43662532407 и43663729317 SUCCESS, но общий native test FAILURE до передачи. Последний подтвердил Pixel Launcher ANR/first-frame timeout, не передачу и не app data safety. Полные evidence второго прогона в probe2/ извлечены из Actions logs ZIP с проверкой SHA, потому что gh run view --log после перезапуска вернул пустой текст. Новый native43700853248/source4984a7b — changed GLES/framebuffer hypothesis, результат ещё ожидается. Такие FAIL не объявляются PASS и не считаются Google/physical QA.

Native MASTER27/CLIENT27→28, API35/36 transfer, реальный Google/OEM/двухтелефонный/offline-heard результат — NOT_RUN. Никаких APK28 links до green data gate.


## Подтверждённый CI43704911303 / source19c3345

Verify job SUCCESS:485 Flutter PASS/0FAIL, CLIENT3PASS, Node47+24PASS,13schema/4fixture/10negative contractPASS,192format files/0changes,analyze clean. Общий run FAILURE: оба native upgrade jobs остановились на403 чтения private draft baseline, до установки. Quarantine candidate job SUCCESS; safeForOwnerInstall=false. Raw краткие строки в evidence/FULL_VERIFY_SOURCE19_18.log, точные SHA в QUARANTINE_SOURCE19_18.json.

Уточнение по хранилищу артефактов: шаг Preserve test report имел conclusion success благодаря continue-on-error, но сырые логи содержат Artifact storage quota has been hit. Реальный upload НЕ состоялся, API artifacts пуст. Не повторять вслепую, не удалять старые артефакты, не менять тариф/права. Использованы ограниченные доказательства в CI logs и private cache; выпуск/доставка новых APK ещё не выполнены.

Native probe43704911357 SUCCESS7: actual API34 Activity+engine destroyed/samePID, bytes both directions, complete unique commit,3files/3hash/module/program, CLIENT offline cold start + native UID-bound AudioTrack. App4ab0588, driver19c3345; доказательства probe5/. Новое native ownership исправлениеcea4897 требует собственного compile/JVM/native результата: старый probe PASS его не сертифицирует. Текущие43708103115 finalize и43708105791 extendedprobe запущены с одной checkpointcea4897.


## Actual43708103115 native finalization SUCCESS
Full run SUCCESS atcea4897. Strict reuse18 actual-tree gate PASS (unchanged verified Dart/server); fresh native compile/build and :app:testDebugUnitTest executed SUCCESS. Normal signed MASTER27→28 UI data14PASS; CLIENT27→28 UI data12PASS. Proofs native27_to28/ and NATIVE_UPGRADE_GATE_18.json.3 independent full APK manifests/byte SHA/certificate readbacks identical. No physical Google/owner phone claimed.

Extendedprobe6 failed before first transfer because external SystemUI ANR hid the actually drawn fixture UI; screenshot/crash0 preserved probe6/. New preflight observer run7 uses exact cached sourcecea4897 APKs, still in progress. Historical native5 app4ab remains valid only for that source.


## Текущий исходник59, не путать с исторической paircea
Normal candidate43715408673 SUCCESS, full analyzer/JVM task/cert/config guards выполнены. Новые upgrade jobs этого run BLOCKED до данных из-за SystemUI/Launcher ANR, не из-за product migration; native59_first/. Native Android SQLite controlled conversion MASTER+CLIENT43715411268 SUCCESS; receipts/screens legacy_native59/. Native normal retention of5 supplemental legacy rows и личного UI baseline ещё требует PASS текущего cached AOSP run43730982434. Full background/SIGKILL source59 probe43730572606 ещё выполняется.

Здесь dispatch в legacy-conversion проверке намеренно simulated/no-network; реальные OS transfers доказываются отдельно. Никакие controlled actors не названы Google-users. Исходники4ab/cea/59, unit/native/OWNER и общий результат каждого run разделяются.

## Source59 actual native evidence — continuation 16:24UTC
-43730572606 API34 SUCCESS11cases, includes actualSIGKILL→OS newPID6.65sec. `full34_59/probe/NATIVE_PROBE_18.json`.
-43732895132 API36 SUCCESS10cases. `api36_59/probe/NATIVE_PROBE_18.json`.
-43730982434 CLIENT13PASS; MASTER QEMU SIGSEGV before update. `native59_aosp/`.
-43733477006 MASTER BLOCKED before update; no crash this time. Failed one-shot SeekBar lookup, subsequent failure XML contains exactseconds. `master59_diag/`.
-43732897880 API33 FAIL at network automatic recovery; no GUI/force-run fallback presented asPASS. `api33_59/`.
-43732892168 API35 FAIL at install/inventory after network/Cancel/range PASS; sqflite lock warnings. `api35_59/`.
-43734787048 pending MASTER-only semantics-settle observer;43734790304 pending API33 scheduler diagnostic.
-43734927899 pending native isolated two-handle lock experiment; default1 vs4nativepool. TESTONLY, no real DB. Local full analyze ef50fc5 PASS, Python compile/diffcheckPASS.
All current evidence collector verifies byte count+SHA before writing. Controllednative/framework is not physical Google/OEM or humanhearing.

## Новое продолжение — текущий код2ec64b4 (старые59 gates исторические)

-4foreground-retry tests PASS и full local `flutter analyze --no-pub --fatal-infos` PASS. Полные485/3/Node относятся к старой неизменявшейся базе, **их reuse теперь НЕ действителен** для нового production Dart; перед новой парой нужен свежий full verify.
-43734790304 API33 scheduler/network readback подтверждает ready/not-active regular recovery при восстановленной validated Wi-Fi. НовыйboundedFGS-code native NOT_RUN.
-43734787048 MASTER failed before update: AOSP launcher не распознавался observer; сохранён XML, classifier теперь проверен на нём и отрицательных Sulfi/ANR примерах.
-43734927899 Dart SQLite experiment BLOCKED/NO_RECEIPT; не причинныйPASS.
-43736599516 pool1 and43737027095 pool4 actual native controls both fail write with SQLiteDatabaseLockedException; no productionDB. Pool-only strategy rejected; implementation not applied.
-43737664851 native busy-control inconclusive: childexit137/Killed, no receipt. Next43738174779 adds phase+guest kill diagnostics, no Flutter rebuild/signing/ownerdata. NativeJava/D8 compilation locally PASS.
-Source59 APKs остаются карантинными историческими байтами. Новый foregroundfix в них отсутствует; выдача запрещена. CurrentCODE requires new build and all native gates.

## Exact a894 results (historical after new scheduling change)
-43740142417 overallSUCCESS:489Flutter/0fail,3CLIENT,47+24Node, contracts/analyze/format, bothnormalAPKs/signature/config, app+sqfliteJVMtasksPASS, actualMASTER27→28 15cases andCLIENT13casesPASS. Rawlogs confirmtest-artifactuploadFAILEDquota despite continue-on-error stepconclusion; no artifactURLs claimed.
-Currenta894 fullNativeAPI33/35/36 SUCCESS10each:43742072087/43740145687/43742077665. Currentnativelegacy2PASS43742080443.
-API34/43742074940 FAILcoldSIGKILL recovery: no newPID within660sec, jobsreadybutnotstarted. Beforefailure UI destroy/background/watchdog/notificationPause/coldexplicitResume PASS. No claim of current34 processlossPASS or owner-safepair.
-New conditionaldeadline/watchdog2min/recovery8min/networkpreflight changes:4newKotlin tests added (NOT_RUN untilfreshCI), localFlutteranalyzePASS andforeground4testsPASS. Freshfull/native/build next; no mixing source receipts.
