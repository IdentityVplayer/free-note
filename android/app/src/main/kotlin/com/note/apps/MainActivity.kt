package com.note.apps

import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.note.apps/abi"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "getPrimaryAbi") {
                    val abi = if (Build.SUPPORTED_ABIS.isNotEmpty()) {
                        Build.SUPPORTED_ABIS[0]
                    } else {
                        "unknown"
                    }
                    result.success(abi)
                } else {
                    result.notImplemented()
                }
            }
    }
}
