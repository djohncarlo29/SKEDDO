import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

void main() {
  testWidgets('rounded sheet dismisses from a downward drag', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigatorKey,
        home: CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              onPressed: () {
                showRoundedCupertinoSheet<void>(
                  context: navigatorKey.currentContext!,
                  pageBuilder: (_) => const CupertinoPageScaffold(
                    child: SizedBox.expand(
                      child: Center(child: Text('Sheet content')),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Sheet content'), findsOneWidget);

    await tester.dragFrom(const Offset(200, 260), const Offset(200, 660));
    await tester.pumpAndSettle();

    expect(find.text('Sheet content'), findsNothing);
  });
}
