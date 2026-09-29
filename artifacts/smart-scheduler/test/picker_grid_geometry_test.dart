import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/picker_grid_geometry.dart';

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
}