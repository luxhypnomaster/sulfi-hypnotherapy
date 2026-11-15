package ru.sulfi.sulfi_hypnotherapy.probe

import android.app.Activity
import android.app.Application
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.io.File
import org.json.JSONObject

/** Compiled ONLY in disposable .transferprobe; never in either user APK. */
object TransferProbeControl {
    @JvmStatic fun attach(activity: Activity, engine: FlutterEngine) {
        require(activity.packageName.endsWith(".transferprobe"))
        MethodChannel(engine.dartExecutor.binaryMessenger, "ru.sulfi/controlled18").setMethodCallHandler { call, result ->
            if (call.method != "destroyUi") { result.notImplemented(); return@setMethodCallHandler }
            val application = activity.application
            var engineDestroyed = false
            val listener = object : FlutterEngine.EngineLifecycleListener {
                override fun onPreEngineRestart() {}
                override fun onEngineWillDestroy() { engineDestroyed = true }
            }
            engine.addEngineLifecycleListener(listener)
            val lifecycle = object : Application.ActivityLifecycleCallbacks {
                override fun onActivityCreated(a: Activity, state: Bundle?) {}
                override fun onActivityStarted(a: Activity) {}
                override fun onActivityResumed(a: Activity) {}
                override fun onActivityPaused(a: Activity) {}
                override fun onActivityStopped(a: Activity) {}
                override fun onActivitySaveInstanceState(a: Activity, state: Bundle) {}
                override fun onActivityDestroyed(a: Activity) {
                    if (a !== activity) return
                    application.unregisterActivityLifecycleCallbacks(this)
                    // Activity reports super.onDestroy BEFORE FlutterActivity
                    // detaches its FlutterView. A next-loop callback waits for
                    // the entire actual onDestroy stack; a fixed delay cannot.
                    Handler(Looper.getMainLooper()).post {
                        val cache = FlutterEngineCache.getInstance()
                        val id = com.ryanheise.audioservice.AudioServicePlugin.getFlutterEngineId()
                        if (cache.get(id) === engine) cache.remove(id)
                        if (!engineDestroyed) engine.destroy()
                        File(activity.filesDir, "probe18-ui-destroy.json").writeText(JSONObject()
                            .put("classification", "DISPOSABLE_CONTROLLED_NO_GOOGLE")
                            .put("activityDestroyed", activity.isDestroyed)
                            .put("engineDestroyed", engineDestroyed)
                            .put("cachedUiEngineAbsent", cache.get(id) == null)
                            .put("workerRunning", ru.sulfi.sulfi_hypnotherapy.transfer.TransferRuntime.running)
                            .put("pid", android.os.Process.myPid())
                            .put("atMs", System.currentTimeMillis()).toString())
                        engine.removeEngineLifecycleListener(listener)
                    }
                }
            }
            application.registerActivityLifecycleCallbacks(lifecycle)
            result.success(null)
            Handler(Looper.getMainLooper()).post { activity.finish() }
        }
    }
}
