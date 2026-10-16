import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/settings_panel.dart';
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
      await tester.tap(find.text('Start of Week'));
      await tester.pumpAndSettle();
      expect(find.text('Saturday'), findsOneWidget);
    },
  );
}
