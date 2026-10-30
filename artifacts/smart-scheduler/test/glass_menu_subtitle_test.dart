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
}
