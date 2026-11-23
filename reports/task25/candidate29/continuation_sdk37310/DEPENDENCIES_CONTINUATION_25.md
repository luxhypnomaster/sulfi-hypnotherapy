# №25 — зависимости и точные исходники

Приложения по-прежнему собраны из737ea741636e9abe7c20353d9d5b8301cf44a5bb; текущийкодQA bf9818624b2a652724850d5d35d7e941ac82421f. Документальные коммиты после него не меняют эти runtime bytes.

|PR|Head SHA|База|Состояние|
|---|---|---|---|
|51|`a7c29a7b478b6c3b001d70d3158b4a65d57b3c50`|feat/task19-auth-stage01|OPEN DRAFT UNMERGED|
|52|`40b7c59e67921f456c3c5a4e943bd40f7232f336`|feat/task20-catalog-vitrine|OPEN DRAFT UNMERGED|
|54|`ff32a0f86b8fe9c5ffe7e75406d8b3291471d9c2`|feat/task21-runtime-sandbox|OPEN DRAFT UNMERGED|
|55|`85fa5321c043ef97b43cb30a88a0909e7edf66f2`|feat/task22-server-ratings-admin|OPEN DRAFT UNMERGED|
|56|`d0a6d9a6daaeca215992e0b771a2332502ecee41`|feat/task23-data-integrity-native-qa|OPEN DRAFT UNMERGED|
|57|`bf9818624b2a652724850d5d35d7e941ac82421f`|feat/task24-local-ux-navigation|OPEN DRAFT UNMERGED|

Protected main ef32862e07f5da07b610d29c721677b27ce1704e содержит узкие operationalQA PR70–75. Приложение/stack не объединялись. PR76 закрыт безmerge/dispatch послеsource/actualDEXpreflight. ОбычныеPR/readback, безforcepush/изменениязащиты.

335protected/31nativepins и ancestry21/22/23/24/PR56 PASS. lib/android/server/third_party/assets равны замороженнойбазе. Клиентскиеэкспериментальные21/22/Auth19flags остаютсяOFF. GAS6/liveAPI/roles/OAuth/ACL не менялись и новымphysicalPASS необъявлены.
