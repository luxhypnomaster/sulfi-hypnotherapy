# №19 G0 — SOURCE audit, не доказанный диагноз телефона

База363a024, исходник APK28de408f1; PR49draft/PR48необъединены. №18PARTIAL: controllednative API33–36/updates PASS, realGoogle/ownerQA не подставляются. Архив19SHA/CRC/manifest PASS. Рабочее дерево19 отдельно, старые данные и процессы18 не меняются.

Call graph: SessionController.signInAlchemistReader→DiaryController.signInAuthor→AlchemistDiaryApi.restoreIdentity→GoogleDiaryIdentity.restore→google_sign_in7.2.0/Androidfork7.2.18 authorized lightweight→auth.whoami. При допустимом explicit interactive fallback DiaryController→GoogleDiaryIdentity.signIn→GoogleSignIn.authenticate. Catalogue/private API получает credential через DiaryApi. Старый AlchemistIdentitySession.token→identity.signIn используется только fallback без supportsServerIdentity; это не основной подключённый путь APK28.

ПодтвержденоSOURCE: AlchemistApi.call сначала rejectIdentity на401, затем один forced silent restore; AlchemistDiaryApi._restore(force) отвергает тот же IDtoken даже если SDK его вернул. До нового whoami _identityRejected остаётсяtrue; последующий UI может предложить interactive. Это достижимый путь к повторному picker, не доказательство конкретного триггера на телефоне.503/timeout retry отдельно; serverGoogle certificates503/BUSY/Drive lock latency не равно Google logout. Фактические owner HTTP/trace/SDK exception ещё нужны.

Fork уже убрал unauthorized-account picker fallback из lightweight; SDK не называется устаревшим. OAuth Testing/scopes/consent status в Console отсюда не подтверждены; исторические Androidpackages и SHA1 есть, текущая конфигурация не меняется.

№18 worker: TransferPlatform→Keystore encrypted expiringGooglelease→transferMain→lease epoch/network checks→auth.whoami scope/role/owner equality→existing queue. Worker не Google SDK, не picker, не Supabase refresh owner. Этот код сохраняется целиком.

Legacy sub inventory: GoogleJwt validatesGoogleiss/aud/RS256/exp/sub and servermaster subject; Router actor/auth.whoami; Access owner/reader grants; AtomicStore registry ownership; Diary author/read-state; Transfer owner/session/byRequest/idempotency; Operations audit/revisions. Local scope SHA256(alchemist:endpoint:verifiedsub), drafts google:sub legacy alias, queued scope and request/session/checkpoint. Никакой email merge/UUID substitution/row rewrite сейчас. SupabaseJWT не принимается GAS какGoogleJWT; bridgeG3BLOCKED_by_scope. SameGoogle master inside CLIENT still receives serverMASTER: localedition alone cannot enforce malicious-client security, existing contract risk noted, noGAS patch.

Выборprototype: официальный SupabaseAuth REST PKCE/S256 via browser, nativebroker single refresh owner + AndroidKeystore encrypted atomicrecord/OSfilelock; DartUI+worker readonlyboundedlease API, no second SDK auto-refresh. Separate .auth19 packages/entrypoint and flagOFF; noGAS integration untilG3. NativeGoogle+Supabase comparison prepared separately; ID+accessToken needed, currentDiaryIdentity has IDonly. CurrentOAuth/signing/packages untouched.

Official references: https://supabase.com/docs/guides/auth/sessions/pkce-flow ; https://supabase.com/docs/reference/dart/auth-signinwithidtoken ; https://supabase.com/docs/guides/auth/sessions ; https://raw.githubusercontent.com/supabase/auth/master/openapi.yaml ; https://pub.dev/packages/google_sign_in . Fetched16.11.2026. Persistent appsession does not mean perpetual validity; refresh revocation/network/crash ambiguity must be distinguished.

## Controlled reproduction и граница вывода

`test/task19_legacy_auth_audit_test.dart` PASS: generic401 и тот же SDK cached ID token временно оставляют readerAuthenticated=false; pinned scope сохраняется, interactive=0. Следующий успешный auth.whoami с тем же токеном восстанавливает доверие. Поэтому реальный телефонный trigger и неизбежность picker не установлены; не считать source candidate полным ROOT_CAUSE OWNER.
