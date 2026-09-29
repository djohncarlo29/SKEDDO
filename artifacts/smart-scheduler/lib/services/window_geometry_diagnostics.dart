import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Reports the physical window, native application-window, and Flutter
/// MediaQuery geometry together while developing platform window behavior.
///
/// This is intentionally read-only. It does not change safe-area values or
/// screen layout; [AppWindowContentBoundary] remains the single consumer that
/// establishes SKEDDO's logical content rectangle.
class WindowGeometryDiagnostics {
  WindowGeometryDiagnostics._();

  static const MethodChannel _channel = MethodChannel(
    'com.smartscheduler/window_geometry',
  );
  static String? _lastDartSignature;
  static bool _requestInFlight = false;

  static void report(BuildContext context) {
    if (kIsWeb || _requestInFlight) return;

    final mediaQuery = MediaQuery.of(context);
    final view = View.maybeOf(context);
    final viewData = view == null ? mediaQuery : MediaQueryData.fromView(view);
    final display = view?.display;
    final dartGeometry = <String, Object?>{
      'mediaQuery': _mediaQueryMap(mediaQuery),
      'viewData': _mediaQueryMap(viewData),
      'flutterView': {
        'physicalSize': view?.physicalSize.toString(),
        'devicePixelRatio': view?.devicePixelRatio,
        'display': display == null
            ? null
            : {
                'size': display.size.toString(),
                'devicePixelRatio': display.devicePixelRatio,
                'refreshRate': display.refreshRate,
              },
      },
    };
    final signature = jsonEncode(dartGeometry);
    if (signature == _lastDartSignature) return;
    _lastDartSignature = signature;
    _requestInFlight = true;
    unawaited(_capture(dartGeometry));
  }

  static Map<String, Object?> _mediaQueryMap(MediaQueryData data) => {
    'size': data.size.toString(),
    'padding': _edgeInsetsMap(data.padding),
    'viewPadding': _edgeInsetsMap(data.viewPadding),
    'viewInsets': _edgeInsetsMap(data.viewInsets),
    'systemGestureInsets': _edgeInsetsMap(data.systemGestureInsets),
    'displayFeatures': data.displayFeatures
        .map(
          (feature) => {
            'bounds': feature.bounds.toString(),
            'type': feature.type.name,
            'state': feature.state.name,
          },
        )
        .toList(),
  };

  static Map<String, double> _edgeInsetsMap(EdgeInsets insets) => {
    'left': insets.left,
    'top': insets.top,
    'right': insets.right,
    'bottom': insets.bottom,
  };

  static Future<void> _capture(Map<String, Object?> dartGeometry) async {
    Object? nativeGeometry;
    try {
      nativeGeometry = await _channel.invokeMethod<Object?>(
        'getWindowGeometry',
      );
    } catch (error) {
      nativeGeometry = 'unavailable: $error';
    } finally {
      _requestInFlight = false;
    }

    debugPrint(
      '[SKEDDO_WINDOW_GEOMETRY] '
      '${jsonEncode(<String, Object?>{'dart': dartGeometry, 'native': nativeGeometry})}',
    );
  }
}
