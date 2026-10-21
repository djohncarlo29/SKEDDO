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
    'calendar-style title keeps scrolling as its edge mask changes',
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

      final titleScrollable = find.descendant(
        of: find.byType(HeaderTitleScroller),
        matching: find.byType(Scrollable),
      );

      int fadeMaskCount() {
        final masks = find.descendant(
          of: find.byType(HeaderTitleScroller),
          matching: find.byType(ShaderMask),
        );
        return masks.evaluate().length;
      }

      await tester.pumpWidget(buildScroller(fadeAfterUserScroll: true));
      await tester.pumpAndSettle();
      expect(fadeMaskCount(), 1);

      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(-40, 0),
      );
      await tester.pumpAndSettle();
      expect(
        tester.state<ScrollableState>(titleScrollable).position.pixels,
        greaterThan(0),
      );
      expect(fadeMaskCount(), 1);

      // Scrollers that do not opt into Calendar's interaction-gated fades
      // retain their existing initial overflow indicator.
      await tester.pumpWidget(buildScroller(fadeAfterUserScroll: false));
      await tester.pumpAndSettle();
      expect(fadeMaskCount(), 1);
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

      int fadeMaskCount() {
        final masks = find.descendant(
          of: find.byType(HeaderTitleScroller),
          matching: find.byType(ShaderMask),
        );
        return masks.evaluate().length;
      }

      expect(fadeMaskCount(), 1);

      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(SingleChildScrollView)),
      );
      await gesture.moveBy(const Offset(24, 0));
      await tester.pump(const Duration(milliseconds: 16));
      final titleScrollable = find.descendant(
        of: find.byType(HeaderTitleScroller),
        matching: find.byType(Scrollable),
      );
      expect(
        tester.state<ScrollableState>(titleScrollable).position.pixels,
        lessThan(0),
      );
      expect(fadeMaskCount(), 1);

      await gesture.up();
      await tester.pumpAndSettle();
    },
  );
}