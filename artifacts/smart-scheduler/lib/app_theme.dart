import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

const kAccentColor = CupertinoDynamicColor.withBrightness(
  color: Color(0xFF007AFF),
  darkColor: Color(0xFF0A84FF),
);
const kBackgroundColor = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFF2F2F7),
  darkColor: Color(0xFF000000),
);
// Background painted behind the receding Navigator stack while an
// "Add Category" CupertinoSheetRoute is open (see main.dart's CupertinoApp
// builder). Deliberately separate from kBackgroundColor — this is the
// furthest-back layer visible around/behind the scaled-down previous page.
const kAddCategorySheetBackground = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFCBCBCB),
  darkColor: Color(0xFF000000),
);
const kCardColor = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFDFDFD),
  darkColor: Color(0xFF1C1C1E),
);
// Floating AppShell tab pill geometry.  Keep these values in the shared theme
// so its position and the content clearance stay in lock-step.
const double kFloatingTabBarHorizontalMargin = 16.0;
const double kFloatingTabBarBottomSpacing = 8.0;
const double kFloatingTabBarHeight = 64.0;
const double kFloatingTabBarCornerRadius = 32.0;
const double kFloatingTabBarSafetyMargin = 12.0;
const kSbSurface = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFDFDFD),
  darkColor: Color(0xFF1C1C1E),
);
// Dedicated surface for the microphone-permission glyph circle.  It is
// intentionally distinct from the sheet surface so the microphone remains
// legible against the frosted card in both appearances.
const kMicPermissionCircle = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFF0F0F5),
  darkColor: Color(0xFF48484A),
);

// ── Modal sheet colours ───────────────────────────────────────────────────────
// These are intentionally separate from kBackgroundColor / kSbSurface.
// In light mode they are identical to their app-level counterparts; in dark
// mode they follow the iOS grouped-inset-list hierarchy:
//   background  → systemGroupedBackground  (0xFF1C1C1E)
//   card / cell → secondarySystemGroupedBackground (0xFF2C2C2E)
const kModalBackground = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFF2F2F7),
  darkColor: Color(0xFF1C1C1E),
);
const kModalCard = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFDFDFD),
  darkColor: Color(0xFF2C2C2E),
);
const kModalButtonBackground = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFF0F0F5),
  darkColor: Color(0xFF3A3A3C),
);
const kModalHandleColor = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFD1D1D6),
  darkColor: Color(0xFF636366),
);

// Shared halo weight for every gel-bloom Xmark, checkmark, and right-chevron.
// This is the established weight used by the search cancel button.
const double kGelBloomIconWeight = 0.4;

const kPreviewCardBackground = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFF9F9FB),
  darkColor: Color(0xFF2C2C2E),
);
const kPreviewCardBorder = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFE5E5EA),
  darkColor: Color(0xFF48484A),
);
const kAttachmentBorder = CupertinoDynamicColor.withBrightness(
  color: Color(0x14000000),
  darkColor: Color(0x1AFFFFFF),
);
const kAttachmentShadow = CupertinoDynamicColor.withBrightness(
  color: Color(0x26000000),
  darkColor: Color(0x00000000),
);
const kAttachmentMenuOverlay = CupertinoDynamicColor.withBrightness(
  color: Color(0xC7FFFFFF),
  darkColor: Color(0xC71C1C1E),
);
const kAttachmentPreviewBackground = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFF2F2F7),
  darkColor: Color(0xFF000000),
);
const kIconPickerBackground = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFEEEEF0),
  darkColor: Color(0xFF3A3A3C),
);
const kImportOverlayScrim = CupertinoDynamicColor.withBrightness(
  color: Color(0x55000000),
  darkColor: Color(0x66000000),
);
const kImportOverlayShadow = CupertinoDynamicColor.withBrightness(
  color: Color(0x33000000),
  darkColor: Color(0x66000000),
);
const kGlassFillColor = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFFFFFF),
  darkColor: Color(0xFF1C1C1E),
);
const kPrimaryLabel = CupertinoDynamicColor.withBrightness(
  color: Color(0xFF1D1D1F),
  darkColor: Color(0xFFFDFDFD),
);

/// Resolves one of the app's semantic colours against the brightness inherited
/// by the current widget tree.  Custom-painted widgets do not all resolve
/// CupertinoDynamicColor automatically, so every custom surface/text style
/// should use this helper at its build boundary.
Color resolveThemeColor(Color color, BuildContext context) =>
    CupertinoDynamicColor.resolve(color, context);

/// Resolves a semantic colour embedded in a [TextStyle].
///
/// Platform-backed inputs and custom sheet content do not consistently resolve
/// CupertinoDynamicColor values themselves, so resolve them at the build
/// boundary before handing the style to those widgets.
TextStyle resolveThemeTextStyle(TextStyle style, BuildContext context) =>
    style.color == null
    ? style
    : style.copyWith(color: resolveThemeColor(style.color!, context));

/// Resolves semantic colours inside a custom shadow list.
List<BoxShadow> resolveThemeShadows(
  List<BoxShadow> shadows,
  BuildContext context,
) => CupertinoTheme.brightnessOf(context) == Brightness.dark
    ? const <BoxShadow>[]
    : shadows
          .map(
            (shadow) => shadow.copyWith(
              color: resolveThemeColor(shadow.color, context),
            ),
          )
          .toList(growable: false);

/// Resolves text glyph shadows while respecting the app-wide shadow policy.
/// Text shadows are only used for light-mode visual weight; Dark Mode has none.
List<Shadow> resolveThemeTextShadows(
  List<Shadow> shadows,
  BuildContext context,
) => CupertinoTheme.brightnessOf(context) == Brightness.dark
    ? const <Shadow>[]
    : shadows
          .map(
            (shadow) => Shadow(
              color: resolveThemeColor(shadow.color, context),
              offset: shadow.offset,
              blurRadius: shadow.blurRadius,
            ),
          )
          .toList(growable: false);

// ── Shadow colours (transparent in Dark Mode — no shadows needed) ─────────────
const kShadowBlack = CupertinoDynamicColor.withBrightness(
  color: Color(0xFF000000),
  darkColor: Color(0x00000000),
);
const kTabBarShadowColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x18000000),
  darkColor: Color(0x00000000),
);
const kCardShadowColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x12000000),
  darkColor: Color(0x00000000),
);

const List<BoxShadow> kCardShadow = [
  BoxShadow(color: kCardShadowColor, blurRadius: 10, offset: Offset(0, 2)),
];

// ── iOS Human Interface Guidelines label colours ───────────────────────────────
const kSecondaryLabel = CupertinoDynamicColor.withBrightness(
  color: Color(0x993C3C43),
  darkColor: Color(0x99EBEBF5), // 60% dark-mode opacity
);
const kTertiaryLabel = CupertinoDynamicColor.withBrightness(
  color: Color(0x4C3C3C43), // #3C3C434D light
  darkColor: Color(0x66EBEBF5), // 40% dark-mode opacity
);

// ── Empty-state placeholder icon colour ───────────────────────────────────────
// Used for the large icon in every "No Events" / "No Results" placeholder
// (DCV, Calendar Day-List, Search).  Intentionally between kTertiaryLabel and
// kSecondaryLabel — visible enough to read, soft enough not to compete with
// real content.
const kEmptyStateIcon = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFA9A9AE), // #A9A9AE light
  darkColor: Color(0xFF707077), // #707077 dark
);

const kSeparatorColor = CupertinoDynamicColor.withBrightness(
  color: Color(0x493C3C43), // #3C3C4349 light
  darkColor: Color(0x99545458), // #54545899 dark
);

// ── Action Panel colours ──────────────────────────────────────────────────────
// Group-break and hairline separator use appearance-specific tones so they
// read at the same visual weight in both appearances.
const kActionPanelGroupBreak = CupertinoDynamicColor.withBrightness(
  color: Color(0x0A000000), // 4% black tint
  // The gap is an intentional recessed break between action groups. Black
  // tint keeps it visually below the glass panel floor in Dark Mode.
  darkColor: Color(0x40000000), // 25% black tint
);
const kActionPanelSeparator = CupertinoDynamicColor.withBrightness(
  color: Color(0x11000000), // 7% black tint
  // A cool gray tint stays visible against the dark glass surface without
  // becoming a bright rule.  Resolve this dynamic color at each panel's build
  // site so both full-size and picker mini-panels follow the active appearance.
  darkColor: Color(0x665C5C60), // visible dark-mode separator tone
);

// ── Category color-picker swatches ───────────────────────────────────────────
// Each swatch is a genuine dynamic color (own light/dark hex pair, not just a
// dimmed light color) so the Events tab's category dots, chips, and the
// color-picker card itself all shift correctly between appearances.
// The first 8 map to Apple's named system colors; the last 3 are custom
// brand colors with hand-picked dark-mode partners.
const kCatRed = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFF3B30), // systemRed
  darkColor: Color(0xFFFF453A),
);
const kCatOrange = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFF9500), // systemOrange
  darkColor: Color(0xFFFF9F0A),
);
const kCatYellow = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFFCC00), // systemYellow
  darkColor: Color(0xFFFFD60A),
);
const kCatGreen = CupertinoDynamicColor.withBrightness(
  color: Color(0xFF34C759), // systemGreen
  darkColor: Color(0xFF30D158),
);
const kCatTeal = CupertinoDynamicColor.withBrightness(
  color: Color(0xFF5AC8FA), // legacy systemTeal
  darkColor: Color(0xFF64D2FF),
);
// Reuses kAccentColor's exact light/dark pair (systemBlue) — the picker's
// "blue" swatch and the app's accent color are the same color.
const kCatBlue = kAccentColor;
const kCatIndigo = CupertinoDynamicColor.withBrightness(
  color: Color(0xFF5856D6), // systemIndigo
  darkColor: Color(0xFF5E5CE6),
);
const kCatPink = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFF2D55), // systemPink
  darkColor: Color(0xFFFF375F),
);
const kCatPurple = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFAF52DE), // systemPurple
  darkColor: Color(0xFFBF5AF2),
);
const kCatTan = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFA89968), // custom — not a system color
  darkColor: Color(0xFFC4B285),
);
const kCatSlate = CupertinoDynamicColor.withBrightness(
  color: Color(0xFF607D8B), // custom — not a system color
  darkColor: Color(0xFF98A2B3),
);
const kCatSand = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFD7C0AE), // custom — not a system color
  darkColor: Color(0xFFE8D5C3),
);

// Full palette in picker order (2 rows of 6) — kept as one list so the
// picker grid and the category-color resolver below stay in sync.
const kCategorySwatches = <Color>[
  kCatRed,
  kCatOrange,
  kCatYellow,
  kCatGreen,
  kCatTeal,
  kCatBlue,
  kCatIndigo,
  kCatPink,
  kCatPurple,
  kCatTan,
  kCatSlate,
  kCatSand,
];

// Same palette but strongly typed as CupertinoDynamicColor — used by main.dart
// to look up the chosen accent swatch from appAccentNotifier without a cast.
const kAccentSwatches = <CupertinoDynamicColor>[
  kCatRed,
  kCatOrange,
  kCatYellow,
  kCatGreen,
  kCatTeal,
  kCatBlue,
  kCatIndigo,
  kCatPink,
  kCatPurple,
  kCatTan,
  kCatSlate,
  kCatSand,
];

/// Categories persist their color as a plain ARGB int (see _UserCategory.
/// toJson/fromJson in events_tab.dart), which loses the dynamic light/dark
/// pairing. This maps a stored color back to its dynamic swatch by matching
/// the light-mode ARGB value, so saved categories still render correctly in
/// dark mode. Falls back to the plain stored color if it doesn't match any
/// swatch (e.g. data from a future custom-color picker).
///
/// Pass [currentAccent] (from [dynamicAccentColor]) so that a category whose
/// stored color matches the current accent's light-mode hex will follow the
/// accent when it changes — i.e. a "default blue" category automatically
/// becomes "default red" if the user picks red as the accent.
Color resolveCategorySwatch(
  Color stored, {
  CupertinoDynamicColor? currentAccent,
}) {
  // If stored matches the current accent's light-mode value it was created
  // with the default accent and should follow accent changes.
  if (currentAccent != null && stored.value == currentAccent.value) {
    return currentAccent;
  }
  for (final swatch in kCategorySwatches) {
    if (swatch.value == stored.value) return swatch;
  }
  return stored;
}

// ══════════════════════════════════════════════════════════════════════════════
// AppAccentColor — InheritedWidget that propagates the user's chosen accent
// colour swatch throughout the entire widget tree.
//
// Wrap the CupertinoApp builder's output with this (main.dart) and call
// [resolveAccentColor] anywhere in the tree to get the correctly resolved
// Color for the current brightness.
// ══════════════════════════════════════════════════════════════════════════════
class AppAccentColor extends InheritedWidget {
  const AppAccentColor({super.key, required this.accent, required super.child});

  /// The currently selected accent swatch (dynamic light/dark pair).
  final CupertinoDynamicColor accent;

  /// Nearest [AppAccentColor] ancestor, or null if none is in the tree.
  static AppAccentColor? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppAccentColor>();

  @override
  bool updateShouldNotify(AppAccentColor old) => accent != old.accent;
}

/// Resolves the app-level accent colour to a plain [Color] for the current
/// brightness.  Call this in any widget's [build] method instead of using
/// [kAccentColor] directly.  Falls back to [kAccentColor] if [AppAccentColor]
/// is not yet in the tree.
Color resolveAccentColor(BuildContext context) {
  final inherited = AppAccentColor.maybeOf(context);
  final swatch = inherited?.accent ?? kAccentColor;
  return CupertinoDynamicColor.resolve(swatch, context);
}

/// Returns the raw [CupertinoDynamicColor] swatch for the current accent.
/// Useful when you need the light/dark pair itself (e.g. for category-colour
/// comparisons via [resolveCategorySwatch]).
CupertinoDynamicColor dynamicAccentColor(BuildContext context) =>
    AppAccentColor.maybeOf(context)?.accent ?? kAccentColor;

/// Renders a stored category color for the current context.
///
/// Categories whose stored color value matches [kCatBlue] (the original app
/// default) follow the live accent so they update whenever the user changes
/// the accent.  All other colors are returned as-is (with any
/// [CupertinoDynamicColor] resolved for the current brightness).
///
/// Call this in every build method that renders a category circle or text
/// instead of reading [category.color] directly.
Color renderCategoryColor(Color stored, BuildContext context) {
  // kCatBlue == kAccentColor: the factory-default category color.  Any
  // category saved with this value was created with the default accent and
  // should track accent changes.
  if (stored.value == kCatBlue.value) return resolveAccentColor(context);
  if (stored is CupertinoDynamicColor) {
    return CupertinoDynamicColor.resolve(stored, context);
  }
  return stored;
}

// ── Search bar icons ────────────────────────────────────────────────────────
// The "circle x" clear-button icon that crossfades with the idle mic icon
// in the search bar once the field has text (see search_bar_widget.dart).
const kSearchClearCircleIcon = CupertinoIcons.clear_circled_solid;

// ── Pill background colour ────────────────────────────────────────────────────
// Used for date/time picker trigger pills and the Cancel import pill.
const kPillColor = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFEEEEEE),
  darkColor: Color(0xFF3E3E40),
);

// ── Shared shape constants ────────────────────────────────────────────────────
// Shared radius for every SquircleStadiumBorder.  The path clamps this only
// when the painted control is physically shorter than 48 px.
const double kSquircleStadiumRadius = 24.0;

// Shared cubic quarter used by both stadium controls and bounded card corners.
const double _kSharedSquircleCurveControl = 0.64;

// The search bar is the one intentionally smaller stadium: 40 px tall with
// 20 px corners.
const double kSearchBarCornerRadius = 20.0;

// Vertical breathing room between the standalone cards in event modal sheets.
// Search-result event tiles use the same rhythm.
const double kModalCardGap = 16.0;

// Legacy aliases used by asymmetric multi-row card shells. Keeping these
// aliases tied to the stadium token makes their visible outer corners match
// the single-row stadium controls while still allowing row-specific corners
// to collapse to zero during animated sections.
const double kCornerRadius = kSquircleStadiumRadius;
const double kCardCornerRadius = kSquircleStadiumRadius;

// Dedicated radius for the modal-sheet presentation (e.g. the Add Category
// sheet). Smaller than kCornerRadius so a full-height sheet doesn't look
// over-rounded — intentionally tighter than kCornerRadius without going
// all the way down to the system's default 12px.
const double kModalSheetCornerRadius = 80.0;

// ── SF Pro Dynamic Tracking ───────────────────────────────────────────────────
const kTracking10 = 0.12;
const kTracking16 = -0.32;
const kTracking17 = -0.43;

// CupertinoDatePicker's default 32 px item extent and 216 px barrel height
// are authored for the default text size. Keep both dimensions proportional
// to the active OS text scaler so larger date labels do not crowd or clip
// inside a fixed-height modal sheet.
const double kCupertinoDatePickerItemExtent = 32.0;
const double kCupertinoDatePickerHeight = 216.0;
const double kCupertinoDatePickerFontSize = 16.0;

double cupertinoDatePickerItemExtent(BuildContext context) {
  return MediaQuery.textScalerOf(context).scale(kCupertinoDatePickerItemExtent);
}

double cupertinoDatePickerHeight(BuildContext context) {
  return MediaQuery.textScalerOf(context).scale(kCupertinoDatePickerHeight);
}

double cupertinoDatePickerFontSize(BuildContext context) {
  return MediaQuery.textScalerOf(context).scale(kCupertinoDatePickerFontSize);
}

// Shared label-to-value separation for picker rows in modal sheets and
// value-bearing rows in Settings. Keep this spacer explicit so larger OS text
// scaling makes labels/value text wrap within their own areas instead of
// allowing the two columns to touch.
const double kLabelValueGap = 25.0;

// Flutter's line breaker can treat punctuation such as "/" as a valid break
// point. Chevron values should instead break only between words, so protect
// each whitespace-delimited token with invisible word joiners. The joiners do
// not change the rendered value, but keep strings such as "M/D/Y" together.
String smartWrapChevronValue(String value) {
  return value.splitMapJoin(
    RegExp(r'\s+'),
    onMatch: (match) => match.group(0)!,
    onNonMatch: (word) => word.runes.map(String.fromCharCode).join('\u2060'),
  );
}

class _WrappedTextMetrics {
  const _WrappedTextMetrics({required this.height, required this.lineCount});

  final double height;
  final int lineCount;
}

/// Lays out a label and its chevron value with a minimum, not fixed, gap.
///
/// The label and value are two flexible text blocks. When the pair cannot fit
/// on one line, the row tries the usable widths between their readable
/// minimums and chooses the allocation with the shortest resulting row. This
/// is intentionally a shared layout decision: a label may wrap to keep the
/// value from becoming needlessly tall, and vice versa.
class MinGapLabelValueRow extends StatelessWidget {
  const MinGapLabelValueRow({
    super.key,
    required this.label,
    required this.labelStyle,
    required this.value,
    required this.valueStyle,
    required this.trailing,
    this.trailingExtraWidth = 16.0,
    this.leading,
    this.leadingWidth = 0.0,
    this.leadingGap = 12.0,
    this.alignTrailing = true,
  });

  final String label;
  final TextStyle labelStyle;
  final String value;
  final TextStyle valueStyle;
  final Widget trailing;
  final double trailingExtraWidth;
  final Widget? leading;
  final double leadingWidth;
  final double leadingGap;
  final bool alignTrailing;

  double _singleLineWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  double _longestWordWidth(BuildContext context, String text, TextStyle style) {
    final words = text.split(RegExp(r'\s+')).where((word) => word.isNotEmpty);
    var longest = 0.0;
    for (final word in words) {
      longest = math.max(longest, _singleLineWidth(context, word, style));
    }
    return longest;
  }

  double _minimumReadableWidth(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final naturalWidth = _singleLineWidth(context, text, style);
    if (naturalWidth == 0) return 0;

    // Keep at least the widest word together whenever the row has enough
    // room. The small floor prevents short words from being squeezed into
    // narrow slivers that are technically measurable but hard to read.
    final widestWord = _longestWordWidth(context, text, style);
    return math.min(naturalWidth, math.max(36.0, widestWord));
  }

  bool _hasMultipleWords(String text) {
    return RegExp(r'\S+\s+\S').hasMatch(text.trim());
  }

  _WrappedTextMetrics _wrappedMetrics(
    BuildContext context,
    String text,
    TextStyle style,
    double maxWidth,
  ) {
    if (maxWidth <= 0) {
      return const _WrappedTextMetrics(
        height: double.infinity,
        lineCount: 999999,
      );
    }
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      textWidthBasis: TextWidthBasis.parent,
    )..layout(maxWidth: maxWidth);
    return _WrappedTextMetrics(
      height: painter.height,
      lineCount: painter.computeLineMetrics().length,
    );
  }

  Widget _animateRowHeight(Widget row) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.none,
      child: row,
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = _singleLineWidth(context, label, labelStyle);
        final wrappedValue = smartWrapChevronValue(value);
        final valueWidth =
            _singleLineWidth(context, wrappedValue, valueStyle) +
            trailingExtraWidth;
        final leadingTotal = leading == null ? 0.0 : leadingWidth + leadingGap;
        final fitsOnOneLine =
            constraints.maxWidth.isFinite &&
            leadingTotal + labelWidth + kLabelValueGap + valueWidth <=
                constraints.maxWidth;
        // Wrapping is a fallback only. Even when either block contains several
        // words, preserve the natural single-line layout whenever the complete
        // label/value/chevron group fits with the required minimum gap.
        //
        // Once wrapping is necessary, these known pairs have an intentional
        // fallback preference: "Category Type" / "Standard" and "Default
        // Event Duration" / "1 hour" or "2 hours" wrap the label only;
        // "Travel Time" / "1 hour, 30 minutes" keeps the label on one line
        // and wraps only the value; "Category Type" / "Shopping List" or
        // "Smart Category" and "Second Alert" / "1 hour, 30 minutes before"
        // wrap both blocks.
        final forceLabelOnlyWrap =
            !fitsOnOneLine &&
            ((label == 'Category Type' && value == 'Standard') ||
                (label == 'Default Event Duration' &&
                    (value == '1 hour' || value == '2 hours')));
        final forceValueOnlyWrap =
            !fitsOnOneLine &&
            label == 'Travel Time' &&
            value == '1 hour, 30 minutes';
        final forceSharedWrap =
            !fitsOnOneLine &&
            ((label == 'Category Type' &&
                    (value == 'Shopping List' || value == 'Smart Category')) ||
                (label == 'Second Alert' &&
                    value == '1 hour, 30 minutes before'));
        final labelCanWrap =
            forceLabelOnlyWrap ||
            forceSharedWrap ||
            (!fitsOnOneLine && !forceValueOnlyWrap && _hasMultipleWords(label));
        final valueCanWrap =
            forceValueOnlyWrap ||
            forceSharedWrap ||
            (!fitsOnOneLine &&
                !forceLabelOnlyWrap &&
                _hasMultipleWords(wrappedValue));

        if (fitsOnOneLine && !labelCanWrap && !valueCanWrap) {
          final row = Row(
            mainAxisSize: alignTrailing ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                SizedBox(width: leadingWidth, child: leading),
                SizedBox(width: leadingGap),
              ],
              SizedBox(
                width: labelWidth,
                child: Text(label, style: labelStyle, softWrap: false),
              ),
              if (alignTrailing)
                const Spacer()
              else
                const SizedBox(width: kLabelValueGap),
              SizedBox(width: valueWidth, child: trailing),
            ],
          );
          return _animateRowHeight(row);
        }

        // Both sides are flexible once the one-line layout no longer fits.
        // Leave the gap out of the search space, and reserve the trailing
        // group's non-text width from the value side.
        final availableAfterGap = math.max(
          0.0,
          constraints.maxWidth - leadingTotal - kLabelValueGap,
        );
        final minLabelWidth = _minimumReadableWidth(context, label, labelStyle);
        final minValueTextWidth = _minimumReadableWidth(
          context,
          wrappedValue,
          valueStyle,
        );
        final minValueSlot = math.min(
          availableAfterGap,
          trailingExtraWidth + minValueTextWidth,
        );
        final minLabelSlot = math.min(availableAfterGap, minLabelWidth);

        // The score makes row height the primary objective. If two allocations
        // have the same row height, prefer the one with less total text height;
        // this keeps a one-line label beside a two-line value when that is
        // already as short as a two-line/two-line arrangement.
        var bestLabelSlot = minLabelSlot;
        var bestValueSlot = math.max(0.0, availableAfterGap - bestLabelSlot);
        var bestTotalHeight = double.infinity;
        final maxLabelSlot = math.max(
          minLabelSlot,
          availableAfterGap - minValueSlot,
        );
        final searchStart = math.min(minLabelSlot, maxLabelSlot);
        final searchEnd = math.max(minLabelSlot, maxLabelSlot);

        final bothBlocksCanWrap =
            _hasMultipleWords(label) && _hasMultipleWords(wrappedValue);
        var bestMaxLines = 999999;
        var bestWrappedBlocks = double.infinity;
        var bestTotalLines = 999999;
        var sharedLabelSlot = 0.0;
        var sharedValueSlot = 0.0;
        var sharedMaxLines = 999999;
        var sharedTotalHeight = double.infinity;

        void considerAllocation(
          double candidateLabelSlot, {
          double? candidateValueSlot,
        }) {
          final labelSlot = candidateLabelSlot
              .clamp(0.0, availableAfterGap)
              .toDouble();
          final valueSlot =
              (candidateValueSlot ?? availableAfterGap - labelSlot)
                  .clamp(0.0, availableAfterGap)
                  .toDouble();
          final labelMetrics = _wrappedMetrics(
            context,
            label,
            labelStyle,
            labelSlot,
          );
          final valueMetrics = _wrappedMetrics(
            context,
            wrappedValue,
            valueStyle,
            math.max(0.0, valueSlot - trailingExtraWidth),
          );
          if ((!labelCanWrap && labelMetrics.lineCount > 1) ||
              (!valueCanWrap && valueMetrics.lineCount > 1) ||
              (labelCanWrap && labelMetrics.lineCount < 2) ||
              (valueCanWrap && valueMetrics.lineCount < 2)) {
            return;
          }
          final totalHeight = labelMetrics.height + valueMetrics.height;
          final maxLines = math.max(
            labelMetrics.lineCount,
            valueMetrics.lineCount,
          );
          final totalLines = labelMetrics.lineCount + valueMetrics.lineCount;
          final wrappedBlocks =
              (labelMetrics.lineCount > 1 ? 1 : 0) +
              (valueMetrics.lineCount > 1 ? 1 : 0);

          // When both text blocks have real break opportunities, remember the
          // best genuinely shared wrap separately. It is allowed to win over
          // a one-sided allocation when it keeps the row at the same maximum
          // line count, but only after the natural single-line layout has been
          // ruled out by the minimum-gap constraint. The explicit pair
          // preferences above are enforced by the line-count guards below.
          if (bothBlocksCanWrap &&
              labelMetrics.lineCount > 1 &&
              valueMetrics.lineCount > 1) {
            if (maxLines < sharedMaxLines ||
                (maxLines == sharedMaxLines &&
                    totalHeight < sharedTotalHeight)) {
              sharedLabelSlot = labelSlot;
              sharedValueSlot = valueSlot;
              sharedMaxLines = maxLines;
              sharedTotalHeight = totalHeight;
            }
          }

          const epsilon = 0.01;
          final isBetter =
              maxLines < bestMaxLines ||
              (maxLines == bestMaxLines &&
                  (totalHeight < bestTotalHeight - epsilon ||
                      (totalHeight - bestTotalHeight).abs() <= epsilon &&
                          (totalLines < bestTotalLines ||
                              (totalLines == bestTotalLines &&
                                  wrappedBlocks < bestWrappedBlocks))));
          if (isBetter) {
            bestLabelSlot = labelSlot;
            bestValueSlot = valueSlot;
            bestMaxLines = maxLines;
            bestTotalHeight = totalHeight;
            bestTotalLines = totalLines;
            bestWrappedBlocks = wrappedBlocks.toDouble();
          }
        }

        // Try the intended authored wrap widths first. If there is spare room,
        // the unused width becomes extra gap rather than widening a block back
        // to one line.
        final preferredLabelSlot = labelCanWrap
            ? math.max(minLabelSlot, (labelWidth + minLabelSlot) / 2.0)
            : labelWidth;
        final preferredValueSlot = valueCanWrap
            ? math.max(minValueSlot, (valueWidth + minValueSlot) / 2.0)
            : valueWidth;
        if (preferredLabelSlot + preferredValueSlot <= availableAfterGap) {
          considerAllocation(
            preferredLabelSlot,
            candidateValueSlot: preferredValueSlot,
          );
        }

        // Also compare the two one-sided choices. The required-wrap guard
        // above keeps only the valid one when exactly one block can wrap.
        considerAllocation(labelWidth);
        considerAllocation(availableAfterGap - valueWidth);

        // If neither one-sided choice is short enough, compare shared-wrap
        // allocations. Wrapping changes at word boundaries, so a one-pixel
        // sweep is enough to find useful breakpoints while remaining stable at
        // fractional device widths and Dynamic Type sizes.
        for (
          var candidateLabelSlot = searchStart;
          candidateLabelSlot <= searchEnd;
          candidateLabelSlot += 1.0
        ) {
          considerAllocation(candidateLabelSlot);
        }
        // Include the fractional endpoint so the right edge remains exact.
        considerAllocation(searchEnd);

        if (bothBlocksCanWrap &&
            sharedMaxLines <= bestMaxLines &&
            sharedMaxLines < 999999) {
          bestLabelSlot = sharedLabelSlot;
          bestValueSlot = sharedValueSlot;
        }

        final row = Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              SizedBox(width: leadingWidth, child: leading),
              SizedBox(width: leadingGap),
            ],
            SizedBox(
              width: bestLabelSlot,
              child: Text(label, style: labelStyle, softWrap: true),
            ),
            SizedBox(
              width: constraints.maxWidth.isFinite
                  ? math.max(
                      kLabelValueGap,
                      constraints.maxWidth -
                          leadingTotal -
                          bestLabelSlot -
                          bestValueSlot,
                    )
                  : kLabelValueGap,
            ),
            SizedBox(width: bestValueSlot, child: trailing),
          ],
        );
        if (!alignTrailing) return _animateRowHeight(row);

        return _animateRowHeight(
          Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [Expanded(child: row)],
          ),
        );
      },
    );
  }
}

/// Describes one date/time-style pill in [AdaptiveLabelPillRow].
class AdaptivePillSpec {
  const AdaptivePillSpec({
    required this.text,
    required this.style,
    required this.backgroundColor,
    this.compactText,
    this.onTap,
  });

  final String text;
  final TextStyle style;
  final Color backgroundColor;
  final String? compactText;
  final VoidCallback? onTap;
}

/// Lays out a label and one or more intrinsic-width pills with the shared
/// minimum label-to-trailing gap.
///
/// The natural single-line layout is always preferred:
///
///   [label][minimum label-to-pill gap][pill group]
///
/// If that complete group cannot fit, the label stays beside a trailing pill
/// column. Date/time pills stack in that column and may wrap internally at
/// the current OS text scale. Only when the label itself consumes the row does
/// the label move above the group. The default minimum gap is 25dp and can be
/// tightened for compact rows that prioritize keeping all content on one line.
class AdaptiveLabelPillRow extends StatelessWidget {
  const AdaptiveLabelPillRow({
    super.key,
    required this.label,
    required this.labelStyle,
    required this.pills,
    this.onLabelTap,
    this.pillGap = 8.0,
    this.verticalWrapGap = 8.0,
    this.horizontalPadding = 12.0,
    this.verticalPadding = 6.0,
    this.wrapLabelLast = false,
    this.labelValueGap = kLabelValueGap,
  }) : assert(pills.length > 0);

  final String label;
  final TextStyle labelStyle;
  final List<AdaptivePillSpec> pills;
  final VoidCallback? onLabelTap;
  final double pillGap;
  final double verticalWrapGap;
  final double horizontalPadding;
  final double verticalPadding;
  /// Keep a multi-word label on one line while pills stack, only allowing
  /// the label to wrap if a stacked pill would otherwise wrap internally.
  final bool wrapLabelLast;
  /// Minimum gap used when deciding whether the label and pill group can share
  /// one line. Existing rows retain the shared 25dp gap by default.
  final double labelValueGap;

  double _textWidth(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width;
  }

  double _pillWidth(BuildContext context, AdaptivePillSpec pill) {
    return _textWidth(context, pill.text, pill.style) + (horizontalPadding * 2);
  }

  double _longestWordWidth(BuildContext context) {
    final words = label
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .map((word) => _textWidth(context, word, labelStyle));
    return words.fold<double>(0.0, math.max);
  }

  bool _pillsFitOnSingleLines(List<double> widths, double maxWidth) =>
      widths.every((width) => width <= maxWidth + 0.01);

  Widget _label({
    required bool fillWidth,
    bool allowWrap = false,
    double? width,
  }) {
    final text = Text(
      label,
      style: labelStyle,
      softWrap: fillWidth || allowWrap,
    );
    final content = width != null
        ? SizedBox(width: width, child: text)
        : fillWidth
        ? SizedBox(width: double.infinity, child: text)
        : text;
    if (onLabelTap == null) {
      return content;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onLabelTap,
      child: content,
    );
  }

  Widget _pill(
    AdaptivePillSpec pill, {
    double? maxWidth,
    String? textOverride,
  }) {
    Widget child = Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: pill.backgroundColor,
        // Keep the configured corner radius when Dynamic Type makes the pill
        // taller. A large capsule radius would change the shape as it wraps.
        borderRadius: const BorderRadius.all(
          Radius.circular(kSquircleStadiumRadius),
        ),
      ),
      child: Text(
        textOverride ?? pill.text,
        style: pill.style,
        textAlign: TextAlign.center,
        softWrap: true,
      ),
    );
    if (maxWidth != null && maxWidth.isFinite) {
      child = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: math.max(0.0, maxWidth)),
        child: child,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: pill.onTap,
      child: child,
    );
  }

  Widget _pillGroup(
    BuildContext context,
    List<double> naturalWidths, {
    required double maxWidth,
  }) {
    final naturalGroupWidth =
        naturalWidths.fold<double>(0.0, (sum, width) => sum + width) +
        (pillGap * math.max(0, pills.length - 1));
    final canStaySideBySide = naturalGroupWidth <= maxWidth;

    if (canStaySideBySide) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < pills.length; i++) ...[
            if (i > 0) SizedBox(width: pillGap),
            SizedBox(width: naturalWidths[i], child: _pill(pills[i])),
          ],
        ],
      );
    }

    if (pills.length == 1) {
      final pill = pills.single;
      final compactText = pill.compactText;
      // This branch is reached only after the full pill failed to fit.
      // Keep the abbreviated text even when it also exceeds the bound so it
      // can wrap inside the pill instead of reverting to an unclipped full
      // month name.
      final textOverride = compactText;
      return Align(
        alignment: Alignment.centerRight,
        child: _pill(pill, maxWidth: maxWidth, textOverride: textOverride),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < pills.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0.0 : pillGap),
            child: _pill(pills[i], maxWidth: maxWidth),
          ),
      ],
    );
  }

  Widget _labelAndPills({
    required Widget label,
    required Widget pillGroup,
    required bool alignLabelToTop,
  }) {
    return Row(
      crossAxisAlignment: alignLabelToTop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [label, const Spacer(), pillGroup],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final labelWidth = _textWidth(context, label, labelStyle);
        final naturalWidths = pills
            .map((pill) => _pillWidth(context, pill))
            .toList(growable: false);
        final naturalGroupWidth =
            naturalWidths.fold<double>(0.0, (sum, width) => sum + width) +
            (pillGap * math.max(0, pills.length - 1));
        final fitsOnOneLine =
            constraints.maxWidth.isFinite &&
            labelWidth + labelValueGap + naturalGroupWidth <=
                constraints.maxWidth;

        if (fitsOnOneLine) {
          return _labelAndPills(
            label: SizedBox(width: labelWidth, child: _label(fillWidth: false)),
            pillGroup: _pillGroup(
              context,
              naturalWidths,
              maxWidth: naturalGroupWidth,
            ),
            alignLabelToTop: false,
          );
        }

        final availableTrailingWidth = constraints.maxWidth.isFinite
            ? math.max(0.0, constraints.maxWidth - labelWidth - labelValueGap)
            : naturalGroupWidth;

        // Keep the label on the left while the date/time pills stack. This is
        // the important narrow-sheet case: the pills retain their authored
        // font size and use the width actually available beside the label.
        //
        // For a single End Date pill, passing the trailing width here is
        // intentional. _pillGroup then selects compactText as soon as the
        // full month-name pill cannot fit beside the label, instead of
        // needlessly moving the full date to a second line.
        if (availableTrailingWidth > 0) {
          // Keep Reminder Date on one line while the pills stack, unless that
          // narrow label slot would make either pill wrap internally. Only
          // then trade label height for pill integrity by wrapping the label
          // at its widest-word width.
          if (wrapLabelLast &&
              !_pillsFitOnSingleLines(
                naturalWidths,
                availableTrailingWidth,
              )) {
            final wrappedLabelWidth = _longestWordWidth(context);
            final wrappedTrailingWidth = math.max(
              0.0,
              constraints.maxWidth -
                  wrappedLabelWidth -
                  labelValueGap,
            );
            if (wrappedLabelWidth < labelWidth &&
                _pillsFitOnSingleLines(
                  naturalWidths,
                  wrappedTrailingWidth,
                )) {
              return _labelAndPills(
                label: _label(
                  fillWidth: false,
                  allowWrap: true,
                  width: wrappedLabelWidth,
                ),
                pillGroup: _pillGroup(
                  context,
                  naturalWidths,
                  maxWidth: wrappedTrailingWidth,
                ),
                alignLabelToTop: true,
              );
            }
          }

          return _labelAndPills(
            label: SizedBox(width: labelWidth, child: _label(fillWidth: false)),
            pillGroup: _pillGroup(
              context,
              naturalWidths,
              maxWidth: availableTrailingWidth,
            ),
            alignLabelToTop: true,
          );
        }

        // The pill cannot share a line with the label. Give the group the
        // entire row instead. For a single end-date pill this is what lets the
        // full month name remain visible whenever the complete pill fits on
        // its own line; _pillGroup chooses the abbreviation only if it does
        // not.
        final fullRowWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : naturalGroupWidth;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _label(fillWidth: true),
            SizedBox(height: verticalWrapGap),
            Align(
              alignment: Alignment.centerRight,
              child: _pillGroup(context, naturalWidths, maxWidth: fullRowWidth),
            ),
          ],
        );
      },
    );
  }
}

// ── SF Pro Line Spacing ───────────────────────────────────────────────────────
const kLineHeight = 1.3;

// ── SF Pro font family names ──────────────────────────────────────────────────
// Returns the registered pubspec font-family name on iOS/macOS where SF Pro is
// available, and null on Android/web so Flutter falls back to the system font.
// Use defaultTargetPlatform (flutter/foundation) instead of dart:io Platform —
// the latter throws UnsupportedError on web.  SF Pro fonts are only needed on
// Android; iOS already ships with the real SF Pro as a system font.
String? get kSFProText =>
    (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
    ? 'SFProText'
    : null;

// ══════════════════════════════════════════════════════════════════════════════
// AnimatedTapIcon — press-shrink + dim animation for bare icon buttons.
// ══════════════════════════════════════════════════════════════════════════════
class AnimatedTapIcon extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final ValueChanged<bool>? onPressedChanged;

  /// When false the scale stays at 1.0 on press — only opacity changes.
  final bool scaleEnabled;

  const AnimatedTapIcon({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(8),
    this.onPressedChanged,
    this.scaleEnabled = true,
  });

  @override
  State<AnimatedTapIcon> createState() => _AnimatedTapIconState();
}

class _AnimatedTapIconState extends State<AnimatedTapIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _opacity;

  int? _activePointer;
  Offset? _downPosition;
  static const double _kTapSlop = 18.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 180),
      vsync: this,
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.72,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _opacity = Tween<double>(
      begin: 1.0,
      end: 0.38,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (widget.onTap == null) return;
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _downPosition = event.position;
    _ctrl.forward();
    widget.onPressedChanged?.call(true);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    final start = _downPosition;
    if (start == null) return;
    if ((event.position - start).distance > _kTapSlop) {
      _activePointer = null;
      _downPosition = null;
      _ctrl.reverse();
      widget.onPressedChanged?.call(false);
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _downPosition = null;
    _ctrl.reverse();
    widget.onPressedChanged?.call(false);
    widget.onTap?.call();
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _downPosition = null;
    _ctrl.reverse();
    widget.onPressedChanged?.call(false);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Padding(
        padding: widget.padding,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) => Transform.scale(
            scale: widget.scaleEnabled ? _scale.value : 1.0,
            child: Opacity(opacity: _opacity.value, child: child),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// BoundedContinuousRectangleBorder — a ContinuousRectangleBorder whose
// effective corner radii are constrained to the rectangle being painted.
//
// Flutter's ContinuousRectangleBorder clamps each individual radius to the
// shortest side, but it does not scale adjacent corners when their combined
// diameter is larger than the available width/height.  That produces the
// vertical "seam" at the sides of unusually short cards (for example a
// one-row, 52 px action panel with the app's 24 px stadium radius).
//
// The requested radius is preserved for normal/tall cards.  For controls
// shorter than 48 px, only the vertical radius is constrained until opposing
// corners meet cleanly.  The horizontal scale remains independent so the
// squircle's corner geometry stays consistent wherever the control permits it.
class BoundedContinuousRectangleBorder extends ContinuousRectangleBorder {
  const BoundedContinuousRectangleBorder({super.side, super.borderRadius});

  BorderRadius _radiusFor(Rect rect, TextDirection? textDirection) {
    final radius = borderRadius.resolve(textDirection);
    if (rect.isEmpty) return BorderRadius.zero;

    // The custom path uses x for horizontal extent and y for vertical extent.
    // Scale each axis only when opposing corners would overlap.
    final horizontalTop = radius.topLeft.x + radius.topRight.x;
    final horizontalBottom = radius.bottomLeft.x + radius.bottomRight.x;
    final verticalLeft = radius.topLeft.y + radius.bottomLeft.y;
    final verticalRight = radius.topRight.y + radius.bottomRight.y;

    var horizontalScale = 1.0;
    if (horizontalTop > rect.width) {
      horizontalScale = math.min(horizontalScale, rect.width / horizontalTop);
    }
    if (horizontalBottom > rect.width) {
      horizontalScale = math.min(
        horizontalScale,
        rect.width / horizontalBottom,
      );
    }

    var verticalScale = 1.0;
    if (verticalLeft > rect.height) {
      verticalScale = math.min(verticalScale, rect.height / verticalLeft);
    }
    if (verticalRight > rect.height) {
      verticalScale = math.min(verticalScale, rect.height / verticalRight);
    }
    horizontalScale = horizontalScale.clamp(0.0, 1.0);
    verticalScale = verticalScale.clamp(0.0, 1.0);

    return BorderRadius.only(
      topLeft: Radius.elliptical(
        radius.topLeft.x * horizontalScale,
        radius.topLeft.y * verticalScale,
      ),
      topRight: Radius.elliptical(
        radius.topRight.x * horizontalScale,
        radius.topRight.y * verticalScale,
      ),
      bottomLeft: Radius.elliptical(
        radius.bottomLeft.x * horizontalScale,
        radius.bottomLeft.y * verticalScale,
      ),
      bottomRight: Radius.elliptical(
        radius.bottomRight.x * horizontalScale,
        radius.bottomRight.y * verticalScale,
      ),
    );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    final radius = _radiusFor(rect, textDirection);
    if (rect.isEmpty) return Path();

    final tl = radius.topLeft;
    final tr = radius.topRight;
    final br = radius.bottomRight;
    final bl = radius.bottomLeft;
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;
    final c = _kSharedSquircleCurveControl;
    final path = Path()..moveTo(left + tl.x, top);

    // Top-right quarter and right edge.
    path.lineTo(right - tr.x, top);
    path.cubicTo(
      right - tr.x + tr.x * c,
      top,
      right,
      top + tr.y - tr.y * c,
      right,
      top + tr.y,
    );
    path.lineTo(right, bottom - br.y);

    // Bottom-right quarter and bottom edge.
    path.cubicTo(
      right,
      bottom - br.y + br.y * c,
      right - br.x + br.x * c,
      bottom,
      right - br.x,
      bottom,
    );
    path.lineTo(left + bl.x, bottom);

    // Bottom-left quarter and left edge.
    path.cubicTo(
      left + bl.x - bl.x * c,
      bottom,
      left,
      bottom - bl.y + bl.y * c,
      left,
      bottom - bl.y,
    );
    path.lineTo(left, top + tl.y);

    // Top-left quarter.
    path.cubicTo(
      left,
      top + tl.y - tl.y * c,
      left + tl.x - tl.x * c,
      top,
      left + tl.x,
      top,
    );
    path.close();
    return path;
  }

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    final innerRect = rect.deflate(side.width);
    return BoundedContinuousRectangleBorder(
      side: side,
      borderRadius: _radiusFor(innerRect, textDirection),
    ).getOuterPath(innerRect, textDirection: textDirection);
  }
}

// SquircleStadiumBorder — a true shallow-control capsule with soft
// continuous/squircle end curves instead of StadiumBorder's semicircles.
//
// This is intentionally a path implementation rather than a
// ContinuousRectangleBorder with a half-height radius. ContinuousRectangleBorder
// treats its radius as a corner-box radius and therefore produces a rounded
// rectangle in a wide, shallow control. Here the end radius is fixed by the
// shared design token, then clamped only when the painted control cannot hold
// the requested geometry.
class SquircleStadiumBorder extends ContinuousRectangleBorder {
  final double radius;

  const SquircleStadiumBorder({
    super.side,
    this.radius = kSquircleStadiumRadius,
  });

  Path _pathForRect(Rect rect) {
    if (rect.isEmpty) return Path();

    // Keep every normal/tall stadium on the same 24 px corner geometry.
    // Height-based clamping is only active below 48 px.
    final radius = math.min(this.radius, rect.height / 2);
    final left = rect.left;
    final top = rect.top;
    final right = rect.right;
    final bottom = rect.bottom;
    final centerY = rect.center.dy;
    final leftCenterX = left + radius;
    final rightCenterX = right - radius;
    final c = radius * _kSharedSquircleCurveControl;
    final path = Path()..moveTo(leftCenterX, top);

    // Top edge and top-right softened capsule quarter.
    path.lineTo(rightCenterX, top);
    path.cubicTo(rightCenterX + c, top, right, centerY - c, right, centerY);

    // Bottom-right quarter and bottom edge.
    path.cubicTo(
      right,
      centerY + c,
      rightCenterX + c,
      bottom,
      rightCenterX,
      bottom,
    );
    path.lineTo(leftCenterX, bottom);

    // Bottom-left quarter and left side.
    path.cubicTo(leftCenterX - c, bottom, left, centerY + c, left, centerY);
    path.cubicTo(left, centerY - c, leftCenterX - c, top, leftCenterX, top);
    path.close();
    return path;
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _pathForRect(rect);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _pathForRect(rect.deflate(side.width));
}

// SplitChevronUpDown — a clean custom up/down picker glyph.  This is painted
// directly instead of clipping CupertinoIcons.chevron_up_chevron_down, because
// midpoint clipping leaves anti-aliased fragments from the other chevron.
class SplitChevronUpDown extends StatelessWidget {
  const SplitChevronUpDown({
    super.key,
    required this.color,
    // Authored size at the default OS text scale.
    this.size = 12.0,
    this.scaleX = 0.90,
    // Authored endpoint gap at the default OS text scale. The two paths move
    // equally away from the icon midpoint, so the whole affordance stays
    // vertically aligned with the value text.
    this.lowerOffset = 3.0,
  });

  final Color color;
  final double size;
  final double scaleX;
  final double lowerOffset;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final scaledSize = textScaler.scale(size);
    final scaledGap = textScaler.scale(lowerOffset);
    final scaledStrokeWidth = textScaler.scale(1.0);

    return CustomPaint(
      size: Size(scaledSize, scaledSize),
      painter: _SplitChevronPainter(
        color: color,
        size: scaledSize,
        gap: scaledGap,
        scaleX: scaleX,
        strokeWidth: scaledStrokeWidth,
      ),
    );
  }
}

/// Keeps a modal-sheet picker value and its chevron in the same right-anchored
/// trailing group used by the Settings Panel.
///
/// The parent row gives this widget the remaining trailing space, while this
/// row lays out the value and chevron from the right edge. Keeping the value
/// as a loose flexible child is important: it lets short values stay beside
/// the chevron instead of stretching through the middle of the sheet.
class ModalSheetPickerTrailing extends StatelessWidget {
  const ModalSheetPickerTrailing({
    super.key,
    required this.value,
    required this.style,
    required this.chevronColor,
    this.showChevron = true,
    this.valuePrefix,
  });

  final String value;
  final TextStyle style;
  final Color chevronColor;
  final bool showChevron;
  final Widget? valuePrefix;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (valuePrefix != null) ...[valuePrefix!, const SizedBox(width: 6)],
        Flexible(
          child: Text(
            smartWrapChevronValue(value),
            style: style,
            textAlign: TextAlign.right,
            softWrap: true,
            // Let the prefix sit beside the painted text block instead of
            // beside the full flexible slot when the value wraps.
            textWidthBasis: TextWidthBasis.longestLine,
          ),
        ),
        if (showChevron) ...[
          const SizedBox(width: 4),
          SizedBox(width: 12, child: SplitChevronUpDown(color: chevronColor)),
        ],
      ],
    );
  }
}

// AdaptiveStadiumBorder — keeps shallow cards on the shared capsule geometry,
// but switches to bounded continuous corners once Dynamic Type makes the card
// tall enough to be a content card.  A fixed stadium is still mathematically
// valid at any height, but it makes large-text rows look stretched and can
// visually crowd wrapped text against the end curves.
//
// The decision is made from the actual painted rect, rather than from the
// number of children in the card.  This is important for a one-row picker:
// its row can become multi-line without changing its widget structure.
class AdaptiveStadiumBorder extends ShapeBorder {
  final double radius;
  final double maxStadiumHeight;

  const AdaptiveStadiumBorder({
    this.radius = kSquircleStadiumRadius,
    this.maxStadiumHeight = 56.0,
  });

  ShapeBorder _borderFor(Rect rect) {
    if (rect.height <= maxStadiumHeight) {
      return SquircleStadiumBorder(radius: radius);
    }
    return BoundedContinuousRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
    );
  }

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) =>
      _borderFor(rect).getOuterPath(rect, textDirection: textDirection);

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) =>
      _borderFor(rect).getInnerPath(rect, textDirection: textDirection);

  @override
  void paint(
    Canvas canvas,
    Rect rect, {
    TextDirection? textDirection,
    BoxShape shape = BoxShape.rectangle,
    BorderRadius? borderRadius,
  }) {}

  @override
  ShapeBorder scale(double t) => AdaptiveStadiumBorder(
    radius: radius * t,
    maxStadiumHeight: maxStadiumHeight,
  );
}

class _SplitChevronPainter extends CustomPainter {
  const _SplitChevronPainter({
    required this.color,
    required this.size,
    required this.gap,
    required this.scaleX,
    required this.strokeWidth,
  });

  final Color color;
  final double size;
  final double gap;
  final double scaleX;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size canvasSize) {
    final inset = size * 0.14;
    // Keep each chevron's authored height stable while the pair separates.
    // This makes the extra space come from moving the paths outward rather
    // than compressing them toward the midpoint.
    final chevronHeight = size * 0.27;
    // Keep the separation symmetric around the icon midpoint: increasing the
    // gap moves the upper chevron up and the lower chevron down together.
    final safeGap = gap.clamp(0.0, size * 0.40);
    final margin = ((size - (chevronHeight * 2) - safeGap) / 2).clamp(
      0.0,
      size,
    );
    final topBaseY = margin + chevronHeight;
    final bottomBaseY = topBaseY + safeGap;
    final centerX = size / 2;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()
      // Up chevron.
      ..moveTo(inset, topBaseY)
      ..lineTo(centerX, margin)
      ..lineTo(size - inset, topBaseY)
      // Down chevron.
      ..moveTo(inset, bottomBaseY)
      ..lineTo(centerX, size - margin)
      ..lineTo(size - inset, bottomBaseY);

    canvas.save();
    canvas.translate((size - (size * scaleX)) / 2, 0);
    canvas.scale(scaleX, 1);
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_SplitChevronPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.size != size ||
      oldDelegate.gap != gap ||
      oldDelegate.scaleX != scaleX ||
      oldDelegate.strokeWidth != strokeWidth;
}

// SquircleClipper — public squircle (ContinuousRectangleBorder) clip path.
//
// Rules for BackdropFilter usage:
//   • SquircleClipper MUST be the DIRECT parent of BackdropFilter so the blur
//     is strictly bounded inside the squircle shape (no halo bleed).
//   • DecoratedBox / shadow must sit OUTSIDE ClipPath so shadows can overflow.
//   • Never wrap a BackdropFilter subtree in Opacity — it breaks compositing.
//   • TileMode.decal prevents kernel clamping at the clip edge.
// ══════════════════════════════════════════════════════════════════════════════
class SquircleClipper extends CustomClipper<Path> {
  // Default constructor — uniform squircle radius.
  const SquircleClipper([this.radius = kCornerRadius]) : borderRadius = null;
  // Named constructor — per-corner squircle radii (e.g. top-only rounding).
  const SquircleClipper.asymmetric(this.borderRadius) : radius = kCornerRadius;

  final double radius;
  final BorderRadius? borderRadius;

  @override
  Path getClip(Size size) => BoundedContinuousRectangleBorder(
    borderRadius: borderRadius ?? BorderRadius.circular(radius),
  ).getOuterPath(Rect.fromLTWH(0, 0, size.width, size.height));

  @override
  bool shouldReclip(SquircleClipper old) =>
      old.radius != radius || old.borderRadius != borderRadius;
}

// ══════════════════════════════════════════════════════════════════════════════
// FrostedGlassCard — the DecoratedBox + ClipPath + BackdropFilter shell.
//
// [progress] is 0.0 → 1.0.  Blur sigma, fill alpha, and shadow alpha all scale
// with it so the glass materialises in sync with whatever drives the value.
//
// Scale / Transform is deliberately NOT applied here.  Complex callers (e.g.
// ActionPanel, which splits scale-progress from glass-progress) keep the
// Transform.scale outside and just pass their glass progress in.
// ══════════════════════════════════════════════════════════════════════════════
class FrostedGlassCard extends StatelessWidget {
  const FrostedGlassCard({
    super.key,
    required this.progress,
    required this.child,
    this.blurSigma = 20.0,
    this.fillOpacity = 0.80,
    this.shadowOpacity = 0.22,
    this.shadowBlurRadius = 28.0,
    this.cornerRadius = kCornerRadius,
    this.border,
    // Optional per-corner override — when set, takes precedence over
    // cornerRadius and allows asymmetric squircle shapes (e.g. top-only).
    this.borderRadius,
    this.stadium = false,
  });

  /// Animation progress: 0.0 (invisible) → 1.0 (fully open).
  final double progress;
  final Widget child;

  /// Maximum BackdropFilter blur sigma at progress = 1.
  final double blurSigma;

  /// Maximum fill opacity at progress = 1.  Keep below 1.0 so the
  /// BackdropFilter blur shows through as frosted glass.
  final double fillOpacity;

  /// Maximum shadow opacity at progress = 1.
  final double shadowOpacity;

  /// Drop-shadow blur radius (does not animate with progress).
  final double shadowBlurRadius;

  final double cornerRadius;

  /// Optional outline painted around the same squircle as the glass surface.
  /// Action panels use this for their Dark Mode tertiary-label hairline.
  final BorderSide? border;

  /// When non-null, overrides [cornerRadius] for per-corner squircle shaping.
  final BorderRadius? borderRadius;

  /// Uses the app-owned squircle stadium for shallow controls that should read
  /// as pills. Kept opt-in so taller cards retain continuous-corner geometry.
  final bool stadium;

  @override
  Widget build(BuildContext context) {
    final blur = blurSigma * progress;
    final fill = (fillOpacity * progress).clamp(0.0, 1.0);
    final shadow = CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? 0.0
        : shadowOpacity * progress;
    final effectiveBR = borderRadius ?? BorderRadius.circular(cornerRadius);
    final useStadium = stadium && borderRadius == null;

    return DecoratedBox(
      decoration: ShapeDecoration(
        shadows: resolveThemeShadows([
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, shadow),
            blurRadius: shadowBlurRadius,
            offset: const Offset(0, 8),
          ),
        ], context),
        shape: useStadium
            ? SquircleStadiumBorder(side: border ?? BorderSide.none)
            : BoundedContinuousRectangleBorder(
                borderRadius: effectiveBR,
                side: border ?? BorderSide.none,
              ),
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(
          shape: useStadium
              ? SquircleStadiumBorder(side: border ?? BorderSide.none)
              : BoundedContinuousRectangleBorder(
                  borderRadius: effectiveBR,
                  side: border ?? BorderSide.none,
                ),
        ),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur,
            tileMode: TileMode.decal,
          ),
          child: ColoredBox(
            color: resolveThemeColor(
              kGlassFillColor,
              context,
            ).withValues(alpha: fill),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GelBloomCard — self-animating frosted-glass card that blooms in on mount.
//
// Owns its own AnimationController so callers need zero animation boilerplate.
// Use for sheets, permission prompts, drawers, or any card that appears on
// screen — just wrap your content and it takes care of the rest.
//
// Example:
//   GelBloomCard(
//     scaleOrigin: Alignment.bottomCenter,   // grows upward from tray edge
//     child: MySheetContent(),
//   )
// ══════════════════════════════════════════════════════════════════════════════
class GelBloomCard extends StatefulWidget {
  const GelBloomCard({
    super.key,
    required this.child,
    this.scaleOrigin = Alignment.bottomCenter,
    this.duration = const Duration(milliseconds: 480),
    this.startScale = 0.60,
    this.blurSigma = 20.0,
    this.fillOpacity = 0.82,
    this.shadowOpacity = 0.26,
    this.cornerRadius = kCornerRadius,
    this.border,
  });

  final Widget child;

  /// Where the bloom grows from.
  ///   Alignment.bottomCenter — sheets/trays (grow upward from the bottom).
  ///   Alignment.topCenter    — dropdown menus (grow downward from the top).
  final Alignment scaleOrigin;

  /// Total open animation duration.
  final Duration duration;

  /// Scale at t=0 before the bloom.  0.60 gives a pronounced gel overshoot.
  final double startScale;

  final double blurSigma;
  final double fillOpacity;
  final double shadowOpacity;
  final double cornerRadius;
  final BorderSide? border;

  @override
  State<GelBloomCard> createState() => _GelBloomCardState();
}

class _GelBloomCardState extends State<GelBloomCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this);
    // easeOut envelope; easeOutBack in the scale expression provides the
    // characteristic gel overshoot without a separate spring simulation.
    _ctrl.animateTo(1.0, duration: widget.duration, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        final pt = _ctrl.value;
        // easeOutBack peaks ~1.07 before settling at 1.0 — the gel bloom.
        // Starting from startScale (0.60) widens the bloom range so the
        // spring overshoot is visually pronounced.
        final scale =
            widget.startScale +
            (1.0 - widget.startScale) * Curves.easeOutBack.transform(pt);

        return Transform.scale(
          scale: scale,
          alignment: widget.scaleOrigin,
          child: FrostedGlassCard(
            progress: pt,
            blurSigma: widget.blurSigma,
            fillOpacity: widget.fillOpacity,
            shadowOpacity: widget.shadowOpacity,
            cornerRadius: widget.cornerRadius,
            border: widget.border,
            child: child!,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GelBloomButton — gel-bloom tap animation wrapper.
//
// Wraps any child widget.  On tap the child springs to [peakScale] using
// easeOutBack then returns to 1.0 with easeInOut, giving the gel "pop" feel.
//
// [tapDelay] holds the onTap callback until the bloom peak is visible —
// useful for dismiss buttons so the animation completes before the screen
// closes.
//
// Typical peakScale values:
//   1.15 — circle buttons (pronounced pop — more travel, more "alive")
//   1.06 — wide card buttons (subtle bloom — large surface, less travel)
// ══════════════════════════════════════════════════════════════════════════════
class GelBloomButton extends StatefulWidget {
  const GelBloomButton({
    super.key,
    required this.child,
    required this.onTap,
    this.peakScale = 1.15,
    this.tapDelay = Duration.zero,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Scale at the bloom peak. 1.15 for circles; 1.06 for wide cards.
  final double peakScale;

  /// Delay before firing [onTap]. Use ~120–130 ms for dismiss buttons.
  final Duration tapDelay;

  @override
  State<GelBloomButton> createState() => _GelBloomButtonState();
}

class _GelBloomButtonState extends State<GelBloomButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: widget.peakScale,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 52,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: widget.peakScale,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 48,
      ),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _bloom() => _ctrl.forward(from: 0.0);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        _bloom();
        if (widget.tapDelay == Duration.zero) {
          widget.onTap();
        } else {
          Future.delayed(widget.tapDelay, () {
            if (mounted) widget.onTap();
          });
        }
      },
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}
