import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// The single primary owner of an option-surface pointer sequence.
///
/// Touch glow and press scaling remain independent visual feedback. Stretch,
/// option selection, and scrolling are mutually exclusive once one wins.
enum GlassOptionGestureOwner {
  /// The pointer has not moved far enough to resolve its intent.
  undecided,

  /// The pointer completed with tap-like movement.
  tap,

  /// The pointer is gliding over selectable options.
  selection,

  /// The scrollable option list owns the movement.
  scroll,

  /// The glass surface owns the stretch movement.
  stretch,
}

/// Coordinates tap, glide selection, scrolling, and glass stretch for one
/// liquid-glass option surface.
///
/// Scroll views using this controller should be wrapped in
/// [GlassOptionGestureScrollConfiguration] so their native drag recognizers
/// cannot compete with the controller. Their normal physics still handles
/// wheel/trackpad scrolling and the controller's explicit drag.
class GlassOptionGestureController extends ChangeNotifier {
  GlassOptionGestureOwner _owner = GlassOptionGestureOwner.undecided;
  GlassOptionGestureOwner _lastCompletedOwner =
      GlassOptionGestureOwner.undecided;
  int? _lastCompletedOptionIndex;
  int? _pointer;
  Offset? _startPosition;
  Offset? _lastPosition;
  VelocityTracker? _velocityTracker;
  ScrollController? _scrollController;
  Drag? _scrollDrag;
  Rect Function()? _surfaceBounds;
  int? Function(Offset)? _optionAt;
  ValueChanged<int?>? _onCandidateChanged;
  ValueChanged<int>? _onSelect;
  int? _startOption;
  int? _activeOption;
  int? _pendingOption;
  double _rowExtent = 48;
  bool _deferUntilInside = false;
  bool _active = false;
  double _movementSlop = kTouchSlop;

  static const double _selectionScrollDistanceRows = 2.5;
  static const double _fastScrollVelocity = 760;

  /// The owner currently locked to this pointer sequence.
  GlassOptionGestureOwner get owner => _owner;

  /// True outside an arbitrated gesture, or after stretch owns this gesture.
  bool get allowsStretch =>
      !_active || _owner == GlassOptionGestureOwner.stretch;

  /// The last resolved owner, including the most recently released tap.
  GlassOptionGestureOwner get lastCompletedOwner => _lastCompletedOwner;

  /// The option index selected by the most recently completed sequence.
  int? get lastCompletedOptionIndex => _lastCompletedOptionIndex;

  /// Whether a pointer sequence is currently being tracked.
  bool get isActive => _active;

  /// Starts a pointer sequence from a real pointer event.
  void beginPointer(
    PointerDownEvent event, {
    required Rect Function() surfaceBounds,
    required int? Function(Offset globalPosition) optionAt,
    required ValueChanged<int?> onCandidateChanged,
    required ValueChanged<int> onSelect,
    ScrollController? scrollController,
    double rowExtent = 48,
    bool deferUntilInside = false,
    double movementSlop = kTouchSlop,
  }) {
    beginAt(
      pointer: event.pointer,
      globalPosition: event.position,
      timeStamp: event.timeStamp,
      kind: event.kind,
      surfaceBounds: surfaceBounds,
      optionAt: optionAt,
      onCandidateChanged: onCandidateChanged,
      onSelect: onSelect,
      scrollController: scrollController,
      rowExtent: rowExtent,
      deferUntilInside: deferUntilInside,
      movementSlop: movementSlop,
    );
  }

  /// Starts a sequence forwarded by a trigger that owns the pointer, such as
  /// the long-press tile that opened a context menu.
  void beginAt({
    required int pointer,
    required Offset globalPosition,
    required Duration timeStamp,
    required PointerDeviceKind kind,
    required Rect Function() surfaceBounds,
    required int? Function(Offset globalPosition) optionAt,
    required ValueChanged<int?> onCandidateChanged,
    required ValueChanged<int> onSelect,
    ScrollController? scrollController,
    double rowExtent = 48,
    bool deferUntilInside = false,
    double movementSlop = kTouchSlop,
    bool startInSelection = false,
  }) {
    if (_active) cancel();
    _active = true;
    _pointer = pointer;
    _owner = GlassOptionGestureOwner.undecided;
    _lastCompletedOptionIndex = null;
    _startPosition = globalPosition;
    _lastPosition = globalPosition;
    _velocityTracker = VelocityTracker.withKind(kind)
      ..addPosition(timeStamp, globalPosition);
    _surfaceBounds = surfaceBounds;
    _optionAt = optionAt;
    _onCandidateChanged = onCandidateChanged;
    _onSelect = onSelect;
    _scrollController = scrollController;
    _rowExtent = rowExtent.clamp(1, double.infinity);
    _deferUntilInside = deferUntilInside;
    _movementSlop = movementSlop.clamp(1, double.infinity);
    _startOption = optionAt(globalPosition);
    _activeOption = null;
    _pendingOption = null;
    if (startInSelection && _startOption != null) {
      _setOwner(GlassOptionGestureOwner.selection);
      _setCandidate(_startOption);
    }
  }

  /// Updates from a real pointer move.
  void movePointer(PointerMoveEvent event) {
    _moveAt(event.pointer, event.position, event.timeStamp);
  }

  /// Updates a pointer sequence forwarded by its trigger.
  void moveAt({
    required int pointer,
    required Offset globalPosition,
    required Duration timeStamp,
  }) {
    _moveAt(pointer, globalPosition, timeStamp);
  }

  void _moveAt(int pointer, Offset globalPosition, Duration timeStamp) {
    if (!_active || _pointer != pointer) return;
    final previous = _lastPosition ?? globalPosition;
    final delta = globalPosition - previous;
    _velocityTracker?.addPosition(timeStamp, globalPosition);
    _lastPosition = globalPosition;

    if (_owner == GlassOptionGestureOwner.undecided) {
      _classifyMove(globalPosition);
    }

    switch (_owner) {
      case GlassOptionGestureOwner.selection:
        _setCandidate(_optionAt?.call(globalPosition));
      case GlassOptionGestureOwner.scroll:
        if (_scrollDrag == null) {
          _startScrollDrag(globalPosition, timeStamp);
        } else {
          _scrollDrag?.update(
            DragUpdateDetails(
              delta: Offset(0, delta.dy),
              primaryDelta: delta.dy,
              globalPosition: globalPosition,
              sourceTimeStamp: timeStamp,
            ),
          );
        }
      case GlassOptionGestureOwner.undecided:
      case GlassOptionGestureOwner.tap:
      case GlassOptionGestureOwner.stretch:
        break;
    }
  }

  void _classifyMove(Offset position) {
    final start = _startPosition;
    final bounds = _surfaceBounds?.call();
    if (start == null || bounds == null) return;
    final total = position - start;
    final distance = total.distance;
    if (distance < _movementSlop) return;

    final candidate = _optionAt?.call(position);
    _pendingOption = candidate;
    if (_deferUntilInside) {
      if (!bounds.contains(position) || candidate == null) return;
      // A pointer forwarded from a trigger already represents a deliberate
      // glide into the newly opened menu. Start selection at its first row;
      // the subsequent events remain locked to that choice.
      _setOwner(GlassOptionGestureOwner.selection);
      _setCandidate(candidate);
      return;
    }

    final dx = total.dx.abs();
    final dy = total.dy.abs();
    final crossedOption = candidate != null && candidate != _startOption;
    final horizontalStretch = dx > dy * 1.6 && dx > _rowExtent * 1.25;
    if (horizontalStretch) {
      _setOwner(GlassOptionGestureOwner.stretch);
      _setCandidate(null);
      return;
    }

    final scrollable = _hasScrollableExtent;
    if (!scrollable) {
      if (candidate != null) {
        _setOwner(GlassOptionGestureOwner.selection);
        _setCandidate(candidate);
      } else {
        _setOwner(GlassOptionGestureOwner.stretch);
      }
      return;
    }

    if (dy <= dx * 0.625 && !crossedOption) {
      _setOwner(GlassOptionGestureOwner.stretch);
      _setCandidate(null);
      return;
    }

    final velocity =
        _velocityTracker?.getVelocity().pixelsPerSecond.dy.abs() ?? 0;
    final traveledRows = dy / _rowExtent;
    final fastContinuousScroll =
        velocity >= _fastScrollVelocity && traveledRows >= 0.65;
    final longVerticalTravel = traveledRows >= _selectionScrollDistanceRows;

    final positionMetrics = _scrollController!.position;
    final movingTowardAvailableContent = total.dy < 0
        ? positionMetrics.pixels < positionMetrics.maxScrollExtent - 0.5
        : positionMetrics.pixels > positionMetrics.minScrollExtent + 0.5;
    final startedAtRelevantBoundary = total.dy < 0
        ? positionMetrics.pixels <= positionMetrics.minScrollExtent + 0.5
        : positionMetrics.pixels >= positionMetrics.maxScrollExtent - 0.5;
    final boundaryScrollIntent = startedAtRelevantBoundary &&
        movingTowardAvailableContent &&
        traveledRows >= 1.5;

    if (fastContinuousScroll ||
        longVerticalTravel ||
        candidate == null ||
        boundaryScrollIntent) {
      _setOwner(GlassOptionGestureOwner.scroll);
      _setCandidate(null);
      return;
    }
    if (crossedOption && traveledRows >= 1.25 && !startedAtRelevantBoundary) {
      _setOwner(GlassOptionGestureOwner.selection);
      _setCandidate(candidate);
    }

    if (!bounds.contains(position)) {
      _setOwner(GlassOptionGestureOwner.scroll);
      _setCandidate(null);
    }
  }

  bool get _hasScrollableExtent {
    final controller = _scrollController;
    if (controller == null || !controller.hasClients) return false;
    final position = controller.position;
    return position.maxScrollExtent - position.minScrollExtent > 0.5;
  }

  void _startScrollDrag(Offset currentPosition, Duration timeStamp) {
    final controller = _scrollController;
    final start = _startPosition;
    if (controller == null || !controller.hasClients || start == null) return;
    final position = controller.position;
    _scrollDrag = position.drag(
      DragStartDetails(globalPosition: start),
      () => _scrollDrag = null,
    );
    final delta = currentPosition - start;
    if (delta.distanceSquared > 0) {
      _scrollDrag?.update(
        DragUpdateDetails(
          delta: Offset(0, delta.dy),
          primaryDelta: delta.dy,
          globalPosition: currentPosition,
          sourceTimeStamp: timeStamp,
        ),
      );
    }
  }

  void _setOwner(GlassOptionGestureOwner value) {
    if (_owner == value) return;
    _owner = value;
    notifyListeners();
  }

  void _setCandidate(int? value) {
    if (_activeOption == value) return;
    _activeOption = value;
    _onCandidateChanged?.call(value);
  }

  /// Ends a real pointer sequence and selects only if glide selection owned it.
  void endPointer(PointerUpEvent event) {
    _endAt(event.pointer, event.position);
  }

  /// Ends a forwarded pointer sequence.
  void endAt({required int pointer, required Offset globalPosition}) {
    _endAt(pointer, globalPosition);
  }

  void _endAt(int pointer, Offset globalPosition) {
    if (!_active || _pointer != pointer) return;
    final movedDistance =
        ((_lastPosition ?? globalPosition) - (_startPosition ?? globalPosition))
            .distance;
    final completionOwner = _owner == GlassOptionGestureOwner.undecided
        ? (_pendingOption != null && movedDistance >= _movementSlop
            ? GlassOptionGestureOwner.selection
            : GlassOptionGestureOwner.tap)
        : _owner;
    final selectedIndex = completionOwner == GlassOptionGestureOwner.selection
        ? (_optionAt?.call(globalPosition) ?? _activeOption ?? _pendingOption)
        : null;
    final onSelect = _onSelect;
    if (completionOwner == GlassOptionGestureOwner.scroll) {
      final velocity = _velocityTracker?.getVelocity() ?? Velocity.zero;
      final verticalVelocity = Velocity(
        pixelsPerSecond: Offset(0, velocity.pixelsPerSecond.dy),
      );
      _scrollDrag?.end(
        DragEndDetails(
          velocity: verticalVelocity,
          primaryVelocity: verticalVelocity.pixelsPerSecond.dy,
        ),
      );
      _scrollDrag = null;
    }
    if (completionOwner == GlassOptionGestureOwner.selection &&
        _activeOption == null &&
        selectedIndex != null) {
      _onCandidateChanged?.call(selectedIndex);
    }
    _onCandidateChanged?.call(null);
    _lastCompletedOwner = completionOwner;
    _lastCompletedOptionIndex = selectedIndex;
    _reset();
    if (selectedIndex != null &&
        completionOwner == GlassOptionGestureOwner.selection) {
      onSelect?.call(selectedIndex);
    }
  }

  /// Cancels a real pointer sequence.
  void cancelPointer(PointerCancelEvent event) {
    cancel(pointer: event.pointer);
  }

  /// Cancels a forwarded pointer sequence, or the current sequence if omitted.
  void cancel({int? pointer}) {
    if (!_active || (pointer != null && _pointer != pointer)) return;
    _scrollDrag?.cancel();
    _scrollDrag = null;
    _onCandidateChanged?.call(null);
    _lastCompletedOwner = GlassOptionGestureOwner.undecided;
    _lastCompletedOptionIndex = null;
    _reset();
  }

  void _reset() {
    _active = false;
    _pointer = null;
    _startPosition = null;
    _lastPosition = null;
    _velocityTracker = null;
    _scrollController = null;
    _surfaceBounds = null;
    _optionAt = null;
    _onCandidateChanged = null;
    _onSelect = null;
    _startOption = null;
    _activeOption = null;
    _pendingOption = null;
    _deferUntilInside = false;
    _movementSlop = kTouchSlop;
    _owner = GlassOptionGestureOwner.undecided;
    notifyListeners();
  }

  @override
  void dispose() {
    _scrollDrag?.cancel();
    _scrollDrag = null;
    super.dispose();
  }
}

/// Makes one gesture controller available to a glass surface and its options.
class GlassOptionGestureScope extends InheritedWidget {
  /// Creates a scope that shares one gesture controller with descendants.
  const GlassOptionGestureScope({
    super.key,
    required this.controller,
    required super.child,
  });

  /// The shared owner for gestures in this surface.
  final GlassOptionGestureController controller;

  /// Finds the closest gesture scope, if one is present.
  static GlassOptionGestureController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<GlassOptionGestureScope>()
      ?.controller;

  @override
  bool updateShouldNotify(GlassOptionGestureScope oldWidget) =>
      controller != oldWidget.controller;
}

/// Disables competing direct-drag recognizers while preserving wheel and
/// trackpad pointer-scroll input for a coordinated option list.
class GlassOptionGestureScrollConfiguration extends StatelessWidget {
  /// Creates a scroll configuration for a gesture-arbitrated option list.
  const GlassOptionGestureScrollConfiguration({
    super.key,
    required this.child,
  });

  /// The scrollable content whose drag is owned by a
  /// [GlassOptionGestureController].
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final behavior = ScrollConfiguration.of(context).copyWith(
      dragDevices: const <PointerDeviceKind>{},
    );
    return ScrollConfiguration(behavior: behavior, child: child);
  }
}
