# №18 — фактические проверки G2

G0/G1 до реализации:81b7c71. Анализатор после текущих изменений — No issues. Первая адресная серия:12 PASS (новые4 queue и прежние queue/auth17). Расширенная серия:16 PASS —4 queue18,3 download18,4 queue17,4 auth17,1 Dart→production JS domain→selective client install16. Это CODE/CONTROLLED, не Android/Google/OWNER.

Новый crash-tail regression сначала RED: после truncate random-access cursor оставался в старом EOF, итоговый SHA расходился. Добавлено точное setPosition(confirmedOffset) до append. Узкая серия3 PASS, затем объединённая16 PASS. Коррупция подтверждённого префикса останавливает загрузку до сети/установки, байты сохраняются. Неподдерживаемый chunk API даёт CHUNK_RESUME_UNAVAILABLE без скрытого full-download fallback. Ранее успешная source27 проверка не подменяет эти результаты.

Промежуточная ошибка команды dart fix: интерфейс принимает один путь, исправлено адресным запуском. Две WIP-синтаксические ошибки closures/signature выявлены analyze, исправлены до CI. Неуспешная компиляция loading5 тестов не названа PASS; итоговая реально исполненная серия16 PASS.

Native Kotlin/Android OS lifecycle, API34/35/36, native27→28 обеих APK, реальные Google/две физические установки — NOT_RUN. Выдача APK28 пока заблокирована safety gate. Текущий CI только targeted compile без подписи/APK; полный suite запускать после завершения G2, не повторять вслепую.
