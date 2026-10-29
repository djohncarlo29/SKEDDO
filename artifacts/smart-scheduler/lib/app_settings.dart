import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ai/ai_services.dart';
import 'ai/parsed_date.dart';
import 'services/local_storage.dart';

// ══════════════════════════════════════════════════════════════════════════════
// App-level appearance settings — module-level notifiers that are written by
// SettingsPanel and read by SKEDDOApp to rebuild CupertinoApp reactively.
//
//   appBrightnessNotifier    — null = follow system, light/dark = override.
//   appTextSizeUsesSystemNotifier — true when text follows the phone OS.
//   appTextSizeIndexNotifier — custom SKEDDO text-size position (0–6).
//   appStartOfWeekNotifier   — the effective first weekday, Sunday through
//                              Saturday.
//   appStartOfWeekUsesSystemNotifier — whether the weekday follows the OS.
//   appDefaultViewNotifier   — 'Day' | 'Week' | 'Month' | 'Year'.
//   appEventDurationNotifier — '15 minutes' | '30 minutes' | '1 hour' | '2 hours'.
//   appDateLocaleNotifier    — monthFirst or dayFirst for ambiguous numeric dates.
//   appDateFormatNotifier    — the app-wide date display format.
//   appLiquidGlassOpacityNotifier — 0.2..0.8 material opacity for Liquid Glass
//     controls, including the floating tab bar and AppShell menu button. Its
//     slider position is quantized to whole percentage points.
// ══════════════════════════════════════════════════════════════════════════════

/// Brightness override applied to CupertinoThemeData.
/// null → CupertinoApp follows MediaQuery.platformBrightness (system mode).
final ValueNotifier<Brightness?> appBrightnessNotifier =
    ValueNotifier<Brightness?>(null);

/// The operating system brightness, independent of SKEDDO's optional theme
/// override. The app root keeps this synchronized with PlatformDispatcher.
final ValueNotifier<Brightness> appSystemBrightnessNotifier =
    ValueNotifier<Brightness>(Brightness.light);

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

/// Calendar weekday names use a stable Sunday-first index: Sunday = 0,
/// Saturday = 6. The effective app value is kept separately from the system
/// value so a custom choice does not overwrite the mirrored OS setting.
const List<String> kFirstDayOfWeekOptions = <String>[
  'Sunday',
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
];

final ValueNotifier<String> appSystemFirstDayOfWeekNotifier =
    ValueNotifier<String>('Sunday');
final ValueNotifier<bool> appStartOfWeekUsesSystemNotifier =
    ValueNotifier<bool>(true);
final ValueNotifier<String> appStartOfWeekNotifier =
    ValueNotifier<String>('Sunday');

/// Standard trailing value for settings that can mirror the operating system.
/// Keep "System" visible in the parent Settings list while the mirrored option
/// is selected; show the app-only value otherwise.
String mirrorSystemSettingTrailingValue({
  required bool usesSystem,
  required String appOnlyValue,
}) => usesSystem ? 'System' : appOnlyValue;

int firstDayOfWeekIndexForName(String name) {
  final index = kFirstDayOfWeekOptions.indexOf(name);
  return index < 0 ? 0 : index;
}

String firstDayOfWeekNameForIndex(int index) =>
    kFirstDayOfWeekOptions[index.clamp(0, 6).toInt()];

/// Returns the date's column in a calendar whose first column is [firstDay].
/// DateTime.weekday is Monday-first; the app's persisted choices are Sunday-
/// first, so convert both to the same 0–6 indexing before subtracting.
int calendarWeekdayColumnForDate(
  DateTime date, {
  String? firstDay,
}) {
  final startIndex = firstDayOfWeekIndexForName(
    firstDay ?? appStartOfWeekNotifier.value,
  );
  final sundayFirstDateIndex = date.weekday % 7;
  return (sundayFirstDateIndex - startIndex + 7) % 7;
}

int calendarMonthStartOffset(
  int year,
  int month, {
  String? firstDay,
}) => calendarWeekdayColumnForDate(DateTime(year, month, 1), firstDay: firstDay);

List<String> calendarWeekdayHeaderLetters({String? firstDay}) {
  const sundayFirstLetters = <String>['S', 'M', 'T', 'W', 'T', 'F', 'S'];
  final startIndex = firstDayOfWeekIndexForName(
    firstDay ?? appStartOfWeekNotifier.value,
  );
  return List<String>.generate(
    7,
    (index) => sundayFirstLetters[(startIndex + index) % 7],
    growable: false,
  );
}

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
appSkeddoTextScaleMappingNotifier = ValueNotifier<List<SkeddoTextScaleMapping>>(
  const <SkeddoTextScaleMapping>[],
);

/// Frozen scaler selected for the active Custom setting. Native profile
/// refreshes never replace this value; only an explicit Custom selection does.
final ValueNotifier<TextScaler?> appCustomTextScalerNotifier =
    ValueNotifier<TextScaler?>(null);

const _textScaleChannel = MethodChannel('com.smartscheduler/text_scale');
const _systemCalendarChannel = MethodChannel(
  'com.smartscheduler/system_calendar',
);

/// Refreshes the device's preferred first weekday. Native platforms read the
/// OS calendar/locale preference; web and older native binaries keep the
/// initialized locale-safe fallback.
Future<void> refreshSystemFirstDayOfWeek() async {
  try {
    final index = await _systemCalendarChannel.invokeMethod<int>(
      'getFirstDayOfWeekIndex',
    );
    if (index == null || index < 0 || index > 6) return;

    final systemDay = firstDayOfWeekNameForIndex(index);
    if (appSystemFirstDayOfWeekNotifier.value != systemDay) {
      appSystemFirstDayOfWeekNotifier.value = systemDay;
    }
    if (appStartOfWeekUsesSystemNotifier.value &&
        appStartOfWeekNotifier.value != systemDay) {
      appStartOfWeekNotifier.value = systemDay;
    }
  } on MissingPluginException {
    // The web preview and older native binaries do not expose this bridge.
  } on PlatformException {
    // Keep the last known value if the OS query is temporarily unavailable.
  }
}

/// Diagnostic-only read of the complete native profile payload. This does not
/// modify any text-size notifier or the ambient MediaQuery.
Future<Map<Object?, Object?>?> fetchTextScaleDiagnosticProfile() {
  return _textScaleChannel.invokeMethod<Map<Object?, Object?>>(
    'getDiagnosticProfile',
  );
}

/// Whether the native profile was loaded successfully. When true, the native
/// currentScale is authoritative; Flutter's MediaQuery value is only a
/// fallback for web and older binaries without this bridge.
bool appHasNativeTextScaleProfile = false;

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

_SampledPlatformTextScaler _extrapolatePlatformScaler(
  _SampledPlatformTextScaler previous,
  _SampledPlatformTextScaler last,
  int steps,
) {
  final ratios = <double>[
    for (var i = 0; i < last._ratios.length; i++)
      last._ratios[i] + (last._ratios[i] - previous._ratios[i]) * steps,
  ];
  return _SampledPlatformTextScaler(last._probeSizes, ratios);
}

List<double> get appSkeddoTextScaleStops =>
    appSkeddoTextScaleStopsNotifier.value;

double skeddoTextScaleForIndex(int index) =>
    appSkeddoTextScaleStops[index.clamp(0, appSkeddoTextScaleStops.length - 1)];

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
  // Web has no native scale-profile channel; Flutter's MediaQuery scaler is
  // already the authoritative fallback, so do not wait on a channel handshake
  // before the first frame.
  if (kIsWeb) return Future<void>.value();
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
        NativeTextScaleStop(scale: nativeStops[i], scaler: nativeScalers[i]),
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
  if (nativeCount < 7) {
    final mappings = <SkeddoTextScaleMapping>[
      for (var index = 0; index < nativeCount; index++)
        SkeddoTextScaleMapping(
          scale: profile.stops[index].scale,
          kind: SkeddoTextScaleMappingKind.native,
          nativeIndex: index,
          scaler:
              profile.stops[index].scaler ??
              TextScaler.linear(profile.stops[index].scale),
        ),
    ];
    final lastScale = profile.stops[nativeCount - 1].scale;
    final previousScale = profile.stops[nativeCount - 2].scale;
    final scaleStep = lastScale - previousScale;
    final previousScaler = profile.stops[nativeCount - 2].scaler;
    final lastScaler = profile.stops[nativeCount - 1].scaler;
    for (var index = nativeCount; index < 7; index++) {
      final steps = index - nativeCount + 1;
      final scale = lastScale + scaleStep * steps;
      final scaler =
          previousScaler is _SampledPlatformTextScaler &&
              lastScaler is _SampledPlatformTextScaler
          ? _extrapolatePlatformScaler(previousScaler, lastScaler, steps)
          : TextScaler.linear(scale);
      mappings.add(
        SkeddoTextScaleMapping(
          scale: scale,
          kind: SkeddoTextScaleMappingKind.extrapolated,
          nativeIndex: null,
          scaler: scaler,
        ),
      );
    }
    return mappings;
  }
  // SKEDDO exposes only the first seven native positions as Custom choices.
  // Do not compress a larger native profile into the seven-position control:
  // System mode still uses the complete native profile independently, while
  // Custom mode intentionally stops at native position seven.
  return List<SkeddoTextScaleMapping>.generate(7, (index) {
    final nativeStop = profile.stops[index];
    return SkeddoTextScaleMapping(
      scale: nativeStop.scale,
      kind: SkeddoTextScaleMappingKind.native,
      nativeIndex: index,
      // A missing platform curve is an explicit compatibility degradation,
      // but it is still captured in the mapping so Custom can freeze it.
      scaler: nativeStop.scaler ?? TextScaler.linear(nativeStop.scale),
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
  appCustomTextScalerNotifier.value = resolveSkeddoTextScale(clamped);
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

/// Whether the app accent follows the native system accent instead of the
/// selected SKEDDO-only swatch.
final ValueNotifier<bool> appAccentUsesSystemNotifier = ValueNotifier<bool>(
  false,
);

/// Calendar — which view to open when the Calendar tab is tapped.
final ValueNotifier<String> appDefaultViewNotifier = ValueNotifier<String>(
  'Month',
);

/// Calendar — whether the Month View header uses full month names.
final ValueNotifier<bool> appFullMonthNameNotifier = ValueNotifier<bool>(false);

/// Event creation — default duration pre-filled in the time picker.
final ValueNotifier<String> appEventDurationNotifier = ValueNotifier<String>(
  '1 hour',
);

/// Event creation and category recovery — category ID to use when no category
/// is explicitly selected.  Uncategorized is the default for new installs.
const String kDefaultCategoryFallbackId = 'sys-uncategorized';
final ValueNotifier<String> appDefaultCategoryNotifier = ValueNotifier<String>(
  kDefaultCategoryFallbackId,
);

/// Display name cached for the Settings main-list trailing.
final ValueNotifier<String> appDefaultCategoryLabelNotifier =
    ValueNotifier<String>('Uncategorized');

String get appDefaultCategoryId {
  final id = appDefaultCategoryNotifier.value;
  return id.isEmpty ? kDefaultCategoryFallbackId : id;
}

/// Parsing preference for ambiguous numeric dates such as 08/12/2026.
final ValueNotifier<DateLocalePreference> appDateLocaleNotifier =
    ValueNotifier<DateLocalePreference>(DateLocalePreference.monthFirst);

/// Date formats shown throughout the app. The sample values are also the
/// visible labels in Settings, so the selected format is always unambiguous.
enum AppDateFormat {
  dayMonthYearSlash('19/08/2026'),
  monthDayYearShortSlash('08/19/26'),
  dayMonthYearShortSlash('19/08/26'),
  monthDayYearSlash('08/19/2026'),
  dayMonthYearDot('19.08.2026'),
  dayMonthYearDash('19-08-2026'),
  yearMonthDaySlash('2026/08/19'),
  yearMonthDayDot('2026.08.19'),
  yearMonthDayDash('2026-08-19');

  const AppDateFormat(this.sample);

  final String sample;

  String format(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString().padLeft(4, '0');
    final shortYear = year.substring(year.length - 2);
    return switch (this) {
      AppDateFormat.dayMonthYearSlash => '$day/$month/$year',
      AppDateFormat.monthDayYearShortSlash => '$month/$day/$shortYear',
      AppDateFormat.dayMonthYearShortSlash => '$day/$month/$shortYear',
      AppDateFormat.monthDayYearSlash => '$month/$day/$year',
      AppDateFormat.dayMonthYearDot => '$day.$month.$year',
      AppDateFormat.dayMonthYearDash => '$day-$month-$year',
      AppDateFormat.yearMonthDaySlash => '$year/$month/$day',
      AppDateFormat.yearMonthDayDot => '$year.$month.$day',
      AppDateFormat.yearMonthDayDash => '$year-$month-$day',
    };
  }

  bool get _isDayFirst =>
      parserLocalePreference == DateLocalePreference.dayFirst;

  String formatMedium(DateTime date, {bool includeYear = true}) {
    final month = _kDateFormatMonthAbbreviations[date.month - 1];
    final day = date.day.toString();
    final year = date.year.toString();
    if (_isDayFirst) {
      return includeYear ? '$day $month $year' : '$day $month';
    }
    return includeYear ? '$month $day, $year' : '$month $day';
  }

  String formatLong(DateTime date) {
    final month = _kDateFormatMonthNames[date.month - 1];
    final day = date.day.toString();
    final year = date.year.toString();
    return _isDayFirst ? '$day $month $year' : '$month $day, $year';
  }

  String formatFull(DateTime date) {
    final weekday = _kDateFormatWeekdayNames[date.weekday - 1];
    return '$weekday, ${formatLong(date)}';
  }

  String get contextFooter {
    final exampleDate = DateTime(2026, 8, 19);
    return 'Format Example:\n'
        '• Short: $sample\n'
        '• Medium: ${formatMedium(exampleDate)}\n'
        '• Long: ${formatLong(exampleDate)}\n'
        '• Full: ${formatFull(exampleDate)}';
  }

  /// Keep the AI parser's existing ambiguity behavior aligned with formats
  /// that put the day before the month. Year-first display formats retain the
  /// app's established month-first parsing fallback.
  DateLocalePreference get parserLocalePreference => switch (this) {
    AppDateFormat.dayMonthYearSlash ||
    AppDateFormat.dayMonthYearShortSlash ||
    AppDateFormat.dayMonthYearDot ||
    AppDateFormat.dayMonthYearDash => DateLocalePreference.dayFirst,
    _ => DateLocalePreference.monthFirst,
  };

  static AppDateFormat? fromName(String? name) {
    for (final format in AppDateFormat.values) {
      if (format.name == name) return format;
    }
    return null;
  }

  static AppDateFormat? fromSample(String sample) {
    for (final format in AppDateFormat.values) {
      if (format.sample == sample) return format;
    }
    return null;
  }
}

const _kDateFormatMonthAbbreviations = <String>[
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

const _kDateFormatMonthNames = <String>[
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

const _kDateFormatWeekdayNames = <String>[
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];

/// New installs and legacy Date Format settings use MM/DD/YYYY for this test.
final ValueNotifier<AppDateFormat> appDateFormatNotifier =
    ValueNotifier<AppDateFormat>(AppDateFormat.monthDayYearSlash);

String formatAppDate(DateTime date, {AppDateFormat? format}) =>
    (format ?? appDateFormatNotifier.value).format(date);

String formatAppDateMedium(
  DateTime date, {
  bool includeYear = true,
  AppDateFormat? format,
}) => (format ?? appDateFormatNotifier.value).formatMedium(
  date,
  includeYear: includeYear,
);

/// Formats a persisted/event-source date for display without changing its
/// stored representation. Supports the app's legacy month-name strings, ISO
/// dates, and numeric dates imported from outside the app.
String formatStoredAppDate(String raw, {DateTime? resolvedDate}) {
  final date = resolvedDate ?? _parseStoredAppDate(raw);
  return date == null ? raw : formatAppDate(date);
}

DateTime? _parseStoredAppDate(String raw) {
  final value = raw.trim();
  if (value.isEmpty) return null;

  final iso = DateTime.tryParse(value);
  if (iso != null) return iso;

  const months = <String, int>{
    'jan': 1,
    'january': 1,
    'feb': 2,
    'february': 2,
    'mar': 3,
    'march': 3,
    'apr': 4,
    'april': 4,
    'may': 5,
    'jun': 6,
    'june': 6,
    'jul': 7,
    'july': 7,
    'aug': 8,
    'august': 8,
    'sep': 9,
    'sept': 9,
    'september': 9,
    'oct': 10,
    'october': 10,
    'nov': 11,
    'november': 11,
    'dec': 12,
    'december': 12,
  };
  final namedDate = RegExp(
    r'^([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{2,4})$',
  ).firstMatch(value);
  if (namedDate != null) {
    final month = months[namedDate.group(1)!.toLowerCase()];
    final day = int.tryParse(namedDate.group(2)!);
    final year = _expandDateYear(namedDate.group(3)!);
    if (month != null && day != null && year != null) {
      return _validDate(year, month, day);
    }
  }

  final numericDate = RegExp(
    r'^(\d{1,4})[./-](\d{1,2})[./-](\d{1,4})$',
  ).firstMatch(value);
  if (numericDate == null) return null;
  final first = numericDate.group(1)!;
  final second = numericDate.group(2)!;
  final third = numericDate.group(3)!;
  final int year;
  final int month;
  final int day;
  if (first.length == 4) {
    year = int.parse(first);
    month = int.parse(second);
    day = int.parse(third);
  } else {
    year = _expandDateYear(third) ?? 0;
    if (appDateFormatNotifier.value.parserLocalePreference ==
        DateLocalePreference.dayFirst) {
      day = int.parse(first);
      month = int.parse(second);
    } else {
      month = int.parse(first);
      day = int.parse(second);
    }
  }
  return year == 0 ? null : _validDate(year, month, day);
}

int? _expandDateYear(String digits) {
  final year = int.tryParse(digits);
  if (year == null) return null;
  if (digits.length >= 3) return year;
  return year >= 70 ? 1900 + year : 2000 + year;
}

DateTime? _validDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  final date = DateTime(year, month, day);
  if (date.year != year || date.month != month || date.day != day) return null;
  return date;
}

/// Minimum material opacity used by the Liquid Glass control.
///
/// The Appearance slider maps its user-facing 0–100% range to 0.2–0.8
/// material opacity so both extremes remain translucent and glass-like.
const double kLiquidGlassMinimumOpacity = 0.2;

/// Maximum material opacity used by the Liquid Glass control.
const double kLiquidGlassMaximumOpacity = 0.8;

/// New installs begin at the midpoint of the Liquid Glass slider.
const double kDefaultLiquidGlassSliderPosition = 0.5;

/// Persisted Liquid Glass slider value in the legacy 0.2–0.8 range.
final ValueNotifier<double> appLiquidGlassOpacityNotifier =
    ValueNotifier<double>(
      liquidGlassOpacityForSliderPosition(kDefaultLiquidGlassSliderPosition),
    );

/// Converts the material opacity to the Liquid Glass slider's whole-percent
/// position in the 0–1 range.
double liquidGlassSliderPositionForOpacity(double opacity) {
  final range = kLiquidGlassMaximumOpacity - kLiquidGlassMinimumOpacity;
  final normalized = ((opacity - kLiquidGlassMinimumOpacity) / range).clamp(
    0.0,
    1.0,
  );
  return quantizeLiquidGlassSliderPosition(normalized.toDouble());
}

/// Keeps Liquid Glass slider values at whole percentage points without adding
/// visible or tactile snap stops while the thumb is being dragged.
double quantizeLiquidGlassSliderPosition(double position) {
  return (position.clamp(0.0, 1.0) * 100).round() / 100.0;
}

/// Settles to whole percentages, with a small release-only detent at 50%.
///
/// The continuous drag path stays unchanged. Values that would otherwise
/// settle from 48% through 52% are pulled onto the midpoint step.
double settleLiquidGlassSliderPosition(double position) {
  final quantized = quantizeLiquidGlassSliderPosition(position);
  final percent = (quantized * 100).round();
  return (percent - 50).abs() <= 2 ? 0.5 : quantized;
}

/// Converts a slider position to the persisted 0.2–0.8 material opacity,
/// settling to a whole percentage point.
double liquidGlassOpacityForSliderPosition(double position) {
  final normalized = quantizeLiquidGlassSliderPosition(position);
  return kLiquidGlassMinimumOpacity +
      normalized * (kLiquidGlassMaximumOpacity - kLiquidGlassMinimumOpacity);
}

// ── SharedPreferences keys ────────────────────────────────────────────────────
const _kThemeKey = 'app_theme';
const _kTextSizeKey = 'app_text_size';
const _kTextSizeModeKey = 'app_text_size_mode';
const _kTextSizeIndexKey = 'app_text_size_index';
const _kAccentIndexKey = 'app_accent_index';
const _kAccentUsesSystemKey = 'app_accent_uses_system';
const _kStartOfWeekKey = 'app_start_of_week';
const _kStartOfWeekModeKey = 'app_start_of_week_mode';
const _kDefaultViewKey = 'app_default_view';
const _kFullMonthNameKey = 'app_full_month_name';
const _kEventDurationKey = 'app_event_duration';
const _kDefaultCategoryKey = 'app_default_category';
const _kDateLocaleKey = 'app_date_locale';
const _kDateFormatKey = 'app_date_format';
const _kLiquidGlassOpacityKey = 'app_liquid_glass_opacity';
const _kPersistedUserCategoriesKey = 'events_user_categories';
const _kPersistedPinnedCategoriesKey = 'events_pinned_categories';

/// Load all persisted settings from SharedPreferences and update notifiers.
/// Call this once at startup (before [runApp]) so the first build reflects the
/// saved state.
Future<void> loadAppSettings() async {
  await LocalStorage.instance.initialize();
  final prefs = await SharedPreferences.getInstance();
  await refreshSystemFirstDayOfWeek();

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
  appAccentUsesSystemNotifier.value =
      prefs.getBool(_kAccentUsesSystemKey) ?? false;

  // New installations mirror the system's first weekday. Values saved by
  // older versions are treated as explicit app-only choices during migration.
  final startOfWeek = prefs.getString(_kStartOfWeekKey);
  final startOfWeekMode = prefs.getString(_kStartOfWeekModeKey);
  final hasValidSavedDay =
      startOfWeek != null && kFirstDayOfWeekOptions.contains(startOfWeek);
  final useSystemStartOfWeek =
      startOfWeekMode == 'system' ||
      (startOfWeekMode == null && !hasValidSavedDay) ||
      (startOfWeekMode == 'custom' && !hasValidSavedDay);
  appStartOfWeekUsesSystemNotifier.value = useSystemStartOfWeek;
  if (useSystemStartOfWeek) {
    appStartOfWeekNotifier.value = appSystemFirstDayOfWeekNotifier.value;
  } else if (hasValidSavedDay) {
    appStartOfWeekNotifier.value = startOfWeek;
  }

  final defaultView = prefs.getString(_kDefaultViewKey);
  if (defaultView != null) appDefaultViewNotifier.value = defaultView;

  final fullMonthName = prefs.getBool(_kFullMonthNameKey);
  if (fullMonthName != null) {
    appFullMonthNameNotifier.value = fullMonthName;
  }

  final eventDuration = prefs.getString(_kEventDurationKey);
  if (eventDuration != null) appEventDurationNotifier.value = eventDuration;

  final defaultCategory = prefs.getString(_kDefaultCategoryKey);
  if (defaultCategory != null && defaultCategory.isNotEmpty) {
    appDefaultCategoryNotifier.value = defaultCategory;
  }
  // Resolve the cached label before the first Settings build. Category records
  // are owned by EventsTab, but their lightweight persisted JSON is shared.
  final savedUserCategories = await LocalStorage.instance.loadContentStringList(
    _kPersistedUserCategoriesKey,
  );
  final savedPinnedCategories = await LocalStorage.instance
      .loadContentStringList(_kPersistedPinnedCategoriesKey);
  final savedCategories = [...?savedUserCategories, ...?savedPinnedCategories];
  for (final raw in savedCategories) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map &&
          decoded['id']?.toString() == appDefaultCategoryNotifier.value) {
        final name = decoded['name']?.toString().trim();
        if (name != null && name.isNotEmpty) {
          appDefaultCategoryLabelNotifier.value = name;
        }
        break;
      }
    } catch (_) {
      // A malformed category record should not block other app settings.
    }
  }

  appDateFormatNotifier.value =
      AppDateFormat.fromName(prefs.getString(_kDateFormatKey)) ??
      AppDateFormat.monthDayYearSlash;
  appDateLocaleNotifier.value =
      appDateFormatNotifier.value.parserLocalePreference;

  final liquidGlassOpacity = prefs.getDouble(_kLiquidGlassOpacityKey);
  if (liquidGlassOpacity != null) {
    appLiquidGlassOpacityNotifier.value = liquidGlassOpacityForSliderPosition(
      liquidGlassSliderPositionForOpacity(liquidGlassOpacity),
    );
  }
  AIServices.setDateLocalePreference(appDateLocaleNotifier.value);
}

/// Persist a single settings key.  All callers go through here so the key list
/// stays in one place.
Future<void> saveAppSetting(String routeTitle, String value) {
  final mode = appTextSizeUsesSystemNotifier.value ? 'system' : 'custom';
  final index = appTextSizeIndexNotifier.value;
  final dateLocale = appDateLocaleNotifier.value.name;
  final dateFormat = appDateFormatNotifier.value.name;
  final startOfWeekMode = appStartOfWeekUsesSystemNotifier.value
      ? 'system'
      : 'custom';
  final next = _settingsWriteQueue.then<void>((_) async {
    final prefs = await SharedPreferences.getInstance();
    switch (routeTitle) {
      case 'Theme':
        await prefs.setString(_kThemeKey, value);
      case 'Text Size':
        await prefs.setString(_kTextSizeKey, value);
        await prefs.setString(_kTextSizeModeKey, mode);
        await prefs.setInt(_kTextSizeIndexKey, index);
      case 'First Day of Week':
        await prefs.setString(_kStartOfWeekKey, value);
        await prefs.setString(_kStartOfWeekModeKey, startOfWeekMode);
      case 'Default View':
        await prefs.setString(_kDefaultViewKey, value);
      case 'Full Month Name':
        await prefs.setBool(_kFullMonthNameKey, value == 'true');
      case 'Default Event Duration':
        await prefs.setString(_kEventDurationKey, value);
      case 'Default Category':
        await prefs.setString(
          _kDefaultCategoryKey,
          appDefaultCategoryNotifier.value,
        );
      case 'Date Format':
        await prefs.setString(_kDateLocaleKey, dateLocale);
        await prefs.setString(_kDateFormatKey, dateFormat);
      case 'Liquid Glass':
        final opacity = double.tryParse(value);
        if (opacity != null && opacity.isFinite) {
          await prefs.setDouble(
            _kLiquidGlassOpacityKey,
            opacity
                .clamp(kLiquidGlassMinimumOpacity, kLiquidGlassMaximumOpacity)
                .toDouble(),
          );
        }
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

/// Persist whether the system accent is active.
void saveAccentUsesSystem(bool usesSystem) {
  SharedPreferences.getInstance().then(
    (p) => p.setBool(_kAccentUsesSystemKey, usesSystem),
  );
}
