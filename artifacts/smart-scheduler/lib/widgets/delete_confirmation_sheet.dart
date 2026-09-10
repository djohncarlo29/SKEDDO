import 'dart:async';

import 'package:flutter/cupertino.dart';

import '../app_theme.dart';
import '../services/event_store.dart';

/// Shows the shared destructive confirmation surface used by event, category,
/// section, and permanent-delete actions.
Future<bool?> showDeleteConfirmationSheet(
  BuildContext context, {
  required String title,
  String? subtitle,
  String actionLabel = 'Delete',
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
          onResult: close,
        ),
  );
  overlay.insert(entry);
  return completer.future;
}

/// Confirms and then moves an active event to Recently Deleted.
Future<void> confirmDeleteEvent(
  BuildContext context,
  ScheduledEvent event,
) async {
  final confirmed = await showDeleteConfirmationSheet(
    context,
    title: 'Delete the event "${event.title.trim().isEmpty ? 'Untitled' : event.title.trim()}"?',
  );
  if (confirmed == true) {
    EventStore.instance.remove(event.id);
  }
}

class _DeleteConfirmationSheetOverlay extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String actionLabel;
  final void Function(bool?) onResult;

  const _DeleteConfirmationSheetOverlay({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
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
                        labelColor: CupertinoColors.destructiveRed,
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