import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, GlassQuality, LiquidRoundedRectangle;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass
    show
        DefaultButtonSettings,
        GlassExtraButtonPlacement,
        GlassTab,
        GlassTabBar,
        GlassTabBarExtraButton;
import 'package:flutter_sficon/flutter_sficon.dart';

import '../app_theme.dart';
import '../app_settings.dart';
import 'fixed_size_icon.dart';
import 'skeddo_glass_settings.dart';

/// Geometry shared by the Liquid Glass settings preview card and its
/// shape-aware movement boundary.
const double kLiquidGlassPreviewHeight = 154.0;
const double _kLandscapeTabSlotWidth = 88.0;
const double _kLandscapeTabIconSize = 16.0;
const double _kLandscapeTabLabelFontSize = 12.0;
const RoundedRectangleBorder kLiquidGlassPreviewCardShape =
    RoundedRectangleBorder(
      borderRadius: BorderRadius.all(Radius.circular(kSquircleStadiumRadius)),
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
    final maximumIndex = math
        .min(normalIndex + 1, nativeStops.length - 1)
        .toInt();
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
    final maximumIndex = math
        .min(normalIndex + 1, fallbackStops.length - 1)
        .toInt();
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
/// This widget owns the navigation-package bar, its four navigation tabs,
/// and its separate trailing action. AppShell remains responsible for
/// navigation, opening the event sheet, safe-area positioning, and overlay
/// ordering.
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
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: appLiquidGlassOpacityNotifier,
    builder: (context, _) => _buildTabBar(context),
  );

  Widget _buildTabBar(BuildContext context) {
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
    final landscapeIconSize = tabTextScaler.scale(_kLandscapeTabIconSize);
    final bottomOffset = floatingTabBarBottomOffset(context);
    final barGlassSettings = skeddoNavigationTabBarGlassSettingsFor(
      isDark ? Brightness.dark : Brightness.light,
    );
    final screenSize = MediaQuery.sizeOf(context);
    final isLandscape = screenSize.width > screenSize.height;

    navigation_glass.GlassTab landscapeTab(
      String label,
      IconData icon,
      IconData? activeIcon,
    ) {
      Widget content(IconData iconData, {required bool active}) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FixedSFIcon(iconData, fontSize: landscapeIconSize),
            const SizedBox(width: 6),
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: _kLandscapeTabLabelFontSize,
                // Let GlassTabBar's selected/unselected layers supply the
                // color. The active layer is clipped to the moving indicator,
                // so color follows the pill during its transition instead of
                // staying attached to the destination index.
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        );
      }

      return navigation_glass.GlassTab(
        icon: content(icon, active: false),
        // Supply an active variant even when its glyph is unchanged so the
        // label weight follows the same moving selected layer as its color.
        activeIcon: content(activeIcon ?? icon, active: true),
        semanticLabel: label,
      );
    }

    final tabs = isLandscape
        ? [
            landscapeTab('Home', SFIcons.sf_house, SFIcons.sf_house_fill),
            landscapeTab('Calendar', SFIcons.sf_calendar, null),
            landscapeTab('Events', SFIcons.sf_list_bullet, null),
            landscapeTab(
              'You',
              SFIcons.sf_person_crop_circle,
              SFIcons.sf_person_crop_circle_fill,
            ),
          ]
        : [
            navigation_glass.GlassTab(
              icon: FixedSFIcon(SFIcons.sf_house, fontSize: tabIconSize),
              activeIcon: FixedSFIcon(
                SFIcons.sf_house_fill,
                fontSize: tabIconSize,
              ),
              label: 'Home',
            ),
            navigation_glass.GlassTab(
              icon: FixedSFIcon(SFIcons.sf_calendar, fontSize: tabIconSize),
              label: 'Calendar',
            ),
            navigation_glass.GlassTab(
              icon: FixedSFIcon(SFIcons.sf_list_bullet, fontSize: tabIconSize),
              label: 'Events',
            ),
            navigation_glass.GlassTab(
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
          ];
    final tabBar = navigation_glass.GlassTabBar.bottom(
      tabs: tabs,
      selectedIndex: selectedIndex,
      onTabSelected: widget.onTabSelected,
      tabWidth: isLandscape ? _kLandscapeTabSlotWidth : null,
      extraButton: navigation_glass.GlassTabBarExtraButton(
        icon: const FixedSFIcon(SFIcons.sf_plus),
        onTap: widget.onCreateEvent,
        label: 'New Event',
        iconColor: selectedColor,
        placement: navigation_glass.GlassExtraButtonPlacement.right,
        size: kFloatingTabBarHeight,
      ),
      barHeight: kFloatingTabBarHeight,
      verticalPadding: 0,
      iconSize: isLandscape ? landscapeIconSize : 20,
      labelFontSize: 9,
      iconLabelSpacing: 1.5,
      magnification: 1,
      settings: barGlassSettings,
      indicatorSettings: skeddoNavigationTabIndicatorGlassSettings(
        isDark ? Brightness.dark : Brightness.light,
      ),
      innerBlur: skeddoActiveTabIndicatorBlurForPosition(
        liquidGlassSliderPositionForOpacity(
          appLiquidGlassOpacityNotifier.value,
        ),
      ),
      indicatorColor: isDark
          ? kFloatingTabBarDarkIndicatorColor
          : kFloatingTabBarLightIndicatorColor,
      selectedIconColor: selectedColor,
      unselectedIconColor: unselectedColor,
      selectedLabelColor: selectedColor,
      unselectedLabelColor: unselectedColor,
      // The landscape row nearly fills its equal-width slot. Keep the
      // selected-color mask inside the moving pill at horizontal edges, rather
      // than letting the default 12pt horizontal jelly bloom tint the leading
      // pixels of the neighboring tab's icon. Preserve the vertical lift, and
      // leave portrait on the package's normal expansion.
      indicatorExpansion: isLandscape
          ? const EdgeInsets.symmetric(vertical: 8)
          : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );

    return Semantics(
      container: true,
      label: 'Main navigation',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final layoutSize = MediaQuery.sizeOf(context);
          final isPortrait = layoutSize.width <= layoutSize.height;
          final availableBarWidth =
              constraints.maxWidth - (kFloatingTabBarHorizontalMargin * 2);
          final landscapeContentWidth =
              (_kLandscapeTabSlotWidth * tabs.length) +
              (tabBar.extraButton?.size ?? 0) +
              (tabBar.extraButton == null ? 0 : tabBar.spacing);
          final frameWidth =
              ((isPortrait ? availableBarWidth : landscapeContentWidth) +
                      tabBar.horizontalPadding * 2)
                  .clamp(0.0, constraints.maxWidth)
                  .toDouble();
          final barSideInset = (constraints.maxWidth - frameWidth) / 2;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: barSideInset,
                bottom: bottomOffset - tabBar.verticalPadding,
                width: frameWidth,
                height: tabBar.preferredSize.height,
                child: AnimatedSlide(
                  duration: widget.animateHorizontalOffset
                      ? kDcvPaneTransitionDuration
                      : Duration.zero,
                  curve: Curves.easeInOutCubic,
                  offset: Offset(
                    frameWidth == 0 ? 0 : widget.horizontalOffset / frameWidth,
                    0,
                  ),
                  child: MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: tabTextScaler),
                    child: Builder(
                      builder: (scaledContext) => MediaQuery.removePadding(
                        context: scaledContext,
                        removeBottom: true,
                        child: navigation_glass.DefaultButtonSettings(
                          settings: barGlassSettings,
                          child: tabBar,
                        ),
                      ),
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
/// The live navigation bar uses `liquid_glass_widgets`; this sample remains
/// intentionally separate from that control but reuses its shared glass settings.
class FloatingTabBarGlassPreview extends StatefulWidget {
  final double sliderPosition;

  const FloatingTabBarGlassPreview({super.key, required this.sliderPosition});

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
    final standardBarWidth = (width - (kFloatingTabBarHorizontalMargin * 2))
        .clamp(150.0, 190.0);
    final minBarWidth =
        (_previewItemPadding * 2) + (3 * (scaledIconSlot + _previewIconGap));
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
        final maxX = math.max(0.0, (previewSize.width - pillSize.width) / 2);
        final maxY = math.max(0.0, (previewSize.height - pillSize.height) / 2);
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
            final isDoubleTap =
                _lastTapAt != null &&
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
                                skeddoBottomBarGlassSettingsFor(
                                  brightness,
                                  sliderPosition: widget.sliderPosition,
                                );
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
  return Path()..addRRect(
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
