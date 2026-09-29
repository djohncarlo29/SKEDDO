import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SharedPreferences.resetStatic();
    appLiquidGlassOpacityNotifier.value = kLiquidGlassMaximumOpacity;
  });

  test('Liquid Glass defaults to 80% when no value is stored', () async {
    await loadAppSettings();

    expect(
      appLiquidGlassOpacityNotifier.value,
      kLiquidGlassMaximumOpacity,
    );
  });

  test('Liquid Glass restores the exact saved value after reload', () async {
    await saveAppSetting('Liquid Glass', '0.5');

    appLiquidGlassOpacityNotifier.value = kLiquidGlassMaximumOpacity;
    await loadAppSettings();

    expect(appLiquidGlassOpacityNotifier.value, 0.5);
  });
}