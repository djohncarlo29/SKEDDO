import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glass_widgets/widgets/shared/glass_effect.dart';
import 'package:smart_scheduler/widgets/skeddo_glass_switch.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets(
      'switch thumb uses shared optics and preserves its ${brightness.name} tint opacity',
      (tester) async {
        await tester.pumpWidget(
          CupertinoApp(
            theme: CupertinoThemeData(brightness: brightness),
            home: CupertinoPageScaffold(
              child: Center(
                child: SkeddoGlassSwitch(value: false, onChanged: (_) {}),
              ),
            ),
          ),
        );

        final effect = tester.widget<GlassEffect>(find.byType(GlassEffect));
        expect(
          effect.settings.glassColor.a,
          brightness == Brightness.dark ? 0.08 : 0.12,
        );
        expect(effect.settings.blur, 3);
        expect(effect.settings.chromaticAberration, 0.3);
        expect(effect.settings.refractiveIndex, 1.59);
      },
    );
  }

  testWidgets('switch taps still toggle its controlled value', (tester) async {
    var value = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (context, setState) => Center(
            child: SkeddoGlassSwitch(
              value: value,
              enableHaptics: false,
              onChanged: (nextValue) {
                setState(() => value = nextValue);
              },
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byType(SkeddoGlassSwitch));
    await tester.pump();
    expect(value, isTrue);
  });

  testWidgets('dragging the thumb still changes the switch value', (
    tester,
  ) async {
    var value = false;
    await tester.pumpWidget(
      CupertinoApp(
        home: StatefulBuilder(
          builder: (context, setState) => Center(
            child: SkeddoGlassSwitch(
              value: value,
              enableHaptics: false,
              onChanged: (nextValue) {
                setState(() => value = nextValue);
              },
            ),
          ),
        ),
      ),
    );

    await tester.drag(find.byType(SkeddoGlassSwitch), const Offset(36, 0));
    await tester.pumpAndSettle();
    expect(value, isTrue);
  });
}
