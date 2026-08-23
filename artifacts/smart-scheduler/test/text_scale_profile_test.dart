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

  test(
    'keeps the complete native profile separate from seven UI mappings',
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
        appSkeddoTextScaleMappingNotifier.value.where(
          (item) => item.kind == SkeddoTextScaleMappingKind.native,
        ),
        hasLength(7),
      );
      expect(appSkeddoTextScaleStops, hasLength(7));
      expect(appSkeddoTextScaleStops, <double>[
        0.88,
        0.96,
        1.04,
        1.12,
        1.24,
        1.35,
        1.46,
      ]);
      expect(appSystemTextScaleNotifier.value, 1.24);
      expect(
        skeddoTextScaleIndexForSystemScale(1.70),
        6,
        reason: 'System thumb caps visually at the seventh SKEDDO position',
      );
    },
  );

  test(
    'Custom keeps its resolved scaler across native profile refresh',
    () async {
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
    },
  );

  test(
    'System and Custom use the identical curve for every direct native stop',
    () async {
      final nativeStops = <double>[0.80, 1.00, 1.20, 1.40, 1.60];
      final probeSizes = <double>[4.0, 16.0, 32.0, 64.0];
      final curves = <Object?>[
        <double>[0.76, 0.90, 1.02, 1.10],
        <double>[0.80, 1.00, 1.12, 1.20],
        <double>[0.88, 1.08, 1.20, 1.28],
        <double>[0.94, 1.16, 1.28, 1.36],
        <double>[1.00, 1.24, 1.36, 1.44],
      ];
      var activeStop = nativeStops.first;
      channel.setMockMethodCallHandler((call) async {
        if (call.method != 'getProfile') return null;
        return <String, Object>{
          'currentScale': activeStop,
          'stops': nativeStops,
          'probeSizes': probeSizes,
          'curves': curves,
        };
      });

      await initializeDeviceTextScaleProfile();
      final profile = appNativeTextScaleProfileNotifier.value!;
      final mapping = appSkeddoTextScaleMappingNotifier.value;
      final sizes = <double>[6.0, 12.0, 20.0, 40.0, 80.0];

      for (var index = 0; index < nativeStops.length; index++) {
        activeStop = nativeStops[index];
        await initializeDeviceTextScaleProfile();
        final systemCurve = resolveCurrentNativeSystemTextScaler()!;
        final customCurve = mapping[index].scaler!;
        for (final size in sizes) {
          expect(
            customCurve.scale(size),
            closeTo(systemCurve.scale(size), 0.000001),
            reason: 'native position ${index + 1}, font size $size',
          );
        }
      }
    },
  );

  test(
    'maps fewer than seven native stops without inserting middle stops',
    () async {
      final expected = <int, List<double>>{
        4: <double>[1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6],
        5: <double>[1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6],
        7: <double>[1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6],
        9: <double>[1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6],
        12: <double>[1.0, 1.1, 1.2, 1.3, 1.4, 1.5, 1.6],
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
            'curves': List<Object?>.filled(count, <double>[1.0, 1.0]),
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
                .every(
                  (item) => item.kind == SkeddoTextScaleMappingKind.native,
                ),
            isTrue,
            reason: '$count native stops',
          );
          expect(
            mapping
                .skip(count)
                .every(
                  (item) =>
                      item.kind == SkeddoTextScaleMappingKind.extrapolated,
                ),
            isTrue,
            reason: '$count native stops',
          );
        } else if (count == 7) {
          expect(
            mapping.every(
              (item) => item.kind == SkeddoTextScaleMappingKind.native,
            ),
            isTrue,
            reason: '$count native stops',
          );
        } else {
          expect(
            mapping.every(
              (item) => item.kind == SkeddoTextScaleMappingKind.native,
            ),
            isTrue,
            reason:
                '$count native stops expose the first seven native positions',
          );
          expect(
            mapping.every((item) => item.nativeIndex! < 7),
            isTrue,
            reason: '$count native stops never expose later Custom positions',
          );
        }
      }
    },
  );

  test(
    'System keeps a native position beyond seven while the SKEDDO thumb caps',
    () async {
      final nativeStops = <double>[
        0.88,
        0.96,
        1.04,
        1.12,
        1.24,
        1.35,
        1.46,
        1.57,
        1.70,
        1.85,
        2.00,
        2.15,
      ];
      channel.setMockMethodCallHandler((call) async {
        if (call.method != 'getProfile') return null;
        return <String, Object>{
          'currentScale': 2.00,
          'stops': nativeStops,
          'probeSizes': <double>[1.0, 2.0],
          'curves': List<Object?>.generate(
            nativeStops.length,
            (index) => <double>[nativeStops[index], nativeStops[index]],
          ),
        };
      });

      await initializeDeviceTextScaleProfile();

      expect(appNativeTextScaleProfileNotifier.value!.stops, hasLength(12));
      expect(appSystemTextScaleNotifier.value, 2.00);
      expect(appSkeddoTextScaleStops, <double>[
        0.88,
        0.96,
        1.04,
        1.12,
        1.24,
        1.35,
        1.46,
      ]);
      expect(skeddoTextScaleIndexForSystemScale(2.00), 6);
      expect(
        appSkeddoTextScaleMappingNotifier.value.every(
          (item) => item.nativeIndex! <= 6,
        ),
        isTrue,
      );
    },
  );

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
