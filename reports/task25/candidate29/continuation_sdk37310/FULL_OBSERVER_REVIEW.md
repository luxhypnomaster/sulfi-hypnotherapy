# Полный native-gate под проверенным наблюдателем

Основание: actualrun12 дал17/17MASTER35 PASS, независимые14снимков×15таблиц/P0media совпали, самGDBконторольреальноработает, QEMUзавершился0 безединогоSIGSEGV. SameSDK run8 безнаблюдателя упалдообновления. Причинаизмененияповедения UNKNOWN; не выдаём наблюдение заисправленнуюгонкуилиproductionfix.

Наблюдатель передаёт исходные сигналы, не подавляетSIGSEGV, не перезапускаетQEMU и не восстанавливаетtestfixture. Не меняет APK, guest renderer, DB, dataset, UIgestures, coldrestart, audio или ниодин P0assertion. Поэтому пригоден для контролируемой проверки реальногоAndroid install-r и сохранности, даже приотдельном незакрытом дефектеhostэмулятора. Это не физическаяприёмка.

Узкийdiff: workflow+emulator_pc25.py. Все4nativejobs получаютодинаковыйконтролируемыйhostobserver. Остаются обеedition35, затемобе36, затемdelivery. Master-onlydiagnostic по-прежнему невыдаёт APK. Добавленобязательный дополнительный post-nativegate: finalQEMUexit0,0SIGSEGV,1AVDlaunch,0restarts, актуальныйпроверенныйGDB/scriptreceipt. Missing/unknown/fatal/restart/anySIG/failednativecases failclosed. Эксклюзивныйlaunchmarker исключаетперезаписьквитанцииповторнымAVD.

Postgate только добавляетhostObserver кJSONотчёту; testcase/inventoryполя побайтамзначенийсохраняются. Независимыйfullverifier требуетновуюboundproof; прежнийdiagnostic17PASSсампо себе новыечетырегейтанеудовлетворяет.108localtests+actionlintPASS, ASTисходныхP0неизменён. ПолныеFlutter/Nodeнеповторяются, runtime335/native31 безdrift.

No signingsecrets/build/re-sign/deploy/ACL/OAuth/userdatachanges. ТолькоordinaryprotectedmainPR,exactbase/head/hashreadback. Rollback:корректирующийPRвосстанавливаетэти2файла. НикакогообъединенияappPR51–57. После4фактическихPASS — независимаяпроверкаартефактовиитоговыйкандидатдляотдельноразрешённойphoneQA,неавтоматическаяустановка.
