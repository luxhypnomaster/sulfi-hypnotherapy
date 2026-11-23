# Прогон12 — подтверждённый MASTER35 под host-наблюдением

45214392456 SUCCESS, main4a11ad9dabf5beb4bb7a87015fc8a05b1d165387, SDK37.3.10 exacta440, appsource737ea741636e9abe7c20353d9d5b8301cf44a5bb, прежние APK29. Single MASTER diagnostic mode: API36 и доставка намеренно SKIPPED, это НЕ полный допуск пары.

Реальный host-control PASS: пользовательский сигналSIGSEGV, modulelibc.so.6, относительныйfileoffset0x4553b, terminationSignal11. GDBSHA3832cc070ae1716e322105d3b39fb398695e5f031c9d39224cf227a8c2b889f6. На самом QEMU: INFERIOR_EXITED, exitCode0, signals[], terminationSignalnull. Ни одного SIGSEGV, перезапуска или восстановления. Нормальные сигналы передаются; ASLR сохранён, память/стек не читаются/не публикуются.

MASTER 17/17 PASS: UI3distinctaudio,2modules(одинсреальнойпаузой),program,history,localdraft28,controlledqueue/cache/settingssupplement,SAFcapsule,baseline,normal install-r28→29,exactrows/media,UI/nativeaudio,coldrestart,offlinepublicreader,localdraft29. Данные синтетические, первоначально созданы настоящей UIAPK28; supplementalqueue не Google и не serverE2E.

Артефакты14838083173/14836274170 независимо size/providerSHA/CRC PASS. Повторно непосредственно из14 raw Android snapshot tar-копий независимо прочитаны все15 таблиц SQLite, integrityok/schema9, сверены все privatefileSHA и snapshotSHA с JSONinventories. Источники не менялись; rawDB/tar/ZIP не публикуются. ExternalSAFcapsule не содержитсявprivate-tar: еёSHA отдельно согласован снативным отчётом, не объявлен независимым чтениемвнешнегофайла.

Вывод: P0-storage MASTER35 подтверждён в данном режиме, crash под GDB не воспроизвёлся. Это НЕ доказанная vendorfix или причинная локализация прежнего SIGSEGV; точный faultmodule прежних падений UNKNOWN. Следующий full35/36pairrun использует тотже проверенный hostobserver и добавляет stricter clean-exit/noSIGSEGV/noRestart gate без изменения исходныхP0cases. Обычная работаэмулятора безGDB и реальные телефоны по-прежнему не объявлены PASS.
