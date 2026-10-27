import 'package:flutter/widgets.dart';

/// Applies the endpoint push used by the native Liquid Glass slider icons.
///
/// Keep this in the app layer: the app intentionally uses the untouched
/// hosted liquid_glass_easy 5.0.0 package.
class LiquidGlassSliderEdgeIcon extends StatelessWidget {
  final double value;
  final bool isMinimum;
  final Widget child;

  const LiquidGlassSliderEdgeIcon({
    super.key,
    required this.value,
    required this.isMinimum,
    required this.child,
  });

  static const double _pressureRange = 0.05;
  static const double _pushDistance = 10;
  static const double _scaleReduction = 0.16;

  double get pressure {
    final position = value.clamp(0.0, 1.0).toDouble();
    final rawPressure = isMinimum
        ? (_pressureRange - position) / _pressureRange
        : (position - (1.0 - _pressureRange)) / _pressureRange;
    return rawPressure.clamp(0.0, 1.0).toDouble();
  }

  double get translationX => (isMinimum ? -1 : 1) * pressure * _pushDistance;

  double get scale => 1 - pressure * _scaleReduction;

  @override
  Widget build(BuildContext context) => Transform.translate(
    offset: Offset(translationX, 0),
    child: Transform.scale(scale: scale, child: child),
  );
}
