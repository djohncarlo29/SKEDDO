import 'dart:ui' show Color;

/// Shared dimensions and neutral tint for touch-following glass highlights.
///
/// Keep the radius and blur consistent across buttons, menus, sheets, and
/// navigation surfaces. Theme-aware callers select the matching surface tint.
abstract final class GlassInteractionGlowDefaults {
  /// Shared radius as a proportion of the glow layer's shortest side.
  static const double radius = 1.6;

  /// Shared Gaussian blur sigma, in logical pixels.
  static const double blurRadius = 16;

  /// Shared additive spread beyond the animated radius.
  static const double spreadRadius = 0;

  /// Shared opacity multiplier.
  static const double opacity = 1;

  /// Neutral touch glow for light surfaces.
  static const Color lightModeColor = Color(0x1A000000);

  /// Neutral touch glow for dark surfaces.
  static const Color darkModeColor = Color(0x26FFFFFF);
}
