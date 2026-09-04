import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'edge_fade_metrics.dart';

/// Paints top and bottom fades over a multiline scrollable.
///
/// Like [HorizontalEdgeFade], this is driven by the scrollable's actual
/// extents. Fitting text is fade-free at rest, but the corresponding opposite
/// edge is revealed while the native bouncing scroll view is pulled past an
/// edge.
class VerticalEdgeFade extends StatefulWidget {
  final Widget child;
  final Color fadeColor;
  final double fadeHeight;
  final bool showBottomFade;
  final double topInset;
  final double bottomInset;
  final TextEditingController? controller;
  final ScrollController? scrollController;
  /// Identifies a meaningful change to the wrapped scrollable's content
  /// geometry. A new value schedules one post-layout sync without tying the
  /// fade to every animation-frame rebuild of the child.
  final Object? contentKey;
  final ValueListenable<EdgeFadeMetrics?>? metricsListenable;
  final bool fadeWhenContentFits;
  final bool fadeOnRubberbandWhenContentFits;
  final bool showTopFadeWhenContentFits;
  final String? placeholderText;
  final TextStyle? placeholderTextStyle;
  final Alignment placeholderAlignment;
  final FocusNode? placeholderFocusNode;
  final ValueListenable<bool>? placeholderFocusListenable;

  const VerticalEdgeFade({
    super.key,
    required this.child,
    required this.fadeColor,
    this.fadeHeight = 36,
    this.showBottomFade = true,
    this.topInset = 0,
    this.bottomInset = 0,
    this.controller,
    this.scrollController,
    this.contentKey,
    this.metricsListenable,
    this.fadeWhenContentFits = false,
    this.fadeOnRubberbandWhenContentFits = false,
    this.showTopFadeWhenContentFits = false,
    this.placeholderText,
    this.placeholderTextStyle,
    this.placeholderAlignment = Alignment.topLeft,
    this.placeholderFocusNode,
    this.placeholderFocusListenable,
  });

  @override
  State<VerticalEdgeFade> createState() => _VerticalEdgeFadeState();
}

class _VerticalEdgeFadeState extends State<VerticalEdgeFade> {
  bool _canScroll = false;
  bool _resetting = false;
  bool _showTopFade = false;
  bool _showBottomFade = false;
  TextEditingValue? _lastControllerValue;
  ScrollController? _attachedScrollController;
  FocusNode? _attachedPlaceholderFocusNode;
  ValueListenable<bool>? _attachedPlaceholderFocusListenable;
  double _rubberbandOffset = 0;
  int _editSyncTicket = 0;
  int _layoutSyncTicket = 0;

  @override
  void initState() {
    super.initState();
    _lastControllerValue = widget.controller?.value;
    widget.controller?.addListener(_handleControllerChanged);
    widget.metricsListenable?.addListener(_handleExternalMetricsChanged);
    _attachPlaceholderFocusNode();
    _attachPlaceholderFocusListenable();
    _attachScrollController();
  }

  @override
  void didUpdateWidget(covariant VerticalEdgeFade oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChanged);
      _lastControllerValue = widget.controller?.value;
      widget.controller?.addListener(_handleControllerChanged);
    }
    if (oldWidget.metricsListenable != widget.metricsListenable) {
      oldWidget.metricsListenable?.removeListener(_handleExternalMetricsChanged);
      widget.metricsListenable?.addListener(_handleExternalMetricsChanged);
    }
    if (oldWidget.scrollController != widget.scrollController) {
      _detachScrollController();
      _attachScrollController();
    }
    if (oldWidget.contentKey != widget.contentKey) {
      _scheduleLayoutSync();
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
        oldWidget.showBottomFade != widget.showBottomFade ||
        oldWidget.fadeWhenContentFits != widget.fadeWhenContentFits ||
        oldWidget.fadeOnRubberbandWhenContentFits !=
            widget.fadeOnRubberbandWhenContentFits ||
        oldWidget.showTopFadeWhenContentFits !=
            widget.showTopFadeWhenContentFits) {
      _resetting = true;
      _canScroll = false;
      _showTopFade = false;
      _showBottomFade = false;
      _resetting = false;
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_handleControllerChanged);
    widget.metricsListenable?.removeListener(_handleExternalMetricsChanged);
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
    _scheduleLayoutSync();
  }

  void _scheduleLayoutSync() {
    final ticket = ++_layoutSyncTicket;

    void syncAfterLayout(int attempt) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || ticket != _layoutSyncTicket) return;
        final controller = _attachedScrollController;
        if (controller?.hasClients != true) {
          if (attempt < 2) syncAfterLayout(attempt + 1);
          return;
        }
        final position = controller!.position;
        if (!position.hasContentDimensions) {
          if (attempt < 2) syncAfterLayout(attempt + 1);
          return;
        }
        _sync(position);
      });
    }

    syncAfterLayout(0);
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

  void _handleExternalMetricsChanged() {
    final metrics = widget.metricsListenable?.value;
    if (metrics != null) _sync(metrics);
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

    if (value.text.isEmpty) {
      _editSyncTicket++;
      if (_canScroll || _showTopFade || _showBottomFade) {
        if (mounted) {
          setState(() {
            _canScroll = false;
            _showTopFade = false;
            _showBottomFade = false;
          });
        }
      }
    }
    _scheduleEditSync(value);
  }

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
        // Pasting or appending at the end must reveal the newly inserted tail.
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
    if (notification.metrics.axis != Axis.vertical) return false;
    _sync(notification.metrics);
    return false;
  }

  bool _handleMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      _sync(notification.metrics);
    }
    return false;
  }

  void _sync(dynamic metrics) {
    if (_resetting) return;
    final rubberbandOffset = metrics.pixels - metrics.minScrollExtent;
    if (widget.controller?.text.isEmpty == true) {
      final showTop = widget.fadeOnRubberbandWhenContentFits &&
          rubberbandOffset > 1.0;
      final showBottom = widget.fadeOnRubberbandWhenContentFits &&
          widget.showBottomFade &&
          rubberbandOffset < -1.0;
      if (_canScroll ||
          _showTopFade != showTop ||
          _showBottomFade != showBottom ||
          (_rubberbandOffset - rubberbandOffset).abs() > 0.1) {
        if (!mounted) return;
        setState(() {
          _canScroll = false;
          _showTopFade = showTop;
          _showBottomFade = showBottom;
          _rubberbandOffset = rubberbandOffset;
        });
      }
      return;
    }

    final canScroll = metrics.maxScrollExtent > 1.0;
    final fadeEdges =
        canScroll ||
        widget.fadeWhenContentFits ||
        widget.fadeOnRubberbandWhenContentFits;
    final isPulledPastStart =
        metrics.pixels < metrics.minScrollExtent - 1.0;
    final isPulledPastEnd = metrics.pixels > metrics.maxScrollExtent + 1.0;
    final showTop = fadeEdges &&
        (canScroll
            ? metrics.extentBefore > 1.0
            : widget.showTopFadeWhenContentFits || isPulledPastEnd);
    final showBottom = fadeEdges &&
        widget.showBottomFade &&
        (canScroll
            ? metrics.extentAfter > 1.0
            : widget.fadeWhenContentFits || isPulledPastStart);

    if (_canScroll == canScroll &&
        _showTopFade == showTop &&
        _showBottomFade == showBottom) {
      return;
    }
    if (!mounted) return;
    setState(() {
      _canScroll = canScroll;
      _showTopFade = showTop;
      _showBottomFade = showBottom;
      _rubberbandOffset = rubberbandOffset;
    });
  }

  bool _placeholderOverflows(BuildContext context, Size size) {
    final text = widget.placeholderText;
    final style = widget.placeholderTextStyle;
    if (text == null ||
        text.isEmpty ||
        style == null ||
        widget.controller?.text.isNotEmpty == true ||
        !size.width.isFinite ||
        size.width <= 0) {
      return false;
    }
    final availableHeight =
        size.height - widget.topInset - widget.bottomInset;
    if (availableHeight <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
    )..layout(maxWidth: size.width);
    return painter.height > availableHeight + 0.5;
  }

  Widget _buildPlaceholder(BuildContext context, Size size) {
    final text = widget.placeholderText;
    final style = widget.placeholderTextStyle;
    if (text == null ||
        text.isEmpty ||
        style == null ||
        widget.controller?.text.isNotEmpty == true ||
        !size.width.isFinite ||
        size.width <= 0) {
      return const SizedBox.shrink();
    }
    final focusedOffset = _placeholderIsFocused ? 4.0 : 0.0;
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: Align(
            alignment: widget.placeholderAlignment,
            child: Transform.translate(
              // Rubberband movement remains immediate, while the focus-only
              // nudge animates when the field is tapped or dismissed.
              offset: Offset(0, -_rubberbandOffset),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                transform: Matrix4.translationValues(
                  focusedOffset,
                  0,
                  0,
                ),
                child: SizedBox(
                  width: size.width,
                  child: Text(
                    text,
                    style: style,
                    softWrap: true,
                    overflow: TextOverflow.clip,
                   ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _fade({
    required bool visible,
    required bool opaqueAtStart,
    double solidTailHeight = 0,
  }) {
    if (!visible) return const SizedBox.shrink();
    final totalHeight = widget.fadeHeight + solidTailHeight;
    final hasOpaqueTail = solidTailHeight > 0;
    final fadeEnd =
        (widget.fadeHeight / totalHeight).clamp(0.0, 1.0).toDouble();
    return IgnorePointer(
      child: SizedBox(
        height: totalHeight,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: opaqueAtStart
                  ? hasOpaqueTail
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
                      ? [0.0, (solidTailHeight / totalHeight), 1.0]
                      : [0.0, fadeEnd, 1.0]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: NotificationListener<ScrollMetricsNotification>(
        onNotification: _handleMetricsNotification,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final size = Size(
              constraints.maxWidth,
              constraints.maxHeight,
            );
            final placeholderOverflow = _placeholderOverflows(context, size);
            // A long empty placeholder is content too: it needs the same
            // bottom fade as a long note, while a fitting placeholder only
            // reveals fades during rubberband motion.
            final showBottomFade =
                _showBottomFade || placeholderOverflow;
            return Stack(
              // Let multiline fields establish their natural height. Expanding
              // this stack inside the modal's unbounded scroll column can make
              // the entire sheet body fail layout while its header still renders.
              clipBehavior: Clip.none,
              children: [
                widget.child,
                _buildPlaceholder(context, size),
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: _fade(
                    visible: _showTopFade,
                    opaqueAtStart: true,
                    solidTailHeight: widget.topInset,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: _fade(
                    visible: showBottomFade,
                    opaqueAtStart: false,
                    solidTailHeight: widget.bottomInset,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}