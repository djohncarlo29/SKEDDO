import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassIconButton, GlassIconButtonShape, GlassQuality;

import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/widgets/modal_toolbar_glass_button.dart';
import 'package:smart_scheduler/widgets/skeddo_glass_settings.dart';

void main() {
  testWidgets('modal toolbar uses package glass icon button in both themes', (
    tester,
  ) async {
    const actionColor = Color(0xFF7B3FE4);

    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        CupertinoApp(
          theme: CupertinoThemeData(brightness: brightness),
          home: Center(
            child: ModalToolbarGlassButton(
              icon: CupertinoIcons.checkmark,
              iconColor: CupertinoColors.white,
              surfaceColor: actionColor,
              isCheckmark: true,
              onTap: () {},
            ),
          ),
        ),
      );

      final button = tester.widget<GlassIconButton>(
        find.byType(GlassIconButton),
      );
      final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.checkmark));
      expect(button.size, 40);
      expect(button.iconSize, 20);
      expect(button.shape, GlassIconButtonShape.circle);
      expect(button.quality, GlassQuality.premium);
      expect(button.useOwnLayer, isTrue);
      expect(
        button.settings,
        skeddoTintedActionGlassSettingsFor(brightness, actionColor),
      );
      expect(
        button.settings!.glassColor,
        actionColor.withValues(alpha: kSkeddoTintedActionGlassOpacity),
      );
      expect(
        icon.color!.toARGB32(),
        CupertinoColors.white.toARGB32(),
      );
    }
  });

  testWidgets('unavailable checkmark disables the package glass button', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: ModalToolbarGlassButton(
            icon: CupertinoIcons.checkmark,
            iconColor: CupertinoColors.white,
            surfaceColor: kDisabledActionSurface,
            isCheckmark: true,
            onTap: _noOp,
          ),
        ),
      ),
    );

    final button = tester.widget<GlassIconButton>(find.byType(GlassIconButton));
    expect(button.onPressed, isNull);
  });
}

void _noOp() {}
