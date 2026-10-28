import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/settings_panel.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';
import 'package:smart_scheduler/widgets/app_shell_toolbar.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';

void main() {
  testWidgets(
    'landscape Settings opens subscreens full-screen instead of splitting panes',
    (tester) async {
      tester.view.devicePixelRatio = 2;
      tester.view.physicalSize = const Size(1920, 1080);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final backAction = ValueNotifier<VoidCallback?>(null);
      final inlineBackVisible = ValueNotifier(false);
      final headerTitleTransition = AppHeaderTitleTransition();
      addTearDown(backAction.dispose);
      addTearDown(inlineBackVisible.dispose);
      addTearDown(headerTitleTransition.dispose);

      Widget buildApp({required bool isOpen}) {
        return CupertinoApp(
          builder: (context, child) => AppWindowContentScope(
            horizontalInset: 24,
            physicalWidth: 960,
            child: child!,
          ),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(960, 540),
              devicePixelRatio: 2,
              padding: EdgeInsets.only(left: 24),
              viewPadding: EdgeInsets.only(left: 24),
            ),
            child: Offstage(
              offstage: !isOpen,
              child: SettingsPanel(
                topInset: 0,
                bottomInset: 0,
                isOpen: isOpen,
                onClose: () {},
                subScreenBackAction: backAction,
                inlineSubScreenBackVisible: inlineBackVisible,
                headerTitleTransition: headerTitleTransition,
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp(isOpen: false));
      await tester.pumpWidget(buildApp(isOpen: true));
      await tester.pump();

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      expect(find.byType(AppWindowMasterDetailTransition), findsNothing);
      expect(find.text('Settings'), findsNothing);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      final backToolbar = tester.widget<AppShellPinnedToolbar>(
        find.byType(AppShellPinnedToolbar),
      );
      expect(backToolbar.glyph, AppShellToolbarGlyph.back);
      backToolbar.onTap();
      await tester.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect(find.byType(AppWindowMasterDetailTransition), findsNothing);
    },
  );
}
