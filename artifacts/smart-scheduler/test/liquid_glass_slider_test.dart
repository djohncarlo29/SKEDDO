import 'package:flutter/cupertino.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, GlassTabBar;
import 'package:flutter_test/flutter_test.dart';

import '../lib/app_settings.dart';
import '../lib/widgets/floating_tab_pill.dart';
import '../lib/widgets/skeddo_glass_settings.dart';

void main() {
  test('shared glass blur uses piecewise linear slider interpolation', () {
    expect(skeddoSharedGlassBlurForPosition(0), closeTo(0.01, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.25), closeTo(0.05, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.5), closeTo(0.5, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.75), closeTo(1, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(1), closeTo(5, 0.000001));

    expect(skeddoSharedGlassBlurForPosition(0.125), closeTo(0.03, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.375), closeTo(0.275, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.625), closeTo(0.75, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.875), 3);
  });

  test('settled tab lens has its own interpolated blur curve', () {
    expect(skeddoActiveTabIndicatorBlurForPosition(0), 0.5);
    expect(skeddoActiveTabIndicatorBlurForPosition(0.25), 1);
    expect(skeddoActiveTabIndicatorBlurForPosition(0.5), 2);
    expect(skeddoActiveTabIndicatorBlurForPosition(0.75), 3);
    expect(skeddoActiveTabIndicatorBlurForPosition(1), 5);

    expect(
      skeddoActiveTabIndicatorBlurForPosition(0.125),
      closeTo(0.75, 0.000001),
    );
    expect(
      skeddoActiveTabIndicatorBlurForPosition(0.375),
      closeTo(1.5, 0.000001),
    );
    expect(
      skeddoActiveTabIndicatorBlurForPosition(0.625),
      closeTo(2.5, 0.000001),
    );
    expect(
      skeddoActiveTabIndicatorBlurForPosition(0.875),
      closeTo(4, 0.000001),
    );
  });

  test('Liquid Glass slider positions settle on whole percentages', () {
    expect(quantizeLiquidGlassSliderPosition(0.756), 0.76);
    expect(
      liquidGlassOpacityForSliderPosition(0.756),
      closeTo(0.656, 0.000001),
    );
    expect(liquidGlassSliderPositionForOpacity(0.656), 0.76);
  });

  testWidgets('tab bar and shared surfaces follow the same slider blur', (
    tester,
  ) async {
    final originalOpacity = appLiquidGlassOpacityNotifier.value;
    addTearDown(() {
      appLiquidGlassOpacityNotifier.value = originalOpacity;
    });

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.75,
    );
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.light),
        home: Stack(
          children: [
            Positioned.fill(
              child: FloatingTabPill(
                selectedIndex: 0,
                eventsAccent: const Color(0xFF007AFF),
                onTabSelected: (_) {},
                onCreateEvent: () {},
              ),
            ),
          ],
        ),
      ),
    );

    var tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(tabBar.settings!.blur, 1);
    expect(skeddoBottomBarGlassSettingsFor(Brightness.light).blur, 1);
    expect(tabBar.innerBlur, 3);

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.5,
    );
    await tester.pump();

    tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(tabBar.settings!.blur, 0.5);
    expect(skeddoBottomBarGlassSettingsFor(Brightness.light).blur, 0.5);
    expect(tabBar.innerBlur, 2);
  });

  testWidgets('settings glass preview updates on every slider change', (
    tester,
  ) async {
    final originalOpacity = appLiquidGlassOpacityNotifier.value;
    addTearDown(() {
      appLiquidGlassOpacityNotifier.value = originalOpacity;
    });

    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.light),
        home: SizedBox(
          height: 300,
          child: ValueListenableBuilder<double>(
            valueListenable: appLiquidGlassOpacityNotifier,
            builder: (context, value, _) => FloatingTabBarGlassPreview(
              sliderPosition: liquidGlassSliderPositionForOpacity(value),
            ),
          ),
        ),
      ),
    );

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.25,
    );
    await tester.pump();
    var previewGlass = tester.widget<GlassContainer>(
      find.byType(GlassContainer),
    );
    expect(previewGlass.settings!.blur, closeTo(0.05, 0.000001));

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.75,
    );
    await tester.pump();
    previewGlass = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(previewGlass.settings!.blur, 1);
  });
}
