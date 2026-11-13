import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sficon/flutter_sficon.dart' show SFIcons;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassContainer,
        GlassGlow,
        GlassInteractiveContainer,
        GlassMenuContentLens,
        GlassMenuItem,
        GlassQuality;
import 'package:smart_scheduler/app_theme.dart'
    show kPrimaryLabel, resolveThemeColor;
import 'package:smart_scheduler/widgets/action_panel.dart'
    show ActionItem, ActionPanel, ActionPanelGlideController;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'context action panel resolves GlassMenu labels in $brightness',
      (tester) async {
        final closing = ValueNotifier(false);
        addTearDown(closing.dispose);
        var editCount = 0;
        var deleteCount = 0;

        await tester.pumpWidget(
          CupertinoApp(
            theme: CupertinoThemeData(brightness: brightness),
            home: Center(
              child: SizedBox(
                width: 250,
                child: ActionPanel(
                  isClosing: closing,
                  useGlassMenuStyle: true,
                  scaleAlignment: Alignment.bottomCenter,
                  items: [
                    ActionItem(
                      label: 'Edit Event Info',
                      icon: CupertinoIcons.pencil,
                      onTap: () => editCount++,
                    ),
                    ActionItem(
                      label: 'Delete Event',
                      icon: CupertinoIcons.trash,
                      isDestructive: true,
                      onTap: () => deleteCount++,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final surface = tester.widget<GlassContainer>(
          find.byType(GlassContainer),
        );
        expect(find.byType(GlassInteractiveContainer), findsOneWidget);
        expect(find.byType(GlassGlow), findsOneWidget);
        expect(surface.quality, GlassQuality.premium);
        expect(surface.settings!.thickness, 30);
        expect(surface.settings!.refractiveIndex, 1.59);
        expect(surface.settings!.chromaticAberration, 0.3);
        expect(surface.settings!.visibility, 1);
        final foregroundLens = tester.widget<GlassMenuContentLens>(
          find.byType(GlassMenuContentLens),
        );
        expect(foregroundLens.thickness, 30);
        expect(foregroundLens.refractiveIndex, 1.30);
        expect(foregroundLens.chromaticAberration, 0.06);
        expect(foregroundLens.normalizedEffectStrength, 0);
        expect(foregroundLens.effectiveThickness, 0);
        expect(foregroundLens.effectiveRefractiveIndex, 1);
        expect(foregroundLens.effectiveChromaticAberration, 0);
        expect(
          foregroundLens.size,
          tester.getSize(find.byType(GlassContainer)),
        );

        final rows = tester.widgetList<GlassMenuItem>(
          find.byType(GlassMenuItem),
        );
        final rowsHeight = rows.fold<double>(
          0,
          (height, row) => height + tester.getSize(find.byWidget(row)).height,
        );
        expect(
          tester.getSize(find.byType(GlassContainer)).height,
          rowsHeight + 24,
        );
        expect(rows, hasLength(2));
        expect(rows.first.title, 'Edit Event Info');
        expect(rows.map((row) => row.iconSize), everyElement(28.0));
        expect(rows.first.iconLabelGap, 12);
        final iconSlot = rows.first.icon! as SizedBox;
        expect(iconSlot.width, 28);
        expect(iconSlot.height, 28);
        expect(iconSlot.child, isA<Center>());
        expect(rows.first.titleStyle!.fontSize, 17);
        expect(rows.first.allowTextWrapping, isTrue);
        expect(rows.first.enablePressScale, isTrue);
        expect(rows.first.showInteractionHighlight, isFalse);
        expect(rows.first.isSelected, isFalse);
        expect(rows.last.isDestructive, isTrue);
        final titleContext = tester.element(find.text('Edit Event Info'));
        expect(
          rows.first.titleStyle!.color,
          resolveThemeColor(kPrimaryLabel, titleContext).withValues(alpha: 0.9),
        );
        expect(rows.last.titleStyle!.color, CupertinoColors.destructiveRed);
        expect(
          tester
              .widgetList<Transform>(find.byType(Transform))
              .any(
                (transform) => transform.alignment == Alignment.bottomCenter,
              ),
          isTrue,
        );

        await tester.tap(find.text('Edit Event Info'));
        expect(editCount, 1);
        expect(deleteCount, 0);
      },
    );
  }

  testWidgets('instant-on-open options are visible on the same frame', (
    tester,
  ) async {
    final closing = ValueNotifier(false);
    addTearDown(closing.dispose);
    const labels = ['Pin', 'Edit Category Info', 'Archive Category'];

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 280,
            child: ActionPanel(
              isClosing: closing,
              useGlassMenuStyle: true,
              items: [
                for (final label in labels)
                  ActionItem(
                    label: label,
                    icon: CupertinoIcons.pencil,
                    instantOnOpen: true,
                    onTap: () {},
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    final initialRowTransforms = tester
        .widgetList<Transform>(
          find.ancestor(
            of: find.text(labels.first),
            matching: find.byType(Transform),
          ),
        )
        .map((transform) => transform.transform.getMaxScaleOnAxis());
    expect(initialRowTransforms, contains(closeTo(1.25, 0.001)));
    expect(
      find.ancestor(
        of: find.text(labels.first),
        matching: find.byType(ImageFiltered),
      ),
      findsOneWidget,
    );
    await tester.pump(const Duration(milliseconds: 16));

    for (final label in labels) {
      final rowOpacity = tester
          .widgetList<Opacity>(
            find.ancestor(of: find.text(label), matching: find.byType(Opacity)),
          )
          .first;
      expect(
        rowOpacity.opacity,
        1.0,
        reason: '$label should appear immediately',
      );
    }
  });

  testWidgets('context menu icon slots grow without clipping at large text', (
    tester,
  ) async {
    final closing = ValueNotifier(false);
    addTearDown(closing.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.5)),
          child: Center(
            child: SizedBox(
              width: 250,
              child: ActionPanel(
                isClosing: closing,
                useGlassMenuStyle: true,
                items: [
                  ActionItem(
                    label: 'Edit Event Info',
                    icon: CupertinoIcons.pencil,
                    iconSize: 24,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final row = tester.widget<GlassMenuItem>(find.byType(GlassMenuItem));
    expect(row.iconSize, greaterThan(70));
    expect(row.iconLabelGap, 12);
    final iconSlot = row.icon! as SizedBox;
    expect(iconSlot.width, 70);
    expect(iconSlot.height, greaterThan(70));
    expect(
      tester.getSize(find.byType(GlassMenuItem)).height,
      greaterThanOrEqualTo(row.iconSize + 16),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('archive glyph reuses the toolbar menu optical offset', (
    tester,
  ) async {
    final closing = ValueNotifier(false);
    addTearDown(closing.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Center(
            child: SizedBox(
              width: 260,
              child: ActionPanel(
                isClosing: closing,
                useGlassMenuStyle: true,
                items: [
                  ActionItem(
                    label: 'Archive Category',
                    icon: SFIcons.sf_archivebox,
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final translated = tester.widgetList<Transform>(find.byType(Transform));
    expect(
      translated.any(
        (transform) =>
            (transform.transform.getTranslation().x + 0.5).abs() < 0.001,
      ),
      isTrue,
    );
  });

  testWidgets('external long-press glide activates the row under release', (
    tester,
  ) async {
    final closing = ValueNotifier(false);
    final glide = ActionPanelGlideController();
    addTearDown(closing.dispose);
    addTearDown(glide.dispose);
    var pinCount = 0;
    var archiveCount = 0;

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 270,
            child: ActionPanel(
              isClosing: closing,
              useGlassMenuStyle: true,
              externalGlideController: glide,
              items: [
                ActionItem(
                  label: 'Pin',
                  icon: CupertinoIcons.pin,
                  onTap: () => pinCount++,
                ),
                ActionItem(
                  label: 'Archive Category',
                  icon: SFIcons.sf_archivebox,
                  onTap: () => archiveCount++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    glide.move(tester.getCenter(find.text('Pin')));
    glide.move(tester.getCenter(find.text('Archive Category')));
    glide.end(tester.getCenter(find.text('Archive Category')));

    expect(pinCount, 0);
    expect(archiveCount, 1);
  });

  testWidgets('external glide scrolls overflowing rows before activation', (
    tester,
  ) async {
    final closing = ValueNotifier(false);
    final glide = ActionPanelGlideController();
    addTearDown(closing.dispose);
    addTearDown(glide.dispose);
    var selected = '';

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 270,
            child: ActionPanel(
              isClosing: closing,
              useGlassMenuStyle: true,
              externalGlideController: glide,
              maxHeight: 132,
              items: [
                for (var index = 0; index < 6; index++)
                  ActionItem(
                    label: 'Option $index',
                    icon: CupertinoIcons.circle,
                    onTap: () => selected = 'Option $index',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewportFinder = find.byType(SingleChildScrollView).first;
    final viewport = tester.getRect(viewportFinder);
    final controller = tester
        .widget<SingleChildScrollView>(viewportFinder)
        .controller!;
    final dragNearBottom = Offset(viewport.center.dx, viewport.bottom - 10);
    glide.move(dragNearBottom);
    await tester.pump();
    for (var index = 0; index < 10; index++) {
      glide.move(
        Offset(viewport.center.dx, viewport.bottom - (index.isEven ? 20 : 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(controller.offset, greaterThan(0));

    final visibleOption = find.text('Option 3');
    expect(visibleOption, findsOneWidget);
    final optionPosition = tester.getCenter(visibleOption);
    glide.move(optionPosition);
    glide.end(optionPosition);
    expect(selected, 'Option 3');
  });

  testWidgets('an opened context platter supports its own glide selection', (
    tester,
  ) async {
    final closing = ValueNotifier(false);
    addTearDown(closing.dispose);
    var pinCount = 0;
    var archiveCount = 0;

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 270,
            child: ActionPanel(
              isClosing: closing,
              useGlassMenuStyle: true,
              items: [
                ActionItem(
                  label: 'Pin',
                  icon: CupertinoIcons.pin,
                  onTap: () => pinCount++,
                ),
                ActionItem(
                  label: 'Archive Category',
                  icon: SFIcons.sf_archivebox,
                  onTap: () => archiveCount++,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Pin')),
    );
    await gesture.moveTo(tester.getCenter(find.text('Archive Category')));
    await tester.pump(const Duration(milliseconds: 20));
    await gesture.up();
    await tester.pump();

    expect(pinCount, 0);
    expect(archiveCount, 1);
  });

  testWidgets('an independently scrolled platter selects on release', (
    tester,
  ) async {
    final closing = ValueNotifier(false);
    addTearDown(closing.dispose);
    var selected = '';

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 270,
            child: ActionPanel(
              isClosing: closing,
              useGlassMenuStyle: true,
              maxHeight: 132,
              items: [
                for (var index = 0; index < 7; index++)
                  ActionItem(
                    label: 'Option $index',
                    icon: CupertinoIcons.circle,
                    onTap: () => selected = 'Option $index',
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final viewportFinder = find.byType(SingleChildScrollView).first;
    final viewport = tester.getRect(viewportFinder);
    final scrollController = tester
        .widget<SingleChildScrollView>(viewportFinder)
        .controller!;
    // The menu is deliberately over height so this verifies its real scroll
    // path, not just glide-selecting rows that were initially visible.
    expect(scrollController.position.maxScrollExtent, greaterThan(0));
    final start = Offset(viewport.center.dx, viewport.bottom - 10);
    final gesture = await tester.startGesture(start);
    var releasePosition = start;
    for (var step = 1; step <= 10; step++) {
      releasePosition = start.translate(0, -step * 8.0);
      await gesture.moveTo(releasePosition);
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(scrollController.offset, greaterThan(0));
    const targetLabel = 'Option 1';
    final targetPosition = tester.getCenter(find.text(targetLabel));
    await gesture.moveTo(targetPosition);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.up();
    await tester.pump();
    expect(selected, targetLabel);
  });

  testWidgets('context action panel scrolls and reveals its scroll pill', (
    tester,
  ) async {
    final closing = ValueNotifier(false);
    addTearDown(closing.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 250,
            child: ActionPanel(
              isClosing: closing,
              useGlassMenuStyle: true,
              maxHeight: 96,
              bouncingScroll: true,
              items: [
                for (var i = 0; i < 5; i++)
                  ActionItem(
                    label: 'Action $i',
                    icon: CupertinoIcons.pencil,
                    onTap: () {},
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView).first,
    );
    expect(scrollView.physics, isA<BouncingScrollPhysics>());
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Positioned && widget.width == 2.5,
      ),
      findsOneWidget,
    );
    final menuScrollPill = tester.widget<Positioned>(
      find.byWidgetPredicate(
        (widget) =>
            widget is Positioned &&
            widget.width == 2.5 &&
            widget.right == -9 &&
            widget.top == 20 &&
            widget.bottom == 20,
      ),
    );
    expect(menuScrollPill.right, -9);

    await tester.drag(
      find.byType(SingleChildScrollView).first,
      const Offset(0, -70),
    );
    await tester.pumpAndSettle();
    expect(
      find.byWidgetPredicate(
        (widget) => widget is AnimatedOpacity && widget.opacity == 0.8,
      ),
      findsWidgets,
    );
  });
}
