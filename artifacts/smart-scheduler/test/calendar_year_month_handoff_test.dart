import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/main.dart';
import 'package:smart_scheduler/tabs/calendar_tab.dart';

void main() {
  testWidgets(
    'Year↔Month destination stays aligned through the real AppShell handoff',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(393, 850);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(() => tester.view.resetPadding());

      // Pump the production root, not a bare CalendarTab. The shell owns the
      // large title, scroll inset, and per-view header-scroll scopes involved
      // in the installed-app handoff.
      await tester.pumpWidget(const SKEDDOApp());
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
        monthPixels,
        monthViewportTop,
      );
      await monthTransition;
      final settledMonthPosition = _positionForViewport(tester, 'month');
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
  double expectedPixels,
  double expectedViewportTop,
) async {
  // Sample the whole transition, not just its endpoints. The destination
  // remains mounted behind the painter, so its scroll state and viewport
  // origin must not move at the logical midpoint or the final handoff.
  for (var frame = 0; frame < 40; frame++) {
    await tester.pump(const Duration(milliseconds: 16));
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
