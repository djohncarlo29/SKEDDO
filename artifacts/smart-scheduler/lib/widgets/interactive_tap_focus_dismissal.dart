import 'dart:async';

import 'package:flutter/rendering.dart'
    show
        HitTestResult,
        PointerCancelEvent,
        PointerUpEvent,
        RenderEditable,
        RendererBinding;
import 'package:flutter/widgets.dart';

import 'native_text_input.dart';

/// Dismisses text-input focus when the user starts interacting outside an
/// editable text field.
///
/// This belongs above the app's Navigator so it also sees taps in root-level
/// modal sheets. Taps that hit a RenderEditable are left alone, allowing users
/// to focus or continue editing another field.
class InteractiveTapFocusDismissal extends StatelessWidget {
  const InteractiveTapFocusDismissal({super.key, required this.child});

  final Widget child;

  static final Set<int> _dismissAfterPointerUp = <int>{};

  static bool _hasEditableFocus() {
    final primaryFocus = FocusManager.instance.primaryFocus;
    final hasFlutterTextInputFocus =
        primaryFocus != null &&
        primaryFocus.hasFocus &&
        primaryFocus is! FocusScopeNode;
    return hasFlutterTextInputFocus ||
        NativeTextInput.focusedController != null;
  }

  void _handlePointerDown(PointerDownEvent event) {
    _dismissAfterPointerUp.remove(event.pointer);
    final hitTest = HitTestResult();
    RendererBinding.instance.hitTestInView(
      hitTest,
      event.position,
      event.viewId,
    );
    final hitEditableText = hitTest.path.any(
      (entry) => entry.target is RenderEditable,
    );
    if (hitEditableText) return;

    if (_hasEditableFocus()) {
      _dismissAfterPointerUp.add(event.pointer);
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    if (!_dismissAfterPointerUp.remove(event.pointer)) return;

    // Run after the target's tap callback. Some picker controls request focus
    // as part of their action; the interaction still owns dismissal.
    scheduleMicrotask(() {
      if (!_hasEditableFocus()) return;
      final primaryFocus = FocusManager.instance.primaryFocus;
      NativeTextInput.unfocusAll();
      primaryFocus?.unfocus();
    });
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _dismissAfterPointerUp.remove(event.pointer);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: child,
    );
  }
}
