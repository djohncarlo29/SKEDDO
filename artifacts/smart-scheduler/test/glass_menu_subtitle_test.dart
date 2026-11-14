import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show PointerScrollEvent;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassMenu, GlassMenuController, GlassMenuDivider, GlassMenuItem;
import 'package:liquid_glass_widgets/utils/glass_morph_controller.dart'
    show GlassMorphContentMotion;

void main() {
  test('GlassMenu retains its original default corner radius', () {
    const menu = GlassMenu(items: [], trigger: Text('Actions'));
    expect(menu.menuBorderRadius, 32.0);
    expect(menu.keepTriggerAnchorOnOverflow, isFalse);
  });

  testWidgets('menu content stays at its destination during the morph', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = GlassMenuController();
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 48, top: 88),
              child: GlassMenu(
                controller: controller,
                menuWidth: 260,
                items: [
                  GlassMenuItem(title: 'Anchored option', onTap: () {}),
                ],
                triggerBuilder: (context, toggle) => CupertinoButton(
                  onPressed: toggle,
                  child: const Text('Open menu'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open menu'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final openingRect = tester.getRect(find.text('Anchored option'));

    await tester.pumpAndSettle();
    final settledRect = tester.getRect(find.text('Anchored option'));
    expect(
      (openingRect.center - settledRect.center).distance,
      lessThan(40),
      reason: 'The content should scale in place, not travel from the trigger.',
    );

    controller.close();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final closingRect = tester.getRect(find.text('Anchored option'));
    expect(
      (closingRect.center - settledRect.center).distance,
      lessThan(40),
      reason: 'The content should stay put while the platter returns.',
    );
    await tester.pumpAndSettle();
  });

  test('menu content starts oversized and clipped by the surface morph', () {
    expect(
      GlassMorphContentMotion.isVisible(progress: 0.0, isClosing: false),
      isTrue,
    );
    expect(GlassMorphContentMotion.opacity(progress: 0.0, isClosing: false), 0);
    expect(
      GlassMorphContentMotion.opacity(progress: 0.075, isClosing: false),
      closeTo(0.5, 0.001),
    );
    expect(
      GlassMorphContentMotion.opacity(progress: 0.5, isClosing: false),
      1.0,
    );
    expect(
      GlassMorphContentMotion.opacity(progress: 0.0, isClosing: true),
      1.0,
    );
    expect(
      GlassMorphContentMotion.opacity(progress: 0.925, isClosing: true),
      closeTo(0.5, 0.001),
    );
    expect(
      GlassMorphContentMotion.isVisible(progress: 0.0, isClosing: true),
      isTrue,
    );
    expect(GlassMorphContentMotion.scale(0.0), 1.25);
    expect(GlassMorphContentMotion.scale(1.0), 1.0);
    expect(
      GlassMorphContentMotion.blurSigma(progress: 0.0, isClosing: false),
      4.0,
    );
    expect(
      GlassMorphContentMotion.blurSigma(progress: 1.0, isClosing: false),
      0.0,
    );
    expect(
      GlassMorphContentMotion.scaleForMorph(progress: 1.0, isClosing: true),
      1.0,
    );
    expect(
      GlassMorphContentMotion.scaleForMorph(progress: 0.0, isClosing: true),
      1.25,
    );
  });

  testWidgets(
    'Sort By checkmark rows use 16pt while parent and separator keep 12pt',
    (tester) async {
      final controller = GlassMenuController();
      const leadingSlotKey = ValueKey('sort-selected-leading-slot');
      const separatorKey = ValueKey('sort-submenu-separator');

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: GlassMenu(
                controller: controller,
                menuWidth: 260,
                items: [
                  GlassMenuItem(
                    title: 'Sort By',
                    submenu: [
                      GlassMenuItem(
                        title: 'Manual',
                        icon: const SizedBox(
                          key: leadingSlotKey,
                          width: 24,
                          height: 24,
                        ),
                        iconSize: 24,
                        contentHorizontalInset: 0,
                        onTap: () {},
                      ),
                      const GlassMenuDivider(key: separatorKey, height: 8),
                    ],
                    onTap: () {},
                  ),
                ],
                triggerBuilder: (context, toggle) => CupertinoButton(
                  onPressed: toggle,
                  child: const Text('Menu'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      controller.open();
      await tester.pumpAndSettle();

      final rootSurfaceRect = tester.getRect(
        find.byKey(const ValueKey('glass-menu-scroll-surface-0')),
      );
      final parentLabelRect = tester.getRect(find.text('Sort By'));
      expect(parentLabelRect.left - rootSurfaceRect.left, closeTo(28, 0.01));

      await tester.tap(find.text('Sort By'));
      await tester.pumpAndSettle();

      final cardRect = tester.getRect(
        find.byKey(const ValueKey('glass-menu-submenu-card-0')),
      );
      final leadingSlotRect = tester.getRect(find.byKey(leadingSlotKey));
      expect(leadingSlotRect.left - cardRect.left, 16);
      final separatorRect = tester.getRect(find.byKey(separatorKey));
      expect(separatorRect.left - cardRect.left, closeTo(12, 0.01));
    },
  );

  testWidgets(
    'separator keeps 12pt inset when option rows use no extra inset',
    (tester) async {
      final controller = GlassMenuController();
      const dividerKey = ValueKey('zero-row-inset-menu-divider');

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: GlassMenu(
                controller: controller,
                menuWidth: 260,
                menuContentHorizontalInset: 0,
                items: [
                  GlassMenuItem(
                    title: 'Compact',
                    contentHorizontalInset: 0,
                    onTap: () {},
                  ),
                  const GlassMenuDivider(key: dividerKey, height: 8),
                  GlassMenuItem(
                    title: 'List',
                    contentHorizontalInset: 0,
                    onTap: () {},
                  ),
                ],
                triggerBuilder: (context, toggle) => CupertinoButton(
                  onPressed: toggle,
                  child: const Text('Menu'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      controller.open();
      await tester.pumpAndSettle();

      final surfaceRect = tester.getRect(
        find.byKey(const ValueKey('glass-menu-scroll-surface-0')),
      );
      final dividerRect = tester.getRect(find.byKey(dividerKey));
      expect(dividerRect.left - surfaceRect.left, closeTo(12, 0.01));
    },
  );

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

  testWidgets('GlassMenuItem supports an exact custom leading-label gap', (
    tester,
  ) async {
    const iconKey = ValueKey('leading-checkmark-slot');
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 260,
            child: GlassMenuItem(
              title: 'Selected option',
              icon: const SizedBox(key: iconKey, width: 17, height: 17),
              iconSize: 17,
              iconLabelGap: 16,
              onTap: () {},
            ),
          ),
        ),
      ),
    );

    final rowRect = tester.getRect(find.byType(GlassMenuItem));
    final iconRect = tester.getRect(find.byKey(iconKey));
    final labelRect = tester.getRect(find.text('Selected option'));
    expect(iconRect.left - rowRect.left, 16);
    expect(labelRect.left - iconRect.right, 16);
  });

  testWidgets('overflowing anchored menus scroll from the trigger edge', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = GlassMenuController();
    const triggerKey = ValueKey('anchored-overflow-trigger');
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 80, top: 180),
              child: GlassMenu(
                controller: controller,
                menuWidth: 240,
                autoAdjustToScreen: true,
                keepTriggerAnchorOnOverflow: true,
                menuPadding: const EdgeInsets.all(16),
                items: [
                  for (var index = 0; index < 12; index++)
                    GlassMenuItem(title: 'Choice $index', onTap: () {}),
                ],
                triggerBuilder: (context, toggleMenu) => GestureDetector(
                  key: triggerKey,
                  onTap: toggleMenu,
                  child: const SizedBox(
                    width: 80,
                    height: 44,
                    child: Text('Picker'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    controller.open();
    await tester.pumpAndSettle();

    final triggerRect = tester.getRect(find.byKey(triggerKey));
    final scrollViewFinder = find.byType(SingleChildScrollView).last;
    final scrollViewRect = tester.getRect(scrollViewFinder);
    final scrollableFinder = find.descendant(
      of: scrollViewFinder,
      matching: find.byType(Scrollable),
    );
    final scrollable = tester.state<ScrollableState>(scrollableFinder);

    expect(scrollable.position.maxScrollExtent, greaterThan(0));
    expect(scrollViewRect.bottom, closeTo(triggerRect.bottom, 1));
  });

  testWidgets('multi-select items can keep their GlassMenu open', (
    tester,
  ) async {
    final controller = GlassMenuController();
    var selectionCount = 0;
    var closeCount = 0;

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: GlassMenu(
              controller: controller,
              items: [
                GlassMenuItem(
                  title: 'Toggle category',
                  closeOnTap: false,
                  onTap: () => selectionCount++,
                ),
              ],
              onClose: () => closeCount++,
              triggerBuilder: (context, toggleMenu) => CupertinoButton(
                onPressed: toggleMenu,
                child: const Text('Include'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Include'));
    await tester.pumpAndSettle();
    expect(controller.isOpen, isTrue);

    await tester.tap(find.text('Toggle category'));
    await tester.pumpAndSettle();
    expect(selectionCount, 1);
    expect(controller.isOpen, isTrue);
    expect(closeCount, 0);

    controller.close();
    await tester.pumpAndSettle();
    expect(controller.isOpen, isFalse);
    expect(closeCount, 1);
  });

  test('trigger impact strength defaults to the existing rebound', () {
    const defaultMenu = GlassMenu(items: [], trigger: Text('Actions'));
    const pickerMenu = GlassMenu(
      items: [],
      trigger: Text('Picker value'),
      triggerImpactStrength: 1.15,
    );

    expect(defaultMenu.triggerImpactStrength, 1.0);
    expect(pickerMenu.triggerImpactStrength, 1.15);
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

  testWidgets('overflow scrolling does not glide-highlight menu options', (
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
    void expectNoGlideHighlight() {
      expect(
        tester
            .widgetList<GlassMenuItem>(find.byType(GlassMenuItem))
            .where((item) => item.isInteractionHighlighted),
        isEmpty,
      );
    }

    expectNoGlideHighlight();

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
    expectNoGlideHighlight();

    // Pulling beyond the top edge uses the scroll view's rubberband response,
    // but must not turn that gesture into a row-selection highlight.
    await tester.drag(scrollableFinderTarget, const Offset(0, 400));
    await tester.pumpAndSettle();
    expectNoGlideHighlight();
  });

  testWidgets('press and long-press show interaction highlight and row scale', (
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

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Option 0')),
    );
    await tester.pump();
    final optionRow = find
        .ancestor(
          of: find.text('Option 0'),
          matching: find.byType(GlassMenuItem),
        )
        .first;
    final rowScale = find.descendant(
      of: optionRow,
      matching: find.byType(AnimatedScale),
    );
    final activeItem = tester.widget<GlassMenuItem>(optionRow);
    expect(activeItem.showInteractionHighlight, isTrue);
    expect(activeItem.enablePressScale, isTrue);
    expect(tester.widget<AnimatedScale>(rowScale).scale, 0.98);
    await tester.pump(const Duration(milliseconds: 510));
    expect(tester.widget<AnimatedScale>(rowScale).scale, 0.98);
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
      expect(indicatorTrack.padding, const EdgeInsets.symmetric(vertical: 32));
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
    'swipe-to-select highlights and scales the active row in a fitting menu',
    (tester) async {
      VoidCallback? toggleMenu;
      int? selectedOption;
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: GlassMenu(
              menuWidth: 260,
              menuHeight: 240,
              useAdaptiveInteractionHighlight: true,
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

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Swipe option 0')),
      );
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('Swipe option 1')));
      await tester.pump();
      final previousRow = find.ancestor(
        of: find.text('Swipe option 0'),
        matching: find.byType(GlassMenuItem),
      );
      final previousSurface = find.descendant(
        of: previousRow.first,
        matching: find.byType(AnimatedContainer),
      );
      expect(
        (tester.widget<AnimatedContainer>(previousSurface.first).decoration
                as BoxDecoration)
            .color,
        const Color(0x00000000),
      );
      final selectedRow = find.ancestor(
        of: find.text('Swipe option 1'),
        matching: find.byType(GlassMenuItem),
      );
      expect(
        tester.widget<GlassMenuItem>(selectedRow.first).isInteractionHighlighted,
        isTrue,
      );
      expect(
        tester.widget<GlassMenuItem>(selectedRow.first).enablePressScale,
        isTrue,
      );
      expect(
        tester
            .widget<AnimatedScale>(
              find
                  .descendant(
                    of: selectedRow.first,
                    matching: find.byType(AnimatedScale),
                  )
                  .first,
            )
            .scale,
        0.98,
      );

      await gesture.up();
      await tester.pumpAndSettle();
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
      find.descendant(of: nestedScrollView, matching: find.byType(Scrollable)),
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
    final highlightedNestedOption = find.ancestor(
      of: find.text('Nested option 2'),
      matching: find.byType(GlassMenuItem),
    );
    expect(
      tester
          .widget<GlassMenuItem>(highlightedNestedOption.first)
          .isInteractionHighlighted,
      isTrue,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(selectedNestedOption, 2);
  });
}
