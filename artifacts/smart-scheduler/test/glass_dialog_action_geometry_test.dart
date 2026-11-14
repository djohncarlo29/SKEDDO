import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassButton,
        GlassDialog,
        GlassDialogAction,
        GlassQuality,
        LiquidGlassSettings,
        LiquidRoundedSuperellipse;

void main() {
  testWidgets('GlassDialog keeps fixed corners as action labels wrap', (
    tester,
  ) async {
    const longLabel =
        'Permanently delete this event and remove it from Recently Deleted';

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: GlassDialog(
              title: 'Confirm deletion',
              actions: const [
                GlassDialogAction(label: longLabel, onPressed: _noop),
              ],
              settings: const LiquidGlassSettings(),
              quality: GlassQuality.minimal,
              maxWidth: 200,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final buttonFinder = find.byType(GlassButton);
    final button = tester.widget<GlassButton>(buttonFinder);
    expect(button.height, isNull);
    expect(button.shape, const LiquidRoundedSuperellipse(borderRadius: 24));
    expect(tester.getSize(buttonFinder).height, greaterThan(44));
    expect(tester.takeException(), isNull);
  });
}

void _noop() {}
