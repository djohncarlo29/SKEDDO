package com.smartscheduler.smart_scheduler

import android.app.Activity
import android.content.res.Configuration
import android.graphics.Color
import android.graphics.Rect
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.OpenableColumns
import android.util.TypedValue
import android.view.View
import android.view.WindowInsets
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.platform.PlatformPlugin
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.SelectionQuietPlatformPlugin
import androidx.core.view.WindowCompat

class MainActivity : FlutterActivity() {
    private val textScaleChannel = "com.smartscheduler/text_scale"
    private val dropMetadataChannel = "com.smartscheduler/drop_metadata"
    private val selectionHapticsChannel = "com.smartscheduler/selection_haptics"
    private val windowGeometryChannel = "com.smartscheduler/window_geometry"
    // These are probe sizes, not app-defined text stops. They let Flutter
    // reproduce Android's non-linear accessibility curve for every native
    // setting exposed by the device.
    private val textProbeSizes = (4..1024).map { it / 4f }
    private var nativeStt: NativeSttPlugin? = null
    private var offlineOcr: NativeOfflineOcrPlugin? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        configureEdgeToEdgeWindow()
        super.onCreate(savedInstanceState)
        // Flutter's platform plugin can update system UI flags while the
        // engine starts. Re-apply the layout contract after the Activity has
        // attached so the DecorView remains full-window on older Android
        // versions as well as Android 15+.
        configureEdgeToEdgeWindow()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, windowGeometryChannel)
            .setMethodCallHandler { call, result ->
                if (call.method == "getWindowGeometry") {
                    result.success(windowGeometry())
                } else {
                    result.notImplemented()
                }
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, textScaleChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "getProfile" && call.method != "getDiagnosticProfile") {
                    if (call.method == "getCurrentScale") {
                        result.success(resources.configuration.fontScale.toDouble())
                    } else {
                        result.notImplemented()
                    }
                    return@setMethodCallHandler
                }
                val current = resources.configuration.fontScale.toDouble()
                val stops = nativeFontScaleStops()
                val diagnosticOnly = call.method == "getDiagnosticProfile"
                val probeSizes = if (diagnosticOnly) {
                    listOf(8f, 12f, 16f, 20f, 24f, 32f, 40f, 48f, 64f, 80f)
                } else {
                    textProbeSizes
                }
                val curves = stops.map { scale ->
                    val metrics = metricsForFontScale(scale)
                    probeSizes.map { size -> nativeScaleForSp(size, metrics) }
                }
                val stopMetrics = stops.map { scale ->
                    metricsForDiagnostic(metricsForFontScale(scale))
                }
                val diagnosticError = if (diagnosticOnly && stops.size < 2) {
                    "Android did not expose at least two config_fontSizeScale stops " +
                        "(found ${stops.size}; resource id ${resources.getIdentifier(
                            "config_fontSizeScale",
                            "array",
                            "android",
                        )})."
                } else {
                    null
                }
                result.success(
                    mapOf(
                        "currentScale" to current,
                        "stops" to stops,
                        "probeSizes" to probeSizes,
                        "curves" to curves,
                        "activeMetrics" to metricsForDiagnostic(resources.displayMetrics),
                        "activeConfigurationFontScale" to resources.configuration.fontScale.toDouble(),
                        "stopMetrics" to stopMetrics,
                        "diagnosticError" to diagnosticError,
                    )
                )
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, dropMetadataChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "resolveUriMetadata") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val uriValue = call.argument<String>("uri")
                if (uriValue.isNullOrBlank()) {
                    result.success(null)
                    return@setMethodCallHandler
                }
                result.success(resolveUriMetadata(Uri.parse(uriValue)))
            }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, selectionHapticsChannel)
            .setMethodCallHandler { call, result ->
                if (call.method != "setSelectionHandleDragging") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                SelectionQuietPlatformPlugin.setSelectionHandleDragging(
                    call.arguments as? Boolean ?: false,
                )
                result.success(null)
            }
        nativeStt = NativeSttPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
        offlineOcr = NativeOfflineOcrPlugin(this, flutterEngine.dartExecutor.binaryMessenger)
    }

    override fun providePlatformPlugin(
        activity: Activity?,
        flutterEngine: FlutterEngine,
    ): PlatformPlugin {
        return SelectionQuietPlatformPlugin(
            this,
            flutterEngine.platformChannel,
            this,
        )
    }

    private fun resolveUriMetadata(uri: Uri): Map<String, String?> {
        val displayName = if (uri.scheme.equals("content", ignoreCase = true)) {
            runCatching {
                contentResolver.query(
                    uri,
                    arrayOf(OpenableColumns.DISPLAY_NAME),
                    null,
                    null,
                    null,
                )?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameColumn = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                        if (nameColumn >= 0) cursor.getString(nameColumn) else null
                    } else {
                        null
                    }
                }
            }.getOrNull()
        } else if (uri.scheme.equals("file", ignoreCase = true)) {
            uri.lastPathSegment
        } else {
            null
        }
        val mimeType = runCatching { contentResolver.getType(uri) }.getOrNull()
        return mapOf("displayName" to displayName, "mimeType" to mimeType)
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

    private fun metricsForFontScale(fontScale: Double): android.util.DisplayMetrics {
        val stopConfiguration = Configuration(resources.configuration).apply {
            this.fontScale = fontScale.toFloat()
        }
        return createConfigurationContext(stopConfiguration).resources.displayMetrics
    }

    private fun nativeScaleForSp(
        sp: Float,
        metrics: android.util.DisplayMetrics,
    ): Double {
        // Match FlutterJNI.getScaledFontSize exactly:
        // TypedValue.applyDimension(COMPLEX_UNIT_SP, size, metrics) / density.
        // The metrics come from a configuration context so Android constructs
        // the same scaled metrics for this hypothetical native OS position,
        // including nonlinear scaling on Android 14+.
        return (
            TypedValue.applyDimension(
                TypedValue.COMPLEX_UNIT_SP,
                sp,
                metrics,
            ) / metrics.density
        ).toDouble() / sp
    }

    private fun metricsForDiagnostic(
        metrics: android.util.DisplayMetrics,
    ): Map<String, Any> {
        return mapOf(
            "density" to metrics.density.toDouble(),
            "scaledDensity" to metrics.scaledDensity.toDouble(),
            "densityDpi" to metrics.densityDpi,
            "scaledDensityOverDensity" to
                (metrics.scaledDensity / metrics.density).toDouble(),
        )
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
        SelectionQuietPlatformPlugin.setSelectionHandleDragging(false)
        offlineOcr?.dispose()
        nativeStt?.dispose()
        super.onDestroy()
    }

    private fun configureEdgeToEdgeWindow() {
        // This is the native source of truth for the Android application
        // window. SystemUiMode.edgeToEdge in Dart controls Flutter's system
        // bar appearance, but does not reliably change decor fitting on every
        // Android/OEM combination.
        WindowCompat.setDecorFitsSystemWindows(window, false)
        window.statusBarColor = Color.TRANSPARENT
        window.navigationBarColor = Color.TRANSPARENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            window.navigationBarDividerColor = Color.TRANSPARENT
            window.attributes = window.attributes.apply {
                layoutInDisplayCutoutMode =
                    android.view.WindowManager.LayoutParams
                        .LAYOUT_IN_DISPLAY_CUTOUT_MODE_SHORT_EDGES
            }
        }
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R) {
            window.decorView.systemUiVisibility =
                window.decorView.systemUiVisibility or
                    View.SYSTEM_UI_FLAG_LAYOUT_STABLE or
                    View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                    View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
        }
    }

    private fun rectMap(rect: Rect): Map<String, Int> = mapOf(
        "left" to rect.left,
        "top" to rect.top,
        "right" to rect.right,
        "bottom" to rect.bottom,
        "width" to rect.width(),
        "height" to rect.height(),
    )

    private fun insetsMap(insets: android.graphics.Insets): Map<String, Int> =
        mapOf(
            "left" to insets.left,
            "top" to insets.top,
            "right" to insets.right,
            "bottom" to insets.bottom,
        )

    private fun windowGeometry(): Map<String, Any?> {
        val resourcesMetrics = resources.displayMetrics
        val realDisplayMetrics = android.util.DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getRealMetrics(realDisplayMetrics)

        val decor = window.decorView
        val location = IntArray(2)
        decor.getLocationOnScreen(location)
        val result = mutableMapOf<String, Any?>(
            "platform" to "android",
            "edgeToEdgeRequested" to true,
            "decorFitsSystemWindows" to false,
            "displaySizePx" to mapOf(
                "width" to realDisplayMetrics.widthPixels,
                "height" to realDisplayMetrics.heightPixels,
            ),
            "resourceDisplayMetricsPx" to mapOf(
                "width" to resourcesMetrics.widthPixels,
                "height" to resourcesMetrics.heightPixels,
                "density" to resourcesMetrics.density.toDouble(),
                "densityDpi" to resourcesMetrics.densityDpi,
            ),
            "decorBoundsPx" to mapOf(
                "leftOnScreen" to location[0],
                "topOnScreen" to location[1],
                "width" to decor.width,
                "height" to decor.height,
            ),
        )

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            val metrics = windowManager.currentWindowMetrics
            val windowInsets = metrics.windowInsets
            val visibleSystemBars = windowInsets.getInsets(
                WindowInsets.Type.systemBars(),
            )
            val systemBars = windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemBars(),
            )
            val systemGestures = windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.systemGestures(),
            )
            val tappable = windowInsets.getInsetsIgnoringVisibility(
                WindowInsets.Type.tappableElement(),
            )
            result["windowBoundsPx"] = rectMap(metrics.bounds)
            result["windowInsets"] = mapOf(
                "systemBarsVisible" to insetsMap(visibleSystemBars),
                "systemBars" to insetsMap(systemBars),
                "systemGestures" to insetsMap(systemGestures),
                "tappableElement" to insetsMap(tappable),
            )
            val cutout = windowInsets.displayCutout
            result["displayCutout"] = cutout?.let {
                mapOf(
                    "safeInsets" to mapOf(
                        "left" to it.safeInsetLeft,
                        "top" to it.safeInsetTop,
                        "right" to it.safeInsetRight,
                        "bottom" to it.safeInsetBottom,
                    ),
                    "boundingRects" to it.boundingRects.map(::rectMap),
                )
            }
        } else {
            @Suppress("DEPRECATION")
            val rootInsets = decor.rootWindowInsets
            if (rootInsets != null && Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                @Suppress("DEPRECATION")
                result["windowInsets"] = mapOf(
                    "systemBars" to mapOf(
                        "left" to rootInsets.systemWindowInsetLeft,
                        "top" to rootInsets.systemWindowInsetTop,
                        "right" to rootInsets.systemWindowInsetRight,
                        "bottom" to rootInsets.systemWindowInsetBottom,
                    ),
                )
            }
        }
        return result
    }
}
