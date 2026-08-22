import 'package:flutter/cupertino.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../app_theme.dart';
import '../app_settings.dart';
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
    final bottomOffset = floatingTabBarBottomOffset(context);
    final barStyle = _floatingTabBarStyle(context);

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: Stack(
        fit: StackFit.expand,
        children: [
          // This layer is deliberately outside the glass capture. It paints
          // onto the page first, then the translucent bar composites above it.
          // Nothing in the shadow can therefore darken or refract through the
          // bar's material.
          Positioned(
            left: kFloatingTabBarHorizontalMargin,
            right: kFloatingTabBarHorizontalMargin,
            bottom: bottomOffset,
            height: kFloatingTabBarHeight,
            child: IgnorePointer(
              child: LiquidGlassShadow(
                // The bar itself stays at the earlier, softer level. Its
                // shadow is separate from the glass, but never competes with
                // the transient raised selection lens below.
                blur: 16,
                opacity: isDark ? 0 : 0.18,
                offset: const Offset(0, 5),
                cornerRadius: kSquircleStadiumRadius,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          LiquidGlassTabBar.withImpeller(
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
            margin: EdgeInsets.only(bottom: bottomOffset),
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
            // The environmental shadows above own elevation. Keep the glass
            // material itself shadow-free so its refraction remains clean.
            pillStyle: LiquidGlassTabPillStyle(
              mode: LiquidGlassPillMode.impellerOnly,
              animated: true,
              shape: LiquidGlassShape.continuousRoundedRectangle(
                cornerRadius: kSquircleStadiumRadius,
              ),
              glassStyle: LiquidGlassStyle(
                shape: LiquidGlassShape.continuousRoundedRectangle(
                  cornerRadius: kSquircleStadiumRadius,
                ),
                appearance: LiquidGlassAppearance(
                  // This shadow belongs to the motion lens only. The package
                  // fades it with the lift/morph handoff, so the settled
                  // active pill remains clean and the moving pill gets depth.
                  shadow: LiquidGlassShadow(
                    blur: 6,
                    opacity: isDark ? 0 : 0.22,
                    offset: const Offset(0, 3),
                    cornerRadius: kSquircleStadiumRadius,
                    inset: 1,
                  ),
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
          // Keep the shared 15% hairline outside the glass capture so it stays
          // stable against the page instead of being refracted into the bar.
          Positioned(
            left: kFloatingTabBarHorizontalMargin,
            right: kFloatingTabBarHorizontalMargin,
            bottom: bottomOffset,
            height: kFloatingTabBarHeight,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: const Color(0x26FFFFFF),
                    width: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(kSquircleStadiumRadius),
                ),
              ),
            ),
          ),
        ],
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

/// A static, icon-only example of the same glass surface used by the
/// Floating Tab Bar. This is used in Settings so the Liquid Glass opacity
/// control previews the real navigation surface rather than a separate
/// approximation.
class FloatingTabBarGlassPreview extends StatelessWidget {
  const FloatingTabBarGlassPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final style = _floatingTabBarStyle(context);
    final barWidth = (width - 64).clamp(150.0, 190.0);

    return Stack(
      alignment: Alignment.center,
      children: [
        IgnorePointer(
          child: LiquidGlassShadow(
            blur: 16,
            opacity: isDark ? 0 : 0.18,
            offset: const Offset(0, 5),
            cornerRadius: kSquircleStadiumRadius,
            child: SizedBox(width: barWidth, height: 50),
          ),
        ),
        LiquidGlassTabBar(
          items: [
            _previewItem(SFIcons.sf_trash),
            _previewItem(SFIcons.sf_folder, size: 23),
            _previewItem(SFIcons.sf_arrow_uturn_backward),
          ],
          selectedIndex: 0,
          onChanged: (_) {},
          width: barWidth,
          height: 50,
          itemPadding: 4,
          itemStyle: LiquidGlassTabItemStyle(
            selectedColor: resolveThemeColor(kSecondaryLabel, context),
            unselectedColor: resolveThemeColor(kSecondaryLabel, context),
            iconSize: 20,
            selectedFontWeight: FontWeight.w500,
            unselectedFontWeight: FontWeight.w500,
          ),
          style: style,
          pillStyle: const LiquidGlassTabPillStyle(
            mode: LiquidGlassPillMode.none,
            show: false,
            animated: false,
          ),
        ),
      ],
    );
  }

  LiquidGlassTabBarItem _previewItem(IconData icon, {double size = 20}) {
    return LiquidGlassTabBarItem(
      iconBuilder: (context, glyph) => FixedSFIcon(icon,
          fontSize: size, fontWeight: FontWeight.normal, color: glyph.color),
    );
  }
}

LiquidGlassStyle _floatingTabBarStyle(BuildContext context) {
  final headerColor = resolveThemeColor(kCardColor, context);
  final defaultBlur = LiquidGlassTabBar.defaultStyle.appearance.blur;
  final blurProgress =
      ((appLiquidGlassOpacityNotifier.value - kLiquidGlassMinimumOpacity) /
              (kLiquidGlassMaximumOpacity - kLiquidGlassMinimumOpacity))
          .clamp(0.0, 1.0);
  final blurScale = blurProgress < 0.9
      ? (0.3 + blurProgress * 3) / 2
      : blurProgress < 1.0
      ? (3.0 + (blurProgress - 0.9) * 10) / 2
      : 2.0;

  return LiquidGlassTabBar.defaultStyle.copyWith(
    appearance: LiquidGlassTabBar.defaultStyle.appearance.copyWith(
      color: headerColor.withValues(
        alpha: appLiquidGlassOpacityNotifier.value,
      ),
      blur: LiquidGlassBlur(
        sigmaX: defaultBlur.sigmaX * blurScale,
        sigmaY: defaultBlur.sigmaY * blurScale,
      ),
    ),
    shape: const LiquidGlassShape.continuousRoundedRectangle(
      cornerRadius: kSquircleStadiumRadius,
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
    refraction: LiquidGlassTabBar.defaultStyle.refraction.copyWith(
      chromaticAberration: 0.0002,
    ),
  );
}
