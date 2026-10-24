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
const double kSkeddoPopoverGlassOpacity = 0.85;
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
    LiquidGlassSettings(glassColor: Color.fromRGBO(0, 0, 0, 0.04));

LiquidGlassSettings skeddoBottomBarGlassSettingsFor(Brightness brightness) =>
    brightness == Brightness.dark
    ? kSkeddoDarkBottomBarGlassSettings
    : kSkeddoBottomBarGlassSettings;

/// Popovers use the shared glass optics with the original modal card tint.
LiquidGlassSettings skeddoPopoverGlassSettingsFor(
  Brightness brightness,
  Color cardTint,
) {
  final shared = skeddoBottomBarGlassSettingsFor(brightness);
  return shared.copyWith(
    glassColor: cardTint.withValues(alpha: kSkeddoPopoverGlassOpacity),
  );
}

/// GlassButtonStyle.prominent multiplies its input tint alpha by 2.5.
/// Dividing the requested opacity by that factor keeps this popover action at
/// the same effective 85% as its card. Its hue comes from the original modal
/// button surface rather than the shared renderer's neutral tint.
LiquidGlassSettings skeddoPopoverButtonGlassSettingsFor(
  Brightness brightness,
  Color buttonTint,
) {
  final popover = skeddoBottomBarGlassSettingsFor(brightness);
  return popover.copyWith(
    glassColor: buttonTint.withValues(
      alpha: kSkeddoPopoverGlassOpacity / 2.5,
    ),
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
