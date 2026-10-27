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
}

void _ignoreSwitchChange(bool _) {}
