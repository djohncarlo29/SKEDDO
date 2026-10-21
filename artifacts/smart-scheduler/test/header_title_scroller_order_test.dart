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

  testWidgets(
    'calendar-style title fades only after a horizontal user drag',
    (tester) async {
      Widget buildScroller({required bool fadeAfterUserScroll}) {
        return CupertinoApp(
          home: Center(
            child: SizedBox(
              width: 180,
              height: 56,
              child: HeaderTitleScroller(
                title: 'September 2026',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
                fadeColor: CupertinoColors.white,
                leading: const SizedBox(width: 40, height: 32),
                leadingContentWidth: 40,
                leadingGap: 0,
                trailing: const SizedBox(width: 64, height: 32),
                trailingContentWidth: 64,
                trailingGap: 4,
                showTrailingFade: true,
                fadeAfterUserScroll: fadeAfterUserScroll,
                centerWhenContentFits: true,
              ),
            ),
          ),
        );
      }

      int fadeCount() {
        final decorations = find.descendant(
          of: find.byType(HeaderTitleScroller),
          matching: find.byType(DecoratedBox),
        );
        return tester
            .widgetList<DecoratedBox>(decorations)
            .where(
              (widget) =>
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).gradient != null,
            )
            .length;
      }

      await tester.pumpWidget(buildScroller(fadeAfterUserScroll: true));
      await tester.pumpAndSettle();
      expect(fadeCount(), 0);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-40, 0),
      );
      await tester.pumpAndSettle();
      expect(fadeCount(), greaterThan(0));

      // Scrollers that do not opt into Calendar's interaction-gated fades
      // retain their existing initial overflow indicator.
      await tester.pumpWidget(buildScroller(fadeAfterUserScroll: false));
      await tester.pumpAndSettle();
      expect(fadeCount(), greaterThan(0));
    },
  );

  testWidgets(
    'calendar-style title can show an edge fade during rubberbanding',
    (tester) async {
      await tester.pumpWidget(
        const CupertinoApp(
          home: Center(
            child: SizedBox(
              width: 320,
              height: 56,
              child: HeaderTitleScroller(
                title: 'May',
                style: TextStyle(fontSize: 17),
                fadeColor: CupertinoColors.white,
                leading: SizedBox(width: 40, height: 32),
                leadingContentWidth: 40,
                leadingGap: 0,
                trailing: SizedBox(width: 64, height: 32),
                trailingContentWidth: 64,
                trailingGap: 4,
                showTrailingFade: true,
                fadeAfterUserScroll: true,
                centerWhenContentFits: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      int fadeCount() {
        final decorations = find.descendant(
          of: find.byType(HeaderTitleScroller),
          matching: find.byType(DecoratedBox),
        );
        return tester
            .widgetList<DecoratedBox>(decorations)
            .where(
              (widget) =>
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).gradient != null,
            )
            .length;
      }

      expect(fadeCount(), 0);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SingleChildScrollView)),
      );
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(fadeCount(), greaterThan(0));

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );
}