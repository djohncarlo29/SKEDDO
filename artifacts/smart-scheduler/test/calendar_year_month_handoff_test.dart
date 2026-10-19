import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/tabs/calendar_tab.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';

void main() {
  testWidgets(
    'Year↔Month destination keeps its measured scroll position through handoff',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final calendarKey = GlobalKey<CalendarTabState>();
      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) => AppWindowContentBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
          home: CupertinoPageScaffold(
            child: CalendarTab(
              key: calendarKey,
              onViewChanged: (_, _, _, _, _, _) {},
            ),
          ),
        ),
      );
      await tester.pump();

      // Month → Year: capture the actual target ScrollPosition while the
      // painter owns the screen, then ensure the live Year view reveals that
      // same position instead of attaching a new one at initialScrollOffset.
      calendarKey.currentState!.navigateDown();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final yearPosition = _positionForViewport(tester, 'year');
      final yearPixels = yearPosition.pixels;
      await tester.pumpAndSettle();
      final settledYearPosition = _positionForViewport(tester, 'year');
      expect(identical(settledYearPosition, yearPosition), isTrue);
      expect(settledYearPosition.pixels, yearPixels);

      // Year → Month: the current Month view is likewise kept mounted behind
      // the painter. Its live scroll position must not change at the midpoint
      // or when the painter relinquishes ownership.
      final monthTransition = calendarKey.currentState!.advanceCurrentHeader();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final monthPosition = _positionForViewport(tester, 'month');
      final monthPixels = monthPosition.pixels;
      await tester.pumpAndSettle();
      await monthTransition;
      final settledMonthPosition = _positionForViewport(tester, 'month');
      expect(identical(settledMonthPosition, monthPosition), isTrue);
      expect(settledMonthPosition.pixels, monthPixels);
    },
  );
}

ScrollPosition _positionForViewport(WidgetTester tester, String view) {
  final viewportKey = find.byKey(
    ValueKey('calendar-$view-scroll-viewport'),
  );
  final viewport = find.descendant(
    of: viewportKey,
    matching: find.byType(SingleChildScrollView),
  );
  expect(viewportKey, findsOneWidget);
  expect(viewport, findsOneWidget);
  final scrollView = tester.widget<SingleChildScrollView>(viewport);
  final controller = scrollView.controller;
  expect(controller, isNotNull);
  expect(controller!.hasClients, isTrue);
  return controller.position;
}
