import 'package:flutter/cupertino.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../app_theme.dart';
import 'fixed_size_icon.dart';

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
    final selectedColor = selectedIndex == 2
        ? CupertinoDynamicColor.resolve(eventsAccent, context)
        : resolveAccentColor(context);
    final unselectedColor = resolveThemeColor(kSecondaryLabel, context);

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
        child: LiquidGlassTabBar(
          items: [
            _tabItem(SFIcons.sf_text_document, 'Notes'),
            _tabItem(SFIcons.sf_calendar, 'Calendar'),
            _tabItem(SFIcons.sf_list_bullet, 'Events'),
          ],
          selectedIndex: selectedIndex,
          onChanged: onTabSelected,
          width: double.infinity,
          height: kFloatingTabBarHeight,
          itemPadding: 4,
          itemStyle: LiquidGlassTabItemStyle(
            selectedColor: selectedColor,
            unselectedColor: unselectedColor,
            iconSize: 20,
            labelFontSize: 11,
            iconLabelGap: 3,
            selectedFontWeight: FontWeight.w700,
            unselectedFontWeight: FontWeight.w700,
          ),
          pillStyle: LiquidGlassTabPillStyle(
            mode: LiquidGlassPillMode.both,
            animated: true,
            color: glassColor,
            distortion: 0.08,
            distortionWidth: 44,
          ),
          style: LiquidGlassTabBar.defaultStyle.copyWith(
            shape: LiquidGlassShape.continuousRoundedRectangle(
              cornerRadius: kFloatingTabBarHeight / 2,
              borderWidth: isDark ? 0.5 : 0,
              borderColor: isDark ? borderColor : null,
            ),
            appearance: LiquidGlassAppearance(
              color: glassColor,
              blur: const LiquidGlassBlur(sigmaX: 2, sigmaY: 2),
            ),
            refraction: const LiquidGlassRefraction(
              distortion: 0.08,
              distortionWidth: 44,
            ),
          ),
        ),
      ),
    );
  }

  LiquidGlassTabBarItem _tabItem(IconData icon, String label) {
    return LiquidGlassTabBarItem(
      label: label,
      iconBuilder: (context, glyph) => FixedSFIcon(
        icon,
        fontSize: glyph.size,
        fontWeight: glyph.selected ? FontWeight.w500 : FontWeight.normal,
        color: glyph.color,
      ),
      labelBuilder: (context, tabLabel) => Text(
        tabLabel.text ?? label,
        style: tabLabel.textStyle.copyWith(
          fontFamily: kSFProText,
          letterSpacing: kTracking10,
          height: kLineHeight,
        ),
      ),
    );
  }
}
