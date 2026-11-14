import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import 'rounded_cupertino_sheet.dart';
import 'skeddo_glass_settings.dart';

/// Presents SKEDDO's scoped iOS 26/27-style alert with the shared glass curve.
Future<T?> showSkeddoGlassAlertDialog<T>({
  required BuildContext context,
  required String title,
  String? message,
  required List<GlassDialogAction> Function(BuildContext dialogContext)
  actionsBuilder,
  bool barrierDismissible = true,
}) {
  final sharedSettings = skeddoModalSheetPickerGlassSettingsFor(
    CupertinoTheme.brightnessOf(context),
  );
  final dialogSettings = skeddoNavigationGlassSettingsFromShared(
    sharedSettings,
  );
  return showSafeCupertinoDialog<T>(
    context: context,
    barrierDismissible: barrierDismissible,
    barrierColor: const Color(0x44000000),
    builder: (dialogContext) => SkeddoGlassAlertPlatter(
      title: title,
      message: message,
      actions: actionsBuilder(dialogContext),
      settings: dialogSettings,
      quality: GlassQuality.premium,
    ),
  );
}

/// The iOS 26/27 alert-platter layout scoped to SKEDDO confirmations.
class SkeddoGlassAlertPlatter extends StatelessWidget {
  const SkeddoGlassAlertPlatter({
    required this.actions,
    super.key,
    this.title,
    this.message,
    this.settings,
    this.quality,
    this.maxWidth = 320,
  });

  final String? title;
  final String? message;
  final List<GlassDialogAction> actions;
  final LiquidGlassSettings? settings;
  final GlassQuality? quality;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final hasHeader = title != null || message != null;
    return AnimatedPadding(
      padding: MediaQuery.viewInsetsOf(context),
      duration: const Duration(milliseconds: 100),
      curve: Curves.decelerate,
      child: MediaQuery.removeViewInsets(
        context: context,
        removeLeft: true,
        removeTop: true,
        removeRight: true,
        removeBottom: true,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth ?? 320),
              child: Semantics(
                scopesRoute: true,
                namesRoute: true,
                explicitChildNodes: true,
                label: title ?? 'Confirmation',
                child: GlassContainer.card(
                  useOwnLayer: true,
                  settings: settings,
                  quality: quality,
                  shape: const LiquidRoundedSuperellipse(borderRadius: 34),
                  padding: EdgeInsets.zero,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (hasHeader)
                          Padding(
                            padding: const EdgeInsetsDirectional.fromSTEB(
                              30,
                              22,
                              30,
                              4.33,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (title != null)
                                  SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      title!,
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w600,
                                        color: CupertinoColors.label
                                            .resolveFrom(context),
                                      ),
                                    ),
                                  ),
                                if (title != null && message != null)
                                  const SizedBox(height: 20.33),
                                if (message != null)
                                  SizedBox(
                                    width: double.infinity,
                                    child: Text(
                                      message!,
                                      style: TextStyle(
                                        fontSize: 15,
                                        color: CupertinoColors.secondaryLabel
                                            .resolveFrom(context),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        Padding(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            hasHeader ? 16 : 22,
                            16,
                            16,
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) =>
                                _buildActions(context, constraints.maxWidth),
                          ),
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
    );
  }

  Widget _buildActions(BuildContext context, double width) {
    if (actions.length <= 2 && _labelsFitSideBySide(context, width)) {
      return Row(
        children: [
          for (var index = 0; index < actions.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(child: _SkeddoAlertActionButton(action: actions[index])),
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < actions.length; index++)
          Padding(
            padding: EdgeInsets.only(top: index > 0 ? 8 : 0),
            child: _SkeddoAlertActionButton(action: actions[index]),
          ),
      ],
    );
  }

  bool _labelsFitSideBySide(BuildContext context, double width) {
    if (actions.length < 2) return true;
    final labelWidth = (width - 8) / 2 - 32;
    final baseStyle = DefaultTextStyle.of(context).style;
    for (final action in actions) {
      final painter = TextPainter(
        text: TextSpan(
          text: action.label,
          style: baseStyle.merge(
            TextStyle(
              fontSize: 17,
              fontWeight: action.isPrimary ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
        maxLines: 1,
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout();
      final fits = painter.width <= labelWidth;
      painter.dispose();
      if (!fits) return false;
    }
    return true;
  }
}

class _SkeddoAlertActionButton extends StatefulWidget {
  const _SkeddoAlertActionButton({required this.action});

  final GlassDialogAction action;

  @override
  State<_SkeddoAlertActionButton> createState() =>
      _SkeddoAlertActionButtonState();
}

class _SkeddoAlertActionButtonState extends State<_SkeddoAlertActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final action = widget.action;
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final fillAlpha = isDark
        ? (_pressed ? 0.20 : 0.115)
        : (_pressed ? 0.25 : 0.15);
    final fill = isDark
        ? CupertinoColors.white.withValues(alpha: fillAlpha)
        : CupertinoColors.black.withValues(alpha: fillAlpha);
    final textColor = action.isDestructive
        ? CupertinoColors.systemRed.resolveFrom(context)
        : CupertinoColors.label.resolveFrom(context);
    final wrapsAtAccessibilitySize =
        MediaQuery.textScalerOf(context).scale(14) > 14 * 1.4;
    final ShapeBorder shape = wrapsAtAccessibilitySize
        ? const RoundedSuperellipseBorder(
            borderRadius: BorderRadius.all(Radius.circular(32)),
          )
        : const StadiumBorder();

    return Semantics(
      button: true,
      label: action.label,
      onTap: action.onPressed,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: action.onPressed,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedContainer(
          duration: _pressed
              ? Duration.zero
              : const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          constraints: const BoxConstraints(minHeight: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: ShapeDecoration(color: fill, shape: shape),
          child: Text(
            action.label,
            maxLines: wrapsAtAccessibilitySize ? null : 1,
            overflow: wrapsAtAccessibilitySize ? null : TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: textColor,
              fontSize: 17,
              fontWeight: action.isPrimary ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
