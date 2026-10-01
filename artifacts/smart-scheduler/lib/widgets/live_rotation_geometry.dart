import 'package:flutter/cupertino.dart';

import 'native_text_input.dart';

/// The shared, live geometry state used by widgets that need to morph between
/// portrait and landscape layouts while the native window is rotating.
///
/// Flutter does not expose a cross-platform fractional rotation callback. The
/// window's changing logical size is the authoritative signal: it is delivered
/// for the actual content geometry on every metrics update, including curved
/// or device-specific native rotation paths.
class RotationGeometryData {
  const RotationGeometryData({
    required this.windowSize,
    required this.portraitSize,
    required this.landscapeSize,
    required this.progress,
    required this.isTransitioning,
  });

  final Size windowSize;
  final Size portraitSize;
  final Size landscapeSize;

  /// 0.0 is the portrait endpoint and 1.0 is the landscape endpoint.
  final double progress;
  final bool isTransitioning;

  double lerp(double portrait, double landscape) =>
      portrait + (landscape - portrait) * progress;

  Size lerpSize(Size portrait, Size landscape) => Size(
    lerp(portrait.width, landscape.width),
    lerp(portrait.height, landscape.height),
  );
}

class LiveRotationGeometry extends StatefulWidget {
  const LiveRotationGeometry({super.key, required this.child});

  final Widget child;

  @override
  State<LiveRotationGeometry> createState() => _LiveRotationGeometryState();
}

class _LiveRotationGeometryState extends State<LiveRotationGeometry>
    with WidgetsBindingObserver {
  Size? _settledSize;
  Size? _fromSize;
  Size? _toSize;
  bool _isTransitioning = false;
  int _finalizeGeneration = 0;
  FocusNode? _focusBeforeRotation;
  TextEditingController? _nativeInputBeforeRotation;

  Size? _windowSize() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null || view.devicePixelRatio <= 0) return null;
    final physicalSize = view.physicalSize;
    if (physicalSize.isEmpty) return null;
    return physicalSize / view.devicePixelRatio;
  }

  bool _isPortrait(Size size) => size.height >= size.width;

  bool _near(Size a, Size b) =>
      (a.width - b.width).abs() < 1.5 && (a.height - b.height).abs() < 1.5;

  Size _swapped(Size size) => Size(size.height, size.width);

  void _startTransition(Size from) {
    final primaryFocus = FocusManager.instance.primaryFocus;
    _focusBeforeRotation =
        primaryFocus is FocusScopeNode ||
            primaryFocus?.context == null
        ? null
        : primaryFocus;
    _nativeInputBeforeRotation = NativeTextInput.focusedController;
    _fromSize = from;
    _toSize = _swapped(from);
    _isTransitioning = true;
    _finalizeGeneration++;
  }

  void _restoreRotationFocus() {
    final savedFocus = _focusBeforeRotation;
    final savedNativeController = _nativeInputBeforeRotation;
    _focusBeforeRotation = null;
    _nativeInputBeforeRotation = null;

    final currentFocus = FocusManager.instance.primaryFocus;
    final hasDifferentLiveFocus =
        currentFocus != null &&
        currentFocus is! FocusScopeNode &&
        currentFocus.context != null &&
        currentFocus != savedFocus;
    if (hasDifferentLiveFocus) return;

    if (savedFocus?.context != null && !savedFocus!.hasFocus) {
      savedFocus.requestFocus();
    }
    if (savedNativeController != null &&
        !NativeTextInput.isFocused(savedNativeController)) {
      NativeTextInput.focus(savedNativeController);
    }
  }

  void _scheduleFinalize(Size target) {
    final generation = ++_finalizeGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _finalizeGeneration) return;
      final live = _windowSize();
      if (live == null || !_near(live, target)) return;
      setState(() {
        _settledSize = live;
        _fromSize = null;
        _toSize = null;
        _isTransitioning = false;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _restoreRotationFocus();
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeMetrics() {
    final next = _windowSize();
    if (next == null) return;

    final settled = _settledSize;
    if (settled == null) {
      setState(() => _settledSize = next);
      return;
    }

    if (!_isTransitioning) {
      if (_isPortrait(next) != _isPortrait(settled)) {
        setState(() => _startTransition(settled));
      }
      return;
    }

    final target = _toSize;
    if (target == null) return;

    // Keep the interpolated model alive for the frame that renders the target
    // constraints. Finalization only replaces equivalent endpoint state after
    // that frame; it never delays or animates the geometry.
    if (_near(next, target)) {
      setState(() {});
      _scheduleFinalize(target);
      return;
    }

    // A second rotation can begin before the previous endpoint cleanup frame.
    // Reverse from the actual endpoint instead of from a stale intermediate
    // window size.
    if (_isPortrait(next) != _isPortrait(target)) {
      setState(() => _startTransition(target));
      return;
    }

    setState(() {});
  }

  @override
  void dispose() {
    _finalizeGeneration++;
    _focusBeforeRotation = null;
    _nativeInputBeforeRotation = null;
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  RotationGeometryData _dataFor(Size current) {
    final settled = _settledSize ?? current;
    Size? from = _fromSize;
    Size? to = _toSize;
    var transitioning = _isTransitioning;

    // MediaQuery can rebuild once before didChangeMetrics reaches this state.
    // Infer the same live transition from the settled endpoint for that frame
    // rather than falling back to a boolean orientation branch.
    if (!transitioning && _isPortrait(current) != _isPortrait(settled)) {
      from = settled;
      to = _swapped(settled);
      transitioning = true;
    }

    final portrait = from != null && _isPortrait(from)
        ? from
        : (to != null && _isPortrait(to) ? to : settled);
    final landscape = from != null && !_isPortrait(from)
        ? from
        : (to != null && !_isPortrait(to) ? to : _swapped(settled));

    if (!transitioning || from == null || to == null) {
      return RotationGeometryData(
        windowSize: current,
        portraitSize: portrait,
        landscapeSize: landscape,
        progress: _isPortrait(current) ? 0.0 : 1.0,
        isTransitioning: false,
      );
    }

    final dx = landscape.width - portrait.width;
    final dy = landscape.height - portrait.height;
    final denominator = dx * dx + dy * dy;
    final progress = denominator <= 0.001
        ? (_isPortrait(current) ? 0.0 : 1.0)
        : (((current.width - portrait.width) * dx +
                      (current.height - portrait.height) * dy) /
                  denominator)
              .clamp(0.0, 1.0);

    return RotationGeometryData(
      windowSize: current,
      portraitSize: portrait,
      landscapeSize: landscape,
      progress: progress,
      isTransitioning: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final current = MediaQuery.sizeOf(context);
    _settledSize ??= current;
    return InheritedRotationGeometry(
      data: _dataFor(current),
      child: widget.child,
    );
  }
}

class InheritedRotationGeometry extends InheritedWidget {
  const InheritedRotationGeometry({
    super.key,
    required this.data,
    required super.child,
  });

  final RotationGeometryData data;

  static RotationGeometryData of(BuildContext context) {
    final inherited = context
        .dependOnInheritedWidgetOfExactType<InheritedRotationGeometry>();
    assert(
      inherited != null,
      'LiveRotationGeometry is missing above this tree',
    );
    return inherited!.data;
  }

  static RotationGeometryData? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<InheritedRotationGeometry>()
      ?.data;

  @override
  bool updateShouldNotify(InheritedRotationGeometry oldWidget) =>
      data.windowSize != oldWidget.data.windowSize ||
      data.progress != oldWidget.data.progress ||
      data.isTransitioning != oldWidget.data.isTransitioning ||
      data.portraitSize != oldWidget.data.portraitSize ||
      data.landscapeSize != oldWidget.data.landscapeSize;
}
