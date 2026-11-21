# Последующие разрешения и точные STOP-гейты №21

В этом цикле никаких владельческих действий не требуется для уже выполненных локальных тестов и draft PR. Ни одно из перечисленных ниже действий НЕ выполнено и НЕ разрешено автоматически.

1. **Production metadata binding:** сначала отдельный проверяемый diff к выбранному хранилищу/существующему Router, административный readback точного Script/deployment/version, proof текущих ACL/scope mapping и atomic HEAD+receipt/CAS/rollback. Только после review — отдельное разрешение владельца на exact apply/deploy; SQLite sandbox нельзя просто объявить GAS adapter. GAS6 пока не менять.
2. **Runtime enable:** SULFI_METADATA_V1 оставлять OFF. Отдельный staged opt-in с реальной проверкой capability/Google/roles/expiry и двумя тестовыми аккаунтами, затем решение о production-переключении. Новые IAM grants/OAuth/ACL здесь не создавать.
3. **Нативная пара:** пригодный runner с достаточным диском/памятью и прежним защищённым signing secret. Не создавать новый debug key. После exact-source native compile, независимого SHA/certificate/package/versionCode readback и update retention gate — отдельное согласование нового номера сборки/ограниченной выдачи. APK28 не заменять, пока эта цепочка не выполнена.
4. **Два телефона:** только проверенную будущую пару владелец добровольно устанавливает штатным обновлением, без удаления/очистки. Следовать OWNER_PHONE_QA_21. Телефон/аккаунты пользователя из Codex не менять.
5. **Git merge / Drive sharing / CI billing:** отдельные решения владельца; draft PR52 не merge, main/ACL/billing не менять и не обходить.

