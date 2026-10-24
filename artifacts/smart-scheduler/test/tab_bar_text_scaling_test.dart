import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_settings.dart';
import 'package:smart_scheduler/widgets/floating_tab_pill.dart';

void main() {
  test('tab text keeps smaller scaling and caps at one step above default', () {
    final previousProfile = appNativeTextScaleProfileNotifier.value;
    appNativeTextScaleProfileNotifier.value = NativeTextScaleProfile(
      stops: [
        NativeTextScaleStop(scale: 0.8, scaler: TextScaler.linear(0.8)),
        NativeTextScaleStop(scale: 1.0, scaler: TextScaler.linear(1.0)),
        NativeTextScaleStop(scale: 1.12, scaler: TextScaler.linear(1.12)),
        NativeTextScaleStop(scale: 1.8, scaler: TextScaler.linear(1.8)),
      ],
      currentScale: 1.8,
      probeSizes: const [],
    );
    addTearDown(() {
      appNativeTextScaleProfileNotifier.value = previousProfile;
    });

    final smaller = skeddoTabBarTextScalerFor(TextScaler.linear(0.8));
    final oversized = skeddoTabBarTextScalerFor(TextScaler.linear(1.8));

    expect(smaller.scale(20), closeTo(16, 0.001));
    expect(oversized.scale(20), closeTo(22.4, 0.001));
  });
}
