import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/widgets.dart';

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
    this.headerTopInset = 0,
    this.headerGap = 0,
    this.footer,
    this.footerHeight = 0,
    this.footerBottomInset = 0,
    this.expandViewport = true,
    this.edgeExtent = 64,
    this.maxBlurSigma = 12,
    this.maxSurfaceOpacity = 0.34,
  }) : assert(headerHeight >= 0),
       assert(headerTopInset >= 0),
       assert(headerGap >= 0),
       assert(footerHeight >= 0),
       assert(footerBottomInset >= 0),
       assert(edgeExtent > 0);

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
  double _topProgress = 0;
  double _bottomProgress = 0;

  double get _activationDistance => math.max(
    48,
    widget.headerHeight +
        widget.headerGap +
        widget.baseScrollPadding.top,
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

  void _syncScrollMetrics(ScrollMetrics metrics) {
    if (metrics.maxScrollExtent <= 1) {
      if (_topProgress != 0 || _bottomProgress != 0) {
        setState(() {
          _topProgress = 0;
          _bottomProgress = 0;
        });
      }
      return;
    }

    final distance = _activationDistance;
    final nextTop = (metrics.pixels / distance).clamp(0.0, 1.0).toDouble();
    final nextBottom = widget.footer == null
        ? 0.0
        : ((metrics.pixels - (metrics.maxScrollExtent - distance)) / distance)
              .clamp(0.0, 1.0)
              .toDouble();
    if ((nextTop - _topProgress).abs() < 0.01 &&
        (nextBottom - _bottomProgress).abs() < 0.01) {
      return;
    }
    setState(() {
      _topProgress = nextTop;
      _bottomProgress = nextBottom;
    });
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
    const white = Color(0xFFFFFFFF);
    final edgeColor = white.withValues(alpha: progress);
    final clearColor = white.withValues(alpha: 0);
    final gradient = LinearGradient(
      begin: atTop ? Alignment.topCenter : Alignment.bottomCenter,
      end: atTop ? Alignment.bottomCenter : Alignment.topCenter,
      colors: [edgeColor, clearColor],
    );

    return IgnorePointer(
      child: ClipRect(
        child: ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: gradient.createShader,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: widget.maxBlurSigma * progress,
              sigmaY: widget.maxBlurSigma * progress,
            ),
            child: ColoredBox(
              color: widget.surfaceColor.withValues(
                alpha: widget.maxSurfaceOpacity * progress,
              ),
              child: const SizedBox.expand(),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollable = widget.scrollBuilder(context, _scrollPadding);
    final topEffectHeight =
        widget.headerTopInset + widget.headerHeight + widget.edgeExtent;
    final hasFooter = widget.footer != null && widget.footerHeight > 0;

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
            if (_topProgress > 0.01)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: topEffectHeight,
                child: _buildEdgeEffect(
                  atTop: true,
                  progress: _topProgress,
                ),
              ),
            if (hasFooter && _bottomProgress > 0.01)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: widget.footerHeight +
                    widget.footerBottomInset +
                    widget.edgeExtent,
                child: _buildEdgeEffect(
                  atTop: false,
                  progress: _bottomProgress,
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