# №18 — фактические проверки G2

G0/G1 до реализации:81b7c71. Анализатор после текущих изменений — No issues. Первая адресная серия:12 PASS (новые4 queue и прежние queue/auth17). Расширенная серия:16 PASS —4 queue18,3 download18,4 queue17,4 auth17,1 Dart→production JS domain→selective client install16. Это CODE/CONTROLLED, не Android/Google/OWNER.

Новый crash-tail regression сначала RED: после truncate random-access cursor оставался в старом EOF, итоговый SHA расходился. Добавлено точное setPosition(confirmedOffset) до append. Узкая серия3 PASS, затем объединённая16 PASS. Коррупция подтверждённого префикса останавливает загрузку до сети/установки, байты сохраняются. Неподдерживаемый chunk API даёт CHUNK_RESUME_UNAVAILABLE без скрытого full-download fallback. Ранее успешная source27 проверка не подменяет эти результаты.

Промежуточная ошибка команды dart fix: интерфейс принимает один путь, исправлено адресным запуском. Две WIP-синтаксические ошибки closures/signature выявлены analyze, исправлены до CI. Неуспешная компиляция loading5 тестов не названа PASS; итоговая реально исполненная серия16 PASS.

Native Kotlin/Android OS lifecycle, API34/35/36, native27→28 обеих APK, реальные Google/две физические установки — NOT_RUN. Выдача APK28 пока заблокирована safety gate. Текущий CI только targeted compile без подписи/APK; полный suite запускать после завершения G2, не повторять вслепую.

## Второй implementation checkpoint

Upload lost-ack test: реальный MediaTransfer отправляет блок, controlled transport теряет ответ после принятия, клиент сначала выполняет beginUpload с ТЕМ ЖЕ requestId, затем повторяет тот же offset. Ровно2 новых блока для400001bytes,3HTTP upload попытки, повторная операция использует descriptor/старый receipt без передачи байтов.1новый тест + прежний production JS-domain integration PASS2. Обновлённые queue/download18 PASS7. Analyzer clean после исправления typed video-probe record.

Targeted native compile43658921493 наc94e668: FAIL до APK:2 Kotlin Int→Long errors у JobInfo.NETWORK_BYTES_UNKNOWN. Исправлено toLong для обоих аргументов, без ослабления OS policy. Следующий адресный compile сохранён отдельным запуском; Google/signing secrets не требуются. Изменения послеc94: async native media probe вне main thread, role-change invalidates authority epoch, typed video codec probe, finalizeDownload receipt validation и upload uncertainty reconciliation. Native lifecycle/upgrade/реальный Google пока NOT_RUN.
