import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/foundation.dart';
import 'edge_fade_metrics.dart';

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
  /// Optional metrics from a text input whose scrolling is hosted outside
  /// Flutter's Scrollable tree (for example, the web DOM input).
  final ValueListenable<EdgeFadeMetrics?>? metricsListenable;
  /// Fades the wrapped text by masking its alpha rather than painting a
  /// surface-colored gradient over it.
  final bool alphaMask;
  /// Keeps the Large Header behavior for short, rubberbandable content:
  /// show the trailing fade at rest and reveal the leading fade while the
  /// content is pulled toward that edge even when maxScrollExtent is zero.
  final bool fadeWhenContentFits;
  /// Allows short, fully visible content to show the corresponding fade only
  /// while it is being rubberbanded past an edge. Unlike
  /// [fadeWhenContentFits], this does not show a fade at rest.
  final bool fadeOnRubberbandWhenContentFits;
  /// Adds a restrained drag-following fallback when short content has no
  /// scroll extent to rubberband through its native editable viewport.
  final bool rubberbandWhenContentFits;
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
    this.metricsListenable,
    this.alphaMask = false,
    this.fadeWhenContentFits = false,
    this.fadeOnRubberbandWhenContentFits = false,
    this.rubberbandWhenContentFits = false,
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
  ValueListenable<EdgeFadeMetrics?>? _attachedMetricsListenable;
  FocusNode? _attachedPlaceholderFocusNode;
  ValueListenable<bool>? _attachedPlaceholderFocusListenable;
  double _rubberbandOffset = 0;
  int? _rubberbandPointer;
  Offset? _rubberbandStartPosition;
  double _manualChildOffset = 0;
  bool _manualRubberbandActive = false;
  double _rubberbandViewportWidth = 0;
  int _editSyncTicket = 0;

  @override
  void initState() {
    super.initState();
    _lastControllerValue = widget.controller?.value;
    widget.controller?.addListener(_handleControllerChanged);
    _attachPlaceholderFocusNode();
    _attachPlaceholderFocusListenable();
    _attachScrollController();
    _attachMetricsListenable();
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
    if (oldWidget.metricsListenable != widget.metricsListenable) {
      _detachMetricsListenable();
      _attachMetricsListenable();
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
    _detachMetricsListenable();
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

  void _attachMetricsListenable() {
    final listenable = widget.metricsListenable;
    if (listenable == null) return;
    _attachedMetricsListenable = listenable;
    listenable.addListener(_handleExternalMetricsChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _attachedMetricsListenable != listenable) return;
      _handleExternalMetricsChanged();
    });
  }

  void _detachMetricsListenable() {
    _attachedMetricsListenable?.removeListener(_handleExternalMetricsChanged);
    _attachedMetricsListenable = null;
  }

  void _handleExternalMetricsChanged() {
    final metrics = _attachedMetricsListenable?.value;
    if (metrics == null) return;
    if (widget.rubberbandWhenContentFits && metrics.maxScrollExtent <= 1.0) {
      if (metrics.pixels.abs() > 1.0) {
        _manualRubberbandActive = true;
        _manualChildOffset = -metrics.pixels;
      } else if (_manualRubberbandActive && _rubberbandPointer == null) {
        _manualRubberbandActive = false;
        _manualChildOffset = 0;
      }
    }
    _syncMetrics(
      pixels: metrics.pixels,
      minScrollExtent: metrics.minScrollExtent,
      maxScrollExtent: metrics.maxScrollExtent,
      extentBefore: metrics.extentBefore,
      extentAfter: metrics.extentAfter,
    );
  }

  void _handleRubberbandPointerDown(
    PointerDownEvent event,
    double viewportWidth,
  ) {
    if (!widget.rubberbandWhenContentFits ||
        _canScroll ||
        !viewportWidth.isFinite) {
      return;
    }
    _rubberbandPointer = event.pointer;
    _rubberbandStartPosition = event.position;
    _rubberbandViewportWidth = viewportWidth;
  }

  void _handleRubberbandPointerMove(PointerMoveEvent event) {
    if (event.pointer != _rubberbandPointer) return;
    final start = _rubberbandStartPosition;
    if (start == null) return;
    final delta = event.position - start;
    if (delta.dy.abs() > kTouchSlop && delta.dy.abs() > delta.dx.abs()) {
      _finishRubberbandPointer(event.pointer);
      return;
    }
    if (delta.dx.abs() < kTouchSlop || _canScroll) return;
    // Let native editable scrolling win if it has already reported an
    // overscroll. This fallback covers fitting text whose internal scroll
    // extent remains exactly zero.
    if (!_manualRubberbandActive && _rubberbandOffset.abs() > 1.0) return;

    final maxShift = math.min(32.0, _rubberbandViewportWidth * 0.16);
    final childOffset = (delta.dx * 0.55)
        .clamp(-maxShift, maxShift)
        .toDouble();
    if ((_manualChildOffset - childOffset).abs() < 0.1) return;
    setState(() {
      _manualRubberbandActive = true;
      _manualChildOffset = childOffset;
    });
    _syncMetrics(
      pixels: -childOffset,
      minScrollExtent: 0,
      maxScrollExtent: 0,
      extentBefore: 0,
      extentAfter: 0,
    );
  }

  void _finishRubberbandPointer(int pointer) {
    if (_rubberbandPointer != pointer) return;
    _rubberbandPointer = null;
    _rubberbandStartPosition = null;
    if (!_manualRubberbandActive) return;
    setState(() {
      _manualRubberbandActive = false;
      _manualChildOffset = 0;
    });
    _syncMetrics(
      pixels: 0,
      minScrollExtent: 0,
      maxScrollExtent: 0,
      extentBefore: 0,
      extentAfter: 0,
    );
  }

  void _handleRubberbandPointerUp(PointerUpEvent event) {
    _finishRubberbandPointer(event.pointer);
  }

  void _handleRubberbandPointerCancel(PointerCancelEvent event) {
    _finishRubberbandPointer(event.pointer);
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
    // A fitting search field uses the wrapper's drag-following fallback.
    // EditableText may still emit idle (zero-offset) metrics for the same
    // pointer sequence; those must not erase the synthetic rubberband or its
    // edge fade while the fallback gesture is active.
    if (widget.rubberbandWhenContentFits &&
        _manualRubberbandActive &&
        _rubberbandPointer != null &&
        metrics.maxScrollExtent <= 1.0 &&
        metrics.pixels.abs() <= 1.0) {
      return;
    }
    _syncMetrics(
      pixels: metrics.pixels,
      minScrollExtent: metrics.minScrollExtent,
      maxScrollExtent: metrics.maxScrollExtent,
      extentBefore: metrics.extentBefore,
      extentAfter: metrics.extentAfter,
    );
  }

  void _syncMetrics({
    required double pixels,
    required double minScrollExtent,
    required double maxScrollExtent,
    required double extentBefore,
    required double extentAfter,
  }) {
    if (_resetting) return;
    final rubberbandOffset = pixels - minScrollExtent;
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
    final canScroll = maxScrollExtent > 1.0;
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
    final isPulledPastStart = pixels < minScrollExtent - 1.0;
    final isPulledPastEnd = pixels > maxScrollExtent + 1.0;
    final showLeading = fadeEdges &&
        (canScroll
            ? extentBefore > 1.0
            : widget.showLeadingFadeWhenContentFits || isPulledPastEnd);
    final showTrailing =
        fadeEdges &&
        widget.showTrailingFade &&
        (canScroll
            ? extentAfter > 1.0
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

  Shader _alphaMaskShader(
    Rect bounds, {
    required bool leading,
    required bool trailing,
  }) {
    final width = bounds.width;
    if (width <= 0 || (!leading && !trailing)) {
      return const LinearGradient(
        colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
      ).createShader(bounds);
    }

    final availableFadeWidth = math.max(
      0.0,
      (width - widget.leadingInset - widget.trailingInset) / 2,
    );
    final fadeWidth = math.min(widget.fadeWidth, availableFadeWidth);
    final leadingStart = (widget.leadingInset / width).clamp(0.0, 1.0);
    final leadingEnd =
        ((widget.leadingInset + fadeWidth) / width).clamp(0.0, 1.0);
    final trailingStart =
        ((width - widget.trailingInset - fadeWidth) / width).clamp(0.0, 1.0);
    final trailingEnd =
        ((width - widget.trailingInset) / width).clamp(0.0, 1.0);

    final stops = <double>{0.0, 1.0};
    if (leading) {
      stops
        ..add(leadingStart)
        ..add(leadingEnd);
    }
    if (trailing) {
      stops
        ..add(trailingStart)
        ..add(trailingEnd);
    }
    final sortedStops = stops.toList()..sort();

    double alphaAt(double stop) {
      var alpha = 1.0;
      if (leading) {
        if (stop <= leadingStart) {
          alpha = 0.0;
        } else if (stop < leadingEnd && leadingEnd > leadingStart) {
          alpha = (stop - leadingStart) / (leadingEnd - leadingStart);
        }
      }
      if (trailing) {
        if (stop >= trailingEnd) {
          alpha = 0.0;
        } else if (stop > trailingStart && trailingEnd > trailingStart) {
          alpha = math.min(
            alpha,
            (trailingEnd - stop) / (trailingEnd - trailingStart),
          );
        }
      }
      return alpha.clamp(0.0, 1.0).toDouble();
    }

    return LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      stops: sortedStops,
      colors: sortedStops
          .map((stop) => const Color(0xFFFFFFFF).withValues(alpha: alphaAt(stop)))
          .toList(),
    ).createShader(bounds);
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
    final focusedPlaceholder = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      transform: Matrix4.translationValues(focusedOffset, 0, 0),
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
    );
    final Widget rubberbandedPlaceholder = widget.rubberbandWhenContentFits
        ? AnimatedContainer(
            duration: _manualRubberbandActive
                ? Duration.zero
                : const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              _manualChildOffset,
              0,
              0,
            ),
            child: focusedPlaceholder,
          )
        : Transform.translate(
            offset: Offset(-_rubberbandOffset, 0),
            child: focusedPlaceholder,
          );
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
                child: rubberbandedPlaceholder,
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
        final content = Stack(
          clipBehavior: Clip.none,
          children: [
            if (widget.rubberbandWhenContentFits)
              AnimatedContainer(
                duration: _manualRubberbandActive
                    ? Duration.zero
                    : const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                transform: Matrix4.translationValues(
                  _manualChildOffset,
                  0,
                  0,
                ),
                child: widget.child,
              )
            else
              widget.child,
            _buildPlaceholder(context, constraints.maxWidth),
          ],
        );
        // Keep the ShaderMask mounted for the full gesture lifecycle. When no
        // edge is faded, _alphaMaskShader returns opaque white; removing the
        // wrapper at release would reparent the AnimatedContainer children and
        // snap their rubberband animation instead of settling them.
        final fadedContent = widget.alphaMask
            ? ShaderMask(
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => _alphaMaskShader(
                  bounds,
                  leading: _showLeadingFade,
                  trailing: showTrailingFade,
                ),
                child: content,
              )
            : content;

        return Listener(
          onPointerDown: (event) =>
              _handleRubberbandPointerDown(event, constraints.maxWidth),
          onPointerMove: _handleRubberbandPointerMove,
          onPointerUp: _handleRubberbandPointerUp,
          onPointerCancel: _handleRubberbandPointerCancel,
          child: NotificationListener<ScrollNotification>(
            onNotification: _handleScrollNotification,
            child: NotificationListener<ScrollMetricsNotification>(
              onNotification: _handleMetricsNotification,
              child: Stack(
              clipBehavior: Clip.none,
              // Let one-line fields establish their natural height. Expanding
              // this stack in an unbounded modal Column can make the entire
              // sheet body fail layout while its header still renders.
              children: [
                fadedContent,
                if (!widget.alphaMask) ...[
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
              ],
              ),
            ),
          ),
        );
      },
    );
  }
}