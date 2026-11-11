import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassThemeVariant;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass
    show
        DefaultButtonSettings,
        GlassExtraButtonPlacement,
        GlassTabBar,
        JellyClipper;
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

  test('selected-color mask follows the pill beyond both tab-bar edges', () {
    const size = Size(400, 49);
    const expansion = EdgeInsets.symmetric(horizontal: 12, vertical: 8);

    final leftOverdrag = navigation_glass.JellyClipper(
      itemCount: 4,
      alignment: const Alignment(-1.2, 0),
      thickness: 1,
      expansion: expansion,
      transform: Matrix4.identity(),
      borderRadius: 32,
    ).getClip(size).getBounds();
    expect(leftOverdrag.left, closeTo(-37.4, 0.001));
    expect(leftOverdrag.right, closeTo(84.6, 0.001));

    final rightOverdrag = navigation_glass.JellyClipper(
      itemCount: 4,
      alignment: const Alignment(1.2, 0),
      thickness: 1,
      expansion: expansion,
      transform: Matrix4.identity(),
      borderRadius: 32,
    ).getClip(size).getBounds();
    expect(rightOverdrag.left, closeTo(315.4, 0.001));
    expect(rightOverdrag.right, closeTo(437.4, 0.001));
  });

  testWidgets(
    'navigation package tab bar preserves dimensions, colors, and routing',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
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
        skeddoNavigationTabIndicatorGlassSettings(Brightness.light),
      );
      expect(
        tabBar.indicatorSettings!.chromaticAberration,
        kSkeddoActiveTabIndicatorChromaticAberration,
      );
      expect(tabBar.settings!.chromaticAberration, 0.3);
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

  testWidgets(
    'landscape tab bar is wider and portrait width is restored',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CupertinoApp(
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
      await tester.pumpAndSettle();

      final tabBar = find.byType(navigation_glass.GlassTabBar);
      final portraitSize = tester.getSize(tabBar);
      expect(portraitSize.height, 49.0);
      expect(
        tester
            .widget<navigation_glass.GlassTabBar>(tabBar)
            .indicatorSettings!
            .chromaticAberration,
        kSkeddoActiveTabIndicatorChromaticAberration,
      );

      tester.view.physicalSize = const Size(874, 402);
      await tester.pump();
      final landscapeSize = tester.getSize(tabBar);
      expect(landscapeSize.width, greaterThan(portraitSize.width));
      expect(landscapeSize.width, closeTo(449.0, 0.01));
      expect(tester.getSize(tabBar).height, 49.0);
      expect(
        tester
            .widget<navigation_glass.GlassTabBar>(tabBar)
            .indicatorSettings!
            .chromaticAberration,
        kSkeddoActiveTabIndicatorChromaticAberration,
      );

      tester.view.physicalSize = const Size(402, 874);
      await tester.pump();
      expect(tester.getSize(tabBar).width, portraitSize.width);
      expect(tester.getRect(tabBar).center.dx, 201.0);
    },
  );

  testWidgets('landscape tab labels sit beside icons; portrait stays stacked', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(874, 402);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int? selectedTab;

    Widget buildBar() => CupertinoApp(
      home: Stack(
        children: [
          Positioned.fill(
            child: FloatingTabPill(
              selectedIndex: 0,
              eventsAccent: const Color(0xFF007AFF),
              onTabSelected: (index) => selectedTab = index,
              onCreateEvent: () {},
            ),
          ),
        ],
      ),
    );

    await tester.pumpWidget(buildBar());
    await tester.pumpAndSettle();

    var tabBar = tester.widget<navigation_glass.GlassTabBar>(
      find.byType(navigation_glass.GlassTabBar),
    );
    expect(tabBar.tabs.map((tab) => tab.label), everyElement(isNull));
    expect(tabBar.tabs.map((tab) => tab.semanticLabel), [
      'Home',
      'Calendar',
      'Events',
      'You',
    ]);
    expect(tabBar.tabWidth, 88.0);
    expect(
      tabBar.indicatorExpansion.resolve(TextDirection.ltr),
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
    expect(tabBar.tabs.every((tab) => tab.icon is Row), isTrue);
    expect(tabBar.tabs.every((tab) => tab.activeIcon is Row), isTrue);
    final homeItem = tabBar.tabs[0].icon as Row;
    final homeIcon = homeItem.children[0] as FixedSFIcon;
    final homeLabel = homeItem.children[2] as Text;
    expect(homeIcon.fontSize, 16.0);
    expect(homeLabel.style!.fontSize, 12.0);
    expect(homeLabel.style!.color, isNull);
    expect(homeLabel.style!.fontWeight, FontWeight.w500);
    final activeHomeItem = tabBar.tabs[0].activeIcon as Row;
    final activeHomeLabel = activeHomeItem.children[2] as Text;
    expect(activeHomeLabel.style!.color, isNull);
    expect(activeHomeLabel.style!.fontWeight, FontWeight.w600);
    expect(find.text('Home'), findsWidgets);
    expect(find.text('Calendar'), findsWidgets);

    final calendarLabelColors = tester
        .widgetList<RichText>(find.byType(RichText))
        .where((text) => text.text.toPlainText() == 'Calendar')
        .map((text) => text.text.style?.color)
        .toSet();
    expect(calendarLabelColors, contains(tabBar.selectedLabelColor));
    expect(calendarLabelColors, contains(tabBar.unselectedLabelColor));

    await tester.tap(find.text('Calendar').first);
    await tester.pump(const Duration(milliseconds: 350));
    expect(selectedTab, 1);

    tester.view.physicalSize = const Size(402, 874);
    await tester.pumpWidget(buildBar());
    tabBar = tester.widget<navigation_glass.GlassTabBar>(
      find.byType(navigation_glass.GlassTabBar),
    );
    expect(tabBar.tabs.map((tab) => tab.label), [
      'Home',
      'Calendar',
      'Events',
      'You',
    ]);
    expect(tabBar.tabs.first.icon, isA<FixedSFIcon>());
    expect(
      tabBar.indicatorExpansion.resolve(TextDirection.ltr),
      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  });

  testWidgets('dark tab keeps package optics with SKEDDO charcoal tint', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
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
    expect(
      tabBar.indicatorSettings,
      skeddoNavigationTabIndicatorGlassSettings(Brightness.dark),
    );
    expect(tabBar.indicatorSettings, isNotNull);
    expect(
      tabBar.indicatorSettings!.chromaticAberration,
      kSkeddoActiveTabIndicatorChromaticAberration,
    );
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
