# №17 G0 — доказанная кодовая причина и границы

База: source25ecdf984a831a288bf85e14119a5e054144ccf9, APK26producer9b94f24f3e5302c20a96dce5a2e7bdc074c21a1c. PR47 draft/unmerged; новаяветкаfix/task17-stable-auth-queue. Пакет10files/9manifestSHA/67criteria подтверждён,ZIP SHA6572591bb71d73ba8a0de8e41f1a323da3bd1ea026f2e06a1030af5de69c92eb.

## Два RED воспроизведения до изменения поведения

1. AlchemistQueueIndicator.didChangeAppLifecycleState → cloudQueue.pauseAll → pause(name) выставляет USER_PAUSED независимо от участия человека. DiaryController.signInAuthor также вызывает onAccountLogout до нового выбора; SessionController callback снова вызывает pauseAll. Если событие приходит между durable enqueue и pump, _stops=true проверяется до увеличения attempts, HTTP не вызывается. task17_root_cause_test: sent0/attempts0, ожидание LIFECYCLE_PAUSED, фактически USER_PAUSED. Это воспроизводимый путь «система остановила до транспорта», не сбой GAS.
2. AlchemistApi.call захватывает originalScope до await credential, но verifiedIdentityToken может выполнить silent restore: scope public→account, generation прежняя. checkScope ошибочно выбрасывает ACCOUNT_CHANGED до первого HTTP. task17_root_cause_test: ожидался1запрос, фактическиauthorizationexception изcall.checkScope. Смена уже известного subject и explicit logout должны оставаться запрещены: новый тест их не разрешает.
3. Queue.enqueue возвращает void без результата, в том числе при _activeName==name иqueued/running+_running. UI не может отличить принятый Resume от пропуска. Конкретные race нуждаются в дополнительном controlled доказательстве вG2; не объявлено единственным физическим rootcause.
4. UI diary/store/server-authorization опирается на кратковременный readerAuthenticated. При истёкшем RAMcredential кнопка показывает вход и signInAuthor вызывает interactive SDK без предварительного silent restore. Это кодовый путь повторного picker; точные15минут/GoogleSDKнаустройствеNOT_RUN. AlchemistIdentitySession fallback не является текущим server-identity путем — не переписывать его как мнимую причину.
5. Google ownerBinding уже SHA(endpoint|scope), scope SHA(endpoint+server-verifiedsub). Это НЕ token hash и НЕ email; не менять существующие значения ради нового алгоритма.
6. Offline MASTER workspace требует api.verifiedRole==MASTER; без SDK restore он скрыт. Личные несвязанные локальные drafts и приватные server-subject drafts нужно различать; нельзя открыть все существующие drafts публичным fallback.
7. Версия0.4.12+17 hardcoded вspace_sheet.dart. Это дефект надписи, не доказательство downgrade/data migration.

## Карта единой identity

GoogleDiaryIdentity → DiaryController → AlchemistDiaryApi.bindIdentity/restoreIdentity/_verifyIdentity(auth.whoami) → serververifiedsubject/role/readerScope. SessionController.alchemistApi и author adapter используют этот жеcredential/scope/epoch. Дневник, editor, каталогpersonal/public, module/program publisher, CLIENTinstaller используют этотконтроллер; независимые OAuthbackend не обнаружены. UI static credential selection в public store при открытии до восстановления может показывать login до возврата издневника. Same-owner Resume обязан сначала подтвердить identity/role, затемtaskowner; рольMASTERсама по себе неравнасовпадениюowner.

## Исторический LIVE и новая диагностика

Одна текстово-графическая diarypublication MASTER26→CLIENT25 действительно получена по записи владельца в актуальномпаспорте; этоне catalog installPASS. Фраза«Добавьсебевбиблиотеку» — авторскийтекст,неCTA. Остальныеэпизоды безживойтрассы нельзяоднозначносопоставитьодномуrootcause. НовыйQAtraceopt-in/RAM200events/TTL20мин/exportexplicit,безtokens/sub/email/URLs/payload; ownerEqualboolean. Старые№16отчётысохранены.

Live read-only GET?op=serverVersion:HTTP200, source1a0cf8e5a60144075eec793767953586bfa319a2,policy2,fullSourceReadytrue. Историческийdeploy43036540579 подтверждалversion6 этогоsource. Числовойcurrentdeploymentversion endpointнеотдаёт; считатьcurrentversion6свереннымпоисточнику/истории,административныйdeploymentreadbackотдельноNOT_RUN. Никакогоdeploy/bootstrap/ACLchanges.

G1 additionalconfirmedSDKpath:upstreamgoogle_sign_in_android7.2.18 attemptLightweightAuthentication firstauthorized/autoselect thenfallbackfilterToAuthorized:false/autoselect:false. This canpresentpickerfromautomaticrestore. Narrowpinnedfork removesonlysecondfallback,explicitauthenticateunchanged;nativeCredentialManagerstillneedsphysicalGoogleQA. G1controlled13PASS includinglogoutintent/coldhint/lateSDKcompletion/offlinelocaldraft/otherownerdeny. Serveridentityhints(scopehash+lastrole)arelocalreadmetadataonly,notcredentials/nocloudpermission. Explicitlogoutdisablepersisted;SDKtokensremainRAM. Legacyprivate scopesandaliasunchanged. Fullidentity/accountswitchHTTPnegativeexistingregressionspreserved.
