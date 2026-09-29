import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/picker_grid_geometry.dart';

const _horizontalInset = 16.0;
const _portraitWidth = 390.0;
const _landscapeWidth = 844.0;
const _epsilon = 0.000001;

class _PickerCase {
  final String name;
  final int itemCount;
  final int authoredColumns;
  final double minimumGap;
  final double verticalGap;
  final double verticalInset;
  final double? maximumItemSize;
  final bool scalesSpacingWithText;

  const _PickerCase({
    required this.name,
    required this.itemCount,
    required this.authoredColumns,
    required this.minimumGap,
    required this.verticalGap,
    this.verticalInset = 0.0,
    this.maximumItemSize,
    this.scalesSpacingWithText = true,
  });

  PickerGridGeometry portrait({double textScaleRatio = 1.0}) {
    final scaledGap = scalesSpacingWithText
        ? minimumGap * textScaleRatio
        : minimumGap;
    final targetItemSize = PickerGridGeometry.scaledPortraitItemSize(
      viewportWidth: _portraitWidth,
      horizontalInset: _horizontalInset,
      authoredColumns: authoredColumns,
      minimumGap: scaledGap,
      textScaleRatio: textScaleRatio,
      maximumItemSize: maximumItemSize,
    );
    return PickerGridGeometry.resolve(
      itemCount: itemCount,
      viewportWidth: _portraitWidth,
      horizontalInset: _horizontalInset,
      targetItemSize: targetItemSize,
      minimumHorizontalGap: scaledGap,
      verticalGap: scalesSpacingWithText
          ? verticalGap * textScaleRatio
          : verticalGap,
      verticalInset: verticalInset * textScaleRatio,
      authoredMaximumColumns: authoredColumns,
    );
  }

  PickerGridGeometry landscape({double textScaleRatio = 1.0}) {
    return PickerGridGeometry.landscape(
      portrait: portrait(textScaleRatio: textScaleRatio),
      itemCount: itemCount,
      viewportWidth: _landscapeWidth,
      horizontalInset: _horizontalInset,
      authoredMaximumColumns: itemCount,
    );
  }
}

const _pickerCases = [
  _PickerCase(
    name: 'Color',
    itemCount: 12,
    authoredColumns: 6,
    minimumGap: 16,
    maximumItemSize: 43,
    verticalGap: 16,
    scalesSpacingWithText: false,
  ),
  _PickerCase(
    name: 'Icon',
    itemCount: 72,
    authoredColumns: 7,
    minimumGap: 6,
    verticalGap: 6,
  ),
  _PickerCase(
    name: 'Emoji',
    itemCount: 72,
    authoredColumns: 7,
    minimumGap: 2,
    verticalGap: 2,
    verticalInset: 6,
  ),
];

void _expectRowEdges(
  PickerGridGeometry geometry, {
  required int itemCount,
}) {
  for (var row = 0; row < geometry.rows; row++) {
    final firstIndex = row * geometry.columns;
    final rowItemCount = math.min(
      geometry.columns,
      itemCount - firstIndex,
    );
    final lastIndex = firstIndex + rowItemCount - 1;

    expect(
      geometry.itemRects[firstIndex].left,
      closeTo(_horizontalInset, _epsilon),
      reason: 'row $row must start at the 16pt content inset',
    );

    final lastItem = geometry.itemRects[lastIndex];
    if (rowItemCount == geometry.columns) {
      expect(
        lastItem.right,
        closeTo(geometry.viewportWidth - _horizontalInset, _epsilon),
        reason: '${geometry.viewportWidth}px $row must fill its content width',
      );
    } else {
      expect(
        lastItem.right,
        lessThan(geometry.viewportWidth - _horizontalInset),
        reason: 'incomplete row $row must remain start-aligned',
      );
    }
  }
}

void main() {
  test('portrait geometry owns the 16pt content inset', () {
    final target = PickerGridGeometry.scaledPortraitItemSize(
      viewportWidth: 390,
      horizontalInset: 16,
      authoredColumns: 7,
      minimumGap: 6,
      textScaleRatio: 1,
    );
    final geometry = PickerGridGeometry.resolve(
      itemCount: 72,
      viewportWidth: 390,
      horizontalInset: 16,
      targetItemSize: target,
      minimumHorizontalGap: 6,
      verticalGap: 6,
      authoredMaximumColumns: 72,
    );

    expect(geometry.itemRects.first.left, 16);
    expect(geometry.itemRects.first.top, 0);
    expect(geometry.contentBounds.left, 16);
    expect(geometry.contentBounds.right, 374);
  });

  test('landscape preserves portrait item size and expands gaps', () {
    final portrait = PickerGridGeometry.resolve(
      itemCount: 72,
      viewportWidth: 390,
      horizontalInset: 16,
      targetItemSize: 40,
      minimumHorizontalGap: 6,
      verticalGap: 6,
      authoredMaximumColumns: 72,
    );
    final landscape = PickerGridGeometry.landscape(
      portrait: portrait,
      itemCount: 72,
      viewportWidth: 844,
      horizontalInset: 16,
      authoredMaximumColumns: 72,
    );

    expect(landscape.itemSize, portrait.itemSize);
    expect(landscape.verticalGap, portrait.verticalGap);
    expect(landscape.horizontalGap, greaterThanOrEqualTo(portrait.horizontalGap));
    expect(
      landscape.itemRects
          .where((rect) => rect.right == landscape.viewportWidth - 16)
          .length,
      greaterThan(0),
    );
  });

  test('vertical inset contributes to total grid height, not item size', () {
    final geometry = PickerGridGeometry.resolve(
      itemCount: 14,
      viewportWidth: 390,
      horizontalInset: 16,
      targetItemSize: 40,
      minimumHorizontalGap: 6,
      verticalGap: 6,
      verticalInset: 6,
      authoredMaximumColumns: 7,
    );

    expect(geometry.itemRects.first.top, 6);
    expect(geometry.height, 2 * 6 + 2 * 40 + 6);
    expect(geometry.itemSize, 40);
  });

  test('all picker configurations keep the actual 16pt row edges', () {
    for (final picker in _pickerCases) {
      final geometry = picker.portrait();

      expect(
        geometry.contentBounds.left,
        closeTo(_horizontalInset, _epsilon),
        reason: '${picker.name} content must begin at 16pt',
      );
      expect(
        geometry.contentBounds.right,
        closeTo(_portraitWidth - _horizontalInset, _epsilon),
        reason: '${picker.name} content must end at 16pt',
      );
      _expectRowEdges(geometry, itemCount: picker.itemCount);
    }
  });

  test('landscape preserves each picker baseline and never shrinks its gap', () {
    for (final picker in _pickerCases) {
      final portrait = picker.portrait();
      final landscape = picker.landscape();

      expect(
        landscape.itemSize,
        closeTo(portrait.itemSize, _epsilon),
        reason: '${picker.name} item size must remain portrait-derived',
      );
      expect(
        landscape.verticalGap,
        closeTo(portrait.verticalGap, _epsilon),
        reason: '${picker.name} vertical gap must remain portrait-derived',
      );
      if (portrait.columns > 1 && landscape.columns > 1) {
        expect(
          landscape.horizontalGap,
          greaterThanOrEqualTo(portrait.horizontalGap),
          reason: '${picker.name} landscape gap cannot shrink',
        );
      }
      _expectRowEdges(landscape, itemCount: picker.itemCount);
    }
  });

  test('icon and emoji incomplete final rows stay start-aligned', () {
    for (final picker in _pickerCases.where(
      (picker) => picker.name == 'Icon' || picker.name == 'Emoji',
    )) {
      final geometry = picker.portrait();
      final firstIndex = (geometry.rows - 1) * geometry.columns;
      final lastIndex = geometry.itemRects.length - 1;
      final remainder = picker.itemCount % geometry.columns;

      expect(remainder, greaterThan(0), reason: '${picker.name} must be partial');
      expect(
        geometry.itemRects[firstIndex].left,
        closeTo(_horizontalInset, _epsilon),
      );
      expect(
        geometry.itemRects[lastIndex].right,
        lessThan(geometry.viewportWidth - _horizontalInset),
        reason: '${picker.name} partial row must not distribute extra space',
      );
      expect(
        geometry.itemRects[lastIndex].left,
        closeTo(
          _horizontalInset +
              (remainder - 1) *
                  (geometry.itemSize + geometry.horizontalGap),
          _epsilon,
        ),
      );
    }
  });

  test('larger text scales preserve inset, gap, and bounds', () {
    const textScaleRatios = [1.0, 1.15, 1.3, 1.5, 2.0, 3.2];

    for (final picker in _pickerCases) {
      for (final textScaleRatio in textScaleRatios) {
        final geometry = picker.portrait(
          textScaleRatio: textScaleRatio,
        );

        expect(
          geometry.itemSize,
          greaterThan(0),
          reason: '${picker.name} must retain a positive item size',
        );
        expect(
          geometry.itemRects.every(
            (rect) =>
                rect.left >= _horizontalInset - _epsilon &&
                rect.right <=
                    geometry.viewportWidth - _horizontalInset + _epsilon,
          ),
          isTrue,
          reason: '${picker.name} scale $textScaleRatio must stay in bounds',
        );
        if (geometry.columns > 1) {
          final expectedMinimumGap = picker.scalesSpacingWithText
              ? picker.minimumGap * textScaleRatio
              : picker.minimumGap;
          expect(
            geometry.horizontalGap,
            greaterThanOrEqualTo(expectedMinimumGap),
            reason: '${picker.name} scale $textScaleRatio shrank the gap',
          );
        }
      }
    }
  });
}