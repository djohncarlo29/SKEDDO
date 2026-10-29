import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass
    show GlassButton, GlassButtonStyle, GlassQuality, LiquidOval;

import '../app_settings.dart';
import '../app_theme.dart';
import 'skeddo_glass_settings.dart';

/// Shared liquid_glass_widgets button for modal sheet toolbar actions.
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
    this.peakScale,
    this.disableTouchMotion = false,
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

  /// Fine pixel offset applied to the glyph inside the circle. A back
  /// chevron defaults to the app's optical-centering correction when this is
  /// left at [Offset.zero].
  final Offset iconOffset;
  final bool flipHorizontal;
  final Duration tapDelay;

  /// Optional fixed press scale. When null, use the package's native 17-point
  /// press growth, matching the pinned AppShell toolbar.
  final double? peakScale;

  /// Disables press scaling and drag-following deformation.
  ///
  /// Use only for controls that intentionally need a fixed shape; modal
  /// toolbar actions normally keep press scaling and stretch enabled.
  final bool disableTouchMotion;
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
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: appLiquidGlassOpacityNotifier,
    builder: (context, _, _) => _buildButton(context),
  );

  Widget _buildButton(BuildContext context) {
    final resolvedSurface = resolveThemeColor(widget.surfaceColor, context);
    final disabledSurface = resolveThemeColor(kDisabledActionSurface, context);
    final checkmark =
        widget.isCheckmark || widget.icon == CupertinoIcons.checkmark;
    final disabledBySurface =
        checkmark && resolvedSurface.toARGB32() == disabledSurface.toARGB32();
    _canTap = widget.enabled && !disabledBySurface;
    final interactionScale = widget.disableTouchMotion ? 1.0 : widget.peakScale;
    final stretch = widget.disableTouchMotion ? 0.0 : 0.5;
    final anchorStretch = !widget.disableTouchMotion;

    final neutralSurfaces = [
      resolveThemeColor(kModalCard, context).toARGB32(),
      resolveThemeColor(kCardColor, context).toARGB32(),
    ];
    final followsActionColor =
        checkmark && !neutralSurfaces.contains(resolvedSurface.toARGB32());
    final activeTintedCheckmark = followsActionColor && _canTap;
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
    final glassSettings = activeTintedCheckmark
        ? skeddoActiveCheckmarkGlassSettingsFor(brightness)
        : followsActionColor
        ? skeddoTintedActionGlassSettingsFor(brightness, resolvedSurface)
        : skeddoBottomBarGlassSettingsFor(brightness);
    final navigationGlassSettings = skeddoNavigationGlassSettingsFromShared(
      glassSettings,
    );
    final iconOffset = widget.iconOffset != Offset.zero
        ? widget.iconOffset
        : widget.icon == CupertinoIcons.chevron_left
        ? const Offset(-2, 0)
        : Offset.zero;
    final positionedIcon = iconOffset == Offset.zero
        ? iconWidget
        : Transform.translate(offset: iconOffset, child: iconWidget);
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

    final Widget renderedButton;
    if (activeTintedCheckmark) {
      // Keep all visual layers inside one transparent package GlassButton so
      // its LiquidStretch transforms the color fill, refraction, lighting, and
      // glyph together.
      final composite = Stack(
        fit: StackFit.expand,
        children: [
          ClipOval(
            child: ColoredBox(
              color: resolvedSurface.withValues(
                alpha: kSkeddoActiveCheckmarkFillOpacity,
              ),
            ),
          ),
          IgnorePointer(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: kSkeddoActiveCheckmarkRefractionOverlayOpacity,
                child: navigation_glass.GlassButton.custom(
                  onTap: _ignoreTap,
                  width: widget.size,
                  height: widget.size,
                  shape: const navigation_glass.LiquidOval(),
                  settings: skeddoNavigationGlassSettingsFromShared(
                    skeddoActiveCheckmarkRefractionSettingsFor(brightness),
                  ),
                  quality: navigation_glass.GlassQuality.premium,
                  useOwnLayer: true,
                  interactionScale: 1,
                  stretch: 0,
                  anchorStretch: false,
                  glowColor: const Color(0x00000000),
                  glowOpacity: 0,
                  glowBlurRadius: 0,
                  glowSpreadRadius: 0,
                  ambientBaseLight: 0,
                  isStationary: true,
                  excludeFromSemantics: true,
                  label: '',
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: ExcludeSemantics(
              child: navigation_glass.GlassButton.custom(
                onTap: _ignoreTap,
                width: widget.size,
                height: widget.size,
                shape: const navigation_glass.LiquidOval(),
                settings: navigationGlassSettings,
                quality: navigation_glass.GlassQuality.premium,
                useOwnLayer: true,
                interactionScale: 1,
                stretch: 0,
                anchorStretch: false,
                glowColor: const Color(0x00000000),
                glowOpacity: 0,
                glowBlurRadius: 0,
                glowSpreadRadius: 0,
                ambientBaseLight: 0,
                isStationary: true,
                excludeFromSemantics: true,
                label: '',
                child: const SizedBox.expand(),
              ),
            ),
          ),
          IgnorePointer(
            child: ExcludeSemantics(child: Center(child: transformedIcon)),
          ),
        ],
      );

      renderedButton = navigation_glass.GlassButton.custom(
        onTap: _handleTap,
        width: widget.size,
        height: widget.size,
        shape: const navigation_glass.LiquidOval(),
        quality: navigation_glass.GlassQuality.premium,
        interactionScale: interactionScale,
        stretch: stretch,
        anchorStretch: anchorStretch,
        resistance: 0.01,
        enabled: true,
        style: navigation_glass.GlassButtonStyle.transparent,
        glowOpacity: 0,
        glowBlurRadius: 0,
        glowSpreadRadius: 0,
        ambientBaseLight: 0,
        label: widget.semanticLabel ?? fallbackLabel,
        child: composite,
      );
    } else {
      renderedButton = navigation_glass.GlassButton.custom(
        onTap: _handleTap,
        width: widget.size,
        height: widget.size,
        shape: const navigation_glass.LiquidOval(),
        settings: navigationGlassSettings,
        quality: navigation_glass.GlassQuality.premium,
        useOwnLayer: true,
        interactionScale: interactionScale,
        stretch: stretch,
        anchorStretch: anchorStretch,
        enabled: checkmark || _canTap,
        glowColor: checkmark && !_canTap ? const Color(0x00000000) : null,
        label: widget.semanticLabel ?? fallbackLabel,
        child: transformedIcon,
      );
    }
    if (checkmark && !_canTap) {
      return Semantics(
        container: true,
        button: true,
        enabled: false,
        label: widget.semanticLabel ?? fallbackLabel,
        child: ExcludeSemantics(child: renderedButton),
      );
    }
    return renderedButton;
  }
}

void _ignoreTap() {}
