import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps Android Freeform caption controls legible over the transparent
/// caption background when SKEDDO's in-app light/dark setting changes.
class WindowCaptionAppearance {
  WindowCaptionAppearance._();

  static const MethodChannel _channel = MethodChannel(
    'com.smartscheduler/window_appearance',
  );
  static bool? _lastLightSurface;

  static void synchronize(Brightness brightness) {
    if (kIsWeb || !Platform.isAndroid) return;
    final lightSurface = brightness == Brightness.light;
    if (_lastLightSurface == lightSurface) return;
    _lastLightSurface = lightSurface;
    unawaited(_send(lightSurface));
  }

  static Future<void> _send(bool lightSurface) async {
    try {
      await _channel.invokeMethod<void>(
        'setCaptionBarAppearance',
        {'lightSurface': lightSurface},
      );
    } on MissingPluginException {
      _lastLightSurface = null;
    } on PlatformException {
      _lastLightSurface = null;
    }
  }
}
