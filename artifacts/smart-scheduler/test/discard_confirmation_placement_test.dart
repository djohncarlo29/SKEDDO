import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassButton, GlassMenuAlignment, GlassPopover;
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/delete_confirmation_sheet.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';
import 'package:smart_scheduler/widgets/skeddo_glass_settings.dart';

void main() {
  testWidgets('discard confirmation always uses the top-left placement', (
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
        builder: (context, child) => AppWindowContentScope(
          horizontalInset: 0,
          physicalWidth: 800,
          child: child ?? const SizedBox.shrink(),
        ),
        home: Builder(
          builder: (context) {
            pageContext = context;
            return Center(
              child: DiscardChangesPopoverAnchor(
                key: anchorKey,
                child: CupertinoButton(
                  onPressed: () {},
                  child: const Icon(CupertinoIcons.xmark),
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

    final message = find.text('Are you sure you want to discard this new event?');
    expect(message, findsOneWidget);
    expect(find.byIcon(CupertinoIcons.xmark), findsOneWidget);
    final popoverFinder = find.byType(GlassPopover);
    expect(popoverFinder, findsOneWidget);
    final popover = tester.widget<GlassPopover>(popoverFinder);
    expect(popover.alignment, GlassMenuAlignment.topLeft);
    expect(popover.popoverWidth, 400);
    expect(popover.barrierDismissible, isTrue);
    expect(
      popover.settings!.refractiveIndex,
      skeddoBottomBarGlassSettingsFor(Brightness.light).refractiveIndex,
    );
    expect(popover.settings!.glassColor.a, 0.70);
    expect(
      skeddoPopoverGlassSettingsFor(Brightness.dark).glassColor.a,
      0.70,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is ColoredBox &&
            widget.color == const Color(0x44000000),
      ),
      findsNothing,
    );

    final discardButtonFinder = find.ancestor(
      of: find.text('Discard Changes'),
      matching: find.byType(GlassButton),
    );
    expect(discardButtonFinder, findsOneWidget);
    expect(tester.getSize(discardButtonFinder).width, greaterThan(300));
    final discardButton = tester.widget<GlassButton>(discardButtonFinder);
    expect(discardButton.settings!.glassColor.a, closeTo(0.28, 0.001));
    expect(
      skeddoPopoverButtonGlassSettingsFor(Brightness.dark).glassColor.a,
      closeTo(0.28, 0.001),
    );

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
