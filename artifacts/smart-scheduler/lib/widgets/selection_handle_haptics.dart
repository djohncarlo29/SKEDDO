import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/services.dart';

const MethodChannel _selectionHapticsChannel = MethodChannel(
  'com.smartscheduler/selection_haptics',
);

/// Marks the pointer-down period on a selection handle so Android can ignore
/// Flutter's repeated selection-click haptic while the handle is held.
class SelectionHandleHapticsGuard extends StatefulWidget {
  const SelectionHandleHapticsGuard({super.key, required this.child});

  final Widget child;

  @override
  State<SelectionHandleHapticsGuard> createState() =>
      _SelectionHandleHapticsGuardState();
}

class _SelectionHandleHapticsGuardState
    extends State<SelectionHandleHapticsGuard> {
  int? _activePointer;

  void _setHandlePressed(bool pressed) {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    unawaited(
      _selectionHapticsChannel
          .invokeMethod<void>('setSelectionHandleDragging', pressed)
          .catchError((Object _) {}),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _setHandlePressed(true);
  }

  void _handlePointerEnd(PointerEvent event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _setHandlePressed(false);
  }

  @override
  void dispose() {
    if (_activePointer != null) _setHandlePressed(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: _handlePointerDown,
    onPointerUp: _handlePointerEnd,
    onPointerCancel: _handlePointerEnd,
    child: widget.child,
  );
}

/// Cupertino selection controls that suppress only handle-press haptics on
/// Android. Other app and picker haptics remain available.
class HapticQuietCupertinoTextSelectionControls
    extends CupertinoTextSelectionControls
    with TextSelectionHandleControls {
  HapticQuietCupertinoTextSelectionControls();

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) => SelectionHandleHapticsGuard(
    child: super.buildHandle(context, type, textLineHeight, onTap),
  );
}

final hapticQuietCupertinoTextSelectionControls =
    HapticQuietCupertinoTextSelectionControls();