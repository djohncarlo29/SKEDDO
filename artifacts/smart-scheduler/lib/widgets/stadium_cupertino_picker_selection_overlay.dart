import 'package:flutter/cupertino.dart';

/// Cupertino picker selection bar with the system overlay's spacing and color,
/// but with true stadium ends that scale to half the bar's rendered height.
class StadiumCupertinoPickerSelectionOverlay extends StatelessWidget {
  const StadiumCupertinoPickerSelectionOverlay({
    super.key,
    this.background = CupertinoColors.tertiarySystemFill,
    this.capStartEdge = true,
    this.capEndEdge = true,
  });

  final Color background;
  final bool capStartEdge;
  final bool capEndEdge;

  static const double _horizontalMargin = 9;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final radius = Radius.circular(constraints.maxHeight / 2);
        return Container(
          margin: EdgeInsetsDirectional.only(
            start: capStartEdge ? _horizontalMargin : 0,
            end: capEndEdge ? _horizontalMargin : 0,
          ),
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(background, context),
            borderRadius: BorderRadiusDirectional.horizontal(
              start: capStartEdge ? radius : Radius.zero,
              end: capEndEdge ? radius : Radius.zero,
            ),
          ),
        );
      },
    );
  }
}