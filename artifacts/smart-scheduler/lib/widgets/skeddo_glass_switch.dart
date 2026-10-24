import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassQuality, LiquidRoundedRectangle;
import 'package:flutter_liquid_glass_widgets/widgets/shared/glass_effect.dart';

import 'skeddo_glass_settings.dart';

/// SKEDDO's non-native switch.
///
/// The package's GlassSwitch currently hardcodes its thumb's glass settings
/// and blur to zero. This keeps the same switch geometry and lift animation,
/// while sending the thumb through the shared renderer when available.
class SkeddoGlassSwitch extends StatefulWidget {
  const SkeddoGlassSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeColor,
    this.inactiveColor,
    this.width = 70,
    this.height = 31,
    this.enableHaptics = true,
    this.focusNode,
    this.autofocus = false,
    this.semanticLabel,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? activeColor;
  final Color? inactiveColor;
  final double width;
  final double height;
  final bool enableHaptics;
  final FocusNode? focusNode;
  final bool autofocus;
  final String? semanticLabel;

  @override
  State<SkeddoGlassSwitch> createState() => _SkeddoGlassSwitchState();
}

class _SkeddoGlassSwitchState extends State<SkeddoGlassSwitch>
    with TickerProviderStateMixin {
  static const _defaultThumbShadowColor = Color(0x33000000);

  late final AnimationController _positionController;
  late final AnimationController _thicknessController;
  late final Animation<double> _positionAnimation;
  late final Animation<double> _thicknessAnimation;
  late bool _isMovingForward;

  bool _isDragging = false;
  double _dragStartX = 0;
  double _dragStartPosition = 0;
  bool _dragAbandonedExternally = false;
  bool _justEndedDrag = false;
  bool _dragMidpointHapticFired = false;
  bool _dragWasAboveMidpoint = false;

  double get _thumbTravelDistance {
    final thumbSize = widget.height - 4;
    final thumbWidth = thumbSize * 1.6;
    return widget.width - thumbWidth - 4;
  }

  @override
  void initState() {
    super.initState();
    _positionController = AnimationController(
      duration: const Duration(milliseconds: 380),
      vsync: this,
      value: widget.value ? 1 : 0,
    );
    _thicknessController = AnimationController(
      duration: const Duration(milliseconds: 380),
      vsync: this,
    );
    _positionAnimation = CurvedAnimation(
      parent: _positionController,
      curve: Curves.easeInOutCubic,
      reverseCurve: Curves.easeInOutCubic,
    );
    _thicknessAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 0,
          end: 1,
        ).chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 45,
      ),
      TweenSequenceItem(
        tween: Tween<double>(
          begin: 1,
          end: 0,
        ).chain(CurveTween(curve: Curves.easeInOutQuad)),
        weight: 55,
      ),
    ]).animate(_thicknessController);
    _isMovingForward = widget.value;
  }

  @override
  void didUpdateWidget(covariant SkeddoGlassSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value == oldWidget.value) return;

    if (_isDragging) {
      _isDragging = false;
      _dragAbandonedExternally = true;
    }
    _isMovingForward = widget.value;
    if (widget.value) {
      unawaited(_positionController.forward());
    } else {
      unawaited(_positionController.reverse());
    }

    final justEndedDrag = _justEndedDrag;
    _justEndedDrag = false;
    if (!justEndedDrag) {
      if (_thicknessController.value >= 0.99) {
        _thicknessController.value = 0;
      }
      final distance = widget.value
          ? 1 - _positionController.value
          : _positionController.value;
      final durationMs = (380 * distance).round();
      if (durationMs > 0) {
        unawaited(
          _thicknessController.animateTo(
            1,
            duration: Duration(milliseconds: durationMs),
            curve: Curves.easeIn,
          ),
        );
      } else {
        _thicknessController.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _positionController.dispose();
    _thicknessController.dispose();
    super.dispose();
  }

  void _handleTap() => widget.onChanged(!widget.value);

  void _activateFromKeyboard() {
    _handleTap();
    if (widget.enableHaptics) unawaited(HapticFeedback.lightImpact());
  }

  void _onTapDown(TapDownDetails details) {
    if (_thicknessController.value >= 0.99) {
      _thicknessController.value = 0;
    }
    _dragAbandonedExternally = false;
    unawaited(
      _thicknessController.animateTo(
        0.45,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
      ),
    );
  }

  void _onTapUp(TapUpDetails details) {
    if (_isDragging) return;
    if (widget.enableHaptics) unawaited(HapticFeedback.lightImpact());
    _handleTap();
  }

  void _onTapCancel() {
    if (!_isDragging) {
      unawaited(_thicknessController.forward(from: _thicknessController.value));
    }
  }

  void _onDragStart(DragStartDetails details) {
    _positionController.stop();
    _dragStartX = details.localPosition.dx;
    _dragStartPosition = _positionController.value;
    _dragAbandonedExternally = false;
    setState(() => _isDragging = true);
    _thicknessController.stop();
    if (_thicknessController.value >= 0.99) {
      _thicknessController.value = 0;
    }
    if ((_thicknessController.value - 0.45).abs() > 0.01) {
      unawaited(
        _thicknessController.animateTo(
          0.45,
          duration: const Duration(milliseconds: 80),
        ),
      );
    } else {
      _thicknessController.value = 0.45;
    }
    _dragMidpointHapticFired = false;
    _dragWasAboveMidpoint = _positionController.value >= 0.5;
  }

  void _onDragCancel() {
    setState(() => _isDragging = false);
    unawaited(_thicknessController.forward(from: _thicknessController.value));
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_isDragging) return;
    final travel = _thumbTravelDistance;
    if (travel <= 0) return;
    final delta = details.localPosition.dx - _dragStartX;
    _positionController.value = (_dragStartPosition + delta / travel).clamp(
      0.0,
      1.0,
    );

    if (widget.enableHaptics && !_dragMidpointHapticFired) {
      final aboveMidpoint = _positionController.value >= 0.5;
      if (aboveMidpoint != _dragWasAboveMidpoint) {
        unawaited(HapticFeedback.lightImpact());
        _dragMidpointHapticFired = true;
      }
      _dragWasAboveMidpoint = aboveMidpoint;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    if (_dragAbandonedExternally) {
      _dragAbandonedExternally = false;
      return;
    }
    if (!_isDragging) return;

    final position = _positionController.value;
    final velocity = details.primaryVelocity ?? 0;
    final shouldBeOn = velocity.abs() > 200 ? velocity > 0 : position >= 0.5;

    _isMovingForward = shouldBeOn;
    setState(() => _isDragging = false);
    _justEndedDrag = true;
    if (shouldBeOn) {
      unawaited(_positionController.forward());
    } else {
      unawaited(_positionController.reverse());
    }
    unawaited(_thicknessController.forward(from: _thicknessController.value));

    if (widget.enableHaptics &&
        !_dragMidpointHapticFired &&
        shouldBeOn != widget.value) {
      unawaited(HapticFeedback.lightImpact());
    }
    _dragMidpointHapticFired = false;
    if (shouldBeOn != widget.value) widget.onChanged(shouldBeOn);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = CupertinoTheme.brightnessOf(context);
    final isDark = brightness == Brightness.dark;
    final quality = !kIsWeb && ui.ImageFilter.isShaderFilterSupported
        ? GlassQuality.premium
        : GlassQuality.standard;
    final inactiveTrackColor =
        widget.inactiveColor ??
        (isDark ? const Color(0x33FFFFFF) : const Color(0xFFC5C5C6));
    final activeTrackColor = widget.activeColor ?? CupertinoColors.systemGreen;

    return Semantics(
      container: true,
      label: widget.semanticLabel ?? 'Switch',
      button: true,
      toggled: widget.value,
      onTap: _handleTap,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          focusNode: widget.focusNode,
          autofocus: widget.autofocus,
          shortcuts: const <ShortcutActivator, Intent>{
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
          },
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activateFromKeyboard();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: _onTapDown,
            onTapUp: _onTapUp,
            onTapCancel: _onTapCancel,
            onHorizontalDragCancel: _onDragCancel,
            onHorizontalDragStart: _onDragStart,
            onHorizontalDragUpdate: _onDragUpdate,
            onHorizontalDragEnd: _onDragEnd,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: Listenable.merge([
                  _positionController,
                  _thicknessController,
                ]),
                builder: (context, child) {
                  final position = _positionAnimation.value;
                  final thickness = _thicknessAnimation.value;
                  final scale = 1 - thickness * 0.08;
                  final blendedColor = Color.lerp(
                    inactiveTrackColor,
                    activeTrackColor,
                    position,
                  )!;
                  final specularTop = Color.lerp(
                    activeTrackColor,
                    CupertinoColors.white,
                    0.25,
                  )!;
                  final track = Container(
                    width: widget.width,
                    height: widget.height,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(blendedColor, specularTop, position)!,
                          blendedColor,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(widget.height / 2),
                      boxShadow: position > 0.01
                          ? [
                              BoxShadow(
                                color: activeTrackColor.withValues(
                                  alpha: 0.35 * position,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 1),
                              ),
                            ]
                          : null,
                    ),
                  );
                  final thumbSize = widget.height - 4;
                  final thumbWidth = thumbSize * 1.6;
                  final thumbTravelDistance = widget.width - thumbWidth - 4;
                  final verticalExpansion = thickness * 10;
                  final leadingStretch = thickness * 16;
                  final thumbOffset = 2 + thumbTravelDistance * position;
                  final anchorOffset = _isDragging
                      ? leadingStretch / 2
                      : (_isMovingForward ? 0.0 : leadingStretch);
                  final thumb = Positioned(
                    left: thumbOffset - anchorOffset,
                    top: 2 - verticalExpansion,
                    child: Transform.scale(
                      scale: scale * (1 + thickness * 0.1),
                      child: _buildThumb(
                        thumbSize: thumbSize,
                        transition: thickness,
                        leadingStretch: leadingStretch,
                        verticalExpansion: verticalExpansion,
                        anchorOffset: anchorOffset,
                        isDark: isDark,
                        quality: quality,
                      ),
                    ),
                  );
                  return SizedBox(
                    width: widget.width,
                    height: widget.height,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [track, thumb],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThumb({
    required double thumbSize,
    required double transition,
    required double leadingStretch,
    required double verticalExpansion,
    required double anchorOffset,
    required bool isDark,
    required GlassQuality quality,
  }) {
    final thumbWidth = thumbSize * 1.6;
    final thumbHeight = thumbSize;
    final totalWidth = thumbWidth + leadingStretch;
    final totalHeight = thumbHeight + verticalExpansion * 2;
    final isStandard = quality == GlassQuality.standard;

    final materialThumb = Opacity(
      opacity: (1 - transition * 1.2).clamp(0.0, 1.0),
      child: Container(
        width: thumbWidth,
        height: thumbHeight,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          borderRadius: BorderRadius.circular(thumbHeight / 2),
          boxShadow: [
            BoxShadow(
              color: _defaultThumbShadowColor.withValues(
                alpha: 0.2 * (1 - transition),
              ),
              blurRadius: 0,
              offset: const Offset(0, 2),
            ),
          ],
        ),
      ),
    );

    return SizedBox(
      width: totalWidth,
      height: totalHeight,
      child: GlassEffect(
        shape: LiquidRoundedRectangle(borderRadius: totalHeight / 2),
        settings: skeddoSwitchThumbGlassSettingsFor(
          isDark ? Brightness.dark : Brightness.light,
        ),
        quality: quality,
        interactionIntensity: transition,
        rimThickness: isStandard ? (isDark ? 0.5 : 0.7) : 0.5,
        ambientRim: isStandard ? (isDark ? 0.08 : 0.15) : 0.1,
        baseAlphaMultiplier: isStandard ? (isDark ? 0.0 : 0.04) : 0.2,
        edgeAlphaMultiplier: isStandard ? (isDark ? 0.15 : 0.28) : 0.4,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            const Positioned.fill(child: ColoredBox(color: Color(0x00000000))),
            Positioned(left: anchorOffset, child: materialThumb),
          ],
        ),
      ),
    );
  }
}
