# Прогон 11: подтверждённая ошибка политики сигналов GDB

45213411298, main405f727335244404a67417fe146e35f74410d3bc. GDB установлен; отдельная control-программа действительно завершилась без обычногоexitCode (null), но сигнал не был перехвачен: signals[], INFERIOR_EXITED. Внешний preflight остановил выполнение ДО Android; все нативные шаги skipped. Не считать этот результат QEMU SIGSEGV или тестом обновления.

Readback артефактов size/SHA/CRC PASS. Найден подтверждённый дефект самого инструмента: `handle SIGSEGV stop noprint pass`. Официальная GDB Signals documentation прямо говорит: `noprint ... implies nostop`. Поэтому последующееnoprint отменялоstop. Исправление: `stop print pass`, logging redirect в /dev/null, чтение фактического `$_exitsignal` вместо зависимости от текстового transcript. Нормальные сигналы передаются, rawdebugger/память/стек не публикуются.

Источник: https://sourceware.org/gdb/current/onlinedocs/gdb.html/Signals.html . Полный прочитанный HTML SHA256913409f5f5a299b04df8d4f368f668dfb478edaabac1205b929abe92d2f40c5b; сохранён только публичный excerpt сreceipt. Прежнее предположение, что толькоargv объясняет весь отказ, было недостаточным: fileargv устранил exit127, но политика сигналов оставалась ошибочной. Контрольные прогоны10/11 НЕ трогали приложение.
