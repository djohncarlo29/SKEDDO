import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassButton,
        GlassButtonStyle,
        GlassMenuAlignment,
        GlassPopover,
        GlassQuality,
        LiquidGlassSettings,
        LiquidRoundedSuperellipse;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassDialogAction;

import '../app_settings.dart';
import '../app_theme.dart';
import '../services/event_store.dart';
import 'action_panel.dart';
import 'device_screen_size.dart' as device_screen_size;
import 'rounded_cupertino_sheet.dart';
import 'skeddo_glass_alert_platter.dart';
import 'skeddo_glass_settings.dart';

VoidCallback? _activeDiscardChangesSheetDismiss;
bool _discardChangesBackConsumed = false;

/// Closes the active discard popover when a back event is delivered.
///
/// The GlassPopover is hosted by the editor route, so the editor's PopScope
/// receives the back event that dismisses it. The short-lived consumed flag
/// prevents a duplicate callback from reopening the confirmation immediately.
bool dismissActiveDiscardChangesConfirmationSheet() {
  if (_discardChangesBackConsumed) return true;

  final dismiss = _activeDiscardChangesSheetDismiss;
  if (dismiss == null) return false;

  _discardChangesBackConsumed = true;
  scheduleMicrotask(() {
    _discardChangesBackConsumed = false;
  });
  dismiss();
  return true;
}

/// Shows the shared confirmation surface used by event, category, section, and
/// lifecycle actions.
Future<bool?> showConfirmationSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String actionLabel = 'Delete',
  bool destructive = false,
  bool accentAction = false,
}) {
  return showSkeddoGlassAlertDialog<bool>(
    context: context,
    title: title,
    message: subtitle,
    actionsBuilder: (dialogContext) => [
      GlassDialogAction(
        label: 'Cancel',
        onPressed: () => Navigator.of(dialogContext).pop(false),
      ),
      GlassDialogAction(
        label: actionLabel,
        isDestructive: destructive,
        isPrimary: accentAction,
        onPressed: () => Navigator.of(dialogContext).pop(true),
      ),
    ],
  );
}

/// Shows the shared destructive confirmation surface used by event, category,
/// section, and permanent-delete actions.
Future<bool?> showDeleteConfirmationSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String actionLabel = 'Delete',
}) {
  return showConfirmationSheet(
    context,
    title: title,
    subtitle: subtitle,
    actionLabel: actionLabel,
    destructive: true,
  );
}

/// Confirms an archive action using the same destructive-red treatment as the
/// other lifecycle confirmations. Archiving is reversible, but it still
/// removes the item from the active schedule.
Future<bool?> showArchiveConfirmationSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String actionLabel = 'Archive',
}) {
  return showConfirmationSheet(
    context,
    title: title,
    subtitle: subtitle,
    actionLabel: actionLabel,
    destructive: true,
  );
}

/// Shows the shared top-left confirmation used when an editor with unsaved
/// changes is dismissed, regardless of whether dismissal came from the X-mark,
/// a system navigation action, or a sheet gesture.
Future<bool?> showDiscardChangesConfirmationSheet(
  BuildContext context, {
  required GlobalKey<DiscardChangesPopoverAnchorState> anchorKey,
  required String entityLabel,
  required bool isNew,
}) async {
  if (!context.mounted) return null;

  // A downward drag can veto route dismissal while the sheet is still partway
  // through its gesture. Restore the route before GlassPopover measures its
  // trigger, so its morph starts at the X's actual settled position.
  await RoundedCupertinoSheetRoute.restoreCurrentSheetToOpen(context);
  if (!context.mounted) return null;

  final anchor = anchorKey.currentState;
  if (anchor == null) {
    throw StateError(
      'The discard confirmation must be anchored to its visible close button.',
    );
  }
  return anchor.show(entityLabel: entityLabel, isNew: isNew);
}

/// Runs both confirmations in one morphing glass dialog route. Cancelling the
/// second step returns to the first; cancelling the first dismisses the flow.
Future<bool> showTwoStepConfirmationSheet({
  required BuildContext context,
  required String firstTitle,
  String? firstSubtitle,
  required String firstActionLabel,
  required String secondTitle,
  String? secondSubtitle,
  required String secondActionLabel,
  bool destructive = true,
}) async {
  final result = await showSkeddoGlassAlertFlow<bool>(
    context: context,
    steps: [
      SkeddoGlassAlertFlowStep<bool>(
        title: firstTitle,
        message: firstSubtitle,
        actions: [
          SkeddoGlassAlertFlowAction<bool>(
            label: firstActionLabel,
            isDestructive: destructive,
            nextStep: 1,
          ),
          const SkeddoGlassAlertFlowAction<bool>(label: 'Cancel'),
        ],
      ),
      SkeddoGlassAlertFlowStep<bool>(
        title: secondTitle,
        message: secondSubtitle,
        actions: [
          SkeddoGlassAlertFlowAction<bool>(
            label: secondActionLabel,
            isDestructive: destructive,
            result: true,
          ),
          const SkeddoGlassAlertFlowAction<bool>(label: 'Cancel', nextStep: 0),
        ],
      ),
    ],
  );
  return result == true;
}

/// Confirms and then moves an active event to Recently Deleted.
Future<void> confirmDeleteEvent(
  BuildContext context,
  ScheduledEvent event,
) async {
  final title =
      'Delete the event "${event.title.trim().isEmpty ? 'Untitled' : event.title.trim()}"?';
  final confirmed = await showTwoStepConfirmationSheet(
    context: context,
    firstTitle: title,
    firstSubtitle:
        'This event will move to Recently Deleted. You can recover it '
        'later or permanently delete it.',
    firstActionLabel: 'Delete Event',
    secondTitle: 'Are you sure?',
    secondSubtitle:
        'The event will be removed from the active schedule and moved '
        'to Recently Deleted.',
    secondActionLabel: 'Delete Event',
  );
  if (confirmed == true) {
    EventStore.instance.remove(event.id);
  }
}

/// Confirms and then moves an active event to Archived Items.
Future<void> confirmArchiveEvent(
  BuildContext context,
  ScheduledEvent event,
) async {
  final title =
      'Archive the event "${event.title.trim().isEmpty ? 'Untitled' : event.title.trim()}"?';
  final confirmed = await showTwoStepConfirmationSheet(
    context: context,
    firstTitle: title,
    firstSubtitle:
        'This event will move to Archived Items. You can recover it later.',
    firstActionLabel: 'Archive Event',
    secondTitle: 'Are you sure?',
    secondSubtitle:
        'The event will be removed from the active schedule and moved '
        'to Archived Items.',
    secondActionLabel: 'Archive Event',
  );
  if (confirmed == true) {
    EventStore.instance.archiveEvent(event.id);
  }
}

/// Confirms removing a section in two deliberate steps. Section deletion only
/// changes the section membership; the events remain in their category.
Future<bool?> confirmDeleteSection(
  BuildContext context, {
  required String sectionName,
}) async {
  final displayName = sectionName.trim().isEmpty
      ? 'New Section'
      : sectionName.trim();
  return showTwoStepConfirmationSheet(
    context: context,
    firstTitle: 'Delete the section "$displayName"?',
    firstSubtitle:
        'Events in "$displayName" will stay in this category and will '
        'no longer belong to this section. They will not be deleted.',
    firstActionLabel: 'Delete Section',
    secondTitle: 'Are you sure?',
    secondSubtitle:
        'The section will be removed. Its events will stay in this '
        'category and can be organized into another section.',
    secondActionLabel: 'Delete Section',
  );
}

/// Wraps the editor's actual leading close button in a GlassPopover. The button
/// remains the popover trigger, so its glass lens morphs into the confirmation
/// instead of rendering a second X above the editor.
class DiscardChangesPopoverAnchor extends StatefulWidget {
  const DiscardChangesPopoverAnchor({super.key, required this.child});

  final Widget child;

  @override
  State<DiscardChangesPopoverAnchor> createState() =>
      DiscardChangesPopoverAnchorState();
}

class DiscardChangesPopoverAnchorState
    extends State<DiscardChangesPopoverAnchor> {
  static const _triggerReturnTolerance = 0.5;
  static const _stableTriggerFramesRequired = 3;

  late final VoidCallback _dismissCallback;
  final GlobalKey _triggerKey = GlobalKey();
  final ValueNotifier<bool> _popoverOverlayClosing = ValueNotifier(false);
  VoidCallback? _togglePopover;
  Key _popoverKey = UniqueKey();
  Timer? _closePollTimer;
  Completer<bool?>? _confirmationCompleter;
  Offset? _triggerOrigin;
  Offset? _previousTriggerPosition;
  int _stableTriggerFrames = 0;
  String _entityLabel = 'item';
  bool _isNew = false;
  bool _popoverIsOpen = false;
  bool _isClosing = false;
  bool? _pendingResult;

  @override
  void initState() {
    super.initState();
    _dismissCallback = _dismissActivePopover;
  }

  @override
  void dispose() {
    _closePollTimer?.cancel();
    _popoverOverlayClosing.dispose();
    if (identical(_activeDiscardChangesSheetDismiss, _dismissCallback)) {
      _activeDiscardChangesSheetDismiss = null;
    }
    final completer = _confirmationCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    super.dispose();
  }

  Future<bool?> show({required String entityLabel, required bool isNew}) {
    final existing = _confirmationCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<bool?>();
    _confirmationCompleter = completer;
    _entityLabel = entityLabel;
    _isNew = isNew;
    _pendingResult = null;
    _popoverOverlayClosing.value = false;
    _popoverIsOpen = false;
    _isClosing = false;
    _triggerOrigin = null;
    _previousTriggerPosition = null;
    _stableTriggerFrames = 0;
    _closePollTimer?.cancel();
    _closePollTimer = null;
    _activeDiscardChangesSheetDismiss = _dismissCallback;
    setState(() {});

    // Let the updated message build before asking GlassPopover to measure its
    // content. Its triggerBuilder also refreshes the toggle callback each build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !identical(_confirmationCompleter, completer)) return;
      if (_isClosing) return;
      final togglePopover = _togglePopover;
      if (togglePopover == null) {
        _isClosing = true;
        _finishClose();
        return;
      }
      _popoverIsOpen = true;
      togglePopover();
    });

    return completer.future;
  }

  void _dismissActivePopover() {
    if (_isClosing) return;
    _isClosing = true;
    _pendingResult = null;
    if (_popoverIsOpen) {
      _togglePopover?.call();
    } else {
      _finishClose();
    }
    if (mounted) setState(() {});
  }

  void _onPopoverClosing() {
    _popoverIsOpen = false;
    _popoverOverlayClosing.value = true;
    if (!_isClosing) {
      _isClosing = true;
      _pendingResult = null;
    }
    _scheduleCloseFinish();
    if (mounted) setState(() {});
  }

  void _onPopoverOpened() {
    _popoverOverlayClosing.value = false;
    final renderObject = _triggerKey.currentContext?.findRenderObject();
    if (renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      _triggerOrigin = null;
      return;
    }
    _triggerOrigin = renderObject.localToGlobal(Offset.zero);
    _previousTriggerPosition = null;
    _stableTriggerFrames = 0;
  }

  void _scheduleCloseFinish() {
    if (_closePollTimer != null || !mounted) return;
    _closePollTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted || !_isClosing) {
        timer.cancel();
        _closePollTimer = null;
        return;
      }
      if (_popoverTriggerHasReturned()) {
        timer.cancel();
        _closePollTimer = null;
        _finishClose();
      } else {
        // Keep frame timing aligned with the package's spring. Once its own
        // overlay has hidden, a final few stable samples still confirm that
        // the real trigger has finished its recoil before completing discard.
        WidgetsBinding.instance.scheduleFrame();
      }
    });
  }

  bool _popoverTriggerHasReturned() {
    final origin = _triggerOrigin;
    final renderObject = _triggerKey.currentContext?.findRenderObject();
    if (origin == null ||
        renderObject is! RenderBox ||
        !renderObject.attached ||
        !renderObject.hasSize) {
      _stableTriggerFrames = 0;
      _previousTriggerPosition = null;
      return false;
    }

    // GlassPopover hides the real trigger while its morph is open, then hands
    // visibility back at the zero-crossing. Do not treat that first handoff as
    // completion: the spring still carries the trigger through its closing
    // recoil. Wait until the actual trigger is visible and back at rest.
    RenderObject? ancestor = renderObject;
    while (ancestor != null) {
      if (ancestor is RenderOpacity && ancestor.opacity < 0.999) {
        _stableTriggerFrames = 0;
        _previousTriggerPosition = null;
        return false;
      }
      ancestor = ancestor.parent;
    }

    final position = renderObject.localToGlobal(Offset.zero);
    final isAtOrigin =
        (position.dx - origin.dx).abs() <= _triggerReturnTolerance &&
        (position.dy - origin.dy).abs() <= _triggerReturnTolerance;
    if (!isAtOrigin) {
      _stableTriggerFrames = 0;
      _previousTriggerPosition = position;
      return false;
    }

    final previous = _previousTriggerPosition;
    final isStable =
        previous != null &&
        (position.dx - previous.dx).abs() <= _triggerReturnTolerance &&
        (position.dy - previous.dy).abs() <= _triggerReturnTolerance;
    _stableTriggerFrames = isStable ? _stableTriggerFrames + 1 : 0;
    _previousTriggerPosition = position;
    return _stableTriggerFrames >= _stableTriggerFramesRequired;
  }

  void _finishClose() {
    _closePollTimer?.cancel();
    _closePollTimer = null;
    _popoverIsOpen = false;
    if (identical(_activeDiscardChangesSheetDismiss, _dismissCallback)) {
      _activeDiscardChangesSheetDismiss = null;
    }

    final completer = _confirmationCompleter;
    final result = _pendingResult;
    _confirmationCompleter = null;
    _pendingResult = null;
    _popoverOverlayClosing.value = false;
    _entityLabel = 'item';
    _isNew = false;
    _isClosing = false;
    _popoverKey = UniqueKey();
    if (mounted) setState(() {});
    if (completer != null && !completer.isCompleted) {
      completer.complete(result);
    }
  }

  void _acceptDiscard(VoidCallback closePopover) {
    if (_isClosing) return;
    _pendingResult = true;
    _isClosing = true;
    closePopover();
    if (mounted) setState(() {});
  }

  Widget _buildPopoverContent(
    BuildContext context,
    VoidCallback closePopover,
    double sliderPosition,
  ) {
    if (_confirmationCompleter == null) return const SizedBox.shrink();
    final primary = resolveThemeColor(kPrimaryLabel, context);
    final message = _isNew
        ? 'Are you sure you want to discard this new $_entityLabel?'
        : 'Are you sure you want to discard your changes?';

    return ActionPanelScrollView(
      maxHeight: MediaQuery.sizeOf(context).height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          kDiscardConfirmationButtonEdgeGap,
          kDiscardConfirmationSheetTopInset,
          kDiscardConfirmationButtonEdgeGap,
          kDiscardConfirmationButtonEdgeGap,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: kDiscardConfirmationMessageHorizontalInset,
              ),
              child: Text(
                message,
                style: TextStyle(
                  inherit: false,
                  fontSize: 15,
                  fontFamily: kSFProText,
                  fontWeight: FontWeight.w400,
                  color: primary,
                ),
              ),
            ),
            const SizedBox(height: kDiscardConfirmationMessageButtonGap),
            LayoutBuilder(
              builder: (context, constraints) {
                final buttonWidth = constraints.maxWidth;
                final textScaler = MediaQuery.textScalerOf(context);
                final buttonTextStyle = _discardConfirmationButtonTextStyle(
                  context,
                );
                final textPainter = TextPainter(
                  text: TextSpan(
                    text: 'Discard Changes',
                    style: buttonTextStyle,
                  ),
                  textDirection: Directionality.of(context),
                  textScaler: textScaler,
                )..layout(maxWidth: math.max(0, buttonWidth - 32));
                final buttonHeight = math.max(48.0, textPainter.height + 26.0);
                return _DiscardConfirmationGlassButton(
                  width: buttonWidth,
                  height: buttonHeight,
                  textStyle: buttonTextStyle,
                  isClosing: _popoverOverlayClosing,
                  settings: skeddoPopoverButtonGlassSettingsFor(
                    CupertinoTheme.brightnessOf(context),
                    resolveThemeColor(kModalButtonBackground, context),
                    sliderPosition: sliderPosition,
                  ),
                  onPressed: () => _acceptDiscard(closePopover),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: appLiquidGlassOpacityNotifier,
    builder: (context, opacity, _) {
      final sliderPosition = liquidGlassSliderPositionForOpacity(opacity);
      final viewportSize = MediaQuery.sizeOf(context);
      final screenSize =
          device_screen_size.getDeviceScreenSize(context) ?? viewportSize;

      return GlassPopover(
        key: _popoverKey,
        triggerBuilder: (_, togglePopover) {
          _togglePopover = togglePopover;
          return KeyedSubtree(key: _triggerKey, child: widget.child);
        },
        contentBuilder: (popoverContext, closePopover) =>
            _buildPopoverContent(popoverContext, closePopover, sliderPosition),
        popoverWidth:
            screenSize.shortestSide * kDiscardConfirmationTopLeftWidthFraction,
        // Keep the app-specific offset here so regular/future GlassPopovers
        // remain exactly trigger-aligned by default.
        popoverOffset: const Offset(-4, -4),
        anchorGrowthToTrigger: true,
        keepTriggerHiddenDuringClose: true,
        popoverBorderRadius: kDiscardConfirmationPopoverCornerRadius,
        alignment: GlassMenuAlignment.topLeft,
        // GlassPopover adds the platform view insets itself when clamping. Do
        // not add AppWindowContentScope's landscape inset again here, or the
        // popover is pushed inward from its actual trigger.
        screenPadding: const EdgeInsets.all(12),
        settings: skeddoPopoverGlassSettingsFor(
          CupertinoTheme.brightnessOf(context),
          resolveThemeColor(kCardColor, context),
          sliderPosition: sliderPosition,
        ),
        quality: GlassQuality.premium,
        barrierDismissible: true,
        onClose: _onPopoverClosing,
        onOpen: _onPopoverOpened,
      );
    },
  );
}

/// Keeps the destructive action in the popover's content subtree so its
/// moving clip, foreground lens, and transition blur affect surface and label.
class _DiscardConfirmationGlassButton extends StatelessWidget {
  const _DiscardConfirmationGlassButton({
    required this.width,
    required this.height,
    required this.textStyle,
    required this.isClosing,
    required this.settings,
    required this.onPressed,
  });

  final double width;
  final double height;
  final TextStyle textStyle;
  final ValueListenable<bool> isClosing;
  final LiquidGlassSettings settings;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const ValueKey('discard-confirmation-glass-button-anchor'),
      width: width,
      height: height,
      child: ValueListenableBuilder<bool>(
        valueListenable: isClosing,
        child: GlassButton.custom(
          onTap: onPressed,
          width: width,
          height: height,
          shape: const LiquidRoundedSuperellipse(
            borderRadius: kDiscardConfirmationButtonCornerRadius,
          ),
          settings: settings,
          quality: GlassQuality.premium,
          useOwnLayer: true,
          style: GlassButtonStyle.filled,
          interactionScale: 1,
          stretch: 0,
          anchorStretch: false,
          glowColor: const Color(0x00000000),
          glowOpacity: 0,
          glowBlurRadius: 0,
          glowSpreadRadius: 0,
          ambientBaseLight: 0,
          enableInteractionColorFeedback: false,
          label: 'Discard Changes',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Center(
              child: Text(
                'Discard Changes',
                textAlign: TextAlign.center,
                style: textStyle,
              ),
            ),
          ),
        ),
        builder: (context, isClosing, button) =>
            IgnorePointer(ignoring: isClosing, child: button),
      ),
    );
  }
}

TextStyle _discardConfirmationButtonTextStyle(BuildContext context) =>
    TextStyle(
      inherit: false,
      fontSize: 17,
      fontFamily: kSFProText,
      fontWeight: FontWeight.w400,
      color: CupertinoColors.systemRed.resolveFrom(context),
    );
