import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassThemeVariant, LiquidGlassSettings;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass;

import '../app_settings.dart';

/// Shared optical settings for the package-rendered floating tab bar and
/// standalone modal toolbar GlassIconButtons.
///
/// These retain flutter_liquid_glass_widgets' bottom-bar optics while using
/// SKEDDO's explicit tint colors and slider-driven opacity. The constants are
/// the shared renderer opacity at the remapped 50% slider mark.
const double kSkeddoLightBottomBarOpacity = 0.528;
const double kSkeddoDarkBottomBarOpacity = 0.628;

/// GlassPopover card and button opacity at the remapped 50% slider mark.
const double kSkeddoPopoverGlassOpacity = 0.907;
const double kSkeddoTintedActionGlassOpacity = 0.85;
const double kSkeddoActiveCheckmarkFillOpacity = 0.85;
const double kSkeddoActiveCheckmarkRefractionOverlayOpacity = 0.30;
const double _kActiveCheckmarkGlassSliderReference = 0.5;
const double _kOldSliderPositionForNewMidpoint = 0.57;

const LiquidGlassSettings _packageBottomBarGlassDefaults = LiquidGlassSettings(
  thickness: 30,
  blur: 3,
  chromaticAberration: 0.3,
  lightIntensity: 0.6,
  refractiveIndex: 1.59,
  saturation: 0.7,
  ambientStrength: 1,
  lightAngle: 0.75 * math.pi,
  glassColor: Color(0x3DFFFFFF),
);

final LiquidGlassSettings kSkeddoBottomBarGlassSettings =
    _packageBottomBarGlassDefaults.copyWith(
      glassColor: const Color.fromRGBO(
        0xFF,
        0xFF,
        0xFF,
        kSkeddoLightBottomBarOpacity,
      ),
    );

final LiquidGlassSettings kSkeddoDarkBottomBarGlassSettings =
    kSkeddoBottomBarGlassSettings.copyWith(
      glassColor: const Color.fromRGBO(
        0x3E,
        0x3E,
        0x40,
        kSkeddoDarkBottomBarOpacity,
      ),
      lightAngle: GlassThemeVariant.dark.settings!.lightAngle,
      lightIntensity: GlassThemeVariant.dark.settings!.lightIntensity,
      ambientStrength: GlassThemeVariant.dark.settings!.ambientStrength,
    );

/// A reduced, deliberately subtle tint for the lifted selected-tab lens in
/// Light Mode. Dark Mode continues to use the package's transparent default.
const LiquidGlassSettings kSkeddoLightLiftedTabIndicatorSettings =
    LiquidGlassSettings(
      glassColor: Color.fromRGBO(0, 0, 0, 0.04),
      // The package only paints this indicator shadow when the elevation is
      // explicitly different from its default. Keep it close to the native
      // baseline so the lifted lens gains depth without a heavy halo.
      shadowElevation: 1.2,
    );

LiquidGlassSettings skeddoBottomBarGlassSettingsFor(
  Brightness brightness, {
  double? sliderPosition,
}) => _settingsForSharedGlassPosition(
  brightness,
  sliderPosition ??
      liquidGlassSliderPositionForOpacity(appLiquidGlassOpacityNotifier.value),
);

const _kSharedGlassBlurAnchors = <(double, double)>[
  (0, 0.01),
  (25, 0.5),
  (50, 1),
  (75, 3.5),
  (100, 10),
];

const _kActiveTabIndicatorBlurAnchors = <(double, double)>[
  (0, 0.5),
  (25, 1),
  (50, 2),
  (75, 4.5),
  (100, 12),
];

const _kSharedGlassLightOpacityAnchors = <(double, double)>[
  (0, 0.20),
  (25, 0.35),
  (50, 0.50),
  (75, 0.60),
  (100, 0.70),
];

const _kSharedGlassDarkOpacityAnchors = <(double, double)>[
  (0, 0.30),
  (25, 0.45),
  (50, 0.60),
  (75, 0.70),
  (100, 0.80),
];

const _kPopoverOpacityAnchors = <(double, double)>[
  (0, 0.85),
  (25, 0.875),
  (50, 0.90),
  (75, 0.925),
  (100, 0.95),
];

const _kPopoverBlurAnchors = <(double, double)>[
  (0, 1),
  (25, 2.5),
  (50, 5),
  (75, 7.5),
  (100, 10),
];

double _interpolateSliderAnchors(
  double position,
  List<(double, double)> anchors,
) {
  final percent = position.clamp(0.0, 1.0).toDouble() * 100;
  for (var index = 0; index < anchors.length - 1; index++) {
    final lower = anchors[index];
    final upper = anchors[index + 1];
    if (percent <= upper.$1) {
      final progress = (percent - lower.$1) / (upper.$1 - lower.$1);
      return lower.$2 + (upper.$2 - lower.$2) * progress;
    }
  }
  return anchors.last.$2;
}

/// Remaps the slider coordinate so 50% preserves the effects formerly produced
/// at 57%, while 0% and 100% keep their original endpoint effects.
double skeddoLiquidGlassEffectPositionForSliderPosition(double position) {
  final normalized = position.clamp(0.0, 1.0).toDouble();
  if (normalized <= 0.5) {
    return normalized * (_kOldSliderPositionForNewMidpoint / 0.5);
  }
  return _kOldSliderPositionForNewMidpoint +
      (normalized - 0.5) * ((1 - _kOldSliderPositionForNewMidpoint) / 0.5);
}

/// Backdrop blur for the shared Liquid Glass renderer, interpolated between
/// the slider's explicitly specified percentage anchors.
double skeddoSharedGlassBlurForPosition(double position) =>
    _interpolateSliderAnchors(
      skeddoLiquidGlassEffectPositionForSliderPosition(position),
      _kSharedGlassBlurAnchors,
    );

/// Backdrop blur for the settled active-tab lens. It uses a separate slider
/// curve from the surrounding tab-bar shell.
double skeddoActiveTabIndicatorBlurForPosition(double position) =>
    _interpolateSliderAnchors(
      skeddoLiquidGlassEffectPositionForSliderPosition(position),
      _kActiveTabIndicatorBlurAnchors,
    );

/// Slider-driven tint opacity for shared renderer surfaces. The GlassPopover
/// intentionally uses its own fixed opacity.
double skeddoSharedGlassOpacityForPosition(
  double position,
  Brightness brightness,
) => _interpolateSliderAnchors(
  skeddoLiquidGlassEffectPositionForSliderPosition(position),
  brightness == Brightness.dark
      ? _kSharedGlassDarkOpacityAnchors
      : _kSharedGlassLightOpacityAnchors,
);

/// Independent opacity curve used by both GlassPopover surfaces.
double skeddoPopoverOpacityForPosition(double position) =>
    _interpolateSliderAnchors(
      skeddoLiquidGlassEffectPositionForSliderPosition(position),
      _kPopoverOpacityAnchors,
    );

/// Independent blur curve used by the GlassPopover card.
double skeddoPopoverBlurForPosition(double position) =>
    _interpolateSliderAnchors(
      skeddoLiquidGlassEffectPositionForSliderPosition(position),
      _kPopoverBlurAnchors,
    );

LiquidGlassSettings _settingsForSharedGlassPosition(
  Brightness brightness,
  double position,
) {
  final base = brightness == Brightness.dark
      ? kSkeddoDarkBottomBarGlassSettings
      : kSkeddoBottomBarGlassSettings;
  return base.copyWith(
    blur: skeddoSharedGlassBlurForPosition(position),
    glassColor: base.glassColor.withValues(
      alpha: skeddoSharedGlassOpacityForPosition(position, brightness),
    ),
  );
}

/// Bridges the slider-driven shared optical values into the separate
/// navigation package's settings type without using that package's defaults.
navigation_glass.LiquidGlassSettings skeddoPinnedNavigationGlassSettingsFor(
  Brightness brightness, {
  double? sliderPosition,
  double visibility = 1,
}) {
  final shared = skeddoBottomBarGlassSettingsFor(
    brightness,
    sliderPosition: sliderPosition,
  );
  final specularSharpness = switch (shared.specularSharpness.name) {
    'soft' => navigation_glass.GlassSpecularSharpness.soft,
    'sharp' => navigation_glass.GlassSpecularSharpness.sharp,
    _ => navigation_glass.GlassSpecularSharpness.medium,
  };

  return navigation_glass.LiquidGlassSettings(
    visibility: visibility.clamp(0.0, 1.0).toDouble(),
    glassColor: shared.glassColor,
    thickness: shared.thickness,
    blur: shared.blur,
    chromaticAberration: shared.chromaticAberration,
    lightAngle: shared.lightAngle,
    lightIntensity: shared.lightIntensity,
    ambientStrength: shared.ambientStrength,
    ambientRim: shared.ambientRim,
    fresnelStrength: shared.fresnelStrength,
    refractiveIndex: shared.refractiveIndex,
    saturation: shared.saturation,
    glowIntensity: shared.glowIntensity,
    specularSharpness: specularSharpness,
    standardOpacityMultiplier: shared.standardOpacityMultiplier,
    shadowElevation: shared.shadowElevation,
    shadow: shared.shadow,
    whitenStrength: shared.whitenStrength,
    whitenGated: shared.whitenGated,
    backerColor: shared.backerColor,
    platformViewFallbackColor: shared.platformViewFallbackColor,
  );
}

/// The floating tab-bar shell defines the blur value shared by SKEDDO's
/// package-rendered glass surfaces. The settled active-tab lens remains
/// independent through its own [GlassTabBar.innerBlur] slider curve.
LiquidGlassSettings skeddoTabBarGlassSettingsFor(Brightness brightness) =>
    skeddoBottomBarGlassSettingsFor(brightness);

/// Discard popovers use an opaque card tint while retaining the package's
/// existing optical settings and edge lighting.
LiquidGlassSettings skeddoPopoverGlassSettingsFor(
  Brightness brightness,
  Color cardTint, {
  double? sliderPosition,
}) {
  final position =
      sliderPosition ??
      liquidGlassSliderPositionForOpacity(appLiquidGlassOpacityNotifier.value);
  final shared = skeddoBottomBarGlassSettingsFor(
    brightness,
    sliderPosition: position,
  );
  return shared.copyWith(
    blur: skeddoPopoverBlurForPosition(position),
    glassColor: cardTint.withValues(
      alpha: skeddoPopoverOpacityForPosition(position),
    ),
  );
}

/// Gives the discard action its own opaque modal-button tint without adding
/// optical edge treatments or a button shadow. The containing popover keeps its
/// independent glass lighting and shadow.
LiquidGlassSettings skeddoPopoverButtonGlassSettingsFor(
  Brightness brightness,
  Color buttonTint, {
  double? sliderPosition,
}) {
  final position =
      sliderPosition ??
      liquidGlassSliderPositionForOpacity(appLiquidGlassOpacityNotifier.value);
  final popover = skeddoBottomBarGlassSettingsFor(
    brightness,
    sliderPosition: position,
  );
  return popover.copyWith(
    glassColor: buttonTint.withValues(
      alpha: skeddoPopoverOpacityForPosition(position),
    ),
    thickness: 0,
    blur: 0,
    chromaticAberration: 0,
    lightIntensity: 0,
    ambientStrength: 0,
    ambientRim: 0,
    fresnelStrength: 0,
    refractiveIndex: 1,
    saturation: 1,
    glowIntensity: 0,
    shadowElevation: 0,
    shadow: const [],
  );
}

/// Preserves the shared renderer's optics while tinting an enabled action
/// button's glass with its accent/category color.
LiquidGlassSettings skeddoTintedActionGlassSettingsFor(
  Brightness brightness,
  Color tint,
) => skeddoBottomBarGlassSettingsFor(
  brightness,
).copyWith(glassColor: tint.withValues(alpha: kSkeddoTintedActionGlassOpacity));

/// Settings for the full-strength lighting/rim layer above an active fill.
///
/// The package's premium shader preserves backdrop luminance when tinting
/// chromatic glass. On a bright background, that operation can shift a blue
/// accent toward cyan. Active checkmarks therefore use a clear glass layer
/// over an opaque accent base. This top layer keeps the shared Fresnel rim and
/// lighting, but does not displace the base color. It stays at the 50% slider
/// reference so active checkmarks are unaffected by slider changes.
LiquidGlassSettings skeddoActiveCheckmarkGlassSettingsFor(
  Brightness brightness,
) =>
    skeddoBottomBarGlassSettingsFor(
      brightness,
      sliderPosition: _kActiveCheckmarkGlassSliderReference,
    ).copyWith(
      glassColor: const Color(0x00FFFFFF),
      saturation: 1,
      refractiveIndex: 1,
      chromaticAberration: 0,
      shadowElevation: 0,
    );

/// Refraction is rendered separately so its sampled edge colors are blended
/// over the solid category fill rather than replacing it. Its slider reference
/// matches the active checkmark's fixed lighting layer.
LiquidGlassSettings skeddoActiveCheckmarkRefractionSettingsFor(
  Brightness brightness,
) =>
    skeddoBottomBarGlassSettingsFor(
      brightness,
      sliderPosition: _kActiveCheckmarkGlassSliderReference,
    ).copyWith(
      glassColor: const Color(0x00FFFFFF),
      saturation: 1,
      chromaticAberration: 0,
      fresnelStrength: 0,
      ambientRim: 0,
      lightIntensity: 0,
      ambientStrength: 0,
      shadowElevation: 0,
    );
