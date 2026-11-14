import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassButton,
        GlassButtonStyle,
        GlassContainer,
        AdaptiveGlass,
        GlassMenuAlignment,
        LiquidGlassBlendGroup,
        GlassPopover,
        GlassQuality,
        LiquidGlassLayer,
        LiquidRoundedSuperellipse;
import 'package:flutter_liquid_glass_widgets/widgets/shared/glass_popover_content_lens.dart'
    show GlassPopoverContentLens;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassDefaults;
import 'package:smart_scheduler/app_settings.dart';
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/delete_confirmation_sheet.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';
import 'package:smart_scheduler/widgets/skeddo_glass_settings.dart';

void main() {
  test('GlassPopover keeps its default trigger alignment', () {
    final popover = GlassPopover(
      trigger: const SizedBox.shrink(),
      contentBuilder: (_, __) => const SizedBox.shrink(),
    );
    expect(popover.popoverOffset, Offset.zero);
    expect(popover.anchorGrowthToTrigger, isFalse);
  });

  testWidgets('popover content stays at its destination during the morph', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 48, top: 88),
              child: GlassPopover(
                popoverWidth: 260,
                popoverHeight: 160,
                autoAdjustToScreen: false,
                triggerBuilder: (context, toggle) => CupertinoButton(
                  onPressed: toggle,
                  child: const Text('Open popover'),
                ),
                contentBuilder: (_, __) => const Text(
                  'Anchored popover content',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Open popover'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final contentFinder = find.text(
      'Anchored popover content',
      skipOffstage: false,
    );
    expect(contentFinder, findsOneWidget);
    final openingRect = tester.getRect(contentFinder);

    await tester.pumpAndSettle();
    final settledRect = tester.getRect(
      contentFinder,
    );
    expect(
      (openingRect.center - settledRect.center).distance,
      lessThan(40),
      reason: 'The content should scale in place, not travel from the trigger.',
    );

    await tester.tapAt(const Offset(760, 560));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 16));
    final closingRect = tester.getRect(contentFinder);
    expect(
      (closingRect.center - settledRect.center).distance,
      lessThan(40),
      reason: 'The content should stay put while the platter returns.',
    );
    await tester.pumpAndSettle();
  });

  testWidgets(
    'discard popover does not reveal its surfaced trigger under the closing glass',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final triggerKey = GlobalKey();
      VoidCallback? closePopover;
      await tester.pumpWidget(
        CupertinoApp(
          home: Align(
            alignment: Alignment.topLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: 48, top: 88),
              child: GlassPopover(
                popoverWidth: 260,
                popoverHeight: 160,
                anchorGrowthToTrigger: true,
                keepTriggerHiddenDuringClose: true,
                triggerBuilder: (context, toggle) => GestureDetector(
                  key: triggerKey,
                  behavior: HitTestBehavior.opaque,
                  onTap: toggle,
                  child: const SizedBox(width: 40, height: 40),
                ),
                contentBuilder: (_, close) {
                  closePopover = close;
                  return const Text('Discard confirmation');
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(triggerKey));
      await tester.pumpAndSettle();
      expect(find.byType(LiquidGlassLayer), findsOneWidget);

      closePopover!();
      var observedVisibleClosingLayer = false;
      for (
        var frame = 0;
        frame < 80 && find.byType(LiquidGlassLayer).evaluate().isNotEmpty;
        frame++
      ) {
        await tester.pump(const Duration(milliseconds: 16));

        final layer = find.byType(LiquidGlassLayer);
        if (layer.evaluate().isEmpty) continue;
        final layerOpacityFinder = find.ancestor(
          of: layer,
          matching: find.byType(Opacity),
        );
        final layerOpacity = layerOpacityFinder.evaluate().isEmpty
            ? 1.0
            : tester.widget<Opacity>(layerOpacityFinder.first).opacity;
        if (layerOpacity <= 0.001) continue;

        observedVisibleClosingLayer = true;
        final triggerOpacities = find
            .ancestor(
              of: find.byKey(triggerKey),
              matching: find.byType(Opacity),
            )
            .evaluate()
            .map((element) => (element.widget as Opacity).opacity);
        expect(
          triggerOpacities,
          everyElement(0.0),
          reason:
              'The separate trigger surface must stay hidden while the '
              'closing popover glass is still visible.',
        );
      }

      expect(observedVisibleClosingLayer, isTrue);
      await tester.pumpAndSettle();
      expect(find.byType(LiquidGlassLayer), findsNothing);
    },
  );

  testWidgets('discard popover grows without detaching below its trigger', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final triggerKey = GlobalKey();
    await tester.pumpWidget(
      CupertinoApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.only(left: 48, top: 88),
            child: GlassPopover(
              popoverWidth: 260,
              popoverHeight: 160,
              popoverOffset: const Offset(-4, -4),
              anchorGrowthToTrigger: true,
              autoAdjustToScreen: false,
              triggerBuilder: (context, toggle) => SizedBox(
                key: triggerKey,
                width: 40,
                height: 40,
                child: GestureDetector(
                  onTap: toggle,
                  child: const Icon(CupertinoIcons.xmark),
                ),
              ),
              contentBuilder: (_, __) => const Text('Confirmation'),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final triggerRect = tester.getRect(find.byKey(triggerKey));
    await tester.tap(find.byKey(triggerKey));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    // The anchored reveal uses a single growing platter, not a detached
    // trigger ghost plus a second moving surface.
    expect(find.byType(GlassContainer), findsOneWidget);
    final bodyBlob = tester.getRect(find.byType(GlassContainer));
    expect((bodyBlob.left - triggerRect.left).abs(), lessThan(4.5));
    expect((bodyBlob.top - triggerRect.top).abs(), lessThan(4.5));
    expect(
      tester.widget<LiquidGlassBlendGroup>(
        find.byType(LiquidGlassBlendGroup),
      ).blend,
      0,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('discard confirmation always uses the top-left placement', (
    tester,
  ) async {
    final originalGlassSliderValue = appLiquidGlassOpacityNotifier.value;
    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.5,
    );
    addTearDown(() {
      appLiquidGlassOpacityNotifier.value = originalGlassSliderValue;
    });

    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext pageContext;
    final anchorKey = GlobalKey<DiscardChangesPopoverAnchorState>();
    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => AppWindowContentScope(
          horizontalInset: 24,
          physicalWidth: 800,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, top: 72),
                child: DiscardChangesPopoverAnchor(
                  key: anchorKey,
                  child: CupertinoButton(
                    onPressed: () {},
                    child: const Icon(CupertinoIcons.xmark),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    final triggerOrigin = tester.getTopLeft(find.byType(GlassPopover));
    final confirmation = showDiscardChangesConfirmationSheet(
      pageContext,
      anchorKey: anchorKey,
      entityLabel: 'event',
      isNew: true,
    );
    await tester.pumpAndSettle();

    final message = find.text(
      'Are you sure you want to discard this new event?',
    );
    expect(message, findsOneWidget);
    final messageText = tester.widget<Text>(message);
    expect(messageText.style?.fontSize, 15);
    expect(messageText.style?.height, 1.25);
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    final popoverFinder = find.byType(GlassPopover);
    expect(popoverFinder, findsOneWidget);
    final popover = tester.widget<GlassPopover>(popoverFinder);
    expect(popover.quality, GlassQuality.premium);
    expect(popover.enableInteractionGlow, isTrue);
    expect(popover.glowOnTapOnly, isFalse);
    expect(popover.popoverBorderRadius, 34);
    expect(popover.alignment, GlassMenuAlignment.topLeft);
    expect(popover.anchorGrowthToTrigger, isTrue);
    expect(popover.keepTriggerHiddenDuringClose, isTrue);
    expect(popover.popoverWidth, 400);
    expect(popover.popoverOffset, const Offset(-4, -4));
    expect(popover.screenPadding, const EdgeInsets.all(12));
    expect(kSkeddoPopoverGlassOpacity, 0.83276);
    final glassContainers = find.byType(GlassContainer);
    final glassContainerRects = List<Rect>.generate(
      glassContainers.evaluate().length,
      (index) => tester.getRect(glassContainers.at(index)),
    );
    expect(
      glassContainerRects.any(
        (rect) =>
            (rect.left - (triggerOrigin.dx - 4)).abs() < 1.0 &&
            (rect.top - (triggerOrigin.dy - 4)).abs() < 1.0 &&
            (rect.width - popover.popoverWidth).abs() < 1.0,
      ),
      isTrue,
      reason: 'The landscape popover should open 4px above and left of the X.',
    );
    expect(popover.barrierDismissible, isTrue);
    expect(popover.settings!.refractiveIndex, 1.59);
    expect(popover.settings!.thickness, 30);
    expect(popover.settings!.chromaticAberration, 0.3);
    expect(popover.settings!.blur, skeddoPopoverBlurForPosition(0.5));
    expect(
      popover.settings!.glassColor.a,
      closeTo(kSkeddoPopoverGlassOpacity, 0.001),
    );
    final foregroundLens = tester.widget<GlassPopoverContentLens>(
      find.byType(GlassPopoverContentLens),
    );
    expect(foregroundLens.thickness, 30);
    expect(foregroundLens.refractiveIndex, 1.30);
    expect(foregroundLens.chromaticAberration, 0.06);
    expect(foregroundLens.normalizedEffectStrength, 0);
    expect(foregroundLens.effectiveThickness, 0);
    expect(foregroundLens.effectiveRefractiveIndex, 1);
    expect(foregroundLens.effectiveChromaticAberration, 0);
    final morphLayerFinder = find.byType(LiquidGlassLayer);
    expect(morphLayerFinder, findsOneWidget);
    final morphLayer = tester.widget<LiquidGlassLayer>(morphLayerFinder);
    expect(morphLayer.shadows, popover.settings!.effectiveShadow);
    expect(morphLayer.shadows, isNotEmpty);
    final lightCardTint = resolveThemeColor(kModalCard, pageContext);
    expect(
      popover.settings!.glassColor.toARGB32() & 0x00FFFFFF,
      lightCardTint.toARGB32() & 0x00FFFFFF,
    );
    expect(
      skeddoPopoverGlassSettingsFor(
        Brightness.dark,
        const Color(0xFF2C2C2E),
      ).glassColor.a,
      closeTo(kSkeddoPopoverGlassOpacity, 0.001),
    );
    expect(
      skeddoPopoverGlassSettingsFor(
            Brightness.dark,
            const Color(0xFF2C2C2E),
          ).glassColor.toARGB32() &
          0x00FFFFFF,
      0x002C2C2E,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox && widget.color == const Color(0x44000000),
      ),
      findsNothing,
    );

    final discardButtonFinder = find.ancestor(
      of: find.text('Discard Changes'),
      matching: find.byType(GlassButton),
    );
    expect(discardButtonFinder, findsOneWidget);
    expect(tester.getSize(discardButtonFinder).width, greaterThan(300));
    const buttonAnchorKey = ValueKey(
      'discard-confirmation-glass-button-anchor',
    );
    final buttonAnchorFinder = find.byKey(buttonAnchorKey);
    expect(buttonAnchorFinder, findsOneWidget);
    final buttonRect = tester.getRect(discardButtonFinder);
    final anchorRect = tester.getRect(buttonAnchorFinder);
    expect(buttonRect.height, closeTo(48, 0.01));
    expect(buttonRect.left, closeTo(anchorRect.left, 0.01));
    expect(buttonRect.top, closeTo(anchorRect.top, 0.01));
    expect(buttonRect.width, closeTo(anchorRect.width, 0.01));
    expect(buttonRect.height, closeTo(anchorRect.height, 0.01));
    expect(
      anchorRect.top - tester.getRect(message).bottom,
      closeTo(kDiscardConfirmationMessageButtonGap, 0.1),
    );
    expect(
      find.ancestor(
        of: buttonAnchorFinder,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is Padding &&
              widget.padding ==
                  const EdgeInsets.fromLTRB(
                    kDiscardConfirmationButtonEdgeGap,
                    kDiscardConfirmationSheetTopInset,
                    kDiscardConfirmationButtonEdgeGap,
                    kDiscardConfirmationButtonEdgeGap,
                  ),
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.ancestor(
        of: discardButtonFinder,
        matching: find.byType(GlassPopoverContentLens),
      ),
      findsOneWidget,
    );
    final buttonGlassAncestors = find.ancestor(
      of: discardButtonFinder,
      matching: find.byType(GlassContainer),
    );
    expect(buttonGlassAncestors, findsWidgets);
    expect(
      buttonGlassAncestors.evaluate().any(
            (element) =>
                (element.widget as GlassContainer).clipBehavior ==
                Clip.antiAlias,
          ),
      isTrue,
    );
    final discardButton = tester.widget<GlassButton>(discardButtonFinder);
    expect(discardButton.height, 48);
    expect(
      discardButton.shape,
      const LiquidRoundedSuperellipse(
        borderRadius: kDiscardConfirmationButtonCornerRadius,
      ),
    );
    final discardLabel = tester.widget<Text>(
      find.descendant(
        of: discardButtonFinder,
        matching: find.text('Discard Changes'),
      ),
    );
    expect(discardLabel.style?.fontWeight, FontWeight.w400);
    expect(
      discardLabel.style?.color,
      CupertinoColors.systemRed.resolveFrom(pageContext),
    );
    final fillFinder = find.byKey(
      const ValueKey('discard-confirmation-action-fill'),
    );
    Color currentActionFill() =>
        (tester.widget<AnimatedContainer>(fillFinder).decoration
                as ShapeDecoration)
            .color!;
    expect(
      currentActionFill(),
      skeddoConfirmationActionFillColor(pageContext, highlighted: false),
    );
    final mouse = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(
      mouse.addPointer(location: buttonRect.center),
    );
    await tester.pump();
    await tester.sendEventToBinding(mouse.hover(buttonRect.center));
    await tester.pump();
    expect(
      currentActionFill(),
      skeddoConfirmationActionFillColor(pageContext, highlighted: true),
    );
    expect(
      discardButton.settings!.glassColor.a,
      closeTo(kSkeddoPopoverGlassOpacity, 0.001),
    );
    expect(discardButton.useOwnLayer, isTrue);
    expect(discardButton.quality, GlassQuality.premium);
    expect(discardButton.style, GlassButtonStyle.filled);
    expect(discardButton.interactionScale, 1);
    expect(discardButton.stretch, 0);
    expect(discardButton.anchorStretch, isFalse);
    expect(
      discardButton.glowColor,
      GlassDefaults.touchGlowColorForBrightness(Brightness.light),
    );
    expect(discardButton.glowRadius, GlassDefaults.touchGlowRadius);
    expect(discardButton.glowOpacity, GlassDefaults.touchGlowOpacity);
    expect(discardButton.glowBlurRadius, GlassDefaults.touchGlowBlurRadius);
    expect(discardButton.glowSpreadRadius, GlassDefaults.touchGlowSpreadRadius);
    expect(discardButton.ambientBaseLight, 0);
    expect(discardButton.enableInteractionColorFeedback, isFalse);
    final buttonGlassFinder = find.descendant(
      of: discardButtonFinder,
      matching: find.byType(AdaptiveGlass),
    );
    expect(buttonGlassFinder, findsOneWidget);
    expect(tester.widget<AdaptiveGlass>(buttonGlassFinder).glowIntensity, 0);
    final heldPress = await tester.startGesture(
      tester.getCenter(discardButtonFinder),
    );
    await tester.pump(const Duration(milliseconds: 250));
    expect(tester.widget<AdaptiveGlass>(buttonGlassFinder).glowIntensity, 0);
    await heldPress.cancel();
    await tester.pump();
    expect(discardButton.settings!.thickness, 0);
    expect(discardButton.settings!.blur, 0);
    expect(discardButton.settings!.chromaticAberration, 0);
    expect(discardButton.settings!.lightIntensity, 0);
    expect(discardButton.settings!.ambientStrength, 0);
    expect(discardButton.settings!.ambientRim, 0);
    expect(discardButton.settings!.fresnelStrength, 0);
    expect(discardButton.settings!.refractiveIndex, 1);
    expect(discardButton.settings!.glowIntensity, 0);
    expect(discardButton.settings!.shadowElevation, 0);
    expect(discardButton.settings!.effectiveShadow, isEmpty);
    final lightButtonTint = resolveThemeColor(
      kModalButtonBackground,
      pageContext,
    );
    expect(
      discardButton.settings!.glassColor.toARGB32() & 0x00FFFFFF,
      lightButtonTint.toARGB32() & 0x00FFFFFF,
    );
    expect(
      skeddoPopoverButtonGlassSettingsFor(
        Brightness.dark,
        const Color(0xFF3A3A3C),
      ).glassColor.a,
      closeTo(kSkeddoPopoverGlassOpacity, 0.001),
    );
    expect(
      skeddoPopoverButtonGlassSettingsFor(
            Brightness.dark,
            const Color(0xFF3A3A3C),
          ).glassColor.toARGB32() &
          0x00FFFFFF,
      0x003A3A3C,
    );
    expect(
      skeddoPopoverButtonGlassSettingsFor(
        Brightness.dark,
        const Color(0xFF3A3A3C),
      ).effectiveShadow,
      isEmpty,
    );

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.75,
    );
    await tester.pump();
    final livePopover = tester.widget<GlassPopover>(popoverFinder);
    expect(
      livePopover.settings!.blur,
      closeTo(skeddoPopoverBlurForPosition(0.75), 0.000001),
    );
    expect(
      livePopover.settings!.glassColor.a,
      closeTo(skeddoPopoverOpacityForPosition(0.75), 0.001),
    );
    final liveDiscardButton = tester.widget<GlassButton>(discardButtonFinder);
    expect(
      liveDiscardButton.settings!.glassColor.a,
      closeTo(skeddoPopoverOpacityForPosition(0.75), 0.001),
    );
    expect(liveDiscardButton.settings!.blur, 0);

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.5,
    );
    await tester.pump();
    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(await confirmation, isNull);

    var acceptedConfirmationFinished = false;
    final acceptedConfirmation =
        showDiscardChangesConfirmationSheet(
          pageContext,
          anchorKey: anchorKey,
          entityLabel: 'event',
          isNew: false,
        ).then((result) {
          acceptedConfirmationFinished = true;
          return result;
        });
    await tester.pumpAndSettle();
    expect(
      find.text('Are you sure you want to discard your changes?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Discard Changes'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(acceptedConfirmationFinished, isFalse);
    await tester.pumpAndSettle();
    expect(await acceptedConfirmation, isTrue);
  });

  testWidgets('discard popover supports drag-to-select its single action', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext pageContext;
    final anchorKey = GlobalKey<DiscardChangesPopoverAnchorState>();
    await tester.pumpWidget(
      CupertinoApp(
        theme: const CupertinoThemeData(brightness: Brightness.dark),
        builder: (context, child) => AppWindowContentScope(
          horizontalInset: 24,
          physicalWidth: 800,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, top: 72),
                child: DiscardChangesPopoverAnchor(
                  key: anchorKey,
                  child: CupertinoButton(
                    onPressed: () {},
                    child: const Icon(CupertinoIcons.xmark),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    final confirmation = showDiscardChangesConfirmationSheet(
      pageContext,
      anchorKey: anchorKey,
      entityLabel: 'event',
      isNew: true,
    );
    await tester.pumpAndSettle();

    final message = find.text(
      'Are you sure you want to discard this new event?',
    );
    final button = find.byKey(
      const ValueKey('discard-confirmation-glass-button-anchor'),
    );
    final glassButton = tester.widget<GlassButton>(
      find.ancestor(
        of: find.text('Discard Changes'),
        matching: find.byType(GlassButton),
      ),
    );
    final fill = find.byKey(
      const ValueKey('discard-confirmation-action-fill'),
    );
    Color currentFill() =>
        (tester.widget<AnimatedContainer>(fill).decoration as ShapeDecoration)
            .color!;

    expect(message, findsOneWidget);
    expect(button, findsOneWidget);
    expect(
      glassButton.glowColor,
      GlassDefaults.touchGlowColorForBrightness(Brightness.dark),
    );
    expect(
      currentFill(),
      skeddoConfirmationActionFillColor(pageContext, highlighted: false),
    );

    final gesture = await tester.startGesture(tester.getCenter(message));
    await gesture.moveTo(tester.getCenter(button));
    await tester.pump();
    expect(
      currentFill(),
      skeddoConfirmationActionFillColor(pageContext, highlighted: true),
    );

    await gesture.moveTo(tester.getCenter(message));
    await tester.pump();
    expect(
      currentFill(),
      skeddoConfirmationActionFillColor(pageContext, highlighted: false),
    );

    await gesture.moveTo(tester.getCenter(button));
    await tester.pump();
    expect(
      currentFill(),
      skeddoConfirmationActionFillColor(pageContext, highlighted: true),
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(await confirmation, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('discard action button grows with large system text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext pageContext;
    final anchorKey = GlobalKey<DiscardChangesPopoverAnchorState>();
    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => AppWindowContentScope(
          horizontalInset: 0,
          physicalWidth: 400,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(2.5)),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, top: 72),
                child: DiscardChangesPopoverAnchor(
                  key: anchorKey,
                  child: CupertinoButton(
                    onPressed: () {},
                    child: const Icon(CupertinoIcons.xmark),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    final confirmation = showDiscardChangesConfirmationSheet(
      pageContext,
      anchorKey: anchorKey,
      entityLabel: 'event',
      isNew: true,
    );
    await tester.pumpAndSettle();

    final buttonFinder = find.ancestor(
      of: find.text('Discard Changes'),
      matching: find.byType(GlassButton),
    );
    expect(buttonFinder, findsOneWidget);
    final buttonRect = tester.getRect(buttonFinder);
    final labelRect = tester.getRect(find.text('Discard Changes'));
    expect(buttonRect.height, greaterThan(57));
    expect(labelRect.top, greaterThanOrEqualTo(buttonRect.top));
    expect(labelRect.bottom, lessThanOrEqualTo(buttonRect.bottom));
    expect(tester.takeException(), isNull);

    await tester.tapAt(const Offset(390, 1390));
    await tester.pumpAndSettle();
    expect(await confirmation, isNull);
  });

  testWidgets('discard confirmation offset also applies in portrait', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(600, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext pageContext;
    final anchorKey = GlobalKey<DiscardChangesPopoverAnchorState>();
    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => AppWindowContentScope(
          horizontalInset: 0,
          physicalWidth: 600,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 24, top: 72),
                child: DiscardChangesPopoverAnchor(
                  key: anchorKey,
                  triggerOffset: const Offset(4, 2),
                  child: const SizedBox(width: 44, height: 44),
                ),
              ),
            );
          },
        ),
      ),
    );

    final triggerOrigin = tester.getTopLeft(find.byType(GlassPopover));
    final confirmation = showDiscardChangesConfirmationSheet(
      pageContext,
      anchorKey: anchorKey,
      entityLabel: 'event',
      isNew: true,
    );
    await tester.pumpAndSettle();

    final popover = tester.widget<GlassPopover>(find.byType(GlassPopover));
    expect(popover.popoverOffset, const Offset(-8, -6));
    final glassContainers = find.byType(GlassContainer);
    final glassContainerRects = List<Rect>.generate(
      glassContainers.evaluate().length,
      (index) => tester.getRect(glassContainers.at(index)),
    );
    expect(
      glassContainerRects.any(
        (rect) =>
            (rect.left - (triggerOrigin.dx - 8)).abs() < 1.0 &&
            (rect.top - (triggerOrigin.dy - 6)).abs() < 1.0 &&
            (rect.width - popover.popoverWidth).abs() < 1.0,
      ),
      isTrue,
      reason:
          'The moved trigger must keep the settled popover at its old position.',
    );

    await tester.tapAt(const Offset(500, 700));
    await tester.pumpAndSettle();
    expect(await confirmation, isNull);
  });

  testWidgets(
    'a vetoed sheet swipe restores the X before opening its discard popover',
    (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final navigatorKey = GlobalKey<NavigatorState>();
      final anchorKey = GlobalKey<DiscardChangesPopoverAnchorState>();
      late BuildContext sheetContext;
      var requestedConfirmation = false;

      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigatorKey,
          builder: (context, child) => AppWindowContentScope(
            horizontalInset: 0,
            physicalWidth: 800,
            child: child ?? const SizedBox.shrink(),
          ),
          home: const CupertinoPageScaffold(child: SizedBox.expand()),
        ),
      );

      final sheetFuture = navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(
          builder: (_) => Builder(
            builder: (context) {
              sheetContext = context;
              return PopScope<void>(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop || requestedConfirmation) return;
                  requestedConfirmation = true;
                  unawaited(
                    showDiscardChangesConfirmationSheet(
                      sheetContext,
                      anchorKey: anchorKey,
                      entityLabel: 'event',
                      isNew: true,
                    ),
                  );
                },
                child: CupertinoPageScaffold(
                  child: Column(
                    children: [
                      RoundedCupertinoSheetHeader(
                        child: DiscardChangesPopoverAnchor(
                          key: anchorKey,
                          child: const SizedBox(
                            width: 44,
                            height: 44,
                            child: Icon(CupertinoIcons.xmark),
                          ),
                        ),
                      ),
                      const Expanded(child: SizedBox.expand()),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      final trigger = find.byType(GlassPopover);
      final originalTriggerPosition = tester.getTopLeft(trigger);
      await tester.dragFrom(
        tester.getRect(trigger).center,
        const Offset(0, 380),
      );
      await tester.pumpAndSettle();

      expect(requestedConfirmation, isTrue);
      expect(
        find.text('Are you sure you want to discard this new event?'),
        findsOneWidget,
      );
      expect(tester.getTopLeft(trigger), originalTriggerPosition);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await sheetFuture;
    },
  );

  testWidgets(
    'discard popover follows rotation, closes, and opens again',
    (tester) async {
      tester.view.physicalSize = const Size(420, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final anchorKey = GlobalKey<DiscardChangesPopoverAnchorState>();
      late BuildContext pageContext;
      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) => AppWindowContentScope(
            horizontalInset: 0,
            physicalWidth: 420,
            child: child ?? const SizedBox.shrink(),
          ),
          home: Builder(
            builder: (context) {
              pageContext = context;
              return CupertinoPageScaffold(
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: DiscardChangesPopoverAnchor(
                      key: anchorKey,
                      child: const SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(CupertinoIcons.xmark),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      );

      Future<bool?> openDiscardPopover() =>
          showDiscardChangesConfirmationSheet(
            pageContext,
            anchorKey: anchorKey,
            entityLabel: 'event',
            isNew: true,
          );

      var confirmation = openDiscardPopover();
      await tester.pumpAndSettle();
      expect(
        find.text('Are you sure you want to discard this new event?'),
        findsOneWidget,
      );

      tester.view.physicalSize = const Size(900, 420);
      await tester.pump();
      await tester.pumpAndSettle();

      final popover = tester.widget<GlassPopover>(find.byType(GlassPopover));
      final glassContainers = find.byType(GlassContainer);
      final bodyRects = List<Rect>.generate(
        glassContainers.evaluate().length,
        (index) => tester.getRect(glassContainers.at(index)),
      ).where((rect) => (rect.width - popover.popoverWidth).abs() < 1.0)
          .toList();
      final visibleBodyRects = bodyRects
          .where(
            (rect) =>
                rect.left >= 11 &&
                rect.right <= 889 &&
                rect.top >= 11 &&
                rect.bottom <= 409,
          )
          .toList();
      expect(
        visibleBodyRects,
        isNotEmpty,
        reason: 'Popover body candidates after rotation: $bodyRects',
      );

      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(await confirmation, isNull);

      confirmation = openDiscardPopover();
      await tester.pumpAndSettle();
      expect(
        find.text('Are you sure you want to discard this new event?'),
        findsOneWidget,
      );
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(await confirmation, isNull);
    },
  );
}
