import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../app_theme.dart';

/// The app-wide liquid-glass switch.
///
/// All switch controls go through this wrapper so their interaction sizing,
/// disabled treatment, and theme colors stay consistent while the visual
/// control is always [LiquidGlassSwitch].
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.height = 44.0,
    this.color,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? CupertinoTheme.of(context).primaryColor;
    final inactiveColor = resolveThemeColor(kTertiaryLabel, context);

    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: SizedBox(
          height: height,
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Independent from the switch capture: this is painted onto
                // the surrounding scene before the glass thumb is composited.
                LiquidGlassShadow(
                  blur: 9,
                  opacity: CupertinoTheme.brightnessOf(context) == Brightness.dark
                      ? 0
                      : 0.26,
                  offset: const Offset(0, 4),
                  cornerRadius: 15.5,
                  child: const SizedBox(width: 70, height: 31),
                ),
                LiquidGlassShadow(
                  blur: 3,
                  opacity: CupertinoTheme.brightnessOf(context) == Brightness.dark
                      ? 0
                      : 0.18,
                  offset: const Offset(0, 2),
                  cornerRadius: 15.5,
                  inset: 1,
                  child: const SizedBox(width: 70, height: 31),
                ),
                LiquidGlassSwitch(
                  value: value,
                  onChanged: onChanged,
                  width: 70.0,
                  height: 31.0,
                  activeColor: activeColor,
                  inactiveColor: inactiveColor,
                  style: LiquidGlassStyle(
                    shape: LiquidGlassSwitch.defaultStyle.shape,
                    // Keep the switch optically interactive; only move the
                    // environmental shadow out of the material appearance.
                    appearance: LiquidGlassAppearance(
                      saturation: LiquidGlassSwitch
                          .defaultStyle
                          .appearance
                          .saturation,
                      blur: LiquidGlassSwitch.defaultStyle.appearance.blur,
                      color: LiquidGlassSwitch.defaultStyle.appearance.color,
                      enableInnerRadiusTransparent: LiquidGlassSwitch
                          .defaultStyle
                          .appearance
                          .enableInnerRadiusTransparent,
                    ),
                    refraction: LiquidGlassSwitch.defaultStyle.refraction.copyWith(
                      // Match the active tab pill's tuned lens behavior while
                      // keeping the switch's own native thumb geometry.
                      distortion: 0.04,
                      distortionWidth: 12,
                      magnification: 1,
                      chromaticAberration: 0.0002,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
