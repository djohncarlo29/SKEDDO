import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FragmentProgram, FragmentShader, ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
  static const String _shaderAsset =
      'assets/shaders/modal_sheet_scroll_edge.frag';
  static const int _fallbackBlurBandCount = 16;
  static Future<FragmentProgram>? _sharedShaderProgram;

  double _topProgress = 0;
  double _bottomProgress = 0;
  FragmentShader? _topShader;
  FragmentShader? _bottomShader;

  @override
  void initState() {
    super.initState();
    if (ImageFilter.isShaderFilterSupported) {
      unawaited(_loadProgressiveShader());
    }
  }

  Future<void> _loadProgressiveShader() async {
    try {
      final program = await (_sharedShaderProgram ??= FragmentProgram.fromAsset(
        _shaderAsset,
      ));
      if (!mounted) return;
      setState(() {
        _topShader = program.fragmentShader();
        _bottomShader = program.fragmentShader();
      });
    } catch (error, stackTrace) {
      debugPrint('Modal sheet edge shader unavailable: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  @override
  void dispose() {
    _topShader?.dispose();
    _bottomShader?.dispose();
    super.dispose();
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

  void _configureShader(
    FragmentShader shader, {
    required bool atTop,
    required double progress,
  }) {
    final color = widget.surfaceColor;
    shader
      ..setFloat(2, progress)
      ..setFloat(3, widget.maxBlurSigma)
      ..setFloat(4, widget.maxSurfaceOpacity)
      ..setFloat(5, color.red / 255)
      ..setFloat(6, color.green / 255)
      ..setFloat(7, color.blue / 255)
      ..setFloat(8, color.alpha / 255)
      ..setFloat(9, MediaQuery.devicePixelRatioOf(context))
      ..setFloat(10, atTop ? widget.headerHeight : widget.footerHeight)
      ..setFloat(11, widget.edgeExtent)
      ..setFloat(12, atTop ? 0 : 1);
  }

  double _smoothStep(double value) {
    final t = value.clamp(0.0, 1.0).toDouble();
    return t * t * (3 - 2 * t);
  }

  double _fieldStrengthAt(
    double y, {
    required bool atTop,
    required double anchorExtent,
  }) {
    if (atTop) {
      return 1 - _smoothStep((y - anchorExtent) / widget.edgeExtent);
    }
    return _smoothStep(y / widget.edgeExtent);
  }

  LinearGradient _fallbackMaterialGradient({
    required bool atTop,
    required double progress,
    required double anchorExtent,
    required double fieldHeight,
  }) {
    final opacity =
        (widget.maxSurfaceOpacity * progress * widget.surfaceColor.alpha / 255)
            .clamp(0.0, 1.0)
            .toDouble();
    final strong = widget.surfaceColor.withValues(alpha: opacity);
    final medium = widget.surfaceColor.withValues(alpha: opacity * 0.55);
    final clear = widget.surfaceColor.withValues(alpha: 0);

    if (atTop) {
      final anchorStop = (anchorExtent / fieldHeight).clamp(0.0, 1.0);
      final middleStop = (anchorStop + 1) / 2;
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [strong, strong, medium, clear],
        stops: [0, anchorStop, middleStop, 1],
      );
    }

    final transitionStop = (widget.edgeExtent / fieldHeight).clamp(0.0, 1.0);
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [clear, medium, strong, strong],
      stops: [0, transitionStop / 2, transitionStop, 1],
    );
  }

  Widget _buildFallbackEdgeEffect({
    required bool atTop,
    required double progress,
  }) {
    final anchorExtent = atTop ? widget.headerHeight : widget.footerHeight;
    final fieldHeight = anchorExtent + widget.edgeExtent;
    final bandExtent = fieldHeight / _fallbackBlurBandCount;
    final bands = List<Widget>.generate(_fallbackBlurBandCount, (index) {
      final bandTop = bandExtent * index;
      final bandCenter = bandTop + bandExtent / 2;
      final fieldStrength = _fieldStrengthAt(
        bandCenter,
        atTop: atTop,
        anchorExtent: anchorExtent,
      );
      final sigma = widget.maxBlurSigma * progress * fieldStrength;
      if (sigma < 0.05) return const SizedBox.shrink();
      return Positioned(
        top: bandTop,
        left: 0,
        right: 0,
        height: bandExtent,
        child: ClipRect(
          child: BackdropFilter.grouped(
            filter: ImageFilter.blur(
              sigmaX: sigma,
              sigmaY: sigma,
              tileMode: TileMode.decal,
            ),
            child: const SizedBox.expand(),
          ),
        ),
      );
    });
    final gradient = _fallbackMaterialGradient(
      atTop: atTop,
      progress: progress,
      anchorExtent: anchorExtent,
      fieldHeight: fieldHeight,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        BackdropGroup(
          child: Stack(fit: StackFit.expand, children: bands),
        ),
        IgnorePointer(
          child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
        ),
      ],
    );
  }

  Widget _buildEdgeEffect({required bool atTop, required double progress}) {
    final shader = atTop ? _topShader : _bottomShader;
    if (shader == null) {
      return _buildFallbackEdgeEffect(atTop: atTop, progress: progress);
    }

    _configureShader(shader, atTop: atTop, progress: progress);
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.shader(shader),
        child: const SizedBox.expand(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scrollable = widget.scrollBuilder(context, _scrollPadding);
    final topEffectHeight = widget.headerHeight + widget.edgeExtent;
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
                top: kModalSheetScrollEdgeTopOffset,
                left: 0,
                right: 0,
                height: topEffectHeight,
                child: _buildEdgeEffect(atTop: true, progress: _topProgress),
              ),
            if (hasFooter && _bottomProgress > 0.01)
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
