package ru.sulfi.sulfi_hypnotherapy.transfer

import android.app.*
import android.app.job.*
import android.content.*
import android.content.pm.ServiceInfo
import android.media.MediaMetadataRetriever
import android.net.*
import android.os.*
import android.security.keystore.*
import android.util.Base64
import io.flutter.FlutterInjector
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.dart.DartExecutor
import io.flutter.plugin.common.*
import org.json.JSONObject
import java.security.KeyStore
import java.security.MessageDigest
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/** Native authority/control hints ONLY. Task payloads/offsets/receipts stay in library.sqlite. */
object TransferPlatform {
    const val CHANNEL = "ru.sulfi/transfers18"
    const val JOB = 1801
    const val RECOVERY = 1802
    const val NOTIFICATION = 1810
    private const val KEY = "sulfi-transfer-lease18"
    internal fun prefs(c: Context) = c.getSharedPreferences("transfer_authority18", Context.MODE_PRIVATE)
    private fun hash(s: String) = MessageDigest.getInstance("SHA-256").digest(s.toByteArray()).joinToString("") { "%02x".format(it) }
    private fun secret(): SecretKey {
        val ks = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (ks.getKey(KEY, null) as? SecretKey)?.let { return it }
        return KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore").apply {
            init(KeyGenParameterSpec.Builder(KEY, KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE).build())
        }.generateKey()
    }
    private fun seal(value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.ENCRYPT_MODE, secret()) }
        return Base64.encodeToString(cipher.iv + cipher.doFinal(value.toByteArray()), Base64.NO_WRAP)
    }
    @Synchronized fun lease(c: Context): JSONObject? = try {
        val raw = prefs(c).getString("sealed", null)
        if (raw == null) null else {
            val bytes = Base64.decode(raw, Base64.NO_WRAP)
            val cipher = Cipher.getInstance("AES/GCM/NoPadding").apply { init(Cipher.DECRYPT_MODE, secret(), GCMParameterSpec(128, bytes.copyOfRange(0, 12))) }
            JSONObject(String(cipher.doFinal(bytes.copyOfRange(12, bytes.size))))
        }
    } catch (_: Exception) { null } // Key invalidation is WAITING_AUTH, never a DB reset.

    @Synchronized fun authorize(c: Context, m: Map<*, *>): String {
        val endpoint = m["endpoint"] as String
        val scope = m["scope"] as String
        val owner = m["ownerBinding"] as String
        val role = m["role"] as String
        val expires = (m["expiresAt"] as Number).toLong()
        require(Regex("^https://script\\.google\\.com/macros/s/[\\w-]+/exec$").matches(endpoint))
        require(expires > System.currentTimeMillis() && expires <= System.currentTimeMillis() + 7200000)
        val public = scope == "public" && owner == "public" && role == "PUBLIC"
        require(public || Regex("^account:[a-f0-9]{64}$").matches(scope) && owner == hash("$endpoint|$scope") && role in listOf("MASTER", "CLIENT"))
        val token = m["token"] as? String
        require(public && token == null || !public && token != null && token.length in 100..16384)
        val previous = lease(c)
        val epoch = if (previous?.optString("ownerBinding") == owner) previous.getString("epoch") else java.util.UUID.randomUUID().toString()
        if (previous != null && previous.optString("ownerBinding") != owner) TransferRuntime.stop("OWNER_CHANGED")
        val networkPolicy = m["networkPolicy"] as? String ?: "any"
        require(networkPolicy in listOf("any", "unmetered"))
        val value = JSONObject().put("networkPolicy", networkPolicy).put("endpoint", endpoint).put("scope", scope).put("ownerBinding", owner)
            .put("role", role).put("expiresAt", expires).put("epoch", epoch).put("token", token ?: JSONObject.NULL)
        check(prefs(c).edit().putString("sealed", seal(value.toString())).commit())
        return epoch
    }
    @Synchronized fun revoke(c: Context) {
        check(prefs(c).edit().remove("sealed").commit())
        (c.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).apply { cancel(JOB); cancel(RECOVERY) }
        TransferRuntime.stop("OWNER_CHANGED")
    }
    fun command(c: Context, name: String, action: String, owner: String) {
        require(action in listOf("pause", "cancel", "resume"))
        require(lease(c)?.optString("ownerBinding") == owner)
        check(prefs(c).edit().putString("control:" + hash(name), JSONObject().put("name", name).put("ownerBinding", owner).put("action", action).toString()).commit())
        TransferRuntime.channel?.invokeMethod("control", mapOf("name" to name, "action" to action))
    }
    fun controls(c: Context, owner: String): List<Map<String, String>> = prefs(c).all.filterKeys { it.startsWith("control:") }.values.mapNotNull {
        try { val v = JSONObject(it as String); if (v.optString("ownerBinding") != owner) null else mapOf("name" to v.getString("name"), "action" to v.getString("action")) } catch (_: Exception) { null }
    }
    fun notify(c: Context, progress: Map<*, *> = emptyMap<String, String>(), ongoing: Boolean = true): Notification {
        val manager = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) manager.createNotificationChannel(NotificationChannel("sulfi_transfers18", "Передачи файлов", NotificationManager.IMPORTANCE_LOW))
        val title = (progress["title"] as? String)?.take(100) ?: "Передачи Сульфи"
        val stage = (progress["label"] as? String)?.take(100) ?: "Подготовка передачи"
        val n = (progress["bytes"] as? Number)?.toLong() ?: 0L
        val total = (progress["totalBytes"] as? Number)?.toLong() ?: 0L
        val open = Intent(c, Class.forName("ru.sulfi.sulfi_hypnotherapy.MainActivity")).putExtra("sulfi_transfer_queue", true)
        val pending = PendingIntent.getActivity(c, 1800, open, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        @Suppress("DEPRECATION")
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, "sulfi_transfers18") else Notification.Builder(c)
        b.setSmallIcon(android.R.drawable.stat_sys_upload).setContentTitle(title)
            .setContentText(if (total > 0) "$stage · $n / $total байт" else stage)
            .setContentIntent(pending).setOnlyAlertOnce(true).setOngoing(ongoing).setVisibility(Notification.VISIBILITY_PRIVATE)
            .setProgress(1000, if (total > 0) ((n.coerceAtMost(total).toDouble() / total) * 1000).toInt() else 0, total <= 0)
        val name = progress["name"] as? String
        val owner = lease(c)?.optString("ownerBinding")
        if (name != null && owner != null) for ((action, label) in listOf("pause" to "Пауза", "cancel" to "Отменить")) {
            val intent = Intent(c, TransferActionReceiver::class.java).putExtra("name", name).putExtra("owner", owner).putExtra("action", action)
            val control = PendingIntent.getBroadcast(c, (name + action).hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            @Suppress("DEPRECATION") b.addAction(0, label, control)
        }
        return b.build()
    }
    fun recoverLater(c: Context, delay: Long) {
        if (lease(c) == null) return
        val job = JobInfo.Builder(RECOVERY, ComponentName(c, TransferJobService::class.java))
            .setRequiredNetworkType(if (lease(c)?.optString("networkPolicy") == "unmetered") JobInfo.NETWORK_TYPE_UNMETERED else JobInfo.NETWORK_TYPE_ANY).setPersisted(true)
            .setMinimumLatency(delay.coerceIn(30000L, 900000L)).setBackoffCriteria(30000L, JobInfo.BACKOFF_POLICY_EXPONENTIAL).build()
        (c.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).schedule(job)
    }
    fun startUser(c: Context): String {
        require(lease(c) != null)
        (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIFICATION + 1)
        prefs(c).edit().putBoolean("needsUserStart", false).commit()
        if (Build.VERSION.SDK_INT >= 33 && c.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
            if (c is Activity) c.requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 1880)
            return "WAITING_POLICY"
        }
        prefs(c).edit().putLong("dispatchSeq", prefs(c).getLong("dispatchSeq", 0) + 1).putInt("initFailures", 0).commit()
        if (TransferRuntime.running) { TransferRuntime.channel?.invokeMethod("wake", null); return "RUNNING" }
        recoverLater(c, 600000L) // Persistent crash watchdog; canceled when no runnable work remains.
        if (Build.VERSION.SDK_INT >= 34) {
            val scheduler = c.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
            if (!scheduler.canRunUserInitiatedJobs()) return "WAITING_POLICY"
            val network = NetworkRequest.Builder().addCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)
            if (lease(c)?.optString("networkPolicy") == "unmetered") network.addCapability(NetworkCapabilities.NET_CAPABILITY_NOT_METERED)
            val job = JobInfo.Builder(JOB, ComponentName(c, TransferJobService::class.java))
                .setUserInitiated(true).setRequiredNetwork(network.build())
                .setEstimatedNetworkBytes(JobInfo.NETWORK_BYTES_UNKNOWN, JobInfo.NETWORK_BYTES_UNKNOWN).build()
            return if (scheduler.schedule(job) == JobScheduler.RESULT_SUCCESS) "QUEUED" else "WAITING_POLICY"
        }
        val i = Intent(c, TransferForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= 26) c.startForegroundService(i) else c.startService(i)
        return "QUEUED"
    }
    fun attach(source: Context, messenger: BinaryMessenger, worker: Boolean = false) {
        val c = source.applicationContext
        val activity = java.lang.ref.WeakReference(source as? Activity)
        val channel = MethodChannel(messenger, CHANNEL)
        if (worker) TransferRuntime.channel = channel
        channel.setMethodCallHandler { call, result ->
            try {
                @Suppress("UNCHECKED_CAST") val m = call.arguments as? Map<String, Any?> ?: emptyMap()
                when (call.method) {
                    "authorize" -> { require(!worker); result.success(authorize(c, m)) }
                    "revoke" -> { revoke(c); result.success(null) }
                    "start" -> { require(!worker); result.success(startUser(activity.get() ?: c)) }
                    "control" -> { command(c, m["name"] as String, m["action"] as String, m["ownerBinding"] as String); result.success(null) }
                    "controls" -> result.success(controls(c, m["ownerBinding"] as String))
                    "lease" -> {
                        require(worker)
                        val v = lease(c)
                        if (v == null || v.optLong("expiresAt") <= System.currentTimeMillis() || m["epoch"] != null && m["epoch"] != v.optString("epoch")) result.error("WAITING_AUTH", "Подтвердите исходный Google-аккаунт", null)
                        else result.success(v.keys().asSequence().associateWith { if (v.isNull(it)) null else v.get(it) } + mapOf("dispatchSeq" to prefs(c).getLong("dispatchSeq", 0)))
                    }
                    "progress" -> { require(worker); TransferRuntime.progress(m); result.success(null) }
                    "done" -> { require(worker); result.success(null); Handler(Looper.getMainLooper()).post { TransferRuntime.finish((m["retryAfterMs"] as? Number)?.toLong(), (m["observedDispatch"] as? Number)?.toLong() ?: -1, m["state"] as? String, m["startupFailure"] == true) } }
                    "status" -> result.success(mapOf("running" to TransferRuntime.running, "needsUserStart" to prefs(c).getBoolean("needsUserStart", false), "stopReason" to TransferRuntime.stopReason, "openQueue" to TransferRuntime.consumeOpen()))
                    "paths" -> result.success(mapOf("support" to c.filesDir.absolutePath))
                    "network" -> {
                        val manager = c.getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
                        result.success(mapOf("available" to (manager.activeNetwork != null), "metered" to manager.isActiveNetworkMetered))
                    }
                    "freeBytes" -> result.success(c.filesDir.usableSpace)
                    "probeAudio" -> { val r = MediaMetadataRetriever(); try { r.setDataSource(m["path"] as String); result.success(r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_DURATION)?.toLong()) } finally { r.release() } }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("TRANSFER_POLICY", "Передача сохранена. Откройте очередь для продолжения.", null) }
        }
    }
}

object TransferRuntime {
    var channel: MethodChannel? = null
    private var engine: FlutterEngine? = null
    private var context: Context? = null
    private var complete: (() -> Unit)? = null
    private var wake: PowerManager.WakeLock? = null
    private var lastNotice = 0L
    var stopReason: String? = null; private set
    var runId = 0; private set
    private var openQueue = false
    val running get() = engine != null
    fun requestOpen() { openQueue = true }
    fun consumeOpen(): Boolean { val v = openQueue; openQueue = false; return v }
    fun start(c: Context, finished: () -> Unit): Boolean {
        if (running) { channel?.invokeMethod("wake", null); return false }
        context = c.applicationContext; complete = finished; stopReason = null; runId++
        if (Build.VERSION.SDK_INT < 34) wake = (c.getSystemService(Context.POWER_SERVICE) as PowerManager).newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, c.packageName + ":transfers18").apply { setReferenceCounted(false); acquire(600000L) }
        val loader = FlutterInjector.instance().flutterLoader(); loader.startInitialization(c); loader.ensureInitializationComplete(c, null)
        val headless = FlutterEngine(c.applicationContext, null, false)
        // Register only the DB plugin. audio_service has global engine state;
        // auto-registration here could disturb an ongoing self-hypnosis session.
        headless.plugins.add(com.tekartik.sqflite.SqflitePlugin())
        engine = headless
        TransferPlatform.attach(c.applicationContext, headless.dartExecutor.binaryMessenger, true)
        headless.dartExecutor.executeDartEntrypoint(DartExecutor.DartEntrypoint(loader.findAppBundlePath(), "transferMain"))
        return true
    }
    fun stop(reason: String) { stopReason = reason; channel?.invokeMethod("stop", mapOf("reason" to reason)) }
    fun progress(m: Map<*, *>) {
        val c = context ?: return
        if (SystemClock.elapsedRealtime() - lastNotice < 1000) return
        lastNotice = SystemClock.elapsedRealtime()
        if (Build.VERSION.SDK_INT < 34) wake?.acquire(600000L)
        (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).notify(TransferPlatform.NOTIFICATION, TransferPlatform.notify(c, m))
    }
    fun finish(retryAfter: Long?, observedDispatch: Long = -1, state: String? = null, startupFailure: Boolean = false) {
        val c = context ?: return
        val done = complete; complete = null
        val old = engine; engine = null; channel = null
        if (wake?.isHeld == true) wake?.release(); wake = null
        old?.destroy()
        (c.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).cancel(TransferPlatform.RECOVERY)
        val preferences = TransferPlatform.prefs(c)
        val failures = if (startupFailure) preferences.getInt("initFailures", 0) + 1 else 0
        preferences.edit().putInt("initFailures", failures).commit()
        val newlyEnqueued = observedDispatch >= 0 && preferences.getLong("dispatchSeq", 0) > observedDispatch
        if ((retryAfter != null || newlyEnqueued) && failures < 5 && !preferences.getBoolean("needsUserStart", false)) TransferPlatform.recoverLater(c, if (newlyEnqueued) 30000L else retryAfter!!)
        if (state == "WAITING_AUTH" || state == "WAITING_POLICY") {
            val manager = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val pending = TransferPlatform.notify(c, mapOf("title" to "Передача сохранена", "label" to if (state == "WAITING_AUTH") "Откройте Сульфи и подтвердите Google-вход" else "Android отложил работу — откройте очередь"), false)
            manager.notify(TransferPlatform.NOTIFICATION + 1, pending)
        }
        (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(TransferPlatform.NOTIFICATION)
        done?.invoke()
    }
}

class TransferJobService : JobService() {
    private val handler = Handler(Looper.getMainLooper())
    private val budget = Runnable { TransferRuntime.stop("WAITING_POLICY") }
    override fun onStartJob(p: JobParameters): Boolean {
        if (TransferPlatform.prefs(this).getBoolean("needsUserStart", false)) return false
        if (Build.VERSION.SDK_INT >= 34) setNotification(p, TransferPlatform.NOTIFICATION, TransferPlatform.notify(this), JOB_END_NOTIFICATION_POLICY_REMOVE)
        val started = TransferRuntime.start(this) { handler.removeCallbacks(budget); jobFinished(p, false) }
        if (started && p.jobId == TransferPlatform.RECOVERY) handler.postDelayed(budget, 90000L)
        return started
    }
    override fun onStopJob(p: JobParameters): Boolean {
        handler.removeCallbacks(budget)
        val userStop = Build.VERSION.SDK_INT >= 31 && p.stopReason == JobParameters.STOP_REASON_USER
        if (userStop) TransferPlatform.prefs(this).edit().putBoolean("needsUserStart", true).commit()
        TransferRuntime.stop("WAITING_POLICY")
        val interruptedRun = TransferRuntime.runId
        handler.postDelayed({ if (TransferRuntime.running && TransferRuntime.runId == interruptedRun) TransferRuntime.finish(if (userStop) null else 30000L) }, 3000L)
        // UIDT user stop is not circumvented. Force Stop is governed by Android.
        return if (Build.VERSION.SDK_INT >= 31) p.stopReason != JobParameters.STOP_REASON_USER else true
    }
}
class TransferForegroundService : Service() {
    override fun onBind(i: Intent?): IBinder? = null
    override fun onStartCommand(i: Intent?, flags: Int, id: Int): Int {
        val notification = TransferPlatform.notify(this)
        if (Build.VERSION.SDK_INT >= 29) startForeground(TransferPlatform.NOTIFICATION, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        else startForeground(TransferPlatform.NOTIFICATION, notification)
        TransferRuntime.start(this) { stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
        return START_NOT_STICKY
    }
    override fun onTimeout(startId: Int, fgsType: Int) { TransferRuntime.stop("WAITING_POLICY"); stopForeground(STOP_FOREGROUND_REMOVE); stopSelf() }
    override fun onDestroy() {
        if (TransferRuntime.running) {
            val interruptedRun = TransferRuntime.runId
            TransferRuntime.stop("WAITING_POLICY")
            Handler(Looper.getMainLooper()).postDelayed({ if (TransferRuntime.running && TransferRuntime.runId == interruptedRun) TransferRuntime.finish(30000L) }, 3000L)
        }
        super.onDestroy()
    }
}
class TransferActionReceiver : BroadcastReceiver() {
    override fun onReceive(c: Context, i: Intent) {
        try { TransferPlatform.command(c, i.getStringExtra("name")!!, i.getStringExtra("action")!!, i.getStringExtra("owner")!!) } catch (_: Exception) { /* stale owner action cannot affect a new owner */ }
    }
}
