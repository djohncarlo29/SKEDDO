import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassMenu, GlassMenuItem, GlassMenuSelectionPillBehavior;

void main() {
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

  testWidgets('selection pill appears during scrolling but not on menu open', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: GlassMenu(
              menuWidth: 260,
              menuHeight: 130,
              selectionPillBehavior:
                  GlassMenuSelectionPillBehavior.scrollOrLongPress,
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
    expect(pill, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 151));
    expect(pill, findsNothing);
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
      expect(tester.widget<AnimatedOpacity>(indicatorFinder).opacity, 0);

      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -80),
      );
      await tester.pump();
      expect(tester.widget<AnimatedOpacity>(indicatorFinder).opacity, 0.8);

      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.widget<AnimatedOpacity>(indicatorFinder).opacity, 0);
    },
  );
}
