import 'package:flutter/cupertino.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass
    show GlassAppBar, GlassBarItem, GlassBarItemBackground;

import '../app_settings.dart';
import '../app_theme.dart';
import 'rounded_cupertino_sheet.dart';
import 'app_shell_navigation_scope.dart';
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
    this.showPrimary = true,
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
  final bool showPrimary;

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      appAccentNotifier,
      appLiquidGlassOpacityNotifier,
    ];
    final routeChanges = AppShellNavigationScope.routeChangesOf(context);
    if (routeChanges != null) listenables.add(routeChanges);
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) => _buildToolbar(context),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    final color = this.color ?? resolveAccentColor(context);
    final visibility = opacity.clamp(0.0, 1.0).toDouble();
    final settings = skeddoPinnedNavigationGlassSettingsFor(
      MediaQuery.platformBrightnessOf(context),
      visibility: visibility,
    );
    final item = showPrimary
        ? navigation_glass.GlassBarItem.icon(
            id: appShellPrimaryToolbarItemId,
            label: semanticLabel,
            enabled: visibility > 0.01,
            background: navigation_glass.GlassBarItemBackground.shared,
            icon: _AppShellToolbarGlyphContent(
              state: glyph,
              glyphColor: color,
              opacity: visibility,
            ),
            onTap: onTap,
          )
        : null;

    return preserveRoundedCupertinoSheetToolbarSize(
      context,
      navigation_glass.GlassAppBar.pinned(
        title: const SizedBox.shrink(),
        leading: item == null
            ? const <navigation_glass.GlassBarItem>[]
            : <navigation_glass.GlassBarItem>[item],
        actions: showPrimary
            ? actions
            : const <navigation_glass.GlassBarItem>[],
        backButton: false,
        buttonSize: buttonSize,
        toolbarHeight: toolbarHeight,
        centerTitle: false,
        padding: EdgeInsets.symmetric(horizontal: horizontalInset),
        buttonSettings: settings,
      ),
    );
  }
}

/// Keeps the package's matched item as one persistent button while changing
/// its glyph immediately at the destination. The fixed Icon fields provide a
/// stable content identity to GlassNavigationShell; the route-specific glyph
/// is painted by this widget rather than cross-fading a second toolbar item.
class _AppShellToolbarGlyphContent extends Icon {
  const _AppShellToolbarGlyphContent({
    required this.state,
    required this.glyphColor,
    required this.opacity,
  }) : super(CupertinoIcons.line_horizontal_3, size: 26);

  final AppShellToolbarGlyph state;
  final Color glyphColor;
  final double opacity;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: opacity,
    child: _AppShellMenuGlyph(state: state, color: glyphColor),
  );
}

class _AppShellMenuGlyph extends StatelessWidget {
  const _AppShellMenuGlyph({required this.state, required this.color});

  final AppShellToolbarGlyph state;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final (topY, topAngle, bottomY, bottomAngle, strokeWidth) = switch (state) {
      AppShellToolbarGlyph.menu => (-4.5, 0.0, 4.5, 0.0, 22.0),
      AppShellToolbarGlyph.close => (
        0.0,
        0.7853981633974483,
        0.0,
        -0.7853981633974483,
        22.0,
      ),
      AppShellToolbarGlyph.back => (
        -3.86,
        -0.6981317007977318,
        3.86,
        0.6981317007977318,
        12.0,
      ),
    };

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

Route<void> appShellToolbarStateRoute({
  required String name,
  required WidgetBuilder toolbarBuilder,
  required VoidCallback onSystemBack,
  bool opaque = false,
}) {
  return _AppShellToolbarStateRoute(
    name: name,
    toolbarBuilder: toolbarBuilder,
    onSystemBack: onSystemBack,
    opaque: opaque,
  );
}

/// A non-modal route used only to register a toolbar destination.
///
/// When hosted by a dedicated toolbar Navigator layered over the app content,
/// [opaque] keeps the package's route transition progress authoritative without
/// covering the app body. The page's empty background remains pass-through.
class _AppShellToolbarStateRoute extends PageRouteBuilder<void> {
  _AppShellToolbarStateRoute({
    required String name,
    required WidgetBuilder toolbarBuilder,
    required VoidCallback onSystemBack,
    required super.opaque,
  }) : super(
         settings: RouteSettings(name: name),
         barrierDismissible: false,
         transitionDuration: const Duration(milliseconds: 360),
         reverseTransitionDuration: const Duration(milliseconds: 360),
         pageBuilder: (context, _, _) => PopScope<Object?>(
           canPop: false,
           onPopInvokedWithResult: (didPop, _) {
             if (!didPop) onSystemBack();
           },
           child: Stack(
             fit: StackFit.expand,
             children: [
               const IgnorePointer(child: SizedBox.expand()),
               Positioned(
                 top: 0,
                 left: 0,
                 right: 0,
                 child: toolbarBuilder(context),
               ),
             ],
           ),
         ),
         transitionsBuilder: (context, animation, secondaryAnimation, child) =>
             child,
       );

  @override
  Widget buildModalBarrier() =>
      const IgnorePointer(ignoring: true, child: SizedBox.expand());
}
