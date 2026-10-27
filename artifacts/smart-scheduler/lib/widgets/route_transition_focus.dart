import 'package:flutter/widgets.dart';

/// Requests focus after the route containing [context] has finished entering.
///
/// Returns a callback that removes the pending listener. The caller should
/// invoke it from `dispose` so a dismissed route cannot receive delayed focus.
VoidCallback requestFocusAfterRouteTransition(
  BuildContext context,
  FocusNode focusNode,
) {
  final route = ModalRoute.of(context);
  final animation = route?.animation;
  var cancelled = false;
  AnimationStatusListener? listener;

  void removeListener() {
    final currentListener = listener;
    if (currentListener == null) return;
    animation?.removeStatusListener(currentListener);
    listener = null;
  }

  void cancel() {
    cancelled = true;
    removeListener();
  }

  void requestFocus() {
    if (cancelled || !context.mounted || (route != null && !route.isCurrent)) {
      return;
    }
    focusNode.requestFocus();
  }

  if (animation == null || animation.status == AnimationStatus.completed) {
    requestFocus();
    return cancel;
  }

  listener = (status) {
    if (status != AnimationStatus.completed) return;
    removeListener();
    requestFocus();
  };
  animation.addStatusListener(listener!);
  return cancel;
}
