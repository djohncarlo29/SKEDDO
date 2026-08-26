import 'package:flutter/cupertino.dart';

/// Cupertino-native text input used across the app's search bars and the
/// Notes tab note editor.
///
/// This used to embed a real platform `UITextField`/`EditText` via
/// `PlatformView` (see git history / NativeTextInputFactory.kt +
/// AppDelegate.swift for the old implementation). It has been replaced with
/// a pure-Flutter [CupertinoTextField] so the field composites normally with
/// the rest of the tree — most notably so `BackdropFilter` (the category
/// context-menu blur) can actually blur it, which was impossible while it
/// was a platform view.
///
/// The public API (constructor shape + the static focus-management methods)
/// is unchanged so every call site (search_bar_widget.dart, notes_tab.dart,
/// events_tab.dart, calendar_tab.dart) keeps working without modification.
class NativeTextInput extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool multiline;
  final TextStyle style;
  final TextStyle placeholderStyle;
  final EdgeInsets padding;
  final Color cursorColor;
  final Color? selectionColor;
  final TextSelectionControls? selectionControls;
  // Fired when the field gains or loses focus. Used by the Notes tab to
  // collapse the header / show the Cancel button when the user taps into
  // the search bar.
  final ValueChanged<bool>? onFocusChanged;

  const NativeTextInput({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.style,
    required this.placeholderStyle,
    required this.cursorColor,
    this.selectionColor,
    this.selectionControls,
    this.multiline = false,
    this.padding = EdgeInsets.zero,
    this.onFocusChanged,
  });

  // List (not Set) so insertion order is preserved.  focus() searches in
  // reverse so the most-recently-registered instance wins — this lets a
  // DCV search overlay's AppSearchBar take focus over the page-0 grid's
  // AppSearchBar when both share the same TextEditingController.
  static final List<_NativeTextInputState> _instances = [];

  static void unfocusAll() {
    for (final state in _instances) {
      state._blur();
    }
  }

  // Programmatically focus the field for the instance whose
  // [TextEditingController] matches [controller].
  static void focus(TextEditingController controller) {
    for (int i = _instances.length - 1; i >= 0; i--) {
      if (_instances[i].widget.controller == controller) {
        _instances[i]._focus();
        return;
      }
    }
  }

  /// Tells the field to refuse implicit focus loss (tap-outside,
  /// scroll-triggered blur, etc.) while the keyboard must stay up. Only an
  /// explicit [unfocusAll] / [_blur] call (via "blur") is allowed to resign
  /// focus until [unlockFocus] is called.
  static void lockFocus(TextEditingController controller) {
    for (int i = _instances.length - 1; i >= 0; i--) {
      if (_instances[i].widget.controller == controller) {
        _instances[i]._lockFocus();
        return;
      }
    }
  }

  /// Restores normal resign behaviour.  Always call this before an explicit
  /// [unfocusAll] / cancel so the field is clean for the next session.
  static void unlockFocus(TextEditingController controller) {
    for (int i = _instances.length - 1; i >= 0; i--) {
      if (_instances[i].widget.controller == controller) {
        _instances[i]._unlockFocus();
        return;
      }
    }
  }

  @override
  State<NativeTextInput> createState() => _NativeTextInputState();
}

class _NativeTextInputState extends State<NativeTextInput> {
  late final FocusNode _focusNode;

  // When true, any implicit focus loss (tap-outside, scroll-drag, another
  // widget stealing focus, etc.) is refused and focus is immediately
  // reclaimed — mirrors the old isLocked / textFieldShouldEndEditing=false
  // native behaviour so the keyboard stays visible during search mode.
  bool _isLocked = false;
  // Set for the duration of an explicit blur() call so the reclaim-on-lock
  // logic above doesn't fight an intentional dismiss.
  bool _explicitBlur = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'NativeTextInput');
    _focusNode.addListener(_handleFocusChange);
    widget.controller.addListener(_handleTextChange);
    NativeTextInput._instances.add(this);
  }

  @override
  void didUpdateWidget(covariant NativeTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleTextChange);
      widget.controller.addListener(_handleTextChange);
    }
  }

  @override
  void dispose() {
    NativeTextInput._instances.remove(this);
    widget.controller.removeListener(_handleTextChange);
    _focusNode.removeListener(_handleFocusChange);
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    // Rebuild so the animated placeholder overlay shows/hides in step with
    // the field's emptiness, matching the old native TextWatcher behaviour.
    if (mounted) setState(() {});
  }

  void _handleFocusChange() {
    final focused = _focusNode.hasFocus;
    if (!focused && _isLocked && !_explicitBlur) {
      // Refuse the implicit resign and reclaim focus immediately — same
      // contract as the native textFieldShouldEndEditing()==false /
      // isLocked-re-request behaviour this widget replaces.
      _focusNode.requestFocus();
      return;
    }
    widget.onFocusChanged?.call(focused);
    setState(() {}); // drives the placeholder slide animation
  }

  void _blur() {
    _explicitBlur = true;
    _focusNode.unfocus();
    // Clear on the next frame so it outlives the synchronous unfocus() call
    // above and the focus-change notification it triggers.
    WidgetsBinding.instance.addPostFrameCallback((_) => _explicitBlur = false);
  }

  void _focus() {
    _focusNode.requestFocus();
  }

  void _lockFocus() {
    _isLocked = true;
  }

  void _unlockFocus() {
    _isLocked = false;
  }

  @override
  Widget build(BuildContext context) {
    final alignment = widget.multiline
        ? Alignment.topLeft
        : Alignment.centerLeft;
    final bool showPlaceholder = widget.controller.text.isEmpty;
    // Placeholder slides 4px to the right when the field gains focus, same
    // offset/curve as the old Android/iOS overlay-label animation.
    final double placeholderOffset = _focusNode.hasFocus ? 4.0 : 0.0;

    return Stack(
      alignment: alignment,
      children: [
        if (showPlaceholder)
          Positioned.fill(
            child: IgnorePointer(
              child: Padding(
                padding: widget.padding,
                child: Align(
                  alignment: alignment,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    transform: Matrix4.translationValues(
                      placeholderOffset,
                      0,
                      0,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      child: Text(
                        widget.placeholder,
                        style: widget.placeholderStyle,
                        maxLines: widget.multiline ? null : 1,
                        overflow: widget.multiline
                            ? TextOverflow.clip
                            : TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        CupertinoTextField(
          controller: widget.controller,
          focusNode: _focusNode,
          style: widget.style,
          decoration: null,
          maxLines: widget.multiline ? null : 1,
          minLines: null,
          keyboardType: widget.multiline
              ? TextInputType.multiline
              : TextInputType.text,
          textCapitalization: TextCapitalization.sentences,
           textAlignVertical: widget.multiline
               ? TextAlignVertical.top
               : TextAlignVertical.center,
          padding: widget.padding,
          cursorColor: widget.cursorColor,
          selectionControls: widget.selectionControls,
          cursorOpacityAnimates: true,
          enableInteractiveSelection: true,
        ),
      ],
    );
  }
}
