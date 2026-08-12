import 'dart:async';
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/cupertino.dart';
import '../app_theme.dart';
import 'search_bar_widget.dart' show sbContextMenuActive;

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

  // Web parity stub: programmatically focuses the underlying HTML input
  // for the instance whose [TextEditingController] matches [controller].
  // Mirrors the mobile implementation so callers don't need a platform
  // check at the call site.
  static void focus(TextEditingController controller) {
    for (int i = _instances.length - 1; i >= 0; i--) {
      if (_instances[i].widget.controller == controller) {
        _instances[i]._focus();
        return;
      }
    }
  }

  // No-op stubs — focus locking is a mobile-only concept (iOS UITextField
  // delegate / Android InputMethodManager).  The web build calls the same
  // call sites so no platform guard is needed at the call site.
  static void lockFocus(TextEditingController controller) {}
  static void unlockFocus(TextEditingController controller) {}

  @override
  State<NativeTextInput> createState() => _NativeTextInputState();
}

class _NativeTextInputState extends State<NativeTextInput> {
  late final String _viewType;
  late final html.HtmlElement _element;
  StreamSubscription<html.Event>? _inputSub;
  bool _updatingFromNative = false;

  @override
  void initState() {
    super.initState();
    _installPlaceholderStyle();
    _viewType =
        'smart_scheduler/native_text_input_web_${identityHashCode(this)}';
    _element = widget.multiline
        ? html.TextAreaElement()
        : html.InputElement(type: 'text');
    _configureElement();
    _setNativeText(widget.controller.text);
    _inputSub = _element.onInput.listen((_) => _syncTextFromNative());
    widget.controller.addListener(_syncTextToNative);
    ui_web.platformViewRegistry.registerViewFactory(_viewType, (_) => _element);
    NativeTextInput._instances.add(this);
  }

  void _blur() {
    _element.blur();
  }

  void _focus() {
    _element.focus();
  }

  @override
  void didUpdateWidget(covariant NativeTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncTextToNative);
      widget.controller.addListener(_syncTextToNative);
      _setNativeText(widget.controller.text);
    }
    _configureElement();
  }

  @override
  void dispose() {
    NativeTextInput._instances.remove(this);
    widget.controller.removeListener(_syncTextToNative);
    _inputSub?.cancel();
    _element.remove();
    super.dispose();
  }

  void _configureElement() {
    final color = _cssColor(widget.style.color ?? kPrimaryLabel);
    final caret = _cssColor(widget.cursorColor);
    final selection = _cssColor(
      widget.selectionColor ?? widget.cursorColor,
      alpha: 0.28,
    );
    final fontSize = widget.style.fontSize ?? 17;
    final lineHeight = widget.style.height ?? 1.3;

    _element
      ..className = 'smart-scheduler-native-text-input'
      ..setAttribute('placeholder', widget.placeholder)
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.boxSizing = 'border-box'
      ..style.background = 'transparent'
      ..style.border = '0'
      ..style.outline = 'none'
      ..style.padding =
          '${widget.padding.top}px ${widget.padding.right}px ${widget.padding.bottom}px ${widget.padding.left}px'
      ..style.margin = '0'
      ..style.color = color
      ..style.fontFamily =
          'SFProText, -apple-system, BlinkMacSystemFont, sans-serif'
      ..style.fontSize = '${fontSize}px'
      ..style.fontWeight = '${widget.style.fontWeight?.value ?? 400}'
      ..style.lineHeight = '$lineHeight'
      ..style.letterSpacing = '${widget.style.letterSpacing ?? 0}px'
      ..style.resize = 'none'
      ..style.setProperty('caret-color', caret)
      ..style.setProperty('--smart-scheduler-selection-color', selection)
      ..style.setProperty('-webkit-appearance', 'none')
      ..style.setProperty('appearance', 'none');

    if (_element is html.TextAreaElement) {
      (_element as html.TextAreaElement)
        ..wrap = 'soft'
        ..style.overflowY = 'auto'
        ..style.setProperty('scrollbar-width', 'none')
        ..style.setProperty('-ms-overflow-style', 'none')
        ..style.setProperty('overscroll-behavior', 'contain');
    }
  }

  void _syncTextFromNative() {
    final text = _nativeText;
    if (widget.controller.text == text) return;
    _updatingFromNative = true;
    widget.controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
    _updatingFromNative = false;
  }

  void _syncTextToNative() {
    if (_updatingFromNative) return;
    final text = widget.controller.text;
    if (_nativeText == text) return;
    _setNativeText(text);
  }

  String get _nativeText {
    if (_element is html.TextAreaElement) {
      return (_element as html.TextAreaElement).value ?? '';
    }
    return (_element as html.InputElement).value ?? '';
  }

  void _setNativeText(String text) {
    if (_element is html.TextAreaElement) {
      (_element as html.TextAreaElement).value = text;
    } else {
      (_element as html.InputElement).value = text;
    }
  }

  String _cssColor(Color color, {double? alpha}) {
    final r = (color.r * 255).round();
    final g = (color.g * 255).round();
    final b = (color.b * 255).round();
    if (alpha == null || alpha >= 0.999) return 'rgb($r, $g, $b)';
    return 'rgba($r, $g, $b, ${alpha.toStringAsFixed(3)})';
  }

  void _installPlaceholderStyle() {
    if (html.document.getElementById('smart-scheduler-native-input-style') !=
        null) {
      return;
    }
    final style = html.StyleElement()
      ..id = 'smart-scheduler-native-input-style'
      ..text = '''
.smart-scheduler-native-text-input::placeholder {
  color: rgb(154, 154, 160);
  opacity: 1;
}
.smart-scheduler-native-text-input::selection {
  background: var(--smart-scheduler-selection-color, rgba(0, 122, 255, 0.28));
  color: inherit;
}
.smart-scheduler-native-text-input::-moz-selection {
  background: var(--smart-scheduler-selection-color, rgba(0, 122, 255, 0.28));
  color: inherit;
}
.smart-scheduler-native-text-input::-webkit-scrollbar {
  display: none;
  width: 0;
  height: 0;
}
''';
    html.document.head?.append(style);
  }

  @override
  Widget build(BuildContext context) {
    // Keep HtmlElementView ALWAYS in the widget tree (never removed) so
    // Flutter never has to re-mount/re-attach the DOM element — that
    // re-attachment is what causes the one-frame blank flicker on close.
    // Instead, hide the HTML element via CSS and Stack a Flutter ghost
    // text on top; removing the ghost on close is instant.
    return ValueListenableBuilder<bool>(
      valueListenable: sbContextMenuActive,
      // ALWAYS return a Stack so Flutter reconciles the same widget type on
      // every rebuild.  If the builder alternates between returning Stack and
      // returning child! directly, Flutter sees a type mismatch and unmounts
      // + remounts the HtmlElementView — that remount is the blank flicker.
      builder: (context, menuOpen, child) {
        _element.style.visibility = menuOpen ? 'hidden' : 'visible';
        return Stack(
          children: [
            child!, // HtmlElementView — always present
            if (menuOpen) _buildGhostText(), // ghost added/removed as a child
          ],
        );
      },
      child: HtmlElementView(viewType: _viewType),
    );
  }

  Widget _buildGhostText() {
    final text = widget.controller.text;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text.isEmpty ? widget.placeholder : text,
        style: text.isEmpty ? widget.placeholderStyle : widget.style,
        maxLines: widget.multiline ? null : 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
