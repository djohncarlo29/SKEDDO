import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../app_theme.dart';
import '../app_settings.dart';
import 'fixed_size_icon.dart';

/// Geometry shared by the Liquid Glass settings preview card and its
/// shape-aware movement boundary.
const double kLiquidGlassPreviewHeight = 154.0;
const BoundedSquircleStadiumBorder kLiquidGlassPreviewCardShape =
    BoundedSquircleStadiumBorder(
  radius: kSquircleStadiumRadius,
);
const LiquidGlassShape kLiquidGlassPreviewGlassShape =
    LiquidGlassShape.roundedRectangle(
  cornerRadius: kSquircleStadiumRadius,
  clipQuality: LiquidGlassClipQuality.exact,
);

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
    // The settled selection uses a lighter tint. The moving glass eases
    // through that same tint, then becomes clear at its fully lifted endpoint.
    final settledPillColor = selectedPillColor.withValues(alpha: 0.60);
    final transitionPillColor = selectedPillColor.withValues(alpha: 0.60);
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
            child: MediaQuery.withClampedTextScaling(
              minScaleFactor: kFloatingTabBarMinimumTextScale,
              maxScaleFactor: kFloatingTabBarMaximumTextScale,
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
                  // Keep the fully lifted glass lens clear. The transition-only
                  // tint carries the visible handoff without tinting this
                  // settled lifted endpoint; the package aberration remains
                  // authored on the glass refraction itself.
                  color: const Color(0x00000000),
                  transitionColor: transitionPillColor,
                  shape: LiquidGlassShape.squircle(
                    cornerRadius: kSquircleStadiumRadius,
                  ),
                  glassStyle: LiquidGlassStyle(
                    shape: LiquidGlassShape.squircle(
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
                  // tint at rest. The package rest endpoint retains its
                  // authored chromatic aberration for a continuous handoff,
                  // while its zero distortion keeps the settled pill stable.
                  rest: LiquidGlassStyle(
                    shape: LiquidGlassShape.squircle(
                      cornerRadius: kSquircleStadiumRadius,
                    ),
                    appearance: LiquidGlassAppearance(color: settledPillColor),
                    // Keep the package aberration authored at the settled
                    // endpoint too. Distortion remains inert so the static
                    // rest pill is still stable and does not bend the bar.
                    refraction: const LiquidGlassRefraction(
                      distortion: 0,
                      distortionWidth: 0,
                      magnification: 1,
                      chromaticAberration: kFloatingTabBarChromaticAberration,
                    ),
                  ),
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
  static const _pillHeight = 50.0;
  final ValueNotifier<Offset> _offsetNotifier = ValueNotifier(Offset.zero);
  int? _activePointer;
  bool _pointerMoved = false;
  DateTime? _lastTapAt;
  Offset? _lastTapPosition;

  @override
  void dispose() {
    _offsetNotifier.dispose();
    super.dispose();
  }

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
        // The old rectangular maxX/maxY limits allowed the pill's corners to
        // enter the preview card's curved corners. Keep the runtime card size
        // and its bounded squircle path together for both clipping and bounds.
        final previewSize = Size(
          constraints.hasBoundedWidth ? constraints.maxWidth : barWidth,
          constraints.hasBoundedHeight
              ? constraints.maxHeight
              : kLiquidGlassPreviewHeight,
        );
        final pillSize = Size(barWidth, _pillHeight);
        // The preview uses one fixed-radius outline for the card and pill.
        // Unlike a size-dependent superellipse, a fixed-radius outline nests
        // exactly at the card corners, so the pill can reach either corner
        // without an artificial inset.
        final previewPath = _liquidGlassPreviewPath(previewSize);
        final pillPath = _liquidGlassPreviewPath(pillSize);

        Offset clampOffset(Offset current, Offset target) {
          return _clampPreviewOffset(
            cardPath: previewPath,
            pillPath: pillPath,
            cardSize: previewSize,
            pillSize: pillSize,
            currentOffset: current,
            targetOffset: target,
          );
        }

        void handlePointerDown(PointerDownEvent event) {
          _activePointer = event.pointer;
          _pointerMoved = false;
        }

        void handlePointerMove(PointerMoveEvent event) {
          if (_activePointer != event.pointer) return;
          if (event.delta.distanceSquared > 0) _pointerMoved = true;
          final offset = _offsetNotifier.value;
          _offsetNotifier.value = clampOffset(offset, offset + event.delta);
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
              _offsetNotifier.value = Offset.zero;
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
              child: ValueListenableBuilder<Offset>(
                valueListenable: _offsetNotifier,
                builder: (context, offset, child) {
                  final boundedOffset = clampOffset(Offset.zero, offset);
                  return Transform.translate(
                    offset: boundedOffset,
                    child: child,
                  );
                },
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
                             height: _pillHeight,
                           ),
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
                           final style = _floatingTabBarStyle(
                             context,
                             exactClip: true,
                           );
                           return IgnorePointer(
                             child: LiquidGlassTabBar(
                               items: [
                                 _previewItem(SFIcons.sf_trash),
                                 _previewItem(SFIcons.sf_folder, size: 23),
                                 _previewItem(
                                   SFIcons.sf_arrowshape_turn_up_left,
                                 ),
                               ],
                               selectedIndex: 0,
                               onChanged: (_) {},
                               width: barWidth,
                               height: _pillHeight,
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

/// Tests the rendered pill outline against the preview card path. Sampling the
/// contour catches the pill's curved corners and straight-side extrema rather
/// than treating either shape as a rectangle.
bool _pillFitsPreview({
  required Path cardPath,
  required Path pillPath,
  required Size cardSize,
  required Size pillSize,
  required Offset offset,
}) {
  final pillRect = Rect.fromCenter(
    center: cardSize.center(Offset.zero) + offset,
    width: pillSize.width,
    height: pillSize.height,
  );
  final translatedPill = pillPath.shift(pillRect.topLeft);
  final cardCenter = cardSize.center(Offset.zero);

  for (final metric in translatedPill.computeMetrics()) {
    final sampleCount = math.max(12, (metric.length / 3).ceil());
    for (var index = 0; index <= sampleCount; index++) {
      final tangent = metric.getTangentForOffset(
        metric.length * index / sampleCount,
      );
      if (tangent == null ||
          !_cardContainsOrTouches(cardPath, tangent.position, cardCenter)) {
        return false;
      }
    }
  }
  return true;
}

bool _cardContainsOrTouches(Path cardPath, Offset point, Offset cardCenter) {
  if (cardPath.contains(point)) return true;
  final towardCenter = cardCenter - point;
  final distance = towardCenter.distance;
  if (distance == 0) return false;
  // Path.contains can reject a point exactly on the cubic boundary. A tiny
  // inward probe accepts that shared edge without allowing a visible overlap.
  return cardPath.contains(point + towardCenter * (0.08 / distance));
}

/// Clamps movement to the furthest legal point on each axis.
///
/// Solving the two axes independently avoids diagonal resistance at rounded
/// corners. A straight-line search from the current point to a diagonal target
/// stops on the corner arc before either axis can reach its legal edge.
Offset _clampPreviewOffset({
  required Path cardPath,
  required Path pillPath,
  required Size cardSize,
  required Size pillSize,
  required Offset currentOffset,
  required Offset targetOffset,
}) {
  bool fits(Offset offset) => _pillFitsPreview(
        cardPath: cardPath,
        pillPath: pillPath,
        cardSize: cardSize,
        pillSize: pillSize,
        offset: offset,
      );

  Offset start = fits(currentOffset) ? currentOffset : Offset.zero;
  if (!fits(start)) {
    // Keep the state centered if a responsive relayout temporarily makes the
    // preview smaller than the pill; do not reintroduce rectangular limits.
    return Offset.zero;
  }
  if (fits(targetOffset)) return targetOffset;

  Offset clampAxis(Offset from, Offset target, {required bool horizontal}) {
    final axisTarget = horizontal
        ? Offset(target.dx, from.dy)
        : Offset(from.dx, target.dy);
    if (fits(axisTarget)) return axisTarget;

    var low = from;
    var high = axisTarget;
    for (var iteration = 0; iteration < 14; iteration++) {
      final middle = Offset(
        (low.dx + high.dx) / 2,
        (low.dy + high.dy) / 2,
      );
      if (fits(middle)) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return low;
  }

  Offset solve(bool horizontalFirst) {
    var result = start;
    result = clampAxis(
      result,
      targetOffset,
      horizontal: horizontalFirst,
    );
    result = clampAxis(
      result,
      targetOffset,
      horizontal: !horizontalFirst,
    );
    return result;
  }

  final horizontalFirst = solve(true);
  final verticalFirst = solve(false);
  if (fits(horizontalFirst) && fits(verticalFirst)) {
    final horizontalDistance =
        (horizontalFirst - targetOffset).distanceSquared;
    final verticalDistance = (verticalFirst - targetOffset).distanceSquared;
    return horizontalDistance <= verticalDistance
        ? horizontalFirst
        : verticalFirst;
  }
  return fits(horizontalFirst) ? horizontalFirst : verticalFirst;
}

LiquidGlassStyle _floatingTabBarStyle(
  BuildContext context, {
  bool exactClip = false,
}) {
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
