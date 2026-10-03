import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FragmentProgram, FragmentShader, ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

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
  // One continuously masked filter avoids horizontal seams between sigma bands.
  static const double _topBlurSigmaScale = 0.85;
  static const LinearGradient _topBlurMaskGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFFFFFFFF),
      Color(0xF4FFFFFF),
      Color(0xD7FFFFFF),
      Color(0xAEFFFFFF),
      Color(0x80FFFFFF),
      Color(0x51FFFFFF),
      Color(0x28FFFFFF),
      Color(0x0BFFFFFF),
      Color(0x00FFFFFF),
    ],
    stops: [0, 0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1],
  );
  static const String _shaderAsset =
      'assets/shaders/modal_sheet_scroll_edge.frag';
  static Future<FragmentProgram>? _sharedShaderProgram;

  double _topProgress = 0;
  double _bottomProgress = 0;
  FragmentShader? _topShader;
  FragmentShader? _bottomShader;

  // Android devices use the built-in BackdropFilter path. The custom runtime
  // image-filter shader is renderer-sensitive there and can silently produce
  // no visible edge effect on otherwise-supported Impeller devices.
  bool get _useProgressiveShader =>
      !kIsWeb &&
      defaultTargetPlatform != TargetPlatform.android &&
      ImageFilter.isShaderFilterSupported;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_syncFromScrollController);
    if (_useProgressiveShader) {
      unawaited(_loadProgressiveShader());
    }
  }

  @override
  void didUpdateWidget(covariant ModalSheetScrollUnder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_syncFromScrollController);
      widget.scrollController?.addListener(_syncFromScrollController);
      _syncFromScrollController();
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
    widget.scrollController?.removeListener(_syncFromScrollController);
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

  /// At rest, the first scroll-content item starts at this same distance from
  /// the sheet top. Both the material fade and blur reach zero at that edge.
  double get _topFadeExtent => _scrollPadding.top;

  double get _topBlurExtent => _topFadeExtent;

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

  void _syncFromScrollController() {
    final controller = widget.scrollController;
    if (controller == null || controller.positions.length != 1) return;
    final position = controller.position;
    if (!position.hasContentDimensions) return;
    _syncScrollMetrics(position);
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
      ..setFloat(3, widget.maxBlurSigma * (atTop ? _topBlurSigmaScale : 1))
      ..setFloat(4, widget.maxSurfaceOpacity)
      ..setFloat(5, color.red / 255)
      ..setFloat(6, color.green / 255)
      ..setFloat(7, color.blue / 255)
      ..setFloat(8, color.alpha / 255)
      ..setFloat(9, MediaQuery.devicePixelRatioOf(context))
      ..setFloat(10, atTop ? _topFadeExtent : widget.edgeExtent)
      ..setFloat(11, atTop ? _topBlurExtent : widget.edgeExtent)
      ..setFloat(12, atTop ? 0 : 1);
  }

  LinearGradient _fallbackMaterialGradient({
    required bool atTop,
    required double progress,
    required double fieldHeight,
  }) {
    // Keep the tint translucent so it does not wash out the blur beneath it.
    final maxOpacity = widget.maxSurfaceOpacity;
    final opacity = (maxOpacity * progress * widget.surfaceColor.alpha / 255)
        .clamp(0.0, 1.0)
        .toDouble();
    final strong = widget.surfaceColor.withValues(alpha: opacity);
    final medium = widget.surfaceColor.withValues(alpha: opacity * 0.55);
    final clear = widget.surfaceColor.withValues(alpha: 0);

    if (atTop) {
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [strong, clear],
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
    final fieldHeight = atTop
        ? _topFadeExtent
        : widget.footerHeight + widget.edgeExtent;
    final blurHeight = atTop ? _topBlurExtent : fieldHeight;
    final blurGradient = atTop
        ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFFFFF), Color(0x00FFFFFF)],
          )
        : LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [
              Color(0x00FFFFFF),
              Color(0xFFFFFFFF),
              Color(0xFFFFFFFF),
            ],
            stops: [0, (widget.edgeExtent / fieldHeight).clamp(0.0, 1.0), 1],
          );
    final gradient = _fallbackMaterialGradient(
      atTop: atTop,
      progress: progress,
      fieldHeight: fieldHeight,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        if (atTop)
          Positioned.fill(
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) =>
                  _topBlurMaskGradient.createShader(bounds),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.maxBlurSigma * _topBlurSigmaScale * progress,
                    sigmaY: widget.maxBlurSigma * _topBlurSigmaScale * progress,
                    tileMode: TileMode.decal,
                  ),
                  // ShaderMask introduces a temporary buffer; src preserves
                  // the filtered backdrop instead of blending into that buffer.
                  blendMode: BlendMode.src,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          )
        else
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: blurHeight,
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (bounds) => blurGradient.createShader(bounds),
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: widget.maxBlurSigma * progress,
                    sigmaY: widget.maxBlurSigma * progress,
                    tileMode: TileMode.decal,
                  ),
                  blendMode: BlendMode.src,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
        IgnorePointer(
          child: DecoratedBox(decoration: BoxDecoration(gradient: gradient)),
        ),
      ],
    );
  }

  Widget _buildEdgeEffect({required bool atTop, required double progress}) {
    final shader = _useProgressiveShader
        ? (atTop ? _topShader : _bottomShader)
        : null;
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
