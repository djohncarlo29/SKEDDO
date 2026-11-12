import 'package:flutter/cupertino.dart';

/// Reserves the shared trailing selection-mark column used by picker rows.
///
/// Callers keep the row's existing 16 pt outer horizontal inset; this slot
/// supplies the additional 16 pt separation from the label and keeps that
/// label geometry stable while selection moves between rows.
class TrailingCheckmarkSlot extends StatelessWidget {
  const TrailingCheckmarkSlot({
    super.key,
    required this.selected,
    required this.color,
  });

  final bool selected;
  final Color color;

  static const double _labelGap = 16;
  static const double _baseSize = 17;

  @override
  Widget build(BuildContext context) {
    final checkmarkSize = MediaQuery.textScalerOf(context).scale(_baseSize);
    return SizedBox(
      width: _labelGap + checkmarkSize,
      child: Align(
        alignment: Alignment.centerRight,
        child: selected
            ? Icon(CupertinoIcons.checkmark, size: checkmarkSize, color: color)
            : SizedBox(width: checkmarkSize, height: checkmarkSize),
      ),
    );
  }
}
