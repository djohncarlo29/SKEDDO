import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassEdge, LiquidGlassScrollEdge;

import '../app_theme.dart'
    show BoundedSquircleStadiumBorder, kModalSheetCornerRadius;

/// The top scroll-edge effect is anchored to the modal sheet's top edge,
/// independently of the inset used to position its header.
const double kModalSheetScrollEdgeTopOffset = 0;

typedef _ModalSheetEdgeProgress = ({
  double top,
  double bottom,
  int renderRevision,
});

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
    this.showTopEdgeOnShortContentRubberband = true,
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

  /// Shows the top scroll-under treatment while short content is pulled past
  /// either end of its zero-range scroll extent with bouncing physics.
  final bool showTopEdgeOnShortContentRubberband;

  /// Length of each gradient edge transition.
  final double edgeExtent;

  /// Maximum blur sigma at the fixed-control edge.
  final double maxBlurSigma;

  /// Maximum opacity of the matching modal-surface veil.
  final double maxSurfaceOpacity;

  @override
  State<ModalSheetScrollUnder> createState() => _ModalSheetScrollUnderState();
}

class _ModalSheetScrollUnderState extends State<ModalSheetScrollUnder>
    with WidgetsBindingObserver {
  static const double _topBlurSigmaScale = 0.85;

  static const double _inactiveBlurSigma = 0.001;

  final ValueNotifier<_ModalSheetEdgeProgress> _edgeProgress = ValueNotifier((
    top: 0,
    bottom: 0,
    renderRevision: 0,
  ));
  Animation<double>? _parentRouteSecondaryAnimation;
  bool _parentRouteIsCovered = false;
  bool _metricsRefreshScheduled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.scrollController?.addListener(_handleScrollControllerChanged);
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
      _parentRouteSecondaryAnimation = secondaryAnimation;
      _parentRouteSecondaryAnimation?.addStatusListener(
        _handleParentRouteAnimationStatus,
      );
      if (secondaryAnimation != null &&
          secondaryAnimation.status != AnimationStatus.dismissed) {
        _parentRouteIsCovered = true;
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
    _scheduleScrollControllerSync();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.scrollController?.removeListener(_handleScrollControllerChanged);
    _parentRouteSecondaryAnimation?.removeStatusListener(
      _handleParentRouteAnimationStatus,
    );
    _edgeProgress.dispose();
    super.dispose();
  }

  void _scheduleScrollControllerSync() {
    if (widget.scrollController == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _syncFromScrollController()) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncFromScrollController();
      });
    });
  }

  @override
  void didChangeMetrics() {
    if (_metricsRefreshScheduled) return;
    _metricsRefreshScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsRefreshScheduled = false;
      if (!mounted) return;

      // Orientation changes can resize the scroll viewport without producing
      // a useful scroll notification. Read its newly laid-out metrics and
      // refresh the backdrop-filter layer even if progress itself is unchanged.
      final synced = _syncFromScrollController();
      final current = _edgeProgress.value;
      _edgeProgress.value = (
        top: current.top,
        bottom: current.bottom,
        renderRevision: current.renderRevision + 1,
      );
      if (!synced && widget.scrollController != null) {
        _scheduleScrollControllerSync();
      }
    });
  }

  void _handleParentRouteAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward ||
        status == AnimationStatus.completed) {
      _parentRouteIsCovered = true;
      return;
    }
    if (status != AnimationStatus.dismissed) return;

    // Wait until the parent route's secondary transition has settled before
    // syncing the edge to the parent's final, live scroll position.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          _parentRouteSecondaryAnimation?.status !=
              AnimationStatus.dismissed) {
        return;
      }
      _parentRouteIsCovered = false;
      _syncFromScrollController();
    });
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
    ScrollMetrics metrics,
  ) {
    // Ignore route-transition scroll notifications while covered. At settle,
    // _handleParentRouteAnimationStatus resyncs from the live ScrollPosition;
    // transient route metrics must not replace that settled value.
    if (_parentRouteIsCovered) return;

    if (metrics.maxScrollExtent <= 1) {
      final distance = _activationDistance;
      final shortContentTopPull = widget.showTopEdgeOnShortContentRubberband
          ? _shortContentPull(metrics, distance)
          : 0.0;
      final currentProgress = _edgeProgress.value;
      if ((shortContentTopPull - currentProgress.top).abs() < 0.01 &&
          currentProgress.bottom == 0) {
        return;
      }
      _edgeProgress.value = (
        top: shortContentTopPull,
        bottom: 0,
        renderRevision: currentProgress.renderRevision,
      );
      return;
    }

    final distance = _activationDistance;
    final nextTop = (metrics.pixels / distance).clamp(0.0, 1.0).toDouble();
    final nextBottom = _bottomProgressForMetrics(metrics, distance);
    final currentProgress = _edgeProgress.value;
    if ((nextTop - currentProgress.top).abs() < 0.01 &&
        (nextBottom - currentProgress.bottom).abs() < 0.01) {
      return;
    }
    _edgeProgress.value = (
      top: nextTop,
      bottom: nextBottom,
      renderRevision: currentProgress.renderRevision,
    );
  }

  double _shortContentPull(ScrollMetrics metrics, double distance) {
    final pastStart = metrics.minScrollExtent - metrics.pixels;
    final pastEnd = metrics.pixels - metrics.maxScrollExtent;
    final pull = math.max(pastStart, pastEnd).clamp(0.0, distance).toDouble();
    return pull / distance;
  }

  double _bottomProgressForMetrics(ScrollMetrics metrics, double distance) {
    if (widget.footer == null || metrics.maxScrollExtent <= 1) return 0;

    // Base effect strength on content's actual travel under the footer edge.
    // Short ranges reveal the effect gradually rather than stretching the
    // entire range to full opacity.
    final start = math.max(0.0, metrics.maxScrollExtent - distance);
    return ((metrics.pixels - start) / distance).clamp(0.0, 1.0).toDouble();
  }

  bool _syncFromScrollController() {
    final controller = widget.scrollController;
    if (controller == null || controller.positions.length != 1) return false;
    final position = controller.position;
    if (!position.hasContentDimensions) return false;
    _syncScrollMetrics(position);
    return true;
  }

  void _handleScrollControllerChanged() {
    _syncFromScrollController();
  }

  bool _onScrollNotification(ScrollNotification notification) {
    if (notification.depth == 0) _syncScrollMetrics(notification.metrics);
    return false;
  }

  bool _onMetricsNotification(ScrollMetricsNotification notification) {
    if (notification.depth == 0) _syncScrollMetrics(notification.metrics);
    return false;
  }

  Widget _buildEdgeEffect({required bool atTop, required double progress}) {
    final opacity =
        (widget.maxSurfaceOpacity * progress * widget.surfaceColor.a)
            .clamp(0.0, 1.0)
            .toDouble();
    final requestedBlur =
        widget.maxBlurSigma * (atTop ? _topBlurSigmaScale : 1) * progress;
    return LiquidGlassScrollEdge(
      key: ValueKey<Object>((atTop, _edgeProgress.value.renderRevision)),
      edge: atTop ? LiquidGlassEdge.top : LiquidGlassEdge.bottom,
      color: widget.surfaceColor.withValues(alpha: opacity),
      // Keep LiquidGlassScrollEdge's render-tree shape stable at rest. The
      // effect itself is hidden then, and this near-zero sigma prevents an
      // inactive blur from changing scroll viewport layout during a pull.
      blur: requestedBlur > 0 ? requestedBlur : _inactiveBlurSigma,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollable = widget.scrollBuilder(context, _scrollPadding);
    final hasFooter = widget.footer != null && widget.footerHeight > 0;

    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onMetricsNotification,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScrollNotification,
        child: Stack(
          fit: widget.expandViewport ? StackFit.expand : StackFit.loose,
          // Let card decorations paint their shadows beyond the scroll
          // viewport. The rounded sheet route remains the outer visual clip.
          clipBehavior: Clip.none,
          children: [
            if (widget.expandViewport)
              Positioned.fill(child: scrollable)
            else
              scrollable,
            Positioned.fill(
              // Keep the overlay's position fixed so progress updates never
              // relayout the ScrollView while it is being rubberbanded.
              child: IgnorePointer(
                child: ValueListenableBuilder<_ModalSheetEdgeProgress>(
                  valueListenable: _edgeProgress,
                  builder: (context, progress, _) => ClipPath(
                    // Clip only the effect layer. Keeping the scroller outside
                    // this clip preserves the backdrop content for Android's
                    // BackdropFilter while masking transparent corners.
                    clipper: ShapeBorderClipper(shape: widget.edgeClipShape),
                    child: Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [
                        Positioned(
                          top: kModalSheetScrollEdgeTopOffset,
                          left: 0,
                          right: 0,
                          height: _topFadeExtent,
                          child: Offstage(
                            offstage: progress.top <= 0.01,
                            child: _buildEdgeEffect(
                              atTop: true,
                              progress: progress.top,
                            ),
                          ),
                        ),
                        if (hasFooter)
                          Positioned(
                            bottom: widget.footerBottomInset,
                            left: 0,
                            right: 0,
                            height: widget.footerHeight + widget.edgeExtent,
                            child: Offstage(
                              offstage: progress.bottom <= 0.01,
                              child: _buildEdgeEffect(
                                atTop: false,
                                progress: progress.bottom,
                              ),
                            ),
                          ),
                      ],
                    ),
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

/// Matches [SizeTransition]'s vertical layout/animation while giving fully
/// visible modal cards enough paint room for their outer shadows.
///
/// During the size animation, content remains clipped exactly like a normal
/// [SizeTransition]. Once fully open, the clip expands beyond the layout box
/// so a card at the edge of a transition group can paint its shadow.
class ModalCardShadowSizeTransition extends AnimatedWidget {
  const ModalCardShadowSizeTransition({
    super.key,
    required Animation<double> sizeFactor,
    required this.child,
    this.axisAlignment = 0,
    this.shadowOutset = 20,
  }) : super(listenable: sizeFactor);

  final Widget child;
  final double axisAlignment;
  final double shadowOutset;

  Animation<double> get sizeFactor => listenable as Animation<double>;

  @override
  Widget build(BuildContext context) {
    final factor = math.max(sizeFactor.value, 0.0);
    final outset = factor >= 1.0 ? shadowOutset : 0.0;

    return ClipRect(
      clipper: _ModalCardShadowClipper(outset: outset),
      child: Align(
        alignment: AlignmentDirectional(-1.0, axisAlignment),
        heightFactor: factor,
        child: child,
      ),
    );
  }
}

class _ModalCardShadowClipper extends CustomClipper<Rect> {
  const _ModalCardShadowClipper({required this.outset});

  final double outset;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    -outset,
    -outset,
    size.width + outset,
    size.height + outset,
  );

  @override
  Rect getApproximateClipRect(Size size) => getClip(size);

  @override
  bool shouldReclip(covariant _ModalCardShadowClipper oldClipper) =>
      outset != oldClipper.outset;
}
