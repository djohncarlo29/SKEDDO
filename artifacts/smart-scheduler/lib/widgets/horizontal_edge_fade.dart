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
  // HeaderTitleScroller: each side is derived independently from the actual
  // overflow position rather than from the other side's visibility.
  bool _canScroll = false;
  bool _resetting = false;
  bool _showLeadingFade = false;
  bool _showTrailingFade = false;
  bool _suppressTrailingAfterEdit = false;
  TextEditingValue? _lastControllerValue;

  @override
  void initState() {
    super.initState();
    _lastControllerValue = widget.controller?.value;
    widget.controller?.addListener(_handleControllerChanged);
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
    // AlwaysScrollableScrollPhysics can report negative/overscrolled pixels
    // even when the content fits. Only actual content overflow may enable a
    // fade; rubber-band motion alone must not create one.
    final showLeading = canScroll && metrics.pixels > 1.0;
    if (_suppressTrailingAfterEdit &&
        metrics.pixels >= metrics.maxScrollExtent - 1.0) {
      _suppressTrailingAfterEdit = false;
    }
    final showTrailing =
        canScroll &&
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
    );
  }
}