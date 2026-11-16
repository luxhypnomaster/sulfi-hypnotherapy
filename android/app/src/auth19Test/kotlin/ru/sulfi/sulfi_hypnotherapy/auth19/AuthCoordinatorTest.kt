package ru.sulfi.sulfi_hypnotherapy.auth19

import org.junit.Assert.*
import org.junit.Test
import java.net.URI
import java.net.URLDecoder
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger
import java.util.concurrent.locks.ReentrantLock

class MemoryAuthStore : AuthStore {
    private val lock = ReentrantLock()
    private var value = AuthRecord()
    override fun <T> exclusive(block: () -> T): T { lock.lock(); try { return block() } finally { lock.unlock() } }
    override fun load() = AuthRecord(value.session, value.pending, value.loggedOut, value.epoch, value.retryAt, value.terminal)
    override fun save(record: AuthRecord) { value = AuthRecord(record.session, record.pending, record.loggedOut, record.epoch, record.retryAt, record.terminal) }
}
class FakeAuthBackend(private val clock: () -> Long) : AuthBackend {
    val refreshes = AtomicInteger()
    var verifyFailure: AuthFault? = null
    var refreshFailure: AuthFault? = null
    var logoutFailure: AuthFault? = null
    var verifyUid = "account-A"
    var exchangeUid = "account-A"
    var rejectAccessOnce = false
    override fun exchange(code: String, verifier: String) = AuthSession(exchangeUid, "access-new", "refresh-new", clock() + 3_600_000)
    override fun refresh(token: String): AuthSession {
        refreshes.incrementAndGet(); refreshFailure?.let { throw it }; Thread.sleep(15)
        return AuthSession("account-A", "access-rotated", "refresh-rotated", clock() + 3_600_000)
    }
    override fun verify(token: String): String {
        verifyFailure?.let { throw it }
        if (rejectAccessOnce) { rejectAccessOnce = false; throw AuthFault(AuthState.REAUTH_REQUIRED, "ACCESS_REJECTED") }
        return verifyUid
    }
    override fun logout(token: String) { logoutFailure?.let { throw it } }
}
class AuthCoordinatorTest {
    private var time = 10_000_000L
    private val store = MemoryAuthStore()
    private val backend = FakeAuthBackend { time }
    private fun coordinator() = AuthCoordinator(store, backend, "https://abcdefghijklmnopqrst.supabase.co", "sulfiauth19master", { time })
    private fun seed(expired: Boolean = false) { store.save(AuthRecord(AuthSession("account-A", "access-old", "refresh-old", time + if (expired) -1 else 3_600_000))) }
    private fun callback(url: String): String {
        val q = URI(url).rawQuery.split('&').associate { val p=it.split('=',limit=2); p[0] to URLDecoder.decode(p[1],"UTF-8") }
        return q.getValue("redirect_to") + "&code=synthetic-one-use-code"
    }
    @Test fun coldStartVerifiesStoredCredentialWithoutGooglePicker() {
        seed(); assertEquals(AuthState.AUTHENTICATED, coordinator().restore().state)
        assertEquals(AuthState.AUTHENTICATED, coordinator().restore().state); assertEquals(0, backend.refreshes.get())
    }
    @Test fun twoEnginesConcurrentExpiryRotateExactlyOnce() {
        seed(true); val pool = Executors.newFixedThreadPool(8)
        try {
            val runs = (1..32).map { pool.submit<AuthSnapshot> { coordinator().restore() } }
            runs.forEach { assertEquals(AuthState.AUTHENTICATED, it.get(5, TimeUnit.SECONDS).state) }
            assertEquals(1, backend.refreshes.get()); assertEquals("refresh-rotated", store.load().session!!.refresh)
        } finally { pool.shutdownNow() }
    }
    @Test fun unauthorizedAccessRefreshesBeforeReauth() {
        seed(); backend.rejectAccessOnce = true
        assertEquals(AuthState.AUTHENTICATED, coordinator().restore().state); assertEquals(1, backend.refreshes.get())
    }
    @Test fun secondEngineWithOldRejectedAccessDoesNotRotateAgain() {
        seed(); val first = coordinator(); val second = coordinator()
        assertEquals(AuthState.AUTHENTICATED, first.restore(rejectedAccess="access-old").state)
        assertEquals(AuthState.AUTHENTICATED, second.restore(rejectedAccess="access-old").state)
        assertEquals(1, backend.refreshes.get())
    }
    @Test fun backend503AndBusyKeepCredentialsAndBoundedRetry() {
        seed(); backend.verifyFailure = AuthFault(AuthState.BACKEND_UNAVAILABLE,"AUTH_BACKEND_UNAVAILABLE")
        assertEquals(AuthState.BACKEND_UNAVAILABLE,coordinator().restore().state)
        assertEquals("refresh-old",store.load().session!!.refresh); assertFalse(store.load().loggedOut)
        assertEquals("RETRY_LATER",coordinator().restore().code); backend.verifyFailure=null;time+=5100
        assertEquals(AuthState.AUTHENTICATED,coordinator().restore().state)
    }
    @Test fun networkTimeoutIsNotLogout() {
        seed(); backend.verifyFailure=AuthFault(AuthState.OFFLINE,"AUTH_NETWORK_UNAVAILABLE")
        assertEquals(AuthState.OFFLINE,coordinator().restore().state); assertNotNull(store.load().session)
    }
    @Test fun revokedRefreshIsPersistentlyRevoked() {
        seed(true);backend.refreshFailure=AuthFault(AuthState.REVOKED,"SESSION_REVOKED")
        assertEquals(AuthState.REVOKED,coordinator().restore().state);backend.refreshFailure=null
        assertEquals(AuthState.REVOKED,coordinator().restore().state);assertNull(store.load().session)
    }
    @Test fun explicitLocalLogoutWinsEvenWhenServerUnavailable() {
        seed();backend.logoutFailure=AuthFault(AuthState.BACKEND_UNAVAILABLE,"AUTH_BACKEND_UNAVAILABLE")
        assertEquals(AuthState.SIGNED_OUT,coordinator().logout().state)
        assertEquals(AuthState.SIGNED_OUT,coordinator().restore().state);assertTrue(store.load().loggedOut)
    }
    @Test fun workerBoundToANeverGetsBOrRefreshesB() {
        store.save(AuthRecord(AuthSession("account-B","b-access","b-refresh",time+3_600_000)))
        try { coordinator().lease("account-A");fail("Cross-account lease") } catch(e:AuthFault){ assertEquals("OWNER_MISMATCH",e.code) }
        assertEquals(0,backend.refreshes.get())
    }
    @Test fun rotatedCredentialSurvivesUserEndpointOutage() {
        seed(true);backend.verifyFailure=AuthFault(AuthState.BACKEND_UNAVAILABLE,"AUTH_BACKEND_UNAVAILABLE")
        assertEquals(AuthState.BACKEND_UNAVAILABLE,coordinator().restore().state)
        assertEquals("refresh-rotated",store.load().session!!.refresh);backend.verifyFailure=null;time+=5100
        assertEquals(AuthState.AUTHENTICATED,coordinator().restore().state);assertEquals(1,backend.refreshes.get())
    }
    @Test fun pkceNonceCallbackReplayAndWrongOriginDenied() {
        val c=coordinator();val url=c.beginLogin();val cb=callback(url)
        assertTrue(url.contains("code_challenge_method=s256"));assertFalse(url.contains(store.load().pending!!.verifier))
        try { c.completeLogin(cb.replace("sulfiauth19master:","attacker:"));fail() } catch(e:AuthFault){ assertEquals("INVALID_CALLBACK",e.code) }
        assertEquals(AuthState.AUTHENTICATED,c.completeLogin(cb).state)
        try { c.completeLogin(cb);fail() } catch(e:AuthFault){ assertEquals("NO_PENDING_LOGIN",e.code) }
    }
    @Test fun staleOrDuplicateStateDoesNotConsumePendingLogin() {
        val c=coordinator();val cb=callback(c.beginLogin());val pending=store.load().pending
        for(bad in listOf(cb+"&state=wrong",cb.replace(pending!!.nonce,"wrong"))) {
            try { c.completeLogin(bad);fail() } catch(_:AuthFault){}
            assertEquals(pending,store.load().pending)
        }
    }
    @Test fun oneInteractiveIntentUntilExplicitCancel() {
        val c=coordinator();c.beginLogin()
        try { c.beginLogin();fail() } catch(e:AuthFault){ assertEquals("LOGIN_ALREADY_PENDING",e.code) }
        c.cancelLogin(); assertNotNull(c.beginLogin())
    }
    @Test fun sameAccountLoginRefusesUnexpectedProviderAccount() {
        seed();val c=coordinator();val cb=callback(c.beginLogin());backend.exchangeUid="account-B"
        assertEquals("OWNER_MISMATCH",c.completeLogin(cb).code);assertEquals("account-A",store.load().session!!.uid)
    }
    @Test fun deliberateSwitchInvalidatesOldOwnerLeases() {
        seed();val c=coordinator();val cb=callback(c.beginLogin(switchAccount=true));backend.exchangeUid="account-B";backend.verifyUid="account-B"
        assertEquals(AuthState.AUTHENTICATED,c.completeLogin(cb).state)
        try { c.lease("account-A");fail() } catch(e:AuthFault){ assertEquals("OWNER_MISMATCH",e.code) }
    }
    @Test fun exchangeCredentialsAreSavedBeforeTransientUserCheck() {
        val c=coordinator();val cb=callback(c.beginLogin());backend.verifyFailure=AuthFault(AuthState.OFFLINE,"AUTH_NETWORK_UNAVAILABLE")
        assertEquals(AuthState.OFFLINE,c.completeLogin(cb).state);assertEquals("refresh-new",store.load().session!!.refresh)
        time+=5100;backend.verifyFailure=null;assertEquals(AuthState.AUTHENTICATED,coordinator().restore().state)
    }
    @Test fun snapshotsAndRecordsDoNotStringifySecretsOrUserIdentifier() {
        seed(); assertFalse(store.load().toString().contains("refresh-old"));assertFalse(store.load().session.toString().contains("access-old"))
        assertFalse(coordinator().restore().toString().contains("account-A"))
    }
}
