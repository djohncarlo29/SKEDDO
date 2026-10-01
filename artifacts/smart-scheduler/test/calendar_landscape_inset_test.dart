import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/tabs/calendar_tab.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';

void main() {
  testWidgets(
    'landscape Year View keeps full-width panels and insets month grids',
    (tester) async {
      const screenSize = Size(844, 390);
      const horizontalSafeInset = 28.0;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      CalendarView? visibleView;
      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context).copyWith(
              size: screenSize,
              padding: const EdgeInsets.only(left: horizontalSafeInset),
              viewPadding: const EdgeInsets.only(left: horizontalSafeInset),
            );
            return MediaQuery(
              data: mediaQuery,
              child: AppWindowContentBoundary(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: CupertinoPageScaffold(
            child: CalendarTab(
              onViewChanged:
                  (view, displayYear, previousTitle, title, nextTitle) {
                    visibleView = view;
                  },
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester.state<CalendarTabState>(find.byType(CalendarTab)).navigateDown();
      await tester.pumpAndSettle();
      expect(visibleView, CalendarView.year);

      final monthGrids = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_MiniMonthGrid',
      );
      expect(monthGrids, findsWidgets);

      final visibleGridRects = <Rect>[];
      for (var index = 0; index < monthGrids.evaluate().length; index++) {
        final rect = tester.getRect(monthGrids.at(index));
        if (rect.right > 0 && rect.left < screenSize.width) {
          visibleGridRects.add(rect);
        }
      }
      expect(visibleGridRects, hasLength(12));
      for (final rect in visibleGridRects) {
        expect(rect.left, greaterThanOrEqualTo(horizontalSafeInset + 15.5));
        expect(
          rect.right,
          lessThanOrEqualTo(
            screenSize.width - horizontalSafeInset - 15.5,
          ),
        );
      }

      final yearViewports = find.byType(SingleChildScrollView);
      var foundFullWidthYearViewport = false;
      for (var index = 0; index < yearViewports.evaluate().length; index++) {
        final rect = tester.getRect(yearViewports.at(index));
        if (rect.left.abs() < 1.0 &&
            (rect.width - screenSize.width).abs() < 1.0) {
          foundFullWidthYearViewport = true;
          break;
        }
      }
      expect(foundFullWidthYearViewport, isTrue);
    },
  );
}