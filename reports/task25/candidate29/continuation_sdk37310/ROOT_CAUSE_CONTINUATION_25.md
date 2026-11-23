# №25 — установленные причины и границы вывода

Подтверждено: выполнение native gate прекращает host-эмулятор при открытии паузы в старойAPK28. Раннийrun8 мониторировал настоящийqemuchild и зафиксировалSIGSEGV/exit-11, нулевыеOOMkills и отсутствиеwrapper-cancel. ВерсияSDK37.3.10 реально проверена поvendorarchiveSHA и бинарнику; её обновление не устранило сбой.

Run12 подGDBполностью прошёл MASTER35. Run13 подтвердил CLIENT35, но MASTER вновь потерялADB. GDB зафиксировалSIGSEGV в исполняемом отображении вне allowlist, затем выдалerror приcontinue. Его конечныйexit1 нельзя приписывать напрямуюфатальному исходутогожесигнала: судьбаinferiorпослеошибкиотладчиканеустановлена. Точноеимямодуля/функцияUNKNOWN; не утверждатьSwiftShader/AVX/гонку/миграцию как доказаннуюпричину. Не публиковалисьrawmaps,память,стек,core; dmesgнедоступен.

Отдельно подтверждены причины трёх отказов самого diagnostic setup: GDB отсутствовал наrunner; контрольнаяshell-cкомандадалаexit127; GDBnoprint подразумеваетnostop и отменялstop. Они исправлены и проверены настоящимLinuxSIGSEGVcontrol. Upstreamactionпродолжалbootпослеfailedprehook — обязательный внешнийpreflight теперь останавливает Androidaction доегоначала.

Возможныйsoftwareобход отвергнут доисполнения. ActualsignedMASTER29classes.dex показываетAudioServiceActivity.provideFlutterEngine→AudioServicePlugin.getFlutterEngine→newFlutterEngine(applicationContext). Lockfileплагина0.18.19 SHA95f3267f3449eb5cf71c8fcf1d556f57af1e898e2dc5815fb168d1843653edb7. Flutterdelegate возвращается приhostprovidedengine доhost.getFlutterShellArgs. GenericIntentflags поэтому не доказываютsoftwarebackend в этомприложении. Это причина неприменимости обхода, НЕ доказанная причина hostSIGSEGV.

Приложения/SQLite/auth не менялись этим продолжением. Исходный пользовательский инцидент24→25 остаётсяUNKNOWN. Существующиеactual17/15P0PASS подтверждают сохранность ихfixtures, но не устраняют обязательный общийgate и не заменяютowner/liveприёмку.
