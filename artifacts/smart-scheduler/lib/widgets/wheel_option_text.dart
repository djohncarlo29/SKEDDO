import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Keeps a wheel option inside its selection-bar segment after magnification.
///
/// The text keeps the active OS text scaler. FittedBox only applies an
/// additional scale-down when the actual wheel width cannot contain it.
class WheelOptionText extends StatelessWidget {
  const WheelOptionText({
    super.key,
    required this.text,
    required this.style,
    this.alignment = Alignment.center,
    this.textAlign = TextAlign.center,
    this.magnification = 1.0,
    this.selectionInsets = EdgeInsetsDirectional.zero,
    this.fallbackWidth,
  }) : assert(magnification > 0);

  final String text;
  final TextStyle style;
  final AlignmentGeometry alignment;
  final TextAlign? textAlign;
  final double magnification;

  /// Width kept clear of rounded/capped selection-bar edges.
  final EdgeInsetsDirectional selectionInsets;

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
        final resolvedInsets = selectionInsets.resolve(
          Directionality.of(context),
        );
        final textWidth =
            math.max(0.0, availableWidth - resolvedInsets.horizontal) /
            magnification;

        return SizedBox(
          width: availableWidth,
          child: Padding(
            padding: selectionInsets,
            child: Align(
              alignment: alignment,
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
          ),
        );
      },
    );
  }
}
