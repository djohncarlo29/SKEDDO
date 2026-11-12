import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassContainer,
        GlassMenu,
        GlassMenuController,
        GlassMenuItem,
        GlassQuality,
        AdaptiveLiquidGlassLayer,
        LiquidRoundedRectangle;

import 'package:smart_scheduler/app_settings.dart'
    show
        appLiquidGlassOpacityNotifier,
        liquidGlassOpacityForSliderPosition,
        liquidGlassSliderPositionForOpacity;
import 'package:smart_scheduler/widgets/action_panel.dart'
    show ActionItem, ModalSheetGlassMenu;
import 'package:smart_scheduler/widgets/skeddo_glass_settings.dart'
    show
        skeddoNavigationGlassSettingsFromShared,
        skeddoPopoverBlurForPosition,
        skeddoPopoverGlassSettingsFor,
        skeddoPopoverOpacityForPosition,
        skeddoBottomBarGlassSettingsFor,
        skeddoModalSheetPickerGlassSettingsFor;

void main() {
  test('popover menus use the shared rim strength in both themes', () {
    const tint = Color(0xff202024);
    for (final position in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      final dark = skeddoPopoverGlassSettingsFor(
        Brightness.dark,
        tint,
        sliderPosition: position,
      );
      expect(dark.lightIntensity, 0.35);
      expect(dark.glowIntensity, 0.375);
      expect(dark.fresnelStrength, 1.0);
      expect(dark.thickness, 20);
      expect(dark.refractiveIndex, 1.10);
      expect(dark.chromaticAberration, 0.20);
      expect(dark.ambientRim, 0);
      expect(
        dark.glassColor.a,
        closeTo(skeddoPopoverOpacityForPosition(position), 0.001),
      );
      expect(dark.blur, closeTo(skeddoPopoverBlurForPosition(position), 0.001));

      final navigationSettings = skeddoNavigationGlassSettingsFromShared(dark);
      expect(navigationSettings.lightIntensity, 0.35);
      expect(navigationSettings.glowIntensity, dark.glowIntensity);
      expect(navigationSettings.fresnelStrength, dark.fresnelStrength);
      expect(navigationSettings.ambientRim, dark.ambientRim);
    }

    final light = skeddoPopoverGlassSettingsFor(
      Brightness.light,
      tint,
      sliderPosition: 0.5,
    );
    expect(light.glowIntensity, 0.75);
    expect(light.fresnelStrength, 1.0);
    expect(light.thickness, 20);
    expect(light.refractiveIndex, 1.10);
    expect(light.chromaticAberration, 0.20);
  });

  test('modal picker menus use the toolbar surface tint in both themes', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      for (final position in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final toolbar = skeddoBottomBarGlassSettingsFor(
          brightness,
          sliderPosition: position,
        );
        final picker = skeddoModalSheetPickerGlassSettingsFor(
          brightness,
          sliderPosition: position,
        );

        expect(
          picker.glassColor,
          toolbar.glassColor.withValues(
            alpha: skeddoPopoverOpacityForPosition(position),
          ),
        );
        expect(
          picker.blur,
          closeTo(skeddoPopoverBlurForPosition(position), 0.001),
        );
      }
    }
  });

  testWidgets('modal picker menu keeps its text trigger free of a glass blob', (
    tester,
  ) async {
    final originalOpacity = appLiquidGlassOpacityNotifier.value;
    addTearDown(() => appLiquidGlassOpacityNotifier.value = originalOpacity);
    VoidCallback? openMenu;
    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.0,
    );

    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        home: MediaQuery(
          data: const MediaQueryData(
            platformBrightness: Brightness.light,
            textScaler: TextScaler.linear(1.5),
          ),
          child: Center(
            child: ModalSheetGlassMenu(
              trigger: const Text('October'),
              actions: [
                ActionItem(
                  label: 'November',
                  icon: CupertinoIcons.circle,
                  checkmark: true,
                  onTap: () {},
                ),
                ActionItem(
                  label: 'December',
                  icon: CupertinoIcons.circle,
                  onTap: () {},
                ),
              ],
              semanticLabel: 'Month, October',
              builder: (context, menuTrigger, open) {
                openMenu = open;
                return menuTrigger;
              },
            ),
          ),
        ),
      ),
    );

    final menu = tester.widget<GlassMenu>(find.byType(GlassMenu));
    expect(menu.morphFromZero, isFalse);
    expect(menu.suppressTriggerGlassBlob, isTrue);
    expect(menu.triggerEntryImpactStrength, 0.35);
    expect(menu.triggerImpactStrength, 1.15);
    expect(menu.normalizeTriggerReturnOvershoot, isTrue);
    expect(menu.quality, GlassQuality.premium);
    expect(menu.keepTriggerAnchorOnOverflow, isTrue);
    expect(menu.showItemInteractionHighlight, isFalse);
    expect(menu.menuContentHorizontalInset, 12);
    expect(find.text('October'), findsOneWidget);

    final options = menu.items.whereType<GlassMenuItem>().toList();
    expect(options, hasLength(2));
    for (final option in options) {
      expect(option.iconSize, 36);
      expect(option.iconLabelGap, 12);
      expect(option.allowTextWrapping, isTrue);
      expect(option.trailing, isNull);
      final iconSlot = option.icon! as SizedBox;
      expect(iconSlot.width, 36);
      expect(iconSlot.height, 36);
    }
    final checkmark =
        ((options.first.icon! as SizedBox).child as Center).child as Icon;
    expect(checkmark.icon, CupertinoIcons.checkmark);
    expect(checkmark.size, 25.5);
    expect((options.last.icon! as SizedBox).child, isA<SizedBox>());

    final initialPosition = liquidGlassSliderPositionForOpacity(
      appLiquidGlassOpacityNotifier.value,
    );
    expect(
      menu.settings!.blur,
      closeTo(skeddoPopoverBlurForPosition(initialPosition), 0.001),
    );
    expect(
      menu.settings!.glassColor.a,
      closeTo(skeddoPopoverOpacityForPosition(initialPosition), 0.001),
    );
    expect(menu.settings!.lightIntensity, 0.35);
    expect(menu.settings!.glowIntensity, 0.375);
    expect(menu.settings!.fresnelStrength, 1.0);
    expect(menu.settings!.thickness, 20);
    expect(menu.settings!.refractiveIndex, 1.10);
    expect(menu.settings!.chromaticAberration, 0.20);

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      1.0,
    );
    await tester.pump();
    final updatedMenu = tester.widget<GlassMenu>(find.byType(GlassMenu));
    final updatedPosition = liquidGlassSliderPositionForOpacity(
      appLiquidGlassOpacityNotifier.value,
    );
    expect(
      updatedMenu.settings!.blur,
      closeTo(skeddoPopoverBlurForPosition(updatedPosition), 0.001),
    );
    expect(
      updatedMenu.settings!.blur,
      isNot(closeTo(menu.settings!.blur, 0.001)),
    );

    openMenu!();
    await tester.pump();
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    final menuBody = tester.widget<GlassContainer>(
      find.byType(GlassContainer).last,
    );
    expect(menuBody.quality, GlassQuality.premium);
    expect(menuBody.settings!.visibility, lessThan(1));
    expect(menuBody.settings!.lightIntensity, 0.35);
    expect(menuBody.settings!.fresnelStrength, 1.0);
    expect(menuBody.settings!.thickness, 20);
    expect(menuBody.settings!.refractiveIndex, 1.10);
    expect(menuBody.settings!.chromaticAberration, 0.20);
    final capturedGlassLayers = tester
        .widgetList<AdaptiveLiquidGlassLayer>(
          find.byType(AdaptiveLiquidGlassLayer),
        )
        .where((layer) => layer.quality == GlassQuality.premium);
    expect(capturedGlassLayers, isNotEmpty);
    for (final layer in capturedGlassLayers) {
      expect(layer.settings!.lightIntensity, 0.35);
      expect(layer.settings!.fresnelStrength, 1.0);
    }
    final triggerOpacity = tester
        .widgetList<Opacity>(
          find.ancestor(
            of: find.text('October'),
            matching: find.byType(Opacity),
          ),
        )
        .map((widget) => widget.opacity)
        .where((opacity) => opacity > 0 && opacity < 1)
        .first;
    expect(triggerOpacity, greaterThan(0));
  });

  testWidgets(
    'picker menu keeps its open radius until the shrinking bounds require a stadium',
    (tester) async {
      GlassMenuController? controller;

      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: ModalSheetGlassMenu(
              trigger: const Text('Radius trigger'),
              actions: [
                for (var index = 0; index < 6; index++)
                  ActionItem(
                    label: 'Option $index',
                    icon: CupertinoIcons.circle,
                    onTap: () {},
                  ),
              ],
              semanticLabel: 'Radius test',
              onOpened: (value) => controller = value,
              builder: (context, menuTrigger, openMenu) => menuTrigger,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Radius trigger'));
      await tester.pumpAndSettle();
      expect(controller!.isOpen, isTrue);

      GlassContainer menuBody() =>
          tester.widget<GlassContainer>(find.byType(GlassContainer).last);
      double menuRadius() =>
          (menuBody().shape as LiquidRoundedRectangle).borderRadius;

      expect(menuRadius(), 32);
      expect(menuBody().settings!.thickness, 20);
      expect(menuBody().settings!.refractiveIndex, 1.10);
      expect(menuBody().settings!.chromaticAberration, 0.20);
      controller!.close();

      var sawStadiumPhase = false;
      for (var frame = 0; frame < 100 && controller!.isOpen; frame++) {
        await tester.pump(const Duration(milliseconds: 8));
        final glassContainers = find.byType(GlassContainer);
        if (glassContainers.evaluate().isEmpty) break;
        final body = tester.widget<GlassContainer>(glassContainers.first);
        expect(body.settings!.thickness, 20);
        expect(body.settings!.refractiveIndex, 1.10);
        expect(body.settings!.chromaticAberration, 0.20);
        final shortSide = math.min(body.width!, body.height!);
        final radius = (body.shape as LiquidRoundedRectangle).borderRadius;
        if (shortSide >= 64) {
          expect(radius, 32);
        } else {
          expect(radius, closeTo(shortSide / 2, 0.01));
          sawStadiumPhase = true;
        }
      }

      await tester.pumpAndSettle();
      expect(controller!.isOpen, isFalse);
      expect(sawStadiumPhase, isTrue);
    },
  );

  testWidgets(
    'picker dismissal keeps the trigger mounted through the reverse morph',
    (tester) async {
      GlassMenuController? controller;
      var closeCallbackRan = false;
      var callbackSawOverlayOpen = true;

      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: ModalSheetGlassMenu(
              trigger: const Text('Picker value'),
              actions: [
                ActionItem(
                  label: 'A picker option that wraps onto multiple lines',
                  icon: CupertinoIcons.circle,
                  onTap: () {},
                ),
              ],
              semanticLabel: 'Picker value',
              onOpened: (value) => controller = value,
              onClosed: (value) {
                closeCallbackRan = true;
                callbackSawOverlayOpen = value.isOpen;
              },
              builder: (context, menuTrigger, openMenu) => menuTrigger,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Picker value'));
      await tester.pumpAndSettle();
      expect(controller, isNotNull);
      expect(controller!.isOpen, isTrue);
      final renderedOption = tester
          .widgetList<GlassMenuItem>(find.byType(GlassMenuItem))
          .singleWhere((item) => item.title.startsWith('A picker option'));
      expect(renderedOption.showInteractionHighlight, isFalse);
      expect(renderedOption.allowTextWrapping, isTrue);
      final optionText = tester.widget<Text>(
        find.text('A picker option that wraps onto multiple lines'),
      );
      expect(optionText.maxLines, isNull);
      expect(optionText.overflow, TextOverflow.visible);

      controller!.close();
      await tester.pump(const Duration(milliseconds: 16));
      expect(controller!.isOpen, isTrue);
      expect(closeCallbackRan, isFalse);

      await tester.pumpAndSettle();
      expect(controller!.isOpen, isFalse);
      expect(closeCallbackRan, isTrue);
      expect(callbackSawOverlayOpen, isFalse);
    },
  );

  testWidgets(
    'single-select picker closes without recoloring its selected option',
    (tester) async {
      var selected = false;
      GlassMenuController? controller;
      const idleColor = Color(0xff222222);
      const selectedColor = Color(0xff087df0);

      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: StatefulBuilder(
              builder: (context, setState) => ModalSheetGlassMenu(
                trigger: Text(selected ? 'Selected value' : 'Current value'),
                actions: [
                  ActionItem(
                    label: 'Choice',
                    icon: CupertinoIcons.circle,
                    checkmark: selected,
                    labelColor: selected ? selectedColor : idleColor,
                    onTap: () => setState(() => selected = true),
                  ),
                ],
                semanticLabel: 'Example picker',
                onOpened: (value) => controller = value,
                builder: (context, menuTrigger, openMenu) => menuTrigger,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Current value'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Choice'));
      await tester.pump();

      expect(controller!.isOpen, isTrue);
      expect(selected, isTrue);
      final closingOption = tester
          .widgetList<GlassMenuItem>(find.byType(GlassMenuItem))
          .singleWhere((item) => item.title == 'Choice');
      expect(closingOption.titleStyle!.color, idleColor);

      await tester.pumpAndSettle();
      expect(controller!.isOpen, isFalse);
      expect(find.text('Selected value'), findsOneWidget);
    },
  );

  testWidgets('multi-select Include option stays open and updates live', (
    tester,
  ) async {
    var selected = false;
    GlassMenuController? controller;
    const idleColor = Color(0xff222222);
    const selectedColor = Color(0xff087df0);

    await tester.pumpWidget(
      CupertinoApp(
        home: Center(
          child: StatefulBuilder(
            builder: (context, setState) => ModalSheetGlassMenu(
              trigger: Text(selected ? 'One selected' : 'None selected'),
              actions: [
                ActionItem(
                  label: 'Category',
                  icon: CupertinoIcons.circle,
                  checkmark: selected,
                  labelColor: selected ? selectedColor : idleColor,
                  closeMenuOnTap: false,
                  onTap: () => setState(() => selected = !selected),
                ),
              ],
              semanticLabel: 'Include',
              onOpened: (value) => controller = value,
              builder: (context, menuTrigger, openMenu) => menuTrigger,
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('None selected'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Category'));
    await tester.pumpAndSettle();

    expect(controller!.isOpen, isTrue);
    expect(selected, isTrue);
    final updatedOption = tester
        .widgetList<GlassMenuItem>(find.byType(GlassMenuItem))
        .singleWhere((item) => item.title == 'Category');
    expect(updatedOption.titleStyle!.color, selectedColor);

    controller!.close();
    await tester.pumpAndSettle();
    expect(controller!.isOpen, isFalse);
  });

  testWidgets('picker trigger return spring is independent of option count', (
    tester,
  ) async {
    Future<double> peakTriggerTravel(int optionCount) async {
      GlassMenuController? controller;
      await tester.pumpWidget(
        CupertinoApp(
          home: Padding(
            padding: const EdgeInsets.only(top: 220),
            child: Align(
              alignment: Alignment.topCenter,
              child: ModalSheetGlassMenu(
                trigger: const Text('Spring trigger'),
                actions: [
                  for (var index = 0; index < optionCount; index++)
                    ActionItem(
                      label: 'Choice $index',
                      icon: CupertinoIcons.circle,
                      onTap: () {},
                    ),
                ],
                semanticLabel: 'Spring test',
                onOpened: (value) => controller = value,
                builder: (context, menuTrigger, openMenu) => menuTrigger,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Spring trigger'));
      await tester.pumpAndSettle();
      controller!.close();

      var peak = 0.0;
      final triggerTransforms = find.ancestor(
        of: find.text('Spring trigger'),
        matching: find.byType(Transform),
      );
      for (var frame = 0; frame < 100 && controller!.isOpen; frame++) {
        await tester.pump(const Duration(milliseconds: 8));
        for (final transform in tester.widgetList<Transform>(
          triggerTransforms,
        )) {
          final distance = transform.transform.getTranslation().y.abs();
          if (distance > peak) peak = distance;
        }
      }
      await tester.pumpAndSettle();
      return peak;
    }

    final shortMenuTravel = await peakTriggerTravel(1);
    final longMenuTravel = await peakTriggerTravel(8);

    expect(shortMenuTravel, greaterThan(0));
    expect(longMenuTravel, greaterThan(0));
    expect(shortMenuTravel, closeTo(longMenuTravel, 1.0));
  });
}
