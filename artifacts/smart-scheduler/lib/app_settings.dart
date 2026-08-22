import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai/ai_services.dart';
import 'ai/parsed_date.dart';

// ══════════════════════════════════════════════════════════════════════════════
// App-level appearance settings — module-level notifiers that are written by
// SettingsPanel and read by SKEDDOApp to rebuild CupertinoApp reactively.
//
//   appBrightnessNotifier    — null = follow system, light/dark = override.
//   appTextSizeUsesSystemNotifier — true when text follows the phone OS.
//   appTextSizeIndexNotifier — custom SKEDDO text-size position (0–6).
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

/// Whether SKEDDO follows the phone's current OS text size.
final ValueNotifier<bool> appTextSizeUsesSystemNotifier = ValueNotifier<bool>(
  true,
);

/// Custom SKEDDO text-size position. This is kept as an index into the
/// device-specific stops below.
final ValueNotifier<int> appTextSizeIndexNotifier = ValueNotifier<int>(3);

/// The unmodified OS text scale captured above SKEDDO's optional custom
/// MediaQuery override. Settings uses this to keep the seven-position slider
/// aligned with the phone while System mode is active.
final ValueNotifier<double> appSystemTextScaleNotifier = ValueNotifier<double>(
  1.0,
);

/// Compatibility stops used on web and on old native binaries that expose only
/// the active scale. These are SKEDDO UI stops, never a native profile.
const List<double> kFallbackSkeddoTextScaleStops = <double>[
  0.88,
  1.00,
  1.12,
  1.24,
  1.35,
  1.46,
  1.57,
];

/// The seven SKEDDO UI stop values. This is deliberately separate from
/// [appNativeTextScaleProfileNotifier], whose list remains complete.
final ValueNotifier<List<double>> appSkeddoTextScaleStopsNotifier =
    ValueNotifier<List<double>>(kFallbackSkeddoTextScaleStops);

enum SkeddoTextScaleMappingKind {
  native,
  interpolated,
  extrapolated,
  compatibilityFallback,
}

class NativeTextScaleStop {
  final double scale;
  final TextScaler? scaler;

  const NativeTextScaleStop({required this.scale, required this.scaler});
}

/// The complete platform profile. This list is never resized to match the
/// seven-position SKEDDO control.
class NativeTextScaleProfile {
  final List<NativeTextScaleStop> stops;
  final double currentScale;
  final List<double> probeSizes;

  const NativeTextScaleProfile({
    required this.stops,
    required this.currentScale,
    required this.probeSizes,
  });

  int get length => stops.length;
}

class SkeddoTextScaleMapping {
  final double scale;
  final SkeddoTextScaleMappingKind kind;
  final int? nativeIndex;
  final TextScaler? scaler;

  const SkeddoTextScaleMapping({
    required this.scale,
    required this.kind,
    required this.nativeIndex,
    required this.scaler,
  });
}

final ValueNotifier<NativeTextScaleProfile?> appNativeTextScaleProfileNotifier =
    ValueNotifier<NativeTextScaleProfile?>(null);

/// The independent seven-position UI mapping. Its entries reference the
/// complete native profile or explicitly identify derived/fallback behavior.
final ValueNotifier<List<SkeddoTextScaleMapping>>
    appSkeddoTextScaleMappingNotifier =
    ValueNotifier<List<SkeddoTextScaleMapping>>(
      const <SkeddoTextScaleMapping>[],
    );

/// Frozen scaler selected for the active Custom setting. Native profile
/// refreshes never replace this value; only an explicit Custom selection does.
final ValueNotifier<TextScaler?> appCustomTextScalerNotifier =
    ValueNotifier<TextScaler?>(null);

const _textScaleChannel = MethodChannel('com.smartscheduler/text_scale');

/// Whether the native profile was loaded successfully. When true, the native
/// currentScale is authoritative; Flutter's MediaQuery value is only a
/// fallback for web and older binaries without this bridge.
bool appHasNativeTextScaleProfile = false;

/// The exact platform TextScaler captured while System mode is active.
///
/// Reusing this object for the matching custom position preserves Android's
/// nonlinear accessibility curve instead of replacing it with a linear
/// approximation. It is intentionally not refreshed while Custom mode is
/// active, so Custom remains independent from later OS changes.
TextScaler? appCapturedSystemTextScaler;
int? appCapturedSystemTextScaleIndex;

class _SampledPlatformTextScaler extends TextScaler {
  final List<double> _probeSizes;
  final List<double> _ratios;

  const _SampledPlatformTextScaler(this._probeSizes, this._ratios);

  @override
  double scale(double fontSize) {
    if (_probeSizes.isEmpty || _ratios.isEmpty) return fontSize;
    if (fontSize <= _probeSizes.first) return fontSize * _ratios.first;
    for (var i = 1; i < _probeSizes.length; i++) {
      if (fontSize <= _probeSizes[i]) {
        final t =
            (fontSize - _probeSizes[i - 1]) /
            (_probeSizes[i] - _probeSizes[i - 1]);
        final ratio = _ratios[i - 1] + (_ratios[i] - _ratios[i - 1]) * t;
        return fontSize * ratio;
      }
    }
    return fontSize * _ratios.last;
  }

  @override
  double get textScaleFactor => scale(16) / 16;
}

_SampledPlatformTextScaler _interpolatePlatformScalers(
  _SampledPlatformTextScaler lower,
  _SampledPlatformTextScaler upper,
  double t,
) {
  final ratios = <double>[
    for (var i = 0; i < lower._ratios.length; i++)
      lower._ratios[i] + (upper._ratios[i] - lower._ratios[i]) * t,
  ];
  return _SampledPlatformTextScaler(lower._probeSizes, ratios);
}

List<double> get appSkeddoTextScaleStops =>
    appSkeddoTextScaleStopsNotifier.value;

double skeddoTextScaleForIndex(int index) =>
    appSkeddoTextScaleStops[index.clamp(
      0,
      appSkeddoTextScaleStops.length - 1,
    )];

int skeddoTextScaleIndexForSystemScale(double scale) {
  var closestIndex = 0;
  var closestDistance = double.infinity;
  for (var i = 0; i < appSkeddoTextScaleStops.length; i++) {
    final distance = (appSkeddoTextScaleStops[i] - scale).abs();
    if (distance < closestDistance) {
      closestDistance = distance;
      closestIndex = i;
    }
  }
  return closestIndex;
}

/// Fetch the complete native OS profile. The separate SKEDDO mapping is built
/// from it without modifying or trimming the native entries.
Future<void> initializeDeviceTextScaleProfile() {
  return _enqueueTextScaleProfileOperation(_loadDeviceTextScaleProfile);
}

Future<void> _loadDeviceTextScaleProfile() async {
  final request = ++_textScaleProfileRequest;
  try {
    final raw = await _textScaleChannel.invokeMethod<Map<Object?, Object?>>(
      'getProfile',
    );
    final rawStops = raw?['stops'];
    if (rawStops is! List) return;
    final nativeStops = rawStops
        .whereType<num>()
        .map((value) => value.toDouble())
        .where((value) => value.isFinite && value > 0)
        .toList();
    if (nativeStops.length < 2) return;
    for (var i = 1; i < nativeStops.length; i++) {
      if (nativeStops[i] <= nativeStops[i - 1]) return;
    }

    final rawProbeSizes = raw?['probeSizes'];
    final rawCurves = raw?['curves'];
    final probeSizes = rawProbeSizes is List
        ? rawProbeSizes
              .map((value) => value is num ? value.toDouble() : double.nan)
              .toList()
        : <double>[];
    if (probeSizes.length < 2 ||
        probeSizes.any((value) => !value.isFinite || value <= 0)) {
      return;
    }
    for (var i = 1; i < probeSizes.length; i++) {
      if (probeSizes[i] <= probeSizes[i - 1]) return;
    }
    final nativeScalers = <TextScaler?>[
      for (var i = 0; i < nativeStops.length; i++)
        _parsePlatformScaler(rawCurves, i, probeSizes),
    ];
    final nativeProfileStops = <NativeTextScaleStop>[
      for (var i = 0; i < nativeStops.length; i++)
        NativeTextScaleStop(
          scale: nativeStops[i],
          scaler: nativeScalers[i],
        ),
    ];
    final current = (raw?['currentScale'] as num?)?.toDouble();
    if (current != null &&
        current.isFinite &&
        request == _textScaleProfileRequest) {
      final profile = NativeTextScaleProfile(
        stops: List<NativeTextScaleStop>.unmodifiable(nativeProfileStops),
        currentScale: current,
        probeSizes: List<double>.unmodifiable(probeSizes),
      );
      appNativeTextScaleProfileNotifier.value = profile;
      final mapping = _createSkeddoTextScaleMapping(profile);
      appSkeddoTextScaleMappingNotifier.value =
          List<SkeddoTextScaleMapping>.unmodifiable(mapping);
      // Only the seven-position UI representation is updated here. The
      // complete native profile above is never projected back into a
      // seven-entry native list.
      appSkeddoTextScaleStopsNotifier.value = List<double>.unmodifiable(
        mapping.map((item) => item.scale).toList(),
      );
      appHasNativeTextScaleProfile = true;
      appSystemTextScaleNotifier.value = current;
    }
  } on PlatformException {
    // Flutter's MediaQuery scale remains the authoritative fallback.
  } on MissingPluginException {
    // Web and older binaries do not have the native profile channel.
  }
}

List<SkeddoTextScaleMapping> _createSkeddoTextScaleMapping(
  NativeTextScaleProfile profile,
) {
  final nativeCount = profile.stops.length;
  if (nativeCount == 0) {
    return List<SkeddoTextScaleMapping>.generate(
      7,
      (_) => const SkeddoTextScaleMapping(
        scale: 1.0,
        kind: SkeddoTextScaleMappingKind.compatibilityFallback,
        nativeIndex: null,
        scaler: null,
      ),
    );
  }
  return List<SkeddoTextScaleMapping>.generate(7, (index) {
    final coordinate = index * (nativeCount - 1) / 6;
    final lower = coordinate.floor();
    final upper = coordinate.ceil();
    if (lower == upper) {
      return SkeddoTextScaleMapping(
        scale: profile.stops[lower].scale,
        kind: SkeddoTextScaleMappingKind.native,
        nativeIndex: lower,
        // A missing platform curve is an explicit compatibility degradation,
        // but it is still captured in the mapping so Custom can freeze it.
        scaler:
            profile.stops[lower].scaler ??
            TextScaler.linear(profile.stops[lower].scale),
      );
    }
    final lowerScaler = profile.stops[lower].scaler;
    final upperScaler = profile.stops[upper].scaler;
    return SkeddoTextScaleMapping(
      scale: profile.stops[lower].scale +
          (profile.stops[upper].scale - profile.stops[lower].scale) *
              (coordinate - lower),
      kind: SkeddoTextScaleMappingKind.interpolated,
      nativeIndex: null,
      scaler: lowerScaler is _SampledPlatformTextScaler &&
              upperScaler is _SampledPlatformTextScaler
          ? _interpolatePlatformScalers(
              lowerScaler,
              upperScaler,
              coordinate - lower,
            )
            : TextScaler.linear(
                profile.stops[lower].scale +
                    (profile.stops[upper].scale - profile.stops[lower].scale) *
                        (coordinate - lower),
              ),
    );
  });
}

TextScaler? resolveSkeddoTextScale(int index) {
  final mapping = appSkeddoTextScaleMappingNotifier.value;
  if (index < 0 || index >= mapping.length) return null;
  return mapping[index].scaler;
}

/// Explicitly enters or previews a Custom position. The resolved scaler is
/// captured here, not read again from the mutable native-profile notifier.
void selectCustomTextScaleIndex(int index) {
  final clamped = index.clamp(0, 6);
  appTextSizeIndexNotifier.value = clamped;
  appTextSizeUsesSystemNotifier.value = false;
  appCustomTextScalerNotifier.value =
      clamped == appCapturedSystemTextScaleIndex &&
          appCapturedSystemTextScaler != null
      ? appCapturedSystemTextScaler
      : resolveSkeddoTextScale(clamped);
}

int _textScaleProfileRequest = 0;
Future<void> _textScaleProfileQueue = Future<void>.value();

/// Serialize the full profile read, including the lightweight current-scale
/// probe. Lifecycle callbacks and the one-second poll can otherwise complete
/// out of order and publish an older profile after a newer one.
Future<void> _enqueueTextScaleProfileOperation(
  Future<void> Function() operation,
) {
  final next = _textScaleProfileQueue.then<void>(
    (_) => operation(),
    onError: (Object _, StackTrace __) => operation(),
  );
  _textScaleProfileQueue = next.catchError((Object _, StackTrace __) {});
  return next;
}

TextScaler? _parsePlatformScaler(
  Object? rawCurves,
  int index,
  List<double> probeSizes,
) {
  if (rawCurves is! List ||
      index >= rawCurves.length ||
      probeSizes.length < 2) {
    return null;
  }
  final curve = rawCurves[index];
  if (curve is! List || curve.length < probeSizes.length) return null;
  final ratios = <double>[];
  for (var i = 0; i < probeSizes.length; i++) {
    final value = curve[i];
    if (value is! num || !value.isFinite || value <= 0) return null;
    ratios.add(value.toDouble());
  }
  return _SampledPlatformTextScaler(
    List<double>.unmodifiable(probeSizes),
    List<double>.unmodifiable(ratios),
  );
}

/// Cheaply detect an OS text-size change without transferring the full native
/// curve profile. This matters in Android split-screen/floating-window and iPad
/// Split View/Slide Over, where SKEDDO can remain resumed while its host window's
/// text-size traits change.
Future<void> refreshDeviceTextScaleProfileIfChanged() async {
  return _enqueueTextScaleProfileOperation(() async {
    try {
      final current = await _textScaleChannel.invokeMethod<num>(
        'getCurrentScale',
      );
      if (current != null &&
          current.isFinite &&
          current.toDouble() != appSystemTextScaleNotifier.value) {
        await _loadDeviceTextScaleProfile();
      }
    } on PlatformException {
      // The existing Flutter MediaQuery fallback remains authoritative.
    } on MissingPluginException {
      // Web and older binaries do not have the native profile channel.
    }
  });
}

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
const _kTextSizeModeKey = 'app_text_size_mode';
const _kTextSizeIndexKey = 'app_text_size_index';
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

  // Text size. New installs and missing mode data default to System.
  final textSizeMode = prefs.getString(_kTextSizeModeKey);
  if (textSizeMode != null) {
    appTextSizeUsesSystemNotifier.value = textSizeMode != 'custom';
  }
  final textSizeIndex = prefs.getInt(_kTextSizeIndexKey);
  if (textSizeIndex != null) {
    appTextSizeIndexNotifier.value = textSizeIndex.clamp(0, 6);
  }

  // Migrate the previous three-option setting for existing installations.
  final textSize = prefs.getString(_kTextSizeKey);
  if (textSizeMode == null && textSize != null) {
    appTextSizeUsesSystemNotifier.value = textSize == 'Default';
    appTextSizeIndexNotifier.value = switch (textSize) {
      'Compact' => 1,
      'Large' => 5,
      _ => 3,
    };
  }

  // Resolve a persisted Custom choice once against the profile loaded before
  // settings. Later native-profile refreshes must not replace this scaler.
  if (!appTextSizeUsesSystemNotifier.value) {
    appCustomTextScalerNotifier.value = resolveSkeddoTextScale(
      appTextSizeIndexNotifier.value,
    );
  }

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
    final range = kLiquidGlassMaximumOpacity - kLiquidGlassMinimumOpacity;
    final normalized =
        ((liquidGlassOpacity - kLiquidGlassMinimumOpacity) / range).clamp(
          0.0,
          1.0,
        );
    appLiquidGlassOpacityNotifier.value =
        kLiquidGlassMinimumOpacity + normalized * range;
  }
  AIServices.setDateLocalePreference(appDateLocaleNotifier.value);
}

/// Persist a single settings key.  All callers go through here so the key list
/// stays in one place.
Future<void> saveAppSetting(String routeTitle, String value) {
  final mode = appTextSizeUsesSystemNotifier.value ? 'system' : 'custom';
  final index = appTextSizeIndexNotifier.value;
  final next = _settingsWriteQueue.then<void>((_) async {
    final prefs = await SharedPreferences.getInstance();
    switch (routeTitle) {
      case 'Theme':
        await prefs.setString(_kThemeKey, value);
      case 'Text Size':
        await prefs.setString(_kTextSizeKey, value);
        await prefs.setString(_kTextSizeModeKey, mode);
        await prefs.setInt(_kTextSizeIndexKey, index);
      case 'Start of Week':
        await prefs.setString(_kStartOfWeekKey, value);
      case 'Default View':
        await prefs.setString(_kDefaultViewKey, value);
      case 'Default Event Duration':
        await prefs.setString(_kEventDurationKey, value);
      case 'Date Format':
        await prefs.setString(
          _kDateLocaleKey,
          appDateLocaleNotifier.value.name,
        );
      case 'Liquid Glass':
        await prefs.setDouble(
          _kLiquidGlassOpacityKey,
          appLiquidGlassOpacityNotifier.value,
        );
    }
  });
  _settingsWriteQueue = next.catchError((Object _, StackTrace __) {});
  return next;
}

Future<void> _settingsWriteQueue = Future<void>.value();

/// Persist the accent-color index.
void saveAccentIndex(int index) {
  SharedPreferences.getInstance().then(
    (p) => p.setInt(_kAccentIndexKey, index),
  );
}
