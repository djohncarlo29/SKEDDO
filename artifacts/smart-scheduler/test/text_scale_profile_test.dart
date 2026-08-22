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
    appCustomTextScalerNotifier.value = null;
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

  test('keeps the complete native profile separate from seven UI mappings',
      () async {
    final validCurve = <double>[1.0, 1.1];
    channel.setMockMethodCallHandler((call) async {
      if (call.method == 'getProfile') {
        return <String, Object>{
          'currentScale': 1.24,
          'stops': <double>[
            0.88,
            0.96,
            1.04,
            1.12,
            1.24,
            1.35,
            1.46,
            1.57,
            1.70,
          ],
          'probeSizes': <double>[1.0, 2.0],
          'curves': List<Object?>.filled(9, validCurve),
        };
      }
      return null;
    });

    await initializeDeviceTextScaleProfile();

    final profile = appNativeTextScaleProfileNotifier.value;
    expect(profile, isNotNull);
    expect(profile!.stops, hasLength(9));
    expect(appSkeddoTextScaleMappingNotifier.value, hasLength(7));
    expect(
      appSkeddoTextScaleMappingNotifier.value
          .where((item) => item.kind == SkeddoTextScaleMappingKind.native),
      hasLength(3),
    );
    expect(
      appSkeddoTextScaleMappingNotifier.value
          .where((item) => item.kind == SkeddoTextScaleMappingKind.interpolated),
      hasLength(4),
    );
    expect(appSkeddoTextScaleStops, hasLength(7));
  });

  test('Custom keeps its resolved scaler across native profile refresh', () async {
    var profileCall = 0;
    channel.setMockMethodCallHandler((call) async {
      if (call.method != 'getProfile') return null;
      profileCall++;
      final base = profileCall == 1 ? 1.0 : 2.0;
      return <String, Object>{
        'currentScale': base,
        'stops': <double>[base, base + 0.1, base + 0.2, base + 0.3],
        'probeSizes': <double>[1.0, 2.0],
        'curves': <Object?>[
          <double>[base, base],
          <double>[base + 0.1, base + 0.1],
          <double>[base + 0.2, base + 0.2],
          <double>[base + 0.3, base + 0.3],
        ],
      };
    });

    await initializeDeviceTextScaleProfile();
    selectCustomTextScaleIndex(4);
    final selectedScaler = appCustomTextScalerNotifier.value;
    expect(selectedScaler, isNotNull);
    final selectedAt20 = selectedScaler!.scale(20);

    await initializeDeviceTextScaleProfile();

    expect(appTextSizeIndexNotifier.value, 4);
    expect(appCustomTextScalerNotifier.value, same(selectedScaler));
    expect(appCustomTextScalerNotifier.value!.scale(20), selectedAt20);
  });

  test('maps fewer than seven native stops without inserting middle stops',
      () async {
    final expected = <int, List<double>>{
      4: <double>[1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6],
      5: <double>[1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6],
      7: <double>[1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6],
      9: <double>[1.0, 1.133333, 1.266667, 1.4, 1.533333, 1.666667, 1.8],
      12: <double>[
        1.0,
        1.183333,
        1.366667,
        1.55,
        1.733333,
        1.916667,
        2.1,
      ],
    };
    for (final entry in expected.entries) {
      final count = entry.key;
      final nativeStops = <double>[
        for (var index = 0; index < count; index++) 1.0 + index * 0.1,
      ];
      channel.setMockMethodCallHandler((call) async {
        if (call.method != 'getProfile') return null;
        return <String, Object>{
          'currentScale': nativeStops.last,
          'stops': nativeStops,
          'probeSizes': <double>[1.0, 2.0],
          'curves': List<Object?>.filled(
            count,
            <double>[1.0, 1.0],
          ),
        };
      });

      await initializeDeviceTextScaleProfile();

      final mapping = appSkeddoTextScaleMappingNotifier.value;
      expect(mapping, hasLength(7));
      for (var index = 0; index < entry.value.length; index++) {
        expect(
          mapping[index].scale,
          closeTo(entry.value[index], 0.000001),
          reason: '$count native stops, position $index',
        );
      }
      if (count < 7) {
        expect(
          mapping
              .take(count)
              .every((item) => item.kind == SkeddoTextScaleMappingKind.native),
          isTrue,
          reason: '$count native stops',
        );
        expect(
          mapping
              .skip(count)
              .every(
                (item) => item.kind == SkeddoTextScaleMappingKind.extrapolated,
              ),
          isTrue,
          reason: '$count native stops',
        );
      } else if (count == 7) {
        expect(
          mapping.every((item) => item.kind == SkeddoTextScaleMappingKind.native),
          isTrue,
          reason: '$count native stops',
        );
      } else {
        expect(
          mapping
              .where((item) => item.kind == SkeddoTextScaleMappingKind.native)
              .length,
          count == 9 ? 3 : 2,
          reason: '$count native stops',
        );
        expect(
          mapping
              .where(
                (item) =>
                    item.kind == SkeddoTextScaleMappingKind.interpolated,
              )
              .length,
          count == 9 ? 4 : 5,
          reason: '$count native stops',
        );
      }
    }
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
