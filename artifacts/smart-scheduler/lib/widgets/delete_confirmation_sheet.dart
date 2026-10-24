import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassButton,
        GlassButtonStyle,
        GlassMenuAlignment,
        GlassPopover,
        LiquidRoundedSuperellipse;

import '../app_theme.dart';
import '../services/event_store.dart';
import 'action_panel.dart';
import 'app_window_content_boundary.dart';
import 'device_screen_size.dart' as device_screen_size;
import 'modal_toolbar_glass_button.dart';
import 'rounded_cupertino_sheet.dart';

VoidCallback? _activeDiscardChangesSheetDismiss;
bool _discardChangesBackConsumed = false;

/// Closes the active discard confirmation when a back event is delivered.
///
/// The confirmation is an OverlayEntry layered above an editor route, so both
/// the overlay's PopScope and the editor's PopScope can observe the same
/// system-back event. The short-lived consumed flag prevents the second
/// callback from immediately opening another confirmation sheet.
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
  required String entityLabel,
  required bool isNew,
}) async {
  final completer = Completer<bool?>();
  final popoverController = _DiscardPopoverController();
  final VoidCallback dismissPopover = popoverController.dismiss;
  late OverlayEntry entry;
  var overlayRemoved = false;
  final overlay = Overlay.of(context, rootOverlay: true);
  final isPresentedOverModalSheet =
      RoundedCupertinoSheetRoute.hasParentSheet(context);

  void complete(bool? result) {
    if (completer.isCompleted) return;
    completer.complete(result);
  }

  void removeOverlay() {
    if (overlayRemoved) return;
    overlayRemoved = true;
    if (identical(
      _activeDiscardChangesSheetDismiss,
      dismissPopover,
    )) {
      _activeDiscardChangesSheetDismiss = null;
    }
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder:
        (_) => _DiscardChangesSheetOverlay(
          entityLabel: entityLabel,
          isNew: isNew,
          isPresentedOverModalSheet: isPresentedOverModalSheet,
          controller: popoverController,
          onResult: complete,
          onCloseAnimationComplete: removeOverlay,
        ),
  );
  _activeDiscardChangesSheetDismiss = dismissPopover;
  overlay.insert(entry);
  return completer.future;
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

class _DiscardPopoverController {
  VoidCallback? _onDismiss;
  bool _dismissRequestedBeforeAttach = false;

  void attach(VoidCallback onDismiss) {
    _onDismiss = onDismiss;
    if (_dismissRequestedBeforeAttach) {
      _dismissRequestedBeforeAttach = false;
      onDismiss();
    }
  }

  void detach(VoidCallback onDismiss) {
    if (identical(_onDismiss, onDismiss)) _onDismiss = null;
  }

  void dismiss() {
    final callback = _onDismiss;
    if (callback == null) {
      _dismissRequestedBeforeAttach = true;
      return;
    }
    callback();
  }
}

class _DiscardChangesSheetOverlay extends StatefulWidget {
  final String entityLabel;
  final bool isNew;
  final bool isPresentedOverModalSheet;
  final _DiscardPopoverController controller;
  final void Function(bool?) onResult;
  final VoidCallback onCloseAnimationComplete;

  const _DiscardChangesSheetOverlay({
    required this.entityLabel,
    required this.isNew,
    required this.isPresentedOverModalSheet,
    required this.controller,
    required this.onResult,
    required this.onCloseAnimationComplete,
  });

  @override
  State<_DiscardChangesSheetOverlay> createState() =>
      _DiscardChangesSheetOverlayState();
}

class _DiscardChangesSheetOverlayState
    extends State<_DiscardChangesSheetOverlay> {
  static const _popoverTriggerSize = 40.0;
  static const _popoverCloseSettleDelay = Duration(milliseconds: 850);

  VoidCallback? _togglePopover;
  late final VoidCallback _dismissCallback;
  Timer? _removeTimer;
  bool _initialOpenScheduled = false;
  bool _popoverIsOpen = false;
  bool _isClosing = false;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _dismissCallback = _dismissActivePopover;
    widget.controller.attach(_dismissCallback);
  }

  @override
  void dispose() {
    _removeTimer?.cancel();
    widget.controller.detach(_dismissCallback);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
  }

  void _schedulePopoverOpen(VoidCallback togglePopover) {
    _togglePopover = togglePopover;
    if (_initialOpenScheduled) return;
    _initialOpenScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_isClosing) {
        _scheduleOverlayRemoval();
        return;
      }
      _popoverIsOpen = true;
      togglePopover();
    });
  }

  void _dismissActivePopover() {
    if (_isClosing) return;
    _isClosing = true;
    widget.onResult(null);
    if (_popoverIsOpen) {
      _togglePopover?.call();
    } else {
      _scheduleOverlayRemoval();
    }
    if (mounted) setState(() {});
  }

  void _onPopoverClosing() {
    _popoverIsOpen = false;
    if (!_isClosing) {
      _isClosing = true;
      widget.onResult(null);
    }
    _scheduleOverlayRemoval();
    if (mounted) setState(() {});
  }

  void _scheduleOverlayRemoval() {
    if (_removeTimer != null) return;
    _removeTimer = Timer(
      _reduceMotion ? Duration.zero : _popoverCloseSettleDelay,
      widget.onCloseAnimationComplete,
    );
  }

  void _acceptDiscard(VoidCallback closePopover) {
    if (_isClosing) return;
    _isClosing = true;
    widget.onResult(true);
    closePopover();
    if (mounted) setState(() {});
  }

  Widget _buildPopoverContent(
    BuildContext context,
    VoidCallback closePopover,
  ) {
    final primary = resolveThemeColor(kPrimaryLabel, context);
    final message = widget.isNew
        ? 'Are you sure you want to discard this new ${widget.entityLabel}?'
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
    final popoverWidth =
        screenSize.shortestSide * kDiscardConfirmationTopLeftWidthFraction;
    final horizontalInset =
        AppWindowContentScope.of(context).horizontalInset;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) {
        dismissActiveDiscardChangesConfirmationSheet();
      },
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _dismissActivePopover,
              child: const ColoredBox(color: Color(0x44000000)),
            ),
          ),
          Positioned(
            left: horizontalInset + kDiscardConfirmationTopLeftEdgeGap,
            top:
                MediaQuery.viewPaddingOf(context).top +
                kRoundedSheetSafeAreaGap +
                kDiscardConfirmationTopLeftEdgeGap,
            child: GlassPopover(
              triggerBuilder: (popoverContext, togglePopover) {
                _schedulePopoverOpen(togglePopover);
                return IgnorePointer(
                  ignoring: _isClosing,
                  child: ModalToolbarGlassButton(
                    icon: CupertinoIcons.xmark,
                    iconColor: resolveThemeColor(kPrimaryLabel, context),
                    surfaceColor: kModalCard,
                    size: _popoverTriggerSize,
                    iconSize: 20,
                    semanticLabel: 'Close discard confirmation',
                    onTap: togglePopover,
                  ),
                );
              },
              contentBuilder: _buildPopoverContent,
              popoverWidth: popoverWidth,
              popoverBorderRadius: widget.isPresentedOverModalSheet
                  ? kModalConfirmationSheetCornerRadius
                  : kConfirmationSheetCornerRadius,
              alignment: GlassMenuAlignment.topLeft,
              onClose: _onPopoverClosing,
            ),
          ),
        ],
      ),
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