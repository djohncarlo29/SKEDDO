import 'package:flutter/cupertino.dart';
import 'package:flutter_sficon/flutter_sficon.dart';

/// Renders an SF Symbol at its authored size regardless of the current
/// Dynamic Type / text-scaling setting.
///
/// flutter_sficon implements SF Symbols with a [Text] widget, so the package
/// otherwise inherits the app's text scaler.  Keep this boundary local to
/// icon rendering so regular app text continues to respect the user's
/// appearance setting.
class FixedSFIcon extends StatelessWidget {
  const FixedSFIcon(
    this.icon, {
    super.key,
    this.fontSize = 24,
    this.fontWeight = FontWeight.normal,
    this.color,
    this.shadows,
    this.textDirection,
    this.semanticsLabel,
  });

  final IconData icon;
  final double? fontSize;
  final FontWeight? fontWeight;
  final Color? color;
  final List<Shadow>? shadows;
  final TextDirection? textDirection;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.withNoTextScaling(
      child: SFIcon(
        icon,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        shadows: shadows,
        textDirection: textDirection,
        semanticsLabel: semanticsLabel,
      ),
    );
  }
}