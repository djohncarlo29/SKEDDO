import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../app_theme.dart';
import '../services/event_store.dart';
import 'action_panel.dart';
import 'app_window_content_boundary.dart';
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

/// Shows the confirmation used when an editor with unsaved changes is
/// dismissed. The X-mark entry point uses the sheet-attached placement; system
/// back and sheet drag use the centered placement.
Future<bool?> showDiscardChangesConfirmationSheet(
  BuildContext context, {
  required String entityLabel,
  required bool isNew,
  bool fromXmark = false,
}) async {
  final completer = Completer<bool?>();
  late OverlayEntry entry;
  final overlay = Overlay.of(context, rootOverlay: true);
  final isPresentedOverModalSheet =
      RoundedCupertinoSheetRoute.hasParentSheet(context);
  final horizontalInset =
      AppWindowContentScope.of(context).horizontalInset +
      (isPresentedOverModalSheet ? kModalConfirmationHorizontalInset : 16.0);
  VoidCallback? dismissActive;

  void close(bool? result) {
    if (completer.isCompleted) return;
    if (identical(_activeDiscardChangesSheetDismiss, dismissActive)) {
      _activeDiscardChangesSheetDismiss = null;
    }
    entry.remove();
    completer.complete(result);
  }

  entry = OverlayEntry(
    builder:
        (_) => _DiscardChangesSheetOverlay(
          entityLabel: entityLabel,
          isNew: isNew,
          fromXmark: fromXmark,
          horizontalInset: horizontalInset,
          isPresentedOverModalSheet: isPresentedOverModalSheet,
          onResult: close,
        ),
  );
  dismissActive = () => close(null);
  _activeDiscardChangesSheetDismiss = dismissActive;
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

class _DiscardChangesSheetOverlay extends StatelessWidget {
  final String entityLabel;
  final bool isNew;
  final bool fromXmark;
  final double horizontalInset;
  final bool isPresentedOverModalSheet;
  final void Function(bool?) onResult;

  const _DiscardChangesSheetOverlay({
    required this.entityLabel,
    required this.isNew,
    required this.fromXmark,
    required this.horizontalInset,
    required this.isPresentedOverModalSheet,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    final hasLandscapeInset =
        AppWindowContentScope.of(context).horizontalInset > 0.0;
    final primary = resolveThemeColor(kPrimaryLabel, context);
    final sheetBorder =
        CupertinoTheme.brightnessOf(context) == Brightness.dark
            ? BorderSide(
              color: resolveThemeColor(kTertiaryLabel, context),
              width: 0.5,
            )
            : null;
    final buttonDecor = ShapeDecoration(
      color: resolveThemeColor(kModalButtonBackground, context),
      shape: const BoundedSquircleStadiumBorder(
        radius: kDiscardConfirmationButtonCornerRadius,
      ),
      shadows: resolveThemeShadows(kCardShadow, context),
    );
    final viewportSize = MediaQuery.sizeOf(context);
    final sheetWidth = fromXmark
        ? viewportSize.shortestSide * kDiscardConfirmationTopLeftWidthFraction
        : double.infinity;
    final message = isNew
        ? 'Are you sure you want to discard this new $entityLabel?'
        : 'Are you sure you want to discard your changes?';

    final card = SizedBox(
      width: sheetWidth,
      child: GelBloomCard(
        scaleOrigin: fromXmark ? Alignment.topLeft : Alignment.center,
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
              GelBloomButton(
                peakScale: 1.06,
                tapDelay: const Duration(milliseconds: 120),
                onTap: () => onResult(true),
                child: Container(
                  width: double.infinity,
                  decoration: buttonDecor,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 16,
                  ),
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
              ),
              ],
            ),
          ),
        ),
      ),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (_, __) {
        dismissActiveDiscardChangesConfirmationSheet();
      },
      child: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onResult(null),
            child: const ColoredBox(
              color: Color(0x44000000),
              child: SizedBox.expand(),
            ),
          ),
          if (fromXmark)
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: EdgeInsets.only(
                  left:
                      AppWindowContentScope.of(context).horizontalInset +
                      kDiscardConfirmationTopLeftEdgeGap,
                  top:
                      MediaQuery.sizeOf(context).height *
                          kRoundedSheetTopGapRatio +
                      kDiscardConfirmationTopLeftEdgeGap,
                ),
                child: card,
              ),
            )
          else
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
                  child: card,
                ),
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