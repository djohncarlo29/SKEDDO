import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai/ai_services.dart';
import 'ai/parsed_date.dart';

// ══════════════════════════════════════════════════════════════════════════════
// App-level appearance settings — module-level notifiers that are written by
// SettingsPanel and read by SKEDDOApp to rebuild CupertinoApp reactively.
//
//   appBrightnessNotifier    — null = follow system, light/dark = override.
//   appTextSizeNotifier      — 'Compact' (0.85×), 'Default' (system), 'Large' (1.15×).
//   appStartOfWeekNotifier   — 'Sunday' | 'Monday' | 'Saturday'.
//   appDefaultViewNotifier   — 'Day' | 'Week' | 'Month' | 'Year'.
//   appEventDurationNotifier — '15 minutes' | '30 minutes' | '1 hour' | '2 hours'.
//   appDateLocaleNotifier    — monthFirst or dayFirst for ambiguous numeric dates.
//   appLiquidGlassOpacityNotifier — 0.0..1.0 opacity of the floating tab bar.
// ══════════════════════════════════════════════════════════════════════════════

/// Brightness override applied to CupertinoThemeData.
/// null → CupertinoApp follows MediaQuery.platformBrightness (system mode).
final ValueNotifier<Brightness?> appBrightnessNotifier =
    ValueNotifier<Brightness?>(null);

/// Text-size multiplier selection.
/// 'Default' → respect the OS Dynamic Type / font-size setting.
/// 'Compact' → clamp textScaler to 0.95×.
/// 'Large'   → clamp textScaler to 1.05×.
final ValueNotifier<String> appTextSizeNotifier = ValueNotifier<String>(
  'Default',
);

/// Accent-color swatch index into [kCategorySwatches] / [kAccentSwatches]
/// (0–11).  Index 5 = Blue (kCatBlue / kAccentColor) — the app default.
/// Persisted across settings sub-screen lifetimes via module-level storage.
final ValueNotifier<int> appAccentNotifier = ValueNotifier<int>(5);

/// Calendar — first day of the week shown in month/week views.
final ValueNotifier<String> appStartOfWeekNotifier = ValueNotifier<String>(
  'Sunday',
);

/// Calendar — which view to open when the Calendar tab is tapped.
final ValueNotifier<String> appDefaultViewNotifier = ValueNotifier<String>(
  'Month',
);

/// Event creation — default duration pre-filled in the time picker.
final ValueNotifier<String> appEventDurationNotifier = ValueNotifier<String>(
  '1 hour',
);

/// Parsing preference for ambiguous numeric dates such as 08/12/2026.
final ValueNotifier<DateLocalePreference> appDateLocaleNotifier =
    ValueNotifier<DateLocalePreference>(DateLocalePreference.monthFirst);

/// Minimum material opacity used by the Liquid Glass control.
///
/// The Appearance slider maps its user-facing 0–100% range to 0.2–0.8
/// material opacity so both extremes remain translucent and glass-like.
const double kLiquidGlassMinimumOpacity = 0.2;

/// Maximum material opacity used by the Liquid Glass control.
const double kLiquidGlassMaximumOpacity = 0.8;

/// Opacity of the floating Liquid Glass tab bar material.
/// The setting is quantized to tenths by the Appearance subscreen.
final ValueNotifier<double> appLiquidGlassOpacityNotifier =
    ValueNotifier<double>(kLiquidGlassMaximumOpacity);

// ── SharedPreferences keys ────────────────────────────────────────────────────
const _kThemeKey = 'app_theme';
const _kTextSizeKey = 'app_text_size';
const _kAccentIndexKey = 'app_accent_index';
const _kStartOfWeekKey = 'app_start_of_week';
const _kDefaultViewKey = 'app_default_view';
const _kEventDurationKey = 'app_event_duration';
const _kDateLocaleKey = 'app_date_locale';
const _kLiquidGlassOpacityKey = 'app_liquid_glass_opacity';

/// Load all persisted settings from SharedPreferences and update notifiers.
/// Call this once at startup (before [runApp]) so the first build reflects the
/// saved state.
Future<void> loadAppSettings() async {
  final prefs = await SharedPreferences.getInstance();

  // Theme
  final theme = prefs.getString(_kThemeKey);
  if (theme != null) {
    appBrightnessNotifier.value = switch (theme) {
      'Light' => Brightness.light,
      'Dark' => Brightness.dark,
      _ => null,
    };
  }

  // Text size
  final textSize = prefs.getString(_kTextSizeKey);
  if (textSize != null) appTextSizeNotifier.value = textSize;

  // Accent color index
  final accentIndex = prefs.getInt(_kAccentIndexKey);
  if (accentIndex != null) appAccentNotifier.value = accentIndex;

  // Calendar settings
  final startOfWeek = prefs.getString(_kStartOfWeekKey);
  if (startOfWeek != null) appStartOfWeekNotifier.value = startOfWeek;

  final defaultView = prefs.getString(_kDefaultViewKey);
  if (defaultView != null) appDefaultViewNotifier.value = defaultView;

  final eventDuration = prefs.getString(_kEventDurationKey);
  if (eventDuration != null) appEventDurationNotifier.value = eventDuration;

  final dateLocale = prefs.getString(_kDateLocaleKey);
  DateLocalePreference? savedPreference;
  for (final item in DateLocalePreference.values) {
    if (item.name == dateLocale) {
      savedPreference = item;
      break;
    }
  }
  if (savedPreference != null) {
    appDateLocaleNotifier.value = savedPreference;
  }

  final liquidGlassOpacity = prefs.getDouble(_kLiquidGlassOpacityKey);
  if (liquidGlassOpacity != null) {
    final normalized =
        ((liquidGlassOpacity - kLiquidGlassMinimumOpacity) /
                (kLiquidGlassMaximumOpacity - kLiquidGlassMinimumOpacity))
            .clamp(0.0, 1.0);
    appLiquidGlassOpacityNotifier.value =
        (normalized * 10).round() / 10 * kLiquidGlassMaximumOpacity;
  }
  AIServices.setDateLocalePreference(appDateLocaleNotifier.value);
}

/// Persist a single settings key.  All callers go through here so the key list
/// stays in one place.
void saveAppSetting(String routeTitle, String value) {
  SharedPreferences.getInstance().then((prefs) {
    switch (routeTitle) {
      case 'Theme':
        prefs.setString(_kThemeKey, value);
      case 'Text Size':
        prefs.setString(_kTextSizeKey, value);
      case 'Start of Week':
        prefs.setString(_kStartOfWeekKey, value);
      case 'Default View':
        prefs.setString(_kDefaultViewKey, value);
      case 'Default Event Duration':
        prefs.setString(_kEventDurationKey, value);
      case 'Date Format':
        prefs.setString(_kDateLocaleKey, appDateLocaleNotifier.value.name);
      case 'Liquid Glass':
        prefs.setDouble(
          _kLiquidGlassOpacityKey,
          appLiquidGlassOpacityNotifier.value,
        );
    }
  });
}

/// Persist the accent-color index.
void saveAccentIndex(int index) {
  SharedPreferences.getInstance().then(
    (p) => p.setInt(_kAccentIndexKey, index),
  );
}
