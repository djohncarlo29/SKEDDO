import 'package:flutter/cupertino.dart';
import 'package:flutter/widgets.dart';

class _TextFieldTapState {
  bool wasFocusedAtPointerDown = false;
}

final Expando<_TextFieldTapState> _textFieldTapStates =
    Expando<_TextFieldTapState>();

/// Records whether the field was already focused when the current tap began.
///
/// This must happen on pointer-down because CupertinoTextField focuses itself
/// before it invokes its onTap callback.
void recordTextFieldPointerDown(FocusNode focusNode) {
  final state = _textFieldTapStates[focusNode] ??= _TextFieldTapState();
  state.wasFocusedAtPointerDown = focusNode.hasFocus;
}

/// Returns true only when the current tap started while the field was
/// unfocused.
bool shouldMoveTextFieldCaretToEnd(FocusNode focusNode) =>
    !(_textFieldTapStates[focusNode]?.wasFocusedAtPointerDown ?? false);

/// Tracks pointer-down passively without competing with the text field's
/// selection gesture recognizer.
Widget trackTextFieldPointerDown({
  required FocusNode focusNode,
  required Widget child,
}) {
  return Listener(
    behavior: HitTestBehavior.translucent,
    onPointerDown: (_) => recordTextFieldPointerDown(focusNode),
    child: child,
  );
}

/// Moves a field's caret to the end after Flutter finishes processing the tap.
///
/// The post-frame timing is intentional: CupertinoTextField first places the
/// caret at the tapped position during the tap event. This helper is intended
/// for the first tap into a field; subsequent taps must not call it so normal
/// in-text editing remains possible.
void scheduleTextFieldCaretToEnd(
  TextEditingController controller, {
  ScrollController? scrollController,
  bool Function()? isMounted,
}) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (isMounted != null && !isMounted()) return;
    final text = controller.text;
    controller.selection = TextSelection.collapsed(offset: text.length);

    void scrollToEnd() {
      if (isMounted != null && !isMounted()) return;
      if (scrollController?.hasClients != true) return;
      final position = scrollController!.position;
      if (!position.hasContentDimensions) return;
      if (position.pixels != position.maxScrollExtent) {
        position.jumpTo(position.maxScrollExtent);
      }
    }

    // The text field may update its scroll extent in the frame after the
    // selection change, especially when it is first mounted in a sheet.
    scrollToEnd();
    WidgetsBinding.instance.addPostFrameCallback((_) => scrollToEnd());
  });
}