import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass
    show
        GlassAppBar,
        GlassBarItem,
        GlassBarItemBackground,
        GlassNavigationShell;

import '../app_settings.dart';
import '../app_theme.dart';
import '../services/system_accent_color.dart';
import 'app_shell_navigation_scope.dart';
import 'skeddo_glass_settings.dart';

const Object _appShellMenuToolbarItemId = 'app-shell-menu-toolbar';
const Object _appShellCloseToolbarItemId = 'app-shell-close-toolbar';
const Object _appShellBackToolbarItemId = 'app-shell-back-toolbar';

enum AppShellToolbarGlyph { menu, close, back }

extension AppShellToolbarGlyphIdentity on AppShellToolbarGlyph {
  Object get glassItemId => switch (this) {
    AppShellToolbarGlyph.menu => _appShellMenuToolbarItemId,
    AppShellToolbarGlyph.close => _appShellCloseToolbarItemId,
    AppShellToolbarGlyph.back => _appShellBackToolbarItemId,
  };
}

/// Keys toolbar routes by the visible configuration, not the active screen.
///
/// Tabs that show the same glyphs and actions share a route so their pinned
/// glass remains settled instead of being replaced for a content-only change.
String appShellToolbarConfigurationKey({
  required bool searchFocused,
  required int selectedTabIndex,
  required bool dcvToolbarVisible,
  String calendarToolbarVariant = 'month-compact',
}) {
  if (searchFocused) return 'search';
  if (selectedTabIndex == 2 && dcvToolbarVisible) {
    return 'events-dcv';
  }
  if (selectedTabIndex == 1) {
    return 'calendar-$calendarToolbarVariant';
  }
  if (selectedTabIndex == 2) return 'events';
  // Home and You both show the same solo Search action.
  return 'home';
}

/// A route-registered toolbar item using the app's slider-driven glass values.
///
/// Destinations reuse an identity while the glyph is unchanged. A change
/// between menu, close, and back uses a distinct package item identity so the
/// package can run its materialize/blur choreography instead of swapping the
/// glyph inside a permanently matched item.
class AppShellPinnedToolbar extends StatelessWidget {
  static const defaultButtonSize = 40.0;
  static const defaultToolbarHeight = 60.0;

  const AppShellPinnedToolbar({
    super.key,
    required this.glyph,
    required this.onTap,
    required this.semanticLabel,
    required this.horizontalInset,
    this.color,
    this.opacity = 1,
    this.buttonSize = defaultButtonSize,
    this.toolbarHeight = defaultToolbarHeight,
    this.actions = const <navigation_glass.GlassBarItem>[],
    this.hideWhen,
    this.interactionsEnabled,
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

  /// Hides the whole registration, including outgoing routes, when true.
  final ValueListenable<bool>? hideWhen;
  final ValueListenable<bool>? interactionsEnabled;

  @override
  Widget build(BuildContext context) {
    final listenables = <Listenable>[
      appAccentNotifier,
      appAccentUsesSystemNotifier,
      appSystemAccentColorNotifier,
      appLiquidGlassOpacityNotifier,
    ];
    final routeChanges = AppShellNavigationScope.routeChangesOf(context);
    if (routeChanges != null) listenables.add(routeChanges);
    if (hideWhen != null) listenables.add(hideWhen!);
    if (interactionsEnabled != null) listenables.add(interactionsEnabled!);
    return ListenableBuilder(
      listenable: Listenable.merge(listenables),
      builder: (context, _) => _buildToolbar(context),
    );
  }

  Widget _buildToolbar(BuildContext context) {
    if (hideWhen?.value ?? false) return const SizedBox.shrink();

    final color = this.color ?? resolveAccentColor(context);
    final visibility = opacity.clamp(0.0, 1.0).toDouble();
    final canInteract = interactionsEnabled?.value ?? true;
    final settings = skeddoPinnedNavigationGlassSettingsFor(
      MediaQuery.platformBrightnessOf(context),
      visibility: visibility,
    );
    final item = navigation_glass.GlassBarItem.icon(
      id: glyph.glassItemId,
      label: semanticLabel,
      enabled: canInteract && visibility > 0.01,
      background: navigation_glass.GlassBarItemBackground.shared,
      icon: _AppShellToolbarGlyphContent(
        state: glyph,
        glyphColor: color,
        opacity: visibility,
      ),
      onTap: onTap,
    );

    final toolbar = navigation_glass.GlassAppBar.pinned(
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
    // With pinning active, the shell paints and owns the real button hit
    // targets in its separate overlay. The in-route GlassAppBar still spans
    // the whole toolbar row; its transparent surface must not intercept taps
    // on controls placed in the empty space between those buttons.
    return navigation_glass.GlassNavigationShell.maybeOf(context)?.isActive ??
            false
        ? IgnorePointer(child: toolbar)
        : toolbar;
  }
}

/// Keeps the glyph widget type stable for Flutter while GlassNavigationShell
/// treats each navigation glyph state as a distinct package item.
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
      child: Transform.translate(
        // Match the established optical correction for a left-facing
        // chevron; its geometric center reads slightly right of the circle's
        // center without this small glyph-only adjustment.
        offset: state == AppShellToolbarGlyph.back
            ? const Offset(-2, 0)
            : Offset.zero,
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
