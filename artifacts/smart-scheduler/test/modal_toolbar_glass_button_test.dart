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
        skeddoActiveCheckmarkGlassSettingsFor(brightness),
      );
      expect(button.settings!.glassColor.a, 0);
      expect(button.settings!.saturation, 1);
      expect(button.settings!.chromaticAberration, 0);
      expect(button.settings!.fresnelStrength, 0);
      expect(button.settings!.ambientRim, 0);
      expect(button.settings!.lightIntensity, 0.15);
      expect(button.settings!.ambientStrength, 0);
      expect(button.settings!.shadowElevation, 0);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox &&
              widget.color.toARGB32() ==
                  actionColor
                      .withValues(alpha: kSkeddoTintedActionGlassOpacity)
                      .toARGB32(),
        ),
        findsOneWidget,
      );
      expect(
        icon.color!.toARGB32(),
        CupertinoColors.white.toARGB32(),
      );
    }
  });

  testWidgets(
    'inactive checkmarks retain active glass treatment and ignore taps',
    (tester) async {
      for (final entry in [
        (
          Brightness.light,
          const Color(0xFFCECDD3),
        ),
        (
          Brightness.dark,
          const Color(0xFF474749),
        ),
      ]) {
        var taps = 0;
        await tester.pumpWidget(
          CupertinoApp(
            theme: CupertinoThemeData(brightness: entry.$1),
            home: Center(
              child: ModalToolbarGlassButton(
                icon: CupertinoIcons.checkmark,
                iconColor: CupertinoColors.white,
                surfaceColor: kDisabledActionSurface,
                isCheckmark: true,
                semanticLabel: 'Save',
                onTap: () => taps++,
              ),
            ),
          ),
        );

        final context = tester.element(
          find.byType(ModalToolbarGlassButton),
        );
        final inactiveTint = resolveThemeColor(kDisabledActionSurface, context);
        expect(inactiveTint.toARGB32(), entry.$2.toARGB32());

        final button = tester.widget<GlassIconButton>(
          find.byType(GlassIconButton),
        );
        final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.checkmark));
        expect(button.onPressed, isNotNull);
        expect(
          button.settings!.glassColor,
          inactiveTint.withValues(alpha: kSkeddoTintedActionGlassOpacity),
        );
        expect(button.settings!.chromaticAberration, 0.3);
        expect(button.settings!.glassColor.a, closeTo(0.85, 0.001));
        expect(icon.color!.toARGB32(), CupertinoColors.white.toARGB32());

        await tester.tap(find.byIcon(CupertinoIcons.checkmark));
        await tester.pump();
        expect(taps, 0);
      }
    },
  );
}
