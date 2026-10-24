import 'package:flutter/cupertino.dart';

/// Pinch-zoom and pan support for transient image previews.
///
/// Every completed gesture animates the image back to its fit transform, so
/// the preview never remains zoomed or accumulates an offset between gestures.
class ReleaseResetInteractiveViewer extends StatefulWidget {
  const ReleaseResetInteractiveViewer({
    super.key,
    required this.child,
    this.minScale = 1,
    this.maxScale = 5,
    this.resetDuration = const Duration(milliseconds: 300),
    this.boundaryMargin = const EdgeInsets.all(double.infinity),
  });

  final Widget child;
  final double minScale;
  final double maxScale;
  final Duration resetDuration;
  final EdgeInsets boundaryMargin;

  @override
  State<ReleaseResetInteractiveViewer> createState() =>
      _ReleaseResetInteractiveViewerState();
}

class _ReleaseResetInteractiveViewerState
    extends State<ReleaseResetInteractiveViewer>
    with SingleTickerProviderStateMixin {
  late final TransformationController _transformController;
  late final AnimationController _resetController;
  Matrix4Tween? _resetTween;

  @override
  void initState() {
    super.initState();
    _transformController = TransformationController();
    _resetController = AnimationController(
      vsync: this,
      duration: widget.resetDuration,
    )..addListener(_applyResetFrame);
  }

  @override
  void didUpdateWidget(covariant ReleaseResetInteractiveViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetDuration != widget.resetDuration) {
      _resetController.duration = widget.resetDuration;
    }
  }

  void _applyResetFrame() {
    final tween = _resetTween;
    if (tween == null) return;
    _transformController.value = tween.transform(
      Curves.easeOutCubic.transform(_resetController.value),
    );
    if (_resetController.value >= 1) _resetTween = null;
  }

  void _onInteractionStart(ScaleStartDetails _) {
    _resetController.stop();
    _resetTween = null;
  }

  void _onInteractionEnd(ScaleEndDetails _) {
    final current = Matrix4.copy(_transformController.value);
    if (current.isIdentity()) return;

    _resetTween = Matrix4Tween(begin: current, end: Matrix4.identity());
    _resetController
      ..stop()
      ..value = 0
      ..forward();
  }

  @override
  void dispose() {
    _resetController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InteractiveViewer(
      transformationController: _transformController,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      boundaryMargin: widget.boundaryMargin,
      // Let the transformed child bounds grow beyond the initial viewport.
      // Any silhouette clipping belongs inside `child`, so it scales with the
      // image instead of acting as a stationary zoom window.
      clipBehavior: Clip.none,
      // The viewer owns the return-to-fit animation; suppress its independent
      // fling so two animations never compete for the same transform matrix.
      interactionEndFrictionCoefficient: 1e-50,
      onInteractionStart: _onInteractionStart,
      onInteractionEnd: _onInteractionEnd,
      child: widget.child,
    );
  }
}
