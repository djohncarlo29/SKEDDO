import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassThemeVariant, LiquidGlassSettings;

/// Shared optical settings for the package-rendered floating tab bar and
/// standalone modal toolbar GlassIconButtons.
///
/// These retain flutter_liquid_glass_widgets' bottom-bar optics while using
/// SKEDDO's explicit, mode-specific tint colors and opacities.
const double kSkeddoLightBottomBarOpacity = 0.20;
const double kSkeddoDarkBottomBarOpacity = 0.30;
const double kSkeddoTintedActionGlassOpacity = 0.85;

const LiquidGlassSettings _packageBottomBarGlassDefaults = LiquidGlassSettings(
  blendMode: BlendMode.screen,
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
        0x2C,
        0x2C,
        0x2E,
        kSkeddoDarkBottomBarOpacity,
      ),
      blendMode: BlendMode.overlay,
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

/// Preserves the shared renderer's optics while tinting an enabled action
/// button's glass with its accent/category color.
LiquidGlassSettings skeddoTintedActionGlassSettingsFor(
  Brightness brightness,
  Color tint,
) => skeddoBottomBarGlassSettingsFor(brightness).copyWith(
  glassColor: tint.withValues(alpha: kSkeddoTintedActionGlassOpacity),
);
