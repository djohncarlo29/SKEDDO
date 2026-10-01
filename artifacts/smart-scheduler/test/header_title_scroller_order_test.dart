import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/header_title_scroller.dart';

void main() {
  testWidgets(
    'centers a leading control, title, and trailing controls as one group',
    (tester) async {
      const slotKey = ValueKey('header-slot');
      const leadingKey = ValueKey('leading-chevron');
      const trailingKey = ValueKey('trailing-controls');

      await tester.pumpWidget(
        const CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: SizedBox(
                key: slotKey,
                width: 320,
                height: 56,
                child: HeaderTitleScroller(
                  title: 'Period',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  fadeColor: CupertinoColors.white,
                  leading: SizedBox(key: leadingKey, width: 40, height: 32),
                  leadingContentWidth: 40,
                  leadingGap: 0,
                  trailing: SizedBox(key: trailingKey, width: 64, height: 32),
                  trailingContentWidth: 64,
                  trailingGap: 4,
                  centerWhenContentFits: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final leadingRect = tester.getRect(find.byKey(leadingKey));
      final titleRect = tester.getRect(find.text('Period'));
      final trailingRect = tester.getRect(find.byKey(trailingKey));
      final slotRect = tester.getRect(find.byKey(slotKey));

      expect(leadingRect.right, lessThanOrEqualTo(titleRect.left));
      expect(titleRect.right, lessThanOrEqualTo(trailingRect.left));
      expect(
        (leadingRect.left + trailingRect.right) / 2,
        closeTo(slotRect.center.dx, 2.0),
      );
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    },
  );
}