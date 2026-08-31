import 'package:flutter/cupertino.dart';

/// Adds the same edge treatment used by the large header title scroller to a
/// one-line horizontal content surface.
///
/// The wrapped child owns the actual horizontal scroll position. This widget
/// listens to its scroll notifications and paints non-interactive fades above
/// the child's left and right edges. Pulling a short child against either
/// boundary still reveals the corresponding fade when the child's physics
/// support bouncing.
class HorizontalEdgeFade extends StatefulWidget {
  final Widget child;
  final Color fadeColor;
  final double fadeWidth;
  final bool showTrailingFade;

  const HorizontalEdgeFade({
    super.key,
    required this.child,
    required this.fadeColor,
    this.fadeWidth = 36,
    this.showTrailingFade = true,
  });

  @override
  State<HorizontalEdgeFade> createState() => _HorizontalEdgeFadeState();
}

class _HorizontalEdgeFadeState extends State<HorizontalEdgeFade> {
  // The child owns the actual horizontal scroll position. These flags mirror
  // HeaderTitleScroller: overflow is tracked independently from the physics
  // so a short field can still reveal a fade while it is rubberbanding.
  bool _canScroll = false;
  bool _resetting = false;
  bool _showLeadingFade = false;
  bool _showTrailingFade = false;

  @override
  void didUpdateWidget(covariant HorizontalEdgeFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.fadeColor != widget.fadeColor ||
        oldWidget.showTrailingFade != widget.showTrailingFade) {
      _resetting = true;
      _canScroll = false;
      _showLeadingFade = false;
      _showTrailingFade = false;
      _resetting = false;
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.horizontal) return false;
    _sync(notification.metrics);
    return false;
  }

  bool _handleMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.metrics.axis == Axis.horizontal) {
      _sync(notification.metrics);
    }
    return false;
  }

  void _sync(ScrollMetrics metrics) {
    if (_resetting) return;
    final canScroll = metrics.maxScrollExtent > 1.0;
    final showLeading = metrics.pixels > 1.0;
    final showTrailing =
        widget.showTrailingFade &&
        metrics.pixels < metrics.maxScrollExtent - 1.0;

    if (_canScroll == canScroll &&
        _showLeadingFade == showLeading &&
        _showTrailingFade == showTrailing) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _canScroll = canScroll;
      _showLeadingFade = showLeading;
      _showTrailingFade = showTrailing;
    });
  }

  Widget _fade({required bool visible, required bool opaqueAtStart}) {
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
                  ? [
                      widget.fadeColor,
                      widget.fadeColor.withValues(alpha: 0),
                    ]
                  : [
                      widget.fadeColor.withValues(alpha: 0),
                      widget.fadeColor,
                    ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: NotificationListener<ScrollNotification>(
        onNotification: _handleScrollNotification,
        child: NotificationListener<ScrollMetricsNotification>(
          onNotification: _handleMetricsNotification,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: _fade(
                  visible: _showLeadingFade,
                  opaqueAtStart: true,
                ),
              ),
              Positioned(
                right: 0,
                top: 0,
                bottom: 0,
                child: _fade(
                  visible: _showTrailingFade,
                  opaqueAtStart: false,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}