import 'dart:html' as html;
import 'dart:ui' show Size;

import 'package:flutter/widgets.dart' show BuildContext, View;

/// Returns the full browser display size in logical CSS pixels.
///
/// Unlike the page viewport, this remains stable when browser chrome consumes
/// extra height in landscape.
Size? getDeviceScreenSize(BuildContext context) {
  final screen = html.window.screen;
  if (screen != null) {
    final width = screen.width?.toDouble();
    final height = screen.height?.toDouble();
    if (width != null &&
        height != null &&
        width > 0 &&
        height > 0) {
      return Size(width, height);
    }
  }

  final view = View.of(context);
  final devicePixelRatio = view.devicePixelRatio;
  if (!devicePixelRatio.isFinite || devicePixelRatio <= 0) return null;

  final size = view.physicalSize / devicePixelRatio;
  if (size.width <= 0 || size.height <= 0) return null;
  return size;
}