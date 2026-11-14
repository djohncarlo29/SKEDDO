import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassDialogAction,
        GlassContainer,
        GlassQuality,
        LiquidGlassSettings,
        LiquidRoundedSuperellipse;
import 'package:smart_scheduler/widgets/skeddo_glass_alert_platter.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';

void main() {
  testWidgets('category alert platter uses the 1.17 layout and actions', (
    tester,
  ) async {
    String? selectedAction;
    const actions = [
      GlassDialogAction(label: 'Delete Category Only', onPressed: _noop),
      GlassDialogAction(
        label: 'Delete Category & Contents',
        isDestructive: true,
        onPressed: _noop,
      ),
      GlassDialogAction(label: 'Cancel', onPressed: _noop),
    ];

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SkeddoGlassAlertPlatter(
              title: 'Delete the category "Draggable"?',
              message: 'Choose how to handle its events.',
              actions: [
                for (final action in actions)
                  GlassDialogAction(
                    label: action.label,
                    isDestructive: action.isDestructive,
                    onPressed: () => selectedAction = action.label,
                  ),
              ],
              settings: const LiquidGlassSettings(),
              quality: GlassQuality.standard,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Delete the category "Draggable"?'), findsOneWidget);
    expect(find.text('Choose how to handle its events.'), findsOneWidget);
    expect(find.text('Delete Category Only'), findsOneWidget);
    expect(find.text('Delete Category & Contents'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final titleRect = tester.getRect(
      find.text('Delete the category "Draggable"?'),
    );
    final messageRect = tester.getRect(
      find.text('Choose how to handle its events.'),
    );
    final firstButtonRect = tester.getRect(
      find.ancestor(
        of: find.text('Delete Category Only'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(messageRect.top - titleRect.bottom, closeTo(20.33, 0.1));
    expect(firstButtonRect.top - messageRect.bottom, closeTo(20.33, 0.1));

    final platter = tester.widget<GlassContainer>(find.byType(GlassContainer));
    expect(platter.shape, const LiquidRoundedSuperellipse(borderRadius: 34));
    expect(platter.quality, GlassQuality.standard);

    await tester.tap(find.text('Delete Category & Contents'));
    await tester.pump();
    expect(selectedAction, 'Delete Category & Contents');
  });

  testWidgets('alert platter stays legible at accessibility text scaling', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: CupertinoPageScaffold(
          child: Center(
            child: SkeddoGlassAlertPlatter(
              title: 'Delete the category "Draggable"?',
              message:
                  'Choose whether to move the category and its event together.',
              actions: const [
                GlassDialogAction(
                  label: 'Delete Category Only',
                  onPressed: _noop,
                ),
                GlassDialogAction(
                  label: 'Delete Category & Contents',
                  isDestructive: true,
                  onPressed: _noop,
                ),
                GlassDialogAction(label: 'Cancel', onPressed: _noop),
              ],
              settings: const LiquidGlassSettings(),
              quality: GlassQuality.standard,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Delete Category & Contents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared dialog helper returns the chosen action', (tester) async {
    _latestResult = null;
    await tester.pumpWidget(
      const AppWindowContentBoundary(
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(child: _AlertDialogTestTrigger()),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm action?'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(_latestResult, 'confirmed');
  });
}

class _AlertDialogTestTrigger extends StatelessWidget {
  const _AlertDialogTestTrigger();

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => CupertinoButton(
        onPressed: () {
          showSkeddoGlassAlertDialog<String>(
            context: context,
            title: 'Confirm action?',
            message: 'This is a test.',
            actionsBuilder: (dialogContext) => [
              GlassDialogAction(
                label: 'Confirm',
                isPrimary: true,
                onPressed: () => Navigator.of(dialogContext).pop('confirmed'),
              ),
              GlassDialogAction(
                label: 'Cancel',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ).then((value) => _latestResult = value);
        },
        child: const Text('Open dialog'),
      ),
    );
  }
}

String? _latestResult;

void _noop() {}
