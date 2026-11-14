import 'package:flutter/cupertino.dart';

import '../../constants/glass_defaults.dart';
import '../../src/engine/glass_glow.dart' show GlassGlow;
import '../../src/engine/liquid_glass_settings.dart' show LiquidGlassSettings;
import '../../src/engine/liquid_shape.dart' show LiquidShape;
import '../../src/engine/stretch.dart'
    show AnchorStretchSettings, LiquidStretch;
import '../../theme/glass_theme.dart';
import '../../types/glass_quality.dart';
import 'glass_container.dart';

/// A standalone glass platter with the touch glow and stretch used by menus.
///
/// Use this for a floating menu surface that needs GlassMenu's direct
/// manipulation physics but is positioned by an external overlay, so it
/// should not morph from a button trigger.
class GlassInteractiveContainer extends StatelessWidget {
  /// Creates a standalone interactive glass surface.
  const GlassInteractiveContainer({
    super.key,
    required this.child,
    required this.shape,
    required this.settings,
    this.padding = EdgeInsets.zero,
    this.quality = GlassQuality.standard,
    this.useOwnLayer = true,
    this.allowElevation = false,
    this.glowIntensity = 0,
    this.enableInteractionGlow = true,
    this.glowColor,
    this.glowRadius = GlassDefaults.touchGlowRadius,
    this.glowBlurRadius = GlassDefaults.touchGlowBlurRadius,
    this.stretch = 0.5,
    this.interactionScale = 1.02,
    this.stretchResistance = 0.08,
    this.stretchAxis = Axis.horizontal,
    this.allowPositiveX,
    this.allowNegativeX,
    this.allowPositiveY,
    this.allowNegativeY,
    this.anchorStretchSettings = const AnchorStretchSettings(),
  });

  /// The content painted on the glass surface.
  final Widget child;

  /// The surface shape and the clipping shape for its touch glow.
  final LiquidShape shape;

  /// Optical settings for the glass material.
  final LiquidGlassSettings settings;

  /// Insets between the material edge and [child].
  final EdgeInsetsGeometry padding;

  /// Shader quality used to render the glass.
  final GlassQuality quality;

  /// Whether the glass surface owns its renderer layer.
  final bool useOwnLayer;

  /// Whether the surface may cast its package-managed elevation shadow.
  final bool allowElevation;

  /// Persistent surface glow intensity.
  final double glowIntensity;

  /// Whether pointer movement paints a transient touch glow.
  final bool enableInteractionGlow;

  /// Optional override for the touch-glow color.
  final Color? glowColor;

  /// Touch-glow radius relative to the surface's shortest edge.
  final double glowRadius;

  /// Blur radius applied to the transient touch glow.
  final double glowBlurRadius;

  /// How much the surface follows a drag.
  final double stretch;

  /// Scale applied while the surface is pressed.
  final double interactionScale;

  /// Resistance applied to drag movement.
  final double stretchResistance;

  /// Axis along which drag stretch is allowed.
  final Axis? stretchAxis;

  /// Whether stretch is allowed toward positive X.
  final bool? allowPositiveX;

  /// Whether stretch is allowed toward negative X.
  final bool? allowNegativeX;

  /// Whether stretch is allowed toward positive Y.
  final bool? allowPositiveY;

  /// Whether stretch is allowed toward negative Y.
  final bool? allowNegativeY;

  /// Fine-tuning for anchored stretch behavior.
  final AnchorStretchSettings anchorStretchSettings;

  @override
  Widget build(BuildContext context) {
    final isDark = GlassTheme.brightnessOf(context) == Brightness.dark;
    final touchGlowColor = glowColor ??
        (isDark
            ? CupertinoColors.white
                .withValues(alpha: GlassDefaults.specularLightAlpha)
            : CupertinoColors.black
                .withValues(alpha: GlassDefaults.specularDarkAlpha));

    return LiquidStretch(
      stretch: stretch,
      interactionScale: interactionScale,
      resistance: stretchResistance,
      axis: stretchAxis,
      suppressInteractionOnChildren: false,
      anchorStretch: false,
      anchorStretchSettings: anchorStretchSettings,
      allowPositiveX: allowPositiveX,
      allowNegativeX: allowNegativeX,
      allowPositiveY: allowPositiveY,
      allowNegativeY: allowNegativeY,
      child: GlassContainer(
        useOwnLayer: useOwnLayer,
        settings: settings,
        quality: quality,
        allowElevation: allowElevation,
        glowIntensity: glowIntensity,
        shape: shape,
        clipBehavior: Clip.antiAlias,
        child: GlassGlow(
          enabled: enableInteractionGlow,
          glowColor: touchGlowColor,
          glowRadius: glowRadius,
          glowBlurRadius: glowBlurRadius,
          clipper: ShapeBorderClipper(shape: shape),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
