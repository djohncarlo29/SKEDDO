import 'package:flutter/cupertino.dart';

class CupertinoDatePickerWithFullWidthSelection extends StatelessWidget {
  const CupertinoDatePickerWithFullWidthSelection({
    super.key,
    required this.itemExtent,
    required this.pickerBuilder,
  });

  final double itemExtent;
  final CupertinoDatePicker Function(
    SelectionOverlayBuilder selectionOverlayBuilder,
  )
  pickerBuilder;

  static Widget? _hideColumnSelection(
    BuildContext context, {
    required int columnCount,
    required int selectedIndex,
  }) => null;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          pickerBuilder(_hideColumnSelection),
          IgnorePointer(
            child: Center(
              child: SizedBox(
                width: double.infinity,
                height: itemExtent,
                child: const CupertinoPickerDefaultSelectionOverlay(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}