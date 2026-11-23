# Native5: исправление наблюдателя, не приложения

Run45161085603, main3a45c202798307f1fc2593c9b883f2fbe6394951. MASTER actual28→29 normal install-r PASS, cold restart PASS, exact rows/media/settings/private local diary preserved, native audio observed, offline public reader PASS. Всего16PASS+1BLOCKED. Independent15-table readback: единственная ошибка ALL_CASES_PASS; bytes/rows/pins не нарушены.

Последний case ui_master_local_diary29 вызвал old helper open_diary_editor, находясь в reader route из предыдущего case. Actual failure XML содержит «К списку записей», нет «Новая запись». Reader mode сохраняется законно; helper не выполнил переход в авторский список. Это ошибка test navigation. QEMU child3362 штатноexit0 после cleanup, no signals/noOOM, NO_MINIDUMP_FOUND. Нельзя назвать этот прогон повторным SIGSEGV или объявить host crash исправленным.

Минимальный QA patch: перед original editor helper выйти через existing «К списку записей», выбрать existing «Автор»/«Мои записи» только если control наблюдается; original editor readiness и exact SQL persistence assertions остаются. Binding только MASTER. Не изменяется код приложения, роли, Back, Google, данные/guards. Структурный AST-test доказывает полный original helper, Java fixture и все originalcase assertions идентичны после исключения единственного observer binding.

RED controlled replay actualfailureXML отказал в NewEntry; GREEN75tools PASS. NativeGREEN ещё требует отдельного запуска, fakeUI не nativePASS. AOSP35 вариант рассмотрен, но НЕ применён: свежая native evidence показывает рабочий MASTER34 data gate и конкретный observer defect. Сохранён как NOT_APPLIEDdiff, не менял main.
