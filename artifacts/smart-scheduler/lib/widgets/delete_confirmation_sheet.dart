import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../app_theme.dart';
import '../services/event_store.dart';

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

/// Confirms and then moves an active event to Recently Deleted.
Future<void> confirmDeleteEvent(
  BuildContext context,
  ScheduledEvent event,
) async {
  final title =
      'Delete the event "${event.title.trim().isEmpty ? 'Untitled' : event.title.trim()}"?';
  final firstStep = await showDeleteConfirmationSheet(
    context,
    title: title,
    subtitle:
        'This event will move to Recently Deleted. You can recover it later '
        'or permanently delete it.',
    actionLabel: 'Delete Event',
  );
  if (firstStep != true) return;

  final confirmed = await showDeleteConfirmationSheet(
    context,
    title: 'Are you sure?',
    subtitle:
        'The event will be removed from the active schedule and moved to '
        'Recently Deleted.',
    actionLabel: 'Delete Event',
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
  final firstStep = await showArchiveConfirmationSheet(
    context,
    title: title,
    subtitle:
        'This event will move to Archived Items. You can recover it later.',
    actionLabel: 'Archive Event',
  );
  if (firstStep != true) return;

  final confirmed = await showArchiveConfirmationSheet(
    context,
    title: 'Are you sure?',
    subtitle:
        'The event will be removed from the active schedule and moved to '
        'Archived Items.',
    actionLabel: 'Archive Event',
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
  final firstStep = await showDeleteConfirmationSheet(
    context,
    title: 'Delete the section "$displayName"?',
    subtitle:
        'Events in "$displayName" will stay in this category and will no '
        'longer belong to this section. They will not be deleted.',
    actionLabel: 'Delete Section',
  );
  if (firstStep != true) return false;

  return showDeleteConfirmationSheet(
    context,
    title: 'Are you sure?',
    subtitle:
        'The section will be removed. Its events will stay in this category '
        'and can be organized into another section.',
    actionLabel: 'Delete Section',
  );
}

class _DeleteConfirmationSheetOverlay extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String actionLabel;
  final bool destructive;
  final bool accentAction;
  final void Function(bool?) onResult;

  const _DeleteConfirmationSheetOverlay({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.destructive,
    required this.accentAction,
    required this.onResult,
  });

  @override
  Widget build(BuildContext context) {
    final primary = resolveThemeColor(kPrimaryLabel, context);
    final secondary = resolveThemeColor(kSecondaryLabel, context);
    final buttonDecor = ShapeDecoration(
      color: resolveThemeColor(kModalButtonBackground, context),
      shape: const BoundedSquircleStadiumBorder(),
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
          clipBehavior: Clip.antiAlias,
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
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: GelBloomCard(
                scaleOrigin: Alignment.center,
                fillOpacity: 0.82,
                shadowOpacity: 0.26,
                border: sheetBorder,
                shape: BoundedSquircleStadiumBorder(
                  radius: kLargeModalSheetCornerRadius,
                  side: sheetBorder ?? BorderSide.none,
                ),
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
      ],
    );
  }
}