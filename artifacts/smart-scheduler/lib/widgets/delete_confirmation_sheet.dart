import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassButton,
        GlassButtonStyle,
        GlassMenuAlignment,
        GlassPopover,
        GlassQuality,
        LiquidRoundedSuperellipse;

import '../app_theme.dart';
import '../services/event_store.dart';
import 'action_panel.dart';
import 'app_window_content_boundary.dart';
import 'device_screen_size.dart' as device_screen_size;
import 'rounded_cupertino_sheet.dart';
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
}) async {
  final completer = Completer<bool?>();
  late OverlayEntry entry;
  final overlay = Overlay.of(context, rootOverlay: true);
  final isPresentedOverModalSheet =
      RoundedCupertinoSheetRoute.hasParentSheet(context);
  final horizontalInset =
      AppWindowContentScope.of(context).horizontalInset +
      (isPresentedOverModalSheet ? kModalConfirmationHorizontalInset : 16.0);

  void close(bool? result) {
    if (completer.isCompleted) return;
    entry.remove();
    completer.complete(result);
  }

  entry = OverlayEntry(
    builder:
        (_) => _DeleteConfirmationSheetOverlay(
          title: title,
          subtitle: subtitle,
          actionLabel: actionLabel,
          destructive: destructive,
          accentAction: accentAction,
          horizontalInset: horizontalInset,
           isPresentedOverModalSheet: isPresentedOverModalSheet,
          onResult: close,
        ),
  );
  overlay.insert(entry);
  return completer.future;
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

/// Runs a two-step confirmation. Cancelling the second step returns to the
/// first step; cancelling the first step dismisses the flow.
Future<bool> showTwoStepConfirmationSheet({
  required Future<bool?> Function() firstStep,
  required Future<bool?> Function() secondStep,
}) async {
  while (true) {
    final firstResult = await firstStep();
    if (firstResult != true) return false;

    final secondResult = await secondStep();
    if (secondResult == true) return true;
  }
}

/// Confirms and then moves an active event to Recently Deleted.
Future<void> confirmDeleteEvent(
  BuildContext context,
  ScheduledEvent event,
) async {
  final title =
      'Delete the event "${event.title.trim().isEmpty ? 'Untitled' : event.title.trim()}"?';
  final confirmed = await showTwoStepConfirmationSheet(
    firstStep:
        () => showDeleteConfirmationSheet(
          context,
          title: title,
          subtitle:
              'This event will move to Recently Deleted. You can recover it '
              'later or permanently delete it.',
          actionLabel: 'Delete Event',
        ),
    secondStep:
        () => showDeleteConfirmationSheet(
          context,
          title: 'Are you sure?',
          subtitle:
              'The event will be removed from the active schedule and moved '
              'to Recently Deleted.',
          actionLabel: 'Delete Event',
        ),
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
    firstStep:
        () => showArchiveConfirmationSheet(
          context,
          title: title,
          subtitle:
              'This event will move to Archived Items. You can recover it '
              'later.',
          actionLabel: 'Archive Event',
        ),
    secondStep:
        () => showArchiveConfirmationSheet(
          context,
          title: 'Are you sure?',
          subtitle:
              'The event will be removed from the active schedule and moved '
              'to Archived Items.',
          actionLabel: 'Archive Event',
        ),
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
  final displayName =
      sectionName.trim().isEmpty ? 'New Section' : sectionName.trim();
  return showTwoStepConfirmationSheet(
    firstStep:
        () => showDeleteConfirmationSheet(
          context,
          title: 'Delete the section "$displayName"?',
          subtitle:
              'Events in "$displayName" will stay in this category and will '
              'no longer belong to this section. They will not be deleted.',
          actionLabel: 'Delete Section',
        ),
    secondStep:
        () => showDeleteConfirmationSheet(
          context,
          title: 'Are you sure?',
          subtitle:
              'The section will be removed. Its events will stay in this '
              'category and can be organized into another section.',
          actionLabel: 'Delete Section',
        ),
  );
}

/// Wraps the editor's actual leading close button in a GlassPopover. The button
/// remains the popover trigger, so its glass lens morphs into the confirmation
/// instead of rendering a second X above the editor.
class DiscardChangesPopoverAnchor extends StatefulWidget {
  const DiscardChangesPopoverAnchor({
    super.key,
    required this.child,
  });

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
    if (identical(
      _activeDiscardChangesSheetDismiss,
      _dismissCallback,
    )) {
      _activeDiscardChangesSheetDismiss = null;
    }
    final completer = _confirmationCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(null);
    }
    super.dispose();
  }

  Future<bool?> show({
    required String entityLabel,
    required bool isNew,
  }) {
    final existing = _confirmationCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<bool?>();
    _confirmationCompleter = completer;
    _entityLabel = entityLabel;
    _isNew = isNew;
    _pendingResult = null;
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
    if (!_isClosing) {
      _isClosing = true;
      _pendingResult = null;
    }
    _scheduleCloseFinish();
    if (mounted) setState(() {});
  }

  void _onPopoverOpened() {
    final renderObject =
        _triggerKey.currentContext?.findRenderObject();
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
    _closePollTimer = Timer.periodic(const Duration(milliseconds: 16), (
      timer,
    ) {
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
    final isStable = previous != null &&
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
    if (identical(
      _activeDiscardChangesSheetDismiss,
      _dismissCallback,
    )) {
      _activeDiscardChangesSheetDismiss = null;
    }

    final completer = _confirmationCompleter;
    final result = _pendingResult;
    _confirmationCompleter = null;
    _pendingResult = null;
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
                  fontSize: 16,
                  fontFamily: kSFProText,
                  fontWeight: FontWeight.w400,
                  color: primary,
                  letterSpacing: kTracking16,
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: kDiscardConfirmationMessageButtonGap),
            GlassButton.custom(
              onTap: () => _acceptDiscard(closePopover),
              height: 57,
              shape: const LiquidRoundedSuperellipse(
                borderRadius: kDiscardConfirmationButtonCornerRadius,
              ),
              style: GlassButtonStyle.prominent,
              interactionScale: 1.06,
              label: 'Discard Changes',
              child: Center(
                child: Text(
                  'Discard Changes',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    inherit: false,
                    fontSize: 17,
                    fontFamily: kSFProText,
                    fontWeight: FontWeight.w500,
                    color: CupertinoColors.destructiveRed,
                    letterSpacing: kTracking17,
                    height: kLineHeight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewportSize = MediaQuery.sizeOf(context);
    final screenSize =
        device_screen_size.getDeviceScreenSize(context) ?? viewportSize;
    final horizontalInset =
        AppWindowContentScope.of(context).horizontalInset;
    final isPresentedOverModalSheet =
        RoundedCupertinoSheetRoute.hasParentSheet(context);

    return GlassPopover(
      key: _popoverKey,
      triggerBuilder: (_, togglePopover) {
        _togglePopover = togglePopover;
        return KeyedSubtree(key: _triggerKey, child: widget.child);
      },
      contentBuilder: _buildPopoverContent,
      popoverWidth:
          screenSize.shortestSide * kDiscardConfirmationTopLeftWidthFraction,
      popoverBorderRadius: isPresentedOverModalSheet
          ? kModalConfirmationSheetCornerRadius
          : kConfirmationSheetCornerRadius,
      alignment: GlassMenuAlignment.topLeft,
      screenPadding: EdgeInsets.fromLTRB(
        horizontalInset + 12,
        12,
        horizontalInset + 12,
        12,
      ),
      settings: skeddoBottomBarGlassSettingsFor(
        CupertinoTheme.brightnessOf(context),
      ),
      quality: GlassQuality.premium,
      barrierDismissible: true,
      onClose: _onPopoverClosing,
      onOpen: _onPopoverOpened,
    );
  }
}

class _DeleteConfirmationSheetOverlay extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String actionLabel;
  final bool destructive;
  final bool accentAction;
  final double horizontalInset;
  final bool isPresentedOverModalSheet;
  final void Function(bool?) onResult;

  const _DeleteConfirmationSheetOverlay({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.destructive,
    required this.accentAction,
    required this.horizontalInset,
    required this.isPresentedOverModalSheet,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    final hasLandscapeInset =
        AppWindowContentScope.of(context).horizontalInset > 0.0;
    final primary = resolveThemeColor(kPrimaryLabel, context);
    final secondary = resolveThemeColor(kSecondaryLabel, context);
    final buttonDecor = ShapeDecoration(
      color: resolveThemeColor(kModalButtonBackground, context),
      shape: const BoundedSquircleStadiumBorder(
        radius: kConfirmationButtonCornerRadius,
      ),
      shadows: resolveThemeShadows(kCardShadow, context),
    );
    final sheetBorder =
        CupertinoTheme.brightnessOf(context) == Brightness.dark
            ? BorderSide(
              color: resolveThemeColor(kTertiaryLabel, context),
              width: 0.5,
            )
            : null;

    Widget button({
      required String label,
      required Color labelColor,
      required VoidCallback onTap,
    }) {
      return GelBloomButton(
        peakScale: 1.06,
        tapDelay: const Duration(milliseconds: 120),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          decoration: buttonDecor,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
          child: Center(
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                inherit: false,
                fontSize: 17,
                fontFamily: kSFProText,
                fontWeight: FontWeight.w500,
                color: labelColor,
                letterSpacing: kTracking17,
                height: kLineHeight,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => onResult(null),
          child: const ColoredBox(
            color: Color(0x44000000),
            child: SizedBox.expand(),
          ),
        ),
        Align(
          alignment: Alignment.center,
          child: SafeArea(
            left: !hasLandscapeInset,
            right: !hasLandscapeInset,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalInset,
                vertical: 16,
              ),
              child: SizedBox(
                width: double.infinity,
                child: GelBloomCard(
                  scaleOrigin: Alignment.center,
                  fillOpacity: 0.82,
                  shadowOpacity: 0.26,
                  border: sheetBorder,
                  shape: BoundedSquircleStadiumBorder(
                    radius: isPresentedOverModalSheet
                        ? kModalConfirmationSheetCornerRadius
                        : kConfirmationSheetCornerRadius,
                    side: sheetBorder ?? BorderSide.none,
                  ),
                  child: ActionPanelScrollView(
                    maxHeight: MediaQuery.sizeOf(context).height,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                      child: Column(
                       mainAxisSize: MainAxisSize.min,
                       crossAxisAlignment: CrossAxisAlignment.stretch,
                       children: [
                        Text(
                          title,
                          style: TextStyle(
                            inherit: false,
                            fontSize: 18,
                            fontFamily: kSFProText,
                            fontWeight: FontWeight.w600,
                            color: primary,
                            letterSpacing: kTracking16,
                          ),
                        ),
                        if (subtitle != null && subtitle!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Text(
                            subtitle!,
                            style: TextStyle(
                              inherit: false,
                              fontSize: 15,
                              fontFamily: kSFProText,
                              fontWeight: FontWeight.w400,
                              color: secondary,
                              height: 1.5,
                              letterSpacing: kTracking16,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        button(
                          label: actionLabel,
                          labelColor:
                              destructive
                                  ? CupertinoColors.destructiveRed
                                  : accentAction
                                  ? resolveAccentColor(context)
                                  : primary,
                          onTap: () => onResult(true),
                        ),
                        const SizedBox(height: 8),
                        button(
                          label: 'Cancel',
                          labelColor: primary,
                          onTap: () => onResult(null),
                        ),
                        ],
                      ),
                    ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}