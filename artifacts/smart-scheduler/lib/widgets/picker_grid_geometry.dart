import 'dart:math' as math;

import 'package:flutter/cupertino.dart';

/// A complete, renderer-independent geometry description for a picker grid.
///
/// The [viewportWidth] is the width of the picker row/card. The geometry owns
/// the horizontal inset, so renderers do not add a second padding model or ask
/// Wrap/Stack to make independent layout decisions.
class PickerGridGeometry {
  const PickerGridGeometry({
    required this.viewportWidth,
    required this.contentBounds,
    required this.horizontalInset,
    required this.verticalInset,
    required this.itemSize,
    required this.columns,
    required this.rows,
    required this.horizontalGap,
    required this.verticalGap,
    required this.height,
    required this.itemRects,
  });

  final double viewportWidth;
  final Rect contentBounds;
  final double horizontalInset;
  final double verticalInset;
  final double itemSize;
  final int columns;
  final int rows;
  final double horizontalGap;
  final double verticalGap;
  final double height;
  final List<Rect> itemRects;

  double get contentWidth => contentBounds.width;

  /// Calculates the portrait-sized item target used by icon and emoji grids.
  ///
  /// The authored column count establishes the portrait baseline. Increasing
  /// text size increases the target item size; it never causes a later
  /// landscape calculation to stretch items merely to consume extra width.
  static double scaledPortraitItemSize({
    required double viewportWidth,
    required double horizontalInset,
    required int authoredColumns,
    required double minimumGap,
    required double textScaleRatio,
    double? maximumItemSize,
  }) {
    final contentWidth = math.max(
      1.0,
      viewportWidth - 2 * horizontalInset,
    );
    final baselineItemSize = math.max(
      1.0,
      (contentWidth - minimumGap * (authoredColumns - 1)) /
          authoredColumns,
    );
    final cappedBaseline = maximumItemSize == null
        ? baselineItemSize
        : math.min(maximumItemSize, baselineItemSize);
    return math.max(1.0, cappedBaseline * textScaleRatio);
  }

  /// Resolves one complete grid from an explicit target item size.
  ///
  factory PickerGridGeometry.resolve({
    required int itemCount,
    required double viewportWidth,
    required double horizontalInset,
    required double targetItemSize,
    required double minimumHorizontalGap,
    required double verticalGap,
    double verticalInset = 0.0,
    required int authoredMaximumColumns,
  }) {
    final contentWidth = math.max(
      1.0,
      viewportWidth - 2 * horizontalInset,
    );
    final automaticColumns = math.max(
      1,
      math.min(
        itemCount,
        math.min(
          authoredMaximumColumns,
          ((contentWidth + minimumHorizontalGap + 0.001) /
                  (targetItemSize + minimumHorizontalGap))
              .floor(),
        ),
      ),
    );
    final columns = math.max(
      1,
      math.min(
        itemCount,
        math.min(
          authoredMaximumColumns,
          automaticColumns,
        ),
      ),
    );
    final horizontalGap = columns > 1
        ? math.max(
            minimumHorizontalGap,
            (contentWidth - columns * targetItemSize) / (columns - 1),
          )
        : 0.0;
    final rows = (itemCount / columns).ceil();
    final itemAreaHeight =
        rows * targetItemSize + math.max(0, rows - 1) * verticalGap;
    final height = 2 * verticalInset + itemAreaHeight;
    final contentBounds = Rect.fromLTWH(
      horizontalInset,
      verticalInset,
      contentWidth,
      itemAreaHeight,
    );
    final itemRects = List<Rect>.generate(itemCount, (index) {
      return Rect.fromLTWH(
        horizontalInset +
            (index % columns) * (targetItemSize + horizontalGap),
        verticalInset + (index ~/ columns) * (targetItemSize + verticalGap),
        targetItemSize,
        targetItemSize,
      );
    });
    return PickerGridGeometry(
      viewportWidth: viewportWidth,
      contentBounds: contentBounds,
      horizontalInset: horizontalInset,
      verticalInset: verticalInset,
      itemSize: targetItemSize,
      columns: columns,
      rows: rows,
      horizontalGap: horizontalGap,
      verticalGap: verticalGap,
      height: height,
      itemRects: itemRects,
    );
  }

  /// Resolves the landscape geometry from the same portrait baseline.
  ///
  /// The item size and vertical gap are inherited from [portrait]. Only the
  /// available column capacity and horizontal breathing room change.
  factory PickerGridGeometry.landscape({
    required PickerGridGeometry portrait,
    required int itemCount,
    required double viewportWidth,
    required double horizontalInset,
    required int authoredMaximumColumns,
  }) {
    final contentWidth = math.max(
      1.0,
      viewportWidth - 2 * horizontalInset,
    );
    final automaticColumns = math.max(
      1,
      math.min(
        itemCount,
        math.min(
          authoredMaximumColumns,
          ((contentWidth + portrait.horizontalGap + 0.001) /
                  (portrait.itemSize + portrait.horizontalGap))
              .floor(),
        ),
      ),
    );
    final columns = math.max(
      1,
      math.min(
        itemCount,
        math.min(
          authoredMaximumColumns,
          automaticColumns,
        ),
      ),
    );
    final horizontalGap = columns > 1
        ? math.max(
            portrait.horizontalGap,
            (contentWidth - columns * portrait.itemSize) / (columns - 1),
          )
        : 0.0;
    final rows = (itemCount / columns).ceil();
    final itemAreaHeight = rows * portrait.itemSize +
        math.max(0, rows - 1) * portrait.verticalGap;
    final height = 2 * portrait.verticalInset + itemAreaHeight;
    final contentBounds = Rect.fromLTWH(
      horizontalInset,
      portrait.verticalInset,
      contentWidth,
      itemAreaHeight,
    );
    final itemRects = List<Rect>.generate(itemCount, (index) {
      return Rect.fromLTWH(
        horizontalInset +
            (index % columns) * (portrait.itemSize + horizontalGap),
        portrait.verticalInset +
            (index ~/ columns) * (portrait.itemSize + portrait.verticalGap),
        portrait.itemSize,
        portrait.itemSize,
      );
    });
    return PickerGridGeometry(
      viewportWidth: viewportWidth,
      contentBounds: contentBounds,
      horizontalInset: horizontalInset,
      verticalInset: portrait.verticalInset,
      itemSize: portrait.itemSize,
      columns: columns,
      rows: rows,
      horizontalGap: horizontalGap,
      verticalGap: portrait.verticalGap,
      height: height,
      itemRects: itemRects,
    );
  }
}