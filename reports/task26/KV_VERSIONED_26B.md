# №26-Б v1.0 — контрольные точки

## B0 — PASS READ_ONLY (26.11.2026)

- PR77 OPEN DRAFT, точный head23ab5df2895c7ff1ca413c16f2e7352f772edae4; basefeat/task22-server-ratings-admin. Рабочая ветка восстановлена изкоммита послеутратыRAM, безreset/переписыванияветки; чужиеworktrees/файлы не затронуты.
- Preflight19:42UTC: HOBBY ACTIVE/NOT_REQUIRED; exactworkspace/project/service/Production-as-STAGING/active deployment/composition/SQL/2Functions совпали сзакрытымпаспортом. FINISHED/SUCCEEDED/activeEverywhere. SQLobserved/desiredstopped. Никакихresource mutations/nativeHTTPзапросов.
- Live sourcepin1ad664552af20ec06e2e077f2aea051e243165e4,curatedeb7056dab8f104402e28dd6972d15c8629766ba2; deploymentветкасовпала. Previousworkingreleaseсохранёнвowner-onlyпаспорте.
- Docs26.11: native list(options:{prefix,limit,cursor}) →{keys,cursor}; limitbackendcap1000. get/delete описаны; setбезttl иttl0 документированы какнеистекающие. ЭтоDOCUMENTED,пока неLIVE capabilityPASS.
- Compute globalno-wake UNVERIFIABLE: известныйservingreadback показываетrelease, несонвсехпроцессов. SQLcontrolplane даётточечныйobservedstate. До/послеstoppedнебудетполнымPASS; закрытыеAPI неищем. B3допускаетодинFunctionreadсчестнымPARTIAL.
- НоваяденежнаястоимостьPENDING; existingownerUIbaselineизпрофилянеявляетсяновымAPIзамером. БезэкстраполяцийилиугадыванияквотыCodex. Новыересурсы/тарифы/idle не меняются.

ДалееB1: единственныйнеобходимыйcodedeploy существующегоprotectedprobe; отдельныйсинтетическийrunjournal доnativewrite. GuardsреальногоHEAD/reader/publisher неослаблять. Max5keysодновременно/max30nativeHTTP; B4cleanup/closureобязательны.
