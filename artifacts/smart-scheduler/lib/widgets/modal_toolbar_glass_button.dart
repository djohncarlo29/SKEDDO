import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassIconButton, GlassIconButtonShape, GlassQuality;

import '../app_theme.dart';
import 'skeddo_glass_settings.dart';

/// Shared package GlassIconButton for modal sheet toolbar actions.
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
    final checkmark =
        widget.isCheckmark || widget.icon == CupertinoIcons.checkmark;
    final disabledBySurface =
        checkmark && resolvedSurface.toARGB32() == disabledSurface.toARGB32();
    _canTap = widget.enabled && !disabledBySurface;

    final neutralSurfaces = [
      resolveThemeColor(kModalCard, context).toARGB32(),
      resolveThemeColor(kCardColor, context).toARGB32(),
    ];
    final followsActionColor =
        checkmark &&
        !neutralSurfaces.contains(resolvedSurface.toARGB32());
    final iconColor = followsActionColor
        ? CupertinoColors.white
        : resolveThemeColor(widget.iconColor, context);

    Widget iconWidget =
        widget.child ??
        Icon(widget.icon, color: iconColor, size: widget.iconSize);
    if (checkmark && widget.child != null) {
      iconWidget = ColorFiltered(
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
        child: iconWidget,
      );
    }

    final brightness = CupertinoTheme.brightnessOf(context);
    final glassSettings = followsActionColor
        ? skeddoTintedActionGlassSettingsFor(brightness, resolvedSurface)
        : skeddoBottomBarGlassSettingsFor(brightness);
    final positionedIcon = widget.iconOffset == Offset.zero
        ? iconWidget
        : Transform.translate(offset: widget.iconOffset, child: iconWidget);
    final transformedIcon = widget.flipHorizontal
        ? Transform.scale(scaleX: -1, child: positionedIcon)
        : positionedIcon;
    final fallbackLabel = checkmark
        ? 'Confirm'
        : widget.icon == CupertinoIcons.chevron_left
        ? 'Back'
        : widget.icon == CupertinoIcons.xmark
        ? 'Close'
        : 'Action';

    final button = GlassIconButton(
      icon: transformedIcon,
      // Keep checkmark glass fully styled even when its action is unavailable;
      // _handleTap still blocks the action while the package renders it active.
      onPressed: checkmark ? _handleTap : (_canTap ? _handleTap : null),
      size: widget.size,
      iconSize: widget.iconSize,
      shape: GlassIconButtonShape.circle,
      settings: glassSettings,
      quality: GlassQuality.premium,
      useOwnLayer: true,
      interactionScale: widget.peakScale,
      semanticLabel: widget.semanticLabel ?? fallbackLabel,
    );
    if (checkmark && !_canTap) {
      return Semantics(
        container: true,
        button: true,
        enabled: false,
        label: widget.semanticLabel ?? fallbackLabel,
        child: ExcludeSemantics(child: button),
      );
    }
    return button;
  }
}
