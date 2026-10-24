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

      final buttons = tester
          .widgetList<GlassIconButton>(find.byType(GlassIconButton))
          .toList();
      expect(buttons, hasLength(2));
      final refractionLayer = buttons.first;
      final button = buttons.last;
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
      expect(button.settings!.refractiveIndex, 1);
      expect(button.settings!.chromaticAberration, 0);
      final sharedSettings = skeddoBottomBarGlassSettingsFor(brightness);
      expect(button.settings!.fresnelStrength, sharedSettings.fresnelStrength);
      expect(button.settings!.lightIntensity, sharedSettings.lightIntensity);
      expect(button.settings!.ambientStrength, sharedSettings.ambientStrength);
      expect(button.settings!.shadowElevation, 0);
      expect(
        refractionLayer.settings,
        skeddoActiveCheckmarkRefractionSettingsFor(brightness),
      );
      expect(
        refractionLayer.settings!.refractiveIndex,
        sharedSettings.refractiveIndex,
      );
      expect(
        refractionLayer.settings!.fresnelStrength,
        0,
      );
      expect(
        refractionLayer.onPressed,
        isNotNull,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Opacity &&
              widget.opacity ==
                  kSkeddoActiveCheckmarkRefractionOverlayOpacity,
        ),
        findsOneWidget,
      );
      expect(
        button.settings!.glassColor,
        const Color(0x00FFFFFF),
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is ColoredBox &&
              widget.color.toARGB32() ==
                  actionColor
                      .withValues(alpha: kSkeddoActiveCheckmarkFillOpacity)
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
        expect(find.byType(GlassIconButton), findsOneWidget);
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
