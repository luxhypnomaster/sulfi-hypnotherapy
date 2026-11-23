# Прогон 10: контроль отладчика

Run45212351651, main3b5f6c2dcb05b4dd8dc37621c6db059c4dcb51fa. Пакет Ubuntu GDB15.1-1ubuntu1~24.04.1 установлен через APT с проверкой подписей. Контроль завершился exit127 без SIGSEGV; GDB_PC_CONTROL_FAILED. По PC_SELFTEST: signals[], INFERIOR_EXITED, exitCode127. Это дефект диагностического вызова, не падение QEMU и не результат приложения.

Отдельный обязательный step выполнил безопасную остановку: KVM/Android/emulator/fixture/API36/delivery SKIPPED. Подписи/байты APK readback PASS. Оба артефакта независимо size/SHA/CRC verified, run10/.

Следующее исправление касается только контрольной команды: вместо сложной строки shell-c передавать путь к фиксированному Python-файлу. Он игнорирует USR1/USR2, затем действительно посылает себе SIGSEGV, core отключён. Локальный реальный subprocess подтвердил exit -11 без stdout/stderr. Это тест host-процесса, не Android PASS. Никаких повторных сборок, подписей или изменений приложения.
