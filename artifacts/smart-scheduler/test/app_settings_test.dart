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
    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      kDefaultLiquidGlassSliderPosition,
    );
    await LocalStorage.instance.useDatabaseForTesting(
      AppDatabase(NativeDatabase.memory()),
    );
  });

  tearDown(() async {
    await LocalStorage.instance.resetDatabaseForTesting();
  });

  test('Liquid Glass defaults to 50% when no value is stored', () async {
    await loadAppSettings();

    expect(
      liquidGlassSliderPositionForOpacity(appLiquidGlassOpacityNotifier.value),
      kDefaultLiquidGlassSliderPosition,
    );
  });

  test('Liquid Glass restores the changed slider value after reload', () async {
    const changedPosition = 0.73;
    final changedValue = liquidGlassOpacityForSliderPosition(changedPosition);
    await saveAppSetting('Liquid Glass', changedValue.toString());

    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      kDefaultLiquidGlassSliderPosition,
    );
    await loadAppSettings();

    expect(
      liquidGlassSliderPositionForOpacity(appLiquidGlassOpacityNotifier.value),
      changedPosition,
    );
  });
}
