package ru.sulfi.sulfi_hypnotherapy.auth19

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Test
import org.junit.runner.RunWith
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicInteger

/** Real Android Keystore/files, controlled backend. NEVER Google/phone proof. */
@RunWith(AndroidJUnit4::class)
class Auth19NativeTest {
    private val context get() = InstrumentationRegistry.getInstrumentation().targetContext
    private val uid = "11111111-1111-4111-8111-111111111111"
    private fun store() = SecureSessionStore(context, "controlled-native19")
    private val refreshCount = AtomicInteger()
    private fun backend() = object : AuthBackend {
        override fun exchange(code:String,verifier:String):AuthSession = error("No interactive flow in native controlled test")
        override fun refresh(token:String):AuthSession { refreshCount.incrementAndGet();Thread.sleep(80);return AuthSession(uid,"controlled-access-native19","controlled-refresh-native19",System.currentTimeMillis()+3_600_000) }
        override fun verify(token:String) = uid
        override fun logout(token:String) {}
    }
    private fun coordinator(s:AuthStore) = AuthCoordinator(s,backend(),"https://abcdefghijklmnopqrst.supabase.co","sulfiauth19master")
    @Test fun persistAndConcurrentRotate() {
        assertTrue(context.packageName.endsWith(".auth19"))
        val s=store();s.exclusive { s.save(AuthRecord(AuthSession(uid,"controlled-expired","controlled-refresh-before19",System.currentTimeMillis()-1))) }
        val pool=Executors.newFixedThreadPool(8)
        try {
            val results=(1..24).map { pool.submit<AuthSnapshot> { coordinator(store()).restore() } }
            results.forEach { assertEquals(AuthState.AUTHENTICATED,it.get(10,TimeUnit.SECONDS).state) }
            assertEquals(1,refreshCount.get())
        } finally { pool.shutdownNow() }
        val bytes=context.noBackupFilesDir.resolve("auth19-controlled-native19/session.aesgcm").readBytes()
        assertFalse(String(bytes,Charsets.ISO_8859_1).contains("controlled-refresh-native19"))
        assertFalse(String(bytes,Charsets.ISO_8859_1).contains(uid))
        assertTrue(context.databaseList().isEmpty())
        println("AUTH19_NATIVE_RECEIPT={\"phase\":\"PERSIST_AND_ROTATE\",\"pid\":${android.os.Process.myPid()},\"refreshes\":1,\"encrypted\":true,\"Google\":\"NOT_RUN\"}")
    }
    @Test fun coldRestoreAndLogout() {
        val c=coordinator(store());assertEquals(AuthState.AUTHENTICATED,c.restore().state);assertEquals(0,refreshCount.get())
        assertEquals(uid,c.lease(uid)["uid"])
        try { c.lease("22222222-2222-4222-8222-222222222222");fail("wrong owner lease") } catch(e:AuthFault){assertEquals("OWNER_MISMATCH",e.code)}
        assertEquals(AuthState.SIGNED_OUT,c.logout().state);assertEquals(AuthState.SIGNED_OUT,coordinator(store()).restore().state)
        assertTrue(context.databaseList().isEmpty())
        println("AUTH19_NATIVE_RECEIPT={\"phase\":\"COLD_RESTORE_LOGOUT\",\"pid\":${android.os.Process.myPid()},\"refreshes\":0,\"logoutTombstone\":true,\"Google\":\"NOT_RUN\"}")
    }
}
