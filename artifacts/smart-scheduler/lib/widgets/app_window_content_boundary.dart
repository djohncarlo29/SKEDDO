import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

/// Establishes the app-wide content rectangle inside the physical window.
///
/// The window background remains outside this boundary so system/cutout areas
/// never reveal the engine's default clear color. In landscape, the larger
/// horizontal system inset is reserved on both sides, regardless of which
/// physical side currently reports the cutout or system area.
class AppWindowContentBoundary extends StatelessWidget {
  const AppWindowContentBoundary({super.key, required this.child});

  final Widget child;

  /// Returns the symmetric landscape reservation derived from platform data.
  ///
  /// [mediaQuery] is the live inherited window metrics. [viewData] is read
  /// directly from the underlying FlutterView when available, so a descendant
  /// route's rewritten MediaQuery cannot erase the physical window inset.
  static double landscapeSystemInsetFor(
    MediaQueryData mediaQuery,
    MediaQueryData viewData,
  ) {
    if (viewData.size.width <= viewData.size.height) return 0.0;

    return math.max(
      math.max(
        math.max(viewData.padding.left, viewData.padding.right),
        math.max(viewData.viewPadding.left, viewData.viewPadding.right),
      ),
      math.max(
        viewData.systemGestureInsets.left,
        viewData.systemGestureInsets.right,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final view = View.maybeOf(context);
    final viewData = view == null ? mediaQuery : MediaQueryData.fromView(view);
    final horizontalInset = landscapeSystemInsetFor(mediaQuery, viewData);

    if (horizontalInset <= 0.0) return child;

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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      child: MediaQuery(data: contentMediaQuery, child: child),
    );
  }
}
