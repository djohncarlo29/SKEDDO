import 'dart:math' as math;

import 'package:flutter/widgets.dart';

const double _selectionBarEdgeInset = 8.0;

/// Keeps a wheel option inside its selection-bar segment after magnification.
///
/// Every option keeps exactly an 8dp minimum inset from both segment edges.
/// The text keeps the active OS text scaler; FittedBox shrinks it further when
/// needed.
class WheelOptionText extends StatelessWidget {
  static const double edgeInset = _selectionBarEdgeInset;

  const WheelOptionText({
    super.key,
    required this.text,
    required this.style,
    this.alignment = Alignment.center,
    this.textAlign = TextAlign.center,
    this.magnification = 1.0,
    this.fallbackWidth,
  }) : assert(magnification > 0);

  final String text;
  final TextStyle style;
  final AlignmentGeometry alignment;
  final TextAlign? textAlign;
  final double magnification;

  /// Used only if the wheel's item constraints do not provide a finite width.
  final double? fallbackWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = math.max(
          0.0,
          constraints.hasBoundedWidth
              ? constraints.maxWidth
              : fallbackWidth ?? MediaQuery.sizeOf(context).width,
        );
        final textWidth = math.max(
              0.0,
              availableWidth - 2 * _selectionBarEdgeInset,
            ) /
            magnification;

        return SizedBox(
          width: availableWidth,
          child: Center(
            child: SizedBox(
              width: textWidth,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: alignment,
                child: Text(
                  text,
                  style: style,
                  textAlign: textAlign,
                  maxLines: 1,
                  softWrap: false,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
