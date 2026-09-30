import 'dart:ui' show Size;

import 'package:flutter/widgets.dart' show BuildContext, View;

/// Returns the full Flutter view size in logical pixels on native platforms.
Size? getDeviceScreenSize(BuildContext context) {
  final view = View.of(context);
  final devicePixelRatio = view.devicePixelRatio;
  if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) return null;

  final size = view.physicalSize / devicePixelRatio;
  if (size.width <= 0 || size.height <= 0) return null;
  return size;
}