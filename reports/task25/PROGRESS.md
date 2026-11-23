# №25 — активная контрольная точка прогона 10

Запущен diagnostic run **45212351651**, доверенная main **3b5f6c2dcb05b4dd8dc37621c6db059c4dcb51fa**, узкий обычный PR72 (workflow + host helper). Не дублировать. Одно MASTER API35 под GDB; API36 и доставка отключены. Сначала обязательная установка GDB из подписанного Ubuntu APT и реальный контроль PC/сигналов отдельным шагом ДО emulator action. При провале action skipped. Receipt связан с SHA самого GDB и reviewed GDB script.

Фактический предыдущий run9 45210761918: GDB отсутствует. Контроль/fixture/установка APK28 не выполнялись. Upstream action всё же boot-нул Android после ошибки pre-hook; наш strong readiness отказал до fixture, QEMU штатно exit0. Это исправлено отдельным внешним preflight. Не выдавать run9 за QEMU SIGSEGV или успешную нативную проверку.

Run8 45207789337: реальная SDK37.3.10 по SHA a440 проверена, но MASTER35/CLIENT35 снова host SIGSEGV при паузе APK28 до обновления (по 5 ранних PASS). Нет OOM/cancel/minidump, dmesg unavailable. SDK-fix гипотеза не подтвердилась. Code-module пока UNKNOWN. Артефакты8/9 независимо raw size/SHA/CRC verified, raw synthetic snapshots/ZIP остаются локально и не публикуются в Git/Drive.

Приложения неизменны: source737ea741636e9abe7c20353d9d5b8301cf44a5bb, две подписанные APK29 build45103325755; никаких повторных сборок/подписей. 102 local QA-tool tests + actionlint PASS, оригинальные P0-проверки AST-identical. Нужны терминальные logs/artifacts run10 и PC metadata либо точный blocker. Никаких слепых повторов. Full four-gate delivery BLOCKED, owner versions UNKNOWN, реальные Google/телефоны NOT_RUN.

Пути: /dev/shm/sulfi25-resume, reports/task25/candidate29/continuation_sdk37310; /dev/shm/task25-pc10-watch.log. Диск overlay12MB free, тяжёлое толькоSHM. Локальных KVM/gdb нет — локальные emulator installs не делать. Старые APK/данные/production/ACL/OAuth/ключи/app PRstack не изменены. Папка25 1o5g7O5jm5yw2URWVCIhEJrbP40ddMPwn; текущий pointer пока исторический BLOCKED, его прежние 2674 bytes/SHA45d06… независимо подтверждены перед обновлением.
