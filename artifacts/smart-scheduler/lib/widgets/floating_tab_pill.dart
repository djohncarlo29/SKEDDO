import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassContainer,
        GlassExtraButtonPlacement,
        GlassQuality,
        GlassTab,
        GlassTabBar,
        GlassTabBarExtraButton,
        LiquidRoundedRectangle;
import 'package:flutter_sficon/flutter_sficon.dart';

import '../app_theme.dart';
import '../app_settings.dart';
import 'fixed_size_icon.dart';
import 'skeddo_glass_settings.dart';

/// Geometry shared by the Liquid Glass settings preview card and its
/// shape-aware movement boundary.
const double kLiquidGlassPreviewHeight = 154.0;
const RoundedRectangleBorder kLiquidGlassPreviewCardShape =
    RoundedRectangleBorder(
  borderRadius: BorderRadius.all(
    Radius.circular(kSquircleStadiumRadius),
  ),
);

/// Preserves smaller text settings while limiting the tab bar to one native
/// accessibility-size stop above the platform's normal size.
TextScaler skeddoTabBarTextScalerFor(TextScaler source) {
  final nativeStops = appNativeTextScaleProfileNotifier.value?.stops;
  late final TextScaler maximum;

  if (nativeStops != null && nativeStops.isNotEmpty) {
    var normalIndex = 0;
    var normalDistance = double.infinity;
    for (var index = 0; index < nativeStops.length; index++) {
      final distance = (nativeStops[index].scale - 1.0).abs();
      if (distance < normalDistance) {
        normalDistance = distance;
        normalIndex = index;
      }
    }
    final maximumIndex =
        math.min(normalIndex + 1, nativeStops.length - 1).toInt();
    final stop = nativeStops[maximumIndex];
    maximum = stop.scaler ?? TextScaler.linear(stop.scale);
  } else {
    final fallbackStops = appSkeddoTextScaleStopsNotifier.value;
    if (fallbackStops.isEmpty) return source;
    var normalIndex = 0;
    var normalDistance = double.infinity;
    for (var index = 0; index < fallbackStops.length; index++) {
      final distance = (fallbackStops[index] - 1.0).abs();
      if (distance < normalDistance) {
        normalDistance = distance;
        normalIndex = index;
      }
    }
    final maximumIndex =
        math.min(normalIndex + 1, fallbackStops.length - 1).toInt();
    maximum = TextScaler.linear(fallbackStops[maximumIndex]);
  }

  return _UpperBoundedTextScaler(source, maximum);
}

class _UpperBoundedTextScaler extends TextScaler {
  const _UpperBoundedTextScaler(this.source, this.maximum);

  final TextScaler source;
  final TextScaler maximum;

  @override
  double scale(double fontSize) {
    final scaled = source.scale(fontSize);
    final maximumScaled = maximum.scale(fontSize);
    return scaled <= maximumScaled ? scaled : maximumScaled;
  }

  @override
  double get textScaleFactor => scale(16) / 16;

  @override
  bool operator ==(Object other) =>
      other is _UpperBoundedTextScaler &&
      other.source == source &&
      other.maximum == maximum;

  @override
  int get hashCode => Object.hash(source, maximum);
}

/// The AppShell's platform-neutral floating tab control.
///
/// This widget owns the package bar, its four navigation tabs, and its
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
    final tabTextScaler = skeddoTabBarTextScalerFor(
      MediaQuery.textScalerOf(context),
    );
    final tabIconSize = tabTextScaler.scale(20);
    final bottomOffset = floatingTabBarBottomOffset(context);
    final tabBar = GlassTabBar.bottom(
      tabs: [
        GlassTab(
          icon: FixedSFIcon(SFIcons.sf_house, fontSize: tabIconSize),
          activeIcon: FixedSFIcon(SFIcons.sf_house_fill, fontSize: tabIconSize),
          label: 'Home',
        ),
        GlassTab(
          icon: FixedSFIcon(SFIcons.sf_calendar, fontSize: tabIconSize),
          label: 'Calendar',
        ),
        GlassTab(
          icon: FixedSFIcon(SFIcons.sf_list_bullet, fontSize: tabIconSize),
          label: 'Events',
        ),
        GlassTab(
          icon: FixedSFIcon(
            SFIcons.sf_person_crop_circle,
            fontSize: tabIconSize,
          ),
          activeIcon: FixedSFIcon(
            SFIcons.sf_person_crop_circle_fill,
            fontSize: tabIconSize,
          ),
          label: 'You',
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
      iconLabelSpacing: 1.5,
      magnification: 1,
      settings: skeddoTabBarGlassSettingsFor(
        isDark ? Brightness.dark : Brightness.light,
      ),
      indicatorSettings: isDark
          ? null
          : kSkeddoLightLiftedTabIndicatorSettings,
      innerBlur: 3,
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
                child: MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: tabTextScaler),
                  child: Builder(
                    builder: (scaledContext) => MediaQuery.removePadding(
                      context: scaledContext,
                      removeBottom: true,
                      child: tabBar,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A package-rendered glass sample for the Settings opacity control.
///
/// The live Flutter navigation bar uses `GlassTabBar.bottom`; this sample is
/// intentionally separate from that control but reuses its shared glass settings.
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
    final width = MediaQuery.sizeOf(context).width;
    final textScaler = skeddoTabBarTextScalerFor(
      MediaQuery.textScalerOf(context),
    );
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
        final maxX = math.max(
          0.0,
          (previewSize.width - pillSize.width) / 2,
        );
        final maxY = math.max(
          0.0,
          (previewSize.height - pillSize.height) / 2,
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
                        // The Settings preview is a visual sample, not a
                        // second navigation control. Ignore the tab bar's own
                        // hit testing; the preview pointer handlers own drag
                        // and double-tap behavior.
                        Builder(
                          builder: (context) {
                            final brightness = CupertinoTheme.brightnessOf(
                              context,
                            );
                            final sharedSettings =
                                skeddoBottomBarGlassSettingsFor(brightness);
                            final iconColor = resolveThemeColor(
                              kSecondaryLabel,
                              context,
                            );
                            return IgnorePointer(
                              child: GlassContainer(
                                width: barWidth,
                                height: pillHeight,
                                shape: const LiquidRoundedRectangle(
                                  borderRadius: kSquircleStadiumRadius,
                                ),
                                settings: sharedSettings,
                                quality: GlassQuality.premium,
                                useOwnLayer: true,
                                child: Row(
                                  children: [
                                    _previewItem(
                                      SFIcons.sf_trash,
                                      size: 21,
                                      opticalScale: 1.0,
                                      color: iconColor,
                                      textScaler: textScaler,
                                    ),
                                    _previewItem(
                                      SFIcons.sf_folder,
                                      size: 27,
                                      opticalScale: 0.775,
                                      color: iconColor,
                                      textScaler: textScaler,
                                    ),
                                    _previewItem(
                                      SFIcons.sf_arrowshape_turn_up_left,
                                      size: 25.5,
                                      opticalScale: 0.825,
                                      color: iconColor,
                                      textScaler: textScaler,
                                    ),
                                  ],
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

  Widget _previewItem(
    IconData icon, {
    required double size,
    required double opticalScale,
    required Color color,
    required TextScaler textScaler,
  }) {
    final iconSlot = textScaler.scale(_previewIconReferenceSize);
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(_previewItemPadding),
        child: SizedBox(
          width: iconSlot,
          height: iconSlot,
          child: Center(
            child: UnconstrainedBox(
              clipBehavior: Clip.none,
              child: Transform.scale(
                scale: opticalScale,
                child: FixedSFIcon(
                  icon,
                  fontSize: textScaler.scale(size),
                  fontWeight: FontWeight.normal,
                  color: color,
                ),
              ),
            ),
          ),
        ),
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
