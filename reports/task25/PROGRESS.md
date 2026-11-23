# №25 — активная контрольная точка прогона 12

Запущен diagnostic run **45214392456**, доверенная main **4a11ad9dabf5beb4bb7a87015fc8a05b1d165387**, узкий обычный PR74 (workflow hash + documented GDB signal policy). Не дублировать. Одно MASTER API35 под GDB; API36 и доставка отключены. Сначала обязательная установка GDB из подписанного Ubuntu APT и реальный контроль PC/сигналов отдельным шагом ДО emulator action. При провале action skipped. Receipt связан с SHA самого GDB и reviewed GDB script.

Фактический предыдущий run9 45210761918: GDB отсутствует. Контроль/fixture/установка APK28 не выполнялись. Upstream action всё же boot-нул Android после ошибки pre-hook; наш strong readiness отказал до fixture, QEMU штатно exit0. Это исправлено отдельным внешним preflight. Не выдавать run9 за QEMU SIGSEGV или успешную нативную проверку.

Run8 45207789337: реальная SDK37.3.10 по SHA a440 проверена, но MASTER35/CLIENT35 снова host SIGSEGV при паузе APK28 до обновления (по 5 ранних PASS). Нет OOM/cancel/minidump, dmesg unavailable. SDK-fix гипотеза не подтвердилась. Code-module пока UNKNOWN. Артефакты8/9 независимо raw size/SHA/CRC verified, raw synthetic snapshots/ZIP остаются локально и не публикуются в Git/Drive.

Приложения неизменны: source737ea741636e9abe7c20353d9d5b8301cf44a5bb, две подписанные APK29 build45103325755; никаких повторных сборок/подписей. 103 local QA-tool tests + actionlint PASS, оригинальные P0-проверки AST-identical. Нужны терминальные logs/artifacts run12 и PC metadata либо точный blocker. Никаких слепых повторов. Full four-gate delivery BLOCKED, owner versions UNKNOWN, реальные Google/телефоны NOT_RUN.

Пути: /dev/shm/sulfi25-resume, reports/task25/candidate29/continuation_sdk37310; /dev/shm/task25-pc12-watch.log. Диск overlay12MB free, тяжёлое толькоSHM. Локальных KVM/gdb нет — локальные emulator installs не делать. Старые APK/данные/production/ACL/OAuth/ключи/app PRstack не изменены. Папка25 1o5g7O5jm5yw2URWVCIhEJrbP40ddMPwn; текущий pointer пока исторический BLOCKED, его прежние 2674 bytes/SHA45d06… независимо подтверждены перед обновлением.

Run10: GDB15.1 установлен, selftest exit127 безсигнала. Android action полностьюSKIPPED: внешнийpreflight работает. Исправлена собственная ошибка запуска shell-c: отдельный фиксированный Python-файл, локальный РЕАЛЬНЫЙ процесс exit-11 без stdout/stderr/core. Это host-control, не AndroidPASS. Материалы RUN10_RESULT.md и run10/, hashes/CRC независимо проверены.

Run11: file-control исполнился, но GDB не остановился; сигнал fatal безобычного exitCode. Подтверждена собственная ошибка GDBpolicy: noprint implies nostop поофициальной Signals manual. PR74 исправляет stop print pass +logging /dev/null +actual $_exitsignal. Android action оставалсяSKIPPED. RUN11_RESULT.md/run11/ иофициальный quote/SHA сохранены. Контроль hostPC ещё требуетреальногоCI, mockunit103 не заменяетего.
