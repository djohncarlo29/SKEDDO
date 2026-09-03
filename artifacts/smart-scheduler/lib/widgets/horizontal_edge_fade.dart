import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';

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
  /// Optional one-line placeholder content whose intrinsic width should also
  /// participate in trailing overflow fades while the field is empty.
  final String? overflowText;
  final TextStyle? overflowTextStyle;
  /// When supplied, the wrapper paints this placeholder itself above the
  /// field. This is used for fields whose native placeholder would ellipsize.
  final String? placeholderText;
  final TextStyle? placeholderTextStyle;
  final TextAlign placeholderTextAlign;
  final Alignment placeholderAlignment;
  final FocusNode? placeholderFocusNode;
  final ValueListenable<bool>? placeholderFocusListenable;
  /// Whether the empty placeholder receives the small focus-time nudge.
  ///
  /// Centered placeholders can opt out so focus does not change their visual
  /// alignment.
  final bool placeholderMovesOnFocus;

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
    this.overflowText,
    this.overflowTextStyle,
    this.placeholderText,
    this.placeholderTextStyle,
    this.placeholderTextAlign = TextAlign.left,
    this.placeholderAlignment = Alignment.centerLeft,
    this.placeholderFocusNode,
    this.placeholderFocusListenable,
    this.placeholderMovesOnFocus = true,
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
  TextEditingValue? _lastControllerValue;
  ScrollController? _attachedScrollController;
  FocusNode? _attachedPlaceholderFocusNode;
  ValueListenable<bool>? _attachedPlaceholderFocusListenable;
  double _rubberbandOffset = 0;
  int _editSyncTicket = 0;

  @override
  void initState() {
    super.initState();
    _lastControllerValue = widget.controller?.value;
    widget.controller?.addListener(_handleControllerChanged);
    _attachPlaceholderFocusNode();
    _attachPlaceholderFocusListenable();
    _attachScrollController();
  }

  @override
  void didUpdateWidget(covariant HorizontalEdgeFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      _lastControllerValue = widget.controller?.value;
      widget.controller?.addListener(_handleControllerChanged);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      _detachScrollController();
      _attachScrollController();
    }
    if (oldWidget.placeholderFocusNode != widget.placeholderFocusNode) {
      _detachPlaceholderFocusNode();
      _attachPlaceholderFocusNode();
    }
    if (oldWidget.placeholderFocusListenable !=
        widget.placeholderFocusListenable) {
      _detachPlaceholderFocusListenable();
      _attachPlaceholderFocusListenable();
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
    _detachPlaceholderFocusNode();
    _detachPlaceholderFocusListenable();
    _detachScrollController();
    super.dispose();
  }

  void _attachPlaceholderFocusNode() {
    final focusNode = widget.placeholderFocusNode;
    if (focusNode == null) return;
    _attachedPlaceholderFocusNode = focusNode;
    focusNode.addListener(_handlePlaceholderFocusChanged);
  }

  void _detachPlaceholderFocusNode() {
    _attachedPlaceholderFocusNode?.removeListener(_handlePlaceholderFocusChanged);
    _attachedPlaceholderFocusNode = null;
  }

  void _handlePlaceholderFocusChanged() {
    if (mounted) setState(() {});
  }

  void _attachPlaceholderFocusListenable() {
    final listenable = widget.placeholderFocusListenable;
    if (listenable == null) return;
    _attachedPlaceholderFocusListenable = listenable;
    listenable.addListener(_handlePlaceholderFocusChanged);
  }

  void _detachPlaceholderFocusListenable() {
    _attachedPlaceholderFocusListenable?.removeListener(
      _handlePlaceholderFocusChanged,
    );
    _attachedPlaceholderFocusListenable = null;
  }

  bool get _placeholderIsFocused =>
      widget.placeholderFocusNode?.hasFocus == true ||
      widget.placeholderFocusListenable?.value == true;

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

    // Empty text has no hidden content, even if the text field has not
    // recalculated its scroll metrics yet. Clear the visual state immediately
    // instead of allowing one stale metrics notification to paint old fades.
    if (value.text.isEmpty) {
      _editSyncTicket++;
      if (_canScroll || _showLeadingFade || _showTrailingFade) {
        if (mounted) {
          setState(() {
            _canScroll = false;
            _showLeadingFade = false;
            _showTrailingFade = false;
          });
        }
      }
    }

    _scheduleEditSync(value);
  }

  /// Lets EditableText finish its layout, then keeps the caret's end visible
  /// for typing, deletion, and paste. A second frame handles the case where
  /// the text field updates its max extent one frame after the controller.
  void _scheduleEditSync(TextEditingValue editedValue) {
    final ticket = ++_editSyncTicket;

    void syncAfterLayout() {
      if (!mounted || ticket != _editSyncTicket) return;
      final controller = _attachedScrollController;
      if (controller?.hasClients != true) return;
      final position = controller!.position;
      if (!position.hasContentDimensions) return;

      final value = widget.controller?.value;
      if (value?.text.isEmpty == true) {
        if (position.pixels != position.minScrollExtent) {
          position.jumpTo(position.minScrollExtent);
        }
      } else if (value != null &&
          value.selection.isValid &&
          value.selection.isCollapsed &&
          value.selection.extentOffset >= value.text.length &&
          position.pixels != position.maxScrollExtent) {
        // Pasting or appending at the end must reveal the newly inserted tail
        // immediately. This also keeps the last character visible while
        // backspacing at the end.
        position.jumpTo(position.maxScrollExtent);
      }
      _sync(position);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      syncAfterLayout();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        syncAfterLayout();
      });
    });
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
    final rubberbandOffset = metrics.pixels - metrics.minScrollExtent;
    // Metrics can lag behind a controller clear by a frame. Text itself is
    // authoritative: an empty field cannot have hidden content on either end.
    if (widget.controller?.text.isEmpty == true) {
      final showLeading =
          widget.fadeOnRubberbandWhenContentFits &&
          rubberbandOffset > 1.0;
      final showTrailing =
          widget.fadeOnRubberbandWhenContentFits &&
          widget.showTrailingFade &&
          rubberbandOffset < -1.0;
      if (_canScroll != false ||
          _showLeadingFade != showLeading ||
          _showTrailingFade != showTrailing ||
          (_rubberbandOffset - rubberbandOffset).abs() > 0.1) {
        if (!mounted) return;
        setState(() {
          _canScroll = false;
          _showLeadingFade = showLeading;
          _showTrailingFade = showTrailing;
          _rubberbandOffset = rubberbandOffset;
        });
      }
      return;
    }
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
    final showTrailing =
        fadeEdges &&
        widget.showTrailingFade &&
        (canScroll
            ? metrics.extentAfter > 1.0
            : widget.fadeWhenContentFits || isPulledPastStart);

    if (_canScroll == canScroll &&
        _showLeadingFade == showLeading &&
        _showTrailingFade == showTrailing &&
        (_rubberbandOffset - rubberbandOffset).abs() <= 0.1) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _canScroll = canScroll;
      _showLeadingFade = showLeading;
      _showTrailingFade = showTrailing;
      _rubberbandOffset = rubberbandOffset;
    });
  }

  Widget _fade({
    required bool visible,
    required bool opaqueAtStart,
    double solidTailWidth = 0,
  }) {
    if (!visible) return const SizedBox.shrink();
    final totalWidth = widget.fadeWidth + solidTailWidth;
    final hasOpaqueTail = solidTailWidth > 0;
    final fadeEnd = (widget.fadeWidth / totalWidth).clamp(0.0, 1.0).toDouble();
    return IgnorePointer(
      child: SizedBox(
        width: totalWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: opaqueAtStart
                  ? solidTailWidth > 0
                      ? [
                          widget.fadeColor,
                          widget.fadeColor,
                          widget.fadeColor.withValues(alpha: 0),
                        ]
                      : [
                          widget.fadeColor,
                          widget.fadeColor.withValues(alpha: 0),
                        ]
                  : hasOpaqueTail
                  ? [
                      widget.fadeColor.withValues(alpha: 0),
                      widget.fadeColor,
                      widget.fadeColor,
                    ]
                  : [
                      widget.fadeColor.withValues(alpha: 0),
                      widget.fadeColor,
                    ],
              stops: hasOpaqueTail
                  ? opaqueAtStart
                      ? [
                          0.0,
                          (solidTailWidth / totalWidth).clamp(0.0, 1.0),
                          1.0,
                        ]
                      : [0.0, fadeEnd, 1.0]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  bool _placeholderOverflows(BuildContext context, double width) {
    final text = widget.placeholderText ?? widget.overflowText;
    final style = widget.placeholderTextStyle ?? widget.overflowTextStyle;
    if (text == null ||
        style == null ||
        widget.controller?.text.isEmpty != true ||
        !width.isFinite) {
      return false;
    }
    final availableWidth =
        width - widget.leadingInset - widget.trailingInset;
    if (availableWidth <= 0) return false;

    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return painter.width > availableWidth + 0.5;
  }

  Widget _buildPlaceholder(BuildContext context, double width) {
    final text = widget.placeholderText;
    final style = widget.placeholderTextStyle;
    if (text == null ||
        text.isEmpty ||
        style == null ||
        widget.controller?.text.isEmpty != true ||
        !width.isFinite) {
      return const SizedBox.shrink();
    }
    final availableWidth = math.max(
      0.0,
      width - widget.leadingInset - widget.trailingInset,
    );
    final focusedOffset =
        widget.placeholderMovesOnFocus && _placeholderIsFocused ? 4.0 : 0.0;
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: Padding(
            padding: EdgeInsets.only(
              left: widget.leadingInset,
              right: widget.trailingInset,
            ),
            child: Align(
              alignment: widget.placeholderAlignment,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Transform.translate(
                  // Keep rubberband movement immediate so the placeholder
                  // tracks the field's native scroll gesture, while the
                  // focus-only 4 px nudge gets the same tap-time animation
                  // as the native text input.
                  offset: Offset(-_rubberbandOffset, 0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    transform: Matrix4.translationValues(
                      focusedOffset,
                      0,
                      0,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minWidth: availableWidth),
                      child: Text(
                        text,
                        style: style,
                        textAlign: widget.placeholderTextAlign,
                        maxLines: 1,
                        softWrap: false,
                        overflow: TextOverflow.clip,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final placeholderOverflow = _placeholderOverflows(
          context,
          constraints.maxWidth,
        );
        final showTrailingFade =
            _showTrailingFade || placeholderOverflow;
        // The child is painted first and the fades are painted above it. The
        // gradient is the edge treatment; this wrapper must not add a second
        // ClipRect boundary before the fade. TextField/scroll-view children
        // still own their normal viewport clipping.
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
                _buildPlaceholder(context, constraints.maxWidth),
                Positioned(
                  // Paint the leading fade from the wrapper edge. Its opaque
                  // tail covers the reserved control gap before the text
                  // viewport, so rubberbanded text cannot leak through that
                  // otherwise transparent padding.
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: _fade(
                    visible: _showLeadingFade,
                    opaqueAtStart: true,
                    solidTailWidth: widget.leadingInset,
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
                    visible: showTrailingFade,
                    opaqueAtStart: false,
                    solidTailWidth: widget.trailingInset,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}