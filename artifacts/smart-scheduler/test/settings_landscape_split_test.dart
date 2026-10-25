import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/settings_panel.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';

void main() {
  testWidgets(
    'landscape Settings keeps the master usable and switches detail screens',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final backAction = ValueNotifier<VoidCallback?>(null);
      final headerTitleTransition = AppHeaderTitleTransition();
      addTearDown(headerTitleTransition.dispose);

      Widget buildApp({required bool isOpen}) {
        return CupertinoApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(960, 540),
              devicePixelRatio: 2,
              padding: EdgeInsets.only(left: 24),
              viewPadding: EdgeInsets.only(left: 24),
            ),
            child: AppWindowContentScope(
              horizontalInset: 24,
              physicalWidth: 960,
              child: Offstage(
                offstage: !isOpen,
                child: SettingsPanel(
                  topInset: 0,
                  bottomInset: 0,
                  isOpen: isOpen,
                  isLandscapeTwoPane: true,
                  onClose: () {},
                  subScreenBackAction: backAction,
                  headerTitleTransition: headerTitleTransition,
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp(isOpen: false));
      await tester.pumpWidget(buildApp(isOpen: true));
      await tester.pump();

      await tester.tap(find.text('Theme'));
      await tester.pump();
      final masterTransition = tester
          .widgetList<AppWindowMasterDetailTransition>(
            find.byType(AppWindowMasterDetailTransition),
          )
          .firstWhere((transition) => transition.focusAnchorKey != null);
      expect(masterTransition.focusAvoidTabBar, isFalse);
      final masterView = find.byType(CustomScrollView).first;
      final masterScrollable = find.descendant(
        of: masterView,
        matching: find.byType(Scrollable),
      );
      final masterPosition = tester
          .state<ScrollableState>(masterScrollable)
          .position;
      final initialMasterOffset = masterPosition.pixels;
      await tester.timedDrag(
        masterView,
        const Offset(0, -180),
        const Duration(milliseconds: 80),
      );
      expect(masterPosition.pixels, greaterThan(initialMasterOffset));

      await tester.pumpAndSettle();
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);

      await tester.drag(masterView, const Offset(0, 180));
      await tester.drag(masterView, const Offset(0, 100));
      await tester.pumpAndSettle();
      final defaultViewCenter = tester.getCenter(find.text('Default View'));
      final masterViewRect = tester.getRect(masterView);
      expect(defaultViewCenter.dy > masterViewRect.top, isTrue);
      expect(defaultViewCenter.dy < masterViewRect.bottom, isTrue);
      await tester.tap(find.text('Default View'));
      await tester.pump();
      await tester.tap(find.text('First Day of Week'));
      await tester.pumpAndSettle();
      expect(find.text('Saturday'), findsOneWidget);

      final detailBackButton = find.ancestor(
        of: find.byIcon(CupertinoIcons.back),
        matching: find.byType(CupertinoButton),
      );
      final onBack = tester.widget<CupertinoButton>(detailBackButton).onPressed;
      expect(onBack, isNotNull);
      onBack!();
      await tester.pumpAndSettle();
      expect(find.byType(AppWindowMasterDetailTransition), findsNothing);
      expect(find.text('Saturday'), findsNothing);
      final fullWidthMaster = tester.getRect(
        find.byType(CustomScrollView).first,
      );
      final selectedMasterRow = tester.getRect(find.text('Default View').first);
      expect(selectedMasterRow.top, greaterThanOrEqualTo(fullWidthMaster.top));
      expect(selectedMasterRow.bottom, lessThanOrEqualTo(fullWidthMaster.bottom));
    },
  );
}
