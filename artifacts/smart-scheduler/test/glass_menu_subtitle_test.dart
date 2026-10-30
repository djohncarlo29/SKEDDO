import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassMenu, GlassMenuItem;
import 'package:liquid_glass_widgets/utils/glass_morph_controller.dart'
    show GlassMorphContentMotion;

void main() {
  test('GlassMenu retains its original default corner radius', () {
    const menu = GlassMenu(items: [], trigger: Text('Actions'));
    expect(menu.menuBorderRadius, 32.0);
  });

  test('menu and popover content share the same morph fade and scale', () {
    expect(
      GlassMorphContentMotion.isVisible(progress: 0.29, isClosing: false),
      isFalse,
    );
    expect(
      GlassMorphContentMotion.isVisible(progress: 0.31, isClosing: false),
      isTrue,
    );
    expect(
      GlassMorphContentMotion.opacity(progress: 0.3, isClosing: false),
      0.0,
    );
    expect(
      GlassMorphContentMotion.opacity(progress: 0.5, isClosing: false),
      closeTo(0.5, 0.001),
    );
    expect(GlassMorphContentMotion.scale(0.3), 0.5);
    expect(GlassMorphContentMotion.scale(1.0), 1.0);
    expect(
      GlassMorphContentMotion.opacity(progress: 0.85, isClosing: true),
      0.0,
    );
    expect(
      GlassMorphContentMotion.opacity(progress: 0.925, isClosing: true),
      closeTo(0.5, 0.001),
    );
  });

  testWidgets('menu row centers leading and trailing controls with its label', (
    tester,
  ) async {
    const leadingKey = ValueKey('leading-control');
    const trailingKey = ValueKey('trailing-control');

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: GlassMenuItem(
            title: 'Option',
            icon: SizedBox(
              key: leadingKey,
              width: 24,
              height: 24,
              child: Icon(CupertinoIcons.list_bullet),
            ),
            trailing: SizedBox(
              key: trailingKey,
              width: 18,
              height: 18,
              child: Icon(CupertinoIcons.chevron_right),
            ),
            onTap: () {},
          ),
        ),
      ),
    );

    final labelCenterY = tester.getRect(find.text('Option')).center.dy;
    expect(
      tester.getRect(find.byKey(leadingKey)).center.dy,
      closeTo(labelCenterY, 0.1),
    );
    expect(
      tester.getRect(find.byKey(trailingKey)).center.dy,
      closeTo(labelCenterY, 0.1),
    );
  });

  testWidgets('submenu height updates when its header gains a subtitle', (
    tester,
  ) async {
    String? subtitle;
    late StateSetter rebuildMenu;
    VoidCallback? toggleMenu;
    final reportedExtents = <double>[];

    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (context, setState) {
            rebuildMenu = setState;
            return CupertinoPageScaffold(
              child: Center(
                child: GlassMenu(
                  menuWidth: 260,
                  autoAdjustToScreen: true,
                  items: [
                    GlassMenuItem(
                      title: 'Sort By',
                      subtitle: subtitle,
                      submenu: [
                        for (final title in const [
                          'Manual',
                          'Deadline',
                          'Creation Date',
                          'Priority',
                          'Title',
                        ])
                          GlassMenuItem(title: title, onTap: () {}),
                      ],
                      onTap: () {},
                    ),
                  ],
                  onLevelChanged: (depth, extent) {
                    if (depth == 1) reportedExtents.add(extent);
                  },
                  triggerBuilder: (context, toggle) {
                    toggleMenu = toggle;
                    return CupertinoButton(
                      onPressed: toggle,
                      child: const Text('Actions'),
                    );
                  },
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    toggleMenu!();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort By'));
    await tester.pumpAndSettle();

    final submenuCard = find.byKey(const ValueKey('glass-menu-submenu-card-0'));
    final initialHeight = tester.getSize(submenuCard).height;
    expect(find.text('Title'), findsOneWidget);

    rebuildMenu(() => subtitle = 'Creation Date');
    await tester.pumpAndSettle();

    final updatedHeight = tester.getSize(submenuCard).height;
    expect(updatedHeight, greaterThan(initialHeight));
    expect(reportedExtents.length, greaterThanOrEqualTo(2));
    expect(reportedExtents.last, greaterThan(reportedExtents.first));
    expect(find.text('Title'), findsOneWidget);
  });

  testWidgets('submenu chevrons scale with the OS text size', (tester) async {
    VoidCallback? toggleMenu;
    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: CupertinoPageScaffold(
            child: Center(
              child: GlassMenu(
                menuWidth: 260,
                items: [
                  GlassMenuItem(
                    title: 'Sort By',
                    submenu: [GlassMenuItem(title: 'Deadline', onTap: () {})],
                    onTap: () {},
                  ),
                ],
                triggerBuilder: (context, toggle) {
                  toggleMenu = toggle;
                  return CupertinoButton(
                    onPressed: toggle,
                    child: const Text('Actions'),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    toggleMenu!();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort By'));
    await tester.pumpAndSettle();

    final chevrons = tester.widgetList<Icon>(
      find.byIcon(CupertinoIcons.chevron_right),
    );
    expect(chevrons, isNotEmpty);
    expect(chevrons.every((icon) => icon.size == 32), isTrue);
    expect(chevrons.every((icon) => icon.weight == 500), isTrue);
  });

  testWidgets('open submenu is repositioned after landscape-to-portrait', (
    tester,
  ) async {
    final previousPhysicalSize = tester.view.physicalSize;
    final previousDevicePixelRatio = tester.view.devicePixelRatio;
    addTearDown(() {
      tester.view.physicalSize = previousPhysicalSize;
      tester.view.devicePixelRatio = previousDevicePixelRatio;
    });
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 400);

    VoidCallback? toggleMenu;
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Align(
            alignment: Alignment.topRight,
            child: GlassMenu(
              menuWidth: 260,
              autoAdjustToScreen: true,
              items: [
                GlassMenuItem(
                  title: 'Sort By',
                  submenu: [
                    for (final title in const [
                      'Manual',
                      'Deadline',
                      'Creation Date',
                      'Priority',
                      'Title',
                    ])
                      GlassMenuItem(title: title, onTap: () {}),
                  ],
                  onTap: () {},
                ),
              ],
              triggerBuilder: (context, toggle) {
                toggleMenu = toggle;
                return CupertinoButton(
                  onPressed: toggle,
                  child: const Text('Actions'),
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    toggleMenu!();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort By'));
    await tester.pumpAndSettle();

    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpAndSettle();

    final cardRect = tester.getRect(
      find.byKey(const ValueKey('glass-menu-submenu-card-0')),
    );
    expect(cardRect.left, greaterThanOrEqualTo(0));
    expect(cardRect.top, greaterThanOrEqualTo(0));
    expect(cardRect.right, lessThanOrEqualTo(400));
    expect(cardRect.bottom, lessThanOrEqualTo(800));
  });

  testWidgets('submenu header displays its current subtitle', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: GlassMenu(
              menuWidth: 260,
              items: [
                GlassMenuItem(
                  title: 'Sort By',
                  subtitle: 'Manual',
                  titleStyle: const TextStyle(color: CupertinoColors.label),
                  iconColor: CupertinoColors.label,
                  submenu: [GlassMenuItem(title: 'Deadline', onTap: () {})],
                  onTap: () {},
                ),
              ],
              triggerBuilder: (context, toggleMenu) => CupertinoButton(
                onPressed: toggleMenu,
                child: const Text('Actions'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort By'));
    await tester.pump();
    final rotatingChevron = find.byKey(
      const ValueKey('glass-menu-submenu-chevron-1'),
    );
    expect(rotatingChevron, findsOneWidget);
    final openingRotation = tester.widget<TweenAnimationBuilder<double>>(
      rotatingChevron,
    );
    expect(openingRotation.tween.begin, 0);
    expect(openingRotation.tween.end, 0.25);
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('glass-menu-header-1'));
    expect(
      find.descendant(of: header, matching: find.text('Sort By')),
      findsOneWidget,
    );
    final headerChevron = find.descendant(
      of: header,
      matching: find.byIcon(CupertinoIcons.chevron_right),
    );
    expect(tester.widget<Icon>(headerChevron).color, CupertinoColors.label);

    await tester.tap(
      find.descendant(of: header, matching: find.text('Sort By')),
    );
    await tester.pump();
    final closingRotation = tester.widget<TweenAnimationBuilder<double>>(
      rotatingChevron,
    );
    expect(closingRotation.tween.begin, 0.25);
    expect(closingRotation.tween.end, 0);
    await tester.pumpAndSettle();
    expect(find.text('Manual'), findsOneWidget);
  });

  testWidgets('only the parent row whose submenu is open rotates its chevron', (
    tester,
  ) async {
    final sortByOpenStates = <bool>[];
    final deadlineOpenStates = <bool>[];
    final priorityOpenStates = <bool>[];

    Widget submenuTrailing(String key, bool isOpen) => AnimatedRotation(
      key: ValueKey(key),
      turns: isOpen ? 0.25 : 0,
      duration: const Duration(milliseconds: 180),
      child: const Icon(CupertinoIcons.chevron_right),
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: GlassMenu(
              menuWidth: 260,
              items: [
                GlassMenuItem(
                  title: 'Sort By',
                  trailingBuilder: (context, isOpen) {
                    sortByOpenStates.add(isOpen);
                    return submenuTrailing('sort-by-chevron', isOpen);
                  },
                  submenu: [
                    GlassMenuItem(
                      title: 'Deadline',
                      trailingBuilder: (context, isOpen) {
                        deadlineOpenStates.add(isOpen);
                        return submenuTrailing('deadline-chevron', isOpen);
                      },
                      submenu: [
                        GlassMenuItem(title: 'Oldest First', onTap: () {}),
                      ],
                      onTap: () {},
                    ),
                    GlassMenuItem(
                      title: 'Priority',
                      trailingBuilder: (context, isOpen) {
                        priorityOpenStates.add(isOpen);
                        return submenuTrailing('priority-chevron', isOpen);
                      },
                      submenu: [
                        GlassMenuItem(title: 'Highest First', onTap: () {}),
                      ],
                      onTap: () {},
                    ),
                  ],
                  onTap: () {},
                ),
              ],
              triggerBuilder: (context, toggleMenu) => CupertinoButton(
                onPressed: toggleMenu,
                child: const Text('Actions'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort By'));
    await tester.pumpAndSettle();

    expect(sortByOpenStates.last, isTrue);
    expect(deadlineOpenStates.last, isFalse);
    expect(priorityOpenStates.last, isFalse);
    expect(
      tester
          .widgetList<AnimatedRotation>(
            find.byKey(const ValueKey('priority-chevron')),
          )
          .every((rotation) => rotation.turns == 0),
      isTrue,
    );

    await tester.tap(find.text('Deadline').first);
    await tester.pumpAndSettle();
    expect(sortByOpenStates.last, isTrue);
    expect(deadlineOpenStates.last, isTrue);
    expect(priorityOpenStates.last, isFalse);
    expect(
      tester
          .widgetList<AnimatedRotation>(
            find.byKey(const ValueKey('deadline-chevron')),
          )
          .every((rotation) => rotation.turns == 0.25),
      isTrue,
    );

    final deadlineHeader = find.byKey(const ValueKey('glass-menu-header-2'));
    await tester.tap(
      find.descendant(of: deadlineHeader, matching: find.text('Deadline')),
    );
    await tester.pumpAndSettle();
    expect(sortByOpenStates.last, isTrue);
    expect(deadlineOpenStates.last, isFalse);
    expect(priorityOpenStates.last, isFalse);
    expect(
      tester
          .widgetList<AnimatedRotation>(
            find.byKey(const ValueKey('deadline-chevron')),
          )
          .every((rotation) => rotation.turns == 0),
      isTrue,
    );
  });

  testWidgets('overflow scrolling does not show the selection pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: GlassMenu(
              menuWidth: 260,
              menuHeight: 130,
              items: [
                for (var index = 0; index < 8; index++)
                  GlassMenuItem(title: 'Option $index', onTap: () {}),
              ],
              triggerBuilder: (context, toggleMenu) => CupertinoButton(
                onPressed: toggleMenu,
                child: const Text('Actions'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    final pill = find.byKey(const ValueKey('glass-menu-selection-pill'));
    expect(pill, findsNothing);

    final scrollableFinder = find.descendant(
      of: find.byType(GlassMenu),
      matching: find.byType(Scrollable),
    );
    final scrollableFinderTarget = scrollableFinder.last;
    final scrollable = tester.state<ScrollableState>(scrollableFinderTarget);
    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    tester.binding.handlePointerEvent(
      PointerScrollEvent(
        position: tester.getCenter(scrollableFinderTarget),
        scrollDelta: const Offset(0, 80),
      ),
    );
    await tester.pump();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(pill, findsNothing);

    // Pulling beyond the top edge uses the scroll view's rubberband response,
    // but must not turn that gesture into a row-selection highlight.
    await tester.drag(scrollableFinderTarget, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(pill, findsNothing);
  });

  testWidgets('press and long-press activation has no selector or row scale', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: GlassMenu(
              menuWidth: 260,
              menuHeight: 130,
              items: [
                for (var index = 0; index < 8; index++)
                  GlassMenuItem(
                    title: 'Option $index',
                    onTap: () => tapped = true,
                  ),
              ],
              triggerBuilder: (context, toggleMenu) => CupertinoButton(
                onPressed: toggleMenu,
                child: const Text('Actions'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();

    final pill = find.byKey(const ValueKey('glass-menu-selection-pill'));
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Option 0')),
    );
    final optionRow = find.ancestor(
      of: find.text('Option 0'),
      matching: find.byType(GlassMenuItem),
    ).first;
    final rowScale = find.descendant(
      of: optionRow,
      matching: find.byType(AnimatedScale),
    );
    expect(tester.widget<AnimatedScale>(rowScale).scale, 1.0);
    await tester.pump(const Duration(milliseconds: 510));
    expect(pill, findsNothing);
    expect(tester.widget<AnimatedScale>(rowScale).scale, 1.0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tapped, isTrue);
  });

  testWidgets(
    'open menu reanchors and remains visible after orientation change',
    (tester) async {
      const portrait = Size(360, 720);
      const landscape = Size(720, 360);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.binding.setSurfaceSize(portrait);

      Widget buildApp(Size viewport) => CupertinoApp(
        home: MediaQuery(
          data: MediaQueryData(size: viewport),
          child: CupertinoPageScaffold(
            child: SizedBox.expand(
              child: Align(
                alignment: viewport.width > viewport.height
                    ? Alignment.topRight
                    : Alignment.bottomLeft,
                child: GlassMenu(
                  menuWidth: 240,
                  autoAdjustToScreen: true,
                  items: [
                    GlassMenuItem(
                      title: 'Sort By',
                      subtitle: 'Manual',
                      submenu: [GlassMenuItem(title: 'Deadline', onTap: () {})],
                      onTap: () {},
                    ),
                  ],
                  triggerBuilder: (context, toggleMenu) => CupertinoButton(
                    onPressed: toggleMenu,
                    child: const Text('Actions'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpWidget(buildApp(portrait));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sort By').first);
      await tester.pumpAndSettle();
      final portraitRow = tester.getRect(find.text('Deadline'));

      await tester.binding.setSurfaceSize(landscape);
      await tester.pumpWidget(buildApp(landscape));
      await tester.pumpAndSettle();
      final landscapeRow = tester.getRect(find.text('Deadline'));

      expect(landscapeRow.left, greaterThanOrEqualTo(0));
      expect(landscapeRow.right, lessThanOrEqualTo(landscape.width));
      expect(landscapeRow.top, greaterThanOrEqualTo(0));
      expect(landscapeRow.bottom, lessThanOrEqualTo(landscape.height));
      expect(landscapeRow.center.dx, greaterThan(portraitRow.center.dx));
    },
  );

  testWidgets(
    'menu row height follows text scaling while vertical padding stays fixed',
    (tester) async {
      Future<double> pumpRow(double scale) async {
        await tester.pumpWidget(
          CupertinoApp(
            home: MediaQuery(
              data: MediaQueryData(
                size: const Size(400, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: CupertinoPageScaffold(
                child: Center(
                  child: SizedBox(
                    width: 260,
                    child: GlassMenuItem(
                      title: 'Option',
                      onTap: () {},
                      allowTextWrapping: true,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final row = find.descendant(
          of: find.byType(GlassMenuItem),
          matching: find.byType(AnimatedContainer),
        );
        final animatedRow = tester.widget<AnimatedContainer>(row.first);
        expect(
          animatedRow.padding,
          const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        );
        final rowConstraints = tester.widget<ConstrainedBox>(
          find
              .descendant(
                of: find.byType(GlassMenuItem),
                matching: find.byType(ConstrainedBox),
              )
              .first,
        );
        return rowConstraints.constraints.minHeight;
      }

      final smallTextRowHeight = await pumpRow(0.8);
      final largeTextRowHeight = await pumpRow(1.5);

      expect(smallTextRowHeight, lessThan(44));
      expect(largeTextRowHeight, greaterThan(44));
    },
  );

  testWidgets('root and nested menu extents grow with text scaling', (
    tester,
  ) async {
    const viewport = Size(800, 600);

    Future<(double, double)> measureExtents(double scale) async {
      var rootExtent = 0.0;
      var nestedExtent = 0.0;
      VoidCallback? toggleMenu;
      await tester.pumpWidget(
        CupertinoApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: viewport,
              textScaler: TextScaler.linear(scale),
            ),
            child: CupertinoPageScaffold(
              child: Center(
                child: GlassMenu(
                  menuWidth: 260,
                  items: [
                    GlassMenuItem(
                      title: 'More actions',
                      allowTextWrapping: true,
                      submenu: [
                        GlassMenuItem(
                          title:
                              'A longer option label that wraps as text grows',
                          allowTextWrapping: true,
                          onTap: () {},
                        ),
                        GlassMenuItem(
                          title:
                              'Another option that needs more room at larger sizes',
                          allowTextWrapping: true,
                          onTap: () {},
                        ),
                      ],
                      onTap: () {},
                    ),
                  ],
                  onLevelChanged: (depth, height) {
                    if (depth == 0) rootExtent = height;
                    if (depth == 1) nestedExtent = height;
                  },
                  triggerBuilder: (context, toggle) {
                    toggleMenu = toggle;
                    return CupertinoButton(
                      onPressed: toggle,
                      child: const Text('Actions'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      toggleMenu!();
      await tester.pumpAndSettle();
      await tester.tap(find.text('More actions'));
      await tester.pumpAndSettle();
      final extents = (rootExtent, nestedExtent);
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('glass-menu-header-1')),
          matching: find.text('More actions'),
        ),
      );
      await tester.pumpAndSettle();
      toggleMenu!();
      await tester.pumpAndSettle();
      return extents;
    }

    final smallTextExtents = await measureExtents(0.8);
    final largeTextExtents = await measureExtents(1.5);

    expect(largeTextExtents.$1, greaterThan(smallTextExtents.$1));
    expect(largeTextExtents.$2, greaterThan(smallTextExtents.$2));
  });

  testWidgets(
    'selection-wrapped menu items retain multiline text at larger scales',
    (tester) async {
      const title = 'A long menu action label that must wrap across lines';
      VoidCallback? toggleMenu;
      await tester.pumpWidget(
        CupertinoApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: CupertinoPageScaffold(
              child: Center(
                child: GlassMenu(
                  menuWidth: 220,
                  items: [
                    GlassMenuItem(
                      title: title,
                      allowTextWrapping: true,
                      onTap: () {},
                    ),
                  ],
                  triggerBuilder: (context, toggle) {
                    toggleMenu = toggle;
                    return CupertinoButton(
                      onPressed: toggle,
                      child: const Text('Actions'),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      toggleMenu!();
      await tester.pumpAndSettle();

      final titleFinder = find.text(title);
      final titleWidget = tester.widget<Text>(titleFinder);
      expect(titleWidget.maxLines, isNull);
      expect(titleWidget.overflow, TextOverflow.visible);
      expect(tester.getSize(titleFinder).height, greaterThan(50));
    },
  );

  testWidgets(
    'trailing icons keep an 8px label gap without inflating menu height',
    (tester) async {
      const title = 'Single Day';
      const trailingKey = ValueKey('menu-trailing-icon');
      var naturalHeight = 0.0;
      VoidCallback? toggleMenu;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: GlassMenu(
              menuWidth: 260,
              items: [
                GlassMenuItem(
                  title: title,
                  icon: const SizedBox(width: 24, height: 24),
                  trailing: const SizedBox(
                    key: trailingKey,
                    width: 18,
                    height: 18,
                  ),
                  trailingWidth: 18,
                  onTap: () {},
                ),
              ],
              onLevelChanged: (depth, height) {
                if (depth == 0) naturalHeight = height;
              },
              triggerBuilder: (context, toggle) {
                toggleMenu = toggle;
                return CupertinoButton(
                  onPressed: toggle,
                  child: const Text('Actions'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      toggleMenu!();
      await tester.pumpAndSettle();

      final titleRect = tester.getRect(find.text(title));
      final trailingRect = tester.getRect(find.byKey(trailingKey));
      expect(trailingRect.left - titleRect.right, closeTo(8, 0.1));
      expect(naturalHeight, closeTo(68, 0.1));
    },
  );

  testWidgets(
    'scrollable menus restore edge fading and a transient indicator',
    (tester) async {
      VoidCallback? toggleMenu;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: GlassMenu(
              menuWidth: 240,
              menuHeight: 120,
              items: [
                for (var index = 0; index < 6; index++)
                  GlassMenuItem(title: 'Menu row $index', onTap: () {}),
              ],
              triggerBuilder: (context, toggle) {
                toggleMenu = toggle;
                return CupertinoButton(
                  onPressed: toggle,
                  child: const Text('Actions'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      toggleMenu!();
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('glass-menu-scroll-fade')),
        findsOneWidget,
      );
      final indicatorFinder = find.byKey(
        const ValueKey('glass-menu-scroll-indicator'),
      );
      final indicatorTrack = tester.widget<Padding>(
        find.byKey(const ValueKey('glass-menu-scroll-indicator-track-0')),
      );
      expect(
        indicatorTrack.padding,
        const EdgeInsets.symmetric(vertical: 32),
      );
      final scale = find.descendant(
        of: indicatorFinder,
        matching: find.byType(AnimatedScale),
      );
      expect(tester.widget<AnimatedOpacity>(indicatorFinder).opacity, 0);

      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -80),
      );
      await tester.pump();
      expect(tester.widget<AnimatedOpacity>(indicatorFinder).opacity, 0.8);
      expect(tester.widget<AnimatedScale>(scale).scale, 1.0);

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<AnimatedOpacity>(indicatorFinder).opacity, 0);
      expect(tester.widget<AnimatedScale>(scale).scale, 0.65);
    },
  );

  testWidgets(
    'parent menu scroll state remains intact while nested panels open and close',
    (tester) async {
      VoidCallback? toggleMenu;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: GlassMenu(
              menuWidth: 260,
              menuHeight: 140,
              maxStackHeight: 160,
              items: [
                for (var index = 0; index < 4; index++)
                  GlassMenuItem(title: 'Root $index', onTap: () {}),
                GlassMenuItem(
                  title: 'Open nested',
                  onTap: () {},
                  submenu: [
                    for (var index = 0; index < 8; index++)
                      GlassMenuItem(title: 'Nested $index', onTap: () {}),
                  ],
                ),
                for (var index = 0; index < 6; index++)
                  GlassMenuItem(title: 'Tail $index', onTap: () {}),
              ],
              triggerBuilder: (context, toggle) {
                toggleMenu = toggle;
                return CupertinoButton(
                  onPressed: toggle,
                  child: const Text('Actions'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      toggleMenu!();
      await tester.pumpAndSettle();

      final rootScrollView = find.byType(SingleChildScrollView).first;
      final rootController = tester
          .widget<SingleChildScrollView>(rootScrollView)
          .controller!;
      final rootScrollable = tester.state<ScrollableState>(
        find.descendant(of: rootScrollView, matching: find.byType(Scrollable)),
      );
      expect(rootController.positions.length, 1);
      expect(rootScrollable.position.physics, isA<BouncingScrollPhysics>());
      await tester.drag(rootScrollView, const Offset(0, -90));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open nested'));
      await tester.pumpAndSettle();
      final offsetBeforeSubmenu = rootScrollable.position.pixels;
      expect(offsetBeforeSubmenu, greaterThan(0));

      await tester.tap(find.text('Open nested'));
      await tester.pumpAndSettle();
      expect(rootController.positions.length, 1);
      expect(
        rootScrollable.position.pixels,
        closeTo(offsetBeforeSubmenu, 0.01),
      );
      expect(
        find.byKey(const ValueKey('glass-menu-scroll-fade')),
        findsOneWidget,
      );

      final nestedScrollView = find.byType(SingleChildScrollView).last;
      final nestedController = tester
          .widget<SingleChildScrollView>(nestedScrollView)
          .controller!;
      final nestedScrollable = tester.state<ScrollableState>(
        find.descendant(
          of: nestedScrollView,
          matching: find.byType(Scrollable),
        ),
      );
      expect(nestedController.positions.length, 1);
      expect(nestedScrollable.position.physics, isA<BouncingScrollPhysics>());
      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('glass-menu-header-1')),
          matching: find.text('Open nested'),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        rootScrollable.position.pixels,
        closeTo(offsetBeforeSubmenu, 0.01),
      );
    },
  );

  testWidgets(
    'swipe-to-select works without a pill or row scale in a fitting menu',
    (tester) async {
      VoidCallback? toggleMenu;
      int? selectedOption;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: GlassMenu(
              menuWidth: 260,
              menuHeight: 240,
              items: [
                for (var index = 0; index < 4; index++)
                  GlassMenuItem(
                    title: 'Swipe option $index',
                    onTap: () => selectedOption = index,
                  ),
              ],
              triggerBuilder: (context, toggle) {
                toggleMenu = toggle;
                return CupertinoButton(
                  onPressed: toggle,
                  child: const Text('Actions'),
                );
              },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      toggleMenu!();
      await tester.pumpAndSettle();

      final fittingScrollView = find.byType(SingleChildScrollView).last;
      final fittingScrollable = tester.state<ScrollableState>(
        find.descendant(
          of: fittingScrollView,
          matching: find.byType(Scrollable),
        ),
      );
      expect(
        fittingScrollable.position.physics,
        isA<NeverScrollableScrollPhysics>(),
      );

      final pill = find.byKey(const ValueKey('glass-menu-selection-pill'));
      expect(pill, findsNothing);
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Swipe option 0')),
      );
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Swipe option 1')));
      await tester.pump();
      expect(pill, findsNothing);
      final selectedRow = find.ancestor(
        of: find.text('Swipe option 1'),
        matching: find.byType(GlassMenuItem),
      );
      expect(
        tester.widget<GlassMenuItem>(selectedRow.first).enablePressScale,
        isFalse,
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(pill, findsNothing);
      expect(selectedOption, 1);
    },
  );

  testWidgets('a fitting nested menu has no rubberband but slide-selects', (
    tester,
  ) async {
    int? selectedNestedOption;
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: GlassMenu(
            menuWidth: 260,
            items: [
              GlassMenuItem(
                title: 'Open nested',
                submenu: [
                  GlassMenuItem(
                    title: 'Nested option 1',
                    onTap: () => selectedNestedOption = 1,
                  ),
                  GlassMenuItem(
                    title: 'Nested option 2',
                    onTap: () => selectedNestedOption = 2,
                  ),
                ],
                onTap: () {},
              ),
            ],
            triggerBuilder: (context, toggle) => CupertinoButton(
              onPressed: toggle,
              child: const Text('Actions'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open nested'));
    await tester.pumpAndSettle();

    final nestedScrollView = find.byType(SingleChildScrollView).last;
    final nestedScrollable = tester.state<ScrollableState>(
      find.descendant(
        of: nestedScrollView,
        matching: find.byType(Scrollable),
      ),
    );
    expect(nestedScrollable.position.maxScrollExtent, 0);
    expect(
      nestedScrollable.position.physics,
      isA<NeverScrollableScrollPhysics>(),
    );

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Nested option 1')),
    );
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Nested option 2')));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('glass-menu-selection-pill')),
      findsNothing,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selectedNestedOption, 2);
  });
}
