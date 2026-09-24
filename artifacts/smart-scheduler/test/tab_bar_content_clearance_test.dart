import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart';

void main() {
  testWidgets('classic native tab bar reserves bar and safe-area height', (
    tester,
  ) async {
    final previousMode = usesClassicNativeTabBarForLayout.value;
    addTearDown(() {
      usesClassicNativeTabBarForLayout.value = previousMode;
    });

    usesClassicNativeTabBarForLayout.value = true;
    final clearance = await _measureClearance(tester);

    expect(
      clearance,
      kClassicNativeTabBarHeight + 34.0 + kClassicNativeTabBarMinimumContentGap,
    );
  });

  testWidgets('classic native tab bar preserves larger requested gaps', (
    tester,
  ) async {
    final previousMode = usesClassicNativeTabBarForLayout.value;
    addTearDown(() {
      usesClassicNativeTabBarForLayout.value = previousMode;
    });

    usesClassicNativeTabBarForLayout.value = true;
    final clearance = await _measureClearance(tester, finalContentGap: 20.0);

    expect(clearance, kClassicNativeTabBarHeight + 34.0 + 20.0);
  });

  testWidgets('floating tab bar keeps its existing clearance', (tester) async {
    final previousMode = usesClassicNativeTabBarForLayout.value;
    addTearDown(() {
      usesClassicNativeTabBarForLayout.value = previousMode;
    });

    usesClassicNativeTabBarForLayout.value = false;
    final clearance = await _measureClearance(tester);

    expect(clearance, kFloatingTabBarHeight + 34.0 + 12.0);
  });
}

Future<double> _measureClearance(
  WidgetTester tester, {
  double? finalContentGap,
}) async {
  var clearance = 0.0;
  await tester.pumpWidget(
    MediaQuery(
      data: const MediaQueryData(
        viewPadding: EdgeInsets.only(bottom: 34.0),
        systemGestureInsets: EdgeInsets.only(bottom: 34.0),
      ),
      child: Builder(
        builder: (context) {
          clearance = floatingTabBarContentBottomClearance(
            context,
            finalContentGap: finalContentGap ?? kFloatingTabBarSafetyMargin,
          );
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  return clearance;
}
