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
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final selectedColor = selectedIndex == 2
        ? CupertinoDynamicColor.resolve(eventsAccent, context)
        : resolveAccentColor(context);
    final unselectedColor = resolveThemeColor(kSecondaryLabel, context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final headerColor = resolveThemeColor(kCardColor, context);
    final barOpacity = 0.8;
    final barStyle = LiquidGlassTabBar.defaultStyle.copyWith(
      appearance: LiquidGlassTabBar.defaultStyle.appearance.copyWith(
        // Use the resolved header surface itself, not a white overlay. This
        // keeps the bar denser while preserving the correct Light/Dark tone.
        color: headerColor.withValues(alpha: barOpacity),
      ),
      shape: const LiquidGlassShape.continuousRoundedRectangle(
        // Match the shared bounded stadium geometry used by the rest of the
        // app instead of deriving 25 px from this pill's 50 px height.
        cornerRadius: kSquircleStadiumRadius,
        // Keep the package's optical rim, but make it a quiet edge accent
        // rather than a bright continuous stroke.
        borderWidth: 0.45,
        lightIntensity: 0.46,
        lightDirection: 62,
        borderType: OpticalBorder(
          borderSaturation: 1.0,
          ambientIntensity: 0.18,
          borderSolidity: 0.28,
          lightSpread: 0.12,
        ),
      ),
      // The package default is intentionally colorful at the rim. Keep the
      // bar's refraction and magnification, but make channel separation
      // effectively imperceptible.
      refraction: LiquidGlassTabBar.defaultStyle.refraction.copyWith(
        chromaticAberration: 0.0002,
      ),
    );

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: LiquidGlassTabBar.withImpeller(
        items: [
          _tabItem(SFIcons.sf_text_document, 'Notes'),
          _tabItem(SFIcons.sf_calendar, 'Calendar'),
          _tabItem(SFIcons.sf_list_bullet, 'Events'),
        ],
        selectedIndex: selectedIndex,
        onChanged: onTabSelected,
        width: (screenWidth - (kFloatingTabBarHorizontalMargin * 2)).clamp(
          0.0,
          double.infinity,
        ),
        height: kFloatingTabBarHeight,
        margin: const EdgeInsets.only(bottom: kFloatingTabBarBottomSpacing),
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
        style: barStyle,
        // Keep the package's tuned glass pill, including its raised
        // transition and magnifier layer. The quieter rim is applied to the
        // outer bar surface above, without adding a static border.
        pillStyle: const LiquidGlassTabPillStyle(
          mode: LiquidGlassPillMode.impellerOnly,
          animated: true,
          // Keep the active pill on the same bounded 24 px squircle family
          // as the bar and the rest of the app, including while it lifts.
          shape: LiquidGlassShape.continuousRoundedRectangle(
            cornerRadius: kSquircleStadiumRadius,
          ),
          // The active pill is the most noticeable source of RGB fringing.
          // This is close to neutral while preserving the glass movement.
          glassStyle: LiquidGlassStyle(
            shape: LiquidGlassShape.continuousRoundedRectangle(
              cornerRadius: kSquircleStadiumRadius,
            ),
            refraction: LiquidGlassRefraction(
              distortion: 0.04,
              distortionWidth: 12,
              magnification: 1,
              chromaticAberration: 0.0002,
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
