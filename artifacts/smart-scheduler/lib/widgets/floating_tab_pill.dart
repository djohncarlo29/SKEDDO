import 'package:flutter/cupertino.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

import '../app_theme.dart';
import 'fixed_size_icon.dart';

// Extra backdrop capture around the visible pill. The local glass shader uses
// this field only for a low-frequency ambient ring, then clips its output back
// to the existing stadium; it never displays the expanded field directly.
const double _kLiquidGlassFieldExtension = 18.0;

/// The AppShell's platform-neutral floating tab control.
///
/// This widget owns the pill's presentation and tab-item interaction only.
/// AppShell remains responsible for the selected index, navigation callbacks,
/// safe-area positioning, and overlay ordering.
class FloatingTabPill extends StatelessWidget {
  const FloatingTabPill({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.eventsAccent,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final Color eventsAccent;

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final borderColor = resolveThemeColor(kTertiaryLabel, context);
    final glassColor = resolveThemeColor(
      kGlassFillColor,
      context,
    ).withValues(alpha: isDark ? 0.80 : 0.70);
    final shadowColor = isDark
        ? const Color(0x00000000)
        : const Color(0x38000000);
    final fieldHeight =
        kFloatingTabBarHeight + (_kLiquidGlassFieldExtension * 2);

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: DecoratedBox(
        decoration: ShapeDecoration(
          shadows: resolveThemeShadows([
            BoxShadow(
              color: shadowColor,
              blurRadius: 28,
              offset: const Offset(0, 8),
            ),
          ], context),
          shape: SquircleStadiumBorder(
            side: isDark
                ? BorderSide(color: borderColor, width: 0.5)
                : BorderSide.none,
          ),
        ),
        child: ClipPath(
          // The group below is intentionally taller than the visible pill.
          // ClipPath keeps the expanded backdrop field from painting outside
          // the original stadium shape.
          clipper: const SquircleClipper(kFloatingTabBarHeight / 2),
          child: OverflowBox(
            minHeight: fieldHeight,
            maxHeight: fieldHeight,
            alignment: Alignment.center,
            child: OCLiquidGlassGroup(
              settings: OCLiquidGlassSettings(
                // Keep the package's shape response gentle. The local shader
                // adds the extended field as diffuse environmental light, not
                // as a transformed backdrop image.
                refractStrength: -0.045,
                distortFalloffPx: 38,
                distortExponent: 4,
                blurRadiusPx: 2.0,
                specStrength: 0.0,
                specPower: 80,
                specWidth: 8,
                lightbandStrength: 0.0,
                lightbandColor: CupertinoColors.white,
              ),
              child: SizedBox(
                width: double.infinity,
                height: fieldHeight,
                child: Center(
                  child: OCLiquidGlass(
                    width: double.infinity,
                    height: kFloatingTabBarHeight,
                    borderRadius: kFloatingTabBarHeight / 2,
                    color: glassColor,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 3,
                      ),
                      child: Row(
                        children: [
                          _FloatingTabItem(
                            icon: SFIcons.sf_text_document,
                            label: 'Notes',
                            active: selectedIndex == 0,
                            accentColor: resolveAccentColor(context),
                            onTap: () => onTabSelected(0),
                          ),
                          _FloatingTabItem(
                            icon: SFIcons.sf_calendar,
                            label: 'Calendar',
                            active: selectedIndex == 1,
                            accentColor: resolveAccentColor(context),
                            onTap: () => onTabSelected(1),
                          ),
                          _FloatingTabItem(
                            icon: SFIcons.sf_list_bullet,
                            label: 'Events',
                            active: selectedIndex == 2,
                            accentColor: eventsAccent,
                            onTap: () => onTabSelected(2),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FloatingTabItem extends StatelessWidget {
  const _FloatingTabItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.accentColor,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final Color accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? CupertinoDynamicColor.resolve(accentColor, context)
        : resolveThemeColor(kSecondaryLabel, context);

    return Expanded(
      child: Semantics(
        button: true,
        selected: active,
        label: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: SizedBox(
            height: kFloatingTabBarTouchTargetHeight,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FixedSFIcon(
                  icon,
                  fontSize: 20,
                  fontWeight: active ? FontWeight.w500 : FontWeight.normal,
                  color: color,
                ),
                const SizedBox(height: 3),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: kSFProText,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.normal,
                    color: color,
                    letterSpacing: kTracking10,
                    height: kLineHeight,
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
