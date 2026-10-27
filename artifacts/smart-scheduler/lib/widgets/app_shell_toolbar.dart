import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass
    show GlassAppBar, GlassBarItem, GlassBarItemBackground;

import '../app_settings.dart';
import '../app_theme.dart';
import 'skeddo_glass_settings.dart';

const Object appShellPrimaryToolbarItemId = 'app-shell-primary-toolbar';

enum AppShellToolbarGlyph { menu, close, back }

/// A route-registered toolbar item using the app's slider-driven glass values.
///
/// Each destination builds this same item with [appShellPrimaryToolbarItemId],
/// allowing GlassNavigationShell to retain the button while its route changes.
class AppShellPinnedToolbar extends StatelessWidget {
  const AppShellPinnedToolbar({
    super.key,
    required this.glyph,
    required this.onTap,
    required this.semanticLabel,
    required this.horizontalInset,
    this.color,
    this.opacity = 1,
    this.buttonSize = 40,
    this.toolbarHeight = 60,
    this.actions = const <navigation_glass.GlassBarItem>[],
  });

  final AppShellToolbarGlyph glyph;
  final VoidCallback onTap;
  final String semanticLabel;
  final double horizontalInset;
  final Color? color;
  final double opacity;
  final double buttonSize;
  final double toolbarHeight;

  /// Additional items join this shared cluster and turn its circle into a pill.
  final List<navigation_glass.GlassBarItem> actions;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([
      appAccentNotifier,
      appLiquidGlassOpacityNotifier,
    ]),
    builder: (context, _) => _buildToolbar(context),
  );

  Widget _buildToolbar(BuildContext context) {
    final color = this.color ?? resolveAccentColor(context);
    final visibility = opacity.clamp(0.0, 1.0).toDouble();
    final settings = skeddoPinnedNavigationGlassSettingsFor(
      MediaQuery.platformBrightnessOf(context),
      visibility: visibility,
    );
    final item = navigation_glass.GlassBarItem.icon(
      id: appShellPrimaryToolbarItemId,
      label: semanticLabel,
      enabled: visibility > 0.01,
      background: navigation_glass.GlassBarItemBackground.shared,
      icon: Opacity(
        opacity: visibility,
        child: _AppShellMenuGlyph(state: glyph, color: color),
      ),
      onTap: onTap,
    );

    return navigation_glass.GlassAppBar.pinned(
      title: const SizedBox.shrink(),
      leading: <navigation_glass.GlassBarItem>[item],
      actions: actions,
      backButton: false,
      buttonSize: buttonSize,
      toolbarHeight: toolbarHeight,
      centerTitle: false,
      padding: EdgeInsets.symmetric(horizontal: horizontalInset),
      buttonSettings: settings,
    );
  }
}

class _AppShellMenuGlyph extends StatelessWidget {
  const _AppShellMenuGlyph({required this.state, required this.color});

  final AppShellToolbarGlyph state;
  final Color color;

  Widget _buildGlyph(double progress) {
    final double topY;
    final double topAngle;
    final double bottomY;
    final double bottomAngle;
    final double strokeWidth;

    if (progress >= 0) {
      final t = progress.clamp(0.0, 1.0);
      topY = -4.5 + 4.5 * t;
      topAngle = 0.7853981633974483 * t;
      bottomY = 4.5 - 4.5 * t;
      bottomAngle = -0.7853981633974483 * t;
      strokeWidth = 22;
    } else {
      final t = (-progress).clamp(0.0, 1.0);
      topY = -4.5 + 0.64 * t;
      topAngle = -0.6981317007977318 * t;
      bottomY = 4.5 - 0.64 * t;
      bottomAngle = 0.6981317007977318 * t;
      strokeWidth = 22 - 10 * t;
    }

    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(0, topY),
            child: Transform.rotate(
              angle: topAngle,
              child: _MenuStroke(width: strokeWidth, color: color),
            ),
          ),
          Transform.translate(
            offset: Offset(0, bottomY),
            child: Transform.rotate(
              angle: bottomAngle,
              child: _MenuStroke(width: strokeWidth, color: color),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final target = switch (state) {
      AppShellToolbarGlyph.menu => 0.0,
      AppShellToolbarGlyph.close => 1.0,
      AppShellToolbarGlyph.back => -1.0,
    };
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: target),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      builder: (context, progress, _) => _buildGlyph(progress),
    );
  }
}

class _MenuStroke extends StatelessWidget {
  const _MenuStroke({required this.width, required this.color});

  final double width;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: 1.6,
    decoration: ShapeDecoration(
      color: color,
      shape: const BoundedSquircleStadiumBorder(radius: kSquircleStadiumRadius),
    ),
  );
}
