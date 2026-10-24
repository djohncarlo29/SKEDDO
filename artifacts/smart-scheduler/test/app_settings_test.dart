import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/app_settings.dart';
import 'package:smart_scheduler/services/app_database.dart';
import 'package:smart_scheduler/services/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    SharedPreferences.resetStatic();
    appLiquidGlassOpacityNotifier.value = kLiquidGlassMaximumOpacity;
    await LocalStorage.instance.useDatabaseForTesting(
      AppDatabase(NativeDatabase.memory()),
    );
  });

  tearDown(() async {
    await LocalStorage.instance.resetDatabaseForTesting();
  });

  test('Liquid Glass defaults to 80% when no value is stored', () async {
    await loadAppSettings();

    expect(appLiquidGlassOpacityNotifier.value, kLiquidGlassMaximumOpacity);
  });

  test('Liquid Glass restores the exact saved value after reload', () async {
    await saveAppSetting('Liquid Glass', '0.5');

    appLiquidGlassOpacityNotifier.value = kLiquidGlassMaximumOpacity;
    await loadAppSettings();

    expect(appLiquidGlassOpacityNotifier.value, 0.5);
  });
}
