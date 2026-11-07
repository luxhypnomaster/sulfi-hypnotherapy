package ru.sulfi.sulfi_hypnotherapy

import com.ryanheise.audioservice.AudioServiceActivity
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.security.MessageDigest
import java.util.concurrent.Executors

class MainActivity: AudioServiceActivity() {
    private val executor = Executors.newSingleThreadExecutor()
    private var pending: MethodChannel.Result? = null
    private var cameraResult: MethodChannel.Result? = null
    private var cameraFile: File? = null
    private var exportPath: String? = null
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ru.sulfi/device_files").setMethodCallHandler { call, result ->
            when (call.method) {
                "capturePhoto" -> {
                    if (cameraResult != null) { result.error("BUSY", "Камера уже открыта", null); return@setMethodCallHandler }
                    val file = File.createTempFile("sulfi-photo-", ".jpg", cacheDir)
                    val uri = androidx.core.content.FileProvider.getUriForFile(this, "$packageName.history.camera", file)
                    val intent = Intent(android.provider.MediaStore.ACTION_IMAGE_CAPTURE).putExtra(android.provider.MediaStore.EXTRA_OUTPUT, uri).addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION or Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    intent.clipData = android.content.ClipData.newRawUri("photo", uri)
                    cameraResult = result; cameraFile = file
                    try { startActivityForResult(intent, 742) } catch (e: Exception) { cameraResult = null; cameraFile = null; file.delete(); result.error("CAMERA", "Камера недоступна", null) }
                }
                "copyLegacyAudio" -> {
                    val uri = android.net.Uri.parse(call.arguments as String)
                    if (uri.scheme != "content") { result.error("URI", "Недопустимый источник", null); return@setMethodCallHandler }
                    executor.execute {
                        val target = File.createTempFile("sulfi-legacy-", ".part", cacheDir)
                        try {
                            contentResolver.openInputStream(uri)!!.use { input -> target.outputStream().use { input.copyTo(it) } }
                            runOnUiThread { result.success(target.path) }
                        } catch (e: Exception) { target.delete(); runOnUiThread { result.error("MISSING", "Прежний источник недоступен", null) } }
                    }
                }
                "freeBytes" -> result.success(filesDir.usableSpace)
                "keepAwake" -> {
                    if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                "diagnostics" -> {
                    val flags = if (Build.VERSION.SDK_INT >= 28) PackageManager.GET_SIGNING_CERTIFICATES else PackageManager.GET_SIGNATURES
                    val info = packageManager.getPackageInfo(packageName, flags)
                    @Suppress("DEPRECATION")
                    val signatures = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.apkContentsSigners else info.signatures
                    val hashes = signatures?.map { signature -> MessageDigest.getInstance("SHA-256").digest(signature.toByteArray()).joinToString("") { "%02x".format(it) } } ?: emptyList<String>()
                    val lineage = if (Build.VERSION.SDK_INT >= 28) info.signingInfo?.signingCertificateHistory?.map { signature -> MessageDigest.getInstance("SHA-256").digest(signature.toByteArray()).joinToString("") { "%02x".format(it) } } ?: emptyList<String>() else hashes
                    @Suppress("DEPRECATION")
                    val code = if (Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()
                    result.success(mapOf("applicationId" to packageName, "versionName" to info.versionName, "versionCode" to code, "certificateSha256" to hashes, "certificateHistorySha256" to lineage,
                        "debuggable" to ((applicationInfo.flags and android.content.pm.ApplicationInfo.FLAG_DEBUGGABLE) != 0)))
                }
                "saveZip", "openZip" -> {
                    if (pending != null) { result.error("BUSY", "Уже открыт выбор файла", null); return@setMethodCallHandler }
                    exportPath = if (call.method == "saveZip") call.argument<String>("path") else null
                    if (call.method == "saveZip" && (exportPath == null || !File(exportPath!!).canonicalPath.startsWith(cacheDir.canonicalPath + File.separator))) {
                        result.error("PATH", "Файл вне временного хранилища", null); return@setMethodCallHandler
                    }
                    pending = result
                    val intent = Intent(if (exportPath == null) Intent.ACTION_OPEN_DOCUMENT else Intent.ACTION_CREATE_DOCUMENT).apply {
                        addCategory(Intent.CATEGORY_OPENABLE); type = "application/zip"
                        if (exportPath != null) putExtra(Intent.EXTRA_TITLE, "Сульфи-резервная-копия.zip")
                    }
                    try { startActivityForResult(intent, 741) }
                    catch (e: Exception) { pending = null; result.error("PICKER", "Не удалось открыть системный выбор файла", null) }
                }
                else -> result.notImplemented()
            }
        }
    }
    @Deprecated("Activity result API used by the Flutter Activity")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 742) {
            val callback = cameraResult; val file = cameraFile
            cameraResult = null; cameraFile = null
            if (resultCode == Activity.RESULT_OK && file != null && file.length() > 0) callback?.success(file.path)
            else { file?.delete(); callback?.success(null) }
            return
        }
        if (requestCode != 741) return
        val callback = pending ?: return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending = null; callback.success(if (exportPath != null) false else null); return
        }
        val source = exportPath
        executor.execute {
            var imported: File? = null
            try {
                val value: Any = if (source != null) {
                    contentResolver.openOutputStream(uri, "wt")!!.use { output -> File(source).inputStream().use { it.copyTo(output) } }; true
                } else {
                    imported = File.createTempFile("sulfi-incoming-", ".zip", cacheDir)
                    contentResolver.openInputStream(uri)!!.use { input -> imported!!.outputStream().use { output ->
                        val buffer = ByteArray(65536); var total = 0L
                        while (true) { val n = input.read(buffer); if (n < 0) break; total += n
                            require(total <= 4L * 1024 * 1024 * 1024 && filesDir.usableSpace > 16L * 1024 * 1024) { "Недостаточно места или слишком большой ZIP" }
                            output.write(buffer, 0, n)
                        }
                    } }; imported!!.path
                }
                runOnUiThread { pending = null; callback.success(value) }
            } catch (e: Exception) {
                imported?.delete()
                runOnUiThread { pending = null; callback.error("TRANSFER", "Не удалось прочитать или сохранить ZIP. Проверьте место и доступ.", null) }
            }
        }
    }
}
