import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';

void main() {
  test('reserves the same landscape inset regardless of physical side', () {
    final landscape = MediaQueryData(size: const Size(844, 390));
    final leftCutout = landscape.copyWith(
      viewPadding: const EdgeInsets.only(left: 52),
    );
    final rightCutout = landscape.copyWith(
      viewPadding: const EdgeInsets.only(right: 52),
    );

    expect(
      AppWindowContentBoundary.landscapeSystemInsetFor(landscape, leftCutout),
      52,
    );
    expect(
      AppWindowContentBoundary.landscapeSystemInsetFor(landscape, rightCutout),
      52,
    );
  });

  test('does not reserve horizontal landscape space in portrait', () {
    final portrait = MediaQueryData(size: const Size(390, 844));
    final withInset = portrait.copyWith(
      viewPadding: const EdgeInsets.only(left: 52),
    );

    expect(
      AppWindowContentBoundary.landscapeSystemInsetFor(portrait, withInset),
      0,
    );
  });

  test('uses the largest physical horizontal platform reservation', () {
    final landscape = MediaQueryData(size: const Size(844, 390));
    final withPlatformInsets = landscape.copyWith(
      padding: const EdgeInsets.only(right: 24),
      viewPadding: const EdgeInsets.only(right: 48),
      systemGestureInsets: const EdgeInsets.only(left: 56),
    );

    expect(
      AppWindowContentBoundary.landscapeSystemInsetFor(
        landscape,
        withPlatformInsets,
      ),
      56,
    );
  });
}
