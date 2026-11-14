import 'package:flutter/widgets.dart';
import 'package:liquid_glass_widgets/widgets/shared/glass_option_gesture_arena.dart';
import 'package:meta/meta.dart';
import 'interaction_notification.dart';

@internal
class GlassDragBuilder extends StatefulWidget {
  const GlassDragBuilder({
    required this.builder,
    this.behavior = HitTestBehavior.opaque,
    this.suppressInteractionOnChildren = true,
    this.gestureController,
    this.child,
    super.key,
  });

  final HitTestBehavior behavior;
  final bool suppressInteractionOnChildren;
  final GlassOptionGestureController? gestureController;
  final ValueWidgetBuilder<Offset?> builder;
  final Widget? child;

  @override
  State<GlassDragBuilder> createState() => _GlassDragBuilderState();
}

class _GlassDragBuilderState extends State<GlassDragBuilder> {
  Offset? currentDragOffset;
  bool _shouldIgnoreCurrentPointer = false;

  bool get isDragging => currentDragOffset != null;

  @override
  void initState() {
    super.initState();
    widget.gestureController?.addListener(_onGestureOwnerChanged);
  }

  @override
  void didUpdateWidget(covariant GlassDragBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.gestureController != widget.gestureController) {
      oldWidget.gestureController?.removeListener(_onGestureOwnerChanged);
      widget.gestureController?.addListener(_onGestureOwnerChanged);
    }
  }

  @override
  void dispose() {
    widget.gestureController?.removeListener(_onGestureOwnerChanged);
    super.dispose();
  }

  void _onGestureOwnerChanged() {
    if (mounted) setState(() {});
  }

  Offset? get _builderOffset {
    if (currentDragOffset == null || widget.gestureController?.allowsStretch != false) {
      return currentDragOffset;
    }
    return Offset.zero;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<InteractionNotification>(
      onNotification: (notification) {
        if (widget.suppressInteractionOnChildren) {
          _shouldIgnoreCurrentPointer = true;
        }
        return false; // Let it bubble
      },
      child: Listener(
        behavior: widget.behavior,
        onPointerDown: (event) {
          if (widget.suppressInteractionOnChildren &&
              _shouldIgnoreCurrentPointer) {
            _shouldIgnoreCurrentPointer = false;
            return;
          }
          if (!mounted) return;
          setState(() => currentDragOffset = Offset.zero);
        },
        onPointerMove: (event) {
          if (currentDragOffset == null) return;
          if (!mounted) return;
          setState(() {
            currentDragOffset =
                (currentDragOffset ?? Offset.zero) + event.delta;
          });
        },
        onPointerUp: (event) {
          _shouldIgnoreCurrentPointer = false;
          if (!mounted) return;
          setState(() => currentDragOffset = null);
        },
        onPointerCancel: (event) {
          _shouldIgnoreCurrentPointer = false;
          if (!mounted) return;
          setState(() => currentDragOffset = null);
        },
        child: widget.builder(context, _builderOffset, widget.child),
      ),
    );
  }
}
