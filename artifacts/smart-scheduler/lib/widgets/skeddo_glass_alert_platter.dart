import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../app_theme.dart' show kTertiaryLabel;
import 'rounded_cupertino_sheet.dart';
import 'skeddo_glass_settings.dart';

const double _alertPlatterTitleMessageGap = 14.5;
const double _alertPlatterMessageActionGap = 20.33;

/// Presents SKEDDO's scoped iOS 26/27-style alert with the shared glass curve.
Future<T?> showSkeddoGlassAlertDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<GlassDialogAction> Function(BuildContext dialogContext)
  actionsBuilder,
  bool barrierDismissible = true,
}) {
  final sharedSettings = skeddoModalSheetPickerGlassSettingsFor(
    CupertinoTheme.brightnessOf(context),
  );
  final dialogSettings = skeddoNavigationGlassSettingsFromShared(
    sharedSettings,
  );
  return showSafeCupertinoDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: const Color(0x44000000),
    // Keep the full-window capture layer stationary. Cupertino's default
    // transition scales the entire route child, which shifts the glass
    // backdrop sampling while the dialog itself is moving.
    transitionBuilder: (context, animation, secondaryAnimation, child) => child,
    builder: (dialogContext) => SkeddoGlassAlertPlatter(
      title: title,
      message: message,
      actions: actionsBuilder(dialogContext),
      settings: dialogSettings,
      quality: GlassQuality.premium,
    ),
  );
}

/// The iOS 26/27 alert-platter layout scoped to SKEDDO confirmations.
class SkeddoGlassAlertPlatter extends StatefulWidget {
  const SkeddoGlassAlertPlatter({
    required this.actions,
    super.key,
    this.title,
    this.message,
    this.settings,
    this.quality,
    this.maxWidth = 320,
  });

  final String? title;
  final String? message;
  final List<GlassDialogAction> actions;
  final LiquidGlassSettings? settings;
  final GlassQuality? quality;
  final double? maxWidth;

  @override
  State<SkeddoGlassAlertPlatter> createState() =>
      _SkeddoGlassAlertPlatterState();
}

class _SkeddoGlassAlertPlatterState extends State<SkeddoGlassAlertPlatter> {
  final List<GlobalKey> _actionKeys = [];
  final ValueNotifier<int?> _hoveredActionIndex = ValueNotifier(null);

  @override
  void initState() {
    super.initState();
    _syncActionKeys();
  }

  @override
  void didUpdateWidget(covariant SkeddoGlassAlertPlatter oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncActionKeys();
  }

  @override
  void dispose() {
    _hoveredActionIndex.dispose();
    super.dispose();
  }

  void _syncActionKeys() {
    if (_actionKeys.length > widget.actions.length) {
      _actionKeys.removeRange(widget.actions.length, _actionKeys.length);
    }
    while (_actionKeys.length < widget.actions.length) {
      _actionKeys.add(GlobalKey());
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasHeader = widget.title != null || widget.message != null;
    final settings = widget.settings ?? const LiquidGlassSettings();
    final quality = widget.quality ?? GlassQuality.standard;
    return Stack(
      key: const ValueKey('skeddo-glass-alert-fullscreen-layer'),
      fit: StackFit.expand,
      children: [
        // Match GlassMenu's backdrop-capture architecture: keep the capture
        // layer full-screen and alive for the entire route transition, with the
        // alert surface grouped inside it instead of capturing in its own layer.
        AdaptiveLiquidGlassLayer(
          settings: settings,
          quality: quality,
          child: AnimatedPadding(
            padding: MediaQuery.viewInsetsOf(context),
            duration: const Duration(milliseconds: 100),
            curve: Curves.decelerate,
            child: MediaQuery.removeViewInsets(
              context: context,
              removeLeft: true,
              removeTop: true,
              removeRight: true,
              removeBottom: true,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: _transitionDialogContent(
                      context,
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: widget.maxWidth ?? 320,
                        ),
                        child: Semantics(
                          scopesRoute: true,
                          namesRoute: true,
                          explicitChildNodes: true,
                          label: widget.title ?? 'Confirmation',
                          child: GlassInteractiveContainer(
                            useOwnLayer: false,
                            settings: settings,
                            quality: quality,
                            shape: const LiquidRoundedSuperellipse(
                              borderRadius: 34,
                            ),
                            padding: EdgeInsets.zero,
                            child: _AlertPlatterScrollViewport(
                              actions: widget.actions,
                              actionKeys: _actionKeys,
                              hoveredActionIndex: _hoveredActionIndex,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  if (hasHeader)
                                    Padding(
                                      padding:
                                          const EdgeInsetsDirectional.fromSTEB(
                                            30,
                                            22,
                                            30,
                                            0,
                                          ),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (widget.title != null)
                                            SizedBox(
                                              width: double.infinity,
                                              child: Text(
                                                widget.title!,
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.w600,
                                                  color: CupertinoColors.label
                                                      .resolveFrom(context),
                                                ),
                                              ),
                                            ),
                                          if (widget.title != null &&
                                              widget.message != null)
                                            const SizedBox(
                                              // Text glyphs leave different
                                              // leading inside the 17pt and 15pt
                                              // line boxes. This optical
                                              // correction matches the action gap.
                                              height:
                                                  _alertPlatterTitleMessageGap,
                                            ),
                                          if (widget.message != null)
                                            SizedBox(
                                              width: double.infinity,
                                              child: Text(
                                                widget.message!,
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  color: CupertinoColors
                                                      .secondaryLabel
                                                      .resolveFrom(context),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      16,
                                      hasHeader
                                          ? _alertPlatterMessageActionGap
                                          : 22,
                                      16,
                                      16,
                                    ),
                                    child: _buildActions(context),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _transitionDialogContent(BuildContext context, Widget child) {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null) return child;

    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        key: const ValueKey('skeddo-glass-alert-dialog-transition'),
        scale: animation.drive(
          Tween<double>(begin: 1.3, end: 1),
        ),
        child: child,
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    final buttonOrder = List<int>.generate(
      widget.actions.length,
      (index) => index,
    );
    if (buttonOrder.length == 2) {
      final cancelIndex = widget.actions.indexWhere(
        (action) => action.label.trim().toLowerCase() == 'cancel',
      );
      if (cancelIndex == 0) {
        buttonOrder
          ..[0] = 1
          ..[1] = 0;
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var orderIndex = 0; orderIndex < buttonOrder.length; orderIndex++)
          Padding(
            padding: EdgeInsets.only(top: orderIndex > 0 ? 8 : 0),
            child: _SkeddoAlertActionButton(
              key: _actionKeys[buttonOrder[orderIndex]],
              action: widget.actions[buttonOrder[orderIndex]],
              displayLabel: widget.actions[buttonOrder[orderIndex]].label,
              actionIndex: buttonOrder[orderIndex],
              hoveredActionIndex: _hoveredActionIndex,
            ),
          ),
      ],
    );
  }
}

class _SkeddoAlertActionButton extends StatefulWidget {
  const _SkeddoAlertActionButton({
    required this.action,
    required this.displayLabel,
    required this.actionIndex,
    required this.hoveredActionIndex,
    super.key,
  });

  final GlassDialogAction action;
  final String displayLabel;
  final int actionIndex;
  final ValueListenable<int?> hoveredActionIndex;

  @override
  State<_SkeddoAlertActionButton> createState() =>
      _SkeddoAlertActionButtonState();
}

class _SkeddoAlertActionButtonState extends State<_SkeddoAlertActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final textColor = action.isDestructive
        ? CupertinoColors.systemRed.resolveFrom(context)
        : CupertinoColors.label.resolveFrom(context);
    final wrapsAtAccessibilitySize =
        MediaQuery.textScalerOf(context).scale(14) > 14 * 1.4;
    final ShapeBorder shape = wrapsAtAccessibilitySize
        ? const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(32)),
          )
        : const StadiumBorder();

    return Semantics(
      button: true,
      label: action.label,
      onTap: action.onPressed,
      child: ValueListenableBuilder<int?>(
        valueListenable: widget.hoveredActionIndex,
        builder: (context, hoveredIndex, _) {
          final highlighted = _pressed || hoveredIndex == widget.actionIndex;
          final isDark =
              CupertinoTheme.brightnessOf(context) == Brightness.dark;
          final fillAlpha = isDark
              ? (highlighted ? 0.20 : 0.115)
              : (highlighted ? 0.25 : 0.15);
          final fill = isDark
              ? CupertinoColors.white.withValues(alpha: fillAlpha)
              : CupertinoColors.black.withValues(alpha: fillAlpha);
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            onTap: action.onPressed,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedContainer(
              key: ValueKey<int>(widget.actionIndex),
              duration: highlighted
                  ? Duration.zero
                  : const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 48),
              alignment: Alignment.center,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              decoration: ShapeDecoration(color: fill, shape: shape),
              child: Text(
                widget.displayLabel,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AlertPlatterScrollViewport extends StatefulWidget {
  const _AlertPlatterScrollViewport({
    required this.child,
    required this.actions,
    required this.actionKeys,
    required this.hoveredActionIndex,
  });

  final Widget child;
  final List<GlassDialogAction> actions;
  final List<GlobalKey> actionKeys;
  final ValueNotifier<int?> hoveredActionIndex;

  @override
  State<_AlertPlatterScrollViewport> createState() =>
      _AlertPlatterScrollViewportState();
}

class _AlertPlatterScrollViewportState
    extends State<_AlertPlatterScrollViewport> {
  static const double _fadeHeight = 50;
  static const double _platterRadius = 34;

  final ScrollController _controller = ScrollController();
  Timer? _indicatorHideTimer;
  bool _canScroll = false;
  bool _showTopFade = false;
  bool _showBottomFade = false;
  bool _indicatorVisible = false;
  int? _activePointer;
  Offset? _pointerDownPosition;
  Offset? _lastPointerPosition;
  bool _pointerDragged = false;
  bool _didScrollDuringPointer = false;
  double? _lastScrollPixels;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_syncFromController);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncFromController();
    });
  }

  @override
  void dispose() {
    _indicatorHideTimer?.cancel();
    _controller
      ..removeListener(_syncFromController)
      ..dispose();
    super.dispose();
  }

  void _syncFromController() {
    if (!_controller.hasClients) return;
    _syncFromMetrics(_controller.position);
  }

  void _syncFromMetrics(ScrollMetrics metrics) {
    final canScroll = metrics.maxScrollExtent > 1.0;
    // ScrollMetrics.extentBefore/After clamp to zero at their respective
    // endpoints, including during bounce. This keeps the reached edge fully
    // opaque while retaining a fade only where content remains offscreen.
    final showTop = canScroll && metrics.extentBefore > 1.0;
    final showBottom = canScroll && metrics.extentAfter > 1.0;
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
    });
  }

  bool _onScrollMetrics(ScrollMetricsNotification notification) {
    if (notification.metrics.axis == Axis.vertical) {
      _syncFromMetrics(notification.metrics);
    }
    return false;
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical || notification.depth > 0) {
      return false;
    }
    _syncFromMetrics(notification.metrics);
    if (_activePointer != null &&
        notification is ScrollUpdateNotification &&
        _lastScrollPixels != notification.metrics.pixels) {
      _lastScrollPixels = notification.metrics.pixels;
      _didScrollDuringPointer = true;
      _updateHoveredAction(_lastPointerPosition);
    }
    if (_canScroll &&
        (notification is ScrollStartNotification ||
            notification is ScrollUpdateNotification ||
            notification is OverscrollNotification)) {
      _showScrollIndicator();
    }
    if (notification is ScrollEndNotification) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncFromController();
      });
    }
    return false;
  }

  void _showScrollIndicator() {
    if (!_indicatorVisible) {
      setState(() => _indicatorVisible = true);
    }
    _indicatorHideTimer?.cancel();
    _indicatorHideTimer = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) setState(() => _indicatorVisible = false);
    });
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _pointerDownPosition = event.position;
    _lastPointerPosition = event.position;
    _pointerDragged = false;
    _didScrollDuringPointer = false;
    _lastScrollPixels = _controller.hasClients
        ? _controller.position.pixels
        : null;
    _setHoveredAction(_actionIndexAt(event.position));
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer || _pointerDownPosition == null) {
      return;
    }
    _lastPointerPosition = event.position;
    if ((event.position - _pointerDownPosition!).distance > kTouchSlop) {
      _pointerDragged = true;
    }
    _updateHoveredAction(event.position);
  }

  void _updateHoveredAction(Offset? position) {
    if (position == null) return;
    // On overflowing dialogs, only activate the glide highlight once the
    // Scrollable has actually moved. This keeps regular drags distinct from
    // scroll-to-select and lets content moving beneath a stationary finger
    // update the hovered button.
    if (_canScroll && !_didScrollDuringPointer) {
      _setHoveredAction(null);
      return;
    }
    _setHoveredAction(_actionIndexAt(position));
  }

  void _setHoveredAction(int? index) {
    if (widget.hoveredActionIndex.value != index) {
      widget.hoveredActionIndex.value = index;
    }
  }

  int? _actionIndexAt(Offset globalPosition) {
    for (var index = 0; index < widget.actionKeys.length; index++) {
      final renderObject = widget.actionKeys[index].currentContext
          ?.findRenderObject();
      if (renderObject is! RenderBox ||
          !renderObject.attached ||
          !renderObject.hasSize) {
        continue;
      }
      final bounds =
          renderObject.localToGlobal(Offset.zero) & renderObject.size;
      if (bounds.contains(globalPosition)) return index;
    }
    return null;
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _lastPointerPosition = event.position;
    _updateHoveredAction(event.position);
    final shouldSelect = _pointerDragged;
    final didScroll = _didScrollDuringPointer;
    _activePointer = null;
    _pointerDownPosition = null;
    _lastPointerPosition = null;
    _pointerDragged = false;
    _didScrollDuringPointer = false;
    _lastScrollPixels = null;
    if (!shouldSelect || (_canScroll && !didScroll)) {
      _setHoveredAction(null);
      return;
    }

    final actionIndex = _actionIndexAt(event.position);
    if (actionIndex != null && actionIndex < widget.actions.length) {
      widget.actions[actionIndex].onPressed();
    } else {
      _setHoveredAction(null);
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _pointerDownPosition = null;
    _lastPointerPosition = null;
    _pointerDragged = false;
    _didScrollDuringPointer = false;
    _lastScrollPixels = null;
    _setHoveredAction(null);
  }

  Shader _scrollFadeShader(Rect bounds) {
    const white = Color(0xFFFFFFFF);
    const transparent = Color(0x00FFFFFF);
    if (bounds.height == 0) {
      return const LinearGradient(colors: [white, white]).createShader(bounds);
    }
    final topFraction = _showTopFade
        ? (_fadeHeight / bounds.height).clamp(0.0, 0.45)
        : 0.0;
    final bottomFraction = _showBottomFade
        ? (_fadeHeight / bounds.height).clamp(0.0, 0.45)
        : 0.0;
    final topStart = topFraction * 0.30;
    final topSolid = topFraction * 0.65;
    final bottomSolid = 1.0 - bottomFraction * 0.65;
    final bottomEnd = 1.0 - bottomFraction * 0.30;
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _showTopFade ? transparent : white,
        _showTopFade ? const Color(0x06FFFFFF) : white,
        _showTopFade ? const Color(0x38FFFFFF) : white,
        white,
        white,
        _showBottomFade ? const Color(0x38FFFFFF) : white,
        _showBottomFade ? const Color(0x06FFFFFF) : white,
        _showBottomFade ? transparent : white,
      ],
      stops: [
        0.0,
        topStart,
        topSolid,
        topFraction,
        1.0 - bottomFraction,
        bottomSolid,
        bottomEnd,
        1.0,
      ],
    ).createShader(bounds);
  }

  Widget _buildScrollIndicator() {
    return Positioned(
      right: 3,
      top: 0,
      bottom: 0,
      width: 2.5,
      child: IgnorePointer(
        child: AnimatedOpacity(
          key: const ValueKey('skeddo-glass-alert-scroll-indicator'),
          opacity: _canScroll && _indicatorVisible ? 0.8 : 0.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: AnimatedScale(
            scale: _indicatorVisible ? 1.0 : 0.65,
            alignment: Alignment.center,
            duration: const Duration(milliseconds: 240),
            curve: _indicatorVisible ? Curves.easeOutBack : Curves.easeInCubic,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final trackInset = math.min(
                  _platterRadius,
                  constraints.maxHeight / 2,
                );
                final trackHeight = math.max(
                  0.0,
                  constraints.maxHeight - trackInset * 2,
                );
                if (trackHeight <= 0) return const SizedBox.shrink();
                return Padding(
                  padding: EdgeInsets.symmetric(vertical: trackInset),
                  child: AnimatedBuilder(
                    animation: _controller,
                    builder: (context, _) {
                      if (!_controller.hasClients) {
                        return const SizedBox.shrink();
                      }
                      final position = _controller.position;
                      if (!position.hasContentDimensions ||
                          position.maxScrollExtent < 1.0) {
                        return const SizedBox.shrink();
                      }
                      final overscroll = position.pixels < 0
                          ? -position.pixels
                          : position.pixels > position.maxScrollExtent
                          ? position.pixels - position.maxScrollExtent
                          : 0.0;
                      final total =
                          position.maxScrollExtent +
                          position.viewportDimension +
                          overscroll;
                      final fraction = (position.viewportDimension / total)
                          .clamp(0.0, 1.0);
                      final thumbHeight = math.min(
                        trackHeight,
                        math.max(20.0, fraction * trackHeight),
                      );
                      final ratio = (position.pixels / position.maxScrollExtent)
                          .clamp(0.0, 1.0);
                      final thumbTop = (ratio * (trackHeight - thumbHeight))
                          .clamp(
                            0.0,
                            (trackHeight - thumbHeight).clamp(
                              0.0,
                              double.infinity,
                            ),
                          );
                      return Stack(
                        children: [
                          Positioned(
                            top: thumbTop,
                            left: 0,
                            right: 0,
                            height: thumbHeight,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: CupertinoDynamicColor.resolve(
                                  kTertiaryLabel,
                                  context,
                                ),
                                borderRadius: BorderRadius.circular(1.25),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollMetricsNotification>(
      onNotification: _onScrollMetrics,
      child: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: Listener(
          onPointerDown: _onPointerDown,
          onPointerMove: _onPointerMove,
          onPointerUp: _onPointerUp,
          onPointerCancel: _onPointerCancel,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              ShaderMask(
                key: const ValueKey('skeddo-glass-alert-scroll-fade'),
                blendMode: BlendMode.dstIn,
                shaderCallback: _scrollFadeShader,
                child: SingleChildScrollView(
                  key: const ValueKey('skeddo-glass-alert-scroll-viewport'),
                  controller: _controller,
                  physics: _canScroll
                      ? const BouncingScrollPhysics(
                          parent: AlwaysScrollableScrollPhysics(),
                        )
                      : const NeverScrollableScrollPhysics(),
                  child: widget.child,
                ),
              ),
              _buildScrollIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}
