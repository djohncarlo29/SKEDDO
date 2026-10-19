import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/tabs/calendar_tab.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';

void main() {
  testWidgets(
    'Year↔Month destination stays mounted while the painter owns the transition',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      const screenSize = Size(393, 680);
      const headerInset = 68.0;
      tester.view.physicalSize = screenSize;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(() => tester.view.resetPadding());

      // Match the production content inset and title-slot height while keeping
      // unrelated tabs out of this focused calendar transition test.
      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(
              context,
            ).copyWith(size: screenSize);
            return MediaQuery(
              data: mediaQuery,
              child: AppWindowContentBoundary(
                child: Padding(
                  padding: const EdgeInsets.only(top: headerInset),
                  child: AppHeaderScrollInsetScope(
                    leadingInset: headerInset,
                    child: child ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            );
          },
          home: CupertinoPageScaffold(
            child: CalendarTab(
              onViewChanged: (_, _, _, _, _, _) {},
              scrollableTitleBuilder:
                  (context, title, displayYear, view, isActive) =>
                      SizedBox(
                        height: kAppHeaderTitleHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text('$title $displayYear'),
                        ),
                      ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final calendar = tester.state<CalendarTabState>(
        find.byType(CalendarTab),
      );

      final initialMonthPosition = _positionForViewport(tester, 'month');
      final initialMonthViewportTop = _viewportTop(tester, 'month');
      final initialMonthOffset = initialMonthPosition.maxScrollExtent
          .clamp(0.0, 96.0)
          .toDouble();
      if (initialMonthOffset > 0.0) {
        initialMonthPosition.jumpTo(initialMonthOffset);
        await tester.pump();
      }
      final savedMonthPixels = initialMonthPosition.pixels;

      // Month → Year: capture the actual target ScrollPosition while the
      // painter owns the screen, then ensure the live Year view reveals that
      // same position instead of attaching a new one at initialScrollOffset.
      calendar.navigateDown();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final yearPosition = _positionForViewport(tester, 'year');
      final yearPixels = yearPosition.pixels;
      final yearViewportTop = _viewportTop(tester, 'year');
      await _pumpAndExpectStableViewport(
        tester,
        'year',
        yearPosition,
        yearPixels,
        yearViewportTop,
      );
      final settledYearPosition = _positionForViewport(tester, 'year');
      expect(identical(settledYearPosition, yearPosition), isTrue);
      expect(settledYearPosition.pixels, yearPixels);
      expect(_viewportTop(tester, 'year'), closeTo(yearViewportTop, 0.01));

      // Give Year View a non-zero live offset before the reverse transition.
      // That makes the second Month → Year pass prove that the target's saved
      // position survives the painter/live handoff, not just a zero-offset
      // coincidence.
      expect(settledYearPosition.maxScrollExtent, greaterThan(0.0));
      final savedYearPixels = settledYearPosition.maxScrollExtent
          .clamp(0.0, 120.0)
          .toDouble();
      settledYearPosition.jumpTo(savedYearPixels);
      await tester.pump();

      // Year → Month: the current Month view is likewise kept mounted behind
      // the painter. Its destination offset and geometry must match what the
      // painter measured when it relinquishes ownership.
      final monthTransition = calendar.advanceCurrentHeader();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final monthPosition = _positionForViewport(tester, 'month');
      final monthPixels = monthPosition.pixels;
      final monthViewportTop = _viewportTop(tester, 'month');
      await _pumpAndExpectStableViewport(
        tester,
        'month',
        monthPosition,
        monthPixels,
        monthViewportTop,
      );
      await monthTransition;
      final settledMonthPosition = _positionForViewport(tester, 'month');
      expect(identical(settledMonthPosition, monthPosition), isTrue);
      expect(settledMonthPosition.pixels, monthPixels);
      expect(settledMonthPosition.pixels, savedMonthPixels);
      expect(_viewportTop(tester, 'month'), closeTo(monthViewportTop, 0.01));
      expect(
        _viewportTop(tester, 'month'),
        closeTo(initialMonthViewportTop, 0.01),
      );

      // Month → Year again with the stored non-zero Year offset. This catches
      // a remounted Scrollable silently returning to its original offset.
      calendar.navigateDown();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      final returningYearPosition = _positionForViewport(tester, 'year');
      final returningYearPixels = returningYearPosition.pixels;
      expect(returningYearPixels, savedYearPixels);
      final returningYearViewportTop = _viewportTop(tester, 'year');
      await _pumpAndExpectStableViewport(
        tester,
        'year',
        returningYearPosition,
        savedYearPixels,
        returningYearViewportTop,
      );
      final settledReturningYearPosition = _positionForViewport(tester, 'year');
      expect(
        identical(settledReturningYearPosition, returningYearPosition),
        isTrue,
      );
      expect(settledReturningYearPosition.pixels, savedYearPixels);
      expect(
        _viewportTop(tester, 'year'),
        closeTo(returningYearViewportTop, 0.01),
      );
    },
  );
}

Future<void> _pumpAndExpectStableViewport(
  WidgetTester tester,
  String view,
  ScrollPosition expectedPosition,
  double expectedPixels,
  double expectedViewportTop,
) async {
  // Sample the whole transition, not just its endpoints. The destination
  // remains mounted behind the painter, so its scroll state and viewport
  // origin must not move at the logical midpoint or the final handoff.
  for (var frame = 0; frame < 40; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      identical(_positionForViewport(tester, view), expectedPosition),
      isTrue,
      reason: '$view ScrollPosition was replaced during the morph',
    );
    expect(
      _positionForViewport(tester, view).pixels,
      closeTo(expectedPixels, 0.01),
    );
    expect(_viewportTop(tester, view), closeTo(expectedViewportTop, 0.01));
  }
  await tester.pumpAndSettle();
  expect(
    _positionForViewport(tester, view).pixels,
    closeTo(expectedPixels, 0.01),
  );
  expect(_viewportTop(tester, view), closeTo(expectedViewportTop, 0.01));
}

ScrollPosition _positionForViewport(WidgetTester tester, String view) {
  final viewportKey = find.byKey(ValueKey('calendar-$view-scroll-viewport'));
  final viewport = _scrollViewForViewport(view);
  expect(viewportKey, findsOneWidget);
  expect(viewport, findsOneWidget);
  final scrollView = tester.widget<SingleChildScrollView>(viewport);
  final controller = scrollView.controller;
  expect(controller, isNotNull);
  expect(controller!.hasClients, isTrue);
  return controller.position;
}

Finder _scrollViewForViewport(String view) {
  final viewportKey = find.byKey(ValueKey('calendar-$view-scroll-viewport'));
  return find.descendant(
    of: viewportKey,
    matching: find.byType(SingleChildScrollView),
  );
}

double _viewportTop(WidgetTester tester, String view) =>
    tester.getTopLeft(_scrollViewForViewport(view)).dy;
