import 'package:flutter/cupertino.dart';

/// Adds the same edge treatment used by the large header title scroller to a
/// one-line horizontal content surface.
///
/// The wrapped child owns the actual horizontal scroll position. This widget
/// listens to its scroll notifications and paints non-interactive fades above
/// the child's left and right edges. The insets locate the opaque boundary of
/// each fade; they do not reserve layout space or add a separate gap between
/// the text and the fade.
const double kHorizontalFadeEdgeGap = 16.0;
const double kHorizontalFadeContentGap = 8.0;

class HorizontalEdgeFade extends StatefulWidget {
  final Widget child;
  final Color fadeColor;
  final double fadeWidth;
  final bool showTrailingFade;
  /// Distance from the wrapped surface's left edge to the fully opaque edge
  /// of the left fade. The fade extends inward from this point.
  final double leadingInset;
  /// Distance from the wrapped surface's right edge to the fully opaque edge
  /// of the right fade. The fade extends inward from this point.
  final double trailingInset;
  final TextEditingController? controller;
  final ScrollController? scrollController;
  /// Keeps the Large Header behavior for short, rubberbandable content:
  /// show the trailing fade at rest and reveal the leading fade while the
  /// content is pulled toward that edge even when maxScrollExtent is zero.
  final bool fadeWhenContentFits;
  /// Allows short, fully visible content to show the corresponding fade only
  /// while it is being rubberbanded past an edge. Unlike
  /// [fadeWhenContentFits], this does not show a fade at rest.
  final bool fadeOnRubberbandWhenContentFits;
  /// Shows the leading edge treatment at rest when content fits. This is
  /// useful for static labels whose two ends should share the same treatment.
  final bool showLeadingFadeWhenContentFits;

  const HorizontalEdgeFade({
    super.key,
    required this.child,
    required this.fadeColor,
    this.fadeWidth = 36,
    this.showTrailingFade = true,
    this.leadingInset = 0,
    this.trailingInset = 0,
    this.controller,
    this.scrollController,
    this.fadeWhenContentFits = false,
    this.fadeOnRubberbandWhenContentFits = false,
    this.showLeadingFadeWhenContentFits = false,
  });

  @override
  State<HorizontalEdgeFade> createState() => _HorizontalEdgeFadeState();
}

class _HorizontalEdgeFadeState extends State<HorizontalEdgeFade> {
  // The child owns the actual horizontal scroll position. These flags mirror
  // HeaderTitleScroller: each side is derived independently from the actual
  // overflow position rather than from the other side's visibility.
  bool _canScroll = false;
  bool _resetting = false;
  bool _showLeadingFade = false;
  bool _showTrailingFade = false;
  bool _suppressTrailingAfterEdit = false;
  TextEditingValue? _lastControllerValue;
  ScrollController? _attachedScrollController;

  @override
  void initState() {
    super.initState();
    _lastControllerValue = widget.controller?.value;
    widget.controller?.addListener(_handleControllerChanged);
    _attachScrollController();
  }

  @override
  void didUpdateWidget(covariant HorizontalEdgeFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      _lastControllerValue = widget.controller?.value;
      widget.controller?.addListener(_handleControllerChanged);
      _suppressTrailingAfterEdit = false;
    }
    if (oldWidget.scrollController != widget.scrollController) {
      _detachScrollController();
      _attachScrollController();
    }
    if (oldWidget.fadeColor != widget.fadeColor ||
        oldWidget.showTrailingFade != widget.showTrailingFade ||
        oldWidget.fadeWhenContentFits != widget.fadeWhenContentFits ||
        oldWidget.fadeOnRubberbandWhenContentFits !=
            widget.fadeOnRubberbandWhenContentFits ||
        oldWidget.showLeadingFadeWhenContentFits !=
            widget.showLeadingFadeWhenContentFits) {
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
    _detachScrollController();
    super.dispose();
  }

  void _attachScrollController() {
    final controller = widget.scrollController;
    if (controller == null) return;
    _attachedScrollController = controller;
    controller.addListener(_handleScrollControllerChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _attachedScrollController != controller) return;
      if (controller.hasClients) _sync(controller.position);
    });
  }

  void _detachScrollController() {
    _attachedScrollController?.removeListener(_handleScrollControllerChanged);
    _attachedScrollController = null;
  }

  void _handleScrollControllerChanged() {
    final controller = _attachedScrollController;
    if (controller?.hasClients != true) return;
    _sync(controller!.position);
  }

  void _handleControllerChanged() {
    final controller = widget.controller;
    if (controller == null) return;
    final value = controller.value;
    final previousValue = _lastControllerValue;
    _lastControllerValue = value;
    final textChanged = previousValue?.text != value.text;
    final selectionChanged = previousValue?.selection != value.selection;
    if (!textChanged && !selectionChanged) return;

    // EditableText moves its internal scroll position to keep a newly typed
    // character/cursor visible after the controller notification. Hide the
    // trailing fade immediately when the cursor is at the natural end, then
    // let the next scroll notification restore it if actual overflow remains.
    _suppressTrailingAfterEdit =
        value.selection.isValid &&
        value.selection.isCollapsed &&
        value.selection.extentOffset >= value.text.length;
    if (_suppressTrailingAfterEdit && _showTrailingFade && mounted) {
      setState(() => _showTrailingFade = false);
    }
  }

  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.horizontal) return false;
    // A controller edit can briefly notify before EditableText finishes
    // moving its viewport to the caret at the new end. Keep the trailing fade
    // hidden during that handoff, but stop suppressing it as soon as the user
    // deliberately drags away from the end. At that point the fade is useful
    // again because content is genuinely hidden on the right.
    if (notification is ScrollUpdateNotification &&
        notification.dragDetails != null) {
      _suppressTrailingAfterEdit = false;
    }
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
    // Most fields only show fades when content is genuinely clipped. Selected
    // modal fields opt into the Large Header behavior, where a short field
    // still fades at its edge during native rubberband motion.
    final fadeEdges =
        canScroll ||
        widget.fadeWhenContentFits ||
        widget.fadeOnRubberbandWhenContentFits;
    // For overflowing content, use the metrics' actual visible extents rather
    // than assuming minScrollExtent is zero. For fitting content, the only
    // hidden pixels are produced by a rubberband overscroll: pulling past the
    // start moves the content toward the right edge, while pulling past the
    // end moves it toward the left edge.
    final isPulledPastStart = metrics.pixels < metrics.minScrollExtent - 1.0;
    final isPulledPastEnd = metrics.pixels > metrics.maxScrollExtent + 1.0;
    final showLeading = fadeEdges &&
        (canScroll
            ? metrics.extentBefore > 1.0
            : widget.showLeadingFadeWhenContentFits || isPulledPastEnd);
    if (_suppressTrailingAfterEdit &&
        metrics.pixels >= metrics.maxScrollExtent - 1.0) {
      _suppressTrailingAfterEdit = false;
    }
    final showTrailing =
        fadeEdges &&
        widget.showTrailingFade &&
        !_suppressTrailingAfterEdit &&
        (canScroll
            ? metrics.extentAfter > 1.0
            : widget.fadeWhenContentFits || isPulledPastStart);

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

  Widget _fade({
    required bool visible,
    required bool opaqueAtStart,
    double solidTailWidth = 0,
  }) {
    if (!visible) return const SizedBox.shrink();
    final totalWidth = widget.fadeWidth + solidTailWidth;
    return IgnorePointer(
      child: SizedBox(
        width: totalWidth,
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
    // The child is painted first and the fades are painted above it. The
    // gradient is the edge treatment; this wrapper must not add a second
    // ClipRect boundary before the fade. TextField/scroll-view children still
    // own their normal viewport clipping.
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _handleMetricsNotification,
        child: Stack(
          clipBehavior: Clip.none,
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
              // Run the trailing gradient continuously through the inset.
              // A hard stop at a fractional inset creates the visible slit
              // between the fade and the text field's action reservation.
              right: 0,
              top: 0,
              bottom: 0,
              child: _fade(
                visible: _showTrailingFade,
                opaqueAtStart: false,
                solidTailWidth: widget.trailingInset,
              ),
            ),
          ],
        ),
      ),
    );
  }
}