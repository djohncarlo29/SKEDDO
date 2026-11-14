import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../app_theme.dart'
    show
        kConfirmationButtonCornerRadius,
        kConfirmationMessageActionGap,
        skeddoConfirmationActionFillColor,
        kTertiaryLabel;
import 'rounded_cupertino_sheet.dart';
import 'skeddo_glass_settings.dart';

const double _alertPlatterTitleMessageGap = 14.5;
const double _alertPlatterInitialScale = 1.12;

class SkeddoGlassAlertFlowAction<T> {
  const SkeddoGlassAlertFlowAction({
    required this.label,
    this.isDestructive = false,
    this.isPrimary = false,
    this.nextStep,
    this.result,
  });

  final String label;
  final bool isDestructive;
  final bool isPrimary;
  final int? nextStep;
  final T? result;
}

class SkeddoGlassAlertFlowStep<T> {
  const SkeddoGlassAlertFlowStep({
    required this.title,
    required this.actions,
    this.message,
  });

  final String title;
  final String? message;
  final List<SkeddoGlassAlertFlowAction<T>> actions;
}

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

/// Presents a multi-step alert in one route so its glass platter can morph
/// between steps instead of stacking two dismissing/entering dialogs.
Future<T?> showSkeddoGlassAlertFlow<T>({
  required BuildContext context,
  required List<SkeddoGlassAlertFlowStep<T>> steps,
  int initialStep = 0,
  bool barrierDismissible = true,
}) {
  if (steps.isEmpty || initialStep < 0 || initialStep >= steps.length) {
    throw ArgumentError.value(initialStep, 'initialStep', 'No matching step.');
  }
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
    transitionBuilder: (context, animation, secondaryAnimation, child) => child,
    builder: (dialogContext) => _SkeddoGlassAlertFlowRoute<T>(
      steps: steps,
      initialStep: initialStep,
      settings: dialogSettings,
    ),
  );
}

class _SkeddoGlassAlertFlowRoute<T> extends StatefulWidget {
  const _SkeddoGlassAlertFlowRoute({
    required this.steps,
    required this.initialStep,
    required this.settings,
  });

  final List<SkeddoGlassAlertFlowStep<T>> steps;
  final int initialStep;
  final LiquidGlassSettings settings;

  @override
  State<_SkeddoGlassAlertFlowRoute<T>> createState() =>
      _SkeddoGlassAlertFlowRouteState<T>();
}

class _SkeddoGlassAlertFlowRouteState<T>
    extends State<_SkeddoGlassAlertFlowRoute<T>> {
  late int _stepIndex = widget.initialStep;

  void _activate(SkeddoGlassAlertFlowAction<T> action) {
    final nextStep = action.nextStep;
    if (nextStep != null) {
      if (nextStep < 0 || nextStep >= widget.steps.length) {
        throw RangeError.index(nextStep, widget.steps, 'nextStep');
      }
      setState(() => _stepIndex = nextStep);
      return;
    }
    Navigator.of(context).pop<T>(action.result);
  }

  @override
  Widget build(BuildContext context) {
    final step = widget.steps[_stepIndex];
    return SkeddoGlassAlertPlatter(
      key: const ValueKey('skeddo-glass-alert-flow-platter'),
      title: step.title,
      message: step.message,
      contentTransitionKey: _stepIndex,
      settings: widget.settings,
      quality: GlassQuality.premium,
      actions: [
        for (final flowAction in step.actions)
          GlassDialogAction(
            label: flowAction.label,
            isDestructive: flowAction.isDestructive,
            isPrimary: flowAction.isPrimary,
            onPressed: () => _activate(flowAction),
          ),
      ],
    );
  }
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
    this.contentTransitionKey,
  });

  final String? title;
  final String? message;
  final List<GlassDialogAction> actions;
  final LiquidGlassSettings? settings;
  final GlassQuality? quality;
  final double? maxWidth;
  final Object? contentTransitionKey;

  @override
  State<SkeddoGlassAlertPlatter> createState() =>
      _SkeddoGlassAlertPlatterState();
}

class _SkeddoGlassAlertPlatterState extends State<SkeddoGlassAlertPlatter>
    with SingleTickerProviderStateMixin {
  final List<GlobalKey> _actionKeys = [];
  final ValueNotifier<int?> _hoveredActionIndex = ValueNotifier(null);
  final GlassOptionGestureController _optionGestureController =
      GlassOptionGestureController();
  late final AnimationController _stepBloomController;
  late final Animation<double> _stepBloomScale;

  @override
  void initState() {
    super.initState();
    _stepBloomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 1,
    );
    _stepBloomScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: _alertPlatterInitialScale,
        ).chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 42,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: _alertPlatterInitialScale,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 58,
      ),
    ]).animate(_stepBloomController);
    _syncActionKeys();
  }

  @override
  void didUpdateWidget(covariant SkeddoGlassAlertPlatter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentTransitionKey != widget.contentTransitionKey) {
      _actionKeys.clear();
      _hoveredActionIndex.value = null;
      if (widget.contentTransitionKey != null) {
        _stepBloomController.forward(from: 0);
      }
    }
    _syncActionKeys();
  }

  @override
  void dispose() {
    _optionGestureController.dispose();
    _stepBloomController.dispose();
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
                          child: GlassOptionGestureScope(
                            controller: _optionGestureController,
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
                                gestureController: _optionGestureController,
                                contentTransitionKey:
                                    widget.contentTransitionKey,
                                child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                                          ? kConfirmationMessageActionGap
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
        ),
      ],
    );
  }

  Widget _transitionDialogContent(BuildContext context, Widget child) {
    final animation = ModalRoute.of(context)?.animation;
    final dialog = AnimatedBuilder(
      animation: _stepBloomScale,
      child: child,
      builder: (context, child) => Transform.scale(
        key: const ValueKey('skeddo-glass-alert-step-bloom'),
        scale: _stepBloomScale.value,
        alignment: Alignment.center,
        child: child,
      ),
    );
    if (animation == null) return dialog;

    return FadeTransition(
      opacity: animation,
      child: ScaleTransition(
        key: const ValueKey('skeddo-glass-alert-dialog-transition'),
        scale: animation.drive(
          Tween<double>(begin: _alertPlatterInitialScale, end: 1),
        ),
        child: dialog,
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
    // Keep the corner radius fixed as labels wrap. Taller buttons gain straight
    // vertical edges through the middle instead of turning into larger pills.
    const ShapeBorder shape = RoundedSuperellipseBorder(
      borderRadius: BorderRadius.all(
        Radius.circular(kConfirmationButtonCornerRadius),
      ),
    );

    return Semantics(
      button: true,
      label: action.label,
      onTap: action.onPressed,
      child: ValueListenableBuilder<int?>(
        valueListenable: widget.hoveredActionIndex,
        builder: (context, hoveredIndex, _) {
          final highlighted = _pressed || hoveredIndex == widget.actionIndex;
          final fill = skeddoConfirmationActionFillColor(
            context,
            highlighted: highlighted,
          );
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

class _SkeddoAlertContentMaterializeTransition extends StatelessWidget {
  const _SkeddoAlertContentMaterializeTransition({
    required this.animation,
    required this.child,
  });

  static const double _peakBlurSigma = 8;
  static const Interval _entranceContent = Interval(0.35, 1);
  static const Interval _exitContent = Interval(0.45, 1);

  final Animation<double> animation;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      child: GlassMaterializeTransition(
        animation: animation,
        scaleFrom: 1,
        contentSigma: _peakBlurSigma,
        child: child,
      ),
      builder: (context, materializedChild) {
        final progress = animation.value.clamp(0.0, 1.0).toDouble();
        final contentProgress =
            (animation.status == AnimationStatus.reverse
                    ? _exitContent
                    : _entranceContent)
                .transform(progress);
        final sigma = _peakBlurSigma * (1 - contentProgress);
        return Opacity(
          opacity: contentProgress,
          child: ImageFiltered(
            key: const ValueKey(
              'skeddo-glass-alert-content-materialize-filter',
            ),
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: materializedChild,
          ),
        );
      },
    );
  }
}

class _AlertPlatterScrollViewport extends StatefulWidget {
  const _AlertPlatterScrollViewport({
    required this.child,
    required this.actions,
    required this.actionKeys,
    required this.hoveredActionIndex,
    required this.gestureController,
    this.contentTransitionKey,
  });

  final Widget child;
  final List<GlassDialogAction> actions;
  final List<GlobalKey> actionKeys;
  final ValueNotifier<int?> hoveredActionIndex;
  final GlassOptionGestureController gestureController;
  final Object? contentTransitionKey;

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

  @override
  void didUpdateWidget(covariant _AlertPlatterScrollViewport oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.contentTransitionKey == widget.contentTransitionKey) return;
    widget.gestureController.cancel();
    _indicatorHideTimer?.cancel();
    _indicatorVisible = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_controller.hasClients) _controller.jumpTo(0);
      _syncFromController();
    });
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
    widget.gestureController.beginPointer(
      event,
      surfaceBounds: _viewportBounds,
      optionAt: _actionIndexAt,
      onCandidateChanged: _setHoveredAction,
      onSelect: (index) {
        if (index >= 0 && index < widget.actions.length) {
          widget.actions[index].onPressed();
        }
      },
      scrollController: _controller,
      rowExtent: _averageActionHeight,
    );
  }

  void _onPointerMove(PointerMoveEvent event) {
    widget.gestureController.movePointer(event);
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
    widget.gestureController.endPointer(event);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    widget.gestureController.cancelPointer(event);
  }

  Rect _viewportBounds() {
    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      return Rect.zero;
    }
    return MatrixUtils.transformRect(
      renderObject.getTransformTo(null),
      Offset.zero & renderObject.size,
    );
  }

  double get _averageActionHeight {
    final heights = widget.actionKeys
        .map((key) => key.currentContext?.findRenderObject())
        .whereType<RenderBox>()
        .where((box) => box.attached && box.hasSize)
        .map((box) => box.size.height)
        .toList();
    if (heights.isEmpty) return 48;
    return (heights.reduce((a, b) => a + b) / heights.length).clamp(36, 160);
  }

  Widget _buildContent() {
    final transitionKey = widget.contentTransitionKey;
    if (transitionKey == null) return widget.child;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        reverseDuration: const Duration(milliseconds: 280),
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          clipBehavior: Clip.none,
          children: [
            for (final previousChild in previousChildren)
              Positioned(top: 0, left: 0, right: 0, child: previousChild),
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (child, animation) =>
            _SkeddoAlertContentMaterializeTransition(
              animation: animation,
              child: child,
            ),
        child: KeyedSubtree(
          key: ValueKey<Object?>(transitionKey),
          child: widget.child,
        ),
      ),
    );
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
                child: GlassOptionGestureScrollConfiguration(
                  child: SingleChildScrollView(
                    key: const ValueKey('skeddo-glass-alert-scroll-viewport'),
                    controller: _controller,
                    physics: _canScroll
                        ? const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          )
                        : const NeverScrollableScrollPhysics(),
                    child: _buildContent(),
                  ),
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
