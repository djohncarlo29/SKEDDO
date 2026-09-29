import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import '../services/window_geometry_diagnostics.dart';

/// Establishes the app-wide content rectangle inside the physical window.
///
/// The window background remains outside this boundary so system/cutout areas
/// never reveal the engine's default clear color. In landscape, the larger
/// horizontal system inset is reserved on both sides, regardless of which
/// physical side currently reports the cutout or system area.
class AppWindowContentBoundary extends StatelessWidget {
  const AppWindowContentBoundary({
    super.key,
    required this.background,
    required this.child,
  });

  final Widget background;
  final Widget child;

  /// Returns the symmetric landscape reservation from the persistent platform
  /// safe area.
  ///
  /// This intentionally uses only [MediaQueryData.viewPadding]. It represents
  /// the platform safe area for the physical window and is independent of the
  /// keyboard. Gesture, tappable-element, and descendant [padding] insets are
  /// separate concepts and must not widen this app-wide reservation.
  static double landscapeSystemInsetFor(MediaQueryData mediaQuery) {
    if (mediaQuery.size.width <= mediaQuery.size.height) return 0.0;

    return math.max(mediaQuery.viewPadding.left, mediaQuery.viewPadding.right);
  }

  @override
  Widget build(BuildContext context) {
    WindowGeometryDiagnostics.report(context);
    final mediaQuery = MediaQuery.of(context);
    // Read the persistent platform inset from MediaQuery.viewPadding. Do not
    // use padding (which can be rewritten by a route or affected by the IME),
    // viewInsets (keyboard), or gesture insets for this reservation.
    final viewPadding = MediaQuery.viewPaddingOf(context);
    final horizontalInset = landscapeSystemInsetFor(
      mediaQuery.copyWith(viewPadding: viewPadding),
    );

    Widget content = child;
    if (horizontalInset > 0.0) {
      final contentWidth = math.max(
        0.0,
        mediaQuery.size.width - horizontalInset * 2.0,
      );
      final contentMediaQuery = mediaQuery.copyWith(
        size: Size(contentWidth, mediaQuery.size.height),
        // The shared boundary owns the horizontal system space. Clearing these
        // fields prevents SafeArea or a nested route from adding the same inset
        // a second time inside the already-reserved content rectangle.
        padding: mediaQuery.padding.copyWith(left: 0.0, right: 0.0),
        viewPadding: mediaQuery.viewPadding.copyWith(left: 0.0, right: 0.0),
        systemGestureInsets: mediaQuery.systemGestureInsets.copyWith(
          left: 0.0,
          right: 0.0,
        ),
      );
      content = Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalInset),
        child: MediaQuery(data: contentMediaQuery, child: child),
      );
    }

    // Backgrounds belong to the physical window, not to the inset content
    // rectangle. This keeps header/content surfaces continuous through the
    // reserved system area while the actual Navigator/UI subtree remains
    // constrained by the symmetric landscape boundary.
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: background),
        Positioned.fill(child: content),
      ],
    );
  }
}
