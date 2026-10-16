import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/settings_panel.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';

void main() {
  testWidgets(
    'landscape Settings opens Profile and slides later subscreens over it',
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

      expect(find.text('Option A'), findsOneWidget);

      await tester.tap(find.text('Theme'));
      await tester.pump();
      expect(find.text('Option A'), findsOneWidget);

      await tester.pumpAndSettle();
      expect(find.text('Option A'), findsNothing);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    },
  );
}
