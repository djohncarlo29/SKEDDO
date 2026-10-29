import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/app_settings.dart';
import 'package:smart_scheduler/main.dart';
import 'package:smart_scheduler/services/system_accent_color.dart';

void main() {
  testWidgets(
    'selecting system accent preserves the system theme brightness',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.binding.platformDispatcher.platformBrightnessTestValue =
          Brightness.dark;
      addTearDown(
        tester.binding.platformDispatcher.clearPlatformBrightnessTestValue,
      );

      final oldAppBrightness = appBrightnessNotifier.value;
      final oldSystemBrightness = appSystemBrightnessNotifier.value;
      final oldAccentUsesSystem = appAccentUsesSystemNotifier.value;
      final oldSystemAccent = appSystemAccentColorNotifier.value;
      addTearDown(() {
        appBrightnessNotifier.value = oldAppBrightness;
        appSystemBrightnessNotifier.value = oldSystemBrightness;
        appAccentUsesSystemNotifier.value = oldAccentUsesSystem;
        appSystemAccentColorNotifier.value = oldSystemAccent;
      });
      appBrightnessNotifier.value = null;
      appAccentUsesSystemNotifier.value = false;

      // Model a web preview where the inherited MediaQuery disagrees with the
      // platform brightness snapshot used to label the System theme option.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(402, 874),
            platformBrightness: Brightness.light,
          ),
          child: const SKEDDOApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(appSystemBrightnessNotifier.value, Brightness.dark);
      expect(
        CupertinoTheme.brightnessOf(tester.element(find.byType(AppShell))),
        Brightness.dark,
      );

      appAccentUsesSystemNotifier.value = true;
      appSystemAccentColorNotifier.value =
          CupertinoDynamicColor.withBrightness(
            color: const Color(0xFF3B82F6),
            darkColor: const Color(0xFF8AB4F8),
          );
      await tester.pumpAndSettle();

      final shellContext = tester.element(find.byType(AppShell));
      expect(CupertinoTheme.brightnessOf(shellContext), Brightness.dark);
      expect(MediaQuery.platformBrightnessOf(shellContext), Brightness.dark);
      expect(tester.takeException(), isNull);
    },
  );
}
