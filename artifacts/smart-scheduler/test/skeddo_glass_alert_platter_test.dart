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
}

void _noop() {}
