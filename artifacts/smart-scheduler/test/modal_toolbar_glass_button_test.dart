import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassButton,
        GlassButtonStyle,
        GlassIconButton,
        GlassIconButtonShape,
        GlassQuality;

import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/widgets/modal_toolbar_glass_button.dart';
import 'package:smart_scheduler/widgets/skeddo_glass_settings.dart';

void main() {
  testWidgets('modal toolbar uses package glass icon button in both themes', (
    tester,
  ) async {
    const actionColor = Color(0xFF7B3FE4);
    var taps = 0;

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
              onTap: () => taps++,
            ),
          ),
        ),
      );

      final buttons = tester
          .widgetList<GlassIconButton>(find.byType(GlassIconButton))
          .toList();
      expect(buttons, hasLength(2));
      final refractionLayer = buttons.first;
      final lightingLayer = buttons.last;
      final stretchShellFinder = find.byWidgetPredicate(
        (widget) =>
            widget is GlassButton &&
            widget.style == GlassButtonStyle.transparent,
      );
      final stretchShell = tester.widget<GlassButton>(stretchShellFinder);
      final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.checkmark));
      expect(stretchShell.width, 40);
      expect(stretchShell.height, 40);
      expect(stretchShell.interactionScale, 1.15);
      expect(stretchShell.stretch, 0.5);
      expect(stretchShell.style, GlassButtonStyle.transparent);
      expect(stretchShell.child, isA<Stack>());
      expect(
        find.descendant(
          of: stretchShellFinder,
          matching: find.byType(GlassIconButton),
        ),
        findsNWidgets(2),
      );
      expect(
        find.descendant(
          of: stretchShellFinder,
          matching: find.byIcon(CupertinoIcons.checkmark),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: stretchShellFinder,
          matching: find.byWidgetPredicate(
            (widget) => widget is Opacity && widget.opacity == 0.85,
          ),
        ),
        findsNothing,
      );
      expect(
        lightingLayer.settings,
        skeddoActiveCheckmarkGlassSettingsFor(brightness),
      );
      expect(lightingLayer.size, 40);
      expect(lightingLayer.iconSize, 20);
      expect(lightingLayer.shape, GlassIconButtonShape.circle);
      expect(lightingLayer.quality, GlassQuality.premium);
      expect(lightingLayer.useOwnLayer, isTrue);
      expect(lightingLayer.interactionScale, 1);
      expect(lightingLayer.settings!.glassColor.a, 0);
      expect(lightingLayer.settings!.saturation, 1);
      expect(lightingLayer.settings!.refractiveIndex, 1);
      expect(lightingLayer.settings!.chromaticAberration, 0);
      final sharedSettings = skeddoBottomBarGlassSettingsFor(brightness);
      expect(
        lightingLayer.settings!.fresnelStrength,
        sharedSettings.fresnelStrength,
      );
      expect(
        lightingLayer.settings!.lightIntensity,
        sharedSettings.lightIntensity,
      );
      expect(
        lightingLayer.settings!.ambientStrength,
        sharedSettings.ambientStrength,
      );
      expect(lightingLayer.settings!.shadowElevation, 0);
      expect(
        refractionLayer.settings,
        skeddoActiveCheckmarkRefractionSettingsFor(brightness),
      );
      expect(
        refractionLayer.settings!.refractiveIndex,
        sharedSettings.refractiveIndex,
      );
      expect(refractionLayer.settings!.fresnelStrength, 0);
      expect(refractionLayer.interactionScale, 1);
      expect(refractionLayer.onPressed, isNotNull);
      expect(lightingLayer.onPressed, isNotNull);
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Opacity &&
              widget.opacity == kSkeddoActiveCheckmarkRefractionOverlayOpacity,
        ),
        findsOneWidget,
      );
      expect(lightingLayer.settings!.glassColor, const Color(0x00FFFFFF));
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
      expect(icon.color!.toARGB32(), CupertinoColors.white.toARGB32());

      await tester.tap(stretchShellFinder);
      await tester.pumpAndSettle();
      expect(taps, brightness == Brightness.light ? 1 : 2);
    }
  });

  testWidgets(
    'inactive checkmarks retain active glass treatment and ignore taps',
    (tester) async {
      for (final entry in [
        (Brightness.light, const Color(0xFFCECDD3)),
        (Brightness.dark, const Color(0xFF474749)),
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

        final context = tester.element(find.byType(ModalToolbarGlassButton));
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
        expect(
          icon.color!.toARGB32(),
          CupertinoColors.white.toARGB32(),
        );

        await tester.tap(find.byIcon(CupertinoIcons.checkmark));
        await tester.pump();
        expect(taps, 0);
      }
    },
  );
}
