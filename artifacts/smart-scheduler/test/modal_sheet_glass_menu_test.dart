import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassMenu, GlassMenuController, GlassMenuItem, GlassQuality;

import 'package:smart_scheduler/app_settings.dart'
    show
        appLiquidGlassOpacityNotifier,
        liquidGlassOpacityForSliderPosition,
        liquidGlassSliderPositionForOpacity;
import 'package:smart_scheduler/widgets/action_panel.dart'
    show ActionItem, ModalSheetGlassMenu;
import 'package:smart_scheduler/widgets/skeddo_glass_settings.dart'
    show skeddoPopoverBlurForPosition, skeddoPopoverOpacityForPosition;

void main() {
  testWidgets('modal picker menu keeps its text trigger free of a glass blob', (
    tester,
  ) async {
    final originalOpacity = appLiquidGlassOpacityNotifier.value;
    addTearDown(() => appLiquidGlassOpacityNotifier.value = originalOpacity);
    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      0.0,
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: MediaQuery(
          data: const MediaQueryData(
            platformBrightness: Brightness.dark,
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
              builder: (context, menuTrigger, openMenu) => menuTrigger,
            ),
          ),
        ),
      ),
    );

    final menu = tester.widget<GlassMenu>(find.byType(GlassMenu));
    expect(menu.morphFromZero, isTrue);
    expect(menu.triggerImpactStrength, 1.15);
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
  });

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
}
