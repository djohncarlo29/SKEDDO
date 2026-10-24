import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassThemeVariant, LiquidGlassSettings;

/// Shared optical settings for the package-rendered floating tab bar and
/// standalone modal toolbar GlassIconButtons.
///
/// These use flutter_liquid_glass_widgets' bottom-bar optical settings with a
/// 10-percentage-point increase to the glass tint opacity. Keeping them shared
/// prevents standalone package buttons from falling back to weaker general
/// GlassTheme defaults.
const double kSkeddoBottomBarOpacityIncrease = 0.10;

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
      glassColor: _increaseGlassOpacity(
        _packageBottomBarGlassDefaults.glassColor,
      ),
    );

final LiquidGlassSettings kSkeddoDarkBottomBarGlassSettings =
    kSkeddoBottomBarGlassSettings.copyWith(
      glassColor: _increaseGlassOpacity(
        GlassThemeVariant.dark.settings!.glassColor!,
      ),
      lightAngle: GlassThemeVariant.dark.settings!.lightAngle,
      lightIntensity: GlassThemeVariant.dark.settings!.lightIntensity,
      ambientStrength: GlassThemeVariant.dark.settings!.ambientStrength,
    );

/// A deliberately subtle tint for the lifted selected-tab lens in Light Mode.
/// Dark Mode continues to use the package's transparent indicator default.
const LiquidGlassSettings kSkeddoLightLiftedTabIndicatorSettings =
    LiquidGlassSettings(glassColor: Color.fromRGBO(0, 0, 0, 0.08));

Color _increaseGlassOpacity(Color color) => color.withValues(
  alpha: (color.a + kSkeddoBottomBarOpacityIncrease).clamp(0.0, 1.0),
);

LiquidGlassSettings skeddoBottomBarGlassSettingsFor(Brightness brightness) =>
    brightness == Brightness.dark
    ? kSkeddoDarkBottomBarGlassSettings
    : kSkeddoBottomBarGlassSettings;
