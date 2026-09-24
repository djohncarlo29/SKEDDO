import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

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
// iOS 26's floating tab bar keeps a deliberate side inset rather than
// stretching edge-to-edge. Keep the same inset for the bar, shadow, and
// hairline.
const double kFloatingTabBarHorizontalMargin = 24.0;
const double kFloatingTabBarBottomSpacing = 16.0;
const double kFloatingTabBarHeight = 50.0;
const double kFloatingTabBarTouchTargetHeight = 44.0;
// The floating bar is a deliberately compact navigation control. Keep its
// content on a bounded scaler so extreme OS text sizes cannot change the
// geometry that the glass pill, reveal clip, and gesture region share. The
// rest of the app continues to use the full OS scaler.
const double kFloatingTabBarMinimumTextScale = 0.85;
const double kFloatingTabBarMaximumTextScale = 1.15;
const kFloatingTabBarSelectedPillColor = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFFFFFF),
  darkColor: Color(0xFF2C2C2E),
);
const kFloatingTabBarSurfaceColor = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFFAFAFC),
  darkColor: Color(0xFF1C1C1E),
);
// Keep the tab bar and its active glass pill on the package's authored optical
// color-separation setting.
// Keep the navigation pill on the liquid_glass_easy package's authored
// chromatic-aberration value in both its lifted and settled material states.
const double kFloatingTabBarChromaticAberration = 0.002;
// Shared visual gap used between the last content edge and the floating pill.
const double kFloatingTabBarVisualGap = 16.0;
// Keep the pill's final-item safety buffer independent from the Events layout
// gap. Reusing kFloatingTabBarVisualGap here compounds spacing at controls
// that already have their own trailing padding.
const double kFloatingTabBarSafetyMargin = 12.0;
// Shared fixed vertical inset used by compact controls and rows. Text inside
// those controls may grow with the OS text scaler, but this authored breathing
// room does not.
const double kFixedVerticalPadding = 16.0;

// Shared authored horizontal inset for controls aligned to the trailing edge
// of modal rows. Keep this outside scaled content so Dynamic Type changes the
// control's size without changing its distance from the row edge.
const double kModalRowHorizontalInset = 16.0;

// Default authored bottom breathing room for panels, sheets, and stacked modal
// content. Persistent device safe-area space is added separately.
const double kUnifiedBottomPadding = kFixedVerticalPadding;
const double kEmptyStateLabelFontSize = 17.0;

/// The tab bar's bottom edge is constrained by two competing requirements:
/// its 16 px design margin and the persistent system navigation/home-indicator
/// inset. They are not additive. Persistent safe-area and gesture insets are
/// compared rather than summed, and keyboard viewInsets are intentionally
/// ignored so the bar does not move just because an editor is focused.
/// Shared bottom padding rule for surfaces that should respect persistent
/// system navigation without creating additive or colored safe-area bands.
///
/// The authored 16 px breathing room is the minimum. If a home indicator,
/// gesture area, or Android navigation bar is larger, use that actual inset
/// instead. Keyboard viewInsets are deliberately not part of this rule.
double unifiedBottomPaddingForInset(double systemBottomInset) =>
    math.max(kUnifiedBottomPadding, systemBottomInset);

double unifiedBottomPadding(BuildContext context) =>
    unifiedBottomPaddingForInset(systemSafeAreaBottomInset(context));

double floatingTabBarBottomOffsetForInset(double systemBottomInset) =>
    unifiedBottomPaddingForInset(systemBottomInset);

double floatingTabBarBottomOffset(BuildContext context) =>
    floatingTabBarBottomOffsetForInset(
      math.max(
        MediaQuery.viewPaddingOf(context).bottom,
        MediaQuery.systemGestureInsetsOf(context).bottom,
      ),
    );

/// Persistent bottom space occupied by system navigation or the home
/// indicator. This intentionally ignores keyboard [viewInsets] and does not
/// impose the Floating Tab Bar's separate 16 px design margin.
double systemSafeAreaBottomInset(BuildContext context) => math.max(
  MediaQuery.viewPaddingOf(context).bottom,
  MediaQuery.systemGestureInsetsOf(context).bottom,
);

/// Extra scroll-content clearance needed so the final item in a tab can be
/// scrolled fully above the floating pill rather than ending underneath it.
double floatingTabBarContentBottomClearance(
  BuildContext context, {
  double existingTrailingContentPadding = 0,
  double finalContentGap = kFloatingTabBarSafetyMargin,
}) {
  final clearance =
      kFloatingTabBarHeight +
      floatingTabBarBottomOffset(context) +
      finalContentGap -
      existingTrailingContentPadding;
  return math.max(0.0, clearance);
}

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

const double kModalSheetContextFooterFontSize = 13.0;
const double kModalSheetContextFooterHorizontalInset = 16.0;

/// Shared typography for explanatory context text below modal-sheet cards.
TextStyle modalSheetContextFooterStyle(BuildContext context) =>
    resolveThemeTextStyle(
      TextStyle(
        inherit: false,
        color: kSecondaryLabel,
        fontSize: kModalSheetContextFooterFontSize,
        fontFamily: kSFProText,
        fontWeight: FontWeight.w400,
        letterSpacing: kTracking17,
        height: kLineHeight,
      ),
      context,
    );

/// Shared typography for accent-coloured values in modal-sheet picker rows.
TextStyle modalSheetAccentValueStyle(
  BuildContext context,
  Color color,
) => TextStyle(
  inherit: false,
  color: resolveThemeColor(color, context),
  fontSize: 15,
  fontFamily: kSFProText,
  fontWeight: FontWeight.w500,
  letterSpacing: kTracking17,
  height: kLineHeight,
);

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

// Explicit disabled action surface. Do not derive this by multiplying the
// tertiary label alpha: the unavailable checkmark buttons are intentionally a
// fixed 25% surface in both appearances.
const kDisabledActionSurface = CupertinoDynamicColor.withBrightness(
  color: Color(0xFFCECDD3),
  darkColor: Color(0xFF474747),
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

// Multi-Day day-circle marker colors in the same order as [kAccentSwatches].
// These are intentionally separate from the selected-circle accent colors:
// each marker has its own exact Light Mode / Dark Mode pair.
const kMultiDayMarkerSwatches = <CupertinoDynamicColor>[
  CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF7A9A7),
    darkColor: Color(0xFF661D17),
  ), // Red
  CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF7CD93),
    darkColor: Color(0xFF674005),
  ), // Orange
  CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF6E394),
    darkColor: Color(0xFF655603),
  ), // Yellow
  CupertinoDynamicColor.withBrightness(
    color: Color(0xFFA7E1B8),
    darkColor: Color(0xFF125522),
  ), // Green
  CupertinoDynamicColor.withBrightness(
    color: Color(0xFFB4E1F8),
    darkColor: Color(0xFF295465),
  ), // Light Blue
  CupertinoDynamicColor.withBrightness(
    color: Color(0xFF91C2FA),
    darkColor: Color(0xFF033566),
  ), // Blue
  CupertinoDynamicColor.withBrightness(
    color: Color(0xFFB4B4EA),
    darkColor: Color(0xFF26265C),
  ), // Violet
  CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF6A3B5),
    darkColor: Color(0xFF671627),
  ), // Pink
  CupertinoDynamicColor.withBrightness(
    color: Color(0xFFD8B2ED),
    darkColor: Color(0xFF4C2462),
  ), // Purple
  CupertinoDynamicColor.withBrightness(
    color: Color(0xFFD4CEBE),
    darkColor: Color(0xFF4E4735),
  ), // Tan
  CupertinoDynamicColor.withBrightness(
    color: Color(0xFFB9C3CC),
    darkColor: Color(0xFF3D4248),
  ), // Slate
  CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE7DED9),
    darkColor: Color(0xFF5E554E),
  ), // Sand
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

/// Resolves the exact Multi-Day marker color for the active accent swatch.
///
/// The marker palette follows [kAccentSwatches] by index. If a future custom
/// accent is introduced outside the built-in palette, fall back to the active
/// accent rather than selecting an unrelated marker color.
Color resolveMultiDayMarkerColor(BuildContext context) {
  final accent = dynamicAccentColor(context);
  final swatchIndex = kAccentSwatches.indexWhere(
    (swatch) => swatch.value == accent.value,
  );
  final marker = swatchIndex >= 0
      ? kMultiDayMarkerSwatches[swatchIndex]
      : accent;
  return CupertinoDynamicColor.resolve(marker, context);
}

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

/// Returns the top offset for an action whose visual centre should sit on the
/// first line of a modal text field.
///
/// This deliberately uses the field's content inset and first line box rather
/// than the enclosing row height.  The distinction matters for multiline
/// fields, where centring against the row would place the clear action beside
/// the middle of the text instead of beside its first line.
double modalFirstLineActionTop(
  BuildContext context, {
  required double actionHeight,
  double contentTopPadding = 0,
  double fontSize = 17,
  double lineHeight = kLineHeight,
}) {
  final scaledFontSize = MediaQuery.textScalerOf(context).scale(fontSize);
  final firstLineHeight = scaledFontSize * lineHeight;
  return contentTopPadding +
      math.max(0.0, (firstLineHeight - actionHeight) / 2);
}

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
const double kLargeModalSheetCornerRadius = 40.0;
// Confirmation cards and normal confirmation buttons use the standard fixed
// 24px radius. A multiline button grows through its straight middle section
// instead of changing the curvature of its corners.
const double kConfirmationSheetCornerRadius = 24.0;
const double kModalConfirmationSheetCornerRadius = 24.0;
const double kConfirmationButtonCornerRadius = kSquircleStadiumRadius;
// The dismiss confirmation keeps its own token, but its radius is fixed so
// multiline labels grow through the straight middle section.
const double kDiscardConfirmationButtonCornerRadius = kSquircleStadiumRadius;
const double kModalConfirmationHorizontalInset = 24.0;
const double kDiscardConfirmationTopLeftWidthFraction = 2 / 3;
const double kDiscardConfirmationTopLeftEdgeGap = 16.0;
const double kDiscardConfirmationButtonEdgeGap = 16.0;
const double kDiscardConfirmationMessageHorizontalInset = 8.0;
const double kDiscardConfirmationMessageButtonGap = 16.0;
const double kDiscardConfirmationSheetTopInset = 16.0;

// Shared cubic quarter used by both stadium controls and bounded card corners.
const double _kSharedSquircleCurveControl = 0.64;

// The search bar is the one intentionally smaller stadium: 20 px corners.
const double kSearchBarCornerRadius = 20.0;
// Search-bar inner top and bottom insets stay fixed at 8 pt while only its
// text line grows with the ambient OS text scaler. This is intentionally
// search-only; the shared kFixedVerticalPadding remains 16 pt elsewhere.
const double kSearchBarVerticalPadding = 8.0;
const double kSearchBarHostTopPadding = kFixedVerticalPadding;
const double kSearchBarHeaderSeparatorGap = kFixedVerticalPadding;
const double kSearchBarSeparatorHeight = 0.5;
const double kSearchBarTextFontSize = 17.0;
const double kSearchBarSideControlHeight = 40.0;
const double kSearchBarSearchIconSize = 17.0;
const double kSearchBarMicIconSize = 15.0;
const double kSearchBarClearIconSize = 18.0;
// The cancel control is a separate sibling of the search bar. This gap is
// layout spacing, not part of the scaled glass control.
const double kSearchBarCancelGap = 8.0;
// Edge insets are authored layout values, not text-sized values. They stay at
// 16 pt while the icons and text line respond to the ambient OS text scaler.
const double kSearchBarHorizontalEdgePadding = 16.0;

/// Scales search/clear glyphs with Dynamic Type while leaving their authored
/// row edge padding independent from text scaling.
double scaledSearchIconSize(BuildContext context, double authoredSize) =>
    MediaQuery.textScalerOf(context).scale(authoredSize);

/// Returns the active text-size multiplier for an authored font size.
///
/// Circle indicators and other non-text geometry use this ratio when they are
/// designed around a specific text size, so the visual relationship stays
/// stable across System and Custom text-size modes.
double textScaleRatioFor(BuildContext context, double authoredFontSize) {
  if (authoredFontSize <= 0) return 1.0;
  return MediaQuery.textScalerOf(context).scale(authoredFontSize) /
      authoredFontSize;
}

/// The line box occupied by search text at the current OS text scale.
double searchBarTextLineHeight(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(kSearchBarTextFontSize) *
    kLineHeight;

/// The complete AppSearchBar height: fixed 8 pt above and below the text
/// line, with no fixed outer height.
double searchBarHeight(BuildContext context) =>
    (kSearchBarVerticalPadding * 2) + searchBarTextLineHeight(context);

/// Height of a host row before its optional separator.
double searchBarHostRowHeight(BuildContext context) => math.max(
  kSearchBarHostTopPadding + searchBarHeight(context),
  kSearchBarHostTopPadding + kSearchBarSideControlHeight,
);

/// Height required by a pinned search header with its separator.
double searchBarHeaderExtent(BuildContext context) =>
    searchBarHostRowHeight(context) +
    kSearchBarHeaderSeparatorGap +
    kSearchBarSeparatorHeight;

// Vertical breathing room between the standalone cards in event modal sheets.
// Search-result event tiles use the same rhythm.
const double kModalCardGap = 16.0;

// Legacy aliases used by asymmetric multi-row card shells. Keeping these
// aliases tied to the stadium token makes their visible outer corners match
// the single-row stadium controls while still allowing row-specific corners
// to collapse to zero during animated sections.
const double kCornerRadius = kSquircleStadiumRadius;
const double kCardCornerRadius = kSquircleStadiumRadius;

// Modal-sheet header geometry. The circular action controls and the sheet
// corner share one concentric relationship: the sheet radius is the button
// radius plus the authored edge gap.
const double kModalSheetButtonDiameter = 40.0;
const double kModalSheetButtonEdgeGap = 16.0;
const double kModalSheetCornerRadius =
    (kModalSheetButtonDiameter / 2) + kModalSheetButtonEdgeGap;
const double kRoundedSheetTopGapRatio = 0.08;

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
// Shared vertical separation when a label/value or label/pill row falls back
// to a second level. This matches the existing Default Category row spacing.
const double kWrappedLabelValueGap = 8.0;
// Give a preserved single-line label a fractional-pixel cushion so the
// measured width and the render paragraph do not disagree at a line break.
const double kTextLayoutEpsilon = 0.5;

// Modal-sheet picker rows sit 16 pt inside the card edge. This is authored
// layout padding, so it stays fixed while the chevron itself follows Dynamic
// Type through the active text scaler. The inset belongs to the row boundary,
// not the trailing widget; otherwise the row's existing horizontal padding and
// the chevron's padding would add up to 32 pt.
const double kModalSheetPickerRowHorizontalInset = 16.0;
const double kModalSheetPickerChevronSize = 12.0;
const double kModalSheetPickerChevronGap = 4.0;

double modalSheetPickerTrailingExtraWidth(
  BuildContext context, {
  bool showChevron = true,
  bool hasValuePrefix = false,
}) {
  if (!showChevron) return 0.0;
  final scaledChevronWidth = MediaQuery.textScalerOf(
    context,
  ).scale(kModalSheetPickerChevronSize);
  return (hasValuePrefix ? 16.0 : 0.0) +
      scaledChevronWidth +
      kModalSheetPickerChevronGap;
}

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

bool _hasSingleCharacterWordPair(String value) {
  final words = value.trim().split(RegExp(r'\s+'));
  if (words.length != 2) return false;
  return words.any((word) => word.runes.length == 1);
}

String _joinWordCharacters(String word) {
  return word.runes.map(String.fromCharCode).join('\u2060');
}

/// Keeps values such as "1 hour" together for the first layout decision.
///
/// The ordinary [smartWrapChevronValue] form remains the fallback when the
/// complete pair cannot fit beside a wrapped label.
String smartWrapChevronValueAsProtectedPair(String value) {
  if (!_hasSingleCharacterWordPair(value)) {
    return smartWrapChevronValue(value);
  }
  final words = value.trim().split(RegExp(r'\s+'));
  // NBSP keeps the visible space between the two words while preventing a
  // break at that boundary during the label-first layout attempt.
  return '${_joinWordCharacters(words[0])}\u00a0${_joinWordCharacters(words[1])}';
}

/// Chooses the protected short pair until its available text width is too
/// narrow, then permits ordinary word-boundary wrapping as a last resort.
String chevronValueTextForWidth(
  BuildContext context,
  String value,
  TextStyle style,
  double maxWidth,
) {
  final protectedValue = smartWrapChevronValueAsProtectedPair(value);
  if (!maxWidth.isFinite || !_hasSingleCharacterWordPair(value)) {
    return protectedValue;
  }
  final painter = TextPainter(
    text: TextSpan(text: protectedValue, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  return painter.width <= maxWidth + kTextLayoutEpsilon
      ? protectedValue
      : smartWrapChevronValue(value);
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
///
/// If even the widest word from each block cannot fit beside the other block,
/// the row becomes a full-width vertical stack: the label is left-aligned on
/// top, and the value is right-aligned below it with a fixed 16 pt gap. Both
/// blocks retain their full width so either one can wrap across multiple lines.
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

  Widget _animateRowHeight(
    Widget row, {
    Alignment alignment = Alignment.topCenter,
  }) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 220),
      reverseDuration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      alignment: alignment,
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
        final hasProtectedPair = _hasSingleCharacterWordPair(value);
        final protectedPairValue = smartWrapChevronValueAsProtectedPair(value);
        final layoutValue = hasProtectedPair
            ? protectedPairValue
            : wrappedValue;
        final valueWidth =
            _singleLineWidth(context, layoutValue, valueStyle) +
            trailingExtraWidth;
        final leadingTotal = leading == null ? 0.0 : leadingWidth + leadingGap;
        final fitsOnOneLine =
            constraints.maxWidth.isFinite &&
            leadingTotal + labelWidth + kLabelValueGap + valueWidth <=
                constraints.maxWidth;
        // Wrapping is a fallback only. The first wrapped allocation preserves
        // the natural single-line label whenever the value can wrap beside it
        // without violating the gap. Later allocations may wrap the label,
        // then alternate back to the value, in that order.
        final minimumLabelWidth = _minimumReadableWidth(
          context,
          label,
          labelStyle,
        );

        final availableAfterGap = math.max(
          0.0,
          constraints.maxWidth - leadingTotal - kLabelValueGap,
        );

        // A value with a one-character word (for example, "1 hour") is
        // treated as one word while deciding which side should wrap. Keep the
        // value whole and give the label the first chance to wrap. Only when
        // even the label's readable minimum cannot coexist with that value do
        // we fall through to the ordinary shared-wrap algorithm.
        if (hasProtectedPair &&
            !fitsOnOneLine &&
            constraints.maxWidth.isFinite) {
          final protectedValueSlot =
              trailingExtraWidth +
              _singleLineWidth(context, protectedPairValue, valueStyle);
          final labelSlot = availableAfterGap - protectedValueSlot;
          if (labelSlot + kTextLayoutEpsilon >= minimumLabelWidth &&
              _hasMultipleWords(label)) {
            final protectedRow = Row(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  SizedBox(width: leadingWidth, child: leading!),
                  SizedBox(width: leadingGap),
                ],
                SizedBox(
                  width: labelSlot,
                  child: Text(label, style: labelStyle, softWrap: true),
                ),
                const SizedBox(width: kLabelValueGap),
                SizedBox(width: protectedValueSlot, child: trailing),
              ],
            );
            return _animateRowHeight(
              protectedRow,
              alignment: leading == null
                  ? Alignment.topCenter
                  : Alignment.center,
            );
          }
        }

        if (fitsOnOneLine) {
          final row = Row(
            mainAxisSize: alignTrailing ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                SizedBox(width: leadingWidth, child: leading!),
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
          return _animateRowHeight(
            row,
            alignment: leading == null ? Alignment.topCenter : Alignment.center,
          );
        }

        // Both sides are flexible once the one-line layout no longer fits.
        // Leave the gap out of the search space, and reserve the trailing
        // group's non-text width from the value side.
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

        // Search only within allocations that keep each side's widest word
        // intact. The first valid wrap target wins; this gives the value-first
        // alternating order its intended priority.
        var bestLabelSlot = minLabelSlot;
        var bestValueSlot = math.max(0.0, availableAfterGap - bestLabelSlot);
        var foundAllocation = false;
        final maxLabelSlot = math.max(
          minLabelSlot,
          availableAfterGap - minValueSlot,
        );
        final searchStart = math.min(minLabelSlot, maxLabelSlot);
        final searchEnd = math.max(minLabelSlot, maxLabelSlot);

        bool findAllocation(int targetLabelLines, int targetValueLines) {
          var targetFound = false;
          var targetScore = double.infinity;
          var targetLabelSlot = minLabelSlot;
          var targetValueSlot = math.max(
            0.0,
            availableAfterGap - targetLabelSlot,
          );

          void considerCandidate(double candidateLabelSlot) {
            final labelSlot = candidateLabelSlot
                .clamp(0.0, availableAfterGap)
                .toDouble();
            final valueSlot = (availableAfterGap - labelSlot)
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
            final labelWordsFit =
                labelSlot + kTextLayoutEpsilon >=
                _longestWordWidth(context, label, labelStyle);
            final valueWordsFit =
                valueSlot - trailingExtraWidth + kTextLayoutEpsilon >=
                _longestWordWidth(context, wrappedValue, valueStyle);
            if (!labelWordsFit ||
                !valueWordsFit ||
                labelMetrics.lineCount != targetLabelLines ||
                valueMetrics.lineCount != targetValueLines) {
              return;
            }

            // Prefer the allocation closest to the natural label width. This
            // keeps the first value wrap from stealing unnecessary width from
            // the label while preserving the target line counts.
            final score = (labelSlot - labelWidth).abs();
            if (!targetFound || score < targetScore) {
              targetFound = true;
              targetScore = score;
              targetLabelSlot = labelSlot;
              targetValueSlot = valueSlot;
            }
          }

          for (
            var candidateLabelSlot = searchStart;
            candidateLabelSlot <= searchEnd;
            candidateLabelSlot += 1.0
          ) {
            considerCandidate(candidateLabelSlot);
          }
          considerCandidate(searchEnd);

          if (targetFound) {
            bestLabelSlot = targetLabelSlot;
            bestValueSlot = targetValueSlot;
          }
          return targetFound;
        }

        int wordCount(String text) {
          final trimmed = text.trim();
          return trimmed.isEmpty ? 1 : trimmed.split(RegExp(r'\s+')).length;
        }

        final labelWordCount = wordCount(label);
        final valueWordCount = wordCount(wrappedValue);
        final wrapTargets = <List<int>>[];

        void addWrapTarget(int targetLabelLines, int targetValueLines) {
          if (targetLabelLines == 1 && targetValueLines == 1) return;
          wrapTargets.add([targetLabelLines, targetValueLines]);
        }

        // Normal rows alternate one additional wrap at a time, always giving
        // the value the first opportunity: value 2 / label 1, then value 2 /
        // label 2, then value 3 / label 2, and so on.
        var targetLabelLines = 1;
        var targetValueLines = 1;
        if (hasProtectedPair) {
          // The protected-pair branch above already tried label-first with the
          // complete value. If that was not possible, make both sides
          // breakable before continuing the same alternating progression.
          if (labelWordCount > 1) targetLabelLines++;
          if (valueWordCount > 1) targetValueLines++;
          addWrapTarget(targetLabelLines, targetValueLines);
        } else {
          while (targetValueLines < valueWordCount ||
              targetLabelLines < labelWordCount) {
            if (targetValueLines < valueWordCount) {
              targetValueLines++;
              addWrapTarget(targetLabelLines, targetValueLines);
            }
            if (targetLabelLines < labelWordCount) {
              targetLabelLines++;
              addWrapTarget(targetLabelLines, targetValueLines);
            }
          }
        }

        for (final target in wrapTargets) {
          if (findAllocation(target[0], target[1])) {
            foundAllocation = true;
            break;
          }
        }

        if (!foundAllocation) {
          final stackedRow = Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (leading != null) ...[
                SizedBox(width: leadingWidth, child: leading!),
                SizedBox(width: leadingGap),
              ],
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        label,
                        style: labelStyle,
                        textAlign: TextAlign.left,
                        softWrap: true,
                      ),
                    ),
                    const SizedBox(height: kWrappedLabelValueGap),
                    SizedBox(
                      width: double.infinity,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: trailing,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
          return _animateRowHeight(
            stackedRow,
            alignment: leading == null ? Alignment.topCenter : Alignment.center,
          );
        }

        final row = Row(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              SizedBox(width: leadingWidth, child: leading!),
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
        if (!alignTrailing) {
          return _animateRowHeight(
            row,
            alignment: leading == null ? Alignment.topCenter : Alignment.center,
          );
        }

        return _animateRowHeight(
          Row(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [Expanded(child: row)],
          ),
          alignment: leading == null ? Alignment.topCenter : Alignment.center,
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
/// the current OS text scale. Rows can opt into an adaptive date/time fallback:
/// keep the first pill beside the label when it fits and move the remaining
/// pills below, or move the whole group below when even the first pill cannot
/// fit beside the label. The default minimum gap is 25dp and can be tightened
/// for compact rows that prioritize keeping all content on one line.
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
    this.pillsBelowLabelOnWrap = false,
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

  /// When the full row does not fit, use the date/time fallback instead of
  /// keeping a stacked pill column beside the label. The first pill remains
  /// beside the label when it fits; otherwise the full group moves below.
  final bool pillsBelowLabelOnWrap;

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
      decoration: ShapeDecoration(
        color: pill.backgroundColor,
        // Keep the configured corner radius when Dynamic Type makes the pill
        // taller. A large capsule radius would change the shape as it wraps.
        shape: const BoundedSquircleStadiumBorder(
          radius: kSquircleStadiumRadius,
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
    List<AdaptivePillSpec> groupPills,
    List<double> naturalWidths, {
    required double maxWidth,
  }) {
    final naturalGroupWidth =
        naturalWidths.fold<double>(0.0, (sum, width) => sum + width) +
        (pillGap * math.max(0, groupPills.length - 1));
    final canStaySideBySide = naturalGroupWidth <= maxWidth;

    if (canStaySideBySide) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < groupPills.length; i++) ...[
            if (i > 0) SizedBox(width: pillGap),
            SizedBox(width: naturalWidths[i], child: _pill(groupPills[i])),
          ],
        ],
      );
    }

    if (groupPills.length == 1) {
      final pill = groupPills.single;
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
        for (var i = 0; i < groupPills.length; i++)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0.0 : pillGap),
            child: _pill(groupPills[i], maxWidth: maxWidth),
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
              pills,
              naturalWidths,
              maxWidth: naturalGroupWidth,
            ),
            alignLabelToTop: false,
          );
        }

        if (pillsBelowLabelOnWrap) {
          final fullRowWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : naturalGroupWidth;

          final pillGroupFitsOnSecondLevel =
              naturalGroupWidth <= fullRowWidth + 0.01;
          final firstPillFitsBesideLabel =
              pills.length > 1 &&
              labelWidth + labelValueGap + naturalWidths.first <=
                  constraints.maxWidth + 0.01;

          // Prefer keeping the complete date/time pair together below the
          // label. Split the pair only when it cannot fit side-by-side on that
          // second level.
          if (!pillGroupFitsOnSecondLevel && firstPillFitsBesideLabel) {
            final remainingPills = pills.sublist(1);
            final remainingWidths = naturalWidths.sublist(1);
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _labelAndPills(
                  label: SizedBox(
                    width: labelWidth,
                    child: _label(fillWidth: false),
                  ),
                  pillGroup: SizedBox(
                    width: naturalWidths.first,
                    child: _pill(pills.first),
                  ),
                  alignLabelToTop: false,
                ),
                SizedBox(height: verticalWrapGap),
                Align(
                  alignment: Alignment.centerRight,
                  child: _pillGroup(
                    context,
                    remainingPills,
                    remainingWidths,
                    maxWidth: fullRowWidth,
                  ),
                ),
              ],
            );
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _label(fillWidth: true),
              SizedBox(height: verticalWrapGap),
              Align(
                alignment: Alignment.centerRight,
                child: _pillGroup(
                  context,
                  pills,
                  naturalWidths,
                  maxWidth: fullRowWidth,
                ),
              ),
            ],
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
              !_pillsFitOnSingleLines(naturalWidths, availableTrailingWidth)) {
            final wrappedLabelWidth = _longestWordWidth(context);
            final wrappedTrailingWidth = math.max(
              0.0,
              constraints.maxWidth - wrappedLabelWidth - labelValueGap,
            );
            if (wrappedLabelWidth < labelWidth &&
                _pillsFitOnSingleLines(naturalWidths, wrappedTrailingWidth)) {
              return _labelAndPills(
                label: _label(
                  fillWidth: false,
                  allowWrap: true,
                  width: wrappedLabelWidth,
                ),
                pillGroup: _pillGroup(
                  context,
                  pills,
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
              pills,
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
              child: _pillGroup(
                context,
                pills,
                naturalWidths,
                maxWidth: fullRowWidth,
              ),
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

// ConcentricSquircleBorder — a bounded, parent-derived superellipse corner.
//
// The inset is intentionally part of the shape rather than a second arbitrary
// radius: the child curve is kept on the parent's corner-center system and its
// radius is reduced by the distance from that parent surface. The sampled
// superellipse is closer to Apple's continuous corners than a circular
// RoundedRectangle or a single cubic control point.
class ConcentricSquircleBorder extends ContinuousRectangleBorder {
  final double radius;
  final double inset;

  const ConcentricSquircleBorder({
    super.side,
    this.radius = kSquircleStadiumRadius,
    this.inset = 0,
  });

  static const int _cornerSegments = 8;
  static const double _superellipseExponent = 4.0;

  double _superellipseCoordinate(double value) {
    return math.pow(value.abs(), 2 / _superellipseExponent).toDouble();
  }

  void _addTopRightCorner(Path path, Rect rect, double cornerRadius) {
    final centerX = rect.right - cornerRadius;
    final centerY = rect.top + cornerRadius;
    for (var i = 1; i <= _cornerSegments; i++) {
      final t = (math.pi / 2) * i / _cornerSegments;
      path.lineTo(
        centerX + cornerRadius * _superellipseCoordinate(math.sin(t)),
        centerY - cornerRadius * _superellipseCoordinate(math.cos(t)),
      );
    }
  }

  void _addBottomRightCorner(Path path, Rect rect, double cornerRadius) {
    final centerX = rect.right - cornerRadius;
    final centerY = rect.bottom - cornerRadius;
    for (var i = 1; i <= _cornerSegments; i++) {
      final t = (math.pi / 2) * i / _cornerSegments;
      path.lineTo(
        centerX + cornerRadius * _superellipseCoordinate(math.cos(t)),
        centerY + cornerRadius * _superellipseCoordinate(math.sin(t)),
      );
    }
  }

  void _addBottomLeftCorner(Path path, Rect rect, double cornerRadius) {
    final centerX = rect.left + cornerRadius;
    final centerY = rect.bottom - cornerRadius;
    for (var i = 1; i <= _cornerSegments; i++) {
      final t = (math.pi / 2) * i / _cornerSegments;
      path.lineTo(
        centerX - cornerRadius * _superellipseCoordinate(math.sin(t)),
        centerY + cornerRadius * _superellipseCoordinate(math.cos(t)),
      );
    }
  }

  void _addTopLeftCorner(Path path, Rect rect, double cornerRadius) {
    final centerX = rect.left + cornerRadius;
    final centerY = rect.top + cornerRadius;
    for (var i = 1; i <= _cornerSegments; i++) {
      final t = (math.pi / 2) * i / _cornerSegments;
      path.lineTo(
        centerX - cornerRadius * _superellipseCoordinate(math.cos(t)),
        centerY - cornerRadius * _superellipseCoordinate(math.sin(t)),
      );
    }
  }

  Path _pathForRect(Rect rect) {
    if (rect.isEmpty) return Path();
    final double effectiveRadius = math.min<double>(
      math.max<double>(this.radius - inset, 0),
      math.min<double>(rect.width / 2, rect.height / 2),
    );
    final path = Path()..moveTo(rect.left + effectiveRadius, rect.top);

    // The straight segments are retained between sampled superellipse
    // quarters. This is what keeps the shape bounded on short buttons while
    // preserving Apple's soft transition into the vertical sides on sheets.
    path.lineTo(rect.right - effectiveRadius, rect.top);
    _addTopRightCorner(path, rect, effectiveRadius);
    path.lineTo(rect.right, rect.bottom - effectiveRadius);
    _addBottomRightCorner(path, rect, effectiveRadius);
    path.lineTo(rect.left + effectiveRadius, rect.bottom);
    _addBottomLeftCorner(path, rect, effectiveRadius);
    path.lineTo(rect.left, rect.top + effectiveRadius);
    _addTopLeftCorner(path, rect, effectiveRadius);
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

// BoundedSquircleStadiumBorder — the independent, fixed-radius four-corner
// shape used by the modal sheets. It deliberately does not derive geometry
// from a parent surface.
class BoundedSquircleStadiumBorder extends ContinuousRectangleBorder {
  final double radius;
  final bool topOnly;
  final bool bottomOnly;

  const BoundedSquircleStadiumBorder({
    super.side,
    this.radius = kSquircleStadiumRadius,
    this.topOnly = false,
    this.bottomOnly = false,
  });

  Path _pathForRect(Rect rect) {
    if (rect.isEmpty) return Path();
    final effectiveRadius = math.min(
      this.radius,
      math.min(rect.width / 2, rect.height / 2),
    );
    final topRadius = bottomOnly ? 0.0 : effectiveRadius;
    final bottomRadius = topOnly ? 0.0 : effectiveRadius;
    final topC = topRadius * _kSharedSquircleCurveControl;
    final bottomC = bottomRadius * _kSharedSquircleCurveControl;
    final path = Path()..moveTo(rect.left + topRadius, rect.top);
    path.lineTo(rect.right - topRadius, rect.top);
    path.cubicTo(
      rect.right - topRadius + topC,
      rect.top,
      rect.right,
      rect.top + topRadius - topC,
      rect.right,
      rect.top + topRadius,
    );
    path.lineTo(rect.right, rect.bottom - bottomRadius);
    if (bottomRadius > 0) {
      path.cubicTo(
        rect.right,
        rect.bottom - bottomRadius + bottomC,
        rect.right - bottomRadius + bottomC,
        rect.bottom,
        rect.right - bottomRadius,
        rect.bottom,
      );
    } else {
      path.lineTo(rect.right, rect.bottom);
    }
    path.lineTo(rect.left + bottomRadius, rect.bottom);
    if (bottomRadius > 0) {
      path.cubicTo(
        rect.left + bottomRadius - bottomC,
        rect.bottom,
        rect.left,
        rect.bottom - bottomRadius + bottomC,
        rect.left,
        rect.bottom - bottomRadius,
      );
    } else {
      path.lineTo(rect.left, rect.bottom);
    }
    path.lineTo(rect.left, rect.top + topRadius);
    path.cubicTo(
      rect.left,
      rect.top + topRadius - topC,
      rect.left + topRadius - topC,
      rect.top,
      rect.left + topRadius,
      rect.top,
    );
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
    final scaledChevronWidth = MediaQuery.textScalerOf(
      context,
    ).scale(kModalSheetPickerChevronSize);
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (valuePrefix != null) ...[valuePrefix!, const SizedBox(width: 6)],
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) => Text(
              chevronValueTextForWidth(
                context,
                value,
                style,
                constraints.maxWidth,
              ),
              style: style,
              textAlign: TextAlign.right,
              softWrap: true,
              // Let the prefix sit beside the painted text block instead of
              // beside the full flexible slot when the value wraps.
              textWidthBasis: TextWidthBasis.longestLine,
            ),
          ),
        ),
        if (showChevron) ...[
          const SizedBox(width: kModalSheetPickerChevronGap),
          SizedBox(
            width: scaledChevronWidth,
            child: SplitChevronUpDown(color: chevronColor),
          ),
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
    this.tileMode = TileMode.decal,
    this.enableBackdropFilter = true,
    this.fillOpacity = 0.80,
    this.shadowOpacity = 0.22,
    this.shadowBlurRadius = 28.0,
    this.cornerRadius = kCornerRadius,
    this.border,
    // Optional per-corner override — when set, takes precedence over
    // cornerRadius and allows asymmetric squircle shapes (e.g. top-only).
    this.borderRadius,
    this.stadium = false,
    this.shape,
  });

  /// Animation progress: 0.0 (invisible) → 1.0 (fully open).
  final double progress;
  final Widget child;

  /// Maximum BackdropFilter blur sigma at progress = 1.
  final double blurSigma;

  /// Sampling mode used outside the filtered input bounds. Shell controls can
  /// opt into clamping because they remain mounted in a permanent overlay
  /// stack on Android.
  final TileMode tileMode;

  /// Allows always-mounted shell controls to keep the translucent glass
  /// surface while avoiding a full-scene backdrop layer on Android.
  final bool enableBackdropFilter;

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

  /// When non-null, preserves legacy per-corner shaping for callers that need
  /// an asymmetric rectangle rather than the shared bounded stadium.
  final BorderRadius? borderRadius;

  /// Retained for source compatibility with older callers. All default cards
  /// now use the app-owned bounded squircle stadium.
  final bool stadium;

  /// Optional complete shape override for bounded stadium cards.
  final ShapeBorder? shape;

  @override
  Widget build(BuildContext context) {
    final blur = blurSigma * progress;
    final fill = (fillOpacity * progress).clamp(0.0, 1.0);
    final shadow = CupertinoTheme.brightnessOf(context) == Brightness.dark
        ? 0.0
        : shadowOpacity * progress;
    final effectiveShape =
        shape ??
        (borderRadius == null
            ? BoundedSquircleStadiumBorder(
                radius: cornerRadius,
                side: border ?? BorderSide.none,
              )
            : BoundedContinuousRectangleBorder(
                borderRadius: borderRadius!,
                side: border ?? BorderSide.none,
              ));

    return DecoratedBox(
      decoration: ShapeDecoration(
        shadows: resolveThemeShadows([
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, shadow),
            blurRadius: shadowBlurRadius,
            offset: const Offset(0, 8),
          ),
        ], context),
        shape: effectiveShape,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: effectiveShape),
        child: Builder(
          builder: (context) {
            final glassSurface = ColoredBox(
              color: resolveThemeColor(
                kGlassFillColor,
                context,
              ).withValues(alpha: fill),
              child: child,
            );
            if (!enableBackdropFilter) return glassSurface;
            return BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: blur,
                sigmaY: blur,
                tileMode: tileMode,
              ),
              child: glassSurface,
            );
          },
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
    this.shape,
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
  final ShapeBorder? shape;

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
            shape: widget.shape,
            child: child!,
          ),
        );
      },
      child: widget.child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// GelBloomButton — compatibility wrapper for the app's gel-bloom controls.
//
// All tap surfaces go through LiquidGlassButton from liquid_glass_easy.  The
// package owns the glass lens and its native-feeling flex/pop response; this
// wrapper only keeps the existing call-site API and delayed-dismiss behavior.
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

/// Child marker used by [GelBloomButton] to retain compact circular geometry
/// and the material fallback behind LiquidGlassButton.
class LiquidGlassGelCircle extends StatelessWidget {
  const LiquidGlassGelCircle({
    super.key,
    required this.color,
    required this.child,
    this.size = 40,
    this.isCheckmark = false,
    this.showShadow = true,
  });

  final Color color;
  final Widget child;
  final double size;
  final bool isCheckmark;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// The rich, fixed-color action button for circular controls.
///
/// This is the const public wrapper for the historical app-owned glass
/// renderer. The visual lens is kept in [_GelBloomButtonState] so existing
/// delayed-dismiss and tap-bloom behavior remains unchanged.
class StaticLiquidGlassActionButton extends StatelessWidget {
  const StaticLiquidGlassActionButton({
    super.key,
    required this.color,
    required this.child,
    required this.onTap,
    this.size = 40,
    this.isCheckmark = false,
    this.showShadow = true,
    this.peakScale = 1.15,
    this.tapDelay = Duration.zero,
  });

  final Color color;
  final Widget child;
  final VoidCallback onTap;
  final double size;
  final bool isCheckmark;
  final bool showShadow;
  final double peakScale;
  final Duration tapDelay;

  @override
  Widget build(BuildContext context) {
    return GelBloomButton(
      peakScale: peakScale,
      tapDelay: tapDelay,
      onTap: onTap,
      child: LiquidGlassGelCircle(
        color: color,
        size: size,
        isCheckmark: isCheckmark,
        showShadow: showShadow,
        child: child,
      ),
    );
  }
}

LiquidGlassShape _staticLiquidGlassShape({
  required double cornerRadius,
  bool showOpticalBorder = true,
}) {
  return LiquidGlassShape.squircle(
    cornerRadius: cornerRadius,
    borderWidth: showOpticalBorder ? 0.5 : 0,
    lightIntensity: showOpticalBorder ? 0.38 : 0,
    lightDirection: 62,
    borderType: const OpticalBorder(
      borderSaturation: 1.0,
      ambientIntensity: 0.18,
      borderSolidity: 0.16,
      lightSpread: 0.14,
    ),
  );
}

LiquidGlassStyle _staticLiquidGlassStyle({
  required Color glassColor,
  required double cornerRadius,
  bool showOpticalBorder = true,
}) {
  // Build the shared optical style directly instead of copying
  // LiquidGlassButton.defaultStyle. This keeps the renderer identical while
  // ensuring action-button appearance settings, including its shadow policy,
  // can never leak into non-interactive surfaces.
  return LiquidGlassStyle(
    appearance: LiquidGlassAppearance(
      color: glassColor,
      blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
      // Static surfaces receive their app-owned BoxShadow outside the lens.
      shadow: null,
    ),
    // Keep the historical rich renderer's geometry while removing the three
    // requested optical effects: refraction, magnification, and chromatic
    // aberration.
    refraction: const LiquidGlassRefraction(
      distortion: 0,
      distortionWidth: 0,
      magnification: 1,
      chromaticAberration: 0,
    ),
    shape: _staticLiquidGlassShape(
      cornerRadius: cornerRadius,
      showOpticalBorder: showOpticalBorder,
    ),
  );
}

double _staticLiquidGlassSurfaceCornerRadius(ShapeBorder shape) {
  if (shape is BoundedSquircleStadiumBorder) return shape.radius;
  if (shape is SquircleStadiumBorder) return shape.radius;
  return kCornerRadius;
}

/// A non-interactive rich Liquid Glass surface for cards and panels.
///
/// This is intentionally separate from [StaticLiquidGlassActionButton]:
/// there is no gesture detector, bloom animation, or tap callback. It paints
/// the same historical lens treatment as the action button, without the
/// button-only interaction and animation layers.
class StaticLiquidGlassSurface extends StatelessWidget {
  const StaticLiquidGlassSurface({
    super.key,
    required this.color,
    required this.child,
    this.shape = const BoundedSquircleStadiumBorder(),
  });

  final Color color;
  final Widget child;
  final ShapeBorder shape;

  @override
  Widget build(BuildContext context) {
    final cornerRadius = _staticLiquidGlassSurfaceCornerRadius(shape);
    // Static surfaces are solid app-owned fills. Keep the caller's color
    // opaque so these surfaces match a normal Container using the same color.
    // All current and future StaticLiquidGlassSurface instances inherit this
    // policy from the shared implementation.
    final glassColor = color.withValues(alpha: 1.0);
    final cardShadows = resolveThemeShadows(kCardShadow, context);
    return CustomPaint(
      painter: _StaticLiquidGlassSurfacePainter(
        shape: shape,
        shadows: cardShadows,
      ),
      child: IntrinsicHeight(
        child: ClipPath(
            clipper: ShapeBorderClipper(shape: shape),
            child: LiquidGlassView(
              key: ValueKey<int>(color.toARGB32()),
              backgroundWidget: ClipPath(
                clipper: ShapeBorderClipper(shape: shape),
                child: ColoredBox(color: glassColor),
              ),
              realTimeCapture: false,
              useSync: true,
               // Static surfaces have no live refraction and must stay
               // attached to their local route transform. The screen-space
               // Impeller filter can drift when the covered route is scaled
               // by a Cupertino sheet. Native surfaces therefore use the
               // same local capture path as the stable action-button glass.
               // Keep web automatic so CanvasKit continues using its supported
               // capture implementation without forcing an unsupported mode.
               useImpellerBackdrop: kIsWeb ? null : false,
              child: LiquidGlassLens(
                style: _staticLiquidGlassStyle(
                  glassColor: glassColor,
                  cornerRadius: cornerRadius,
                  // Static surfaces never use an optical edge rim. This is
                  // intentionally not configurable on the surface API.
                  showOpticalBorder: false,
                ),
                // No LiquidGlassTouch: this surface is deliberately inert.
                child: child,
              ),
            ),
        ),
      ),
    );
  }
}

class _StaticLiquidGlassSurfacePainter extends CustomPainter {
  const _StaticLiquidGlassSurfacePainter({
    required this.shape,
    required this.shadows,
  });

  final ShapeBorder shape;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect);
    for (final shadow in shadows) {
      canvas.drawShadow(
        path.shift(shadow.offset),
        shadow.color,
        shadow.blurRadius,
        true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _StaticLiquidGlassSurfacePainter oldDelegate) =>
      oldDelegate.shape != shape ||
      oldDelegate.shadows != shadows;
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

  Widget _buildLiquidGlassButton(
    BuildContext context,
    LiquidGlassGelCircle circle,
  ) {
    final isLightMode =
        CupertinoTheme.brightnessOf(context) == Brightness.light;
    // Close/back/search controls are white in Light Mode. Save buttons are
    // deliberately excluded so accent and disabled checkmark surfaces remain
    // meaningful.
    final surfaceColor = circle.isCheckmark || !isLightMode
        ? circle.color
        : const Color(0xFFFFFFFF);
    final glassColor = circle.isCheckmark && isLightMode
        ? surfaceColor
        : surfaceColor.withValues(alpha: 0.8);
    final style = _staticLiquidGlassStyle(
      glassColor: glassColor,
      cornerRadius: circle.size / 2,
    );

    final glass = ClipOval(
          child: SizedBox.square(
            dimension: circle.size,
            // Keep the package's real shader active when this control sits
            // above an occluding route. The local view captures a stable
            // backdrop once and the lens evaluates its optical rim against
            // that cached image.
            child: DecoratedBox(
              // This is deliberately separate from the glass lens' optical
              // rim light: it is a stable, white 15% hairline around the
              // complete button silhouette in both appearances.
              position: DecorationPosition.foreground,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                border: Border.fromBorderSide(
                  BorderSide(color: Color(0x26FFFFFF), width: 0.5),
                ),
              ),
              child: LiquidGlassView(
                // This view keeps a one-shot backdrop capture for stable,
                // inexpensive optical lighting. Recreate that capture when
                // a category/checkmark surface changes color; otherwise the
                // lens body updates while its rim still refracts the old
                // color from the cached sheet backdrop.
                key: ValueKey<int>(surfaceColor.toARGB32()),
                // LiquidGlassView paints its capture surface as a rectangle.
                // The backgroundWidget clip alone is not enough: the view/lens
                // output can still expose that rectangular surface on Android.
                // Clip the complete view so the gel remains circular.
                backgroundWidget: ClipOval(
                  child: ColoredBox(color: surfaceColor.withValues(alpha: 0.8)),
                ),
                realTimeCapture: false,
                useSync: true,
                useImpellerBackdrop: false,
                child: LiquidGlassLens(
                  style: style,
                  // The wrapper owns the same bloom as regular GelBloomButton.
                  // Avoid a second package flex animation changing the scale
                  // and making this path look flatter or out of sync.
                  touch: const LiquidGlassTouch(),
                  child: GestureDetector(
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
                    child: Center(child: circle.child),
                  ),
                ),
              ),
            ),
          ),
        );
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) =>
          Transform.scale(scale: _scale.value, child: child),
      // Apply the same pronounced gel bloom used by the non-glass path. The
      // old LiquidGlass branch only received the package's flexing response,
      // so its tap bloom looked noticeably flatter than regular buttons.
      child: circle.showShadow
          ? LiquidGlassShadow(
              // Keep this close to the silhouette: it is an edge-defining
              // ring, not a broad elevation shadow.
              blur: isLightMode ? 8.0 : 2.25,
              opacity: isLightMode ? 0.20 : 0.0,
              offset: const Offset(1.0, 1.5),
              cornerRadius: circle.size / 2,
              child: glass,
            )
          : glass,
    );
  }

  @override
  Widget build(BuildContext context) {
    final circle = widget.child is LiquidGlassGelCircle
        ? widget.child as LiquidGlassGelCircle
        : null;
    if (circle != null) {
      return _buildLiquidGlassButton(context, circle);
    }

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
