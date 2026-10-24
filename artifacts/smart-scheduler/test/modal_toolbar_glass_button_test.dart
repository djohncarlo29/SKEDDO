import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassButton, GlassQuality, GlassThemeData, GlassThemeVariant;

import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/widgets/modal_toolbar_glass_button.dart';

void main() {
  testWidgets('toolbar checkmark stays glass and follows the action color', (
    tester,
  ) async {
    const actionColor = Color(0xFF7B3FE4);

    for (final brightness in [Brightness.light, Brightness.dark]) {
      Color? resolvedGlassTint;
      await tester.pumpWidget(
        CupertinoApp(
          theme: CupertinoThemeData(brightness: brightness),
          home: Builder(
            builder: (context) {
              resolvedGlassTint = GlassThemeData.of(
                context,
              ).settingsFor(context)?.glassColor;
              return Center(
                child: ModalToolbarGlassButton(
                  icon: CupertinoIcons.checkmark,
                  iconColor: CupertinoColors.white,
                  surfaceColor: actionColor,
                  isCheckmark: true,
                  onTap: () {},
                ),
              );
            },
          ),
        ),
      );

      final button = tester.widget<GlassButton>(find.byType(GlassButton));
      final icon = tester.widget<Icon>(
        find.descendant(
          of: find.byType(GlassButton),
          matching: find.byType(Icon),
        ),
      );
      expect(button.quality, GlassQuality.premium);
      expect(button.useOwnLayer, isTrue);
      expect(button.enabled, isTrue);
      expect(icon.color!.toARGB32(), actionColor.toARGB32());
      expect(
        resolvedGlassTint!.toARGB32(),
        (brightness == Brightness.dark
                ? GlassThemeVariant.dark.settings
                : GlassThemeVariant.light.settings)!
            .glassColor!
            .toARGB32(),
      );
    }
  });

  testWidgets('disabled toolbar checkmark remains a glass button', (
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

    final button = tester.widget<GlassButton>(find.byType(GlassButton));
    expect(button.enabled, isFalse);
    expect(button.quality, GlassQuality.premium);
    expect(button.useOwnLayer, isTrue);
  });
}

void _noOp() {}
