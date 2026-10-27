import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassButton,
        GlassButtonStyle,
        GlassContainer,
        GlassMenuAlignment,
        GlassPopover,
        GlassQuality,
        LiquidGlassLayer;
import 'package:flutter_test/flutter_test.dart';
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
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    final popoverFinder = find.byType(GlassPopover);
    expect(popoverFinder, findsOneWidget);
    final popover = tester.widget<GlassPopover>(popoverFinder);
    expect(popover.alignment, GlassMenuAlignment.topLeft);
    expect(popover.popoverWidth, 400);
    expect(popover.popoverOffset, const Offset(-4, -4));
    expect(popover.screenPadding, const EdgeInsets.all(12));
    expect(kSkeddoPopoverGlassOpacity, 0.907);
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
    expect(
      popover.settings!.refractiveIndex,
      skeddoBottomBarGlassSettingsFor(Brightness.light).refractiveIndex,
    );
    expect(popover.settings!.blur, skeddoPopoverBlurForPosition(0.5));
    expect(popover.settings!.glassColor.a, kSkeddoPopoverGlassOpacity);
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
      kSkeddoPopoverGlassOpacity,
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
    expect(buttonRect.left, closeTo(anchorRect.left, 0.01));
    expect(buttonRect.top, closeTo(anchorRect.top, 0.01));
    expect(buttonRect.width, closeTo(anchorRect.width, 0.01));
    expect(buttonRect.height, closeTo(anchorRect.height, 0.01));
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
      find.ancestor(of: discardButtonFinder, matching: find.byType(ClipPath)),
      findsNothing,
    );
    final discardButton = tester.widget<GlassButton>(discardButtonFinder);
    expect(discardButton.settings!.glassColor.a, kSkeddoPopoverGlassOpacity);
    expect(discardButton.useOwnLayer, isTrue);
    expect(discardButton.quality, GlassQuality.premium);
    expect(discardButton.style, GlassButtonStyle.filled);
    expect(discardButton.interactionScale, 1);
    expect(discardButton.stretch, 0);
    expect(discardButton.anchorStretch, isFalse);
    expect(discardButton.glowColor, const Color(0x00000000));
    expect(discardButton.glowOpacity, 0);
    expect(discardButton.glowBlurRadius, 0);
    expect(discardButton.glowSpreadRadius, 0);
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
      kSkeddoPopoverGlassOpacity,
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
    expect(livePopover.settings!.blur, closeTo(7.85, 0.000001));
    expect(livePopover.settings!.glassColor.a, closeTo(0.9285, 0.001));
    final liveDiscardButton = tester.widget<GlassButton>(discardButtonFinder);
    expect(liveDiscardButton.settings!.glassColor.a, closeTo(0.9285, 0.001));
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
    expect(popover.popoverOffset, const Offset(-4, -4));
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
      reason: 'The portrait popover should open 4px above and left of its X.',
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
}
