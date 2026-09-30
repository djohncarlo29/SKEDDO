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

    expect(AppWindowContentBoundary.landscapeSystemInsetFor(leftCutout), 52);
    expect(AppWindowContentBoundary.landscapeSystemInsetFor(rightCutout), 52);
  });

  test('does not reserve horizontal landscape space in portrait', () {
    final portrait = MediaQueryData(size: const Size(390, 844));
    final withInset = portrait.copyWith(
      viewPadding: const EdgeInsets.only(left: 52),
    );

    expect(AppWindowContentBoundary.landscapeSystemInsetFor(withInset), 0);
  });

  test('uses only persistent view padding, not padding or gesture insets', () {
    final landscape = MediaQueryData(size: const Size(844, 390));
    final withPlatformInsets = landscape.copyWith(
      padding: const EdgeInsets.only(right: 96),
      viewPadding: const EdgeInsets.only(right: 48),
      viewInsets: const EdgeInsets.only(left: 120),
      systemGestureInsets: const EdgeInsets.only(left: 144),
    );

    expect(
      AppWindowContentBoundary.landscapeSystemInsetFor(withPlatformInsets),
      48,
    );
  });

  test('keyboard viewInsets do not change the landscape reservation', () {
    final base = MediaQueryData(
      size: const Size(844, 390),
      viewPadding: const EdgeInsets.only(left: 52),
    );
    final keyboardVisible = base.copyWith(
      viewInsets: const EdgeInsets.only(bottom: 280),
      padding: const EdgeInsets.only(bottom: 280),
    );

    expect(
      AppWindowContentBoundary.landscapeSystemInsetFor(keyboardVisible),
      AppWindowContentBoundary.landscapeSystemInsetFor(base),
    );
  });

  testWidgets('content padding clears one-sided insets for nested safe areas', (
    tester,
  ) async {
    EdgeInsets? nestedPadding;
    EdgeInsets? nestedViewPadding;
    EdgeInsets? nestedGestureInsets;
    double? reservedInset;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(844, 390),
          padding: EdgeInsets.only(left: 52),
          viewPadding: EdgeInsets.only(left: 52),
          systemGestureInsets: EdgeInsets.only(left: 52),
        ),
        child: AppWindowContentBoundary(
          child: AppWindowContentPadding(
            child: Builder(
              builder: (context) {
                reservedInset =
                    AppWindowContentScope.of(context).horizontalInset;
                nestedPadding = MediaQuery.paddingOf(context);
                nestedViewPadding = MediaQuery.viewPaddingOf(context);
                nestedGestureInsets = MediaQuery.systemGestureInsetsOf(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );

    expect(reservedInset, 52);
    expect(nestedPadding!.left, 0);
    expect(nestedPadding!.right, 0);
    expect(nestedViewPadding!.left, 0);
    expect(nestedViewPadding!.right, 0);
    expect(nestedGestureInsets!.left, 0);
    expect(nestedGestureInsets!.right, 0);
  });

  testWidgets('content padding preserves portrait safe areas', (tester) async {
    EdgeInsets? nestedPadding;
    EdgeInsets? nestedViewPadding;
    double? reservedInset;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(left: 18),
          viewPadding: EdgeInsets.only(left: 18),
        ),
        child: AppWindowContentBoundary(
          child: AppWindowContentPadding(
            child: Builder(
              builder: (context) {
                reservedInset =
                    AppWindowContentScope.of(context).horizontalInset;
                nestedPadding = MediaQuery.paddingOf(context);
                nestedViewPadding = MediaQuery.viewPaddingOf(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );

    expect(reservedInset, 0);
    expect(nestedPadding!.left, 18);
    expect(nestedViewPadding!.left, 18);
  });
}
