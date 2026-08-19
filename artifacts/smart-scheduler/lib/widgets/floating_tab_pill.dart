import 'package:flutter/cupertino.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:oc_liquid_glass/oc_liquid_glass.dart';

import '../app_theme.dart';
import 'fixed_size_icon.dart';

// Extra backdrop capture around the visible pill. The local glass shader uses
// this field as one unified optical input: direct refraction stays strong while
// a broad ambient contribution can reach in from just outside the pill.
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
        // Do not clip the expanded group before BackdropFilter runs. That
        // would clip away the very outside pixels the optical field needs.
        // The shader's shape SDF remains the final visible mask, and the
        // registered OCLiquidGlass render object keeps all controls inside the
        // original pill bounds.
        child: LayoutBuilder(
          builder: (context, constraints) {
            final visibleWidth = constraints.maxWidth;
            final fieldWidth =
                visibleWidth + (_kLiquidGlassFieldExtension * 2);
            return OverflowBox(
              minWidth: fieldWidth,
              maxWidth: fieldWidth,
              minHeight: fieldHeight,
              maxHeight: fieldHeight,
              alignment: Alignment.center,
              child: OCLiquidGlassGroup(
                  settings: OCLiquidGlassSettings(
                    // Preserve the strong original optical response. The
                    // shader's expanded field is additional source material,
                    // not a reason to weaken the refraction pass.
                    refractStrength: -0.08,
                    distortFalloffPx: 44,
                    distortExponent: 4,
                    blurRadiusPx: 2.0,
                    specStrength: 0.0,
                    specPower: 80,
                    specWidth: 8,
                    lightbandStrength: 0.0,
                    lightbandColor: CupertinoColors.white,
                  ),
                  child: SizedBox(
                    width: fieldWidth,
                    height: fieldHeight,
                    child: Center(
                      child: OCLiquidGlass(
                        // The render field is larger, but the registered
                        // shape remains exactly the original pill width.
                        width: visibleWidth,
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
            );
          },
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
