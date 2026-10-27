import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassSwitch, LiquidGlassSwitchLayout;

import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/widgets/app_switch.dart';

void main() {
  testWidgets(
    'Liquid Glass AppSwitch forwards app colors and keeps package defaults',
    (tester) async {
      const accentColor = Color(0xFF8A4DCC);
      await tester.pumpWidget(
        CupertinoApp(
          home: AppSwitch(
            value: false,
            onChanged: _ignoreSwitchChange,
            color: accentColor,
          ),
        ),
      );

      final appSwitchContext = tester.element(find.byType(AppSwitch));
      final switchWidget = tester.widget<LiquidGlassSwitch>(
        find.byType(LiquidGlassSwitch),
      );
      expect(switchWidget.style, isNull);
      expect(switchWidget.width, isNull);
      expect(switchWidget.height, isNull);
      expect(switchWidget.layout, const LiquidGlassSwitchLayout());
      expect(switchWidget.activeColor, accentColor);
      expect(
        switchWidget.inactiveColor,
        resolveThemeColor(kTertiaryLabel, appSwitchContext),
      );
      expect(LiquidGlassSwitch.defaultStyle.dispersion, 1.0);
    },
  );

  testWidgets(
    'switch taps in a scaled modal-style row update once and settle',
    (tester) async {
      var allDay = false;
      var changes = 0;

      await tester.pumpWidget(
        CupertinoApp(
          home: StatefulBuilder(
            builder: (context, setState) => GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => allDay = !allDay),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Row(
                  children: [
                    const Text('All-day'),
                    const Spacer(),
                    SizedBox(
                      width: 70 * 0.80,
                      height: 30,
                      child: OverflowBox(
                        maxWidth: 70,
                        maxHeight: 31,
                        alignment: Alignment.center,
                        child: Transform.scale(
                          scale: 0.80,
                          child: AppSwitch(
                            value: allDay,
                            onChanged: (_) {
                              changes++;
                              setState(() => allDay = !allDay);
                            },
                            height: 31,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );

      final switchFinder = find.byType(LiquidGlassSwitch);
      Future<void> settleFrames() async {
        for (var frame = 0; frame < 60; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
      }

      await tester.tap(switchFinder);
      await settleFrames();
      expect(allDay, isTrue);
      expect(changes, 1);

      await tester.tap(switchFinder);
      await settleFrames();
      expect(allDay, isFalse);
      expect(changes, 2);
    },
  );
}

void _ignoreSwitchChange(bool _) {}
