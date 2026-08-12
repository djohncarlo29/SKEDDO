import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:cupertino_native/cupertino_native.dart';
import '../app_theme.dart';

/// The app-wide switch.
///
/// iOS/macOS uses the native UIKit/AppKit CNSwitch.
/// Android and other platforms use [_SlidingSwitch] — a pixel-faithful
/// recreation of the former GlassSwitch geometry (70×31 track, wide pill
/// thumb) animated the same way as CupertinoSwitch, without any fragment
/// shaders so it never crashes on the Skia backend.
class AppSwitch extends StatelessWidget {
  const AppSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
    this.height = 44.0,
    this.color,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;
  final double height;
  final Color? color;

  bool get _usesNativeControl =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Widget build(BuildContext context) {
    if (_usesNativeControl) {
      return CNSwitch(
        value: value,
        enabled: enabled,
        height: height,
        color: color,
        onChanged: onChanged,
      );
    }

    final activeColor =
        color ?? CupertinoTheme.of(context).primaryColor;
    final inactiveColor =
        CupertinoDynamicColor.resolve(kTertiaryLabel, context);

    return IgnorePointer(
      ignoring: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.5,
        child: SizedBox(
          height: height,
          child: Center(
            child: _SlidingSwitch(
              value: value,
              onChanged: onChanged,
              activeColor: activeColor,
              inactiveColor: inactiveColor,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shader-free recreation of the GlassSwitch visual ─────────────────────────
//
// Track:  70 × 31 px pill
// Thumb:  (trackHeight − 2×padding) × 1.6  wide  →  43.2 × 27 px pill
// Travel: trackWidth − thumbWidth − 2×padding  →  22.8 px
// Off:    thumb sits at left = 2 px
// On:     thumb sits at left = 2 + 22.8 = 24.8 px
//
// The thumb is always white with a subtle shadow; the track color
// interpolates between inactiveColor and activeColor during the slide.
class _SlidingSwitch extends StatefulWidget {
  const _SlidingSwitch({
    required this.value,
    required this.onChanged,
    required this.activeColor,
    required this.inactiveColor,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final Color activeColor;
  final Color inactiveColor;

  @override
  State<_SlidingSwitch> createState() => _SlidingSwitchState();
}

class _SlidingSwitchState extends State<_SlidingSwitch>
    with SingleTickerProviderStateMixin {
  // ── Geometry — mirrors the former GlassSwitch dimensions exactly ───────────
  static const double _trackW = 70.0;
  static const double _trackH = 31.0;
  static const double _pad    = 2.0;
  static const double _thumbH = _trackH - _pad * 2;          // 27
  static const double _thumbW = _thumbH * 1.6;               // 43.2
  static const double _travel = _trackW - _thumbW - _pad * 2; // 22.8

  late final AnimationController _ctrl;
  late final Animation<double> _t;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: widget.value ? 1.0 : 0.0,
    );
    _t = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void didUpdateWidget(_SlidingSwitch old) {
    super.didUpdateWidget(old);
    if (widget.value != old.value) {
      widget.value ? _ctrl.forward() : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => widget.onChanged(!widget.value),
      child: AnimatedBuilder(
        animation: _t,
        builder: (_, __) {
          final progress    = _t.value;
          final trackColor  = Color.lerp(
              widget.inactiveColor, widget.activeColor, progress)!;
          final thumbLeft   = _pad + progress * _travel;

          return SizedBox(
            width: _trackW,
            height: _trackH,
            child: DecoratedBox(
              decoration: ShapeDecoration(
                color: trackColor,
                shape: SquircleStadiumBorder(radius: _trackH / 2),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned(
                    left: thumbLeft,
                    top: _pad,
                    child: SizedBox(
                      width: _thumbW,
                      height: _thumbH,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: CupertinoColors.white,
                          shape: SquircleStadiumBorder(radius: _thumbH / 2),
                          shadows: const [
                            BoxShadow(
                              color: Color(0x14000000),
                              blurRadius: 1,
                              offset: Offset(0, 3),
                            ),
                            BoxShadow(
                              color: Color(0x1A000000),
                              blurRadius: 8,
                              offset: Offset(0, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
