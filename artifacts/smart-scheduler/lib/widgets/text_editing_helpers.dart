import 'package:flutter/cupertino.dart';

/// Moves a field's caret to the end after Flutter finishes processing the tap.
///
/// The post-frame timing is intentional: CupertinoTextField may first place
/// the caret at the tapped position during the tap event. This changes only
/// ordinary tap-to-edit behavior; selection and drag gestures do not call this
/// helper.
void scheduleTextFieldCaretToEnd(
  TextEditingController controller, {
  bool Function()? isMounted,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (isMounted != null && !isMounted()) return;
    final text = controller.text;
    controller.selection = TextSelection.collapsed(offset: text.length);
  });
}