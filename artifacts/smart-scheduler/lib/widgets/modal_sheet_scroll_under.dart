import 'dart:math' as math;

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
  Animation<double>? _parentRouteSecondaryAnimation;
  bool _parentRouteIsCovered = false;

  @override
  void initState() {
    super.initState();
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
    widget.scrollController?.removeListener(_handleScrollControllerChanged);
    _parentRouteSecondaryAnimation?.removeStatusListener(
      _handleParentRouteAnimationStatus,
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
      if (_topProgress == 0 && _bottomProgress == 0) return;
      setState(() {
        _topProgress = 0;
        _bottomProgress = 0;
      });
      return;
    }

    final distance = _activationDistance;
    final nextTop = (metrics.pixels / distance).clamp(0.0, 1.0).toDouble();
    final nextBottom = _bottomProgressForMetrics(metrics, distance);
    if ((nextTop - _topProgress).abs() < 0.01 &&
        (nextBottom - _bottomProgress).abs() < 0.01) {
      return;
    }
    setState(() {
      _topProgress = nextTop;
      _bottomProgress = nextBottom;
    });
  }

  double _bottomProgressForMetrics(ScrollMetrics metrics, double distance) {
    if (widget.footer == null || metrics.maxScrollExtent <= 1) return 0;

    // Base effect strength on content's actual travel under the footer edge.
    // Short ranges reveal the effect gradually rather than stretching the
    // entire range to full opacity.
    final start = math.max(0.0, metrics.maxScrollExtent - distance);
    return ((metrics.pixels - start) / distance).clamp(0.0, 1.0).toDouble();
  }

  void _syncFromScrollController() {
    final controller = widget.scrollController;
    if (controller == null || controller.positions.length != 1) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    _syncScrollMetrics(position);
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
    return LiquidGlassScrollEdge(
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
                child: ClipPath(
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
