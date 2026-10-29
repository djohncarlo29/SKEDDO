import 'dart:async';
import 'dart:math' as math;
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/cupertino.dart';
import '../app_theme.dart';
import 'edge_fade_metrics.dart';
import 'search_bar_widget.dart' show sbContextMenuActive;

class NativeTextInput extends StatefulWidget {
  final TextEditingController controller;
  final String placeholder;
  final bool multiline;
  final TextStyle style;
  final TextStyle placeholderStyle;
  final EdgeInsets padding;
  // Kept in the shared API for parity with the mobile implementation. The
  // HTML textarea already receives the fixed viewport height from its parent.
  final int? minLines;
  // Kept in the shared API for parity with the mobile Cupertino field. The
  // browser input owns its native horizontal scroll position.
  final ScrollPhysics? scrollPhysics;
  final ScrollController? scrollController;
  final ValueNotifier<EdgeFadeMetrics?>? metricsListenable;
  final Color cursorColor;
  final Color? selectionColor;
  final TextSelectionControls? selectionControls;
  final bool caretToEndOnFirstTap;
  final bool alphaEdgeFade;
  final bool rubberbandWhenContentFits;
  final double alphaFadeWidth;
  final double alphaFadeLeadingInset;
  final double alphaFadeTrailingInset;

  final ValueChanged<bool>? onFocusChanged;

  const NativeTextInput({
    super.key,
    required this.controller,
    required this.placeholder,
    required this.style,
    required this.placeholderStyle,
    required this.cursorColor,
    this.minLines,
    this.scrollPhysics,
    this.scrollController,
    this.metricsListenable,
    this.selectionColor,
    this.selectionControls,
    this.caretToEndOnFirstTap = false,
    this.alphaEdgeFade = false,
    this.rubberbandWhenContentFits = false,
    this.alphaFadeWidth = 36,
    this.alphaFadeLeadingInset = 0,
    this.alphaFadeTrailingInset = 0,
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

  static void unfocus(TextEditingController controller) {
    for (int i = _instances.length - 1; i >= 0; i--) {
      final state = _instances[i];
      if (state.widget.controller == controller &&
          state._element == html.document.activeElement) {
        state._blur();
        return;
      }
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

  /// Returns the controller for the currently focused DOM input, if any.
  /// Browser rotation can blur an HtmlElementView independently of Flutter's
  /// FocusManager, so the app-level rotation guard needs this platform signal.
  static TextEditingController? get focusedController {
    for (int i = _instances.length - 1; i >= 0; i--) {
      final state = _instances[i];
      if (state._element == html.document.activeElement) {
        return state.widget.controller;
      }
    }
    return null;
  }

  static bool isFocused(TextEditingController controller) {
    for (int i = _instances.length - 1; i >= 0; i--) {
      final state = _instances[i];
      if (state.widget.controller == controller &&
          state._element == html.document.activeElement) {
        return true;
      }
    }
    return false;
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
  late final html.CanvasRenderingContext2D _measureContext;
  StreamSubscription<html.Event>? _inputSub;
  StreamSubscription<html.Event>? _scrollSub;
  StreamSubscription<html.Event>? _focusSub;
  StreamSubscription<html.Event>? _blurSub;
  StreamSubscription<html.MouseEvent>? _pointerDownSub;
  StreamSubscription<html.MouseEvent>? _pointerUpSub;
  bool _updatingFromNative = false;
  bool _metricsScheduled = false;
  bool _wasFocusedAtPointerDown = false;
  int? _rubberbandPointerId;
  double _rubberbandStartX = 0;
  double _rubberbandStartY = 0;
  double _rubberbandViewportWidth = 0;
  double _rubberbandSyntheticPixels = 0;
  bool _rubberbandPointerActive = false;
  String? _lastAlphaEdgeMask;

  @override
  void initState() {
    super.initState();
    _installPlaceholderStyle();
    _viewType =
        'smart_scheduler/native_text_input_web_${identityHashCode(this)}';
    _element = widget.multiline
        ? html.TextAreaElement()
        : html.InputElement(type: 'text');
    _measureContext = html.CanvasElement().context2D;
    _setNativeText(widget.controller.text);
    _inputSub = _element.onInput.listen((_) => _syncTextFromNative());
    _scrollSub = _element.onScroll.listen((_) => _publishScrollMetrics());
    _element
      ..addEventListener('pointerdown', _handleRubberbandPointerDown)
      ..addEventListener('pointermove', _handleRubberbandPointerMove)
      ..addEventListener('pointerup', _handleRubberbandPointerEnd)
      ..addEventListener('pointercancel', _handleRubberbandPointerEnd);
    if (widget.caretToEndOnFirstTap) {
      _pointerDownSub = _element.onMouseDown.listen((_) {
        _wasFocusedAtPointerDown = html.document.activeElement == _element;
      });
      _pointerUpSub = _element.onMouseUp.listen((_) {
        if (_wasFocusedAtPointerDown) return;
        html.window.requestAnimationFrame((_) {
          if (!mounted || html.document.activeElement != _element) return;
          _setNativeCaretToEnd();
        });
      });
    }
    _focusSub = _element.onFocus.listen((_) {
      widget.onFocusChanged?.call(true);
    });
    _blurSub = _element.onBlur.listen((_) {
      widget.onFocusChanged?.call(false);
    });
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
      _schedulePublishScrollMetrics();
    }
  }

  @override
  void dispose() {
    NativeTextInput._instances.remove(this);
    widget.controller.removeListener(_syncTextToNative);
    _inputSub?.cancel();
    _scrollSub?.cancel();
    _focusSub?.cancel();
    _blurSub?.cancel();
    _pointerDownSub?.cancel();
    _pointerUpSub?.cancel();
    _element
      ..removeEventListener('pointerdown', _handleRubberbandPointerDown)
      ..removeEventListener('pointermove', _handleRubberbandPointerMove)
      ..removeEventListener('pointerup', _handleRubberbandPointerEnd)
      ..removeEventListener('pointercancel', _handleRubberbandPointerEnd);
    _element.remove();
    super.dispose();
  }

  void _configureElement(TextScaler textScaler) {
    final color = _cssColor(widget.style.color ?? kPrimaryLabel);
    final caret = _cssColor(widget.cursorColor);
    final selection = _cssColor(
      widget.selectionColor ?? widget.cursorColor,
      alpha: 0.28,
    );
    // HtmlElementView does not receive Flutter's ambient TextScaler
    // automatically. Apply the same scaler explicitly so the visible DOM
    // input matches the Flutter placeholder ghost and the mobile field,
    // including nonlinear accessibility sizes.
    final fontSize = textScaler.scale(widget.style.fontSize ?? 17);
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
    _schedulePublishScrollMetrics();
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
    _schedulePublishScrollMetrics();
  }

  void _syncTextToNative() {
    if (_updatingFromNative) return;
    final text = widget.controller.text;
    if (_nativeText == text) return;
    _setNativeText(text);
    _schedulePublishScrollMetrics();
  }

  void _schedulePublishScrollMetrics() {
    if (_metricsScheduled) return;
    _metricsScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _metricsScheduled = false;
      if (mounted) _publishScrollMetrics();
    });
  }

  void _handleRubberbandPointerDown(html.Event rawEvent) {
    if (!widget.rubberbandWhenContentFits || widget.multiline) return;
    final event = rawEvent as html.PointerEvent;
    final viewportWidth = math.max(
      0.0,
      _element.clientWidth -
          widget.padding.left -
          widget.padding.right,
    );
    if (_measureSingleLineContentWidth() > viewportWidth + 1.0) return;
    _rubberbandPointerId = event.pointerId;
    _rubberbandStartX = event.client.x.toDouble();
    _rubberbandStartY = event.client.y.toDouble();
    _rubberbandViewportWidth = viewportWidth;
    _rubberbandSyntheticPixels = 0;
    _rubberbandPointerActive = false;
  }

  void _handleRubberbandPointerMove(html.Event rawEvent) {
    if (_rubberbandPointerId == null) return;
    final event = rawEvent as html.PointerEvent;
    if (event.pointerId != _rubberbandPointerId) return;
    final deltaX = event.client.x.toDouble() - _rubberbandStartX;
    final deltaY = event.client.y.toDouble() - _rubberbandStartY;
    if (deltaY.abs() > 8 && deltaY.abs() > deltaX.abs()) {
      _endRubberbandPointer(event);
      return;
    }
    if (deltaX.abs() < 8) return;

    final maxShift = math.min(32.0, _rubberbandViewportWidth * 0.16);
    final childOffset = (deltaX * 0.55)
        .clamp(-maxShift, maxShift)
        .toDouble();
    _rubberbandPointerActive = true;
    _rubberbandSyntheticPixels = -childOffset;
    _publishSyntheticRubberbandMetrics(_rubberbandSyntheticPixels);
  }

  void _handleRubberbandPointerEnd(html.Event rawEvent) {
    final event = rawEvent as html.PointerEvent;
    if (event.pointerId == _rubberbandPointerId) {
      _endRubberbandPointer(event);
    }
  }

  void _endRubberbandPointer(html.PointerEvent event) {
    if (event.pointerId != _rubberbandPointerId) return;
    _rubberbandPointerId = null;
    _rubberbandPointerActive = false;
    _rubberbandSyntheticPixels = 0;
    _publishSyntheticRubberbandMetrics(0);
    _schedulePublishScrollMetrics();
  }

  void _publishSyntheticRubberbandMetrics(double pixels) {
    widget.metricsListenable?.value = EdgeFadeMetrics(
      pixels: pixels,
      minScrollExtent: 0,
      maxScrollExtent: 0,
      extentBefore: 0,
      extentAfter: 0,
    );
  }

  void _publishScrollMetrics() {
    if (widget.multiline) {
      final notifier = widget.metricsListenable;
      if (notifier == null) return;
      final viewport = _element.clientHeight.toDouble();
      final content = _element.scrollHeight.toDouble();
      final maxExtent = math.max(0.0, content - viewport);
      final pixels = _element.scrollTop.toDouble();
      notifier.value = EdgeFadeMetrics(
        pixels: pixels,
        minScrollExtent: 0,
        maxScrollExtent: maxExtent,
        extentBefore: math.max(0.0, pixels),
        extentAfter: math.max(0.0, maxExtent - pixels),
      );
      return;
    }

    final horizontalContentWidth = _measureSingleLineContentWidth();
    final horizontalViewportWidth = math.max(
      0.0,
      _element.clientWidth -
          widget.padding.left -
          widget.padding.right,
    );
    final maxExtent = math.max(
      0.0,
      horizontalContentWidth - horizontalViewportWidth,
    );
    if (_rubberbandPointerActive &&
        widget.rubberbandWhenContentFits &&
        maxExtent <= 1.0) {
      _updateAlphaEdgeMask(
        contentWidth: horizontalContentWidth,
        viewportWidth: horizontalViewportWidth,
        pixels: 0,
        maxExtent: 0,
      );
      _publishSyntheticRubberbandMetrics(_rubberbandSyntheticPixels);
      return;
    }
    final pixels = _element.scrollLeft.toDouble();
    _updateAlphaEdgeMask(
      contentWidth: horizontalContentWidth,
      viewportWidth: horizontalViewportWidth,
      pixels: pixels,
      maxExtent: maxExtent,
    );

    final notifier = widget.metricsListenable;
    if (notifier == null) return;
    notifier.value = EdgeFadeMetrics(
      pixels: pixels,
      minScrollExtent: 0,
      maxScrollExtent: maxExtent,
      extentBefore: math.max(0.0, pixels),
      extentAfter: math.max(0.0, maxExtent - pixels),
    );
  }

  double _measureSingleLineContentWidth() {
    final text = _nativeText;
    if (text.isEmpty) return 0;
    _measureContext.font =
        '${widget.style.fontWeight?.value ?? 400} ${_element.style.fontSize} ${_element.style.fontFamily}';
    final letterSpacing = widget.style.letterSpacing ?? 0;
    final measuredWidth = _measureContext.measureText(text).width ?? 0;
    return (
      measuredWidth +
      math.max(0, text.runes.length - 1) * letterSpacing
    ).toDouble();
  }

  void _updateAlphaEdgeMask({
    required double contentWidth,
    required double viewportWidth,
    required double pixels,
    required double maxExtent,
  }) {
    if (!widget.alphaEdgeFade ||
        _nativeText.isEmpty ||
        contentWidth <= viewportWidth + 1 ||
        viewportWidth <= 0) {
      _setAlphaEdgeMask('none');
      return;
    }

    final showLeading = pixels > 1;
    final showTrailing = pixels < maxExtent - 1;
    if (!showLeading && !showTrailing) {
      _setAlphaEdgeMask('none');
      return;
    }

    final fadeWidth = widget.alphaFadeWidth;
    final leadingInset = widget.alphaFadeLeadingInset;
    final trailingInset = widget.alphaFadeTrailingInset;
    final stops = <String>[];
    if (showLeading) {
      stops
        ..add('transparent 0px')
        ..add('transparent ${leadingInset}px')
        ..add('white ${leadingInset + fadeWidth}px');
    } else {
      stops.add('white 0px');
    }
    if (showTrailing) {
      stops
        ..add('white calc(100% - ${trailingInset + fadeWidth}px)')
        ..add('transparent calc(100% - ${trailingInset}px)')
        ..add('transparent 100%');
    } else {
      stops.add('white 100%');
    }
    _setAlphaEdgeMask('linear-gradient(to right, ${stops.join(', ')})');
  }

  void _setAlphaEdgeMask(String value) {
    if (_lastAlphaEdgeMask == value) return;
    _lastAlphaEdgeMask = value;
    _element.style
      ..setProperty('mask-mode', 'alpha')
      ..setProperty('mask-repeat', 'no-repeat')
      ..setProperty('mask-size', '100% 100%')
      ..setProperty('mask-image', value)
      ..setProperty('-webkit-mask-repeat', 'no-repeat')
      ..setProperty('-webkit-mask-size', '100% 100%')
      ..setProperty('-webkit-mask-image', value);
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

  void _setNativeCaretToEnd() {
    final length = _nativeText.length;
    if (_element is html.TextAreaElement) {
      (_element as html.TextAreaElement).setSelectionRange(length, length);
    } else {
      (_element as html.InputElement).setSelectionRange(length, length);
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
    _configureElement(MediaQuery.textScalerOf(context));
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
          fit: StackFit.expand,
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
      child: SizedBox(
        width: double.infinity,
        child: Text(
          text.isEmpty ? widget.placeholder : text,
          style: text.isEmpty ? widget.placeholderStyle : widget.style,
          maxLines: widget.multiline ? null : 1,
          overflow: TextOverflow.clip,
        ),
      ),
    );
  }
}
