import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassThemeVariant;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass
    show DefaultButtonSettings, GlassExtraButtonPlacement, GlassTabBar;
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/widgets/fixed_size_icon.dart';
import 'package:smart_scheduler/widgets/floating_tab_pill.dart';
import 'package:smart_scheduler/widgets/skeddo_glass_settings.dart';

void main() {
  testWidgets('inactive tab tint uses the specified light and dark colors', (
    tester,
  ) async {
    for (final entry in [
      (Brightness.light, const Color.fromRGBO(0, 0, 0, 0.75)),
      (Brightness.dark, const Color.fromRGBO(253, 253, 253, 0.75)),
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
      expect(resolvedColor!.toARGB32(), entry.$2.toARGB32());
      expect(resolvedColor!.a, closeTo(0.75, 0.01));
    }
  });

  testWidgets(
    'navigation package tab bar preserves dimensions, colors, and routing',
    (tester) async {
      const eventsAccent = Color(0xFFDB5500);
      var createEventCalls = 0;
      int? selectedTab;
      await tester.pumpWidget(
        CupertinoApp(
          theme: const CupertinoThemeData(brightness: Brightness.light),
          home: Stack(
            children: [
              Positioned.fill(
                child: FloatingTabPill(
                  selectedIndex: 2,
                  eventsAccent: eventsAccent,
                  onTabSelected: (index) => selectedTab = index,
                  onCreateEvent: () => createEventCalls++,
                ),
              ),
            ],
          ),
        ),
      );

      final context = tester.element(find.byType(FloatingTabPill));
      final tabBar = tester.widget<navigation_glass.GlassTabBar>(
        find.byType(navigation_glass.GlassTabBar),
      );
      final inactiveColor = CupertinoDynamicColor.resolve(
        kTabBarInactiveColor,
        context,
      );

      expect(tabBar.tabs.map((tab) => tab.label), [
        'Home',
        'Calendar',
        'Events',
        'You',
      ]);
      expect((tabBar.tabs[0].icon as FixedSFIcon).icon, SFIcons.sf_house);
      expect(
        (tabBar.tabs[0].activeIcon as FixedSFIcon).icon,
        SFIcons.sf_house_fill,
      );
      expect(
        (tabBar.tabs[3].icon as FixedSFIcon).icon,
        SFIcons.sf_person_crop_circle,
      );
      expect(
        (tabBar.tabs[3].activeIcon as FixedSFIcon).icon,
        SFIcons.sf_person_crop_circle_fill,
      );
      expect(tabBar.selectedIconColor!.toARGB32(), eventsAccent.toARGB32());
      expect(tabBar.selectedLabelColor!.toARGB32(), eventsAccent.toARGB32());
      expect(tabBar.unselectedIconColor!.toARGB32(), inactiveColor.toARGB32());
      expect(tabBar.unselectedLabelColor!.toARGB32(), inactiveColor.toARGB32());
      expect(tabBar.extraButton, isNotNull);
      expect(tabBar.extraButton!.label, 'New Event');
      expect(
        tabBar.extraButton!.iconColor!.toARGB32(),
        eventsAccent.toARGB32(),
      );
      expect(
        tabBar.extraButton!.placement,
        navigation_glass.GlassExtraButtonPlacement.right,
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
        20.0,
      ]);
      expect(tabBar.labelFontSize, 9.0);
      expect(tabBar.iconLabelSpacing, 1.5);
      expect(tabBar.magnification, 1.0);
      expect(
        tabBar.settings,
        skeddoNavigationTabBarGlassSettingsFor(Brightness.light),
      );
      final extraButtonSettings = tester
          .widget<navigation_glass.DefaultButtonSettings>(
            find.byType(navigation_glass.DefaultButtonSettings),
          );
      expect(
        extraButtonSettings.settings,
        skeddoNavigationTabBarGlassSettingsFor(Brightness.light),
      );
      expect(tabBar.settings!.blur, closeTo(1.7, 0.000001));
      expect(
        skeddoBottomBarGlassSettingsFor(Brightness.light).blur,
        closeTo(1.7, 0.000001),
      );
      expect(tabBar.innerBlur, closeTo(2.7, 0.000001));
      expect(kSkeddoLightBottomBarOpacity, 0.528);
      expect(tabBar.settings!.glassColor.a, closeTo(0.528, 0.001));
      expect(tabBar.settings!.glassColor.toARGB32() & 0x00FFFFFF, 0x00FFFFFF);
      expect(
        tabBar.indicatorColor!.toARGB32(),
        kFloatingTabBarLightIndicatorColor.toARGB32(),
      );
      expect(
        tabBar.indicatorSettings,
        skeddoNavigationTabIndicatorGlassSettings(),
      );
      expect(
        tabBar.indicatorSettings!.glassColor,
        const Color.fromRGBO(0, 0, 0, 0.04),
      );
      expect(tabBar.indicatorSettings!.shadowElevation, 1.2);

      await tester.tap(find.text('Calendar').first);
      await tester.pump(const Duration(milliseconds: 350));
      expect(selectedTab, 1);

      await tester.tap(find.bySemanticsLabel('New Event'));
      await tester.pump();
      expect(createEventCalls, 1);
    },
  );

  testWidgets('dark tab keeps package optics with SKEDDO charcoal tint', (
    tester,
  ) async {
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

    final tabBar = tester.widget<navigation_glass.GlassTabBar>(
      find.byType(navigation_glass.GlassTabBar),
    );
    expect(
      tabBar.settings,
      skeddoNavigationTabBarGlassSettingsFor(Brightness.dark),
    );
    expect(tabBar.settings!.blur, closeTo(1.7, 0.000001));
    expect(
      skeddoBottomBarGlassSettingsFor(Brightness.dark).blur,
      closeTo(1.7, 0.000001),
    );
    expect(tabBar.innerBlur, closeTo(2.7, 0.000001));
    expect(kSkeddoDarkBottomBarOpacity, 0.628);
    expect(
      tabBar.indicatorColor!.toARGB32(),
      kFloatingTabBarDarkIndicatorColor.toARGB32(),
    );
    expect(tabBar.settings!.glassColor.a, closeTo(0.628, 0.001));
    expect(tabBar.settings!.glassColor.toARGB32() & 0x00FFFFFF, 0x003E3E40);
    expect(
      tabBar.settings!.lightIntensity,
      GlassThemeVariant.dark.settings!.lightIntensity,
    );
    expect(
      tabBar.settings!.ambientStrength,
      GlassThemeVariant.dark.settings!.ambientStrength,
    );
    expect(tabBar.settings!.thickness, 30.0);
    expect(tabBar.settings!.blur, closeTo(1.7, 0.000001));
    expect(tabBar.settings!.chromaticAberration, 0.3);
    expect(tabBar.settings!.refractiveIndex, 1.59);
    expect(tabBar.settings!.saturation, 0.7);
    expect(tabBar.indicatorSettings, isNull);
    expect(tabBar.iconSize, 20.0);
    expect(tabBar.tabs.map((tab) => (tab.icon! as FixedSFIcon).fontSize), [
      20.0,
      20.0,
      20.0,
      20.0,
    ]);
    expect(tabBar.extraButton!.icon as FixedSFIcon, isNotNull);
    expect((tabBar.extraButton!.icon as FixedSFIcon).fontSize, 24.0);
    expect(tabBar.labelFontSize, 9.0);
    expect(tabBar.magnification, 1.0);
  });
}
