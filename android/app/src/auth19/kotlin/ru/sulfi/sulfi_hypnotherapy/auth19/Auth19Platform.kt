package ru.sulfi.sulfi_hypnotherapy.auth19

import android.app.Activity
import android.content.Intent
import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.BinaryMessenger
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.atomic.AtomicInteger

/** Deliberately absent from default APK source set, no legacy auth integration. */
object Auth19Platform {
    private val executor = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private val listeners = ConcurrentHashMap<Int, EventChannel.EventSink>()
    private val counter = AtomicInteger()
    private var coordinator: AuthCoordinator? = null
    private var configuration: String? = null
    private var pendingCallback: String? = null
    private fun map(s: AuthSnapshot) = mapOf("state" to s.state.name, "uid" to s.uid, "epoch" to s.epoch, "code" to s.code)
    private fun changed(s: AuthSnapshot) { main.post { listeners.values.forEach { it.success(map(s)) } } }

    @JvmStatic fun callback(intent: Intent) {
        val value = intent.dataString ?: return
        executor.execute {
            val c = coordinator
            if (c == null) pendingCallback = value else try { c.completeLogin(value) }
            catch (e: AuthFault) { changed(AuthSnapshot(e.kind, -1, code = e.code)) }
            catch (_: Exception) { changed(AuthSnapshot(AuthState.BACKEND_UNAVAILABLE, -1, code = "AUTH19_UNAVAILABLE")) }
        }
    }
    @JvmStatic fun attach(activity: Activity, engine: FlutterEngine) {
        attachTo(activity.applicationContext, engine.dartExecutor.binaryMessenger, true)
        callback(activity.intent)
    }
    /** Explicit prototype registration for a headless engine. Does not modify
     * Task18 transferMain; Supabase-GAS bridge remains a future G3 gate. */
    @JvmStatic fun attachWorker(context: Context, messenger: BinaryMessenger) {
        attachTo(context.applicationContext, messenger, false)
    }
    private fun attachTo(context: Context, messenger: BinaryMessenger, interactive: Boolean) {
        check(context.packageName.endsWith(".auth19"))
        val id = counter.incrementAndGet()
        EventChannel(messenger, "ru.sulfi/auth19/events").setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink) { listeners[id] = events }
            override fun onCancel(arguments: Any?) { listeners.remove(id) }
        })
        MethodChannel(messenger, "ru.sulfi/auth19").setMethodCallHandler { call, result ->
            executor.execute {
                try {
                    val expectedUid = call.argument<String>("expectedUid")
                    if (!Auth19Policy.allowed(interactive, call.method, expectedUid))
                        throw AuthFault(AuthState.REAUTH_REQUIRED, "WORKER_OWNER_OR_METHOD_DENIED")
                    val value: Any? = if (call.method == "initialize") {
                        val ref = call.argument<String>("projectRef").orEmpty()
                        val key = call.argument<String>("publishableKey").orEmpty()
                        if (!Regex("^[a-z0-9]{20}$").matches(ref) || !Regex("^sb_publishable_[A-Za-z0-9_-]{12,}$").matches(key))
                            throw AuthFault(AuthState.SIGNED_OUT, "OWNER_SETUP_REQUIRED")
                        val scheme = if (context.packageName.contains(".clienttest.")) "sulfiauth19client" else "sulfiauth19master"
                        val config = "$ref|$scheme"
                        if (configuration != null && configuration != config) throw AuthFault(AuthState.REAUTH_REQUIRED, "CONFIGURATION_LOCKED")
                        if (coordinator == null) {
                            coordinator = AuthCoordinator(SecureSessionStore(context, ref), SupabaseRest("https://$ref.supabase.co", key), "https://$ref.supabase.co", scheme, changed = ::changed)
                            configuration = config
                        }
                        pendingCallback?.let { pendingCallback = null; coordinator!!.completeLogin(it) }
                        map(coordinator!!.restore(expectedUid))
                    } else {
                        val c = coordinator ?: throw AuthFault(AuthState.SIGNED_OUT, "OWNER_SETUP_REQUIRED")
                        when (call.method) {
                            "restore" -> map(c.restore(call.argument("expectedUid")))
                            "beginLogin" -> c.beginLogin(call.argument<Boolean>("switchAccount") == true)
                            "logout" -> map(c.logout())
                            "cancelLogin" -> map(c.cancelLogin())
                            "lease" -> c.lease(call.argument<String>("expectedUid").orEmpty(), call.argument<Number>("expectedEpoch")?.toLong())
                            else -> throw AuthFault(AuthState.BACKEND_UNAVAILABLE, "METHOD_NOT_SUPPORTED")
                        }
                    }
                    main.post { result.success(value) }
                } catch (e: AuthFault) { main.post { result.error(e.code, e.kind.name, null) } }
                catch (_: Exception) { main.post { result.error("AUTH19_UNAVAILABLE", AuthState.BACKEND_UNAVAILABLE.name, null) } }
            }
        }
    }
}
