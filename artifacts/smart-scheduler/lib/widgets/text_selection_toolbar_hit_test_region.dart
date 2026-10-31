import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Marks the Flutter-rendered selection toolbar in the pointer hit-test path.
///
/// AppShell dismisses text focus for taps outside editable text. Selection
/// toolbars live in an overlay, so their buttons are not descendants of the
/// editable's RenderEditable and would otherwise be mistaken for outside taps.
class TextSelectionToolbarHitTestRegion extends SingleChildRenderObjectWidget {
  const TextSelectionToolbarHitTestRegion({super.key, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderTextSelectionToolbarHitTestRegion();
}

class _RenderTextSelectionToolbarHitTestRegion extends RenderProxyBox {
  @override
  bool hitTestSelf(Offset position) => true;
}

bool hitTestIncludesTextSelectionToolbar(HitTestResult hitTest) {
  return hitTest.path.any(
    (entry) => entry.target is _RenderTextSelectionToolbarHitTestRegion,
  );
}
