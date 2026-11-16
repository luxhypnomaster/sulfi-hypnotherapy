package ru.sulfi.sulfi_hypnotherapy.auth19

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.AtomicFile
import org.json.JSONObject
import java.io.File
import java.io.RandomAccessFile
import java.security.KeyStore
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.locks.ReentrantLock
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Only compiled into isolated .auth19 builds. No SQLite or legacy prefs access. */
class SecureSessionStore(context: Context, project: String) : AuthStore {
    private val directory = File(context.noBackupFilesDir, "auth19-$project")
    private val data = AtomicFile(File(directory, "session.aesgcm"))
    private val lockFile = File(directory, "session.lock")
    private val alias = "sulfi.auth19.$project"
    private val lock = locks.computeIfAbsent(lockFile.canonicalPath) { ReentrantLock() }
    companion object { private val locks = ConcurrentHashMap<String, ReentrantLock>() }

    override fun <T> exclusive(block: () -> T): T {
        lock.lock()
        try {
            check(data.baseFile.length() <= 131072 && File(data.baseFile.path + ".bak").length() <= 131072)
            check(directory.exists() || directory.mkdirs())
            RandomAccessFile(lockFile, "rw").use { file ->
                file.channel.lock().use { return block() }
            }
        } finally { lock.unlock() }
    }
    private fun key(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(alias, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(alias, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true).build())
        }.generateKey()
    }
    override fun load(): AuthRecord {
        if (!data.baseFile.exists() && !File(data.baseFile.path + ".bak").exists()) return AuthRecord()
        try {
            val encrypted = data.openRead().use { input -> input.readBytes().also { check(it.size in 29..131072) } }
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, key(), GCMParameterSpec(128, encrypted.copyOfRange(0, 12)))
            val q = JSONObject(String(cipher.doFinal(encrypted.copyOfRange(12, encrypted.size)), Charsets.UTF_8))
            check(q.getInt("v") == 1)
            fun nullable(o: JSONObject, key: String) = if (o.isNull(key)) null else o.getString(key)
            val session = q.optJSONObject("session")?.let { AuthSession(it.getString("uid"), it.getString("access"), it.getString("refresh"), it.getLong("expires")) }
            val pending = q.optJSONObject("pending")?.let { PendingLogin(it.getString("verifier"), it.getString("nonce"), it.getLong("expires"), nullable(it, "expectedUid")) }
            return AuthRecord(session, pending, q.getBoolean("loggedOut"), q.getLong("epoch"), q.optLong("retryAt"), nullable(q,"terminal")?.let(AuthState::valueOf))
        } catch (_: Exception) {
            // Preserve ciphertext/key and report. Never erase or recreate data.
            throw AuthFault(AuthState.REAUTH_REQUIRED, "SECURE_STORAGE_UNREADABLE")
        }
    }
    override fun save(record: AuthRecord) {
        val q = JSONObject().put("v", 1).put("loggedOut", record.loggedOut).put("epoch", record.epoch)
            .put("retryAt", record.retryAt).put("terminal", record.terminal?.name ?: JSONObject.NULL)
        record.session?.let { q.put("session", JSONObject().put("uid", it.uid).put("access", it.access).put("refresh", it.refresh).put("expires", it.expires)) }
        record.pending?.let { q.put("pending", JSONObject().put("verifier", it.verifier).put("nonce", it.nonce).put("expires", it.expires).put("expectedUid", it.expectedUid ?: JSONObject.NULL)) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, key()) }
        val bytes = cipher.iv + cipher.doFinal(q.toString().toByteArray(Charsets.UTF_8))
        val stream = data.startWrite()
        try { stream.write(bytes); stream.fd.sync(); data.finishWrite(stream) }
        catch (e: Exception) { data.failWrite(stream); throw e }
    }
}
