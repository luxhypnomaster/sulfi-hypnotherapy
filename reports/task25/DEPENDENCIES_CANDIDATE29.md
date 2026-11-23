# Зависимости кандидата29

App source737ea741636e9abe7c20353d9d5b8301cf44a5bb; code/tool source5977584cfeb14d3f3222d49e45729f76fff35f47. Report snapshot dc6ecb4 (полный SHA в evidence manifest). Ни один appPR ниже не объединён вmain.

|PR|HEAD snapshot|Base|State|
|---|---|---|---|
|51|a7c29a7b478b6c3b001d70d3158b4a65d57b3c50|feat/task19-auth-stage01|OPEN DRAFT UNMERGED|
|52|40b7c59e67921f456c3c5a4e943bd40f7232f336|feat/task20-catalog-vitrine|OPEN DRAFT UNMERGED|
|54|ff32a0f86b8fe9c5ffe7e75406d8b3291471d9c2|feat/task21-runtime-sandbox|OPEN DRAFT UNMERGED|
|55|85fa5321c043ef97b43cb30a88a0909e7edf66f2|feat/task22-server-ratings-admin|OPEN DRAFT UNMERGED|
|56|d0a6d9a6daaeca215992e0b771a2332502ecee41|feat/task23-data-integrity-native-qa|OPEN DRAFT UNMERGED|
|57|5977584cfeb14d3f3222d49e45729f76fff35f47|feat/task24-local-ux-navigation|OPEN DRAFT UNMERGED|

Code ancestry21/22/23/24 иPR56 подтверждён source_gate;335runtime/31native pins без drift. Report-only родительскиеHEAD могут отличаться от кодовой точки; они не считаются автоматически merged/включёнными без source proof. Branch25 от verified PR56d0a6d9a6.

Trusted main e5b91a7e2a68c345dda12a64d079fdc1d6d365b7, только7operational paths заPR58–69. Подробности MAIN_OPERATIONAL_DIFF_25.json вarchive. Unsignedbuild main0e1d195, exact app737, actual existing-key signedpair29. Production/server/app main merge не выполнялся.

Read-only source_gate полеnativeAPK описывает только возможности самого инструмента; реальныеbinaries/native доказательства находятся отдельно вAPK_INFO/READBACK иNATIVE_UPGRADE. Ни protected=true, ни owner branchrule readback не являются доказательством технической невозможности adminbypass. Фактическая процедура — обычные узкиеPR, expectedHEAD, remotehashreadback.
