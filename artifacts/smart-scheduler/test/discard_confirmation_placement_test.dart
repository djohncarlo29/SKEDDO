import 'package:flutter/cupertino.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassButton, GlassMenuAlignment, GlassPopover;
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/delete_confirmation_sheet.dart';

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

    final discardButtonFinder = find.ancestor(
      of: find.text('Discard Changes'),
      matching: find.byType(GlassButton),
    );
    expect(discardButtonFinder, findsOneWidget);
    expect(tester.getSize(discardButtonFinder).width, greaterThan(300));

    await tester.tapAt(const Offset(700, 500));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    expect(await confirmation, isNull);

    final acceptedConfirmation = showDiscardChangesConfirmationSheet(
      pageContext,
      anchorKey: anchorKey,
      entityLabel: 'event',
      isNew: false,
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Are you sure you want to discard your changes?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Discard Changes'));
    await tester.pump(const Duration(milliseconds: 900));
    await tester.pump();
    expect(await acceptedConfirmation, isTrue);
  });
}
