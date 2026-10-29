import 'dart:async';
import 'dart:convert';
import 'dart:math' show max;
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'ai/ai_services.dart';
import 'app_settings.dart';
import 'services/local_storage.dart';
import 'services/system_accent_color.dart';
import 'app_theme.dart';
import 'widgets/app_switch.dart';
import 'widgets/accent_tinted_image.dart';
import 'widgets/fixed_size_icon.dart';
import 'widgets/floating_tab_pill.dart';
import 'widgets/header_title_scroller.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart' as glass_slider;
import 'widgets/native_fluid_slider_row.dart';
import 'widgets/app_window_content_boundary.dart';
import 'widgets/app_header_scroll_edge.dart';
import 'widgets/app_shell_navigation_scope.dart';
import 'widgets/app_shell_toolbar.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SettingsPanel — full-screen settings content with route-based sub-screen nav.
//
// AppShell presents this surface as a Navigator route and pins the shared
// toolbar above it. Portrait sub-screens are pushed as Cupertino routes and
// register the same toolbar item ID; landscape master/detail remains inline.
// The route-level X closes the panel, while the sub-screen chevron pops one
// route.
//
// Spacing contract
//   • Main list and sub-screens use 16 pt edge gaps on the 8 pt grid.
// ══════════════════════════════════════════════════════════════════════════════

double _settingsGridInset(double inset) {
  if (inset <= 0) return 0;
  return (inset / 8).ceil() * 8.0;
}

// ── Accent-color swatch descriptor ────────────────────────────────────────────
// Mirrors the 12 category swatches in kCategoryColors (app_theme.dart).
// Order: Red, Orange, Yellow, Green, Teal, Blue | Violet, Pink, Purple, Tan, Slate, Sand
class _AccentSwatch {
  final String name;
  final CupertinoDynamicColor color;
  const _AccentSwatch(this.name, this.color);
}

const List<_AccentSwatch> _kAccentSwatches = [
  _AccentSwatch('Red', kCatRed),
  _AccentSwatch('Orange', kCatOrange),
  _AccentSwatch('Yellow', kCatYellow),
  _AccentSwatch('Green', kCatGreen),
  _AccentSwatch('Light Blue', kCatTeal),
  _AccentSwatch('Blue', kCatBlue), // index 5 — default
  _AccentSwatch('Violet', kCatIndigo),
  _AccentSwatch('Pink', kCatPink),
  _AccentSwatch('Purple', kCatPurple),
  _AccentSwatch('Tan', kCatTan),
  _AccentSwatch('Slate', kCatSlate),
  _AccentSwatch('Sand', kCatSand),
];

// ── Route descriptor ──────────────────────────────────────────────────────────
class _SettingsRoute {
  final String title;
  final List<String> options;
  // The option pre-selected when the sub-screen opens.  Contextual rows reuse
  // the value already shown as a trailing in the main list; generic rows
  // default to the first option.
  final String defaultValue;
  // When true, _SubScreen renders the accent-color picker instead of the
  // standard text-option list.
  final bool isAccentColor;
  final bool isLiquidGlass;
  final bool isTextSize;
  final bool isDefaultCategory;
  const _SettingsRoute({
    required this.title,
    required this.options,
    required this.defaultValue,
    this.isAccentColor = false,
    this.isLiquidGlass = false,
    this.isTextSize = false,
    this.isDefaultCategory = false,
  });
}

// Pre-defined placeholder routes for every chevron / value-trailing row.
const _kRoutes = <String, _SettingsRoute>{
  'Profile': _SettingsRoute(
    title: 'Profile',
    options: ['Option A', 'Option B', 'Option C'],
    defaultValue: 'Option A',
  ),
  'Sync & Backup': _SettingsRoute(
    title: 'Sync & Backup',
    options: ['Option A', 'Option B', 'Option C'],
    defaultValue: 'Option A',
  ),
  // Contextual — defaultValue matches the trailing shown in the main list.
  'Theme': _SettingsRoute(
    title: 'Theme',
    options: ['System', 'Light', 'Dark'],
    defaultValue: 'System',
  ),
  'Accent Color': _SettingsRoute(
    title: 'Accent Color',
    options: [],
    defaultValue: '',
    isAccentColor: true,
  ),
  'Text Size': _SettingsRoute(
    title: 'Text Size',
    options: [],
    defaultValue: '',
    isTextSize: true,
  ),
  'Liquid Glass': _SettingsRoute(
    title: 'Liquid Glass',
    options: [],
    defaultValue: '',
    isLiquidGlass: true,
  ),
  'App Icon': _SettingsRoute(
    title: 'App Icon',
    options: ['Default', 'Monochrome', 'Option C'],
    defaultValue: 'Default',
  ),
  // Contextual — defaultValue matches the trailing shown in the main list.
  'Default View': _SettingsRoute(
    title: 'Default View',
    options: ['Day', 'Week', 'Month', 'Year'],
    defaultValue: 'Month',
  ),
  // Contextual — defaultValue matches the trailing shown in the main list.
  'First Day of Week': _SettingsRoute(
    title: 'First Day of Week',
    options: kFirstDayOfWeekOptions,
    defaultValue: 'System',
  ),
  // Contextual — defaultValue matches the trailing shown in the main list.
  'Default Event Duration': _SettingsRoute(
    title: 'Default Event Duration',
    options: ['15 minutes', '30 minutes', '1 hour', '2 hours'],
    defaultValue: '1 hour',
  ),
  'Default Category': _SettingsRoute(
    title: 'Default Category',
    options: const [],
    defaultValue: 'Uncategorized',
    isDefaultCategory: true,
  ),
  'Date Format': _SettingsRoute(
    title: 'Date Format',
    options: [
      '19/08/2026',
      '08/19/26',
      '19/08/26',
      '08/19/2026',
      '19.08.2026',
      '19-08-2026',
      '2026/08/19',
      '2026.08.19',
      '2026-08-19',
    ],
    defaultValue: '08/19/2026',
  ),
  'Privacy': _SettingsRoute(
    title: 'Privacy',
    options: ['Option A', 'Option B', 'Option C'],
    defaultValue: 'Option A',
  ),
  'Check for Updates': _SettingsRoute(
    title: 'Check for Updates',
    options: ['Option A', 'Option B', 'Option C'],
    defaultValue: 'Option A',
  ),
  'About SKEDDO': _SettingsRoute(
    title: 'About SKEDDO',
    options: ['Option A', 'Option B', 'Option C'],
    defaultValue: 'Option A',
  ),
};

// ── Main widget ───────────────────────────────────────────────────────────────
class SettingsPanel extends StatefulWidget {
  final double topInset;
  final double bottomInset;
  final bool isOpen;

  /// Whether the current landscape window can fit a master/detail layout.
  /// Settings still opens as a full-width master pane until a row is tapped.
  final bool isLandscapeTwoPane = false;

  /// Called when the X button is tapped — triggers controller.reverse()
  /// on the parent.
  final VoidCallback onClose;

  /// Set to the pop callback when a sub-screen is active, null otherwise.
  /// AppShell uses it to dispatch the shared leading toolbar action.
  final ValueNotifier<VoidCallback?> subScreenBackAction;
  final ValueNotifier<bool> inlineSubScreenBackVisible;
  final AppHeaderTitleTransition headerTitleTransition;

  const SettingsPanel({
    super.key,
    required this.topInset,
    required this.bottomInset,
    required this.isOpen,
    required this.onClose,
    required this.subScreenBackAction,
    required this.inlineSubScreenBackVisible,
    required this.headerTitleTransition,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel>
    with TickerProviderStateMixin {
  // ── Navigation animation ───────────────────────────────────────────────────
  late final AnimationController _navCtrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  // Sub-screen slides in from the right (1,0) → (0,0).
  late final Animation<Offset> _subSlide = Tween<Offset>(
    begin: const Offset(-1.0, 0.0),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _navCtrl, curve: Curves.easeInOutCubic));

  // Main content exits fully to the right as sub-screen enters.
  late final Animation<Offset> _mainParallax = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(1.0, 0.0),
  ).animate(CurvedAnimation(parent: _navCtrl, curve: Curves.easeInOutCubic));

  late final AnimationController _splitDetailController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 360),
  );

  late final AnimationController _paneTransitionController =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 360),
      );
  late final Animation<double> _paneTransitionProgress = CurvedAnimation(
    parent: _paneTransitionController,
    curve: Curves.easeInOutCubic,
  );
  final ScrollController _mainScrollController = ScrollController();
  AppHeaderTitleTransition get _headerTitleTransition =>
      widget.headerTitleTransition;
  final GlobalKey _mainSettingsContentKey = GlobalKey();
  final Map<String, GlobalKey> _settingsRowAnchorKeys = {
    for (final title in [
      ..._kRoutes.keys,
      'Full Month Name',
      'Event Reminders',
      'Daily Summary',
    ])
      title: GlobalKey(),
  };
  _SettingsRoute? _activeRoute;
  _SettingsRoute? _previousRoute;
  bool _isSplitActive = false;
  GlobalKey? _masterAnchorKey;

  bool _isHeaderScrollSource(ScrollMetrics metrics, int depth) {
    return metrics.axis == Axis.vertical &&
        depth == 0 &&
        metrics.viewportDimension >=
            max(240, MediaQuery.sizeOf(context).height * 0.35);
  }

  void _bindHeaderPositionFromContext(BuildContext context) {
    final position = Scrollable.maybeOf(context, axis: Axis.vertical)?.position;
    if (position != null) {
      _headerTitleTransition.bindTo(position, preserveCollapseProgress: true);
    }
  }

  bool _onHeaderScrollNotification(ScrollNotification notification) {
    if (!widget.isOpen ||
        MediaQuery.orientationOf(context) != Orientation.portrait) {
      return false;
    }
    if (!_isHeaderScrollSource(notification.metrics, notification.depth)) {
      return false;
    }
    final notificationContext = notification.context;
    if (notificationContext != null) {
      _bindHeaderPositionFromContext(notificationContext);
    }
    return false;
  }

  bool _onHeaderScrollMetricsNotification(
    ScrollMetricsNotification notification,
  ) {
    if (!widget.isOpen ||
        MediaQuery.orientationOf(context) != Orientation.portrait) {
      return false;
    }
    if (!_isHeaderScrollSource(notification.metrics, notification.depth)) {
      return false;
    }
    _bindHeaderPositionFromContext(notification.context);
    return false;
  }

  void _restoreHeaderScrollOffset() {
    final position = !widget.isLandscapeTwoPane && _activeRoute == null
        ? (AppHeaderScrollView.headerPositionFor(_mainScrollController) ??
              (_mainScrollController.hasClients
                  ? _mainScrollController.position
                  : null))
        : null;
    _headerTitleTransition.bindTo(position, preserveCollapseProgress: true);
  }

  // Listener added to _navCtrl when a push starts; fires the hard-snap of the
  // overlay icon to "<" at the 50 % midpoint — matching the DCV timing.
  VoidCallback? _snapListener;

  @override
  void initState() {
    super.initState();
    _splitDetailController.addStatusListener(_onSplitDetailStatus);
  }

  @override
  void didUpdateWidget(covariant SettingsPanel oldWidget) {
    super.didUpdateWidget(oldWidget);

    final openedNow = widget.isOpen && !oldWidget.isOpen;

    if (openedNow) {
      _activeRoute = null;
      _previousRoute = null;
      _isSplitActive = false;
      _masterAnchorKey = null;
      _navCtrl.value = 0.0;
      _paneTransitionController.value = 0.0;
      _splitDetailController.value = 0.0;
      widget.subScreenBackAction.value = null;
      widget.inlineSubScreenBackVisible.value = false;
      _restoreHeaderScrollOffset();
    }

    if (!widget.isOpen && oldWidget.isOpen) {
      _navCtrl.stop();
      _paneTransitionController.stop();
      _splitDetailController.stop();
      _headerTitleTransition.suspend();
      _isSplitActive = false;
      _paneTransitionController.value = 0.0;
      widget.subScreenBackAction.value = null;
      widget.inlineSubScreenBackVisible.value = false;
    }

    if (widget.isOpen &&
        widget.isLandscapeTwoPane != oldWidget.isLandscapeTwoPane) {
      if (widget.isLandscapeTwoPane && _activeRoute != null) {
        _isSplitActive = true;
        _paneTransitionController.value = 1.0;
        _splitDetailController.value = 1.0;
        _navCtrl.value = 0.0;
        widget.subScreenBackAction.value = _closeSplitPane;
        widget.inlineSubScreenBackVisible.value = true;
      } else if (!widget.isLandscapeTwoPane && _isSplitActive) {
        _isSplitActive = false;
        _paneTransitionController.value = 0.0;
        if (_activeRoute != null) {
          _navCtrl.value = 1.0;
          widget.subScreenBackAction.value = _pop;
          widget.inlineSubScreenBackVisible.value = true;
        } else {
          widget.subScreenBackAction.value = null;
          widget.inlineSubScreenBackVisible.value = false;
        }
      } else if (widget.isLandscapeTwoPane) {
        widget.subScreenBackAction.value = null;
        widget.inlineSubScreenBackVisible.value = false;
      } else if (_activeRoute != null && _navCtrl.value >= 0.5) {
        widget.subScreenBackAction.value = _pop;
        widget.inlineSubScreenBackVisible.value = true;
      }
    }
  }

  void _onSplitDetailStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _previousRoute != null &&
        mounted) {
      setState(() => _previousRoute = null);
    }
  }

  Widget _buildSubScreen({
    required _SettingsRoute route,
    required double bottomInset,
    required Color accentColor,
    required bool applyAppWindowContentPadding,
  }) {
    return _SubScreen(
      key: ValueKey<String>('settings-route-${route.title}'),
      bottomInset: bottomInset,
      route: route,
      accentColor: accentColor,
      accentNotifier: appAccentNotifier,
      applyAppWindowContentPadding: applyAppWindowContentPadding,
    );
  }

  Widget _buildSplitSubScreenStack({
    required _SettingsRoute activeRoute,
    required _SettingsRoute? previousRoute,
    required double bottomInset,
    required Color accentColor,
  }) {
    return AnimatedBuilder(
      animation: _splitDetailController,
      builder: (context, _) {
        final progress = Curves.easeInOutCubic.transform(
          _splitDetailController.value,
        );
        return LayoutBuilder(
          builder: (context, constraints) {
            final incomingOffset = previousRoute == null
                ? 0.0
                : constraints.maxWidth * (1.0 - progress);
            final pages = <Widget>[];
            if (previousRoute != null) {
              pages.add(
                Positioned.fill(
                  key: ValueKey<String>(
                    'settings-route-${previousRoute.title}',
                  ),
                  child: IgnorePointer(
                    child: _buildSubScreen(
                      route: previousRoute,
                      bottomInset: bottomInset,
                      accentColor: accentColor,
                      applyAppWindowContentPadding: false,
                    ),
                  ),
                ),
              );
            }
            pages.add(
              Positioned.fill(
                key: ValueKey<String>('settings-route-${activeRoute.title}'),
                child: IgnorePointer(
                  ignoring: _splitDetailController.isAnimating,
                  child: Transform.translate(
                    offset: Offset(incomingOffset, 0.0),
                    child: _buildSubScreen(
                      route: activeRoute,
                      bottomInset: bottomInset,
                      accentColor: accentColor,
                      applyAppWindowContentPadding: false,
                    ),
                  ),
                ),
              ),
            );
            return AppHeaderScrollClip(
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.none,
                children: pages,
              ),
            );
          },
        );
      },
    );
  }

  void _push(_SettingsRoute route, GlobalKey anchorKey) {
    if (widget.isLandscapeTwoPane) {
      if (_activeRoute?.title == route.title) return;
      _masterAnchorKey = anchorKey;
      if (_activeRoute == null) {
        setState(() {
          _activeRoute = route;
          _isSplitActive = true;
        });
        _splitDetailController.value = 1.0;
        _paneTransitionController.forward(from: 0.0);
      } else {
        setState(() {
          _previousRoute = _activeRoute;
          _activeRoute = route;
        });
        _splitDetailController.forward(from: 0.0);
      }
      widget.subScreenBackAction.value = _closeSplitPane;
      widget.inlineSubScreenBackVisible.value = true;
      return;
    }

    _restoreHeaderScrollOffset();
    widget.subScreenBackAction.value = null;
    widget.inlineSubScreenBackVisible.value = false;
    final navigator = AppShellNavigationScope.navigatorOf(context);
    final routeFuture = navigator.push<void>(
      CupertinoPageRoute<void>(
        settings: RouteSettings(name: 'settings-${route.title}'),
        builder: (routeContext) => _SettingsSubScreenRoute(
          route: route,
          bottomInset: widget.bottomInset,
          headerTitleTransition: _headerTitleTransition,
        ),
      ),
    );
    widget.inlineSubScreenBackVisible.value = false;
    routeFuture.then((_) {
      if (!mounted) return;
      widget.subScreenBackAction.value = null;
      widget.inlineSubScreenBackVisible.value = false;
      _restoreHeaderScrollOffset();
    });
  }

  Future<void> _closeSplitPane() async {
    if (!_isSplitActive ||
        _paneTransitionController.status == AnimationStatus.reverse) {
      return;
    }
    await _paneTransitionController.reverse();
    if (!mounted) return;
    widget.subScreenBackAction.value = null;
    widget.inlineSubScreenBackVisible.value = false;
    // Keep the shared transition mounted through its final frame so its
    // selected-row correction can finish on the same progress tick as the
    // pane and header. Remove the split presentation immediately afterward.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _isSplitActive = false;
        _activeRoute = null;
        _previousRoute = null;
      });
      _splitDetailController.value = 0.0;
    });
  }

  void _pop() {
    if (_navCtrl.status == AnimationStatus.reverse) return;
    // Remove any pending snap listener (pop before reaching 50 %).
    if (_snapListener != null) {
      _navCtrl.removeListener(_snapListener!);
      _snapListener = null;
    }
    _navCtrl.reverse().then((_) {
      if (mounted) {
        setState(() => _activeRoute = null);
        widget.subScreenBackAction.value = null;
        widget.inlineSubScreenBackVisible.value = false;
        _restoreHeaderScrollOffset();
      }
    });
  }

  @override
  void dispose() {
    if (_snapListener != null) _navCtrl.removeListener(_snapListener!);
    _splitDetailController.removeStatusListener(_onSplitDetailStatus);
    _mainScrollController.dispose();
    _paneTransitionController.dispose();
    _splitDetailController.dispose();
    _navCtrl.dispose();
    super.dispose();
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    // Keep top alignment on the settings grid, but use the shared Floating Tab
    // Bar bottom rule for the content edge: 16 pt minimum, or the actual
    // persistent system navigation inset when it is larger. Do not round or
    // add another 16 pt here.
    final topInset = _settingsGridInset(widget.topInset);
    final bottomInset = unifiedBottomPaddingForInset(widget.bottomInset);

    return ListenableBuilder(
      listenable: Listenable.merge([
        appAccentNotifier,
        appAccentUsesSystemNotifier,
        appSystemAccentColorNotifier,
        appBrightnessNotifier,
        appSystemBrightnessNotifier,
        appTextSizeUsesSystemNotifier,
        appTextSizeIndexNotifier,
        appSystemTextScaleNotifier,
        appStartOfWeekNotifier,
        appStartOfWeekUsesSystemNotifier,
        appSystemFirstDayOfWeekNotifier,
        appDefaultViewNotifier,
        appFullMonthNameNotifier,
        appEventDurationNotifier,
        appDefaultCategoryNotifier,
        appDefaultCategoryLabelNotifier,
        appDateFormatNotifier,
        appCustomDateFormatNotifier,
        appDateFormatUsesSystemNotifier,
        appSystemDateFormatNotifier,
        appSystemDateFormatSampleNotifier,
        appLiquidGlassOpacityNotifier,
      ]),
      builder: (context, _) {
        final usesSystemAccent = appAccentUsesSystemNotifier.value;
        final selectedSwatch = _kAccentSwatches[appAccentNotifier.value];
        final swatch = _AccentSwatch(
          mirrorSystemSettingTrailingValue(
            usesSystem: usesSystemAccent,
            appOnlyValue: selectedSwatch.name,
          ),
          usesSystemAccent
              ? appSystemAccentColorNotifier.value
              : selectedSwatch.color,
        );
        final accentColor = resolveAccentColor(context);

        final systemThemeDetail =
            appSystemBrightnessNotifier.value == Brightness.dark
            ? 'Dark'
            : 'Light';
        final themeLabel = mirrorSystemSettingTrailingValue(
          usesSystem: appBrightnessNotifier.value == null,
          systemDetail: systemThemeDetail,
          appOnlyValue: appBrightnessNotifier.value == Brightness.dark
              ? 'Dark'
              : 'Light',
        );
        final textSizeLabel = mirrorSystemSettingTrailingValue(
          usesSystem: appTextSizeUsesSystemNotifier.value,
          appOnlyValue: 'Custom',
        );
        final startOfWeekLabel = mirrorSystemSettingTrailingValue(
          usesSystem: appStartOfWeekUsesSystemNotifier.value,
          systemDetail: appSystemFirstDayOfWeekNotifier.value,
          appOnlyValue: appStartOfWeekNotifier.value,
        );
        final defaultViewLabel = appDefaultViewNotifier.value;
        final fullMonthName = appFullMonthNameNotifier.value;
        final eventDurationLabel = appEventDurationNotifier.value;
        final defaultCategoryLabel = appDefaultCategoryLabelNotifier.value;
        final systemDateSample = appSystemDateFormatSampleNotifier.value;
        final dateFormatLabel = mirrorSystemSettingTrailingValue(
          usesSystem: appDateFormatUsesSystemNotifier.value,
          systemDetail: systemDateSample,
          appOnlyValue: appCustomDateFormatNotifier.value.sample,
        );
        final liquidGlassOpacityLabel =
            '${(liquidGlassSliderPositionForOpacity(appLiquidGlassOpacityNotifier.value) * 100).round()}%';

        final isLandscape =
            MediaQuery.orientationOf(context) == Orientation.landscape;
        final headerContentHeight = isLandscape ? 52.0 : 101.0;
        final headerToolbarHeight = isLandscape
            ? headerContentHeight
            : kAppHeaderToolbarHeight;
        final headerHeight = topInset + headerToolbarHeight;
        final backgroundColor = resolveThemeColor(kBackgroundColor, context);
        final mainSettingsContent = _MainSettingsContent(
          key: _mainSettingsContentKey,
          bottomInset: bottomInset,
          onPush: _push,
          scrollController: _mainScrollController,
          rowAnchorKeys: _settingsRowAnchorKeys,
          accentColor: accentColor,
          accentSwatch: swatch,
          themeLabel: themeLabel,
          textSizeLabel: textSizeLabel,
          startOfWeekLabel: startOfWeekLabel,
          defaultViewLabel: defaultViewLabel,
          fullMonthName: fullMonthName,
          eventDurationLabel: eventDurationLabel,
          defaultCategoryLabel: defaultCategoryLabel,
          dateFormatLabel: dateFormatLabel,
          liquidGlassOpacityLabel: liquidGlassOpacityLabel,
        );

        return NotificationListener<ScrollMetricsNotification>(
          onNotification: _onHeaderScrollMetricsNotification,
          child: NotificationListener<ScrollNotification>(
            onNotification: _onHeaderScrollNotification,
            child: ClipRect(
              child: ColoredBox(
                color: backgroundColor,
                child: SizedBox.expand(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // ── Main body — slides right (parallax) during sub-screen push ──
                      Positioned.fill(
                        top: headerHeight,
                        child: AppHeaderScrollInsetScope(
                          titleTransition: _headerTitleTransition,
                          leadingInset: headerHeight,
                          titleCollapseExtent:
                              MediaQuery.orientationOf(context) ==
                                  Orientation.portrait
                              ? kAppHeaderTitleCollapseDistance
                              : 0.0,
                          child: AppWindowPhysicalWidth(
                            child: AppWindowContentPadding(
                              child: mainSettingsContent,
                            ),
                          ),
                        ),
                      ),

                      // ── Unified snapping header — never slides ──────────────────
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: AnimatedBuilder(
                          animation: _headerTitleTransition,
                          builder: (context, _) => _SettingsHeader(
                            topInset: topInset,
                            contentHeight: headerContentHeight,
                            isLandscape: isLandscape,
                            scrollOffset:
                                _headerTitleTransition.contentOffset,
                            collapseProgress:
                                _headerTitleTransition.collapseProgress,
                            title: 'Settings',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SettingsSubScreenRoute extends StatelessWidget {
  const _SettingsSubScreenRoute({
    required this.route,
    required this.bottomInset,
    required this.headerTitleTransition,
  });

  final _SettingsRoute route;
  final double bottomInset;
  final AppHeaderTitleTransition headerTitleTransition;

  bool _bindHeaderPosition(ScrollNotification notification) {
    final metrics = notification.metrics;
    final notificationContext = notification.context;
    if (metrics.axis != Axis.vertical ||
        notification.depth != 0 ||
        notificationContext == null ||
        metrics.viewportDimension <
            max(240, MediaQuery.sizeOf(notificationContext).height * 0.35)) {
      return false;
    }
    final position = Scrollable.maybeOf(
      notificationContext,
      axis: Axis.vertical,
    )?.position;
    if (position != null) {
      headerTitleTransition.bindTo(position, preserveCollapseProgress: true);
    }
    return false;
  }

  bool _bindHeaderMetrics(ScrollMetricsNotification notification) {
    final notificationContext = notification.context;
    if (notification.metrics.axis != Axis.vertical ||
        notification.depth != 0 ||
        notification.metrics.viewportDimension <
            max(240, MediaQuery.sizeOf(notificationContext).height * 0.35)) {
      return false;
    }
    final position = Scrollable.maybeOf(
      notificationContext,
      axis: Axis.vertical,
    )?.position;
    if (position != null) {
      headerTitleTransition.bindTo(position, preserveCollapseProgress: true);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final geometry = AppWindowMasterDetailGeometry.of(context);
    final isLandscape = geometry.isLandscape;
    final topInset = MediaQuery.paddingOf(context).top;
    final headerContentHeight = isLandscape ? 52.0 : 101.0;
    final toolbarHeight = isLandscape
        ? headerContentHeight
        : kAppHeaderToolbarHeight;
    final headerHeight = topInset + toolbarHeight;
    final backgroundColor = resolveThemeColor(kBackgroundColor, context);

    return ListenableBuilder(
        listenable: Listenable.merge([
          appAccentNotifier,
          appAccentUsesSystemNotifier,
          appSystemAccentColorNotifier,
        ]),
        builder: (context, _) {
          final accentColor = resolveAccentColor(context);
          return NotificationListener<ScrollMetricsNotification>(
            onNotification: _bindHeaderMetrics,
            child: NotificationListener<ScrollNotification>(
              onNotification: _bindHeaderPosition,
              child: ColoredBox(
                color: backgroundColor,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Positioned.fill(
                      top: headerHeight,
                      child: AppHeaderScrollInsetScope(
                        titleTransition: headerTitleTransition,
                        leadingInset: headerHeight,
                        titleCollapseExtent: isLandscape
                            ? 0.0
                            : kAppHeaderTitleCollapseDistance,
                        child: AppWindowPhysicalWidth(
                          child: _SubScreen(
                            bottomInset: bottomInset,
                            route: route,
                            accentColor: accentColor,
                            accentNotifier: appAccentNotifier,
                            applyAppWindowContentPadding: true,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: AnimatedBuilder(
                        animation: headerTitleTransition,
                        builder: (context, _) => _SettingsHeader(
                          topInset: topInset,
                          contentHeight: headerContentHeight,
                          isLandscape: isLandscape,
                          scrollOffset:
                              headerTitleTransition.contentOffset,
                          collapseProgress:
                              headerTitleTransition.collapseProgress,
                          title: route.title,
                        ),
                      ),
                    ),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: AppShellPinnedToolbar(
                        glyph: AppShellToolbarGlyph.back,
                        semanticLabel: 'Back from ${route.title}',
                        horizontalInset:
                            AppWindowContentScope.of(context).horizontalInset +
                            16.0,
                        onTap: () =>
                            AppShellNavigationScope.navigatorOf(context)
                                .maybePop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Main settings content
// ══════════════════════════════════════════════════════════════════════════════
class _MainSettingsContent extends StatelessWidget {
  final double bottomInset;
  final void Function(_SettingsRoute, GlobalKey) onPush;
  final ScrollController scrollController;
  final Map<String, GlobalKey> rowAnchorKeys;
  // Current resolved accent color — used for the Accent Color row trailing.
  final Color accentColor;
  // Current accent swatch — name + color for the trailing circle + label.
  final _AccentSwatch accentSwatch;
  // Live labels derived from app-level notifiers in _SettingsPanelState.build().
  final String themeLabel;
  final String textSizeLabel;
  final String startOfWeekLabel;
  final String defaultViewLabel;
  final bool fullMonthName;
  final String eventDurationLabel;
  final String defaultCategoryLabel;
  final String dateFormatLabel;
  final String liquidGlassOpacityLabel;

  const _MainSettingsContent({
    super.key,
    required this.bottomInset,
    required this.onPush,
    required this.scrollController,
    required this.rowAnchorKeys,
    required this.accentColor,
    required this.accentSwatch,
    required this.themeLabel,
    required this.textSizeLabel,
    required this.startOfWeekLabel,
    required this.defaultViewLabel,
    required this.fullMonthName,
    required this.eventDurationLabel,
    required this.defaultCategoryLabel,
    required this.dateFormatLabel,
    required this.liquidGlassOpacityLabel,
  });

  void _tap(String title) {
    final route = _kRoutes[title];
    final anchorKey = rowAnchorKeys[title];
    if (route != null && anchorKey != null) onPush(route, anchorKey);
  }

  @override
  Widget build(BuildContext context) {
    return AppHeaderScrollView(
      topExtension: kContentAreaTopRaise,
      // Settings is a Stack overlay inside CupertinoTabScaffold. Give it an
      // independent controller instead of inheriting the active tab's primary
      // scroll position.
      primary: false,
      controller: scrollController,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: AppHeaderScrollInset(
            enabled: MediaQuery.orientationOf(context) == Orientation.portrait,
          ),
        ),
        // Already supplied by the shared portrait header/body boundary.
        const SliverToBoxAdapter(child: AppHeaderContentSpacing()),

        // ── Account ─────────────────────────────────────────────────────────
        _SettingsSection(
          label: 'Account',
          rows: [
            _SettingsRow(
              key: rowAnchorKeys['Profile'],
              title: 'Profile',
              trailing: const _ChevronTrailing(),
              onTap: () => _tap('Profile'),
            ),
            _SettingsRow(
              key: rowAnchorKeys['Sync & Backup'],
              title: 'Sync & Backup',
              trailing: const _ChevronTrailing(),
              onTap: () => _tap('Sync & Backup'),
            ),
          ],
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Appearance ───────────────────────────────────────────────────────
        _SettingsSection(
          label: 'Appearance',
          rows: [
            _SettingsRow(
              key: rowAnchorKeys['Theme'],
              title: 'Theme',
              trailing: _ValueTrailing(themeLabel),
              onTap: () => _tap('Theme'),
            ),
            _SettingsRow(
              key: rowAnchorKeys['Accent Color'],
              title: 'Accent Color',
              trailing: _ColorTrailing(
                color: accentColor,
                name: accentSwatch.name,
              ),
              onTap: () => _tap('Accent Color'),
            ),
            _SettingsRow(
              key: rowAnchorKeys['Text Size'],
              title: 'Text Size',
              trailing: _ValueTrailing(textSizeLabel),
              onTap: () => _tap('Text Size'),
            ),
            _SettingsRow(
              key: rowAnchorKeys['Liquid Glass'],
              title: 'Liquid Glass',
              trailing: _ValueTrailing(liquidGlassOpacityLabel),
              onTap: () => _tap('Liquid Glass'),
            ),
          ],
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Calendar ─────────────────────────────────────────────────────────
        _SettingsSection(
          label: 'Calendar',
          rows: [
            _SettingsRow(
              key: rowAnchorKeys['Default View'],
              title: 'Default View',
              trailing: _ValueTrailing(defaultViewLabel),
              onTap: () => _tap('Default View'),
            ),
            _SettingsRow(
              key: rowAnchorKeys['First Day of Week'],
              title: 'First Day of Week',
              trailing: _ValueTrailing(startOfWeekLabel),
              onTap: () => _tap('First Day of Week'),
            ),
            _SettingsRow(
              key: rowAnchorKeys['Default Event Duration'],
              title: 'Default Event Duration',
              trailing: _ValueTrailing(eventDurationLabel),
              onTap: () => _tap('Default Event Duration'),
            ),
            _SettingsRow(
              key: rowAnchorKeys['Default Category'],
              title: 'Default Category',
              trailing: _ValueTrailing(defaultCategoryLabel),
              onTap: () => _tap('Default Category'),
            ),
            _SettingsToggleRow(
              key: rowAnchorKeys['Full Month Name'],
              title: 'Full Month Name',
              value: fullMonthName,
              onChanged: (value) {
                appFullMonthNameNotifier.value = value;
                saveAppSetting('Full Month Name', value.toString());
              },
            ),
            _SettingsRow(
              key: rowAnchorKeys['Date Format'],
              title: 'Date Format',
              trailing: _ValueTrailing(dateFormatLabel),
              onTap: () => _tap('Date Format'),
            ),
          ],
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Notifications ────────────────────────────────────────────────────
        _SettingsSection(
          label: 'Notifications',
          rows: [
            _SettingsToggleRow(
              key: rowAnchorKeys['Event Reminders'],
              title: 'Event Reminders',
              value: true,
              onChanged: (_) {},
            ),
            _SettingsToggleRow(
              key: rowAnchorKeys['Daily Summary'],
              title: 'Daily Summary',
              value: false,
              onChanged: (_) {},
            ),
          ],
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── General ──────────────────────────────────────────────────────────
        _SettingsSection(
          label: 'General',
          rows: [
            _SettingsRow(
              key: rowAnchorKeys['Privacy'],
              title: 'Privacy',
              trailing: const _ChevronTrailing(),
              onTap: () => _tap('Privacy'),
            ),
            _SettingsRow(
              key: rowAnchorKeys['Check for Updates'],
              title: 'Check for Updates',
              trailing: const _ChevronTrailing(),
              onTap: () => _tap('Check for Updates'),
            ),
            _SettingsRow(
              key: rowAnchorKeys['About SKEDDO'],
              title: 'About SKEDDO',
              trailing: const _ChevronTrailing(),
              onTap: () => _tap('About SKEDDO'),
            ),
          ],
        ),

        // SliverPadding is intentionally unpainted: this is transparent
        // breathing room, not a colored safe-area strip.
        SliverPadding(padding: EdgeInsets.only(bottom: bottomInset)),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Sub-screen
// ══════════════════════════════════════════════════════════════════════════════
class _SubScreen extends StatefulWidget {
  final double bottomInset;
  final _SettingsRoute route;
  final bool applyAppWindowContentPadding;
  // Current resolved accent color — forwarded to _SubScreenSection for
  // checkmarks and selection highlights.
  final Color accentColor;
  // Notifier owned by _SettingsPanelState — passed to _AccentColorSection so
  // tapping a swatch immediately updates the live accent everywhere.
  final ValueNotifier<int> accentNotifier;

  const _SubScreen({
    super.key,
    required this.bottomInset,
    required this.route,
    required this.applyAppWindowContentPadding,
    required this.accentColor,
    required this.accentNotifier,
  });

  @override
  State<_SubScreen> createState() => _SubScreenState();
}

class _SubScreenState extends State<_SubScreen> {
  // Tracks the currently selected option for standard (non-accent) sub-screens.
  // Theme and Text Size are seeded from the live global notifiers so the picker
  // opens on the currently active value rather than the route defaultValue.
  late String _selected;

  @override
  void initState() {
    super.initState();
    // Seed the selection from the live global notifier so the sub-screen opens
    // on the value the user actually chose, not the route's compile-time default.
    _selected = switch (widget.route.title) {
      'Theme' => switch (appBrightnessNotifier.value) {
        Brightness.light => 'Light',
        Brightness.dark => 'Dark',
        _ => 'System',
      },
      'Text Size' => appTextSizeUsesSystemNotifier.value ? 'System' : 'Custom',
      'First Day of Week' => appStartOfWeekUsesSystemNotifier.value
          ? 'System'
          : appStartOfWeekNotifier.value,
      'Default View' => appDefaultViewNotifier.value,
      'Default Event Duration' => appEventDurationNotifier.value,
      'Default Category' => appDefaultCategoryLabelNotifier.value,
      'Date Format' => appDateFormatUsesSystemNotifier.value
          ? 'System'
          : appCustomDateFormatNotifier.value.sample,
      _ => widget.route.defaultValue,
    };
  }

  void _onSelect(String opt) {
    setState(() => _selected = opt);
    // Write-through to the matching app-level notifier and persist to disk.
    switch (widget.route.title) {
      case 'Theme':
        appBrightnessNotifier.value = switch (opt) {
          'Light' => Brightness.light,
          'Dark' => Brightness.dark,
          _ => null,
        };
        saveAppSetting('Theme', opt);
      case 'Text Size':
        appTextSizeUsesSystemNotifier.value = opt == 'System';
        saveAppSetting('Text Size', opt);
      case 'First Day of Week':
        final useSystem = opt == 'System';
        appStartOfWeekUsesSystemNotifier.value = useSystem;
        final selectedDay = useSystem
            ? appSystemFirstDayOfWeekNotifier.value
            : opt;
        appStartOfWeekNotifier.value = selectedDay;
        saveAppSetting('First Day of Week', selectedDay);
      case 'Default View':
        appDefaultViewNotifier.value = opt;
        saveAppSetting('Default View', opt);
      case 'Default Event Duration':
        appEventDurationNotifier.value = opt;
        saveAppSetting('Default Event Duration', opt);
      case 'Date Format':
        final useSystem = opt == 'System';
        appDateFormatUsesSystemNotifier.value = useSystem;
        final format = useSystem
            ? appSystemDateFormatNotifier.value
            : AppDateFormat.fromSample(opt) ?? AppDateFormat.monthDayYearSlash;
        if (!useSystem) appCustomDateFormatNotifier.value = format;
        appDateFormatNotifier.value = format;
        final preference = format.parserLocalePreference;
        appDateLocaleNotifier.value = preference;
        AIServices.setDateLocalePreference(preference);
        saveAppSetting('Date Format', opt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final content = AppHeaderScrollView(
      topExtension: kContentAreaTopRaise,
      primary: false,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverToBoxAdapter(
          child: AppHeaderScrollInset(
            enabled: MediaQuery.orientationOf(context) == Orientation.portrait,
          ),
        ),
        // Already supplied by the shared portrait header/body boundary.
        const SliverToBoxAdapter(child: AppHeaderContentSpacing()),

        // Branch: accent-color picker vs. standard option list.
        if (widget.route.isAccentColor)
          _AccentColorSection(accentNotifier: widget.accentNotifier)
        else if (widget.route.isLiquidGlass)
          const _LiquidGlassSection()
        else if (widget.route.title == 'Theme')
          _ThemeSettingsSection(
            selectedOption: _selected,
            accentColor: widget.accentColor,
            onSelect: _onSelect,
          )
        else if (widget.route.isTextSize)
          _TextSizeSection(accentColor: widget.accentColor)
        else if (widget.route.title == 'First Day of Week')
          _FirstDayOfWeekSettingsSection(
            selectedOption: _selected,
            accentColor: widget.accentColor,
            onSelect: _onSelect,
          )
        else if (widget.route.title == 'Date Format')
          _DateFormatSettingsSection(
            accentColor: widget.accentColor,
            onSelect: _onSelect,
          )
        else if (widget.route.isDefaultCategory)
          _DefaultCategorySection(accentColor: widget.accentColor)
        else
          _SubScreenSection(
            options: widget.route.options,
            selectedOption: _selected,
            accentColor: widget.accentColor,
            onSelect: _onSelect,
          ),

        // SliverPadding is intentionally unpainted: this is transparent
        // breathing room, not a colored safe-area strip.
        SliverPadding(
          padding: EdgeInsets.only(
            bottom: unifiedBottomPaddingForInset(widget.bottomInset),
          ),
        ),
      ],
    );

    return ColoredBox(
      color: resolveThemeColor(kBackgroundColor, context),
      child: widget.applyAppWindowContentPadding
          ? AppWindowContentPadding(child: content)
          : content,
    );
  }
}

class _DefaultCategoryOption {
  final String id;
  final String name;
  final Color color;

  const _DefaultCategoryOption({
    required this.id,
    required this.name,
    required this.color,
  });
}

/// The default-category picker intentionally reads the same persisted category
/// records as EventsTab and keeps only active Standard categories. Unnamed and
/// Uncategorized are included while they exist, just like any other category.
class _DefaultCategorySection extends StatefulWidget {
  final Color accentColor;

  const _DefaultCategorySection({required this.accentColor});

  @override
  State<_DefaultCategorySection> createState() =>
      _DefaultCategorySectionState();
}

class _DefaultCategorySectionState extends State<_DefaultCategorySection> {
  List<_DefaultCategoryOption> _options = const [];

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final records = <_DefaultCategoryOption>[];
    final seen = <String>{};
    final userCategories = await LocalStorage.instance.loadContentStringList(
      'events_user_categories',
    );
    final pinnedCategories = await LocalStorage.instance.loadContentStringList(
      'events_pinned_categories',
    );
    final raw = [...?userCategories, ...?pinnedCategories];

    void addRecord(Object? value) {
      if (value is! Map) return;
      final id = value['id']?.toString() ?? '';
      final name = value['name']?.toString().trim() ?? '';
      final type = value['categoryType']?.toString() ?? 'Standard';
      if (id.isEmpty ||
          name.isEmpty ||
          value['archived'] == true ||
          type != 'Standard' ||
          id == 'sys-archived-categories' ||
          id == 'sys-recently-deleted') {
        return;
      }
      if (!seen.add(id)) return;
      final colorValue = value['colorValue'];
      final rawColor = colorValue is num
          ? colorValue.toInt()
          : kAccentColor.value;
      records.add(
        _DefaultCategoryOption(
          id: id,
          name: name,
          color: resolveCategorySwatch(Color(rawColor)),
        ),
      );
    }

    for (final encoded in raw) {
      try {
        addRecord(jsonDecode(encoded));
      } catch (_) {
        // Ignore only the malformed category record.
      }
    }
    if (!mounted) return;
    final selectedExists = records.any(
      (option) => option.id == appDefaultCategoryNotifier.value,
    );
    if (!selectedExists) {
      appDefaultCategoryNotifier.value = kDefaultCategoryFallbackId;
      appDefaultCategoryLabelNotifier.value = 'Uncategorized';
      await saveAppSetting('Default Category', 'Uncategorized');
    }
    setState(() => _options = List.unmodifiable(records));
  }

  void _select(_DefaultCategoryOption option) {
    appDefaultCategoryNotifier.value = option.id;
    appDefaultCategoryLabelNotifier.value = option.name;
    saveAppSetting('Default Category', option.name);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final cardBg = resolveThemeColor(kCardColor, context);
    final shadowColor = resolveThemeColor(kCardShadowColor, context);
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SettingsCard(
              rows: [
                for (final option in _options)
                  _DefaultCategoryRow(
                    option: option,
                    selected: option.id == appDefaultCategoryNotifier.value,
                    accentColor: widget.accentColor,
                    onTap: () => _select(option),
                  ),
              ],
              cardBg: cardBg,
              shadowColor: shadowColor,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
              child: Text(
                'Events created without a category are automatically assigned '
                'to this category.',
                style: TextStyle(
                  fontFamily: kSFProText,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: resolveThemeColor(kSecondaryLabel, context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DefaultCategoryRow extends StatefulWidget {
  final _DefaultCategoryOption option;
  final bool selected;
  final Color accentColor;
  final VoidCallback onTap;

  const _DefaultCategoryRow({
    required this.option,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_DefaultCategoryRow> createState() => _DefaultCategoryRowState();
}

class _DefaultCategoryRowState extends State<_DefaultCategoryRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _pressed ? kActionPanelGroupBreak : const Color(0x00000000),
        constraints: const BoxConstraints(minHeight: _kSettingsRowHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _kSettingsRowVerticalPadding,
        ),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: renderCategoryColor(widget.option.color, context),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.option.name,
                style: TextStyle(
                  fontFamily: kSFProText,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: resolveThemeColor(kPrimaryLabel, context),
                ),
              ),
            ),
            _SettingsCheckmarkSlot(
              selected: widget.selected,
              accentColor: widget.accentColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Headers
// ══════════════════════════════════════════════════════════════════════════════

class _SettingsTwoPaneHeader extends StatelessWidget {
  final AppWindowMasterDetailGeometry geometry;
  final double topInset;
  final double contentHeight;
  final Animation<double> paneProgress;
  final String activeTitle;
  final String? previousTitle;
  final double transitionProgress;
  final Color dividerColor;
  final VoidCallback onBack;

  const _SettingsTwoPaneHeader({
    required this.geometry,
    required this.topInset,
    required this.contentHeight,
    required this.paneProgress,
    required this.activeTitle,
    required this.previousTitle,
    required this.transitionProgress,
    required this.dividerColor,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = resolveThemeColor(kBackgroundColor, context);
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);

    Widget title(String value, {double horizontalPadding = 20}) => Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: HeaderTitleScroller(
          title: value,
          fadeColor: backgroundColor,
          centerWhenContentFits: true,
          contentAlignment: Alignment.centerLeft,
          style: TextStyle(
            fontFamily: kSFProText,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            fontStyle: FontStyle.normal,
            color: primaryLabel,
            letterSpacing: -0.6,
          ),
        ),
      ),
    );

    Widget headerPage(String value, {required bool interactive}) {
      return ColoredBox(
        color: backgroundColor,
        child: IgnorePointer(
          ignoring: !interactive,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: title(value, horizontalPadding: 52)),
              Positioned(
                right: geometry.horizontalInset,
                top: 0,
                bottom: 0,
                child: SizedBox(
                  width: 48,
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(44, 44),
                    onPressed: interactive ? onBack : null,
                    child: Icon(
                      CupertinoIcons.back,
                      size: 19,
                      color: primaryLabel,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final detailHeader = LayoutBuilder(
      builder: (context, constraints) {
        final pages = <Widget>[];
        if (previousTitle != null) {
          pages.add(
            Positioned.fill(
              child: headerPage(previousTitle!, interactive: false),
            ),
          );
        }
        pages.add(
          Positioned.fill(
            child: Transform.translate(
              offset: Offset(
                previousTitle == null
                    ? 0.0
                    : constraints.maxWidth * (1.0 - transitionProgress),
                0.0,
              ),
              child: headerPage(activeTitle, interactive: true),
            ),
          ),
        );
        return ClipRect(
          child: Stack(
            fit: StackFit.expand,
            clipBehavior: Clip.hardEdge,
            children: pages,
          ),
        );
      },
    );

    return Container(
      width: double.infinity,
      height: topInset + contentHeight,
      color: backgroundColor,
      child: Stack(
        children: [
          Positioned.fill(
            top: topInset,
            child: AppWindowMasterDetailTransition(
              geometry: geometry,
              progress: paneProgress,
              dividerColor: dividerColor,
              applyDetailPaneInsets: false,
              drawDivider: false,
              master: title('Settings'),
              detail: detailHeader,
            ),
          ),
          AnimatedBuilder(
            animation: paneProgress,
            builder: (context, _) {
              final progress = paneProgress.value.clamp(0.0, 1.0).toDouble();
              return Positioned(
                left: geometry.masterPaneWidthAt(progress),
                top: 0,
                bottom: 0,
                width: geometry.dividerWidthAt(progress),
                child: ColoredBox(color: dividerColor),
              );
            },
          ),
        ],
      ),
    );
  }
}

// ── Unified snapping header (shared by main settings and sub-screens) ─────────
// The title is swapped by _SettingsPanelState at the 50 % midpoint of the
// nav animation — no slide, just an instant snap matching the DCV timing.
class _SettingsHeader extends StatelessWidget {
  final double topInset;
  final double contentHeight;
  final bool isLandscape;
  final double scrollOffset;
  final double collapseProgress;
  final String title;

  const _SettingsHeader({
    required this.topInset,
    required this.contentHeight,
    required this.isLandscape,
    required this.scrollOffset,
    required this.collapseProgress,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = resolveThemeColor(kBackgroundColor, context);
    final headerSurfaceColor = isLandscape
        ? backgroundColor
        : const Color(0x00000000);
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    final toolbarHeight = isLandscape ? contentHeight : kAppHeaderToolbarHeight;
    final titleCollapseProgress = isLandscape
        ? 0.0
        : collapseProgress.clamp(0.0, 1.0).toDouble();
    final largeTitleFadeProgress = isLandscape
        ? 0.0
        : AppHeaderScrollBehavior.packageLargeTitleFadeProgress(
            collapseProgress,
          );
    final compactTitleFadeProgress = isLandscape
        ? 0.0
        : AppHeaderScrollBehavior.packageCompactTitleFadeProgress(
            collapseProgress,
          );
    final edgeProgress = isLandscape
        ? 0.0
        : AppHeaderScrollBehavior.scrollEdgeProgress(scrollOffset);
    return SizedBox(
      width: double.infinity,
      height: topInset + contentHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topInset + toolbarHeight,
            child: ColoredBox(
              color: headerSurfaceColor.withValues(
                alpha: (1 - titleCollapseProgress) * headerSurfaceColor.a,
              ),
            ),
          ),
          Offstage(
            offstage: !isLandscape,
            child: AppWindowContentPadding(
              child: Padding(
                padding: EdgeInsets.only(top: topInset),
                child: isLandscape
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 84),
                          child: HeaderTitleScroller(
                            title: title,
                            fadeColor: backgroundColor,
                            centerWhenContentFits: true,
                            contentAlignment: Alignment.centerLeft,
                            style: TextStyle(
                              fontFamily: kSFProText,
                              fontSize: 17,
                              fontWeight: FontWeight.w600,
                              fontStyle: FontStyle.normal,
                              color: primaryLabel,
                              letterSpacing: -0.6,
                            ),
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 44 pt icon-row slot — empty (X / back button lives in AppShell)
                          const SizedBox(height: 44),
                          // Large title — snaps between "Settings" and sub-screen name
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                left: 16,
                                right: 16,
                                bottom: kHeaderTitleBottomInset,
                              ),
                              child: Align(
                                alignment: Alignment.bottomLeft,
                                child: SizedBox(
                                  width: double.infinity,
                                  child: HeaderTitleScroller(
                                    title: title,
                                    fadeColor: backgroundColor,
                                    style: TextStyle(
                                      fontFamily: kSFProText,
                                      fontSize: 34,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.normal,
                                      color: primaryLabel,
                                      letterSpacing: -1.2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          if (!isLandscape)
            Positioned(
              top: topInset + toolbarHeight,
              left: 0,
              right: 0,
              height: kAppHeaderTitleHeight,
              child: Transform.translate(
                offset: Offset(0, -scrollOffset),
                child: AppHeaderLargeTitleHandoff(
                  progress: largeTitleFadeProgress,
                  child: Container(
                    color: headerSurfaceColor.withValues(
                      alpha: (1 - titleCollapseProgress) * headerSurfaceColor.a,
                    ),
                    child: AppWindowContentPadding(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: 16,
                          right: 16,
                          bottom: kHeaderTitleBottomInset,
                        ),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: SizedBox(
                            width: double.infinity,
                            child: HeaderTitleScroller(
                              title: title,
                              fadeColor: backgroundColor,
                              style: TextStyle(
                                fontFamily: kSFProText,
                                fontSize: 34,
                                fontWeight: FontWeight.bold,
                                fontStyle: FontStyle.normal,
                                color: primaryLabel,
                                letterSpacing: -1.2,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (!isLandscape)
            AppHeaderScrollEdge(
              progress: edgeProgress,
              surfaceColor: backgroundColor,
              headerHeight: topInset + toolbarHeight,
              backgroundGradientHeight: topInset + toolbarHeight,
            ),
          if (!isLandscape)
            Positioned(
              top: topInset,
              left: 0,
              right: 0,
              height: toolbarHeight,
              child: AppWindowContentPadding(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 84),
                  child: AppHeaderCompactTitle(
                    progress: compactTitleFadeProgress,
                    isLandscape: false,
                    child: SizedBox.expand(
                      child: HeaderTitleScroller(
                        title: title,
                        fadeColor: backgroundColor,
                        centerWhenContentFits: true,
                        contentAlignment: Alignment.centerLeft,
                        style: TextStyle(
                          fontFamily: kSFProText,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          fontStyle: FontStyle.normal,
                          color: primaryLabel,
                          letterSpacing: -0.6,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Section / row widgets
// ══════════════════════════════════════════════════════════════════════════════

// ── Section with label (main settings list) ───────────────────────────────────
class _SettingsSection extends StatelessWidget {
  final String label;
  final List<Widget> rows;

  const _SettingsSection({required this.label, required this.rows});

  @override
  Widget build(BuildContext context) {
    final cardBg = CupertinoDynamicColor.resolve(kCardColor, context);
    final shadowColor = CupertinoDynamicColor.resolve(
      kCardShadowColor,
      context,
    );
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section header label — 8 pt gap to card gives visual breathing
            // room between the uppercase label and the card below.
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 8),
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: kSFProText,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: resolveThemeColor(kSecondaryLabel, context),
                  letterSpacing: 0.0,
                ),
              ),
            ),
            _SettingsCard(rows: rows, cardBg: cardBg, shadowColor: shadowColor),
          ],
        ),
      ),
    );
  }
}

// ── Section without label (sub-screen) ───────────────────────────────────────
class _SubScreenSection extends StatelessWidget {
  final List<String> options;
  final String selectedOption;
  // Resolved accent color forwarded from _SettingsPanelState — used for
  // checkmarks and selected-row labels so they match the live accent.
  final Color accentColor;
  final ValueChanged<String> onSelect;

  const _SubScreenSection({
    required this.options,
    required this.selectedOption,
    required this.accentColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = CupertinoDynamicColor.resolve(kCardColor, context);
    final shadowColor = CupertinoDynamicColor.resolve(
      kCardShadowColor,
      context,
    );
    final rows = options
        .map(
          (opt) => _OptionRow(
            title: opt,
            selected: opt == selectedOption,
            accentColor: accentColor,
            onTap: () => onSelect(opt),
          ),
        )
        .toList();
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SettingsCard(
              rows: rows,
              cardBg: cardBg,
              shadowColor: shadowColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemeSettingsSection extends StatelessWidget {
  final String selectedOption;
  final Color accentColor;
  final ValueChanged<String> onSelect;

  const _ThemeSettingsSection({
    required this.selectedOption,
    required this.accentColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Brightness>(
      valueListenable: appSystemBrightnessNotifier,
      builder: (context, systemBrightness, _) {
        final systemTitle =
            'System Setting (${systemBrightness == Brightness.dark ? 'Dark' : 'Light'})';

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MirrorSystemSettingSection(
                  systemSettingRow: _OptionRow(
                    title: systemTitle,
                    selected: selectedOption == 'System',
                    accentColor: accentColor,
                    onTap: () => onSelect('System'),
                  ),
                  settingsScreenName: _systemThemeSettingsDestination(),
                ),
                const SizedBox(height: 20),
                SkeddoAppOnlySettingsSection(
                  rows: [
                    for (final option in const ['Light', 'Dark'])
                      _OptionRow(
                        title: option,
                        selected: selectedOption == option,
                        accentColor: accentColor,
                        onTap: () => onSelect(option),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FirstDayOfWeekSettingsSection extends StatelessWidget {
  final String selectedOption;
  final Color accentColor;
  final ValueChanged<String> onSelect;

  const _FirstDayOfWeekSettingsSection({
    required this.selectedOption,
    required this.accentColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: appSystemFirstDayOfWeekNotifier,
      builder: (context, systemDay, _) {
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MirrorSystemSettingSection(
                  systemSettingRow: _OptionRow(
                    title: 'System Setting ($systemDay)',
                    selected: selectedOption == 'System',
                    accentColor: accentColor,
                    onTap: () => onSelect('System'),
                  ),
                  settingsScreenName:
                      _systemFirstDayOfWeekSettingsDestination(),
                ),
                const SizedBox(height: 20),
                SkeddoAppOnlySettingsSection(
                  rows: [
                    for (final day in kFirstDayOfWeekOptions)
                      _OptionRow(
                        title: day,
                        selected: selectedOption == day,
                        accentColor: accentColor,
                        onTap: () => onSelect(day),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

String _systemThemeSettingsDestination() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Display',
    TargetPlatform.iOS => 'Display & Brightness',
    _ => 'Display',
  };
}

String _systemFirstDayOfWeekSettingsDestination() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Regional preferences',
    TargetPlatform.iOS => 'Language & Region',
    _ => 'Language & Region',
  };
}

String _systemTextSizeSettingsDestination() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android => 'Font Size',
    TargetPlatform.iOS => 'Display & Text Size',
    _ => 'Font Size',
  };
}

const String _mirrorSystemSettingSectionTitle = 'Mirror System Setting';
const String _skeddoAppOnlySectionTitle = 'Skeddo App Only';
const String _skeddoAppOnlySectionFooter =
    'This setting will apply in Skeddo only. Other apps will use the system setting.';

/// Shared card, heading, and context-footer styling for Settings subsections.
class SettingsPanelSection extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  final String? footer;

  const SettingsPanelSection({
    super.key,
    required this.title,
    required this.rows,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final cardBg = resolveThemeColor(kCardColor, context);
    final shadowColor = resolveThemeColor(kCardShadowColor, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontFamily: kSFProText,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: resolveThemeColor(kSecondaryLabel, context),
            ),
          ),
        ),
        _SettingsCard(rows: rows, cardBg: cardBg, shadowColor: shadowColor),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, top: 8),
            child: Text(
              footer!,
              style: TextStyle(
                fontFamily: kSFProText,
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: resolveThemeColor(kSecondaryLabel, context),
              ),
            ),
          ),
      ],
    );
  }
}

class _DateFormatSettingsSection extends StatelessWidget {
  final Color accentColor;
  final ValueChanged<String> onSelect;

  const _DateFormatSettingsSection({
    required this.accentColor,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        appDateFormatUsesSystemNotifier,
        appSystemDateFormatNotifier,
        appSystemDateFormatSampleNotifier,
        appCustomDateFormatNotifier,
      ]),
      builder: (context, _) {
        final usesSystem = appDateFormatUsesSystemNotifier.value;
        final appOnlyFormat = appCustomDateFormatNotifier.value;
        final settingsScreenName = switch (defaultTargetPlatform) {
          TargetPlatform.android => 'Regional preferences',
          TargetPlatform.iOS => 'Language & Region',
          _ => 'regional settings',
        };
        final optionRows = AppDateFormat.values
            .map(
              (format) => _OptionRow(
                title: format.sample,
                selected: !usesSystem && format == appOnlyFormat,
                accentColor: accentColor,
                onTap: () => onSelect(format.sample),
              ),
            )
            .toList();

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MirrorSystemSettingSection(
                  systemSettingRow: _OptionRow(
                    title: appSystemDateFormatSampleNotifier.value == null
                        ? 'System Setting'
                        : 'System Setting (${appSystemDateFormatSampleNotifier.value})',
                    selected: usesSystem,
                    accentColor: accentColor,
                    onTap: () => onSelect('System'),
                  ),
                  settingsScreenName: settingsScreenName,
                ),
                const SizedBox(height: 20),
                SkeddoAppOnlySettingsSection(
                  rows: optionRows,
                  additionalFooter: appOnlyFormat.contextFooter,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Standard "Skeddo App Only" section and its explanatory footer.
class SkeddoAppOnlySettingsSection extends StatelessWidget {
  final List<Widget> rows;
  final String? additionalFooter;

  const SkeddoAppOnlySettingsSection({
    super.key,
    required this.rows,
    this.additionalFooter,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsPanelSection(
      title: _skeddoAppOnlySectionTitle,
      rows: rows,
      footer: additionalFooter == null
          ? _skeddoAppOnlySectionFooter
          : '$_skeddoAppOnlySectionFooter\n\n$additionalFooter',
    );
  }
}

/// Shared styling for a system-backed option in any Settings sub-screen.
///
/// Use this for each "Mirror System Setting" section so its heading, card,
/// row spacing, and source-screen footer remain consistent across settings.
class MirrorSystemSettingSection extends StatelessWidget {
  final Widget systemSettingRow;
  final String settingsScreenName;
  final String? footer;

  const MirrorSystemSettingSection({
    super.key,
    required this.systemSettingRow,
    required this.settingsScreenName,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsPanelSection(
      title: _mirrorSystemSettingSectionTitle,
      rows: [systemSettingRow],
      footer:
          footer ??
          'When selected, Skeddo will use the setting from $settingsScreenName.',
    );
  }
}

// ── Text-size mode and seven-position custom slider ────────────────────────────
class _TextSizeSection extends StatelessWidget {
  final Color accentColor;

  const _TextSizeSection({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        appTextSizeUsesSystemNotifier,
        appTextSizeIndexNotifier,
        appSystemTextScaleNotifier,
        appSkeddoTextScaleStopsNotifier,
      ]),
      builder: (context, _) {
        final usesSystem = appTextSizeUsesSystemNotifier.value;
        final systemScaleIndex = skeddoTextScaleIndexForSystemScale(
          appSystemTextScaleNotifier.value,
        );
        final customIndex = usesSystem
            ? systemScaleIndex
            : appTextSizeIndexNotifier.value;

        void selectSystem() {
          if (!appTextSizeUsesSystemNotifier.value) {
            appTextSizeUsesSystemNotifier.value = true;
            saveAppSetting('Text Size', 'System');
          }
        }

        void selectCustom(double value) {
          final index = value.round().clamp(0, 6);
          selectCustomTextScaleIndex(index);
          saveAppSetting('Text Size', 'Custom');
        }

        void previewCustom(double value) {
          final index = value.round().clamp(0, 6);
          // Previewing a different position is an explicit Custom change:
          // capture its scaler now so a later native refresh cannot replace
          // the behavior the user just selected.
          selectCustomTextScaleIndex(index);
        }

        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MirrorSystemSettingSection(
                  systemSettingRow: _OptionRow(
                    title: 'System Setting',
                    selected: usesSystem,
                    accentColor: accentColor,
                    onTap: selectSystem,
                  ),
                  settingsScreenName: _systemTextSizeSettingsDestination(),
                ),
                const SizedBox(height: 20),
                SkeddoAppOnlySettingsSection(
                  rows: [
                    _TextSizeSliderRow(
                      index: customIndex,
                      animateChanges: usesSystem,
                      accentColor: accentColor,
                      onChanged: previewCustom,
                      onChangeEnd: selectCustom,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _TextSizeSliderRow extends StatefulWidget {
  final int index;
  final bool animateChanges;
  final Color accentColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _TextSizeSliderRow({
    required this.index,
    required this.animateChanges,
    required this.accentColor,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  State<_TextSizeSliderRow> createState() => _TextSizeSliderRowState();
}

class _TextSizeSliderRowState extends State<_TextSizeSliderRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 420),
  );
  late Animation<double> _indexAnimation;
  double? _dragValue;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _indexAnimation = AlwaysStoppedAnimation(widget.index.toDouble());
  }

  @override
  void didUpdateWidget(_TextSizeSliderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Previewing a text-size position updates the parent while the finger is
    // still down. Keep the slider's raw finger position until release so that
    // those discrete text-size updates do not lock the thumb to a tick.
    if (_isDragging) return;
    if (oldWidget.index != widget.index) {
      _dragValue = null;
    }
    if (widget.animateChanges && oldWidget.index != widget.index) {
      final begin = _indexAnimation.value;
      _indexAnimation =
          Tween<double>(begin: begin, end: widget.index.toDouble()).animate(
            CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
          );
      _controller
        ..stop()
        ..value = 0
        ..forward();
    } else if (!_controller.isAnimating) {
      _indexAnimation = AlwaysStoppedAnimation(widget.index.toDouble());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final inactiveColor = resolveThemeColor(kTertiaryLabel, context);
    final emptyStateGreyColor = resolveThemeColor(kEmptyStateIcon, context);
    return Padding(
      // The 52 pt control box is the complete compact slider row. Do not add
      // a second vertical row padding around the lifted-thumb capture.
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: _kSettingsRowHeight,
        child: AnimatedBuilder(
          animation: _indexAnimation,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              // Match Liquid Glass's tuned endpoint geometry exactly: the
              // settled thumb centers sit 16 px inside the visible card edge.
              final sliderWidth =
                  constraints.maxWidth +
                  2 *
                      (_kLiquidGlassRowHorizontalPadding -
                          _kLiquidGlassSettledEdgeInset);
              return OverflowBox(
                alignment: Alignment.center,
                minWidth: sliderWidth,
                maxWidth: sliderWidth,
                child: !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
                    ? NativeFluidSliderRow(
                        value: _dragValue ?? _indexAnimation.value / 6,
                        minimumValue: 0,
                        maximumValue: 1,
                        minimumIcon: 'TextSizeSmaller',
                        maximumIcon: 'TextSizeLarger',
                        iconSize: 20,
                        divisions: 6,
                        accentColor: widget.accentColor,
                        tickColor: inactiveColor,
                        darkMode:
                            CupertinoTheme.brightnessOf(context) ==
                            Brightness.dark,
                        height: _kSettingsRowHeight,
                        onChangeStart: (_) {
                          if (!_isDragging) {
                            setState(() => _isDragging = true);
                          }
                        },
                        onChanged: (raw) {
                          setState(() => _dragValue = raw);
                          widget.onChanged(raw * 6);
                        },
                        onChangeEnd: (raw) {
                          final settled = (raw * 6).roundToDouble() / 6;
                          setState(() {
                            _dragValue = settled;
                            _isDragging = false;
                          });
                          widget.onChangeEnd(settled * 6);
                        },
                      )
                    : Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: CustomPaint(
                                painter: _TextSizeSliderTicksPainter(
                                  color: inactiveColor,
                                  sliderWidth: sliderWidth,
                                ),
                              ),
                            ),
                          ),
                          // Paint the marks first so the resting thumb covers
                          // the selected mark instead of drawing it on top.
                          glass_slider.LiquidGlassSlider(
                            value: _dragValue ?? _indexAnimation.value / 6,
                            minimumValue: 0,
                            maximumValue: 1,
                            width: sliderWidth,
                            height: _kSettingsRowHeight,
                            layout: _liquidGlassSliderLayout,
                            isContinuous: true,
                            activeColor: widget.accentColor,
                            inactiveColor: inactiveColor,
                            thumbColor: const Color(0xFFFDFDFD),
                            minimumIcon: Icon(
                              SFIcons.sf_textformat_size_smaller,
                              size: 20,
                              color: emptyStateGreyColor,
                            ),
                            maximumIcon: Icon(
                              SFIcons.sf_textformat_size_larger,
                              size: 20,
                              color: emptyStateGreyColor,
                            ),
                            onChangeStart: (_) {
                              if (!_isDragging) {
                                setState(() => _isDragging = true);
                              }
                            },
                            onChanged: (raw) {
                              setState(() => _dragValue = raw);
                              widget.onChanged((raw * 6).roundToDouble());
                            },
                            onChangeEnd: (raw) {
                              final settled = (raw * 6).roundToDouble() / 6;
                              setState(() {
                                _dragValue = settled;
                                _isDragging = false;
                              });
                              widget.onChangeEnd(settled * 6);
                            },
                          ),
                        ],
                      ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TextSizeSliderTicksPainter extends CustomPainter {
  final Color color;
  final double sliderWidth;

  const _TextSizeSliderTicksPainter({
    required this.color,
    required this.sliderWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const tickDiameter = 3.0;
    final layout = _liquidGlassSliderLayout;
    final trackStart = layout.iconSize + layout.iconGap;
    final trackEnd = sliderWidth - trackStart;
    final firstThumbCenter = trackStart + layout.thumbWidth / 2;
    final lastThumbCenter = trackEnd - layout.thumbWidth / 2;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    for (var step = 0; step <= 6; step++) {
      // Marks align with every settled thumb center, not the track's outer
      // endpoints. This leaves both extreme steps inset by half a thumb.
      final x =
          firstThumbCenter + (lastThumbCenter - firstThumbCenter) * step / 6;
      canvas.drawCircle(
        Offset(x, size.height / 2 + 8),
        tickDiameter / 2,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TextSizeSliderTicksPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.sliderWidth != sliderWidth;
}

// ── Liquid Glass opacity control ──────────────────────────────────────────────
class _LiquidGlassSection extends StatelessWidget {
  const _LiquidGlassSection();

  @override
  Widget build(BuildContext context) {
    final cardBg = resolveThemeColor(kCardColor, context);
    final shadowColor = resolveThemeColor(kCardShadowColor, context);
    final accent = resolveAccentColor(context);
    final inactive = resolveThemeColor(kTertiaryLabel, context);
    final emptyStateGrey = resolveThemeColor(kEmptyStateIcon, context);
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final backgroundAsset = isDark
        ? 'assets/liquid_glass_background_dark.webp'
        : 'assets/liquid_glass_background_light.webp';
    const previewShape = kLiquidGlassPreviewCardShape;
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Column(
          children: [
            DecoratedBox(
              decoration: ShapeDecoration(
                color: cardBg,
                shadows: resolveThemeShadows([
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ], context),
                shape: previewShape,
              ),
              child: SizedBox(
                width: double.infinity,
                height: kLiquidGlassPreviewHeight,
                child: ClipPath(
                  clipper: ShapeBorderClipper(shape: previewShape),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AccentTintedImage(
                        assetName: backgroundAsset,
                        accentColor: accent,
                      ),
                      Center(
                        child: ValueListenableBuilder<double>(
                          valueListenable: appLiquidGlassOpacityNotifier,
                          builder: (context, value, _) =>
                              FloatingTabBarGlassPreview(
                                sliderPosition:
                                    liquidGlassSliderPositionForOpacity(value),
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: ShapeDecoration(
                color: cardBg,
                shadows: resolveThemeShadows([
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ], context),
                shape: const BoundedSquircleStadiumBorder(),
              ),
              child: SizedBox(
                height: _kSettingsRowHeight,
                child: ValueListenableBuilder<double>(
                  valueListenable: appLiquidGlassOpacityNotifier,
                  builder: (context, value, _) {
                    final normalized = liquidGlassSliderPositionForOpacity(
                      value,
                    );
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: _LiquidGlassTestIcons(
                        value: normalized,
                        surfaceColor: cardBg,
                        secondaryColor: emptyStateGrey,
                        activeColor: accent,
                        inactiveColor: inactive,
                        darkMode: isDark,
                        onChanged: _setLiquidGlassOpacityLive,
                        onChangeEnd: _setLiquidGlassOpacity,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const _kLiquidGlassSurfaceToken = '__SURFACE__';
const _kLiquidGlassSecondaryToken = '__SECONDARY__';

class _LiquidGlassTestIcons extends StatefulWidget {
  final double value;
  final Color surfaceColor;
  final Color secondaryColor;
  final Color activeColor;
  final Color inactiveColor;
  final bool darkMode;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _LiquidGlassTestIcons({
    required this.value,
    required this.surfaceColor,
    required this.secondaryColor,
    required this.activeColor,
    required this.inactiveColor,
    required this.darkMode,
    required this.onChanged,
    required this.onChangeEnd,
  });

  @override
  State<_LiquidGlassTestIcons> createState() => _LiquidGlassTestIconsState();
}

class _LiquidGlassTestIconsState extends State<_LiquidGlassTestIcons> {
  late final Future<List<String>> _svgSources = Future.wait([
    rootBundle.loadString('assets/icons/Liquid_Glass_left.svg'),
    rootBundle.loadString('assets/icons/Liquid_Glass_right.svg'),
  ]);
  double? _dragValue;
  bool _isDragging = false;

  @override
  void didUpdateWidget(covariant _LiquidGlassTestIcons oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The live opacity notifier rebuilds this subtree on every drag frame.
    // While the finger owns the slider, keep using its local raw position;
    // otherwise the parent rebuild can feed a competing value back into the
    // gesture and make the web control appear tick-locked.
    if (!_isDragging && oldWidget.value != widget.value) {
      _dragValue = null;
    }
  }

  String _svgColor(Color color) {
    final red = (color.r * 255.0).round() & 0xff;
    final green = (color.g * 255.0).round() & 0xff;
    final blue = (color.b * 255.0).round() & 0xff;
    return 'rgba($red, $green, $blue, ${color.a.toStringAsFixed(3)})';
  }

  String _withThemeColors(String svg) {
    return svg
        .replaceAll(_kLiquidGlassSurfaceToken, _svgColor(widget.surfaceColor))
        .replaceAll(
          _kLiquidGlassSecondaryToken,
          _svgColor(widget.secondaryColor),
        );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return NativeFluidSliderRow(
        value: _dragValue ?? widget.value,
        minimumValue: 0,
        maximumValue: 1,
        minimumIcon: 'LiquidGlassLeft',
        maximumIcon: 'LiquidGlassRight',
        iconSize: 34,
        divisions: 0,
        accentColor: widget.activeColor,
        tickColor: widget.inactiveColor,
        stepMarkerValue: kDefaultLiquidGlassSliderPosition,
        stepMarkerColor: widget.inactiveColor,
        darkMode: widget.darkMode,
        height: _kSettingsRowHeight,
        onChangeStart: (_) {
          if (!_isDragging) {
            setState(() => _isDragging = true);
          }
        },
        onChanged: (value) {
          setState(() => _dragValue = value);
          widget.onChanged(value);
        },
        onChangeEnd: (value) {
          final settled = settleLiquidGlassSliderPosition(value);
          setState(() {
            _dragValue = settled;
            _isDragging = false;
          });
          widget.onChangeEnd(settled);
        },
      );
    }
    return FutureBuilder<List<String>>(
      future: _svgSources,
      builder: (context, snapshot) {
        final sources = snapshot.data;
        if (sources == null || sources.length != 2) {
          return const SizedBox.expand();
        }
        return Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return glass_slider.LiquidGlassSlider(
                value: _dragValue ?? widget.value,
                minimumValue: 0,
                maximumValue: 1,
                width: constraints.maxWidth,
                height: _kSettingsRowHeight,
                layout: const glass_slider.LiquidGlassSliderLayout(
                  iconSize: 34,
                  iconGap: 8,
                  horizontalInset: 0,
                ),
                activeColor: widget.activeColor,
                inactiveColor: widget.inactiveColor,
                thumbColor: const Color(0xFFFDFDFD),
                stepMarkerValue: kDefaultLiquidGlassSliderPosition,
                stepMarkerColor: widget.inactiveColor,
                minimumIcon: SvgPicture.string(
                  _withThemeColors(sources[0]),
                  width: 34,
                  height: 34,
                ),
                maximumIcon: SvgPicture.string(
                  _withThemeColors(sources[1]),
                  width: 34,
                  height: 34,
                ),
                onChangeStart: (_) {
                  if (!_isDragging) {
                    setState(() => _isDragging = true);
                  }
                },
                onChanged: (value) {
                  setState(() => _dragValue = value);
                  widget.onChanged(value);
                },
                onChangeEnd: (value) {
                  final settled = settleLiquidGlassSliderPosition(value);
                  setState(() {
                    _dragValue = settled;
                    _isDragging = false;
                  });
                  widget.onChangeEnd(settled);
                },
              );
            },
          ),
        );
      },
    );
  }
}

// The slider row has a fixed 18 px content inset. The settled thumb must sit
// 16 px inside the stadium row edge at either endpoint.
const double _kLiquidGlassRowHorizontalPadding = 18.0;
const double _kLiquidGlassSettledEdgeInset = 16.0;
// Zero inset aligns the line's outer endpoints with the resting thumb's edges.
// Discrete tick bars span the full track, flush to those outer endpoints.
const double _kLiquidGlassSliderInset = 0.0;
const glass_slider.LiquidGlassSliderLayout _liquidGlassSliderLayout =
    glass_slider.LiquidGlassSliderLayout(
      horizontalInset: _kLiquidGlassSliderInset,
    );

void _setLiquidGlassOpacityLive(double raw) {
  final liveValue = liquidGlassOpacityForSliderPosition(raw);
  if (liveValue != appLiquidGlassOpacityNotifier.value) {
    appLiquidGlassOpacityNotifier.value = liveValue;
  }
}

void _setLiquidGlassOpacity(double raw) {
  final snapped = liquidGlassOpacityForSliderPosition(
    settleLiquidGlassSliderPosition(raw),
  );
  if (snapped != appLiquidGlassOpacityNotifier.value) {
    appLiquidGlassOpacityNotifier.value = snapped;
  }
  // The live drag callback has usually already set the notifier to this same
  // snapped value. Persist on every release rather than using that equality as
  // a save guard, otherwise the user's new value is lost on restart.
  saveAppSetting('Liquid Glass', snapped.toString());
}

// ── Squircle card shell shared by both section types ──────────────────────────
class _SettingsCard extends StatelessWidget {
  final List<Widget> rows;
  final Color cardBg;
  final Color shadowColor;

  const _SettingsCard({
    required this.rows,
    required this.cardBg,
    required this.shadowColor,
  });

  @override
  Widget build(BuildContext context) {
    const ShapeBorder shape = BoundedSquircleStadiumBorder();
    return DecoratedBox(
      decoration: ShapeDecoration(
        color: cardBg,
        shadows: resolveThemeShadows([
          BoxShadow(
            color: shadowColor,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ], context),
        shape: shape,
      ),
      child: ClipPath(
        clipper: ShapeBorderClipper(shape: shape),
        child: Column(
          children: [
            for (int i = 0; i < rows.length; i++) ...[
              rows[i],
              if (i < rows.length - 1)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    height: 0.5,
                    color: resolveThemeColor(kSeparatorColor, context),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Tappable settings row ─────────────────────────────────────────────────────
const double _kSettingsRowHeight = 52.0;
const double _kSettingsRowVerticalPadding = kFixedVerticalPadding;

double _settingsWrappedTextHeight(
  BuildContext context,
  String text,
  TextStyle style,
  double width,
) {
  if (text.isEmpty) return 0.0;
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout(maxWidth: width.clamp(1.0, double.infinity).toDouble());
  return painter.height;
}

double _settingsMasterRowHeight(
  BuildContext context, {
  required String title,
  Widget? trailing,
  bool hasSwitch = false,
  required double rowWidth,
}) {
  final contentWidth = (rowWidth - 32.0).clamp(1.0, double.infinity).toDouble();
  final titleStyle = TextStyle(
    fontFamily: kSFProText,
    fontSize: 17,
    fontWeight: FontWeight.w400,
  );
  final valueStyle = TextStyle(
    fontFamily: kSFProText,
    fontSize: 15,
    fontWeight: FontWeight.w400,
  );
  final chevronWidth = _settingsChevronFontSize(context);
  double textHeight(String text, TextStyle style, double width) =>
      _settingsWrappedTextHeight(context, text, style, width);

  double contentHeight;
  if (hasSwitch) {
    contentHeight = textHeight(title, titleStyle, contentWidth - 56.0 - 12.0);
  } else if (trailing is _ChevronTrailing) {
    contentHeight = max(
      textHeight(
        title,
        titleStyle,
        contentWidth - kLabelValueGap - chevronWidth,
      ),
      chevronWidth,
    );
  } else if (trailing is _ValueTrailing || trailing is _ColorTrailing) {
    final value = trailing is _ValueTrailing
        ? trailing.text
        : (trailing as _ColorTrailing).name;
    final trailingExtra = trailing is _ValueTrailing ? 22.0 : 40.0;
    final gap = kLabelValueGap;
    final valueTextWidth = max(1.0, contentWidth * 0.38 - trailingExtra);
    final titleWidth = max(
      1.0,
      contentWidth - gap - trailingExtra - valueTextWidth,
    );
    contentHeight = max(
      textHeight(title, titleStyle, titleWidth),
      textHeight(value, valueStyle, valueTextWidth),
    );
  } else {
    contentHeight = textHeight(title, titleStyle, contentWidth);
  }
  return max(
    _kSettingsRowHeight,
    contentHeight + 2 * _kSettingsRowVerticalPadding,
  );
}

Widget _settingsMasterRowAtPaneProgress(
  BuildContext context, {
  required BoxConstraints constraints,
  required String title,
  Widget? trailing,
  bool hasSwitch = false,
  required Widget child,
}) {
  final scope = AppWindowMasterDetailProgressScope.maybeOf(context);
  if (scope == null || !constraints.maxWidth.isFinite) return child;
  final fullWidth = scope.widthAtEndpoint(constraints.maxWidth, compact: false);
  final compactWidth = scope.widthAtEndpoint(
    constraints.maxWidth,
    compact: true,
  );
  final fullHeight = _settingsMasterRowHeight(
    context,
    title: title,
    trailing: trailing,
    hasSwitch: hasSwitch,
    rowWidth: fullWidth,
  );
  final compactHeight = _settingsMasterRowHeight(
    context,
    title: title,
    trailing: trailing,
    hasSwitch: hasSwitch,
    rowWidth: compactWidth,
  );
  final height = fullHeight + (compactHeight - fullHeight) * scope.value;
  return ClipRect(
    child: SizedBox(height: height, child: child),
  );
}

class _SettingsRow extends StatefulWidget {
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({
    super.key,
    required this.title,
    this.trailing,
    this.onTap,
  });

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _settingsMasterRowAtPaneProgress(
        context,
        constraints: constraints,
        title: widget.title,
        trailing: widget.trailing,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) {
            setState(() => _pressed = false);
            widget.onTap?.call();
          },
          onTapCancel: () => setState(() => _pressed = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            color: _pressed ? kActionPanelGroupBreak : const Color(0x00000000),
            constraints: const BoxConstraints(minHeight: _kSettingsRowHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: _kSettingsRowVerticalPadding,
            ),
            alignment: Alignment.centerLeft,
            child: _buildSettingsRowContent(context),
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsRowContent(BuildContext context) {
    final labelStyle = TextStyle(
      fontFamily: kSFProText,
      fontSize: 17,
      fontWeight: FontWeight.w400,
      color: resolveThemeColor(kPrimaryLabel, context),
    );

    if (widget.trailing is _ValueTrailing) {
      final trailing = widget.trailing! as _ValueTrailing;
      return MinGapLabelValueRow(
        animateHeight:
            AppWindowMasterDetailProgressScope.maybeOf(context) == null,
        label: widget.title,
        labelStyle: labelStyle,
        value: trailing.text,
        valueStyle: TextStyle(
          fontFamily: kSFProText,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: resolveThemeColor(kSecondaryLabel, context),
        ),
        trailing: trailing,
        trailingExtraWidth: 22,
      );
    }
    if (widget.trailing is _ColorTrailing) {
      final trailing = widget.trailing! as _ColorTrailing;
      return MinGapLabelValueRow(
        animateHeight:
            AppWindowMasterDetailProgressScope.maybeOf(context) == null,
        label: widget.title,
        labelStyle: labelStyle,
        value: trailing.name,
        valueStyle: TextStyle(
          fontFamily: kSFProText,
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: resolveThemeColor(kSecondaryLabel, context),
        ),
        trailing: trailing,
        // Swatch + spacing + chevron occupy the non-text portion of the
        // right-pinned value group.
        trailingExtraWidth: 40,
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: Text(widget.title, style: labelStyle, softWrap: true)),
        if (widget.trailing != null) ...[
          const SizedBox(width: kLabelValueGap),
          if (widget.trailing is _ChevronTrailing)
            widget.trailing!
          else
            Flexible(child: widget.trailing!),
        ],
      ],
    );
  }
}

// ── Toggle settings row ───────────────────────────────────────────────────────
class _SettingsToggleRow extends StatefulWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SettingsToggleRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  @override
  State<_SettingsToggleRow> createState() => _SettingsToggleRowState();
}

class _SettingsToggleRowState extends State<_SettingsToggleRow> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value;
  }

  void _setValue(bool value) {
    setState(() => _value = value);
    widget.onChanged(value);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => _settingsMasterRowAtPaneProgress(
        context,
        constraints: constraints,
        title: widget.title,
        hasSwitch: true,
        child: AppSwitchRow(
          value: _value,
          onChanged: _setValue,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: _kSettingsRowHeight),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: _kSettingsRowVerticalPadding,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      widget.title,
                      style: TextStyle(
                        fontFamily: kSFProText,
                        fontSize: 17,
                        fontWeight: FontWeight.w400,
                        color: resolveThemeColor(kPrimaryLabel, context),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 70 * 0.80,
                    height: 30,
                    child: OverflowBox(
                      maxWidth: 70,
                      maxHeight: 31,
                      alignment: Alignment.center,
                      child: Transform.scale(
                        scale: 0.80,
                        child: AppSwitch(
                          value: _value,
                          color: resolveAccentColor(context),
                          height: 31,
                          onChanged: _setValue,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionRow extends StatefulWidget {
  final String title;
  final bool selected;
  final Color accentColor;
  final Color? leadingColor;
  final VoidCallback? onTap;

  const _OptionRow({
    required this.title,
    required this.selected,
    required this.accentColor,
    this.leadingColor,
    this.onTap,
  });

  @override
  State<_OptionRow> createState() => _OptionRowState();
}

class _OptionRowState extends State<_OptionRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _pressed ? kActionPanelGroupBreak : const Color(0x00000000),
        constraints: const BoxConstraints(minHeight: _kSettingsRowHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _kSettingsRowVerticalPadding,
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (widget.leadingColor != null) ...[
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: widget.leadingColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                widget.title,
                style: TextStyle(
                  fontFamily: kSFProText,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: resolveThemeColor(kPrimaryLabel, context),
                ),
              ),
            ),
            _SettingsCheckmarkSlot(
              selected: widget.selected,
              accentColor: widget.accentColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Accent-color picker section (sub-screen body)
// ══════════════════════════════════════════════════════════════════════════════

// The system-backed accent and SKEDDO-only swatches are separate sections.
class _AccentColorSection extends StatelessWidget {
  final ValueNotifier<int> accentNotifier;

  const _AccentColorSection({required this.accentNotifier});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        accentNotifier,
        appAccentUsesSystemNotifier,
        appSystemAccentColorNotifier,
      ]),
      builder: (context, _) {
        final usesSystem = appAccentUsesSystemNotifier.value;
        final systemAccentColor = CupertinoDynamicColor.resolve(
          appSystemAccentColorNotifier.value,
          context,
        );
        final resolvedAccent = resolveAccentColor(context);
        final rows = List.generate(_kAccentSwatches.length, (i) {
          final swatch = _kAccentSwatches[i];
          final resolvedColor = CupertinoDynamicColor.resolve(
            swatch.color,
            context,
          );
          return _AccentSwatchRow(
            swatch: swatch,
            resolvedColor: resolvedColor,
            selected: !usesSystem && i == accentNotifier.value,
            accentColor: resolvedAccent,
            onTap: () {
              appAccentUsesSystemNotifier.value = false;
              saveAccentUsesSystem(false);
              accentNotifier.value = i;
              saveAccentIndex(i);
            },
          );
        });
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                MirrorSystemSettingSection(
                  systemSettingRow: _OptionRow(
                    title: 'System Setting',
                    selected: usesSystem,
                    accentColor: resolvedAccent,
                    leadingColor: systemAccentColor,
                    onTap: () {
                      if (appAccentUsesSystemNotifier.value) return;
                      appAccentUsesSystemNotifier.value = true;
                      saveAccentUsesSystem(true);
                    },
                  ),
                  settingsScreenName: 'your device',
                  footer:
                      'When selected, Skeddo uses your device’s system accent color.',
                ),
                const SizedBox(height: 20),
                SkeddoAppOnlySettingsSection(rows: rows),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ── Single swatch row ─────────────────────────────────────────────────────────
class _AccentSwatchRow extends StatefulWidget {
  final _AccentSwatch swatch;
  final Color resolvedColor;
  final bool selected;
  // The currently active accent — used to tint the label and checkmark of the
  // selected row so they reflect the live accent value.
  final Color accentColor;
  final VoidCallback onTap;

  const _AccentSwatchRow({
    required this.swatch,
    required this.resolvedColor,
    required this.selected,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<_AccentSwatchRow> createState() => _AccentSwatchRowState();
}

class _AccentSwatchRowState extends State<_AccentSwatchRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        color: _pressed ? kActionPanelGroupBreak : const Color(0x00000000),
        constraints: const BoxConstraints(minHeight: _kSettingsRowHeight),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: _kSettingsRowVerticalPadding,
        ),
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            // 12 px filled circle swatch
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: widget.resolvedColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Color name — always Primary; only the checkmark takes accent color.
            Expanded(
              child: Text(
                widget.swatch.name,
                style: TextStyle(
                  fontFamily: kSFProText,
                  fontSize: 17,
                  fontWeight: FontWeight.w400,
                  color: resolveThemeColor(kPrimaryLabel, context),
                ),
              ),
            ),
            _SettingsCheckmarkSlot(
              selected: widget.selected,
              accentColor: widget.accentColor,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Trailing widgets ──────────────────────────────────────────────────────────
double _settingsScaledFontSize(BuildContext context, double baseSize) {
  return MediaQuery.textScalerOf(context).scale(baseSize);
}

const double _kSettingsCheckmarkGap = 16.0;
const double _kSettingsCheckmarkBaseSize = 17.0;

/// Reserves the trailing checkmark column for every selectable subscreen row.
///
/// The slot includes the fixed 16 pt label-to-checkmark gap and the scaled
/// checkmark width. The row's own 16 pt horizontal padding supplies the fixed
/// checkmark-to-edge inset. Keeping the slot present for unselected rows also
/// prevents labels from changing width as selection moves.
class _SettingsCheckmarkSlot extends StatelessWidget {
  final bool selected;
  final Color accentColor;

  const _SettingsCheckmarkSlot({
    required this.selected,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final checkmarkSize = _settingsScaledFontSize(
      context,
      _kSettingsCheckmarkBaseSize,
    );
    return SizedBox(
      width: _kSettingsCheckmarkGap + checkmarkSize,
      child: Align(
        alignment: Alignment.centerRight,
        child: selected
            ? FixedSFIcon(
                SFIcons.sf_checkmark,
                fontSize: checkmarkSize,
                fontWeight: FontWeight.w500,
                color: accentColor,
              )
            : SizedBox(width: checkmarkSize, height: checkmarkSize),
      ),
    );
  }
}

double _settingsChevronFontSize(BuildContext context) {
  // FixedSFIcon intentionally disables inherited scaling, so apply the
  // system text scaler explicitly to match the adjacent setting value.
  return _settingsScaledFontSize(context, 14);
}

class _ChevronTrailing extends StatelessWidget {
  const _ChevronTrailing();

  @override
  Widget build(BuildContext context) {
    return FixedSFIcon(
      SFIcons.sf_chevron_right,
      fontSize: _settingsChevronFontSize(context),
      fontWeight: FontWeight.w500,
      color: resolveThemeColor(kSecondaryLabel, context),
    );
  }
}

class _ValueTrailing extends StatelessWidget {
  final String text;
  const _ValueTrailing(this.text);

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontFamily: kSFProText,
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: resolveThemeColor(kSecondaryLabel, context),
    );
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Flexible(child: _WrappingValueText(text, style: style)),
        const SizedBox(width: 4),
        FixedSFIcon(
          SFIcons.sf_chevron_right,
          fontSize: _settingsChevronFontSize(context),
          fontWeight: FontWeight.w500,
          color: resolveThemeColor(kSecondaryLabel, context),
        ),
      ],
    );
  }
}

/// Displays a trailing setting value with the chevron pinned to the row's
/// trailing edge. The value is allowed to wrap instead of being truncated when
/// the label and value need more horizontal room.
class _WrappingValueText extends StatelessWidget {
  final String text;
  final TextStyle style;

  const _WrappingValueText(this.text, {required this.style});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => Text(
        chevronValueTextForWidth(context, text, style, constraints.maxWidth),
        textAlign: TextAlign.right,
        softWrap: true,
        style: style,
      ),
    );
  }
}

// ── Color-swatch trailing (Accent Color row in main list) ─────────────────────
// Layout: 12 px circle ▸ color name (secondary) ▸ chevron.
class _ColorTrailing extends StatelessWidget {
  final Color color;
  final String name;
  const _ColorTrailing({required this.color, required this.name});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // 12 px filled circle in the current accent color.
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        // Color name label in secondary gray.
        Flexible(
          child: LayoutBuilder(
            builder: (context, constraints) => Text(
              chevronValueTextForWidth(
                context,
                name,
                TextStyle(
                  fontFamily: kSFProText,
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: resolveThemeColor(kSecondaryLabel, context),
                ),
                constraints.maxWidth,
              ),
              textAlign: TextAlign.right,
              softWrap: true,
              style: TextStyle(
                fontFamily: kSFProText,
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: resolveThemeColor(kSecondaryLabel, context),
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        FixedSFIcon(
          SFIcons.sf_chevron_right,
          fontSize: _settingsChevronFontSize(context),
          fontWeight: FontWeight.w500,
          color: resolveThemeColor(kSecondaryLabel, context),
        ),
      ],
    );
  }
}
