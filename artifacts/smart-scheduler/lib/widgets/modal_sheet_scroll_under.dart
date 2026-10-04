import 'dart:convert' show jsonEncode;
import 'dart:math' as math;

import 'package:flutter/foundation.dart'
    show debugPrint, defaultTargetPlatform, TargetPlatform;
import 'package:flutter/rendering.dart'
    show PaintingContext, PipelineOwner, RenderProxyBox;
import 'package:flutter/widgets.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassEdge, LiquidGlassScrollEdge;

import '../app_theme.dart'
    show BoundedSquircleStadiumBorder, kModalSheetCornerRadius;

/// The top scroll-edge effect is anchored to the modal sheet's top edge,
/// independently of the inset used to position its header.
const double kModalSheetScrollEdgeTopOffset = 0;

/// Places a sheet's scrolling content behind its fixed header and, optionally,
/// footer while keeping the original at-rest content positions.
///
/// The caller supplies the visible header/footer geometry and builds its
/// existing scrollable with the adjusted padding returned by [scrollBuilder].
/// The scroll viewport then fills the whole sheet instead of starting below
/// the header. As content moves into either fixed-control region, a bounded
/// backdrop blur and matching surface tint fade in progressively.
class ModalSheetScrollUnder extends StatefulWidget {
  const ModalSheetScrollUnder({
    super.key,
    required this.header,
    required this.headerHeight,
    required this.baseScrollPadding,
    required this.surfaceColor,
    required this.scrollBuilder,
    this.scrollController,
    this.edgeClipShape = const BoundedSquircleStadiumBorder(
      radius: kModalSheetCornerRadius,
      topOnly: true,
    ),
    this.headerTopInset = 0,
    this.headerGap = 0,
    this.footer,
    this.footerHeight = 0,
    this.footerBottomInset = 0,
    this.expandViewport = true,
    this.edgeExtent = 64,
    this.maxBlurSigma = 12,
    this.maxSurfaceOpacity = 0.78,
  }) : assert(headerHeight >= 0),
       assert(headerTopInset >= 0),
       assert(headerGap >= 0),
       assert(footerHeight >= 0),
       assert(footerBottomInset >= 0),
       assert(edgeExtent > 0),
       assert(maxBlurSigma >= 0),
       assert(maxSurfaceOpacity >= 0 && maxSurfaceOpacity <= 1);

  /// Fixed, sharp header. It is painted above the scroll-under effect.
  final Widget header;

  /// Height of [header], excluding [headerTopInset].
  final double headerHeight;

  /// Existing scroll padding before the header/footer overlap is added.
  final EdgeInsets baseScrollPadding;

  /// The sheet's already-resolved surface color, used for the translucent
  /// veil so the effect stays consistent in Light and Dark Mode.
  final Color surfaceColor;

  /// Builds the existing scrollable with the adjusted padding. It receives the
  /// original horizontal/bottom padding plus the header and footer clearances.
  final Widget Function(BuildContext context, EdgeInsets scrollPadding)
  scrollBuilder;

  /// Optional controller for the primary scroller. Listening to its position
  /// directly keeps the edge effect synced even when nested scrollables make
  /// the primary scroll notification's depth vary.
  final ScrollController? scrollController;

  /// Shape of the containing sheet, used to keep backdrop effects within its
  /// visible outline. Override this for popup sheets with a different radius.
  final ShapeBorder edgeClipShape;

  /// Space above the header, such as the existing header-edge spacer.
  final double headerTopInset;

  /// Existing gap between the header and the first scroll-content item.
  final double headerGap;

  /// Optional fixed bottom action area.
  final Widget? footer;

  /// Visible height reserved for [footer] in the scroll content's bottom
  /// padding. Include persistent safe-area spacing when the footer owns it.
  final double footerHeight;

  /// Distance from the sheet's bottom edge to [footer].
  final double footerBottomInset;

  /// Route pages fill their bounded viewport; intrinsic popup sheets can set
  /// this false so short content keeps its natural height.
  final bool expandViewport;

  /// Length of each gradient edge transition.
  final double edgeExtent;

  /// Maximum blur sigma at the fixed-control edge.
  final double maxBlurSigma;

  /// Maximum opacity of the matching modal-surface veil.
  final double maxSurfaceOpacity;

  @override
  State<ModalSheetScrollUnder> createState() => _ModalSheetScrollUnderState();
}

class _ModalSheetScrollUnderState extends State<ModalSheetScrollUnder> {
  static const double _topBlurSigmaScale = 0.85;

  double _topProgress = 0;
  double _bottomProgress = 0;
  int _edgeRepaintGeneration = 0;
  Animation<double>? _parentRouteSecondaryAnimation;
  bool _parentRouteIsCovered = false;
  double? _topProgressBeforeCover;
  double? _bottomProgressBeforeCover;
  Map<String, Object?>? _lastScrollMetrics;
  bool _dismissalMidpointLogged = false;
  bool _awaitingFirstScrollAfterSettle = false;
  String? _lastBuildTraceSignature;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_handleScrollControllerChanged);
    _trace('STATE_INIT');
    _scheduleScrollControllerSync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final secondaryAnimation = ModalRoute.of(context)?.secondaryAnimation;
    if (secondaryAnimation != _parentRouteSecondaryAnimation) {
      _parentRouteSecondaryAnimation?.removeStatusListener(
        _handleParentRouteAnimationStatus,
      );
      _parentRouteSecondaryAnimation?.removeListener(
        _handleParentRouteAnimationTick,
      );
      _parentRouteSecondaryAnimation = secondaryAnimation;
      _parentRouteSecondaryAnimation?.addStatusListener(
        _handleParentRouteAnimationStatus,
      );
      _parentRouteSecondaryAnimation?.addListener(
        _handleParentRouteAnimationTick,
      );
      if (secondaryAnimation != null &&
          secondaryAnimation.status != AnimationStatus.dismissed) {
        _beginParentRouteCover();
      }
      _trace(
        'ROUTE_ANIMATION_ATTACHED',
        extra: {
          'animationStatus': secondaryAnimation?.status.name,
          'animationValue': secondaryAnimation?.value,
        },
      );
      if (secondaryAnimation?.status == AnimationStatus.completed) {
        _trace('A_PARENT_READY_BEFORE_SUBSHEET_DISMISSAL');
      }
      _scheduleScrollControllerSync();
    }
  }

  @override
  void didUpdateWidget(covariant ModalSheetScrollUnder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(
        _handleScrollControllerChanged,
      );
      widget.scrollController?.addListener(_handleScrollControllerChanged);
    }
    _trace('WIDGET_UPDATED');
    _scheduleScrollControllerSync();
  }

  @override
  void dispose() {
    _trace('STATE_DISPOSE');
    widget.scrollController?.removeListener(_handleScrollControllerChanged);
    _parentRouteSecondaryAnimation?.removeStatusListener(
      _handleParentRouteAnimationStatus,
    );
    _parentRouteSecondaryAnimation?.removeListener(
      _handleParentRouteAnimationTick,
    );
    super.dispose();
  }

  void _scheduleScrollControllerSync() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFromScrollController();
    });
  }

  void _handleParentRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.completed) {
      _awaitingFirstScrollAfterSettle = false;
      _beginParentRouteCover();
      if (status == AnimationStatus.forward) {
        _trace('SUBSHEET_PRESENTING');
      } else {
        _dismissalMidpointLogged = false;
        _trace('A_PARENT_READY_BEFORE_SUBSHEET_DISMISSAL');
      }
      return;
    }
    if (status == AnimationStatus.reverse) {
      _dismissalMidpointLogged = false;
      _trace('B_SUBSHEET_DISMISSAL_STARTED');
      return;
    }
    if (status != AnimationStatus.dismissed) return;

    _awaitingFirstScrollAfterSettle = true;
    _trace('C_ROUTE_ANIMATION_DISMISSED_BEFORE_RESTORE');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _parentRouteSecondaryAnimation?.status !=
              AnimationStatus.dismissed) {
        _trace('SETTLE_CALLBACK_SKIPPED_ROUTE_NO_LONGER_DISMISSED');
        return;
      }
      _trace('C_SETTLE_CALLBACK_BEFORE_RESTORE');
      _parentRouteIsCovered = false;
      final topProgress = _topProgressBeforeCover;
      final bottomProgress = _bottomProgressBeforeCover;
      if (topProgress != null && bottomProgress != null) {
        setState(() {
          _topProgress = topProgress;
          _bottomProgress = bottomProgress;
          _edgeRepaintGeneration++;
        });
      } else {
        _syncFromScrollController(forceRepaint: true);
      }
      _topProgressBeforeCover = null;
      _bottomProgressBeforeCover = null;
      _trace('C_SETTLE_CALLBACK_AFTER_RESTORE');
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _trace('C_POST_RESTORE_FRAME_PAINTED');
      });
    });
  }

  void _handleParentRouteAnimationTick() {
    final animation = _parentRouteSecondaryAnimation;
    if (animation?.status != AnimationStatus.reverse ||
        _dismissalMidpointLogged) {
      return;
    }
    if (animation!.value <= 0.7 && animation.value > 0.05) {
      _dismissalMidpointLogged = true;
      _trace(
        'B_SUBSHEET_DISMISSAL_MIDPOINT',
        extra: {'animationValue': animation.value},
      );
    }
  }

  void _beginParentRouteCover() {
    if (_parentRouteIsCovered) return;
    _parentRouteIsCovered = true;
    if (_topProgressBeforeCover == null ||
        _bottomProgressBeforeCover == null) {
      _rememberEdgeProgressBeforeCover();
    }
  }

  void _rememberEdgeProgressBeforeCover() {
    _topProgressBeforeCover = _topProgress;
    _bottomProgressBeforeCover = _bottomProgress;
    _trace('PARENT_PROGRESS_SAVED_BEFORE_COVER');
  }

  String _routePhaseName() {
    final status = _parentRouteSecondaryAnimation?.status;
    if (status == AnimationStatus.forward) return 'SUBSHEET_PRESENTING';
    if (status == AnimationStatus.completed) return 'A_PARENT_COVERED';
    if (status == AnimationStatus.reverse) return 'B_SUBSHEET_DISMISSING';
    if (_awaitingFirstScrollAfterSettle) return 'C_PARENT_SETTLED';
    return status?.name ?? 'NO_ROUTE_ANIMATION';
  }

  Map<String, Object?>? _controllerMetricsSnapshot() {
    final controller = widget.scrollController;
    if (controller == null) return null;
    if (controller.positions.length != 1) {
      return {'attachedPositions': controller.positions.length};
    }
    final position = controller.position;
    return {
      'attachedPositions': 1,
      'hasContentDimensions': position.hasContentDimensions,
      if (position.hasContentDimensions) ...{
        'pixels': position.pixels,
        'minScrollExtent': position.minScrollExtent,
        'maxScrollExtent': position.maxScrollExtent,
        'viewportDimension': position.viewportDimension,
      },
    };
  }

  void _trace(
    String event, {
    Map<String, Object?> extra = const <String, Object?>{},
  }) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final animation = _parentRouteSecondaryAnimation;
    final data = <String, Object?>{
      'event': event,
      'state': identityHashCode(this),
      'phase': _routePhaseName(),
      'routeStatus': animation?.status.name,
      'routeValue': animation?.value,
      'covered': _parentRouteIsCovered,
      'savedTopProgress': _topProgressBeforeCover,
      'savedBottomProgress': _bottomProgressBeforeCover,
      'topProgress': _topProgress,
      'bottomProgress': _bottomProgress,
      'topEdgeWidget': _topProgress > 0.01,
      'bottomEdgeWidget':
          widget.footer != null &&
          widget.footerHeight > 0 &&
          _bottomProgress > 0.01,
      'topBlur': widget.maxBlurSigma * _topBlurSigmaScale * _topProgress,
      'topTintAlpha':
          widget.maxSurfaceOpacity * _topProgress * widget.surfaceColor.a,
      'topBandHeight': _topFadeExtent,
      'clipShape': widget.edgeClipShape.toString(),
      'edgeRepaintGeneration': _edgeRepaintGeneration,
      'lastScrollMetrics': _lastScrollMetrics,
      'controllerMetrics': _controllerMetricsSnapshot(),
      'awaitingFirstScrollAfterSettle': _awaitingFirstScrollAfterSettle,
      ...extra,
    };
    debugPrint('[MODAL_SCROLL_EDGE_TRACE] ${jsonEncode(data)}');
  }

  String _renderTraceSignature() =>
      '${_routePhaseName()}|$_edgeRepaintGeneration|'
      '${_topProgress.toStringAsFixed(3)}|'
      '${_bottomProgress.toStringAsFixed(3)}';

  void _traceRenderEvent(
    String event,
    int renderObjectId,
    Size? size,
    bool needsCompositing,
  ) {
    _trace(
      'RENDER_$event',
      extra: {
        'renderObject': renderObjectId,
        'renderSize': size == null ? null : '${size.width}x${size.height}',
        'needsCompositing': needsCompositing,
        'renderSignature': _renderTraceSignature(),
      },
    );
  }

  double get _activationDistance => math.max(
    48,
    widget.headerHeight + widget.headerGap + widget.baseScrollPadding.top,
  );

  EdgeInsets get _scrollPadding => EdgeInsets.fromLTRB(
    widget.baseScrollPadding.left,
    widget.headerTopInset +
        widget.headerHeight +
        widget.headerGap +
        widget.baseScrollPadding.top,
    widget.baseScrollPadding.right,
    widget.footerHeight +
        widget.footerBottomInset +
        widget.baseScrollPadding.bottom,
  );

  /// At rest, the first scroll-content item starts at this same distance from
  /// the sheet top. Both the material fade and blur reach zero at that edge.
  double get _topFadeExtent => _scrollPadding.top;

  void _syncScrollMetrics(
    ScrollMetrics metrics, {
    bool forceRepaint = false,
    String source = 'unknown',
  }) {
    _lastScrollMetrics = {
      'source': source,
      'pixels': metrics.pixels,
      'minScrollExtent': metrics.minScrollExtent,
      'maxScrollExtent': metrics.maxScrollExtent,
      'viewportDimension': metrics.viewportDimension,
    };
    _trace(
      'SCROLL_METRICS_RECEIVED',
      extra: {
        'source': source,
        'incomingPixels': metrics.pixels,
        'incomingMaxScrollExtent': metrics.maxScrollExtent,
        'incomingViewportDimension': metrics.viewportDimension,
      },
    );

    // A covered sheet can briefly report an empty scroll range while its
    // route is being transformed. Those metrics do not describe the sheet's
    // settled scroll position; clearing the edge here removes its backdrop
    // layer until the user scrolls again.
    if (_parentRouteIsCovered) {
      _trace('SCROLL_METRICS_IGNORED_WHILE_COVERED', extra: {'source': source});
      return;
    }

    if (metrics.maxScrollExtent <= 1) {
      _trace(
        'SCROLL_METRICS_ZERO_EDGE_DECISION',
        extra: {
          'source': source,
          'incomingPixels': metrics.pixels,
          'incomingMaxScrollExtent': metrics.maxScrollExtent,
        },
      );
      if (_topProgress != 0 ||
          _bottomProgress != 0 ||
          forceRepaint) {
        setState(() {
          _topProgress = 0;
          _bottomProgress = 0;
          if (forceRepaint) _edgeRepaintGeneration++;
        });
        _trace('EDGE_PROGRESS_CLEARED_FROM_EMPTY_METRICS');
      }
      return;
    }

    final distance = _activationDistance;
    final nextTop = (metrics.pixels / distance).clamp(0.0, 1.0).toDouble();
    final nextBottom = _bottomProgressForMetrics(metrics, distance);
    _trace(
      'SCROLL_METRICS_PROGRESS_CALCULATED',
      extra: {
        'source': source,
        'activationDistance': distance,
        'incomingTopProgress': nextTop,
        'incomingBottomProgress': nextBottom,
      },
    );
    if ((nextTop - _topProgress).abs() < 0.01 &&
        (nextBottom - _bottomProgress).abs() < 0.01 &&
        !forceRepaint) {
      _trace('SCROLL_METRICS_NO_STATE_CHANGE', extra: {'source': source});
      return;
    }
    setState(() {
      _topProgress = nextTop;
      _bottomProgress = nextBottom;
      if (forceRepaint) _edgeRepaintGeneration++;
    });
    _trace('EDGE_PROGRESS_UPDATED_FROM_METRICS', extra: {'source': source});
  }

  double _bottomProgressForMetrics(ScrollMetrics metrics, double distance) {
    if (widget.footer == null || metrics.maxScrollExtent <= 1) return 0;

    // Base effect strength on content's actual travel under the footer edge.
    // Short ranges reveal the effect gradually rather than stretching the
    // entire range to full opacity.
    final start = math.max(0.0, metrics.maxScrollExtent - distance);
    return ((metrics.pixels - start) / distance).clamp(0.0, 1.0).toDouble();
  }

  void _syncFromScrollController({bool forceRepaint = false}) {
    final controller = widget.scrollController;
    if (controller == null || controller.positions.length != 1) {
      if (forceRepaint) {
        setState(() => _edgeRepaintGeneration++);
      }
      return;
    }
    final position = controller.position;
    if (!position.hasContentDimensions) {
      if (forceRepaint) {
        setState(() => _edgeRepaintGeneration++);
      }
      return;
    }
    _syncScrollMetrics(position, forceRepaint: forceRepaint);
  }

  void _handleScrollControllerChanged() {
    if (_awaitingFirstScrollAfterSettle) {
      _trace('D_FIRST_CONTROLLER_CHANGE_AFTER_SETTLE');
      _awaitingFirstScrollAfterSettle = false;
    }
    _syncFromScrollController();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth == 0) {
      if (_awaitingFirstScrollAfterSettle) {
        _trace(
          'D_FIRST_SCROLL_NOTIFICATION_AFTER_SETTLE',
          extra: {
            'incomingPixels': notification.metrics.pixels,
            'incomingMaxScrollExtent': notification.metrics.maxScrollExtent,
          },
        );
        _awaitingFirstScrollAfterSettle = false;
      }
      _syncScrollMetrics(notification.metrics, source: 'scrollNotification');
    }
    return false;
  }

  bool _onMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.depth == 0) {
      _syncScrollMetrics(notification.metrics, source: 'metricsNotification');
    }
    return false;
  }

  Widget _buildEdgeEffect({required bool atTop, required double progress}) {
    final opacity =
        (widget.maxSurfaceOpacity * progress * widget.surfaceColor.a)
            .clamp(0.0, 1.0)
            .toDouble();
    return LiquidGlassScrollEdge(
      key: ValueKey<String>(
        '${atTop ? 'top' : 'bottom'}-$_edgeRepaintGeneration',
      ),
      edge: atTop ? LiquidGlassEdge.top : LiquidGlassEdge.bottom,
      color: widget.surfaceColor.withValues(alpha: opacity),
      blur: widget.maxBlurSigma * (atTop ? _topBlurSigmaScale : 1) * progress,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollable = widget.scrollBuilder(context, _scrollPadding);
    final hasFooter = widget.footer != null && widget.footerHeight > 0;
    final hasTopEdge = _topProgress > 0.01;
    final hasBottomEdge = hasFooter && _bottomProgress > 0.01;
    final buildTraceSignature =
        '${_routePhaseName()}|$_parentRouteIsCovered|'
        '$_edgeRepaintGeneration|${_topProgress.toStringAsFixed(3)}|'
        '${_bottomProgress.toStringAsFixed(3)}|$hasTopEdge|$hasBottomEdge';
    if (buildTraceSignature != _lastBuildTraceSignature) {
      _lastBuildTraceSignature = buildTraceSignature;
      _trace(
        'BUILD_EDGE_RENDER_DECISION',
        extra: {
          'paintTopEdge': hasTopEdge,
          'paintBottomEdge': hasBottomEdge,
          'scrollPadding': _scrollPadding.toString(),
          'edgeLayerIncluded': hasTopEdge || hasBottomEdge,
        },
      );
    }

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetricsNotification,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: Stack(
          fit: widget.expandViewport ? StackFit.expand : StackFit.loose,
          clipBehavior: Clip.hardEdge,
          children: [
            if (widget.expandViewport)
              Positioned.fill(child: scrollable)
            else
              scrollable,
            if (hasTopEdge || hasBottomEdge)
              Positioned.fill(
                // Clip only the effect layer. Keeping the scroller outside
                // this clip preserves the backdrop content for Android's
                // BackdropFilter while still masking the transparent corners.
                child: _ModalScrollEdgeRenderProbe(
                  onLifecycle: _traceRenderEvent,
                  signature: _renderTraceSignature,
                  child: ClipPath(
                    key: ValueKey<int>(_edgeRepaintGeneration),
                    clipper: ShapeBorderClipper(shape: widget.edgeClipShape),
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        if (hasTopEdge)
                          Positioned(
                            top: kModalSheetScrollEdgeTopOffset,
                            left: 0,
                            right: 0,
                            height: _topFadeExtent,
                            child: _buildEdgeEffect(
                              atTop: true,
                              progress: _topProgress,
                            ),
                          ),
                        if (hasBottomEdge)
                          Positioned(
                            bottom: widget.footerBottomInset,
                            left: 0,
                            right: 0,
                            height: widget.footerHeight + widget.edgeExtent,
                            child: _buildEdgeEffect(
                              atTop: false,
                              progress: _bottomProgress,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            Positioned(
              top: widget.headerTopInset,
              left: 0,
              right: 0,
              height: widget.headerHeight,
              child: widget.header,
            ),
            if (hasFooter)
              Positioned(
                bottom: widget.footerBottomInset,
                left: 0,
                right: 0,
                child: widget.footer!,
              ),
          ],
        ),
      ),
    );
  }
}

class _ModalScrollEdgeRenderProbe extends SingleChildRenderObjectWidget {
  const _ModalScrollEdgeRenderProbe({
    required this.onLifecycle,
    required this.signature,
    required super.child,
  });

  final void Function(String event, int renderObjectId, Size? size, bool compositing)
  onLifecycle;
  final String Function() signature;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _ModalScrollEdgeProbeRenderBox(onLifecycle, signature);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _ModalScrollEdgeProbeRenderBox renderObject,
  ) {
    renderObject
      ..onLifecycle = onLifecycle
      ..signature = signature;
  }
}

class _ModalScrollEdgeProbeRenderBox extends RenderProxyBox {
  _ModalScrollEdgeProbeRenderBox(this.onLifecycle, this.signature);

  void Function(String event, int renderObjectId, Size? size, bool compositing)
  onLifecycle;
  String Function() signature;
  String? _lastPaintSignature;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    onLifecycle('ATTACH', identityHashCode(this), hasSize ? size : null, needsCompositing);
  }

  @override
  void detach() {
    onLifecycle('DETACH', identityHashCode(this), hasSize ? size : null, needsCompositing);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final currentSignature = signature();
    if (currentSignature != _lastPaintSignature) {
      _lastPaintSignature = currentSignature;
      onLifecycle(
        'PAINT:$currentSignature',
        identityHashCode(this),
        hasSize ? size : null,
        needsCompositing,
      );
    }
    super.paint(context, offset);
  }
}
