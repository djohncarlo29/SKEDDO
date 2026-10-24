import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassButton, GlassButtonStyle, GlassQuality, LiquidOval;

import '../app_theme.dart';

/// Glass-package equivalent for the circular leading/trailing controls used
/// in modal sheet toolbars.
class ModalToolbarGlassButton extends StatefulWidget {
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

  /// The old button surface color is retained as an action-state signal.
  /// Checkmarks use an accent/category surface as their glyph tint, while a
  /// disabled-action surface disables the glass button without removing it.
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
  State<ModalToolbarGlassButton> createState() =>
      _ModalToolbarGlassButtonState();
}

class _ModalToolbarGlassButtonState extends State<ModalToolbarGlassButton> {
  Timer? _tapTimer;
  bool _canTap = true;

  void _handleTap() {
    if (!_canTap) return;
    _tapTimer?.cancel();
    if (widget.tapDelay == Duration.zero) {
      widget.onTap();
      return;
    }
    _tapTimer = Timer(widget.tapDelay, () {
      if (mounted && _canTap) widget.onTap();
    });
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resolvedSurface = resolveThemeColor(widget.surfaceColor, context);
    final disabledSurface = resolveThemeColor(kDisabledActionSurface, context);
    final defaultSurfaces = [
      resolveThemeColor(kModalCard, context).toARGB32(),
      resolveThemeColor(kCardColor, context).toARGB32(),
    ];
    final isCheckmark =
        widget.isCheckmark || widget.icon == CupertinoIcons.checkmark;
    final disabledBySurface =
        isCheckmark && resolvedSurface.toARGB32() == disabledSurface.toARGB32();
    _canTap = widget.enabled && !disabledBySurface;

    final followsActionColor =
        isCheckmark &&
        !disabledBySurface &&
        !defaultSurfaces.contains(resolvedSurface.toARGB32());
    final iconColor = followsActionColor
        ? resolvedSurface
        : resolveThemeColor(widget.iconColor, context);
    Widget icon =
        widget.child ??
        Icon(widget.icon, color: iconColor, size: widget.iconSize);
    if (followsActionColor && widget.child != null) {
      icon = ColorFiltered(
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        child: icon,
      );
    }
    final positionedIcon = widget.iconOffset == Offset.zero
        ? icon
        : Transform.translate(offset: widget.iconOffset, child: icon);
    final transformedIcon = widget.flipHorizontal
        ? Transform.scale(scaleX: -1, child: positionedIcon)
        : positionedIcon;
    final fallbackLabel = isCheckmark
        ? 'Confirm'
        : widget.icon == CupertinoIcons.chevron_left
        ? 'Back'
        : widget.icon == CupertinoIcons.xmark
        ? 'Close'
        : 'Action';
    return GlassButton.custom(
      label: widget.semanticLabel ?? fallbackLabel,
      onTap: _handleTap,
      width: widget.size,
      height: widget.size,
      shape: const LiquidOval(),
      quality: GlassQuality.premium,
      useOwnLayer: true,
      interactionScale: widget.peakScale,
      stretch: 0.15,
      enabled: _canTap,
      style: GlassButtonStyle.filled,
      child: Center(child: transformedIcon),
    );
  }
}
