import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassContainer,
        GlassGlow,
        GlassInteractiveContainer,
        GlassMenuItem,
        GlassQuality;
import 'package:smart_scheduler/app_theme.dart'
    show kPrimaryLabel, resolveThemeColor;
import 'package:smart_scheduler/widgets/action_panel.dart'
    show ActionItem, ActionPanel;

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
        expect(rows.first.iconLabelGap, 12);
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
