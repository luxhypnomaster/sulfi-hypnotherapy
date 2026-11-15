package ru.sulfi.sulfi_hypnotherapy.probe

import android.app.Activity
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel

/** Compiled ONLY in the disposable .transferprobe APK, never the two QA candidates. */
object TransferProbeControl {
    @JvmStatic fun attach(activity: Activity, engine: FlutterEngine) {
        require(activity.packageName.endsWith(".transferprobe"))
        MethodChannel(engine.dartExecutor.binaryMessenger, "ru.sulfi/controlled18").setMethodCallHandler { call, result ->
            if (call.method != "destroyUi") { result.notImplemented(); return@setMethodCallHandler }
            result.success(null)
            Handler(Looper.getMainLooper()).postDelayed({
                activity.finish()
                Handler(Looper.getMainLooper()).postDelayed({
                    FlutterEngineCache.getInstance().remove(com.ryanheise.audioservice.AudioServicePlugin.getFlutterEngineId())
                    engine.destroy() // Wait for Activity detach; separate JobService engine MUST survive.
                }, 1000L)
            }, 750L)
        }
    }
}
