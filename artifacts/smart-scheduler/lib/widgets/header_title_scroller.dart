import 'package:flutter/cupertino.dart';
import '../app_settings.dart';

const double kHeaderTitleBaseFontSize = 34;
// Shared bottom breathing room for every large header title. Keeping this
// outside the individual screens prevents baseline drift between tabs and
// Settings sub-screens.
const double kHeaderTitleBottomInset = 10;

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
  // Tracks real overflow for edge fades.  This is intentionally separate from
  // the scroll physics: even a short title should accept the native
  // rubberband gesture when the user pulls it.
  bool _canScroll = false;
  bool _resettingTitle = false;
  bool _showLeadingFade = false;
  bool _showTrailingFade = false;

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
      // Clear the old title's edge state immediately; otherwise the previous
      // title's fade can paint for one frame before the post-layout reset.
      _resettingTitle = true;
      _canScroll = false;
      // Reset the actual scroll offset synchronously as well. Waiting for the
      // post-layout callback lets a newly mounted short title inherit the old
      // screen's offset and appear clipped before its state is corrected.
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
      _resettingTitle = false;
      if (_showLeadingFade || _showTrailingFade) {
        _showLeadingFade = false;
        _showTrailingFade = false;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_scrollController.hasClients) return;
        _scrollController.jumpTo(0);
        _syncScrollEdgeFades(_scrollController.position);
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
    if (!mounted || _resettingTitle || !_scrollController.hasClients) return;
    _syncScrollEdgeFades(_scrollController.position);
  }

  void _syncScrollEdgeFades(ScrollMetrics metrics) {
    final canScroll = metrics.maxScrollExtent > 1.0;
    // Do not gate these on [canScroll]. A short title has maxScrollExtent == 0
    // but can still rubberband past either edge; the clipped pixels need the
    // same fade treatment as a long title.
    final showLeading = metrics.pixels > 1.0;
    final showTrailing =
        widget.showTrailingFade &&
        metrics.pixels < metrics.maxScrollExtent - 1.0;

    if (_canScroll == canScroll &&
        showLeading == _showLeadingFade &&
        showTrailing == _showTrailingFade) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _canScroll = canScroll;
      _showLeadingFade = showLeading;
      _showTrailingFade = showTrailing;
    });
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.horizontal) return false;
    _syncScrollEdgeFades(notification.metrics);
    return false;
  }

  bool _handleMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.metrics.axis == Axis.horizontal) {
      _syncScrollEdgeFades(notification.metrics);
    }
    return false;
  }

  Widget _buildFade({required bool visible, required bool opaqueAtStart}) {
    if (!visible) return const SizedBox.shrink();
    return IgnorePointer(
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Scroll metrics arrive after layout. Preflight the text
                    // width so an overflowing title has its initial trailing
                    // fade in the very first painted frame.
                    final overflowBeforeLayout =
                        _textOverflowsViewport(effectiveStyle, constraints.maxWidth);
                    final initialTrailingFade =
                        !_canScroll &&
                        overflowBeforeLayout &&
                        widget.showTrailingFade &&
                        (!_scrollController.hasClients ||
                            _scrollController.position.pixels <= 1.0);

                    return Stack(
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
                              // Headers always accept the native rubberband gesture,
                              // including titles that fit completely.  _canScroll
                              // remains only an overflow/fade decision; it must not
                              // disable the gesture for short titles.
                              physics: const BouncingScrollPhysics(
                                parent: AlwaysScrollableScrollPhysics(),
                              ),
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
                            visible:
                                _showTrailingFade || initialTrailingFade,
                            opaqueAtStart: false,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  bool _textOverflowsViewport(TextStyle style, double viewportWidth) {
    if (!viewportWidth.isFinite || viewportWidth <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(text: widget.title, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    return painter.width > viewportWidth + 1.0;
  }
}
