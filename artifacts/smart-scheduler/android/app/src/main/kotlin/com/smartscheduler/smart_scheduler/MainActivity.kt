package com.smartscheduler.smart_scheduler

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.os.Build
import kotlin.math.max

class MainActivity : FlutterActivity() {
    private val textScaleChannel = "com.smartscheduler/text_scale"
    // These are probe sizes, not app-defined text stops. They let Flutter
    // reproduce Android's non-linear accessibility curve for every native
    // setting exposed by the device.
    private val textProbeSizes = (4..1024).map { it / 4f }
    private var nativeStt: NativeSttPlugin? = null
    private var offlineOcr: NativeOfflineOcrPlugin? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, textScaleChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "getProfile") {
                    if (call.method == "getCurrentScale") {
                        result.success(resources.configuration.fontScale.toDouble())
                    } else {
                        result.notImplemented()
                    }
                    return@setMethodCallHandler
                }
                val current = resources.configuration.fontScale.toDouble()
                val stops = nativeFontScaleStops()
                val curves = stops.map { scale ->
                    textProbeSizes.map { size -> nativeScaleForSp(size, scale) }
                }
                result.success(
                    mapOf(
                        "currentScale" to current,
                        "stops" to stops,
                        "probeSizes" to textProbeSizes,
                        "curves" to curves,
                    )
                )
            }
        nativeStt = NativeSttPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
        offlineOcr = NativeOfflineOcrPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    private fun nativeFontScaleStops(): List<Double> {
        // Android's Settings app reads this framework resource. OEM overlays
        // can replace it, so this follows Pixel/Samsung/etc. rather than
        // shipping SKEDDO's own universal scale table.
        val resourceId = resources.getIdentifier(
            "config_fontSizeScale",
            "array",
            "android",
        )
        if (resourceId != 0) {
            val values = resources.obtainTypedArray(resourceId)
            try {
                val stops = buildList {
                    for (index in 0 until values.length()) {
                        val value = runCatching {
                            values.getFloat(index, Float.NaN)
                        }.getOrElse {
                            values.getString(index)?.toFloatOrNull() ?: Float.NaN
                        }
                        if (value.isFinite() && value > 0f) add(value.toDouble())
                    }
                }
                // Resource overlays are outside the app's control, but the
                // profile itself is platform-owned data. Preserve every
                // meaningful stop and its original platform order; Dart keeps
                // this complete list separate from SKEDDO's seven UI stops.
                if (stops.size >= 2) return stops
            } finally {
                values.recycle()
            }
        }
        // Old Android releases expose only the active value. Do not turn that
        // single value into a fake seven-position native profile in Dart.
        return emptyList()
    }

    private fun nativeScaleForSp(sp: Float, fontScale: Double): Double {
        if (Build.VERSION.SDK_INT >= 35) {
            val converter = android.content.res.FontScaleConverter.forScale(fontScale.toFloat())
            if (converter != null) {
                return (converter.convertSpToDp(sp) / sp).toDouble()
            }
        }
        // Before Android 15 the public platform contract is linear.
        return fontScale
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
