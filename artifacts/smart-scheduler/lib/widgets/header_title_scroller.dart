import 'package:flutter/cupertino.dart';
import '../app_settings.dart';

const double kHeaderTitleBaseFontSize = 34;

/// Returns the Large Header size for the active text-size position.
///
/// Headers use the current OS/custom profile around the default position, but
/// are intentionally bounded to one position below or above default so the
/// fixed-height header remains stable at accessibility extremes.
double headerTitleFontSize(
  BuildContext context, {
  double baseFontSize = kHeaderTitleBaseFontSize,
}) {
  final skeddoStops = appSkeddoTextScaleStops;
  final nativeProfile = appNativeTextScaleProfileNotifier.value;
  final usesSystem = appTextSizeUsesSystemNotifier.value;
  final nativeStops = nativeProfile?.stops;
  final stops = usesSystem && nativeStops != null && nativeStops.length >= 2
      ? nativeStops.map((stop) => stop.scale).toList(growable: false)
      : skeddoStops;
  if (stops.isEmpty || !baseFontSize.isFinite || baseFontSize <= 0) {
    return baseFontSize;
  }

  int nearestStopIndex(double target) {
    var closestIndex = 0;
    var closestDistance = double.infinity;
    for (var index = 0; index < stops.length; index++) {
      final distance = (stops[index] - target).abs();
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIndex = index;
      }
    }
    return closestIndex;
  }

  // The default is the profile stop representing the platform's normal
  // 1.0 scale. It is not necessarily the middle Custom tick: Android and
  // iOS expose different numbers and positions of native text-size stops.
  final defaultIndex = nearestStopIndex(1.0);
  final activeIndex = usesSystem
      ? nearestStopIndex(appSystemTextScaleNotifier.value)
      : appTextSizeIndexNotifier.value;
  final lowerIndex = (defaultIndex - 1).clamp(0, stops.length - 1);
  final upperIndex = (defaultIndex + 1).clamp(0, stops.length - 1);
  final boundedIndex = activeIndex.clamp(lowerIndex, upperIndex).toInt();

  double scaledSizeAt(int index) {
    final scaler = usesSystem && nativeStops != null && nativeStops.length >= 2
        ? nativeStops[index].scaler
        : index < appSkeddoTextScaleMappingNotifier.value.length
        ? appSkeddoTextScaleMappingNotifier.value[index].scaler
        : null;
    if (scaler != null) {
      final scaled = scaler.scale(baseFontSize);
      if (scaled.isFinite && scaled > 0) return scaled;
    }
    if (!usesSystem && index < appSkeddoTextScaleMappingNotifier.value.length) {
      final scaler = appSkeddoTextScaleMappingNotifier.value[index].scaler;
      if (scaler != null) {
        final scaled = scaler.scale(baseFontSize);
        if (scaled.isFinite && scaled > 0) return scaled;
      }
    }
    return baseFontSize * stops[index];
  }

  final defaultSize = scaledSizeAt(defaultIndex);
  final boundedSize = scaledSizeAt(boundedIndex);
  if (!defaultSize.isFinite || defaultSize <= 0) return baseFontSize;
  return baseFontSize * boundedSize / defaultSize;
}

/// A single-line Large Header title that can be explored horizontally when its
/// rendered width is larger than the title slot.
///
/// The title keeps the Large Header's authored size and height.  Edge fades
/// communicate whether more content is available in either direction:
/// start-only, both, or end-only depending on the current scroll position.
class HeaderTitleScroller extends StatefulWidget {
  final String title;
  final TextStyle style;
  final Color fadeColor;
  final double fadeWidth;
  final Widget? trailing;
  final double trailingGap;
  final bool showTrailingFade;

  const HeaderTitleScroller({
    super.key,
    required this.title,
    required this.style,
    required this.fadeColor,
    this.fadeWidth = 36,
    this.trailing,
    this.trailingGap = 4,
    this.showTrailingFade = true,
  });

  @override
  State<HeaderTitleScroller> createState() => _HeaderTitleScrollerState();
}

class _HeaderTitleScrollerState extends State<HeaderTitleScroller> {
  late final ScrollController _scrollController;
  bool _showLeadingFade = false;
  bool _showTrailingFade = false;
  bool _overscrollingLeading = false;
  bool _overscrollingTrailing = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_updateFades);
    _scheduleFadeUpdate();
  }

  @override
  void didUpdateWidget(covariant HeaderTitleScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title) {
      // Every newly displayed title starts at its logical beginning, including
      // titles arriving through the tab/DCV and Settings navigation animations.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(0);
        _updateFades();
      });
    } else {
      _scheduleFadeUpdate();
    }
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_updateFades)
      ..dispose();
    super.dispose();
  }

  void _scheduleFadeUpdate() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _updateFades();
    });
  }

  void _updateFades() {
    if (!mounted || !_scrollController.hasClients) return;
    final position = _scrollController.position;
    final maxExtent = position.maxScrollExtent;
    final offset = position.pixels;
    final hasOverflow = maxExtent > 0.5;
    final isOverscrollingLeading = _overscrollingLeading || offset < -0.5;
    final isOverscrollingTrailing =
        _overscrollingTrailing || offset > maxExtent + 0.5;
    // Use the actual extents instead of a raw offset threshold. This makes
    // the fade disappear as soon as the scroll position is truly at an edge,
    // including while a rubberband settles back into place.
    final showLeading =
        (hasOverflow && position.extentBefore > 0.5) || isOverscrollingLeading;
    final showTrailing =
        widget.showTrailingFade &&
        ((hasOverflow && position.extentAfter > 0.5) ||
            isOverscrollingTrailing);

    if (showLeading == _showLeadingFade && showTrailing == _showTrailingFade) {
      return;
    }
    setState(() {
      _showLeadingFade = showLeading;
      _showTrailingFade = showTrailing;
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.horizontal) return false;
    if (notification is ScrollStartNotification) {
      _overscrollingLeading = false;
      _overscrollingTrailing = false;
    } else if (notification is OverscrollNotification) {
      _overscrollingLeading = notification.overscroll < -0.5;
      _overscrollingTrailing = notification.overscroll > 0.5;
    } else if (notification is ScrollEndNotification) {
      _overscrollingLeading = false;
      _overscrollingTrailing = false;
    }
    _updateFades();
    return false;
  }

  bool _handleMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.metrics.axis == Axis.horizontal) {
      _updateFades();
    }
    return false;
  }

  Widget _buildFade({required bool visible, required bool opaqueAtStart}) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: SizedBox(
          width: widget.fadeWidth,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: opaqueAtStart
                    ? [widget.fadeColor, widget.fadeColor.withValues(alpha: 0)]
                    : [widget.fadeColor.withValues(alpha: 0), widget.fadeColor],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        appTextSizeUsesSystemNotifier,
        appTextSizeIndexNotifier,
        appSystemTextScaleNotifier,
        appSkeddoTextScaleMappingNotifier,
        appNativeTextScaleProfileNotifier,
      ]),
      builder: (context, _) {
        final effectiveStyle = widget.style.copyWith(
          fontSize: headerTitleFontSize(
            context,
            baseFontSize: widget.style.fontSize ?? kHeaderTitleBaseFontSize,
          ),
        );
        return Semantics(
          label: widget.title,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: ClipRect(
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: _handleMetricsNotification,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: SizedBox(
                        width: double.infinity,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          primary: false,
                          scrollDirection: Axis.horizontal,
                          // A title that fits completely is not scrollable, so it
                          // cannot rubberband or display an edge fade. Overflowing
                          // titles retain native bouncing at their real edges.
                          physics: const BouncingScrollPhysics(),
                          padding: EdgeInsets.zero,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                widget.title,
                                maxLines: 1,
                                softWrap: false,
                                overflow: TextOverflow.visible,
                                // Large Header titles are intentionally fixed-height. The
                                // rest of the app continues to follow the bounded
                                // header scale above instead of the ambient scaler.
                                textScaler: TextScaler.noScaling,
                                style: effectiveStyle,
                              ),
                              if (widget.trailing != null) ...[
                                SizedBox(width: widget.trailingGap),
                                widget.trailing!,
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      child: _buildFade(
                        visible: _showLeadingFade,
                        opaqueAtStart: true,
                      ),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      child: _buildFade(
                        visible: _showTrailingFade,
                        opaqueAtStart: false,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
