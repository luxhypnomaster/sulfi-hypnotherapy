# №19 G1 — единый координатор сессий

Dart AuthCoordinator → MethodChannel → Auth19Platform → native AuthCoordinator → SecureSessionStore + SupabaseRest. SOURCE: lib/auth19/auth_coordinator.dart; lib/main_auth19.dart; android/app/src/auth19/kotlin/ru/sulfi/sulfi_hypnotherapy/auth19/.

Один native executor на процесс обслуживает все Flutter engines. AuthStore.exclusive держит ReentrantLock по canonical install/project path и FileChannel.lock для процессов. Refresh→save находится в той же критической секции. Это отдельная маленькая auth-операция, не глобальный GAS/transfer lock. UI thread не блокируется. Никаких независимых Dart timers или SDK auto-refresh.

| Состояние | Поведение |
|---|---|
| SIGNED_OUT | Нет credentials либо сохранён explicit logout; silent restore не отменяет logout |
| RESTORING | Хранилище само по себе ещё не авторизация |
| AUTHENTICATED | /user подтверждает тот же uid; future worker получает bounded access lease |
| REFRESHING | Один broker обновляет refresh; старая rejected access fingerprint не вызывает вторую rotation |
| OFFLINE | Credential сохранён, bounded retry; picker не вызывается |
| BACKEND_UNAVAILABLE | 503/429/redirect/invalid response — сохранить состояние, не logout |
| REAUTH_REQUIRED | Ошибка авторизации/owner/callback требует явного действия, не auto picker |
| REVOKED | Подтверждённый terminal provider error; старые данные не удаляются |

File: noBackupFilesDir/auth19-PROJECT/session.aesgcm, Android Keystore AES-GCM random IV + AtomicFile/fsync. Не SQLite, не legacy preferences. Refresh токен не возвращается в Dart. Store.decrypt failure сохраняет ciphertext и возвращает ошибку, не создаёт пустую библиотеку. Provider response и local save не образуют общую distributed transaction: crash после remote rotation остаётся реальным окном; parent/reuse recovery зависит от Supabase policy, а не обещается навсегда. Revocation фиксируется честно.

Authority epoch меняется при explicit login/switch/cancel/logout, **не при same-owner refresh**. Callback nonce/verifier/TTL зашифрованы; PKCE S256, strict scheme/host/path/no fragment/duplicate query, replay denied. beginLogin — только явное UI-действие; pending login запрещает второй intent до cancel/expiry. Browser cancel имеет отдельную кнопку отмены.

attachWorker(Context,BinaryMessenger) — отдельная headless регистрация прототипа, разрешены initialize/restore/lease только с expectedUid. Нет chooser/logout из worker. workerLease(expectedUid, expectedEpoch) отклоняет другой аккаунт и старую authority generation; каждый будущий private RPC обязан заново проверить lease, не бесконтрольно кешировать bearer. На logout уже отправленный HTTP нельзя отозвать, но новые leases запрещены. Local logout вызывает /logout?scope=local, не выход всех устройств.

**Не подключено к GAS/реальной очереди №18**: это запрещённый пока G3. Старый transferMain/Keystore Google lease/owner scope/SQLite полностью сохранены. Существующие tasks нельзя автоматически заменить Supabase UID; отсутствие legacy proof означает WAITING_AUTH, не присвоение новому аккаунту. Staging access lease имеет provider=SUPABASE_STAGING_ONLY и не является Google credential.

Dart onAuthStateChange имеет onError: ошибка stream→BACKEND_UNAVAILABLE без очистки credential. initialize не запускает protected operations до verified ready. Два пакета .auth19 получают разные UID/Keystore/noBackup storage, но могут в будущем пройти Google одним человеком; реальное совпадение Supabase UID на2устройствах NOT_RUN.
