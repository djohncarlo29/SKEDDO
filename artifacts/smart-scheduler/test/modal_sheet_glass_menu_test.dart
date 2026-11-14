import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassContainer,
        GlassMenu,
        GlassMenuController,
        GlassMenuDivider,
        GlassMenuItem,
        GlassQuality,
        AdaptiveLiquidGlassLayer,
        LiquidRoundedRectangle,
        GlassMorphContentMotion;
import 'package:liquid_glass_widgets/widgets/shared/glass_menu_content_lens.dart'
    show GlassMenuContentLens;

import 'package:smart_scheduler/app_settings.dart'
    show
        appLiquidGlassOpacityNotifier,
        liquidGlassOpacityForSliderPosition,
        liquidGlassSliderPositionForOpacity;
import 'package:smart_scheduler/app_theme.dart' show kCardColor;
import 'package:smart_scheduler/widgets/action_panel.dart'
    show ActionItem, ModalSheetGlassMenu;
import 'package:smart_scheduler/widgets/skeddo_glass_settings.dart'
    show
        skeddoNavigationGlassSettingsFromShared,
        skeddoPopoverBlurForPosition,
        skeddoPopoverGlassSettingsFor,
        skeddoPopoverOpacityForPosition,
        skeddoModalSheetPickerGlassSettingsFor,
        skeddoGlassMenuSurfaceTintForBrightness;

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
      expect(dark.thickness, 30);
      expect(dark.refractiveIndex, 1.59);
      expect(dark.chromaticAberration, 0.3);
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
    expect(light.thickness, 30);
    expect(light.refractiveIndex, 1.59);
    expect(light.chromaticAberration, 0.3);
  });

  test(
    'modal menus and popovers share toolbar menu card tint in both themes',
    () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final position in [0.0, 0.25, 0.5, 0.75, 1.0]) {
          final menuTint = skeddoGlassMenuSurfaceTintForBrightness(brightness);
          final picker = skeddoModalSheetPickerGlassSettingsFor(
            brightness,
            sliderPosition: position,
          );
          final popover = skeddoPopoverGlassSettingsFor(
            brightness,
            menuTint,
            sliderPosition: position,
          );

          expect(
            menuTint,
            brightness == Brightness.light
                ? const Color(0xFFFDFDFD)
                : const Color(0xFF1C1C1E),
          );
          expect(
            menuTint,
            brightness == Brightness.light
                ? kCardColor.color
                : kCardColor.darkColor,
          );
          expect(picker.glassColor, popover.glassColor);
          expect(
            picker.glassColor,
            menuTint.withValues(
              alpha: skeddoPopoverOpacityForPosition(position),
            ),
          );
          expect(
            picker.blur,
            closeTo(skeddoPopoverBlurForPosition(position), 0.001),
          );
        }
      }
    },
  );

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
            textScaler: TextScaler.linear(2.5),
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
                  groupBreakAbove: true,
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
    expect(menu.showItemInteractionHighlight, isTrue);
    expect(menu.useAdaptiveInteractionHighlight, isTrue);
    expect(menu.menuContentHorizontalInset, 12);
    expect(find.text('October'), findsOneWidget);

    final options = menu.items.whereType<GlassMenuItem>().toList();
    expect(options, hasLength(2));
    expect(
      menu.items.whereType<GlassMenuDivider>().single.indent,
      8,
      reason: 'The divider keeps its existing inset independently of the rows.',
    );
    for (final option in options) {
      expect(option.contentHorizontalInset, 12);
      expect(option.iconSize, 42.5);
      expect(option.iconLabelGap, 16);
      expect(option.allowTextWrapping, isTrue);
      expect(option.trailing, isNull);
      final iconRow = option.icon! as Row;
      expect(iconRow.children.single, isA<SizedBox>());
    }
    final firstIconRow = options.first.icon! as Row;
    final firstCheckmarkSlot = firstIconRow.children.single as SizedBox;
    expect(firstCheckmarkSlot.width, 42.5);
    final checkmark = firstCheckmarkSlot.child as Icon;
    expect(checkmark.icon, CupertinoIcons.checkmark);
    expect(checkmark.size, 42.5);
    final lastIconRow = options.last.icon! as Row;
    expect((lastIconRow.children.single as SizedBox).child, isA<SizedBox>());

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
    expect(menu.settings!.thickness, 30);
    expect(menu.settings!.refractiveIndex, 1.59);
    expect(menu.settings!.chromaticAberration, 0.3);

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
    await tester.pump(const Duration(milliseconds: 40));
    expect(
      find.byKey(const ValueKey<String>('glass-menu-content-lens-wrapper')),
      findsOneWidget,
    );
    final foregroundLens = tester.widget<GlassMenuContentLens>(
      find.byType(GlassMenuContentLens),
    );
    expect(foregroundLens.thickness, 30);
    expect(foregroundLens.refractiveIndex, 1.30);
    expect(foregroundLens.chromaticAberration, 0.06);
    expect(
      foregroundLens.normalizedEffectStrength,
      closeTo(
        GlassMorphContentMotion.blurSigma(
              progress: foregroundLens.progress,
              isClosing: false,
            ) /
            GlassMorphContentMotion.contentPeakBlurSigma,
        0.001,
      ),
    );
    final menuBody = tester.widget<GlassContainer>(
      find.byType(GlassContainer).last,
    );
    expect(menuBody.quality, GlassQuality.premium);
    expect(menuBody.settings!.visibility, lessThan(1));
    expect(menuBody.settings!.lightIntensity, 0.35);
    expect(menuBody.settings!.fresnelStrength, 1.0);
    expect(menuBody.settings!.thickness, 30);
    expect(menuBody.settings!.refractiveIndex, 1.59);
    expect(menuBody.settings!.chromaticAberration, 0.3);
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
    'category picker options show checkmark, colored dot, then label',
    (tester) async {
      Widget categoryDot(Color color) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: ModalSheetGlassMenu(
              trigger: const Text('Category'),
              actions: [
                ActionItem(
                  label: 'Family',
                  icon: CupertinoIcons.circle_fill,
                  iconBuilder: categoryDot,
                  showCategoryDotInPickerMenu: true,
                  checkmark: true,
                  checkmarkColor: const Color(0xffed5a50),
                  onTap: () {},
                ),
                ActionItem(
                  label: 'Work',
                  icon: CupertinoIcons.circle_fill,
                  iconBuilder: categoryDot,
                  showCategoryDotInPickerMenu: true,
                  groupBreakAbove: true,
                  onTap: () {},
                ),
              ],
              semanticLabel: 'Category',
              builder: (context, menu, openMenu) => menu,
            ),
          ),
        ),
      );

      final menu = tester.widget<GlassMenu>(find.byType(GlassMenu));
      expect(menu.menuContentHorizontalInset, 12);
      expect(
        menu.items.whereType<GlassMenuDivider>().single.indent,
        8,
      );
      final options = menu.items.whereType<GlassMenuItem>().toList();
      expect(options, hasLength(2));
      for (final option in options) {
        expect(option.contentHorizontalInset, 12);
        expect(option.iconLabelGap, 16);
        expect(option.iconSize, 17);
        final iconRow = option.icon! as Row;
        expect(iconRow.children, hasLength(3));
        final checkmarkSlot = iconRow.children.first as SizedBox;
        expect(checkmarkSlot.width, 17);
        expect(iconRow.children[1], isA<SizedBox>());
        expect((iconRow.children[1] as SizedBox).width, 16);
        final categoryDot = iconRow.children.last as Container;
        expect(categoryDot.constraints!.maxWidth, 14);
      }
      final selectedIconRow = options.first.icon! as Row;
      final selectedCheckmarkSlot = selectedIconRow.children.first as SizedBox;
      expect(selectedCheckmarkSlot.child, isA<Icon>());
      final unselectedIconRow = options.last.icon! as Row;
      final unselectedCheckmarkSlot = unselectedIconRow.children.first as SizedBox;
      expect(unselectedCheckmarkSlot.child, isA<SizedBox>());
    },
  );

  testWidgets(
    'picker dismissal retraces the opening radius transition',
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
      expect(menuBody().settings!.thickness, 30);
      expect(menuBody().settings!.refractiveIndex, 1.59);
      expect(menuBody().settings!.chromaticAberration, 0.3);
      controller!.close();

      var radiusChanged = false;
      for (var frame = 0; frame < 100 && controller!.isOpen; frame++) {
        await tester.pump(const Duration(milliseconds: 8));
        final glassContainers = find.byType(GlassContainer);
        if (glassContainers.evaluate().isEmpty) break;
        final body = tester.widget<GlassContainer>(glassContainers.first);
        expect(body.settings!.thickness, 30);
        expect(body.settings!.refractiveIndex, 1.59);
        expect(body.settings!.chromaticAberration, 0.3);
        final radius = (body.shape as LiquidRoundedRectangle).borderRadius;
        expect(radius, greaterThan(0));
        if ((radius - 32).abs() > 0.5) radiusChanged = true;
      }

      await tester.pumpAndSettle();
      expect(controller!.isOpen, isFalse);
      expect(radiusChanged, isTrue);
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
      expect(renderedOption.showInteractionHighlight, isTrue);
      expect(renderedOption.useAdaptiveInteractionHighlight, isTrue);
      expect(renderedOption.enablePressScale, isTrue);
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

  testWidgets(
    'modal picker keeps its trigger and open menu visible after rotation',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      GlassMenuController? controller;
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                const SizedBox(height: 640),
                ModalSheetGlassMenu(
                  trigger: const Text('Rotation trigger'),
                  actions: [
                    ActionItem(
                      label: 'Rotation option',
                      icon: CupertinoIcons.circle,
                      onTap: () {},
                    ),
                  ],
                  semanticLabel: 'Rotation picker',
                  onOpened: (value) => controller = value,
                  builder: (context, menuTrigger, openMenu) => menuTrigger,
                ),
                const SizedBox(height: 800),
              ],
            ),
          ),
        ),
      );

      final trigger = find.text('Rotation trigger');
      await tester.ensureVisible(trigger);
      await tester.tap(trigger);
      await tester.pumpAndSettle();
      expect(controller!.isOpen, isTrue);

      final option = find.text('Rotation option');
      final optionRow = find.ancestor(
        of: option,
        matching: find.byType(GlassMenuItem),
      ).first;
      final optionGesture = await tester.startGesture(
        tester.getCenter(option),
      );
      await tester.pump();
      final highlightedOption = tester.widget<GlassMenuItem>(optionRow);
      expect(highlightedOption.showInteractionHighlight, isTrue);
      expect(highlightedOption.useAdaptiveInteractionHighlight, isTrue);
      expect(highlightedOption.isInteractionHighlighted, isTrue);
      expect(highlightedOption.enablePressScale, isTrue);
      final optionSurface = find.descendant(
        of: optionRow,
        matching: find.byType(AnimatedContainer),
      );
      final optionDecoration =
          tester.widget<AnimatedContainer>(optionSurface.first).decoration
              as BoxDecoration;
      final isDark =
          CupertinoTheme.of(tester.element(option)).brightness == Brightness.dark;
      expect(
        optionDecoration.color,
        (isDark ? CupertinoColors.white : CupertinoColors.black).withValues(
          alpha: isDark ? 0.045 : 0.08,
        ),
      );
      expect(
        tester
            .widget<AnimatedScale>(
              find
                  .descendant(
                    of: optionRow,
                    matching: find.byType(AnimatedScale),
                  )
                  .first,
            )
            .scale,
        0.98,
      );
      await optionGesture.cancel();
      await tester.pumpAndSettle();
      expect(
        tester.widget<GlassMenuItem>(optionRow).isInteractionHighlighted,
        isFalse,
      );

      tester.view.physicalSize = const Size(900, 420);
      await tester.pump();
      await tester.pumpAndSettle();

      expect(controller!.isOpen, isTrue);
      final triggerRect = tester.getRect(trigger);
      expect(triggerRect.top, greaterThanOrEqualTo(0));
      expect(triggerRect.bottom, lessThanOrEqualTo(420));

      expect(option, findsOneWidget);
      final optionRect = tester.getRect(option);
      expect(optionRect.top, greaterThanOrEqualTo(0));
      expect(optionRect.bottom, lessThanOrEqualTo(420));

      controller!.close();
      await tester.pumpAndSettle();
      expect(controller!.isOpen, isFalse);
    },
  );

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
