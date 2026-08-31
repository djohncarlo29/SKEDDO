import 'package:flutter/cupertino.dart';

/// Adds the same edge treatment used by the large header title scroller to a
/// one-line horizontal content surface.
///
/// The wrapped child owns the actual horizontal scroll position. This widget
/// listens to its scroll notifications and paints non-interactive fades above
/// the child's left and right edges. Pulling a short child against either
/// boundary still reveals the corresponding fade when the child's physics
/// support bouncing.
const double kHorizontalFadeEdgeGap = 16.0;

class HorizontalEdgeFade extends StatefulWidget {
  final Widget child;
  final Color fadeColor;
  final double fadeWidth;
  final bool showTrailingFade;
  final double leadingInset;
  final double trailingInset;
  final TextEditingController? controller;

  const HorizontalEdgeFade({
    super.key,
    required this.child,
    required this.fadeColor,
    this.fadeWidth = 36,
    this.showTrailingFade = true,
    this.leadingInset = 0,
    this.trailingInset = 0,
    this.controller,
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
  bool _suppressTrailingAfterEdit = false;
  String? _lastControllerText;

  @override
  void initState() {
    super.initState();
    _lastControllerText = widget.controller?.text;
    widget.controller?.addListener(_handleControllerChanged);
  }

  @override
  void didUpdateWidget(covariant HorizontalEdgeFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      _lastControllerText = widget.controller?.text;
      widget.controller?.addListener(_handleControllerChanged);
      _suppressTrailingAfterEdit = false;
    }
    if (oldWidget.fadeColor != widget.fadeColor ||
        oldWidget.showTrailingFade != widget.showTrailingFade) {
      _resetting = true;
      _canScroll = false;
      _showLeadingFade = false;
      _showTrailingFade = false;
      _resetting = false;
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    super.dispose();
  }

  void _handleControllerChanged() {
    final controller = widget.controller;
    if (controller == null) return;
    final textChanged = _lastControllerText != controller.text;
    _lastControllerText = controller.text;
    if (!textChanged) return;

    // EditableText moves its internal scroll position to keep a newly typed
    // character visible after the controller notification. Hide the trailing
    // fade immediately, then let the next scroll notification restore it if
    // the user drags back into the overflow.
    _suppressTrailingAfterEdit =
        controller.selection.isValid &&
        controller.selection.isCollapsed &&
        controller.selection.extentOffset >= controller.text.length;
    if (_suppressTrailingAfterEdit && _showTrailingFade && mounted) {
      setState(() => _showTrailingFade = false);
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
    if (_suppressTrailingAfterEdit &&
        metrics.pixels >= metrics.maxScrollExtent - 1.0) {
      _suppressTrailingAfterEdit = false;
    }
    final showTrailing =
        widget.showTrailingFade &&
        !_suppressTrailingAfterEdit &&
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
             // Let one-line fields establish their natural height. Expanding
             // this stack in an unbounded modal Column can make the entire
             // sheet body fail layout while its header still renders.
            children: [
              widget.child,
              Positioned(
                left: widget.leadingInset,
                top: 0,
                bottom: 0,
                child: _fade(
                  visible: _showLeadingFade,
                  opaqueAtStart: true,
                ),
              ),
              Positioned(
                right: widget.trailingInset,
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