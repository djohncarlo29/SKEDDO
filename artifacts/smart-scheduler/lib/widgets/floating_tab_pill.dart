import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassExtraButtonPlacement,
        GlassTab,
        GlassTabBar,
        GlassTabBarExtraButton,
        GlassThemeVariant,
        LiquidGlassSettings;
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../app_theme.dart';
import '../app_settings.dart';
import 'fixed_size_icon.dart';

/// Geometry shared by the Liquid Glass settings preview card and its
/// shape-aware movement boundary.
const double kLiquidGlassPreviewHeight = 154.0;
const RoundedRectangleBorder kLiquidGlassPreviewCardShape =
    RoundedRectangleBorder(
  borderRadius: BorderRadius.all(
    Radius.circular(kSquircleStadiumRadius),
  ),
);
const LiquidGlassShape kLiquidGlassPreviewGlassShape =
    LiquidGlassShape.roundedRectangle(
  cornerRadius: kSquircleStadiumRadius,
  clipQuality: LiquidGlassClipQuality.exact,
);

// Mirrors the package's private bottom-bar preset, allowing its public
// GlassThemeVariant.dark settings to be applied without adding a charcoal veil.
const LiquidGlassSettings _floatingTabBarBaseSettings = LiquidGlassSettings(
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
final LiquidGlassSettings _floatingTabBarDarkSettings =
    GlassThemeVariant.dark.settings!.applyTo(_floatingTabBarBaseSettings);

/// The AppShell's platform-neutral floating tab control.
///
/// This widget owns the package bar, its three navigation tabs, and its
/// separate trailing action. AppShell remains responsible for navigation,
/// opening the event sheet, safe-area positioning, and overlay ordering.
class FloatingTabPill extends StatefulWidget {
  const FloatingTabPill({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
    required this.onCreateEvent,
    required this.eventsAccent,
    this.horizontalOffset = 0,
    this.animateHorizontalOffset = true,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onCreateEvent;
  final Color eventsAccent;
  /// Horizontal movement from the normal centered position, in logical pixels.
  final double horizontalOffset;
  /// False while AppShell supplies each frame of the shared DCV pane motion.
  final bool animateHorizontalOffset;

  @override
  State<FloatingTabPill> createState() => _FloatingTabPillState();
}

class _FloatingTabPillState extends State<FloatingTabPill> {
  double? _portraitBarWidth;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = widget.selectedIndex;
    final selectedColor = selectedIndex == 2
        ? CupertinoDynamicColor.resolve(widget.eventsAccent, context)
        : resolveAccentColor(context);
    final unselectedColor = CupertinoDynamicColor.resolve(
      kTabBarInactiveColor,
      context,
    );
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final bottomOffset = floatingTabBarBottomOffset(context);
    final tabBar = GlassTabBar.bottom(
      tabs: const [
        GlassTab(
          icon: FixedSFIcon(SFIcons.sf_text_document, fontSize: 20),
          label: 'Notes',
        ),
        GlassTab(
          icon: FixedSFIcon(SFIcons.sf_calendar, fontSize: 20),
          label: 'Calendar',
        ),
        GlassTab(
          icon: FixedSFIcon(SFIcons.sf_list_bullet, fontSize: 20),
          label: 'Events',
        ),
      ],
      selectedIndex: selectedIndex,
      onTabSelected: widget.onTabSelected,
      extraButton: GlassTabBarExtraButton(
        icon: const FixedSFIcon(SFIcons.sf_plus),
        onTap: widget.onCreateEvent,
        label: 'New Event',
        iconColor: selectedColor,
        placement: GlassExtraButtonPlacement.right,
        size: kFloatingTabBarHeight,
      ),
      barHeight: kFloatingTabBarHeight,
      verticalPadding: 0,
      iconSize: 20,
      labelFontSize: 9,
      magnification: 1,
      settings: isDark ? _floatingTabBarDarkSettings : null,
      indicatorColor: isDark
          ? kFloatingTabBarDarkIndicatorColor
          : kFloatingTabBarLightIndicatorColor,
      selectedIconColor: selectedColor,
      unselectedIconColor: unselectedColor,
      selectedLabelColor: selectedColor,
      unselectedLabelColor: unselectedColor,
    );

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final screenSize = MediaQuery.sizeOf(context);
          final isPortrait = screenSize.width <= screenSize.height;
          final availableBarWidth =
              constraints.maxWidth - (kFloatingTabBarHorizontalMargin * 2);
          final portraitWidth = _portraitBarWidth ??
              (math.min(screenSize.width, screenSize.height) -
                  (kFloatingTabBarHorizontalMargin * 2));
          final barWidth = (isPortrait
                  ? availableBarWidth
                  : math.min(availableBarWidth, portraitWidth))
              .clamp(0.0, double.infinity)
              .toDouble();
          if (isPortrait) _portraitBarWidth = barWidth;
          final frameWidth = (barWidth + tabBar.horizontalPadding * 2)
              .clamp(0.0, constraints.maxWidth)
              .toDouble();
          final barSideInset = (constraints.maxWidth - frameWidth) / 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedPositioned(
                duration: widget.animateHorizontalOffset
                    ? kDcvPaneTransitionDuration
                    : Duration.zero,
                curve: Curves.easeInOutCubic,
                left: barSideInset + widget.horizontalOffset,
                right: barSideInset - widget.horizontalOffset,
                bottom: bottomOffset - tabBar.verticalPadding,
                height: tabBar.preferredSize.height,
                child: MediaQuery.removePadding(
                  context: context,
                  removeBottom: true,
                  child: tabBar,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A static `liquid_glass_easy` sample for the Settings opacity control.
///
/// The live Flutter navigation bar uses `GlassTabBar.bottom`; this sample is
/// intentionally separate from that control and its package renderer.
class FloatingTabBarGlassPreview extends StatefulWidget {
  const FloatingTabBarGlassPreview({super.key});

  @override
  State<FloatingTabBarGlassPreview> createState() =>
      _FloatingTabBarGlassPreviewState();
}

class _FloatingTabBarGlassPreviewState
    extends State<FloatingTabBarGlassPreview> {
  static const _standardPillHeight = 50.0;
  static const _previewEdgePadding = 8.0;
  static const _previewIconGap = 24.0;
  static const _previewItemPadding = 4.0;
  // Keep one common slot for the preview glyphs. The trash icon is the
  // optical reference; the other symbols are gently reduced to match its
  // visible height without changing their authored base sizes.
  static const _previewIconReferenceSize = 27.0;
  Offset _offset = Offset.zero;
  int? _activePointer;
  bool _pointerMoved = false;
  DateTime? _lastTapAt;
  Offset? _lastTapPosition;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final textScaler = MediaQuery.textScalerOf(context);
    final scaledIconSlot = textScaler.scale(_previewIconReferenceSize);
    final standardBarWidth =
        (width - (kFloatingTabBarHorizontalMargin * 2)).clamp(
          150.0,
          190.0,
        );
    final minBarWidth = (_previewItemPadding * 2) +
        (3 * (scaledIconSlot + _previewIconGap));
    final barWidth = math.max(standardBarWidth, minBarWidth);
    final pillHeight = math.max(
      _standardPillHeight,
      scaledIconSlot + (_previewEdgePadding * 2),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final previewSize = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : barWidth,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : kLiquidGlassPreviewHeight,
        );
        final pillSize = Size(barWidth, pillHeight);
        // Reserve the contour's small outward extension inside the preview
        // clip so its edge remains visible at every drag limit.
        final maxX = math.max(
          0.0,
          (previewSize.width - pillSize.width) / 2 -
              kLiquidGlassPillContourOutset,
        );
        final maxY = math.max(
          0.0,
          (previewSize.height - pillSize.height) / 2 -
              kLiquidGlassPillContourOutset,
        );
        final boundedOffset = Offset(
          _offset.dx.clamp(-maxX, maxX),
          _offset.dy.clamp(-maxY, maxY),
        );

        void applyDrag(Offset delta) {
          setState(() {
            _offset = Offset(
              (_offset.dx + delta.dx).clamp(-maxX, maxX),
              (_offset.dy + delta.dy).clamp(-maxY, maxY),
            );
          });
        }

        void handlePointerDown(PointerDownEvent event) {
          _activePointer = event.pointer;
          _pointerMoved = false;
        }

        void handlePointerMove(PointerMoveEvent event) {
          if (_activePointer != event.pointer) return;
          if (event.delta.distanceSquared > 0) _pointerMoved = true;
          applyDrag(event.delta);
        }

        void handlePointerUp(PointerUpEvent event) {
          if (_activePointer != event.pointer) return;
          if (!_pointerMoved) {
            final now = DateTime.now();
            final isDoubleTap = _lastTapAt != null &&
                now.difference(_lastTapAt!) <=
                    const Duration(milliseconds: 320) &&
                _lastTapPosition != null &&
                (event.position - _lastTapPosition!).distance <= 28;
            if (isDoubleTap) {
              setState(() => _offset = Offset.zero);
              _lastTapAt = null;
              _lastTapPosition = null;
            } else {
              _lastTapAt = now;
              _lastTapPosition = event.position;
            }
          } else {
            _lastTapAt = null;
            _lastTapPosition = null;
          }
          _activePointer = null;
          _pointerMoved = false;
        }

        void handlePointerCancel(PointerCancelEvent event) {
          if (_activePointer != event.pointer) return;
          _activePointer = null;
          _pointerMoved = false;
          _lastTapAt = null;
          _lastTapPosition = null;
        }

        return SizedBox.expand(
          child: RawGestureDetector(
            // Claim the sequence on pointer-down. The preview is an
            // interactive surface inside a vertical CustomScrollView, and
            // allowing the scroll recognizer to win makes the pill feel
            // sticky or intermittently undraggable.
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              EagerGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                EagerGestureRecognizer.new,
                (_) {},
              ),
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: handlePointerDown,
              onPointerMove: handlePointerMove,
              onPointerUp: handlePointerUp,
              onPointerCancel: handlePointerCancel,
              child: Transform.translate(
                offset: boundedOffset,
                child: Semantics(
                  label: 'Liquid Glass preview',
                  hint: 'Drag to move. Double-tap to center.',
                  child: ClipPath(
                    clipper: const LiquidGlassPreviewClipper(),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        IgnorePointer(
                          child: LiquidGlassShadow(
                            blur: 16,
                            opacity: isDark ? 0 : 0.18,
                            offset: const Offset(0, 5),
                            cornerRadius: kSquircleStadiumRadius,
                            child: SizedBox(
                              width: barWidth,
                              height: pillHeight,
                            ),
                           ),
                         ),
                        // The Settings preview is a visual sample, not a
                        // second navigation control. Ignore the tab bar's own
                        // hit testing; the preview pointer handlers own drag
                        // and double-tap behavior.
                       ValueListenableBuilder<double>(
                         valueListenable: appLiquidGlassOpacityNotifier,
                         builder: (context, _, __) {
                           // Re-resolve the glass appearance on every slider
                           // update while this preview remains mounted.
                           final style = _liquidGlassSettingsPreviewStyle(
                             context,
                             exactClip: true,
                           );
                            return IgnorePointer(
                              child: LiquidGlassTabBar(
                                items: [
                                  _previewItem(
                                    SFIcons.sf_trash,
                                    size: 21,
                                    opticalScale: 1.0,
                                  ),
                                  _previewItem(
                                    SFIcons.sf_folder,
                                    size: 27,
                                    opticalScale: 0.775,
                                  ),
                                  _previewItem(
                                    SFIcons.sf_arrowshape_turn_up_left,
                                    size: 25.5,
                                    opticalScale: 0.825,
                                  ),
                                ],
                                selectedIndex: 0,
                                onChanged: (_) {},
                                width: barWidth,
                                height: pillHeight,
                                itemPadding: _previewItemPadding,
                                itemStyle: LiquidGlassTabItemStyle(
                                  selectedColor: resolveThemeColor(
                                    kSecondaryLabel,
                                    context,
                                  ),
                                  unselectedColor: resolveThemeColor(
                                    kSecondaryLabel,
                                    context,
                                  ),
                                  iconSize: _previewIconReferenceSize,
                                  selectedFontWeight: FontWeight.w500,
                                  unselectedFontWeight: FontWeight.w500,
                                ),
                                style: style,
                                pillStyle: LiquidGlassTabPillStyle(
                                  mode: LiquidGlassPillMode.none,
                                  show: false,
                                  animated: false,
                                  shape: kLiquidGlassPreviewGlassShape,
                                  glassStyle: LiquidGlassStyle(
                                    shape: kLiquidGlassPreviewGlassShape,
                                  ),
                                  rest: LiquidGlassStyle(
                                    shape: kLiquidGlassPreviewGlassShape,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        ValueListenableBuilder<double>(
                          valueListenable: appLiquidGlassOpacityNotifier,
                          builder: (context, glassOpacity, _) =>
                              LightModeLiquidGlassPillContour(
                            whiteOutlineOpacity:
                                _normalizedLiquidGlassOpacity(glassOpacity),
                            child: SizedBox(
                              width: barWidth,
                              height: pillHeight,
                            ),
                          ),
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
    );
  }

  LiquidGlassTabBarItem _previewItem(
    IconData icon, {
    required double size,
    required double opticalScale,
  }) {
    return LiquidGlassTabBarItem(
      iconBuilder: (context, glyph) {
        final textScaler = MediaQuery.textScalerOf(context);
        return SizedBox(
          width: textScaler.scale(_previewIconReferenceSize),
          height: textScaler.scale(_previewIconReferenceSize),
          child: Center(
            child: UnconstrainedBox(
              clipBehavior: Clip.none,
              child: Transform.scale(
                scale: opticalScale,
                child: FixedSFIcon(
                  icon,
                  fontSize: textScaler.scale(size),
                  fontWeight: FontWeight.normal,
                  color: glyph.color,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

Path _liquidGlassPreviewPath(Size size) {
  return Path()
    ..addRRect(
      RRect.fromRectAndRadius(
        Offset.zero & size,
        const Radius.circular(kSquircleStadiumRadius),
      ),
    );
}

class LiquidGlassPreviewClipper extends CustomClipper<Path> {
  const LiquidGlassPreviewClipper();

  @override
  Path getClip(Size size) => _liquidGlassPreviewPath(size);

  @override
  bool shouldReclip(covariant LiquidGlassPreviewClipper oldClipper) => false;
}

/// Applies the app's Liquid Glass opacity setting to `liquid_glass_easy`
/// surfaces that participate in that setting.
LiquidGlassAppearance liquidGlassOpacitySettingAppearance(
  BuildContext context, {
  required LiquidGlassAppearance baseAppearance,
}) {
  final headerColor = resolveThemeColor(kFloatingTabBarSurfaceColor, context);
  final setting = appLiquidGlassOpacityNotifier.value;
  final defaultBlur = baseAppearance.blur;
  final blurProgress =
      _normalizedLiquidGlassOpacity(setting);
  final blurScale = blurProgress < 0.9
      ? (0.3 + blurProgress * 3) / 2
      : blurProgress < 1.0
      ? (3.0 + (blurProgress - 0.9) * 10) / 2
      : 2.0;

  return baseAppearance.copyWith(
    color: headerColor.withValues(alpha: setting),
    blur: LiquidGlassBlur(
      sigmaX: defaultBlur.sigmaX * blurScale,
      sigmaY: defaultBlur.sigmaY * blurScale,
    ),
  );
}

LiquidGlassStyle _liquidGlassSettingsPreviewStyle(
  BuildContext context, {
  bool exactClip = false,
}) {
  final defaultAppearance = LiquidGlassTabBar.defaultStyle.appearance;

  return LiquidGlassTabBar.defaultStyle.copyWith(
    appearance: liquidGlassOpacitySettingAppearance(
      context,
      baseAppearance: defaultAppearance,
    ),
    shape: exactClip
        ? kLiquidGlassPreviewGlassShape
        : LiquidGlassShape.squircle(
            cornerRadius: kSquircleStadiumRadius,
            // Keep the 0.5px hairline inside the capsule lens. The active
            // lifted pill captures this optical rim as part of the bar, so its
            // smaller moving envelope can refract it instead of leaving a
            // fixed sibling outline behind the glass.
            borderWidth: 0.5,
            borderColor: Color(0x26FFFFFF),
            lightIntensity: 0.46,
            lightDirection: 62,
            borderType: OpticalBorder(
              borderSaturation: 1.0,
              ambientIntensity: 0.55,
              borderSolidity: 0.35,
              lightSpread: 0.12,
            ),
          ),
    refraction: LiquidGlassTabBar.defaultStyle.refraction.copyWith(
      chromaticAberration: kFloatingTabBarChromaticAberration,
    ),
  );
}

double _normalizedLiquidGlassOpacity(double materialOpacity) {
  final range = kLiquidGlassMaximumOpacity - kLiquidGlassMinimumOpacity;
  return ((materialOpacity - kLiquidGlassMinimumOpacity) / range)
      .clamp(0.0, 1.0)
      .toDouble();
}
