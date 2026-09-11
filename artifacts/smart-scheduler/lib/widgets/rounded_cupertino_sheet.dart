import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import '../app_theme.dart'
    show
        kBackgroundColor,
        kModalBackground,
        BoundedSquircleStadiumBorder,
        kModalSheetCornerRadius,
        resolveThemeColor,
        systemSafeAreaBottomInset;

// ══════════════════════════════════════════════════════════════════════════════
// RoundedCupertinoSheet — a drop-in replacement for Flutter's built-in
// `showCupertinoSheet` with one difference: the sheet's top corners (and the
// corners revealed on the receding page behind it) use kModalSheetCornerRadius instead
// of the framework's hardcoded 12px.
//
// Every constant, curve, and animation value below is copied verbatim from
// packages/flutter/lib/src/cupertino/sheet.dart (Flutter 3.32) so the motion,
// timing, and feel are pixel-for-pixel identical to the native sheet — only
// the corner radius changes. The pieces that were private to that library
// (the down-drag-to-dismiss controller, the internal sheet-scope marker) are
// reimplemented here using only public ModalRoute/PageRoute API.
// ══════════════════════════════════════════════════════════════════════════════

const double _kTopGapRatio = 0.08;

final Animatable<Offset> _kBottomUpTween = Tween<Offset>(
  begin: const Offset(0.0, 1.0),
  end: const Offset(0.0, _kTopGapRatio),
);
final Animatable<Offset> _kBottomUpTweenWhenCoveringOtherSheet = Tween<Offset>(
  begin: const Offset(0.0, 1.0),
  end: const Offset(0.0, -0.02),
);
final Animatable<Offset> _kMidUpTween = Tween<Offset>(
  begin: Offset.zero,
  end: const Offset(0.0, -0.005),
);
// 0.068 is chosen so that the background-app top edge sits at the same
// screen-space y as the sheet-behind-Custom top edge, which lands at
//   0.08 * (1 − 0.0835) − 0.005 ≈ 0.068
// due to the scale + slide applied by _coverSheetSecondaryTransition.
final Animatable<Offset> _kTopDownTween = Tween<Offset>(
  begin: Offset.zero,
  end: const Offset(0.0, 0.068),
);
Animatable<double> _sheetOpacityTween(BuildContext context) => Tween<double>(
  begin: 0.0,
  end: CupertinoTheme.brightnessOf(context) == Brightness.dark ? 0.13 : 0.10,
);

const double _kMinFlingVelocity = 2.0;
const Duration _kDroppedSheetDragAnimationDuration = Duration(
  milliseconds: 300,
);
const double _kSheetScaleFactor = 0.0835;
final Animatable<double> _kScaleTween = Tween<double>(
  begin: 1.0,
  end: 1.0 - _kSheetScaleFactor,
);

/// Shows an iOS-style sheet identical to [showCupertinoSheet], except its
/// corners use [kModalSheetCornerRadius] (from app_theme.dart) instead of the
/// framework's hardcoded 12px.
Future<T?> showRoundedCupertinoSheet<T>({
  required BuildContext context,
  required WidgetBuilder pageBuilder,
  bool enableDrag = true,
}) {
  return Navigator.of(context, rootNavigator: true).push<T>(
    RoundedCupertinoSheetRoute<T>(builder: pageBuilder, enableDrag: enableDrag),
  );
}

/// Shows a Cupertino popup while keeping the persistent system-navigation
/// region owned by the popup instead of revealing the page underneath it.
///
/// [fullScreen] is used by custom preview surfaces that already lay themselves
/// out across the available route. Standard action sheets remain bottom-aligned.
Future<T?> showSafeCupertinoModalPopup<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool fullScreen = false,
}) {
  return showCupertinoModalPopup<T>(
    context: context,
    builder: (popupContext) => _SafePopupRouteSurface(
      safeBottom: systemSafeAreaBottomInset(popupContext),
      fullScreen: fullScreen,
      child: builder(popupContext),
    ),
  );
}

/// Shows a Cupertino alert while covering the transparent system-navigation
/// region with the modal surface color.
Future<T?> showSafeCupertinoDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
}) {
  return showCupertinoDialog<T>(
    context: context,
    builder: (dialogContext) => _SafePopupRouteSurface(
      safeBottom: systemSafeAreaBottomInset(dialogContext),
      child: builder(dialogContext),
    ),
  );
}

class _SafePopupRouteSurface extends StatelessWidget {
  const _SafePopupRouteSurface({
    required this.safeBottom,
    required this.child,
    this.fullScreen = false,
  });

  final double safeBottom;
  final Widget child;
  final bool fullScreen;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = resolveThemeColor(kBackgroundColor, context);
    return Stack(
      fit: StackFit.expand,
      children: [
        if (safeBottom > 0)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: safeBottom,
            child: ColoredBox(color: surfaceColor),
          ),
        if (fullScreen)
          Positioned.fill(child: child)
        else
          Align(alignment: Alignment.bottomCenter, child: child),
      ],
    );
  }
}

/// Route for displaying an iOS sheet styled page with
/// [kModalSheetCornerRadius] corners.
/// See [showRoundedCupertinoSheet].
class RoundedCupertinoSheetRoute<T> extends PageRoute<T>
    with _RoundedSheetRouteTransitionMixin<T> {
  RoundedCupertinoSheetRoute({
    super.settings,
    required this.builder,
    this.enableDrag = true,
  });

  final WidgetBuilder builder;

  @override
  final bool enableDrag;

  @override
  Widget buildContent(BuildContext context) {
    // Build a single merged MediaQueryData that:
    //   (a) removes top and bottom padding — same as the original
    //       MediaQuery.removePadding(removeTop: true, removeBottom: true) call,
    //   (b) overrides gestureSettings to lock touchSlop to Flutter's standard
    //       kTouchSlop (18 dp).
    //
    // WHY (a) and (b) must be merged into one MediaQuery node:
    //   MediaQuery.removePadding works by inserting its own MediaQuery
    //   descendant.  If we then insert a second MediaQuery inside it (computed
    //   from the original context before removePadding ran), the inner node
    //   carries the full original top/bottom padding and overwrites the
    //   removePadding, pushing the sheet header down.  A single copyWith that
    //   does both operations avoids the layering problem entirely.
    //
    // WHY gestureSettings must be overridden (b):
    //   On Android full-screen / gesture-navigation mode the OS reports a low
    //   effective touchSlop (≈4–8 dp) via gestureSettings so it can quickly
    //   disambiguate OS navigation swipes from app touches.  Every
    //   GestureRecognizer that reads gestureSettings from the widget tree
    //   inherits this value — including TapAndDragGestureRecognizer inside
    //   CupertinoTextField (set via RawGestureDetector.didChangeDependencies).
    //   A 5 dp finger drift (common during gesture-navigation disambiguation)
    //   exceeds the 4–8 dp threshold and causes TapAndDragGestureRecognizer to
    //   enter drag mode internally, independent of any competing recognizers in
    //   the arena.  Once in drag mode it treats the tap-down position as a drag
    //   anchor and the old cursor position (end-of-text) as the endpoint —
    //   producing "select from tapped location to end of text".
    //   Locking to 18 dp means micro-movements can never cross the threshold.
    //
    // Drag-to-dismiss is unaffected: _RoundedDownGestureDetector sits above
    // this MediaQuery and sets gestureSettings directly on its recognizer.
    // Sheet scrolling is also unaffected: 18 dp is Flutter's standard default.
    final MediaQueryData original = MediaQuery.of(context);
    final MediaQueryData mqData = original.copyWith(
      // The route owns the persistent bottom inset below. Keep it out of the
      // sheet's descendant MediaQuery so nested SafeAreas cannot add it a
      // second time and make the inset dependent on page content.
      padding: original.padding.copyWith(top: 0.0, bottom: 0.0),
      gestureSettings: const DeviceGestureSettings(touchSlop: kTouchSlop),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          // Paint the modal surface through the physical bottom independently
          // from the page viewport. This layer is translated with the route,
          // so it covers the bottom without exposing a strip from the route
          // underneath.
          child: ColoredBox(
            color: resolveThemeColor(kModalBackground, context),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // The route rests 8% below the viewport. Keep the authored
                // page at the visible 92% so its scrollable content ends at
                // the physical bottom instead of extending below the clip.
                final double visiblePageHeight =
                    constraints.maxHeight * (1.0 - _kTopGapRatio);
                return Align(
                  alignment: Alignment.topCenter,
                  child: SizedBox(
                    width: constraints.maxWidth,
                    height: visiblePageHeight,
                    child: MediaQuery(
                      data: mqData,
                      child: CupertinoUserInterfaceLevel(
                        data: CupertinoUserInterfaceLevelData.elevated,
                        // Build the page under the cleaned MediaQuery above.
                        // Calling builder(context) here would pass the route's
                        // original context and restore SafeArea padding.
                        child: _RoundedSheetScope(
                          child: Builder(builder: builder),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  /// Whether a rounded sheet route already exists above the given context.
  static bool hasParentSheet(BuildContext context) {
    return _RoundedSheetScope.maybeOf(context) != null;
  }

  /// Pops the entire [RoundedCupertinoSheetRoute], if one exists in the stack.
  static void popSheet(BuildContext context) {
    if (hasParentSheet(context)) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  @override
  Color? get barrierColor => CupertinoColors.transparent;

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get maintainState => true;

  @override
  bool get opaque => false;
}

class _RoundedSheetScope extends InheritedWidget {
  const _RoundedSheetScope({required super.child});

  static _RoundedSheetScope? maybeOf(BuildContext context) {
    return context.getInheritedWidgetOfExactType<_RoundedSheetScope>();
  }

  @override
  bool updateShouldNotify(_RoundedSheetScope oldWidget) => false;
}

/// Marks the part of a sheet where the interactive down-drag-to-dismiss
/// gesture is allowed to begin.  Keeping this as a render target (rather than
/// using a screen-space rectangle) means the route stays correct when a sheet
/// is embedded, padded, or laid out at a different size.
class RoundedCupertinoSheetHeader extends SingleChildRenderObjectWidget {
  const RoundedCupertinoSheetHeader({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RoundedCupertinoSheetHeaderRenderBox();
}

class _RoundedCupertinoSheetHeaderRenderBox extends RenderProxyBox {
  @override
  bool hitTestSelf(Offset position) => true;
}

mixin _RoundedSheetRouteTransitionMixin<T> on PageRoute<T> {
  @protected
  Widget buildContent(BuildContext context);

  @override
  Duration get transitionDuration => const Duration(milliseconds: 500);

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      _RoundedSheetTransition.delegateTransition;

  bool get enableDrag;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return buildContent(context);
  }

  static _RoundedDownGestureController<T> _startPopGesture<T>(
    ModalRoute<T> route,
  ) {
    return _RoundedDownGestureController<T>(
      navigator: route.navigator!,
      getIsCurrent: () => route.isCurrent,
      getIsActive: () => route.isActive,
      // ignore: invalid_use_of_protected_member
      controller: route.controller!,
    );
  }

  static Widget buildPageTransitions<T>(
    ModalRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
    bool enableDrag,
  ) {
    final bool linearTransition = route.popGestureInProgress;
    return _RoundedSheetTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: linearTransition,
      child: _RoundedDownGestureDetector<T>(
        enabledCallback: () => enableDrag,
        onStartPopGesture: () => _startPopGesture<T>(route),
        child: child,
      ),
    );
  }

  @override
  bool canTransitionTo(TransitionRoute<dynamic> nextRoute) {
    return nextRoute is _RoundedSheetRouteTransitionMixin;
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return buildPageTransitions<T>(
      this,
      context,
      animation,
      secondaryAnimation,
      child,
      enableDrag,
    );
  }
}

/// Mirrors CupertinoSheetTransition from the Flutter framework, but with
/// kModalSheetCornerRadius corners instead of the hardcoded 12px.
class _RoundedSheetTransition extends StatefulWidget {
  const _RoundedSheetTransition({
    required this.primaryRouteAnimation,
    required this.secondaryRouteAnimation,
    required this.child,
    required this.linearTransition,
  });

  final Animation<double> primaryRouteAnimation;
  final Animation<double> secondaryRouteAnimation;
  final Widget child;
  final bool linearTransition;

  /// Delegated to the route below a [RoundedCupertinoSheetRoute] so it
  /// animates/rounds off correctly while covered by the sheet.
  static Widget delegateTransition(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    bool allowSnapshotting,
    Widget? child,
  ) {
    if (RoundedCupertinoSheetRoute.hasParentSheet(context)) {
      return _delegatedCoverSheetSecondaryTransition(
        context,
        secondaryAnimation,
        child,
      );
    }
    final bool linear = Navigator.of(context).userGestureInProgress;

    final Curve curve = linear ? Curves.linear : Curves.linearToEaseOut;
    final Curve reverseCurve = linear ? Curves.linear : Curves.easeInToLinear;
    final CurvedAnimation curvedAnimation = CurvedAnimation(
      curve: curve,
      reverseCurve: reverseCurve,
      parent: secondaryAnimation,
    );

    final Animation<double> opacityAnimation = curvedAnimation.drive(
      _sheetOpacityTween(context),
    );
    final Animation<Offset> slideAnimation = curvedAnimation.drive(
      _kTopDownTween,
    );
    final Animation<double> scaleAnimation = curvedAnimation.drive(
      _kScaleTween,
    );
    curvedAnimation.dispose();

    // The receding app must always become darker when a sheet opens.  A light
    // tint in Dark Mode makes black surfaces lighter and reverses the intended
    // modal hierarchy.
    const Color overlayColor = Color(0xFF000000);

    // Use ColorFiltered+srcATop so the dim tint only affects pixels where the
    // sheet content has non-zero alpha.  This prevents the dark overlay from
    // bleeding into the transparent status-bar gap above the sheet.
    final Widget? contrastedChild =
        child != null && !secondaryAnimation.isDismissed
        ? AnimatedBuilder(
            animation: opacityAnimation,
            child: child,
            builder: (BuildContext context, Widget? child) {
              return ColorFiltered(
                colorFilter: ColorFilter.mode(
                  overlayColor.withValues(alpha: opacityAnimation.value),
                  BlendMode.srcATop,
                ),
                child: child,
              );
            },
          )
        : child;

    return SlideTransition(
      position: slideAnimation,
      child: ScaleTransition(
        scale: scaleAnimation,
        filterQuality: FilterQuality.medium,
        alignment: Alignment.topCenter,
        child: ClipPath(
          clipper: ShapeBorderClipper(
            shape: const BoundedSquircleStadiumBorder(
              radius: kModalSheetCornerRadius,
              topOnly: true,
            ),
          ),
          child: contrastedChild,
        ),
      ),
    );
  }

  static Widget _delegatedCoverSheetSecondaryTransition(
    BuildContext context,
    Animation<double> secondaryAnimation,
    Widget? child,
  ) {
    const Curve curve = Curves.linearToEaseOut;
    const Curve reverseCurve = Curves.easeInToLinear;
    final CurvedAnimation curvedAnimation = CurvedAnimation(
      curve: curve,
      reverseCurve: reverseCurve,
      parent: secondaryAnimation,
    );

    final Animation<Offset> slideAnimation = curvedAnimation.drive(
      _kMidUpTween,
    );
    final Animation<double> scaleAnimation = curvedAnimation.drive(
      _kScaleTween,
    );
    final Animation<double> opacityAnimation = curvedAnimation.drive(
      _sheetOpacityTween(context),
    );
    curvedAnimation.dispose();

    // Mirror the dark-overlay that the main-app layer receives when a sheet
    // is pushed over it — opacity is driven by secondaryAnimation so it
    // tracks the user's finger during a drag-to-dismiss gesture.
    // ColorFiltered+srcATop: tint only pixels where the child has alpha > 0,
    // so the transparent gap above the sheet is never dimmed.
    final Widget? coveredChild =
        child != null && !secondaryAnimation.isDismissed
        ? AnimatedBuilder(
            animation: opacityAnimation,
            child: child,
            builder: (BuildContext context, Widget? child) {
              return ColorFiltered(
                colorFilter: ColorFilter.mode(
                  const Color(
                    0xFF000000,
                  ).withValues(alpha: opacityAnimation.value),
                  BlendMode.srcATop,
                ),
                child: child,
              );
            },
          )
        : child;

    return ClipRect(
      child: SlideTransition(
        position: slideAnimation,
        transformHitTests: false,
        child: ScaleTransition(
          scale: scaleAnimation,
          filterQuality: FilterQuality.medium,
          alignment: Alignment.topCenter,
          child: ClipPath(
            clipper: ShapeBorderClipper(
              shape: const BoundedSquircleStadiumBorder(
                radius: kModalSheetCornerRadius,
                topOnly: true,
              ),
            ),
            child: coveredChild,
          ),
        ),
      ),
    );
  }

  @override
  State<_RoundedSheetTransition> createState() =>
      _RoundedSheetTransitionState();
}

class _RoundedSheetTransitionState extends State<_RoundedSheetTransition> {
  late Animation<Offset> _secondaryPositionAnimation;
  late Animation<double> _secondaryScaleAnimation;
  late Animation<double> _secondaryOpacityAnimation;

  CurvedAnimation? _primaryPositionCurve;
  CurvedAnimation? _secondaryPositionCurve;

  @override
  void initState() {
    super.initState();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarBrightness: Brightness.dark,
        statusBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _disposeCurve();
    _setupAnimation();
  }

  @override
  void didUpdateWidget(covariant _RoundedSheetTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.primaryRouteAnimation != widget.primaryRouteAnimation ||
        oldWidget.secondaryRouteAnimation != widget.secondaryRouteAnimation) {
      _disposeCurve();
      _setupAnimation();
    }
  }

  @override
  void dispose() {
    _disposeCurve();
    super.dispose();
  }

  void _setupAnimation() {
    _primaryPositionCurve = CurvedAnimation(
      curve: Curves.fastEaseInToSlowEaseOut,
      reverseCurve: Curves.fastEaseInToSlowEaseOut.flipped,
      parent: widget.primaryRouteAnimation,
    );
    _secondaryPositionCurve = CurvedAnimation(
      curve: Curves.linearToEaseOut,
      reverseCurve: Curves.easeInToLinear,
      parent: widget.secondaryRouteAnimation,
    );
    _secondaryPositionAnimation = _secondaryPositionCurve!.drive(_kMidUpTween);
    _secondaryScaleAnimation = _secondaryPositionCurve!.drive(_kScaleTween);
    _secondaryOpacityAnimation = _secondaryPositionCurve!.drive(
      _sheetOpacityTween(context),
    );
  }

  void _disposeCurve() {
    _primaryPositionCurve?.dispose();
    _secondaryPositionCurve?.dispose();
    _primaryPositionCurve = null;
    _secondaryPositionCurve = null;
  }

  Widget _coverSheetPrimaryTransition(
    BuildContext context,
    Animation<double> animation,
    bool linearTransition,
    Widget? child,
  ) {
    final Animatable<Offset> offsetTween =
        RoundedCupertinoSheetRoute.hasParentSheet(context)
        ? _kBottomUpTweenWhenCoveringOtherSheet
        : _kBottomUpTween;

    final CurvedAnimation curvedAnimation = CurvedAnimation(
      parent: animation,
      curve: linearTransition ? Curves.linear : Curves.fastEaseInToSlowEaseOut,
      reverseCurve: linearTransition
          ? Curves.linear
          : Curves.fastEaseInToSlowEaseOut.flipped,
    );

    final Animation<Offset> positionAnimation = curvedAnimation.drive(
      offsetTween,
    );
    curvedAnimation.dispose();

    return SlideTransition(position: positionAnimation, child: child);
  }

  Widget _coverSheetSecondaryTransition(
    Animation<double> secondaryAnimation,
    Widget? child,
  ) {
    // Wrap child in an overlay that dims as a new sheet slides in above it,
    // mirroring the dark-scrim the main app receives.  Driven by the same
    // curve as scale/slide so it tracks the user's finger during drag.
    // ColorFiltered+srcATop: tint only pixels where the child has alpha > 0,
    // so the transparent gap above the sheet is never dimmed.
    final Widget? dimmedChild = child != null && !secondaryAnimation.isDismissed
        ? AnimatedBuilder(
            animation: _secondaryOpacityAnimation,
            child: child,
            builder: (BuildContext context, Widget? child) {
              return ColorFiltered(
                colorFilter: ColorFilter.mode(
                  const Color(
                    0xFF000000,
                  ).withValues(alpha: _secondaryOpacityAnimation.value),
                  BlendMode.srcATop,
                ),
                child: child,
              );
            },
          )
        : child;

    return ClipRect(
      child: SlideTransition(
        position: _secondaryPositionAnimation,
        transformHitTests: false,
        child: ScaleTransition(
          scale: _secondaryScaleAnimation,
          filterQuality: FilterQuality.medium,
          alignment: Alignment.topCenter,
          child: ClipPath(
            clipper: ShapeBorderClipper(
              shape: const BoundedSquircleStadiumBorder(
                radius: kModalSheetCornerRadius,
                topOnly: true,
              ),
            ),
            child: dimmedChild,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: _coverSheetSecondaryTransition(
        widget.secondaryRouteAnimation,
        _coverSheetPrimaryTransition(
          context,
          widget.primaryRouteAnimation,
          widget.linearTransition,
          ClipPath(
            clipper: ShapeBorderClipper(
              shape: const BoundedSquircleStadiumBorder(
                radius: kModalSheetCornerRadius,
                topOnly: true,
              ),
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _RoundedDownGestureDetector<T> extends StatefulWidget {
  const _RoundedDownGestureDetector({
    required this.enabledCallback,
    required this.onStartPopGesture,
    required this.child,
  });

  final Widget child;
  final ValueGetter<bool> enabledCallback;
  final ValueGetter<_RoundedDownGestureController<T>> onStartPopGesture;

  @override
  State<_RoundedDownGestureDetector<T>> createState() =>
      _RoundedDownGestureDetectorState<T>();
}

class _RoundedDownGestureDetectorState<T>
    extends State<_RoundedDownGestureDetector<T>> {
  _RoundedDownGestureController<T>? _downGestureController;
  late VerticalDragGestureRecognizer _recognizer;

  @override
  void initState() {
    super.initState();
    _recognizer = VerticalDragGestureRecognizer(debugOwner: this)
      // Deliberately use the framework's default recognizer settings. The
      // gesture arena, rather than a render-tree hit-test gate, decides
      // whether the sheet or an editable/scrollable child owns the pointer.
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    if (_downGestureController != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_downGestureController?.navigator.mounted ?? false) {
          _downGestureController?.navigator.didStopUserGesture();
        }
        _downGestureController = null;
      });
    }
    super.dispose();
  }

  void _handleDragStart(DragStartDetails details) {
    assert(mounted);
    assert(_downGestureController == null);
    _downGestureController = widget.onStartPopGesture();
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    assert(mounted);
    assert(_downGestureController != null);
    _downGestureController!.dragUpdate(
      // Divide by the visible sheet height, exactly as the framework does.
      details.primaryDelta! /
          (context.size!.height - (context.size!.height * _kTopGapRatio)),
    );
  }

  void _handleDragEnd(DragEndDetails details) {
    assert(mounted);
    assert(_downGestureController != null);
    _downGestureController!.dragEnd(
      details.velocity.pixelsPerSecond.dy / context.size!.height,
    );
    _downGestureController = null;
  }

  void _handleDragCancel() {
    assert(mounted);
    _downGestureController?.dragEnd(0.0);
    _downGestureController = null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!widget.enabledCallback()) return;
    // Match Flutter's Cupertino sheet: add the recognizer on pointer-down and
    // let the gesture arena arbitrate against child gestures.
    _recognizer.addPointer(event);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _handlePointerDown,
      behavior: HitTestBehavior.translucent,
      child: widget.child,
    );
  }
}

class _RoundedDownGestureController<T> {
  _RoundedDownGestureController({
    required this.navigator,
    required this.controller,
    required this.getIsActive,
    required this.getIsCurrent,
  }) {
    navigator.didStartUserGesture();
  }

  final AnimationController controller;
  final NavigatorState navigator;
  final ValueGetter<bool> getIsActive;
  final ValueGetter<bool> getIsCurrent;

  void dragUpdate(double delta) {
    controller.value -= delta;
  }

  void dragEnd(double velocity) {
    const Curve animationCurve = Curves.easeOut;
    final bool isCurrent = getIsCurrent();
    final bool animateForward;

    if (!isCurrent) {
      animateForward = getIsActive();
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.52;
    }

    if (animateForward) {
      controller.animateTo(
        1.0,
        duration: _kDroppedSheetDragAnimationDuration,
        curve: animationCurve,
      );
    } else {
      if (isCurrent) {
        final NavigatorState rootNavigator = Navigator.of(
          navigator.context,
          rootNavigator: true,
        );
        // Use maybePop so a descendant PopScope can hold the sheet open long
        // enough to ask about unsaved changes. A direct pop bypasses that
        // route-level veto and makes a downward sheet drag destructive.
        rootNavigator.maybePop();
      }

      // If maybePop was vetoed by an unsaved-change PopScope, the route is
      // still current and the controller is sitting at the finger's partial
      // drag value. Always settle it back to 1.0, the fully-open position, in
      // that case so the confirmation overlay never sits above a dismissed
      // sheet. If the route was actually popped, isCurrent becomes false and
      // the normal dismissal animation remains untouched.
      if (getIsCurrent() && controller.value < 1.0) {
        controller.animateTo(
          1.0,
          duration: _kDroppedSheetDragAnimationDuration,
          curve: animationCurve,
        );
      }
    }

    if (controller.isAnimating) {
      late AnimationStatusListener animationStatusCallback;
      animationStatusCallback = (AnimationStatus status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(animationStatusCallback);
      };
      controller.addStatusListener(animationStatusCallback);
    } else {
      navigator.didStopUserGesture();
    }
  }
}
