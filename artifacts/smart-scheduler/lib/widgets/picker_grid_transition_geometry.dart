import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

import 'live_rotation_geometry.dart';
import 'picker_grid_geometry.dart';

/// Transition-only operations for already-resolved picker geometries.
///
/// [PickerGridGeometry] remains the sole authority for settled layout
/// calculation. This adapter only derives endpoint viewport widths from the
/// live window and interpolates the endpoint result for the current frame.
class PickerGridTransitionGeometry {
  const PickerGridTransitionGeometry._();

  /// Projects a picker viewport width from a live window endpoint.
  ///
  /// The picker cards in the current sheets have a stable horizontal inset
  /// from the window. Preserving that difference lets the endpoint geometry
  /// use the same card-relative width as the live constraints.
  static double endpointViewportWidth({
    required RotationGeometryData rotation,
    required double currentViewportWidth,
    required bool landscape,
  }) {
    final windowToViewportInset =
        rotation.windowSize.width - currentViewportWidth;
    final endpointWindowWidth =
        landscape ? rotation.landscapeSize.width : rotation.portraitSize.width;
    return math.max(1.0, endpointWindowWidth - windowToViewportInset);
  }

  /// Interpolates all visual geometry fields between two settled endpoints.
  ///
  /// Item count is unchanged during rotation, so item rectangles can be
  /// interpolated by index even when the endpoint column/row counts differ.
  /// Integer row/column metadata is only used for non-visual bookkeeping by
  /// the current renderers and follows the nearer endpoint.
  static PickerGridGeometry interpolate({
    required PickerGridGeometry portrait,
    required PickerGridGeometry landscape,
    required double progress,
  }) {
    final t = progress.clamp(0.0, 1.0);
    if (t <= 0.0) return portrait;
    if (t >= 1.0) return landscape;

    double lerp(double a, double b) => a + (b - a) * t;

    Rect lerpRect(Rect a, Rect b) => Rect.fromLTRB(
      lerp(a.left, b.left),
      lerp(a.top, b.top),
      lerp(a.right, b.right),
      lerp(a.bottom, b.bottom),
    );

    final itemRects = List<Rect>.generate(
      math.min(portrait.itemRects.length, landscape.itemRects.length),
      (index) => lerpRect(
        portrait.itemRects[index],
        landscape.itemRects[index],
      ),
    );

    return PickerGridGeometry(
      viewportWidth: lerp(portrait.viewportWidth, landscape.viewportWidth),
      contentBounds: lerpRect(
        portrait.contentBounds,
        landscape.contentBounds,
      ),
      horizontalInset: lerp(
        portrait.horizontalInset,
        landscape.horizontalInset,
      ),
      verticalInset: lerp(portrait.verticalInset, landscape.verticalInset),
      itemSize: lerp(portrait.itemSize, landscape.itemSize),
      columns: t < 0.5 ? portrait.columns : landscape.columns,
      rows: t < 0.5 ? portrait.rows : landscape.rows,
      horizontalGap: lerp(
        portrait.horizontalGap,
        landscape.horizontalGap,
      ),
      verticalGap: lerp(portrait.verticalGap, landscape.verticalGap),
      height: lerp(portrait.height, landscape.height),
      itemRects: itemRects,
    );
  }
}