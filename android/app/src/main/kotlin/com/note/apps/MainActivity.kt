package com.note.apps

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Environment
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "com.note.apps/abi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler handler@{ call, result ->
                when (call.method) {
                    "getPrimaryAbi" -> {
                        val abi = if (Build.SUPPORTED_ABIS.isNotEmpty()) {
                            Build.SUPPORTED_ABIS[0]
                        } else {
                            "unknown"
                        }
                        result.success(abi)
                    }
                    "installApk" -> {
                        val path = call.argument<String>("path")
                        if (path == null) {
                            result.error("bad_args", "path missing", null)
                            return@handler
                        }
                        try {
                            installApk(path)
                            result.success(true)
                        } catch (e: Exception) {
                            result.error("install_failed", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// Trigger Android's package installer for [apkPath]. Copies the file
    /// to the Downloads directory first so Android's scoped-storage rules
    /// can locate it via FileProvider when the install intent is fired.
    private fun installApk(apkPath: String) {
        val src = File(apkPath)
        if (!src.exists()) {
            throw IllegalArgumentException("APK not found at $apkPath")
        }
        // Copy to public Downloads so the installer can resolve the URI.
        val downloads = Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOWNLOADS,
        )
        val dest = File(downloads, src.name)
        src.copyTo(dest, overwrite = true)

        val authority = "$packageName.fileprovider"
        val apkUri: Uri = androidx.core.content.FileProvider.getUriForFile(
            this, authority, dest,
        )

        val intent = Intent(Intent.ACTION_VIEW).apply {
            setDataAndType(apkUri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }
}