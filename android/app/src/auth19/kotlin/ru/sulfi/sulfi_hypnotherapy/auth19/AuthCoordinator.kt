package ru.sulfi.sulfi_hypnotherapy.auth19

import java.net.URI
import java.net.URLEncoder
import java.security.MessageDigest
import java.security.SecureRandom
import java.util.Base64

enum class AuthState { SIGNED_OUT, RESTORING, AUTHENTICATED, REFRESHING, OFFLINE, BACKEND_UNAVAILABLE, REAUTH_REQUIRED, REVOKED }
class AuthFault(val kind: AuthState, val code: String) : Exception(code)
class AuthSession(val uid: String, val access: String, val refresh: String, val expires: Long) {
    override fun toString() = "AuthSession(REDACTED)"
}
class PendingLogin(val verifier: String, val nonce: String, val expires: Long, val expectedUid: String?) {
    override fun toString() = "PendingLogin(REDACTED)"
}
class AuthRecord(var session: AuthSession? = null, var pending: PendingLogin? = null,
    var loggedOut: Boolean = false, var epoch: Long = 0, var retryAt: Long = 0,
    var terminal: AuthState? = null) {
    override fun toString() = "AuthRecord(REDACTED)"
}
data class AuthSnapshot(val state: AuthState, val epoch: Long, val uid: String? = null, val code: String = "") {
    override fun toString() = "AuthSnapshot(${state.name}, epoch=$epoch)"
}
interface AuthStore {
    fun <T> exclusive(block: () -> T): T
    fun load(): AuthRecord
    fun save(record: AuthRecord)
}
interface AuthBackend {
    fun exchange(code: String, verifier: String): AuthSession
    fun refresh(token: String): AuthSession
    fun verify(token: String): String
    fun logout(token: String)
}

/** One native authority, shared by all engines; storage lock includes refresh IO.
 * Never sends a Supabase token to legacy GAS or assigns application MASTER roles. */
class AuthCoordinator(private val store: AuthStore, private val backend: AuthBackend,
    private val base: String, private val scheme: String, private val now: () -> Long = System::currentTimeMillis,
    private val changed: (AuthSnapshot) -> Unit = {}) {
    private fun snapshot(r: AuthRecord, state: AuthState, code: String = ""): AuthSnapshot =
        AuthSnapshot(state, r.epoch, if (state == AuthState.AUTHENTICATED) r.session?.uid else null, code).also(changed)

    fun restore(expectedUid: String? = null, rejectedAccess: String? = null): AuthSnapshot = store.exclusive {
        val r = store.load()
        if (r.loggedOut) return@exclusive snapshot(r, AuthState.SIGNED_OUT)
        if (r.pending != null) return@exclusive snapshot(r, AuthState.REAUTH_REQUIRED, "LOGIN_PENDING")
        r.terminal?.let { return@exclusive snapshot(r, it, "SESSION_TERMINATED") }
        val current = r.session ?: return@exclusive snapshot(r, AuthState.SIGNED_OUT)
        if (expectedUid != null && current.uid != expectedUid) return@exclusive snapshot(r, AuthState.REAUTH_REQUIRED, "OWNER_MISMATCH")
        if (r.retryAt > now()) return@exclusive snapshot(r, AuthState.BACKEND_UNAVAILABLE, "RETRY_LATER")
        snapshot(r, AuthState.RESTORING)
        try {
            // A second engine holding an old rejected access token reuses the
            // newly rotated credential instead of rotating refresh a second time.
            var refresh = current.expires <= now() + 60_000 || rejectedAccess != null && rejectedAccess == current.access
            var session = current
            if (!refresh) {
                try {
                    if (backend.verify(session.access) != current.uid) throw AuthFault(AuthState.REAUTH_REQUIRED, "OWNER_MISMATCH")
                } catch (e: AuthFault) {
                    if (e.code == "ACCESS_REJECTED") refresh = true else throw e
                }
            }
            if (refresh) {
                snapshot(r, AuthState.REFRESHING)
                session = backend.refresh(current.refresh)
                if (session.uid != current.uid || session.expires <= now()) throw AuthFault(AuthState.REAUTH_REQUIRED, "OWNER_MISMATCH")
                // Save rotated token before a subsequent user-check can fail on
                // network. It is not yet an authenticated/usable lease.
                r.session = session; r.epoch++; store.save(r)
                if (backend.verify(session.access) != current.uid) throw AuthFault(AuthState.REAUTH_REQUIRED, "OWNER_MISMATCH")
            }
            r.retryAt = 0; store.save(r)
            snapshot(r, AuthState.AUTHENTICATED)
        } catch (e: AuthFault) {
            when (e.kind) {
                AuthState.REVOKED, AuthState.REAUTH_REQUIRED -> {
                    r.terminal = e.kind; r.epoch++; r.session = null
                }
                else -> r.retryAt = now() + 5_000
            }
            store.save(r); snapshot(r, e.kind, e.code)
        }
    }

    fun beginLogin(switchAccount: Boolean = false): String = store.exclusive {
        val r = store.load()
        if (r.pending?.expires?.let { it > now() } == true) throw AuthFault(AuthState.REAUTH_REQUIRED, "LOGIN_ALREADY_PENDING")
        val random = SecureRandom()
        fun randomText(): String = Base64.getUrlEncoder().withoutPadding().encodeToString(ByteArray(48).also(random::nextBytes))
        val pending = PendingLogin(randomText(), randomText(), now() + 600_000, if (switchAccount) null else r.session?.uid)
        r.pending = pending; r.epoch++; r.loggedOut = false; store.save(r)
        snapshot(r, AuthState.REAUTH_REQUIRED, "EXPLICIT_PICKER")
        val challenge = Base64.getUrlEncoder().withoutPadding().encodeToString(MessageDigest.getInstance("SHA-256").digest(pending.verifier.toByteArray(Charsets.US_ASCII)))
        val redirect = "$scheme://oauth/callback?state=${pending.nonce}"
        val params = linkedMapOf("provider" to "google", "redirect_to" to redirect,
            "code_challenge" to challenge, "code_challenge_method" to "s256", "prompt" to "select_account")
        base + "/auth/v1/authorize?" + params.entries.joinToString("&") { it.key + "=" + URLEncoder.encode(it.value, "UTF-8") }
    }

    fun completeLogin(callback: String): AuthSnapshot = store.exclusive {
        val r = store.load(); val pending = r.pending ?: throw AuthFault(AuthState.REAUTH_REQUIRED, "NO_PENDING_LOGIN")
        val uri = try { URI(callback) } catch (_: Exception) { throw AuthFault(AuthState.REAUTH_REQUIRED, "INVALID_CALLBACK") }
        if (uri.scheme != scheme || uri.host != "oauth" || uri.path != "/callback" || uri.fragment != null || uri.userInfo != null || uri.port != -1 || callback.length > 8192)
            throw AuthFault(AuthState.REAUTH_REQUIRED, "INVALID_CALLBACK")
        val parts = uri.rawQuery.orEmpty().split('&').filter { it.isNotEmpty() }.map {
            val kv = it.split('=', limit = 2)
            java.net.URLDecoder.decode(kv[0], "UTF-8") to java.net.URLDecoder.decode(kv.getOrElse(1) { "" }, "UTF-8")
        }
        if (parts.map { it.first }.distinct().size != parts.size) throw AuthFault(AuthState.REAUTH_REQUIRED, "INVALID_CALLBACK")
        val q = parts.toMap()
        if (q["state"] != pending.nonce || pending.expires <= now()) throw AuthFault(AuthState.REAUTH_REQUIRED, "CALLBACK_STATE_MISMATCH")
        if (q["error"] != null) {
            r.pending = null; store.save(r)
            return@exclusive snapshot(r, AuthState.REAUTH_REQUIRED, "LOGIN_CANCELLED")
        }
        val code = q["code"]?.takeIf { it.isNotBlank() && it.length <= 4096 } ?: throw AuthFault(AuthState.REAUTH_REQUIRED, "CODE_MISSING")
        try {
            val session = backend.exchange(code, pending.verifier)
            if (pending.expectedUid != null && session.uid != pending.expectedUid) throw AuthFault(AuthState.REAUTH_REQUIRED, "OWNER_MISMATCH")
            if (session.expires <= now()) throw AuthFault(AuthState.REAUTH_REQUIRED, "SESSION_EXPIRED")
            r.session = session; r.pending = null; r.loggedOut = false; r.terminal = null; r.epoch++
            store.save(r) // Preserve exchanged credentials across a /user outage.
            // Exchange grants no authority until server-side /user is checked.
            if (backend.verify(session.access) != session.uid) throw AuthFault(AuthState.REAUTH_REQUIRED, "OWNER_MISMATCH")
            r.session = session; r.pending = null; r.loggedOut = false; r.terminal = null; r.retryAt = 0; r.epoch++
            store.save(r); snapshot(r, AuthState.AUTHENTICATED)
        } catch (e: AuthFault) {
            if (e.kind == AuthState.OFFLINE || e.kind == AuthState.BACKEND_UNAVAILABLE) r.retryAt = now() + 5_000
            if (e.kind == AuthState.REVOKED) { r.terminal = AuthState.REVOKED; r.session = null }
            r.pending = null; r.epoch++; store.save(r)
            snapshot(r, e.kind, e.code)
        }
    }

    fun cancelLogin(): AuthSnapshot = store.exclusive {
        val r = store.load(); r.pending = null; r.epoch++; store.save(r)
        snapshot(r, AuthState.REAUTH_REQUIRED, "LOGIN_CANCELLED")
    }

    fun logout(): AuthSnapshot = store.exclusive {
        val r = store.load(); val token = r.session?.access
        r.loggedOut = true; r.pending = null; r.session = null; r.terminal = null; r.retryAt = 0; r.epoch++
        store.save(r) // Tombstone first; remote failure must never resurrect.
        if (token != null) try { backend.logout(token) } catch (_: AuthFault) { /* local remains signed out */ }
        snapshot(r, AuthState.SIGNED_OUT)
    }

    fun lease(expectedUid: String): Map<String, Any> {
        require(expectedUid.isNotBlank())
        val result = restore(expectedUid)
        if (result.state != AuthState.AUTHENTICATED) throw AuthFault(result.state, result.code.ifBlank { "WAITING_AUTH" })
        return store.exclusive {
            val r = store.load(); val s = r.session
            if (r.epoch != result.epoch || r.loggedOut || r.pending != null || r.terminal != null || s == null || s.uid != expectedUid || s.expires <= now())
                throw AuthFault(AuthState.REAUTH_REQUIRED, "OWNER_OR_EPOCH_CHANGED")
            mapOf("uid" to s.uid, "accessToken" to s.access, "expiresAt" to s.expires, "epoch" to r.epoch, "provider" to "SUPABASE_STAGING_ONLY")
        }
    }
}
