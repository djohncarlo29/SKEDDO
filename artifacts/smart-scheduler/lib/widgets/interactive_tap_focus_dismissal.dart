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

  static final Map<int, _FocusAtPointerDown> _dismissAfterPointerUp =
      <int, _FocusAtPointerDown>{};

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

    final primaryFocus = FocusManager.instance.primaryFocus;
    final flutterFocus =
        primaryFocus != null &&
            primaryFocus.hasFocus &&
            primaryFocus is! FocusScopeNode
        ? primaryFocus
        : null;
    final nativeController = NativeTextInput.focusedController;
    if (flutterFocus == null && nativeController == null) return;

    _dismissAfterPointerUp[event.pointer] = _FocusAtPointerDown(
      flutterFocus: flutterFocus,
      nativeController: nativeController,
    );
  }

  void _handlePointerUp(PointerUpEvent event) {
    final focusAtPointerDown = _dismissAfterPointerUp.remove(event.pointer);
    if (focusAtPointerDown == null) return;

    // Run after the target's tap callback. Some picker controls request focus
    // as part of their action. Only blur the field that was active when this
    // interaction began, never a newly focused field on a destination route.
    scheduleMicrotask(() {
      final flutterFocus = focusAtPointerDown.flutterFocus;
      if (flutterFocus?.hasFocus ?? false) {
        flutterFocus!.unfocus();
      }
      final nativeController = focusAtPointerDown.nativeController;
      if (nativeController != null &&
          NativeTextInput.isFocused(nativeController)) {
        NativeTextInput.unfocus(nativeController);
      }
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

class _FocusAtPointerDown {
  const _FocusAtPointerDown({
    required this.flutterFocus,
    required this.nativeController,
  });

  final FocusNode? flutterFocus;
  final TextEditingController? nativeController;
}
