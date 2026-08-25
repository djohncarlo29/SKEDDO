import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
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
    // Keep the animated pill's rest endpoint in lock-step with the static
    // active-pill surface. If this is omitted, liquid_glass_easy falls back to
    // its shipped translucent gray during both the lift handoff and settle.
    final selectedPillColor = resolveThemeColor(
      kFloatingTabBarSelectedPillColor,
      context,
    );
    // The settled selection is intentionally stronger than the bar surface,
    // while the moving glass eases through the lifted tint instead of
    // disappearing between the static and glass endpoints.
    final settledPillColor = selectedPillColor.withValues(alpha: 0.60);
    final transitionPillColor = selectedPillColor.withValues(alpha: 0.18);
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
          // The package adds MediaQuery.padding.bottom internally on its
          // Impeller path. Remove that implicit inset and pass the complete
          // shared offset explicitly, otherwise the glass capsule is lifted
          // away from the directly positioned rim/shadow on Android.
          MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: LiquidGlassTabBar.withImpeller(
              items: [
                _tabItem(SFIcons.sf_text_document, 'Notes'),
                _tabItem(SFIcons.sf_calendar, 'Calendar'),
                _tabItem(SFIcons.sf_list_bullet, 'Events'),
              ],
              selectedIndex: selectedIndex,
              onChanged: onTabSelected,
              width: (screenWidth - (kFloatingTabBarHorizontalMargin * 2))
                  .clamp(0.0, double.infinity),
              height: kFloatingTabBarHeight,
              margin: EdgeInsets.only(bottom: bottomOffset),
              itemPadding: 4,
              itemStyle: LiquidGlassTabItemStyle(
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                iconSize: 22,
                labelFontSize: 12,
                underGlassLabelFontSize: 12,
                iconLabelGap: 2,
                selectedFontWeight: FontWeight.w600,
                unselectedFontWeight: FontWeight.w500,
              ),
              style: barStyle,
              // The environmental shadows above own elevation. Keep the glass
              // material itself shadow-free so its refraction remains clean.
              pillStyle: LiquidGlassTabPillStyle(
                mode: LiquidGlassPillMode.impellerOnly,
                animated: true,
                color: transitionPillColor,
                transitionColor: transitionPillColor,
                shape: LiquidGlassShape.continuousRoundedRectangle(
                  cornerRadius: kSquircleStadiumRadius,
                ),
                glassStyle: LiquidGlassStyle(
                  shape: LiquidGlassShape.continuousRoundedRectangle(
                    cornerRadius: kSquircleStadiumRadius,
                  ),
                  appearance: LiquidGlassAppearance(
                    // The raised endpoint must remain a transparent,
                    // refracting glass lens. The resolved Light/Dark color
                    // is owned by the settled rest endpoint above, so the
                    // handoff does not turn the raised pill into a flat fill.
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
                    chromaticAberration: kFloatingTabBarChromaticAberration,
                  ),
                ),
                // Keep the selected Light/Dark surface color as a gentle
                // tint at rest, but do not hand the settled pill over to a
                // flat fill. The package's default tab-pill example keeps
                // this endpoint as a transparent, refracting lens.
                rest: LiquidGlassStyle(
                  shape: LiquidGlassShape.continuousRoundedRectangle(
                    cornerRadius: kSquircleStadiumRadius,
                  ),
                  appearance: LiquidGlassAppearance(color: settledPillColor),
                  // An inert rest refraction makes the animated renderer
                  // hand the settled selection back to the static pill,
                  // which paints this authored tint directly. The lifted
                  // endpoint remains the refracting glass style above.
                  refraction: const LiquidGlassRefraction(
                    distortion: 0,
                    distortionWidth: 0,
                    magnification: 1,
                    chromaticAberration: 0,
                  ),
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
class FloatingTabBarGlassPreview extends StatefulWidget {
  const FloatingTabBarGlassPreview({super.key});

  @override
  State<FloatingTabBarGlassPreview> createState() =>
      _FloatingTabBarGlassPreviewState();
}

class _FloatingTabBarGlassPreviewState
    extends State<FloatingTabBarGlassPreview> {
  Offset _offset = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final barWidth = (width - (kFloatingTabBarHorizontalMargin * 2)).clamp(
      150.0,
      190.0,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxX = math.max(0.0, (constraints.maxWidth - barWidth) / 2);
        final maxY = math.max(0.0, (constraints.maxHeight - 50) / 2);
        final boundedOffset = Offset(
          _offset.dx.clamp(-maxX, maxX),
          _offset.dy.clamp(-maxY, maxY),
        );

        return SizedBox.expand(
          child: GestureDetector(
            // The preview lives inside the settings CustomScrollView. Claim
            // the full preview surface rather than only the painted pill so
            // the scroll view cannot steal a drag that starts near its edge.
            behavior: HitTestBehavior.opaque,
            dragStartBehavior: DragStartBehavior.down,
            onPanUpdate: (details) {
              setState(() {
                _offset = Offset(
                  (_offset.dx + details.delta.dx).clamp(-maxX, maxX),
                  (_offset.dy + details.delta.dy).clamp(-maxY, maxY),
                );
              });
            },
            onDoubleTap: () => setState(() => _offset = Offset.zero),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Transform.translate(
                  offset: boundedOffset,
                  child: Semantics(
                    label: 'Liquid Glass preview',
                    hint: 'Drag to move. Double-tap to center.',
                    child: Stack(
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
                        // The Settings preview is a visual sample, not a second
                        // navigation control. Ignore the tab bar's own hit
                        // testing so taps cannot make a selection indicator
                        // appear; the parent GestureDetector still owns the
                        // preview's drag and double-tap gestures.
                        ValueListenableBuilder<double>(
                          valueListenable: appLiquidGlassOpacityNotifier,
                          builder: (context, _, __) {
                            // Re-resolve the glass appearance on every slider
                            // update while this preview remains mounted.
                            final style = _floatingTabBarStyle(context);
                            return IgnorePointer(
                              child: LiquidGlassTabBar(
                                items: [
                                  _previewItem(SFIcons.sf_trash),
                                  _previewItem(SFIcons.sf_folder, size: 23),
                                  _previewItem(SFIcons.sf_arrow_uturn_left),
                                ],
                                selectedIndex: 0,
                                onChanged: (_) {},
                                width: barWidth,
                                height: 50,
                                itemPadding: 4,
                                itemStyle: LiquidGlassTabItemStyle(
                                  selectedColor: resolveThemeColor(
                                    kSecondaryLabel,
                                    context,
                                  ),
                                  unselectedColor: resolveThemeColor(
                                    kSecondaryLabel,
                                    context,
                                  ),
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
                            );
                          },
                        ),
                        // Match the Floating Tab Bar's stable hairline: it is
                        // painted outside the glass capture so the rim remains
                        // crisp and does not refract with the background.
                        IgnorePointer(
                          child: SizedBox(
                            width: barWidth,
                            height: 50,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0x26FFFFFF),
                                  width: 0.5,
                                ),
                                borderRadius: BorderRadius.circular(
                                  kSquircleStadiumRadius,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  LiquidGlassTabBarItem _previewItem(IconData icon, {double size = 20}) {
    return LiquidGlassTabBarItem(
      iconBuilder: (context, glyph) => FixedSFIcon(
        icon,
        fontSize: size,
        fontWeight: FontWeight.normal,
        color: glyph.color,
      ),
    );
  }
}

LiquidGlassStyle _floatingTabBarStyle(BuildContext context) {
  final headerColor = resolveThemeColor(kFloatingTabBarSurfaceColor, context);
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
      color: headerColor.withValues(alpha: appLiquidGlassOpacityNotifier.value),
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
      chromaticAberration: kFloatingTabBarChromaticAberration,
    ),
  );
}
