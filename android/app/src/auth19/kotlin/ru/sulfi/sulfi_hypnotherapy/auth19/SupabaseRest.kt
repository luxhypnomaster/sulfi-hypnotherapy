package ru.sulfi.sulfi_hypnotherapy.auth19

import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.URL
import javax.net.ssl.HttpsURLConnection

/** Official Supabase Auth OpenAPI PKCE/refresh/user/local-logout endpoints.
 * No Supabase SDK with a second automatic refresh timer is instantiated. */
class SupabaseRest(private val base: String, private val publishableKey: String) : AuthBackend {
    private fun request(path: String, body: JSONObject? = null, token: String? = null): JSONObject {
        val connection = URL(base + "/auth/v1/" + path).openConnection() as HttpsURLConnection
        try {
            connection.requestMethod = if (body == null) "GET" else "POST"
            connection.instanceFollowRedirects = false
            connection.connectTimeout = 10_000; connection.readTimeout = 15_000; connection.useCaches = false
            connection.setRequestProperty("apikey", publishableKey)
            connection.setRequestProperty("Content-Type", "application/json")
            token?.let { connection.setRequestProperty("Authorization", "Bearer $it") }
            if (body != null) { connection.doOutput = true; connection.outputStream.use { it.write(body.toString().toByteArray()) } }
            val status = connection.responseCode
            if (status >= 500 || status == 429 || status in 300..399) throw AuthFault(AuthState.BACKEND_UNAVAILABLE, "AUTH_BACKEND_UNAVAILABLE")
            val input = if (status in 200..299) connection.inputStream else connection.errorStream
            val raw = input?.use {
                val out = ByteArrayOutputStream(); val buffer = ByteArray(4096)
                while (true) { val n = it.read(buffer); if (n < 0) break; if (out.size() + n > 262144) throw AuthFault(AuthState.BACKEND_UNAVAILABLE, "AUTH_RESPONSE_TOO_LARGE"); out.write(buffer, 0, n) }
                out.toString("UTF-8")
            }.orEmpty()
            val q = if (raw.isBlank()) JSONObject() else try { JSONObject(raw) } catch (_: Exception) { throw AuthFault(AuthState.BACKEND_UNAVAILABLE, "AUTH_RESPONSE_INVALID") }
            if (status !in 200..299) {
                val code = q.optString("error_code", q.optString("code"))
                if (code in setOf("refresh_token_not_found", "refresh_token_already_used", "session_not_found", "user_banned", "user_not_found")) throw AuthFault(AuthState.REVOKED, "SESSION_REVOKED")
                if (path == "user" && status == 401) throw AuthFault(AuthState.REAUTH_REQUIRED, "ACCESS_REJECTED")
                throw AuthFault(AuthState.REAUTH_REQUIRED, "AUTH_REQUEST_REJECTED")
            }
            return q
        } catch (e: IOException) { throw AuthFault(AuthState.OFFLINE, "AUTH_NETWORK_UNAVAILABLE") }
        finally { connection.disconnect() }
    }
    private fun session(q: JSONObject): AuthSession {
        try {
            val uid = q.getJSONObject("user").getString("id")
            check(Regex("^[a-fA-F0-9-]{36}$").matches(uid))
            val access = q.getString("access_token"); val refresh = q.getString("refresh_token")
            check(access.isNotBlank() && refresh.isNotBlank())
            val expires = if (q.has("expires_at")) q.getLong("expires_at") * 1000 else System.currentTimeMillis() + q.getLong("expires_in") * 1000
            return AuthSession(uid, access, refresh, expires)
        } catch (_: Exception) { throw AuthFault(AuthState.BACKEND_UNAVAILABLE, "AUTH_RESPONSE_INVALID") }
    }
    override fun exchange(code: String, verifier: String) = session(request("token?grant_type=pkce", JSONObject().put("auth_code", code).put("code_verifier", verifier)))
    override fun refresh(token: String) = session(request("token?grant_type=refresh_token", JSONObject().put("refresh_token", token)))
    override fun verify(token: String) = request("user", token = token).getString("id")
    override fun logout(token: String) { request("logout?scope=local", JSONObject(), token) }
}
