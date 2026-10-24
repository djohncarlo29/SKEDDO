import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassTabBar;
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

  testWidgets('Flutter tab pill uses GlassTabBar with only color overrides', (
    tester,
  ) async {
    const eventsAccent = Color(0xFFDB5500);
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
    expect(tabBar.barHeight, 64.0);
    expect(tabBar.horizontalPadding, 20.0);
    expect(tabBar.verticalPadding, 20.0);
  });
}
