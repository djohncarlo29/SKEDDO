import 'package:flutter/cupertino.dart';
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
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    final confirmation = showDiscardChangesConfirmationSheet(
      pageContext,
      entityLabel: 'event',
      isNew: true,
    );
    await tester.pumpAndSettle();

    final message = find.text('Are you sure you want to discard this new event?');
    expect(message, findsOneWidget);
    expect(
      find.ancestor(
        of: message,
        matching: find.byWidgetPredicate(
          (widget) => widget is Align && widget.alignment == Alignment.topLeft,
        ),
      ),
      findsOneWidget,
    );

    await tester.tapAt(const Offset(700, 500));
    await tester.pumpAndSettle();
    expect(await confirmation, isNull);
  });
}
