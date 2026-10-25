import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassThemeVariant, LiquidGlassSettings;

/// Shared optical settings for the package-rendered floating tab bar and
/// standalone modal toolbar GlassIconButtons.
///
/// These retain flutter_liquid_glass_widgets' bottom-bar optics while using
/// SKEDDO's explicit, mode-specific tint colors and opacities.
const double kSkeddoLightBottomBarOpacity = 0.40;
const double kSkeddoDarkBottomBarOpacity = 0.50;
const double kSkeddoPopoverGlassOpacity = 1.0;
const double kSkeddoTintedActionGlassOpacity = 0.85;
const double kSkeddoActiveCheckmarkFillOpacity = 0.85;
const double kSkeddoActiveCheckmarkRefractionOverlayOpacity = 0.30;

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

LiquidGlassSettings skeddoBottomBarGlassSettingsFor(Brightness brightness) =>
    brightness == Brightness.dark
    ? kSkeddoDarkBottomBarGlassSettings
    : kSkeddoBottomBarGlassSettings;

/// Keeps the floating tab-bar shell clear while leaving its selected glass
/// indicator on the package's separate blur settings.
LiquidGlassSettings skeddoTabBarGlassSettingsFor(Brightness brightness) =>
    skeddoBottomBarGlassSettingsFor(brightness).copyWith(blur: 1);

/// Discard popovers use an opaque card tint while retaining the package's
/// existing optical settings and edge lighting.
LiquidGlassSettings skeddoPopoverGlassSettingsFor(
  Brightness brightness,
  Color cardTint,
) {
  final shared = skeddoBottomBarGlassSettingsFor(brightness);
  return shared.copyWith(
    glassColor: cardTint.withValues(alpha: kSkeddoPopoverGlassOpacity),
  );
}

/// Gives the discard action its own opaque modal-button tint without adding
/// optical edge treatments or a button shadow. The containing popover keeps its
/// independent glass lighting and shadow.
LiquidGlassSettings skeddoPopoverButtonGlassSettingsFor(
  Brightness brightness,
  Color buttonTint,
) {
  final popover = skeddoBottomBarGlassSettingsFor(brightness);
  return popover.copyWith(
    glassColor: buttonTint.withValues(alpha: kSkeddoPopoverGlassOpacity),
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
) => skeddoBottomBarGlassSettingsFor(brightness).copyWith(
  glassColor: tint.withValues(alpha: kSkeddoTintedActionGlassOpacity),
);

/// Settings for the full-strength lighting/rim layer above an active fill.
///
/// The package's premium shader preserves backdrop luminance when tinting
/// chromatic glass. On a bright background, that operation can shift a blue
/// accent toward cyan. Active checkmarks therefore use a clear glass layer
/// over an opaque accent base. This top layer keeps the shared Fresnel rim and
/// lighting, but does not displace the base color.
LiquidGlassSettings skeddoActiveCheckmarkGlassSettingsFor(
  Brightness brightness,
) => skeddoBottomBarGlassSettingsFor(brightness).copyWith(
  glassColor: const Color(0x00FFFFFF),
  saturation: 1,
  refractiveIndex: 1,
  chromaticAberration: 0,
  shadowElevation: 0,
);

/// Refraction is rendered separately so its sampled edge colors are blended
/// over the solid category fill rather than replacing it.
LiquidGlassSettings skeddoActiveCheckmarkRefractionSettingsFor(
  Brightness brightness,
) => skeddoBottomBarGlassSettingsFor(brightness).copyWith(
  glassColor: const Color(0x00FFFFFF),
  saturation: 1,
  chromaticAberration: 0,
  fresnelStrength: 0,
  ambientRim: 0,
  lightIntensity: 0,
  ambientStrength: 0,
  shadowElevation: 0,
);
