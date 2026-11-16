package ru.sulfi.sulfi_hypnotherapy.auth19

import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayInputStream
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.URL
import java.security.cert.Certificate
import javax.net.ssl.HttpsURLConnection

class ControlledHttps(url:URL, private val status:Int, private val body:String) : HttpsURLConnection(url) {
    val sent=ByteArrayOutputStream()
    override fun getResponseCode()=status
    override fun getInputStream()=ByteArrayInputStream(body.toByteArray())
    override fun getErrorStream()=ByteArrayInputStream(body.toByteArray())
    override fun getOutputStream()=sent
    override fun connect() {}
    override fun disconnect() {}
    override fun usingProxy()=false
    override fun getCipherSuite()="CONTROLLED_NO_REAL_TLS"
    override fun getLocalCertificates():Array<Certificate>?=null
    override fun getServerCertificates():Array<Certificate> = emptyArray()
}
class SupabaseRestTest {
    @Test fun googleIdentityMustComeFromServerManagedIdentitiesNotMetadata() {
        fault(AuthState.REAUTH_REQUIRED,"GOOGLE_PROVIDER_REQUIRED") {
            backend(200,"""{"id":"controlled-A","user_metadata":{"provider":"google","role":"MASTER"}}""").verify("controlled")
        }
        assertEquals("controlled-A",backend(200,"""{"id":"controlled-A","identities":[{"provider":"google"}],"role":"MASTER"}""").verify("controlled"))
    }
    private var connection:ControlledHttps?=null
    private fun backend(status:Int,body:String)=SupabaseRest("https://abcdefghijklmnopqrst.supabase.co","sb_publishable_controlled19") {
        ControlledHttps(it,status,body).also { c->connection=c }
    }
    private fun fault(expected:AuthState,code:String,action:()->Unit) {
        try { action();fail("Expected bounded auth failure") } catch(e:AuthFault){assertEquals(expected,e.kind);assertEquals(code,e.code)}
    }
    @Test fun rejectedAccessIsEligibleForSingleRefresh() {
        fault(AuthState.REAUTH_REQUIRED,"ACCESS_REJECTED") { backend(401,"{}").verify("controlled-access") }
    }
    @Test fun serverAndRateLimitFailuresDoNotParseHtmlOrRevoke() {
        for(status in listOf(500,503,429)) fault(AuthState.BACKEND_UNAVAILABLE,"AUTH_BACKEND_UNAVAILABLE") { backend(status,"<html>not JSON</html>").verify("controlled") }
    }
    @Test fun redirectsNeverReceiveBearerAndRequestsAreTimeBounded() {
        fault(AuthState.BACKEND_UNAVAILABLE,"AUTH_BACKEND_UNAVAILABLE") { backend(302,"{}").verify("controlled") }
        assertFalse(connection!!.instanceFollowRedirects);assertEquals(10000,connection!!.connectTimeout);assertEquals(15000,connection!!.readTimeout)
        assertEquals("abcdefghijklmnopqrst.supabase.co",connection!!.url.host)
    }
    @Test fun refreshUsesOfficialGrantAndIgnoresApplicationRoleClaims() {
        val b=backend(200,"""{"access_token":"controlled-next","refresh_token":"controlled-rotated","expires_in":3600,"user":{"id":"11111111-1111-4111-8111-111111111111","role":"MASTER"}}""")
        val s=b.refresh("controlled-old");assertEquals("controlled-rotated",s.refresh)
        assertEquals("grant_type=refresh_token",connection!!.url.query);assertTrue(connection!!.sent.toString().contains("controlled-old"))
        assertFalse(s.toString().contains("MASTER"));assertFalse(s.toString().contains("controlled-rotated"))
    }
    @Test fun explicitProviderRevocationIsTerminal() {
        fault(AuthState.REVOKED,"SESSION_REVOKED") { backend(400,"""{"error_code":"refresh_token_already_used"}""").refresh("controlled") }
    }
    @Test fun responseSizeIsBoundedWithoutLoggingBody() {
        fault(AuthState.BACKEND_UNAVAILABLE,"AUTH_RESPONSE_TOO_LARGE") { backend(200,"x".repeat(262145)).verify("controlled") }
    }
    @Test fun networkFailureIsOfflineNotLogout() {
        val b=SupabaseRest("https://abcdefghijklmnopqrst.supabase.co","sb_publishable_controlled19") {throw IOException("synthetic sensitive diagnostic")}
        fault(AuthState.OFFLINE,"AUTH_NETWORK_UNAVAILABLE") { b.verify("controlled") }
    }
}
