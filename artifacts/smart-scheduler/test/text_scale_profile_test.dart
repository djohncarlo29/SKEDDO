import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.smartscheduler/text_scale');

  tearDown(() {
    channel.setMockMethodCallHandler(null);
    appHasNativeTextScaleProfile = false;
    appTextSizeUsesSystemNotifier.value = true;
    appTextSizeIndexNotifier.value = 3;
  });

  test(
    'incomplete native profiles remain on the compatibility fallback',
    () async {
      channel.setMockMethodCallHandler((call) async {
        if (call.method == 'getProfile') {
          return <String, Object>{
            'currentScale': 1.24,
            'stops': <double>[1.24],
          };
        }
        return null;
      });

      appHasNativeTextScaleProfile = false;
      await initializeDeviceTextScaleProfile();

      expect(appHasNativeTextScaleProfile, isFalse);
    },
  );

  test('refresh keeps Custom selection and preserves curve indexes', () async {
    final validCurve = <double>[1.0, 1.1];
    channel.setMockMethodCallHandler((call) async {
      if (call.method == 'getProfile') {
        return <String, Object>{
          'currentScale': 1.24,
          'stops': <double>[0.88, 1.0, 1.12, 1.24, 1.35, 1.46, 1.57],
          'probeSizes': <double>[1.0, 2.0],
          'curves': <Object?>[
            validCurve,
            null,
            validCurve,
            validCurve,
            validCurve,
            validCurve,
            validCurve,
          ],
        };
      }
      return null;
    });

    appTextSizeUsesSystemNotifier.value = false;
    appTextSizeIndexNotifier.value = 1;
    await initializeDeviceTextScaleProfile();

    expect(appTextSizeIndexNotifier.value, 1);
    expect(appTextScaleStopsNotifier.value, hasLength(7));
    expect(appPlatformTextScalersNotifier.value, hasLength(7));
    expect(appPlatformTextScalersNotifier.value[1], isNull);
    expect(appPlatformTextScalersNotifier.value[2], isNotNull);
  });

  test('overlapping profile reads publish in request order', () async {
    var calls = 0;
    channel.setMockMethodCallHandler((call) async {
      if (call.method != 'getProfile') return null;
      calls++;
      final scale = calls == 1 ? 1.10 : 1.50;
      if (calls == 1) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      return <String, Object>{
        'currentScale': scale,
        'stops': <double>[1.0, 1.5],
        'probeSizes': <double>[1.0, 2.0],
        'curves': <Object?>[
          <double>[1.0, 1.0],
          <double>[1.5, 1.5],
        ],
      };
    });

    await Future.wait([
      initializeDeviceTextScaleProfile(),
      initializeDeviceTextScaleProfile(),
    ]);

    expect(calls, 2);
    expect(appSystemTextScaleNotifier.value, 1.50);
  });
}
