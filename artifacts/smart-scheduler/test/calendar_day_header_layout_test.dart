import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/tabs/calendar_tab.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';

void main() {
  testWidgets(
    'portrait Day View places DOW, week strip, banner, and timeline in order',
    (tester) async {
      const screenSize = Size(402, 874);
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = screenSize;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) {
            final mediaQuery = MediaQuery.of(context).copyWith(
              size: screenSize,
            );
            return MediaQuery(
              data: mediaQuery,
              child: AppWindowContentBoundary(
                child: child ?? const SizedBox.shrink(),
              ),
            );
          },
          home: CupertinoPageScaffold(
            child: CalendarTab(onViewChanged: (_, _, _, _, _) {}),
          ),
        ),
      );
      await tester.pumpAndSettle();

      tester
          .state<CalendarTabState>(find.byType(CalendarTab))
          .jumpToTodayDay();
      await tester.pumpAndSettle();

      final dowMask = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DayViewDowMask',
      );
      final banners = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DayBanner',
      );
      final timelines = find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString() == '_DayTimeline',
      );
      expect(dowMask, findsOneWidget);
      expect(banners, findsNWidgets(3));
      expect(timelines, findsNWidgets(3));

      final dowRect = tester.getRect(dowMask);
      final centerBannerRect = tester.getRect(banners.at(1));
      final centerTimelineRect = tester.getRect(timelines.at(1));
      const weekStripHeight = 52.0;

      expect(dowRect.top, closeTo(kAppHeaderTitleHeight, 0.5));
      expect(
        centerBannerRect.top,
        closeTo(dowRect.bottom + weekStripHeight, 0.5),
      );
      expect(centerTimelineRect.top, closeTo(centerBannerRect.bottom, 0.5));
    },
  );
}
