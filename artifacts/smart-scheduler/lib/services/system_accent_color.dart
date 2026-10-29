import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, ValueNotifier, defaultTargetPlatform;
import 'package:flutter/material.dart' show Brightness, ColorScheme;
import 'package:system_theme/system_theme.dart';

import '../app_theme.dart';

/// The currently available native accent as a light/dark pair.
///
/// Android values come from dynamic_color's wallpaper-derived ColorSchemes;
/// iOS values are generated from the system accent seed exposed by
/// system_theme. Unsupported platforms retain SKEDDO's default blue.
final ValueNotifier<CupertinoDynamicColor> appSystemAccentColorNotifier =
    ValueNotifier<CupertinoDynamicColor>(kAccentColor);

CupertinoDynamicColor? systemAccentFromDynamicColors(
  Color? lightPrimary,
  Color? darkPrimary,
) {
  if (lightPrimary == null && darkPrimary == null) return null;
  return CupertinoDynamicColor.withBrightness(
    color: lightPrimary ?? darkPrimary!,
    darkColor: darkPrimary ?? lightPrimary!,
  );
}

bool hasSameAccentColorPair(
  CupertinoDynamicColor first,
  CupertinoDynamicColor second,
) {
  return first.color.toARGB32() == second.color.toARGB32() &&
      first.darkColor.toARGB32() == second.darkColor.toARGB32();
}

CupertinoDynamicColor _accentPairFromSeed(Color seed) {
  return CupertinoDynamicColor.withBrightness(
    color: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
    ).primary,
    darkColor: ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    ).primary,
  );
}

/// Refresh iOS's native accent after launch and whenever the app resumes.
/// Android refreshes through DynamicColorBuilder, which supplies the full
/// wallpaper palette and is refreshed separately by its state object.
Future<void> refreshSystemAccentColor() async {
  if (defaultTargetPlatform != TargetPlatform.iOS) return;

  SystemTheme.fallbackColor = kAccentColor.color;
  try {
    await SystemTheme.accentColor.load();
    appSystemAccentColorNotifier.value = _accentPairFromSeed(
      SystemTheme.accentColor.accent,
    );
  } catch (_) {
    appSystemAccentColorNotifier.value = kAccentColor;
  }
}
