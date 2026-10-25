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
    expect(skeddoSharedGlassBlurForPosition(0.25), closeTo(0.5, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.5), closeTo(1, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.75), closeTo(3.5, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(1), closeTo(10, 0.000001));

    expect(skeddoSharedGlassBlurForPosition(0.125), closeTo(0.255, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.375), closeTo(0.75, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.625), closeTo(2.25, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.875), closeTo(6.75, 0.000001));
  });

  test('settled tab lens has its own interpolated blur curve', () {
    expect(skeddoActiveTabIndicatorBlurForPosition(0), 0.5);
    expect(skeddoActiveTabIndicatorBlurForPosition(0.25), 1);
    expect(skeddoActiveTabIndicatorBlurForPosition(0.5), 2);
    expect(skeddoActiveTabIndicatorBlurForPosition(0.75), 4.5);
    expect(skeddoActiveTabIndicatorBlurForPosition(1), 12);

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
      closeTo(3.25, 0.000001),
    );
    expect(
      skeddoActiveTabIndicatorBlurForPosition(0.875),
      closeTo(8.25, 0.000001),
    );
  });

  test('shared renderer opacity follows the slider in both themes', () {
    const positions = <double>[0, 0.25, 0.5, 0.75, 1];
    const lightValues = <double>[0.20, 0.30, 0.40, 0.50, 0.70];
    const darkValues = <double>[0.30, 0.40, 0.50, 0.60, 0.80];

    for (var index = 0; index < positions.length; index++) {
      expect(
        skeddoSharedGlassOpacityForPosition(positions[index], Brightness.light),
        closeTo(lightValues[index], 0.000001),
      );
      expect(
        skeddoSharedGlassOpacityForPosition(positions[index], Brightness.dark),
        closeTo(darkValues[index], 0.000001),
      );
    }

    expect(
      skeddoSharedGlassOpacityForPosition(0.125, Brightness.light),
      closeTo(0.25, 0.000001),
    );
    expect(
      skeddoSharedGlassOpacityForPosition(0.875, Brightness.dark),
      closeTo(0.70, 0.000001),
    );
  });

  test('popover card and button follow their independent opacity curve', () {
    final originalOpacity = appLiquidGlassOpacityNotifier.value;
    addTearDown(() {
      appLiquidGlassOpacityNotifier.value = originalOpacity;
    });

    const tint = Color(0xFF123456);
    const positions = <double>[0, 0.25, 0.5, 0.75, 1];
    const expectedOpacities = <double>[0.85, 0.875, 0.90, 0.925, 0.95];
    const expectedBlurs = <double>[1, 2.5, 5, 7.5, 10];

    for (var index = 0; index < positions.length; index++) {
      appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
        positions[index],
      );
      final expected = expectedOpacities[index];
      expect(
        skeddoPopoverOpacityForPosition(positions[index]),
        closeTo(expected, 0.000001),
      );
      expect(
        skeddoPopoverBlurForPosition(positions[index]),
        expectedBlurs[index],
      );
      expect(
        skeddoPopoverGlassSettingsFor(Brightness.light, tint).glassColor.a,
        closeTo(expected, 0.001),
      );
      expect(
        skeddoPopoverGlassSettingsFor(Brightness.light, tint).blur,
        expectedBlurs[index],
      );
      expect(
        skeddoPopoverButtonGlassSettingsFor(Brightness.dark, tint).glassColor.a,
        closeTo(expected, 0.001),
      );
      expect(
        skeddoPopoverButtonGlassSettingsFor(Brightness.dark, tint).blur,
        expectedBlurs[index],
      );
    }

    expect(skeddoPopoverOpacityForPosition(0.125), closeTo(0.8625, 0.000001));
    expect(skeddoPopoverBlurForPosition(0.125), closeTo(1.75, 0.000001));
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
    expect(tabBar.settings!.blur, 3.5);
    expect(tabBar.settings!.glassColor.a, closeTo(0.50, 0.001));
    expect(skeddoBottomBarGlassSettingsFor(Brightness.light).blur, 3.5);
    expect(
      skeddoBottomBarGlassSettingsFor(Brightness.light).glassColor.a,
      closeTo(0.50, 0.001),
    );
    expect(tabBar.innerBlur, 4.5);

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.5,
    );
    await tester.pump();

    tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(tabBar.settings!.blur, 1);
    expect(tabBar.settings!.glassColor.a, closeTo(0.40, 0.001));
    expect(skeddoBottomBarGlassSettingsFor(Brightness.light).blur, 1);
    expect(
      skeddoBottomBarGlassSettingsFor(Brightness.light).glassColor.a,
      closeTo(0.40, 0.001),
    );
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
    expect(previewGlass.settings!.blur, closeTo(0.5, 0.000001));
    expect(previewGlass.settings!.glassColor.a, closeTo(0.30, 0.001));

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.75,
    );
    await tester.pump();
    previewGlass = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(previewGlass.settings!.blur, 3.5);
    expect(previewGlass.settings!.glassColor.a, closeTo(0.50, 0.001));
  });
}
