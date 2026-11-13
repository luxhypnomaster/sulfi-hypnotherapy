# №16-Г — остаток и границы

1. Настоящие Google MASTER/CLIENT и physical two-phone E2E NOT_RUN_OWNER. Controlled fixtures не подтверждают живой Google SDK и Drive. Отдельная PHONE_QA после safe candidate, без ПК/паролей/токенов.
2. Existing GAS6 untouched. Source server diagnostics patch16B не deploy. NEEDS_OWNER_GAS_DEPLOY_APPROVAL только если нужен rollout этих изменений; сначала reviewed patch/rollout/rollback из16B, не новый сервер. Текущая app protocol совместимость проверяется controlled contract, не обещанием live PASS.
3. Старые тестовые материалы владельца не требуется восстанавливать. Их forensic acquisition/ADB/reset/import не выполняются и не предлагаются. Старый16V ROOT_CAUSE остаётся UNKNOWN.
4. Опасная автоматическая orphan очистка отключена. Возможен рост места за счёт сохранённых uncertain/partial файлов; отдельный доказанный сознательный GC вне этого этапа. Нельзя лечить это auto-delete при пустой/неполной базе.
5. Same logical ID с другими аудиобайтами остаётся fail-closed ограничением принятого storage: новый ID для других bytes, никакой destructive revision migration/слияния experimentalPR43.
6. Native recording/emulator failures16V не повторяются без новой гипотезы; никаких утверждений о физическом микрофоне. G4 новый UI harness объяснён фактом launcher из старого failureXML и использует resume/explicit Home.
7. Private GitHub draft доступен только авторизованным владельцам/участникам репозитория; открытый релиз/исходники/Drive ACL не меняются. Если safe pair будет выдана, владелец может передать уже скачанную APK через Quick Share. На Google Диск APK не загружаются.
8. До финального controlled G4 gate кандидат не выдаётся. При критическом data/security или невалидном populated upgrade — BLOCKED, даже если build подписан. Фактический окончательный статус в RESULT_16G.
