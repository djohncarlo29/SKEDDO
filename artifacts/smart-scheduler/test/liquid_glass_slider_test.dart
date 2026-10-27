import 'package:flutter/cupertino.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, GlassTabBar, LiquidGlassSettings;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassSlider;

import 'package:smart_scheduler/app_settings.dart';
import 'package:smart_scheduler/widgets/floating_tab_pill.dart';
import 'package:smart_scheduler/widgets/skeddo_glass_settings.dart';

void main() {
  test('shared glass blur uses piecewise linear slider interpolation', () {
    expect(skeddoSharedGlassBlurForPosition(0), closeTo(0.01, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.25), closeTo(0.57, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.5), closeTo(1.7, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.75), closeTo(4.41, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(1), closeTo(10, 0.000001));

    expect(skeddoSharedGlassBlurForPosition(0.125), closeTo(0.2893, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.375), closeTo(0.855, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.625), closeTo(2.775, 0.000001));
    expect(skeddoSharedGlassBlurForPosition(0.875), closeTo(7.205, 0.000001));
  });

  test('settled tab lens has its own interpolated blur curve', () {
    expect(skeddoActiveTabIndicatorBlurForPosition(0), 0.5);
    expect(
      skeddoActiveTabIndicatorBlurForPosition(0.25),
      closeTo(1.14, 0.000001),
    );
    expect(
      skeddoActiveTabIndicatorBlurForPosition(0.5),
      closeTo(2.7, 0.000001),
    );
    expect(
      skeddoActiveTabIndicatorBlurForPosition(0.75),
      closeTo(5.55, 0.000001),
    );
    expect(skeddoActiveTabIndicatorBlurForPosition(1), 12);

    expect(
      skeddoActiveTabIndicatorBlurForPosition(0.125),
      closeTo(0.785, 0.000001),
    );
    expect(
      skeddoActiveTabIndicatorBlurForPosition(0.375),
      closeTo(1.71, 0.000001),
    );
    expect(
      skeddoActiveTabIndicatorBlurForPosition(0.625),
      closeTo(3.775, 0.000001),
    );
    expect(
      skeddoActiveTabIndicatorBlurForPosition(0.875),
      closeTo(8.775, 0.000001),
    );
  });

  test('shared renderer opacity follows the slider in both themes', () {
    const positions = <double>[0, 0.25, 0.5, 0.75, 1];
    const lightValues = <double>[0.20, 0.371, 0.528, 0.614, 0.70];
    const darkValues = <double>[0.30, 0.471, 0.628, 0.714, 0.80];

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
      closeTo(0.2855, 0.000001),
    );
    expect(
      skeddoSharedGlassOpacityForPosition(0.875, Brightness.dark),
      closeTo(0.757, 0.000001),
    );
  });

  test('50% reproduces the former 57% effect values and endpoints stay fixed', () {
    expect(skeddoLiquidGlassEffectPositionForSliderPosition(0), 0);
    expect(skeddoLiquidGlassEffectPositionForSliderPosition(0.5), 0.57);
    expect(skeddoLiquidGlassEffectPositionForSliderPosition(1), 1);
    expect(skeddoSharedGlassBlurForPosition(0.5), closeTo(1.7, 0.000001));
    expect(
      skeddoActiveTabIndicatorBlurForPosition(0.5),
      closeTo(2.7, 0.000001),
    );
    expect(
      skeddoSharedGlassOpacityForPosition(0.5, Brightness.light),
      closeTo(0.528, 0.000001),
    );
    expect(
      skeddoSharedGlassOpacityForPosition(0.5, Brightness.dark),
      closeTo(0.628, 0.000001),
    );
    expect(skeddoPopoverOpacityForPosition(0.5), closeTo(0.907, 0.000001));
    expect(skeddoPopoverBlurForPosition(0.5), closeTo(5.7, 0.000001));
  });

  test('active checkmark optics stay fixed regardless of slider position', () {
    final originalOpacity = appLiquidGlassOpacityNotifier.value;
    addTearDown(() {
      appLiquidGlassOpacityNotifier.value = originalOpacity;
    });

    for (final brightness in [Brightness.light, Brightness.dark]) {
      LiquidGlassSettings? expectedLighting;
      LiquidGlassSettings? expectedRefraction;

      for (final position in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        appLiquidGlassOpacityNotifier.value =
            liquidGlassOpacityForSliderPosition(position);
        final lighting = skeddoActiveCheckmarkGlassSettingsFor(brightness);
        final refraction = skeddoActiveCheckmarkRefractionSettingsFor(
          brightness,
        );

        expectedLighting ??= lighting;
        expectedRefraction ??= refraction;
        expect(lighting, expectedLighting);
        expect(refraction, expectedRefraction);
      }

      expect(expectedLighting!.blur, closeTo(1.7, 0.000001));
      expect(expectedRefraction!.blur, closeTo(1.7, 0.000001));
    }
  });

  test('popover card and button follow their independent opacity curve', () {
    final originalOpacity = appLiquidGlassOpacityNotifier.value;
    addTearDown(() {
      appLiquidGlassOpacityNotifier.value = originalOpacity;
    });

    const tint = Color(0xFF123456);
    const positions = <double>[0, 0.25, 0.5, 0.75, 1];
    const expectedOpacities = <double>[0.85, 0.8785, 0.907, 0.9285, 0.95];
    const expectedBlurs = <double>[1, 2.85, 5.7, 7.85, 10];

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
        closeTo(expectedBlurs[index], 0.000001),
      );
      expect(
        skeddoPopoverGlassSettingsFor(Brightness.light, tint).glassColor.a,
        closeTo(expected, 0.001),
      );
      expect(
        skeddoPopoverGlassSettingsFor(Brightness.light, tint).blur,
        closeTo(expectedBlurs[index], 0.000001),
      );
      expect(
        skeddoPopoverButtonGlassSettingsFor(Brightness.dark, tint).glassColor.a,
        closeTo(expected, 0.001),
      );
      expect(
        skeddoPopoverButtonGlassSettingsFor(Brightness.dark, tint).blur,
        0,
      );
    }

    expect(skeddoPopoverOpacityForPosition(0.125), closeTo(0.86425, 0.000001));
    expect(skeddoPopoverBlurForPosition(0.125), closeTo(1.855, 0.000001));
  });

  test('Liquid Glass slider positions settle on whole percentages', () {
    expect(quantizeLiquidGlassSliderPosition(0.756), 0.76);
    expect(quantizeLiquidGlassSliderPosition(0.49), 0.49);
    expect(
      liquidGlassOpacityForSliderPosition(0.756),
      closeTo(0.656, 0.000001),
    );
    expect(liquidGlassSliderPositionForOpacity(0.656), 0.76);
    expect(settleLiquidGlassSliderPosition(0.49), 0.5);
    expect(settleLiquidGlassSliderPosition(0.51), 0.5);
    expect(settleLiquidGlassSliderPosition(0.48), 0.5);
    expect(settleLiquidGlassSliderPosition(0.52), 0.5);
    expect(settleLiquidGlassSliderPosition(0.47), 0.47);
    expect(settleLiquidGlassSliderPosition(0.53), 0.53);
  });

  testWidgets('the midpoint marker matches Text Size tick styling', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: LiquidGlassSlider(
            value: 0.25,
            onChanged: _ignoreSliderChange,
            stepMarkerValue: 0.5,
            stepMarkerColor: CupertinoColors.tertiaryLabel,
          ),
        ),
      ),
    );

    final markerFinder = find.byKey(
      const ValueKey('liquid-glass-slider-step-marker'),
    );
    expect(markerFinder, findsOneWidget);
    final marker = tester.widget<Container>(markerFinder);
    final markerSize = tester.getSize(markerFinder);
    expect(markerSize.width, 3);
    expect(markerSize.height, 3);
    final markerDecoration = marker.decoration! as BoxDecoration;
    expect(markerDecoration.shape, BoxShape.circle);
    expect(markerDecoration.color, CupertinoColors.tertiaryLabel);
    final markerPositioned = tester.widget<Positioned>(
      find
          .ancestor(of: markerFinder, matching: find.byType(Positioned))
          .first,
    );
    final sliderSize = tester.getSize(find.byType(LiquidGlassSlider));
    expect(
      markerPositioned.top,
      closeTo(sliderSize.height / 2 + 8 - 1.5, 0.001),
    );
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
    expect(tabBar.settings!.blur, closeTo(4.41, 0.000001));
    expect(tabBar.settings!.glassColor.a, closeTo(0.614, 0.001));
    expect(
      skeddoBottomBarGlassSettingsFor(Brightness.light).blur,
      closeTo(4.41, 0.000001),
    );
    expect(
      skeddoBottomBarGlassSettingsFor(Brightness.light).glassColor.a,
      closeTo(0.614, 0.001),
    );
    expect(tabBar.innerBlur, closeTo(5.55, 0.000001));

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.5,
    );
    await tester.pump();

    tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(tabBar.settings!.blur, closeTo(1.7, 0.000001));
    expect(tabBar.settings!.glassColor.a, closeTo(0.528, 0.001));
    expect(
      skeddoBottomBarGlassSettingsFor(Brightness.light).blur,
      closeTo(1.7, 0.000001),
    );
    expect(
      skeddoBottomBarGlassSettingsFor(Brightness.light).glassColor.a,
      closeTo(0.528, 0.001),
    );
    expect(tabBar.innerBlur, closeTo(2.7, 0.000001));
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
    expect(previewGlass.settings!.blur, closeTo(0.57, 0.000001));
    expect(previewGlass.settings!.glassColor.a, closeTo(0.371, 0.001));

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.75,
    );
    await tester.pump();
    previewGlass = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(previewGlass.settings!.blur, closeTo(4.41, 0.000001));
    expect(previewGlass.settings!.glassColor.a, closeTo(0.614, 0.001));
  });
}

void _ignoreSliderChange(double _) {}
