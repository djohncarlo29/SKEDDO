package com.smartscheduler.smart_scheduler

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    private var nativeStt: NativeSttPlugin? = null
    private var offlineOcr: NativeOfflineOcrPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
