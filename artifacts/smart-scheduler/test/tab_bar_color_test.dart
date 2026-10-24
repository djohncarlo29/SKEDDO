import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassExtraButtonPlacement, GlassTabBar, GlassThemeVariant;
import 'package:smart_scheduler/app_settings.dart'
    show
        appLiquidGlassOpacityNotifier,
        kLiquidGlassMaximumOpacity,
        kLiquidGlassMinimumOpacity;
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/widgets/fixed_size_icon.dart';
import 'package:smart_scheduler/widgets/floating_tab_pill.dart';

void main() {
  testWidgets('inactive tab tint uses the specified light and dark colors', (
    tester,
  ) async {
    for (final entry in [
      (Brightness.light, const Color(0xFF737373)),
      (Brightness.dark, const Color(0xFF8E8E93)),
    ]) {
      Color? resolvedColor;
      await tester.pumpWidget(
        CupertinoApp(
          theme: CupertinoThemeData(brightness: entry.$1),
          home: Builder(
            builder: (context) {
              resolvedColor = CupertinoDynamicColor.resolve(
                kTabBarInactiveColor,
                context,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolvedColor!.value, entry.$2.value);
    }
  });

  testWidgets('Flutter tab bar matches native height and keeps action routing', (
    tester,
  ) async {
    appLiquidGlassOpacityNotifier.value = kLiquidGlassMaximumOpacity;
    const eventsAccent = Color(0xFFDB5500);
    var createEventCalls = 0;
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.light),
        home: Stack(
          children: [
            Positioned.fill(
              child: FloatingTabPill(
                selectedIndex: 2,
                eventsAccent: eventsAccent,
                onTabSelected: (_) {},
                onCreateEvent: () => createEventCalls++,
              ),
            ),
          ],
        ),
      ),
    );

    final context = tester.element(find.byType(FloatingTabPill));
    final tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    final inactiveColor = CupertinoDynamicColor.resolve(
      kTabBarInactiveColor,
      context,
    );

    expect(tabBar.tabs.map((tab) => tab.label), [
      'Notes',
      'Calendar',
      'Events',
    ]);
    expect(tabBar.selectedIconColor!.value, eventsAccent.value);
    expect(tabBar.selectedLabelColor!.value, eventsAccent.value);
    expect(tabBar.unselectedIconColor!.value, inactiveColor.value);
    expect(tabBar.unselectedLabelColor!.value, inactiveColor.value);
    expect(tabBar.extraButton, isNotNull);
    expect(tabBar.extraButton!.label, 'New Event');
    expect(tabBar.extraButton!.iconColor!.value, eventsAccent.value);
    expect(
      tabBar.extraButton!.placement,
      GlassExtraButtonPlacement.right,
    );
    expect(tabBar.extraButton!.size, 49.0);
    expect(tabBar.barHeight, 49.0);
    expect(tabBar.preferredSize.height, 49.0);
    expect(tabBar.horizontalPadding, 20.0);
    expect(tabBar.verticalPadding, 0.0);
    expect(tabBar.iconSize, 20.0);
    expect(tabBar.tabs.map((tab) => (tab.icon! as FixedSFIcon).fontSize), [
      20.0,
      20.0,
      20.0,
    ]);
    expect(tabBar.labelFontSize, 9.0);
    expect(tabBar.magnification, 1.0);
    expect(tabBar.settings, isNotNull);
    expect(tabBar.settings!.glassColor.a, closeTo(0.85, 0.01));
    expect(tabBar.settings!.blur, 40.0);
    expect(tabBar.settings!.saturation, closeTo(1.8, 0.001));
    expect(tabBar.settings!.backerColor!.a, closeTo(0.35, 0.01));
    expect(tabBar.settings!.backerColor!.r, 0.0);
    expect(tabBar.settings!.thickness, 30.0);
    expect(tabBar.settings!.refractiveIndex, 1.59);
    expect(tabBar.indicatorSettings, isNull);
    expect(
      tabBar.indicatorColor!.value,
      kFloatingTabBarLightIndicatorColor.value,
    );

    await tester.tap(find.bySemanticsLabel('New Event'));
    await tester.pump();
    expect(createEventCalls, 1);
  });

  testWidgets('dark tab uses the configured dark glass values', (
    tester,
  ) async {
    appLiquidGlassOpacityNotifier.value = kLiquidGlassMaximumOpacity;
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
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
    expect(
      tabBar.indicatorColor!.value,
      kFloatingTabBarDarkIndicatorColor.value,
    );
    expect(
      tabBar.settings!.glassColor,
      const Color.fromRGBO(255, 255, 255, 0.85),
    );
    expect(
      tabBar.settings!.lightIntensity,
      GlassThemeVariant.dark.settings!.lightIntensity,
    );
    expect(
      tabBar.settings!.ambientStrength,
      GlassThemeVariant.dark.settings!.ambientStrength,
    );
    expect(tabBar.settings!.thickness, 30.0);
    expect(tabBar.settings!.blur, 40.0);
    expect(tabBar.settings!.refractiveIndex, 1.59);
    expect(tabBar.settings!.saturation, closeTo(1.6, 0.001));
    expect(tabBar.settings!.chromaticAberration, 0.3);
    expect(tabBar.settings!.backerColor!.a, closeTo(0.20, 0.01));
    expect(tabBar.settings!.backerColor!.r, 1.0);
    expect(tabBar.indicatorSettings, isNull);
    expect(tabBar.iconSize, 20.0);
    expect(tabBar.tabs.map((tab) => (tab.icon! as FixedSFIcon).fontSize), [
      20.0,
      20.0,
      20.0,
    ]);
    expect(tabBar.extraButton!.icon as FixedSFIcon, isNotNull);
    expect(
      (tabBar.extraButton!.icon as FixedSFIcon).fontSize,
      24.0,
    );
    expect(tabBar.labelFontSize, 9.0);
    expect(tabBar.magnification, 1.0);

    appLiquidGlassOpacityNotifier.value = kLiquidGlassMinimumOpacity;
    await tester.pump();
    tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(tabBar.settings!.glassColor.a, closeTo(0.15, 0.01));
    expect(tabBar.settings!.blur, 30.0);
    expect(tabBar.settings!.saturation, closeTo(1.4, 0.001));
    expect(tabBar.settings!.backerColor!.a, closeTo(0.0, 0.01));
    expect(tabBar.settings!.backerColor!.r, 1.0);

    appLiquidGlassOpacityNotifier.value =
        kLiquidGlassMinimumOpacity +
        0.5 * (kLiquidGlassMaximumOpacity - kLiquidGlassMinimumOpacity);
    await tester.pump();
    tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(tabBar.settings!.glassColor.a, closeTo(0.50, 0.01));
    expect(tabBar.settings!.blur, 35.0);
    expect(tabBar.settings!.saturation, closeTo(1.5, 0.001));
    expect(tabBar.settings!.backerColor!.a, closeTo(0.10, 0.01));
    expect(tabBar.settings!.backerColor!.r, 1.0);

    appLiquidGlassOpacityNotifier.value = kLiquidGlassMaximumOpacity;
    await tester.pump();
  });

  testWidgets('slider updates tab-bar tint, blur, saturation, and underlay', (
    tester,
  ) async {
    appLiquidGlassOpacityNotifier.value = kLiquidGlassMinimumOpacity;
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
    expect(tabBar.settings!.glassColor.a, closeTo(0.15, 0.01));
    expect(tabBar.settings!.blur, 30.0);
    expect(tabBar.settings!.saturation, 1.4);
    expect(tabBar.settings!.backerColor!.a, closeTo(0.0, 0.01));

    appLiquidGlassOpacityNotifier.value =
        kLiquidGlassMinimumOpacity +
        0.5 * (kLiquidGlassMaximumOpacity - kLiquidGlassMinimumOpacity);
    await tester.pump();

    tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(tabBar.settings!.glassColor.a, closeTo(0.50, 0.01));
    expect(tabBar.settings!.blur, 35.0);
    expect(tabBar.settings!.saturation, closeTo(1.6, 0.001));
    expect(tabBar.settings!.backerColor!.a, closeTo(0.175, 0.01));

    appLiquidGlassOpacityNotifier.value = kLiquidGlassMaximumOpacity;
    await tester.pump();
  });
}
