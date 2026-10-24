import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassExtraButtonPlacement, GlassTabBar, GlassTheme;
import 'package:smart_scheduler/app_theme.dart';
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
    final glassTheme = tester.widget<GlassTheme>(find.byType(GlassTheme));
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
    expect(
      tabBar.indicatorColor!.value,
      kFloatingTabBarLightIndicatorColor.value,
    );
    expect(
      glassTheme.data.dark.settings!.glassColor!.value,
      kFloatingTabBarDarkGlassTint.value,
    );

    await tester.tap(find.bySemanticsLabel('New Event'));
    await tester.pump();
    expect(createEventCalls, 1);
  });

  testWidgets('dark tab selection uses a stronger resting tint', (tester) async {
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

    final tabBar = tester.widget<GlassTabBar>(find.byType(GlassTabBar));
    expect(
      tabBar.indicatorColor!.value,
      kFloatingTabBarDarkIndicatorColor.value,
    );
  });
}
