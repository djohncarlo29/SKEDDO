import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_settings.dart';
import 'package:smart_scheduler/services/system_accent_color.dart';
import 'package:smart_scheduler/settings_panel.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';
import 'package:smart_scheduler/widgets/app_shell_toolbar.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';

void main() {
  testWidgets(
    'Theme system label stays on OS brightness under an app-only override',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final originalAppBrightness = appBrightnessNotifier.value;
      final originalSystemBrightness = appSystemBrightnessNotifier.value;
      appBrightnessNotifier.value = Brightness.light;
      appSystemBrightnessNotifier.value = Brightness.dark;
      addTearDown(() {
        appBrightnessNotifier.value = originalAppBrightness;
        appSystemBrightnessNotifier.value = originalSystemBrightness;
      });

      final backAction = ValueNotifier<VoidCallback?>(null);
      final inlineBackVisible = ValueNotifier(false);
      final headerTitleTransition = AppHeaderTitleTransition();
      addTearDown(backAction.dispose);
      addTearDown(inlineBackVisible.dispose);
      addTearDown(headerTitleTransition.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) => AppWindowContentScope(
            horizontalInset: 0,
            physicalWidth: 402,
            child: child!,
          ),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(402, 874),
              platformBrightness: Brightness.light,
            ),
            child: SettingsPanel(
              topInset: 0,
              bottomInset: 0,
              isOpen: true,
              onClose: () {},
              subScreenBackAction: backAction,
              inlineSubScreenBackVisible: inlineBackVisible,
              headerTitleTransition: headerTitleTransition,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Theme').first);
      await tester.pumpAndSettle();

      expect(find.text('System Setting (Dark)'), findsOneWidget);
      expect(find.text('Skeddo App Only'), findsOneWidget);
      expect(
        find.text(
          'This setting will apply in Skeddo only. Other apps will use the system setting.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          'When selected, Skeddo will use the setting from '
          '${defaultTargetPlatform == TargetPlatform.iOS ? 'Display & Brightness' : 'Display'}.',
        ),
        findsOneWidget,
      );

      final backToolbar = tester.widget<AppShellPinnedToolbar>(
        find.byType(AppShellPinnedToolbar),
      );
      expect(backToolbar.glyph, AppShellToolbarGlyph.back);
      backToolbar.onTap();
      await tester.pumpAndSettle();
      expect(find.text('Theme'), findsOneWidget);
    },
  );

  testWidgets(
    'system theme value includes brightness and accent stays unnamed',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(402, 874);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final oldAppBrightness = appBrightnessNotifier.value;
      final oldSystemBrightness = appSystemBrightnessNotifier.value;
      final oldAccentUsesSystem = appAccentUsesSystemNotifier.value;
      final oldSystemAccent = appSystemAccentColorNotifier.value;
      appBrightnessNotifier.value = null;
      appSystemBrightnessNotifier.value = Brightness.dark;
      appAccentUsesSystemNotifier.value = true;
      appSystemAccentColorNotifier.value =
          CupertinoDynamicColor.withBrightness(
            color: const Color(0xFF1769AA),
            darkColor: const Color(0xFF80B9F2),
          );
      addTearDown(() {
        appBrightnessNotifier.value = oldAppBrightness;
        appSystemBrightnessNotifier.value = oldSystemBrightness;
        appAccentUsesSystemNotifier.value = oldAccentUsesSystem;
        appSystemAccentColorNotifier.value = oldSystemAccent;
      });

      final backAction = ValueNotifier<VoidCallback?>(null);
      final inlineBackVisible = ValueNotifier(false);
      final headerTitleTransition = AppHeaderTitleTransition();
      addTearDown(backAction.dispose);
      addTearDown(inlineBackVisible.dispose);
      addTearDown(headerTitleTransition.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) => AppWindowContentScope(
            horizontalInset: 0,
            physicalWidth: 402,
            child: child!,
          ),
          home: SettingsPanel(
            topInset: 0,
            bottomInset: 0,
            isOpen: true,
            onClose: () {},
            subScreenBackAction: backAction,
            inlineSubScreenBackVisible: inlineBackVisible,
            headerTitleTransition: headerTitleTransition,
          ),
        ),
      );
      await tester.pumpAndSettle();

      List<String> visibleText() => tester
          .widgetList<Text>(find.byType(Text))
          .map((text) => (text.data ?? '').replaceAll('\u2060', ''))
          .toList();

      expect(visibleText(), contains('System (Dark)'));
      expect(visibleText(), contains('System Setting'));
      expect(visibleText(), isNot(contains('System (Blue)')));

      appSystemBrightnessNotifier.value = Brightness.light;
      await tester.pump();
      expect(visibleText(), contains('System (Light)'));

      await tester.tap(find.text('Accent Color').first);
      await tester.pumpAndSettle();
      expect(visibleText(), contains('System Setting'));
      expect(visibleText(), isNot(contains('System Setting (Blue)')));
    },
  );
}
