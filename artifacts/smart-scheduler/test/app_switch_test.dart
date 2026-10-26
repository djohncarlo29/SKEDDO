import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassSwitch, LiquidGlassSwitchLayout;

import '../lib/widgets/app_switch.dart';

void main() {
  testWidgets(
    'Android AppSwitch leaves LiquidGlassSwitch styling at package defaults',
    (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: AppSwitch(value: false, onChanged: _ignoreSwitchChange),
        ),
      );

      final switchWidget = tester.widget<LiquidGlassSwitch>(
        find.byType(LiquidGlassSwitch),
      );
      expect(switchWidget.style, isNull);
      expect(switchWidget.width, isNull);
      expect(switchWidget.height, isNull);
      expect(switchWidget.layout, const LiquidGlassSwitchLayout());
      expect(switchWidget.activeColor, const Color(0xFF34C759));
      expect(switchWidget.inactiveColor, const Color(0x4C787880));
      expect(LiquidGlassSwitch.defaultStyle.dispersion, 1.0);
    },
  );
}

void _ignoreSwitchChange(bool _) {}
