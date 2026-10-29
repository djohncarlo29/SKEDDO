import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass
    show GlassButton, GlassButtonStyle, GlassQuality, LiquidOval;

import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/app_settings.dart';
import 'package:smart_scheduler/widgets/modal_toolbar_glass_button.dart';
import 'package:smart_scheduler/widgets/skeddo_glass_settings.dart';

void main() {
  testWidgets('modal back chevron is optically centered by default', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: ModalToolbarGlassButton(
            icon: CupertinoIcons.chevron_left,
            iconColor: CupertinoColors.black,
            surfaceColor: CupertinoColors.white,
            onTap: _ignoreTap,
          ),
        ),
      ),
    );

    final chevron = find.byIcon(CupertinoIcons.chevron_left);
    final opticalOffset = find.ancestor(
      of: chevron,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is Transform &&
            (widget.transform.getTranslation().x + 2).abs() < 0.001,
      ),
    );
    expect(opticalOffset, findsOneWidget);
  });

  testWidgets('modal toolbar uses package glass buttons in both themes', (
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

      final allButtons = tester
          .widgetList<navigation_glass.GlassButton>(
            find.byType(navigation_glass.GlassButton),
          )
          .toList();
      expect(allButtons, hasLength(3));
      final stretchShellFinder = find.byWidgetPredicate(
        (widget) =>
            widget is navigation_glass.GlassButton &&
            widget.style == navigation_glass.GlassButtonStyle.transparent,
      );
      final stretchShell = tester.widget<navigation_glass.GlassButton>(
        stretchShellFinder,
      );
      final innerButtons = tester
          .widgetList<navigation_glass.GlassButton>(
            find.descendant(
              of: stretchShellFinder,
              matching: find.byType(navigation_glass.GlassButton),
            ),
          )
          .toList();
      expect(innerButtons, hasLength(2));
      final refractionLayer = innerButtons.first;
      final lightingLayer = innerButtons.last;
      final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.checkmark));
      expect(stretchShell.width, 40);
      expect(stretchShell.height, 40);
      expect(stretchShell.interactionScale, isNull);
      expect(stretchShell.stretch, 0.5);
      expect(stretchShell.style, navigation_glass.GlassButtonStyle.transparent);
      expect(stretchShell.child, isA<Stack>());
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
        skeddoNavigationGlassSettingsFromShared(
          skeddoActiveCheckmarkGlassSettingsFor(brightness),
        ),
      );
      expect(lightingLayer.width, 40);
      expect(lightingLayer.height, 40);
      expect(lightingLayer.shape, const navigation_glass.LiquidOval());
      expect(lightingLayer.quality, navigation_glass.GlassQuality.premium);
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
        skeddoNavigationGlassSettingsFromShared(
          skeddoActiveCheckmarkRefractionSettingsFor(brightness),
        ),
      );
      expect(
        refractionLayer.settings!.refractiveIndex,
        sharedSettings.refractiveIndex,
      );
      expect(refractionLayer.settings!.fresnelStrength, 0);
      expect(refractionLayer.interactionScale, 1);
      expect(refractionLayer.onTap, isNotNull);
      expect(lightingLayer.onTap, isNotNull);
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

  testWidgets('shared modal toolbar glass updates live with slider', (
    tester,
  ) async {
    final originalSliderValue = appLiquidGlassOpacityNotifier.value;
    addTearDown(() {
      appLiquidGlassOpacityNotifier.value = originalSliderValue;
    });

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.25,
    );
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.light),
        home: Center(
          child: ModalToolbarGlassButton(
            icon: CupertinoIcons.line_horizontal_3,
            iconColor: CupertinoColors.activeBlue,
            surfaceColor: kCardColor,
            onTap: () {},
          ),
        ),
      ),
    );

    var button = tester.widget<navigation_glass.GlassButton>(
      find.byType(navigation_glass.GlassButton),
    );
    expect(button.settings!.blur, closeTo(0.57, 0.000001));
    expect(button.settings!.glassColor.a, closeTo(0.371, 0.001));

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.75,
    );
    await tester.pump();

    button = tester.widget<navigation_glass.GlassButton>(
      find.byType(navigation_glass.GlassButton),
    );
    expect(button.settings!.blur, closeTo(4.41, 0.000001));
    expect(button.settings!.glassColor.a, closeTo(0.614, 0.001));
  });

  testWidgets('modal toolbars match standalone AppShell press motion', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ModalToolbarGlassButton(
              icon: CupertinoIcons.xmark,
              iconColor: CupertinoColors.label,
              surfaceColor: Color(0xFFFFFFFF),
              onTap: _ignoreTap,
            ),
            ModalToolbarGlassButton(
              icon: CupertinoIcons.checkmark,
              iconColor: CupertinoColors.white,
              surfaceColor: Color(0xFF007AFF),
              isCheckmark: true,
              onTap: _ignoreTap,
            ),
          ],
        ),
      ),
    );

    final standardButton = tester.widget<navigation_glass.GlassButton>(
      find.byType(navigation_glass.GlassButton).first,
    );
    expect(standardButton.interactionScale, isNull);
    expect(standardButton.stretch, 0.5);
    expect(standardButton.anchorStretch, isTrue);

    final shellFinder = find.byWidgetPredicate(
      (widget) =>
          widget is navigation_glass.GlassButton &&
          widget.style == navigation_glass.GlassButtonStyle.transparent,
    );
    final checkmarkShell = tester.widget<navigation_glass.GlassButton>(
      shellFinder,
    );
    expect(checkmarkShell.interactionScale, isNull);
    expect(checkmarkShell.stretch, 0.5);
    expect(checkmarkShell.anchorStretch, isTrue);
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

        final button = tester.widget<navigation_glass.GlassButton>(
          find.byType(navigation_glass.GlassButton),
        );
        expect(find.byType(navigation_glass.GlassButton), findsOneWidget);
        final icon = tester.widget<Icon>(find.byIcon(CupertinoIcons.checkmark));
        expect(button.onTap, isNotNull);
        expect(
          button.settings!.glassColor,
          skeddoNavigationGlassSettingsFromShared(
            skeddoTintedActionGlassSettingsFor(entry.$1, inactiveTint),
          ).glassColor,
        );
        expect(
          button.settings!.chromaticAberration,
          skeddoTintedActionGlassSettingsFor(
            entry.$1,
            inactiveTint,
          ).chromaticAberration,
        );
        expect(
          button.settings!.glassColor.a,
          closeTo(kSkeddoTintedActionGlassOpacity, 0.001),
        );
        expect(button.glowColor, const Color(0x00000000));
        expect(icon.color!.toARGB32(), CupertinoColors.white.toARGB32());

        await tester.tap(find.byIcon(CupertinoIcons.checkmark));
        await tester.pump();
        expect(taps, 0);
      }
    },
  );
}

void _ignoreTap() {}
