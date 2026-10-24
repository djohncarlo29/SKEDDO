import 'package:flutter/cupertino.dart';

import '../app_theme.dart';

/// SKEDDO's captured Liquid Glass control for modal sheet toolbars.
///
/// The package GlassButton falls back to a frosted surface on renderers without
/// its premium shader. This wrapper keeps the app's established optical glass
/// renderer and shares action-state behavior across sheet toolbars.
class ModalToolbarGlassButton extends StatelessWidget {
  const ModalToolbarGlassButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.surfaceColor,
    required this.onTap,
    this.child,
    this.size = 40,
    this.iconSize = 20,
    this.isCheckmark = false,
    this.enabled = true,
    this.iconOffset = Offset.zero,
    this.flipHorizontal = false,
    this.tapDelay = Duration.zero,
    this.peakScale = 1.15,
    this.semanticLabel,
  });

  final IconData icon;
  final Color iconColor;

  /// The former button surface is retained as an action-state signal.
  /// Active checkmarks use its accent/category color for the glyph; disabled
  /// actions are made non-interactive while retaining the glass surface.
  final Color surfaceColor;
  final VoidCallback onTap;
  final Widget? child;
  final double size;
  final double iconSize;
  final bool isCheckmark;
  final bool enabled;
  final Offset iconOffset;
  final bool flipHorizontal;
  final Duration tapDelay;
  final double peakScale;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedSurface = resolveThemeColor(surfaceColor, context);
    final disabledSurface = resolveThemeColor(kDisabledActionSurface, context);
    final neutralSurfaces = [
      resolveThemeColor(kModalCard, context).toARGB32(),
      resolveThemeColor(kCardColor, context).toARGB32(),
    ];
    final checkmark = isCheckmark || icon == CupertinoIcons.checkmark;
    final disabledBySurface =
        checkmark && resolvedSurface.toARGB32() == disabledSurface.toARGB32();
    final canTap = enabled && !disabledBySurface;
    final followsActionColor =
        checkmark &&
        !disabledBySurface &&
        !neutralSurfaces.contains(resolvedSurface.toARGB32());
    final resolvedIconColor = followsActionColor
        ? resolvedSurface
        : resolveThemeColor(iconColor, context);

    Widget iconWidget =
        child ?? Icon(icon, color: resolvedIconColor, size: iconSize);
    if (followsActionColor && child != null) {
      iconWidget = ColorFiltered(
        colorFilter: ColorFilter.mode(resolvedIconColor, BlendMode.srcIn),
        child: iconWidget,
      );
    }

    final positionedIcon = iconOffset == Offset.zero
        ? iconWidget
        : Transform.translate(offset: iconOffset, child: iconWidget);
    final transformedIcon = flipHorizontal
        ? Transform.scale(scaleX: -1, child: positionedIcon)
        : positionedIcon;
    final fallbackLabel = checkmark
        ? 'Confirm'
        : icon == CupertinoIcons.chevron_left
        ? 'Back'
        : icon == CupertinoIcons.xmark
        ? 'Close'
        : 'Action';

    return Semantics(
      label: semanticLabel ?? fallbackLabel,
      button: true,
      enabled: canTap,
      child: IgnorePointer(
        ignoring: !canTap,
        child: StaticLiquidGlassActionButton(
          // Keep checkmark actions on the same neutral translucent glass as
          // the other toolbar controls; the action color belongs on the glyph.
          color: checkmark ? kModalCard : surfaceColor,
          size: size,
          isCheckmark: false,
          peakScale: peakScale,
          tapDelay: tapDelay,
          onTap: onTap,
          child: Center(child: transformedIcon),
        ),
      ),
    );
  }
}
