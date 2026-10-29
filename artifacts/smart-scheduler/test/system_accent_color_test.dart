import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/services/system_accent_color.dart';

void main() {
  test('dynamic system accent retains separate light and dark scheme colors', () {
    const lightPrimary = Color(0xFF345678);
    const darkPrimary = Color(0xFFABCDEF);

    final accent = systemAccentFromDynamicColors(
      lightPrimary,
      darkPrimary,
    );

    expect(accent?.color, lightPrimary);
    expect(accent?.darkColor, darkPrimary);
  });

  test('unsupported dynamic color returns no palette', () {
    expect(systemAccentFromDynamicColors(null, null), isNull);
  });
}
