import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart';

void main() {
  testWidgets('modal picker trailing uses the custom value and chevron', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 240,
              child: ModalSheetPickerTrailing(
                value: 'Weekly',
                style: TextStyle(fontSize: 15),
                chevronColor: CupertinoColors.systemGrey,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text &&
            widget.data?.replaceAll('\u2060', '') == 'Weekly',
      ),
      findsOneWidget,
    );
    expect(find.byType(SplitChevronUpDown), findsOneWidget);
  });

  testWidgets('modal picker trailing can omit its custom chevron', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SizedBox(
              width: 160,
              child: ModalSheetPickerTrailing(
                value: 'Day',
                style: TextStyle(fontSize: 15),
                chevronColor: CupertinoColors.systemGrey,
                showChevron: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Text && widget.data?.replaceAll('\u2060', '') == 'Day',
      ),
      findsOneWidget,
    );
    expect(find.byType(SplitChevronUpDown), findsNothing);
  });
}
