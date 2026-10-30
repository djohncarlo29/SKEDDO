import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart'
    show kTouchSlop, PointerDownEvent, PointerEvent, PointerMoveEvent;
import '../app_settings.dart';
import 'app_header_scroll_edge.dart'
    show kAppHeaderTitleTextBottomInset;

const double kHeaderTitleBaseFontSize = 34;
// Shared bottom breathing room for every large header title. Keeping this
// outside the individual screens prevents baseline drift between tabs and
// Settings sub-screens.
const double kHeaderTitleBottomInset = kAppHeaderTitleTextBottomInset;

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
  final GlobalKey? titleTextKey;
  final TextStyle style;
  /// Retained for compatibility with existing callers. Edge fades now mask
  /// title pixels by opacity and do not paint this surface color.
  final Color fadeColor;
  final double fadeWidth;
  final Widget? leading;
  final Widget Function(double titleFontSize)? leadingBuilder;
  final double leadingGap;
  /// Natural width of leading content, used with [centerWhenContentFits].
  final double? leadingContentWidth;
  final Widget? trailing;
  final Widget Function(double titleFontSize)? trailingBuilder;
  final double trailingGap;
  /// Natural width of the trailing content, used with
  /// [centerWhenContentFits] to center the complete title-and-controls group.
  final double? trailingContentWidth;
  final bool showTrailingFade;
  /// Keep edge fades hidden until the user has moved this title horizontally.
  /// This preserves a clean, centered resting state for selected scrollers.
  final bool fadeAfterUserScroll;
  /// Show edge fades only during an active horizontal pointer drag. Unlike
  /// [fadeAfterUserScroll], the fades disappear immediately when the pointer
  /// is released, even if the title remains scrolled.
  final bool fadeOnlyDuringHorizontalDrag;
  final bool centerWhenContentFits;
  final Alignment contentAlignment;
  final CrossAxisAlignment contentCrossAxisAlignment;
  final VoidCallback? onTap;

  const HeaderTitleScroller({
    super.key,
    required this.title,
    this.titleTextKey,
    required this.style,
    required this.fadeColor,
    this.fadeWidth = 36,
    this.leading,
    this.leadingBuilder,
    this.leadingGap = 4,
    this.leadingContentWidth,
    this.trailing,
    this.trailingBuilder,
    this.trailingGap = 4,
    this.trailingContentWidth,
    this.showTrailingFade = true,
    this.fadeAfterUserScroll = false,
    this.fadeOnlyDuringHorizontalDrag = false,
    this.centerWhenContentFits = false,
    this.contentAlignment = Alignment.bottomLeft,
    this.contentCrossAxisAlignment = CrossAxisAlignment.center,
    this.onTap,
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
  bool _hasUserScrolledTitle = false;
  bool _showLeadingFade = false;
  bool _showTrailingFade = false;
  int? _titlePointerId;
  Offset? _titlePointerDownPosition;
  bool _isActiveHorizontalDrag = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_updateFades);
    _scheduleFadeUpdate();
  }

  @override
  void didUpdateWidget(covariant HeaderTitleScroller oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fadeOnlyDuringHorizontalDrag &&
        !widget.fadeOnlyDuringHorizontalDrag) {
      _titlePointerId = null;
      _titlePointerDownPosition = null;
      _isActiveHorizontalDrag = false;
    }
    if (oldWidget.title != widget.title) {
      // Every newly displayed title starts at its logical beginning, including
      // titles arriving through the tab/DCV and Settings navigation animations.
      // Clear the old title's edge state immediately; otherwise the previous
      // title's fade can paint for one frame before the post-layout reset.
      _resettingTitle = true;
      _canScroll = false;
      _hasUserScrolledTitle = false;
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

  void _handleTitlePointerDown(PointerDownEvent event) {
    if (!widget.fadeOnlyDuringHorizontalDrag || _titlePointerId != null) return;
    _titlePointerId = event.pointer;
    _titlePointerDownPosition = event.position;
  }

  void _handleTitlePointerMove(PointerMoveEvent event) {
    if (!widget.fadeOnlyDuringHorizontalDrag ||
        event.pointer != _titlePointerId ||
        _isActiveHorizontalDrag) {
      return;
    }
    final start = _titlePointerDownPosition;
    if (start == null) return;
    final movement = event.position - start;
    if (movement.dx.abs() < kTouchSlop ||
        movement.dx.abs() <= movement.dy.abs()) {
      return;
    }
    _setActiveHorizontalDrag(true);
  }

  void _handleTitlePointerEnd(PointerEvent event) {
    if (event.pointer != _titlePointerId) return;
    _titlePointerId = null;
    _titlePointerDownPosition = null;
    _setActiveHorizontalDrag(false);
  }

  void _setActiveHorizontalDrag(bool isActive) {
    if (_isActiveHorizontalDrag == isActive) return;
    _isActiveHorizontalDrag = isActive;
    if (!mounted) return;
    if (_scrollController.hasClients) {
      _syncScrollEdgeFades(
        _scrollController.position,
        forceRebuild: true,
      );
    } else {
      setState(() {});
    }
  }

  void _syncScrollEdgeFades(
    ScrollMetrics metrics, {
    bool forceRebuild = false,
  }) {
    final canScroll = metrics.maxScrollExtent > 1.0;
    final showFades = widget.fadeOnlyDuringHorizontalDrag
        ? _isActiveHorizontalDrag
        : !widget.fadeAfterUserScroll || _hasUserScrolledTitle;
    // Do not gate these on [canScroll]. A short title has maxScrollExtent == 0
    // but can still rubberband past either edge; the clipped pixels need the
    // same fade treatment as a long title.
    final showLeading = showFades && metrics.pixels > 1.0;
    final showTrailing =
        showFades &&
        widget.showTrailingFade &&
        metrics.pixels < metrics.maxScrollExtent - 1.0;

    if (_canScroll == canScroll &&
        showLeading == _showLeadingFade &&
        showTrailing == _showTrailingFade &&
        !forceRebuild) {
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
    if (!widget.fadeOnlyDuringHorizontalDrag &&
        widget.fadeAfterUserScroll &&
        !_hasUserScrolledTitle) {
      final movedByUserDrag =
          (notification is ScrollUpdateNotification &&
              notification.dragDetails != null &&
              (notification.scrollDelta?.abs() ?? 0) > 0) ||
          (notification is OverscrollNotification &&
              notification.dragDetails != null &&
              notification.overscroll.abs() > 0);
      if (movedByUserDrag) _hasUserScrolledTitle = true;
    }
    _syncScrollEdgeFades(notification.metrics);
    return false;
  }

  bool _handleMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.metrics.axis == Axis.horizontal) {
      _syncScrollEdgeFades(notification.metrics);
    }
    return false;
  }

  Widget _applyFadeMask({
    required Widget child,
    required bool showLeading,
    required bool showTrailing,
  }) {
    return ShaderMask(
      blendMode: showLeading || showTrailing
          ? BlendMode.dstIn
          : BlendMode.dst,
      shaderCallback: (bounds) {
        // dstIn uses only the shader's alpha. Transparent portions reveal the
        // real content behind the header instead of painting a surface tint.
        //
        // Keep this mask mounted even when no edge is faded. Inserting it only
        // after a drag would remount the ScrollView and cancel rubberbanding.
        final width = bounds.width;
        if ((!showLeading && !showTrailing) ||
            widget.fadeWidth <= 0 ||
            !width.isFinite ||
            width <= 0) {
          return const LinearGradient(
            colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
          ).createShader(bounds);
        }

        final maxFadeWidth =
            width / (showLeading && showTrailing ? 2.0 : 1.0);
        final fadeWidth = widget.fadeWidth
            .clamp(0.0, maxFadeWidth)
            .toDouble();
        final leadingStop = fadeWidth / width;
        final trailingStart = 1.0 - leadingStop;

        if (showLeading && showTrailing) {
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [
              Color(0x00000000),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
              Color(0x00000000),
            ],
            stops: [0.0, leadingStop, trailingStart, 1.0],
          ).createShader(bounds);
        }
        if (showLeading) {
          return LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [Color(0x00000000), Color(0xFFFFFFFF)],
            stops: [0.0, leadingStop],
          ).createShader(bounds);
        }
        return LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: const [Color(0xFFFFFFFF), Color(0x00000000)],
          stops: [trailingStart, 1.0],
        ).createShader(bounds);
      },
      child: child,
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
        final trailing =
            widget.trailingBuilder?.call(
              effectiveStyle.fontSize ?? kHeaderTitleBaseFontSize,
            ) ??
            widget.trailing;
        final leading =
            widget.leadingBuilder?.call(
              effectiveStyle.fontSize ?? kHeaderTitleBaseFontSize,
            ) ??
            widget.leading;
        return Semantics(
          label: widget.title,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: ClipRect(
              child: NotificationListener<ScrollMetricsNotification>(
                onNotification: _handleMetricsNotification,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Scroll metrics arrive after layout. Preflight the full
                    // title-and-controls width so an overflowing group has its
                    // initial trailing fade in the very first painted frame.
                    final textWidth = _measureTextWidth(effectiveStyle);
                    final hasUnknownControlWidth =
                        (leading != null &&
                            widget.leadingContentWidth == null) ||
                        (trailing != null &&
                            widget.trailingContentWidth == null);
                    final naturalContentWidth = hasUnknownControlWidth
                        ? double.infinity
                        : (leading == null
                              ? 0.0
                              : widget.leadingGap +
                                    widget.leadingContentWidth!) +
                              textWidth +
                              (trailing == null
                                  ? 0.0
                                  : widget.trailingGap +
                                        widget.trailingContentWidth!);
                    final overflowBeforeLayout =
                        constraints.maxWidth.isFinite &&
                        constraints.maxWidth > 0 &&
                        (naturalContentWidth.isFinite
                                ? naturalContentWidth
                                : textWidth) >
                            constraints.maxWidth + 1.0;
                    final initialTrailingFade =
                        (widget.fadeOnlyDuringHorizontalDrag
                                ? _isActiveHorizontalDrag
                                : !widget.fadeAfterUserScroll ||
                                      _hasUserScrolledTitle) &&
                        !_canScroll &&
                        overflowBeforeLayout &&
                        widget.showTrailingFade &&
                        (!_scrollController.hasClients ||
                            _scrollController.position.pixels <= 1.0);
                    final showLeadingFade = _showLeadingFade;
                    final showTrailingFade =
                        _showTrailingFade || initialTrailingFade;
                    final centeredInset =
                        widget.centerWhenContentFits &&
                            constraints.maxWidth.isFinite &&
                            constraints.maxWidth > 0 &&
                            !overflowBeforeLayout &&
                            naturalContentWidth <= constraints.maxWidth
                        ? ((constraints.maxWidth - naturalContentWidth) / 2)
                              .clamp(0.0, double.infinity)
                              .toDouble()
                        : 0.0;

                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        Align(
                          alignment: widget.contentAlignment,
                          child: SizedBox(
                            width: double.infinity,
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: widget.onTap,
                              child: _applyFadeMask(
                                showLeading: showLeadingFade,
                                showTrailing: showTrailingFade,
                                child: Listener(
                                  onPointerDown:
                                      widget.fadeOnlyDuringHorizontalDrag
                                      ? _handleTitlePointerDown
                                      : null,
                                  onPointerMove:
                                      widget.fadeOnlyDuringHorizontalDrag
                                      ? _handleTitlePointerMove
                                      : null,
                                  onPointerUp:
                                      widget.fadeOnlyDuringHorizontalDrag
                                      ? _handleTitlePointerEnd
                                      : null,
                                  onPointerCancel:
                                      widget.fadeOnlyDuringHorizontalDrag
                                      ? _handleTitlePointerEnd
                                      : null,
                                  child: SingleChildScrollView(
                                    controller: _scrollController,
                                    primary: false,
                                    scrollDirection: Axis.horizontal,
                                    // Headers always accept the native
                                    // rubberband gesture, even when short.
                                    // _canScroll only decides whether a fade is
                                    // visible; it never disables the gesture.
                                    physics: const BouncingScrollPhysics(
                                      parent: AlwaysScrollableScrollPhysics(),
                                    ),
                                    padding: EdgeInsets.zero,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment:
                                          widget.contentCrossAxisAlignment,
                                      children: [
                                        if (centeredInset > 0)
                                          SizedBox(width: centeredInset),
                                        if (leading != null) ...[
                                          leading,
                                          if (widget.leadingGap > 0)
                                            SizedBox(width: widget.leadingGap),
                                        ],
                                        Text(
                                          key: widget.titleTextKey,
                                          widget.title,
                                          maxLines: 1,
                                          softWrap: false,
                                          overflow: TextOverflow.visible,
                                          // Large Header titles are fixed-height
                                          // and use the bounded header scale.
                                          textScaler: TextScaler.noScaling,
                                          style: effectiveStyle,
                                        ),
                                        if (trailing != null) ...[
                                          SizedBox(width: widget.trailingGap),
                                          trailing,
                                        ],
                                        if (centeredInset > 0)
                                          SizedBox(width: centeredInset),
                                      ],
                                    ),
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
              ),
            ),
          ),
        );
      },
    );
  }

  double _measureTextWidth(TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: widget.title, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      textScaler: TextScaler.noScaling,
    )..layout();
    return painter.width;
  }
}
