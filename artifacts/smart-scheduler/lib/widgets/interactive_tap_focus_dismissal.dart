import 'package:flutter/gestures.dart' show PointerDownEvent;
import 'package:flutter/rendering.dart'
    show HitTestResult, RenderEditable, RendererBinding;
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

  void _handlePointerDown(PointerDownEvent event) {
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
    final focusedRenderObject = primaryFocus?.context?.findRenderObject();
    final hasFlutterTextInputFocus = focusedRenderObject is RenderEditable;
    final hasNativeTextInputFocus = NativeTextInput.focusedController != null;
    if (!hasFlutterTextInputFocus && !hasNativeTextInputFocus) return;

    // NativeTextInput has its own platform focus bridge; unfocus it as well as
    // Flutter's current focus so the software keyboard reliably closes.
    NativeTextInput.unfocusAll();
    primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      child: child,
    );
  }
}
