package com.smartscheduler.smart_scheduler

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val textScaleChannel = "com.smartscheduler/text_scale"
    private var nativeStt: NativeSttPlugin? = null
    private var offlineOcr: NativeOfflineOcrPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, textScaleChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "getProfile") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val current = resources.configuration.fontScale.toDouble()
                val stops = listOf(0.85, 1.0, 1.15, 1.30, 1.45)
                result.success(mapOf("currentScale" to current, "stops" to stops))
            }
        nativeStt = NativeSttPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
        offlineOcr = NativeOfflineOcrPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        nativeStt?.onRequestPermissionsResult(requestCode, grantResults)
    }

    override fun onDestroy() {
        offlineOcr?.dispose()
        nativeStt?.dispose()
        super.onDestroy()
    }
}
