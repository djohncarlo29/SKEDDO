import 'dart:async';
import 'dart:io';
import 'dart:math' show max, min;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:dynamic_color/dynamic_color.dart'
    show DynamicColorBuilder, DynamicColorBuilderState;
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:flutter_liquid_glass_widgets/liquid_glass_widgets.dart'
    show LiquidGlassWidgets;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass
    show
        GlassBarItem,
        GlassBarItemBackground,
        GlassEffectTransition,
        GlassNavigationShell,
        LiquidGlassWidgets;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassMenuDivider, GlassMenuItem;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'ai/ai_services.dart';
import 'ai/event_pipeline.dart';
import 'app_theme.dart';
import 'services/event_store.dart';
import 'services/local_storage.dart';
import 'services/system_accent_color.dart';
import 'services/window_caption_appearance.dart';
import 'tabs/calendar_tab.dart';
import 'tabs/events_tab.dart';
import 'tabs/notes_tab.dart';
import 'widgets/action_panel.dart';
import 'widgets/accent_tinted_image.dart';
import 'widgets/app_header_scroll_edge.dart';
import 'widgets/app_window_content_boundary.dart';
import 'widgets/dcv_keyboard_layout.dart';
import 'widgets/fixed_size_icon.dart';
import 'widgets/floating_tab_pill.dart';
import 'widgets/header_title_scroller.dart';
import 'widgets/interactive_tap_focus_dismissal.dart';
import 'widgets/live_rotation_geometry.dart';
import 'widgets/app_shell_toolbar.dart';
import 'widgets/app_shell_navigation_scope.dart';
import 'widgets/native_text_input.dart';
import 'widgets/search_bar_widget.dart';
import 'widgets/rounded_cupertino_sheet.dart'
    show RoundedSheetAppShellDimmer;
import 'widgets/skeddo_glass_settings.dart'
    show
        skeddoNavigationGlassSettingsFromShared,
        skeddoPopoverGlassSettingsFor;
import 'widgets/view_mode_icons.dart';
import 'app_settings.dart';
import 'settings_panel.dart';

// ══════════════════════════════════════════════════════════════════════════════
// _DcvMenuContent — stateful overlay widget for the DCV ellipsis menu.
//
// Owns only the per-session selection state (_sortBy, _showCompleted,
// _viewAsList).  All expansion / animation / panel-positioning machinery is
// delegated to ExpandableActionMenu (from widgets/action_panel.dart).
// Toggle rows are created via ActionItem.toggle() so no manual setState or
// dismiss wiring is required for future two-state rows.
// ══════════════════════════════════════════════════════════════════════════════
class _DcvMenuContent extends StatefulWidget {
  final double panelTop;
  final double panelLeft;
  final double panelWidth;
  final double maxHeight;
  final ValueNotifier<bool> isClosing;
  final VoidCallback onDismiss;
  final bool isSmartCategory;
  final bool isUtilityCategory;
  final bool sectionsEnabled;
  final bool initialManageSections;
  final String initialSortBy;
  final void Function(String) onSortChanged;
  final String initialSortDir;
  final void Function(String) onSortDirChanged;
  final bool initialShowCompleted;
  final void Function(bool) onShowCompletedChanged;
  final bool initialViewAsList;
  final void Function(bool) onViewAsListChanged;
  final VoidCallback? onArchiveCategory;
  final VoidCallback? onDeleteCategory;
  final VoidCallback? onEditCategory;
  final void Function(VoidCallback afterClosed) onDismissThen;
  final VoidCallback onManageSectionsTriggered;
  final VoidCallback onEditSectionsTriggered;

  const _DcvMenuContent({
    required this.panelTop,
    required this.panelLeft,
    required this.panelWidth,
    required this.maxHeight,
    required this.isClosing,
    required this.onDismiss,
    required this.isSmartCategory,
    required this.isUtilityCategory,
    required this.sectionsEnabled,
    required this.initialManageSections,
    required this.initialSortBy,
    required this.onSortChanged,
    required this.initialSortDir,
    required this.onSortDirChanged,
    required this.initialShowCompleted,
    required this.onShowCompletedChanged,
    required this.initialViewAsList,
    required this.onViewAsListChanged,
    this.onArchiveCategory,
    this.onDeleteCategory,
    this.onEditCategory,
    required this.onDismissThen,
    required this.onManageSectionsTriggered,
    required this.onEditSectionsTriggered,
  });

  @override
  State<_DcvMenuContent> createState() => _DcvMenuContentState();
}

class _DcvMenuContentState extends State<_DcvMenuContent> {
  late bool _showCompleted;
  late String _sortBy;
  late String _sortDir;
  late bool _viewAsList;
  late bool _manageSections;
  bool _fastClosing = false;

  static const _kSortOptions = [
    'Manual',
    'Deadline',
    'Creation Date',
    'Priority',
    'Title',
  ];

  // Directional sub-options for each sort mode that supports them.
  static const _kSortDirections = <String, List<String>>{
    'Deadline': ['Earliest First', 'Latest First'],
    'Creation Date': ['Oldest First', 'Newest First'],
    'Priority': ['Lowest First', 'Highest First'],
    'Title': ['Ascending', 'Descending'],
  };

  @override
  void initState() {
    super.initState();
    _sortBy = widget.initialSortBy;
    // Utility categories only expose Creation Date directions and should
    // always start with the newest item first, even if an older saved value
    // is missing or came from a previous menu shape.
    final storedDir = widget.initialSortDir;
    _sortDir = widget.isUtilityCategory
        ? (storedDir == 'Oldest First' ? 'Oldest First' : 'Newest First')
        : (storedDir.isNotEmpty
              ? storedDir
              : (_kSortDirections[_sortBy]?.first ?? ''));
    _showCompleted = widget.initialShowCompleted;
    _viewAsList = widget.initialViewAsList;
    _manageSections = widget.initialManageSections;
  }

  // ── Sort selection ──────────────────────────────────────────────────────────

  void _selectSort(String option) {
    // When switching to a directional sort, reset direction to the first option.
    if (option != _sortBy) {
      final firstDir = _kSortDirections[option]?.first;
      if (firstDir != null) widget.onSortDirChanged(firstDir);
    }
    // No setState — row stays frozen visually during the close animation.
    widget.onSortChanged(option);
    Future.delayed(const Duration(milliseconds: 80), widget.onDismiss);
  }

  void _selectDir(String dir) {
    widget.onSortDirChanged(dir);
    Future.delayed(const Duration(milliseconds: 80), widget.onDismiss);
  }

  void _onDeleteCategoryTap() {
    widget.onDeleteCategory?.call();
    Future.delayed(const Duration(milliseconds: 80), widget.onDismiss);
  }

  void _onArchiveCategoryTap() {
    widget.onArchiveCategory?.call();
    Future.delayed(const Duration(milliseconds: 80), widget.onDismiss);
  }

  void _onEditCategoryTap() {
    // This transition is intentionally faster than a normal menu dismissal:
    // the editor should feel like the next surface, not wait through the full
    // gel close. The modal still opens only after the overlay is removed.
    setState(() => _fastClosing = true);
    widget.onDismissThen(() => widget.onEditCategory?.call());
  }

  void _onInitialNewSectionTap() {
    widget.onManageSectionsTriggered();
    Future.delayed(const Duration(milliseconds: 80), widget.onDismiss);
  }

  void _onSectionOptionTap() {
    widget.onManageSectionsTriggered();
    Future.delayed(const Duration(milliseconds: 80), widget.onDismiss);
  }

  void _onEditSectionsTap() {
    setState(() => _fastClosing = true);
    widget.onDismissThen(widget.onEditSectionsTriggered);
  }

  // Sort By's position must be measured from the same scaled rows that the
  // main ActionPanel renders.  The old fixed 217.5 px value only matched the
  // default text size; at an accessibility text size, any wrapped row above
  // Sort By moved the real trigger while the nested panel stayed put.
  double _rowTop(BuildContext context, String targetLabel) {
    final items = _origItems(null, false, (_) {});
    var top = 0.0;
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      if (i > 0) {
        top += item.groupBreakAbove
            ? ActionItem.groupBreakH
            : ActionItem.separatorH;
      }
      if (item.label == targetLabel) return top;
      top += ActionItem.rowHeightForItem(
        context,
        item,
        panelWidth: widget.panelWidth,
        chevronColumn: true,
      );
    }
    return top;
  }

  double _rowHeight(BuildContext context, String targetLabel) {
    final items = _origItems(null, false, (_) {});
    for (final item in items) {
      if (item.label == targetLabel) {
        return ActionItem.rowHeightForItem(
          context,
          item,
          panelWidth: widget.panelWidth,
          chevronColumn: true,
        );
      }
    }
    return ActionItem.rowHeight;
  }

  double _sortByTop(BuildContext context) => _rowTop(context, 'Sort By');

  double _manageSectionsTop(BuildContext context) =>
      _rowTop(context, 'Manage Sections');

  // ── Item lists ──────────────────────────────────────────────────────────────

  // Main panel items.  ExpandableActionMenu passes (isExpanded, isScalingBack,
  // onTriggerTap) so this method can set contentOpacity and wire onTap on the
  // Sort By row without knowing about the expansion machinery.
  //
  // Two-state rows use ActionItem.toggle() — add future toggles the same way.
  List<ActionItem> _origItems(
    String? expandedTriggerId,
    bool isScalingBack,
    void Function(String triggerId) onTriggerTap,
  ) => [
    // ── View as Columns / List toggle ────────────────────────────────────────
    ActionItem.toggle(
      value: _viewAsList,
      labelWhenTrue: 'View as List',
      labelWhenFalse: 'View as Columns',
      iconWhenTrue: SFIcons.sf_list_bullet,
      iconWhenFalse: SFIcons.sf_list_bullet,
      iconSize: 21,
      iconBuilderWhenFalse: (c) => Transform.translate(
        offset: const Offset(-2.0, 0),
        child: ColumnsViewIcon(color: c, size: 24),
      ),
      onChanged: widget.onViewAsListChanged,
      onDismiss: widget.onDismiss,
    ),
    ActionItem(
      label: 'Edit Category Info',
      icon: SFIcons.sf_pencil,
      iconSize: 22,
      iconWeight: FontWeight.w500,
      groupBreakAbove: true,
      onTap: _onEditCategoryTap,
    ),
    ActionItem(
      label: 'Select Events',
      icon: SFIcons.sf_checkmark_circle,
      onTap: () {},
    ),
    if (widget.sectionsEnabled && _sortBy == 'Manual')
      _manageSections
          ? ActionItem(
              label: 'Manage Sections',
              icon: SFIcons.sf_list_bullet,
              hasChevron: true,
              iconOffset: const Offset(-7.0, 0),
              iconBuilder: (color) => NewSectionIcon(size: 16, color: color),
              contentOpacity: expandedTriggerId == 'manageSections' ? 0.0 : 1.0,
              onTap: () => onTriggerTap('manageSections'),
            )
          : ActionItem(
              label: 'New Section',
              icon: SFIcons.sf_list_bullet,
              iconOffset: const Offset(-7.0, 0),
              iconBuilder: (color) =>
                  NewSectionIcon(size: 16, color: color, showPlusBadge: true),
              onTap: _onInitialNewSectionTap,
            ),
    // Sort By — ExpandableActionMenu hides content (contentOpacity:0) and
    // renders the floating shared element in its place while expanded.
    ActionItem(
      label: 'Sort By',
      icon: SFIcons.sf_arrow_up_arrow_down,
      hasChevron: true,
      subtitle: widget.isUtilityCategory ? _sortDir : _sortBy,
      contentOpacity: expandedTriggerId == 'sortBy' ? 0.0 : 1.0,
      onTap: () => onTriggerTap('sortBy'),
    ),
    // ── Show / Hide Completed toggle ─────────────────────────────────────────
    ActionItem.toggle(
      value: _showCompleted,
      labelWhenTrue: 'Show Completed',
      labelWhenFalse: 'Hide Completed',
      iconWhenTrue: SFIcons.sf_eye,
      iconWhenFalse: SFIcons.sf_eye_slash,
      onChanged: widget.onShowCompletedChanged,
      onDismiss: widget.onDismiss,
    ),
    if (!widget.isUtilityCategory)
      ActionItem(
        label: 'Archive Category',
        icon: SFIcons.sf_archivebox,
        onTap: _onArchiveCategoryTap,
      ),
    if (!widget.isUtilityCategory && !widget.isSmartCategory)
      ActionItem(
        label: 'Delete Category',
        icon: SFIcons.sf_trash,
        isDestructive: true,
        onTap: _onDeleteCategoryTap,
      ),
  ];

  // Sort options shown in the sub-panel.
  // strongFirstSep adds a calendar-weight separator between the Sort By header
  // row slot and the first option (used inside ExpandableActionMenu's sub-panel).
  List<ActionItem> _sortOptionItems() {
    if (widget.isUtilityCategory) {
      return [
        ActionItem(
          label: 'Oldest First',
          icon: SFIcons.sf_checkmark,
          checkmark: _sortDir == 'Oldest First',
          primaryCheckmark: true,
          showTrailingIcon: false,
          groupBreakAbove: true,
          onTap: () => _selectDir('Oldest First'),
        ),
        ActionItem(
          label: 'Newest First',
          icon: SFIcons.sf_checkmark,
          checkmark: _sortDir != 'Oldest First',
          primaryCheckmark: true,
          showTrailingIcon: false,
          onTap: () => _selectDir('Newest First'),
        ),
      ];
    }
    final dirs = _kSortDirections[_sortBy];
    return [
      for (int i = 0; i < _kSortOptions.length; i++)
        ActionItem(
          label: _kSortOptions[i],
          icon: SFIcons.sf_checkmark,
          checkmark: _kSortOptions[i] == _sortBy,
          primaryCheckmark: true,
          iconBuilder: (_) => const SizedBox(width: 20),
          groupBreakAbove: i == 0,
          onTap: () => _selectSort(_kSortOptions[i]),
        ),
      // Direction sub-options — only shown when a directional sort is active.
      if (dirs != null)
        for (int i = 0; i < dirs.length; i++)
          ActionItem(
            label: dirs[i],
            icon: SFIcons.sf_checkmark,
            checkmark: dirs[i] == _sortDir,
            primaryCheckmark: true,
            showTrailingIcon: false,
            groupBreakAbove: i == 0,
            onTap: () => _selectDir(dirs[i]),
          ),
    ];
  }

  List<ActionItem> _sectionOptionItems() => [
    ActionItem(
      label: 'New Section',
      icon: SFIcons.sf_list_bullet,
      iconOffset: const Offset(-7.0, 0),
      iconBuilder: (_) => const SizedBox.shrink(),
      groupBreakAbove: true,
      onTap: _onSectionOptionTap,
    ),
    ActionItem(
      label: 'Edit Sections',
      icon: SFIcons.sf_pencil,
      iconBuilder: (_) => const SizedBox.shrink(),
      groupBreakAbove: false,
      onTap: _onEditSectionsTap,
    ),
  ];

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final expandableActions = <ExpandableActionSpec>[
      if (widget.sectionsEnabled && _sortBy == 'Manual' && _manageSections)
        ExpandableActionSpec(
          id: 'manageSections',
          rowTop: _manageSectionsTop(context),
          rowHeight: _rowHeight(context, 'Manage Sections'),
          label: 'Manage Sections',
          subtitle: null,
          icon: SFIcons.sf_list_bullet,
          iconBuilder: (color) => NewSectionIcon(size: 16, color: color),
          iconOffset: const Offset(-7.0, 0),
          subItems: _sectionOptionItems(),
        ),
      ExpandableActionSpec(
        id: 'sortBy',
        rowTop: _sortByTop(context),
        rowHeight: _rowHeight(context, 'Sort By'),
        label: 'Sort By',
        subtitle: widget.isUtilityCategory ? _sortDir : _sortBy,
        icon: SFIcons.sf_arrow_up_arrow_down,
        subItems: _sortOptionItems(),
      ),
    ];

    return ExpandableActionMenu(
      panelTop: widget.panelTop,
      panelLeft: widget.panelLeft,
      panelWidth: widget.panelWidth,
      isClosing: widget.isClosing,
      onDismiss: widget.onDismiss,
      chevronColumn: true,
      itemsBuilder: _origItems,
      expandableActions: expandableActions,
      closeDurationOverrideMs: _fastClosing ? 240 : null,
      maxHeight: widget.maxHeight,
    );
  }
}

// System-defined (smart) category labels — user-created categories are anything
// not in this set.  "Delete Category" is hidden for smart and utility views.
const _kSmartCategoryLabels = {
  'Today',
  'Tomorrow',
  'This Week',
  'Next Week',
  'Scheduled',
  'Unscheduled',
  'All Events',
  'Completed',
};

const _kUtilityDcvLabels = {'Archived Items', 'Recently Deleted'};

/// Whether the currently open DCV supports the manual Sections action.
///
/// The fixed smart categories are intentionally not section-enabled.  The
/// built-in Unscheduled DCV is the one exception; Unnamed, Uncategorized, and
/// every user-created category are section-enabled because they are not in the
/// fixed smart-category set.
bool _dcvSectionsEnabled(String? label) =>
    label == 'Unscheduled' ||
    (label != null &&
        !_kSmartCategoryLabels.contains(label) &&
        !_kUtilityDcvLabels.contains(label));

const _overlayStyle = SystemUiOverlayStyle(
  statusBarColor: Color(0x00000000),
  statusBarBrightness: Brightness.light,
  statusBarIconBrightness: Brightness.dark,
  systemNavigationBarColor: Color(0x00000000),
  systemNavigationBarIconBrightness: Brightness.dark,
  systemNavigationBarDividerColor: Color(0x00000000),
  systemNavigationBarContrastEnforced: false,
);

// ── Crash logger ──────────────────────────────────────────────────────────────
// Writes a crash report to a file so the next launch can display it.
// Only active on non-web native builds.
String? _crashFilePath;
String? _pendingCrashReport; // read from file on startup, shown in AppShell

void _writeCrashReport(String message) {
  final path = _crashFilePath;
  if (path == null) return;
  try {
    File(path).writeAsStringSync(
      '[${DateTime.now().toIso8601String()}]\n$message',
      mode: FileMode.writeOnly,
      flush: true,
    );
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kIsWeb || defaultTargetPlatform == TargetPlatform.android) {
    await LiquidGlassWidgets.initialize();
  }
  await navigation_glass.LiquidGlassWidgets.initialize();
  // Set the system-bar layout before startup awaits so Android can draw the
  // first frame edge-to-edge, including when the app launches in a freeform
  // window. The header separately uses MediaQuery.padding.top for safe layout.
  if (!kIsWeb) {
    await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
  }
  await initializeDeviceTextScaleProfile();

  // ── Global crash capture (non-web only) ────────────────────────────────────
  if (!kIsWeb) {
    try {
      final dir = await getApplicationDocumentsDirectory();
      _crashFilePath = '${dir.path}/__skeddo_crash__.txt';
      final f = File(_crashFilePath!);
      if (f.existsSync()) {
        _pendingCrashReport = f.readAsStringSync();
        f.deleteSync();
      }
    } catch (_) {}

    // Flutter framework errors (build / layout / painting).
    FlutterError.onError = (details) {
      _writeCrashReport('${details.exceptionAsString()}\n\n${details.stack}');
      FlutterError.presentError(details); // still log to console
    };

    // Unhandled async errors (Dart zones).
    PlatformDispatcher.instance.onError = (error, stack) {
      _writeCrashReport('$error\n\n$stack');
      return false; // do NOT suppress — let crash naturally so OS records it
    };
  }

  // Load the locale preference before any event parsing can occur so all
  // subsequent parser calls use the user's chosen interpretation.
  try {
    await loadAppSettings().timeout(const Duration(seconds: 3));
  } catch (_) {
    // Defaults are already initialized in app_settings.dart.
  }
  // Start AI initialization without holding the first frame. On Android's
  // first launch this copies the model asset; on every platform the persisted
  // index/model work can continue while the app becomes interactive.
  final aiInitialization = AIServices.init();
  EventPipeline.instance.init();
  // Load persisted events so the initial build has the correct state.
  try {
    await EventStore.instance.loadFromStorage().timeout(
      const Duration(seconds: 3),
    );
  } catch (_) {
    // The store remains empty and will be populated by later user actions.
  }
  runApp(navigation_glass.LiquidGlassWidgets.wrap(child: const SKEDDOApp()));

  // Event creation remains safe while the model loads: embedEvent returns
  // false until initialization completes, leaving those events eligible for
  // this background pass instead of persisting placeholder vectors.
  unawaited(
    aiInitialization
        .then<void>((_) {
          EventPipeline.instance.scheduleBackgroundReembed(
            EventStore.instance.events.value,
          );
        })
        .catchError((Object error, StackTrace stack) {
          debugPrint('[Startup] AI initialization failed: $error');
        }),
  );
  unawaited(
    aiInitialization
        .timeout(const Duration(seconds: 8))
        .then<void>((_) {})
        .catchError((Object error, StackTrace stack) {
          debugPrint(
            '[Startup] AI initialization is taking longer than usual: $error',
          );
        }),
  );
}

class SKEDDOApp extends StatefulWidget {
  const SKEDDOApp({super.key});

  @override
  State<SKEDDOApp> createState() => _SKEDDOAppState();
}

class _SKEDDOAppState extends State<SKEDDOApp> with WidgetsBindingObserver {
  Timer? _textScalePollTimer;
  final GlobalKey<DynamicColorBuilderState> _dynamicColorBuilderKey =
      GlobalKey<DynamicColorBuilderState>();
  CupertinoDynamicColor? _pendingDynamicAccent;
  CupertinoDynamicColor? _cachedDynamicAccent;
  // Keep the root route stack attached to the same Navigator across window
  // metric changes and app-shell rebuilds. In particular, an open modal route
  // owns unsaved form controllers and focus nodes that must not be recreated
  // just because the available layout changed from portrait to landscape.
  final GlobalKey<NavigatorState> _rootNavigatorKey =
      GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refreshSystemAccentColor());
    appSystemBrightnessNotifier.value =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    _textScalePollTimer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(refreshDeviceTextScaleProfileIfChanged()),
    );
    // Load the Settings preview background while the app is starting so
    // opening the Liquid Glass sub-screen does not wait on the asset decode.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        precacheImage(
          const AssetImage('assets/liquid_glass_background_light.webp'),
          context,
        ),
      );
      unawaited(
        precacheImage(
          const AssetImage('assets/liquid_glass_background_dark.webp'),
          context,
        ),
      );
      // Prewarm both light and dark transformed variants for the full accent
      // palette. The tint cache is separate from Flutter's ImageCache, so
      // precaching only the source WebPs would still leave the first accent
      // change waiting for pixel transformation.
      unawaited(
        precacheAccentTintedImages(
          lightAccentColors: kAccentSwatches.map((swatch) => swatch.color),
          darkAccentColors: kAccentSwatches.map((swatch) => swatch.darkColor),
        ),
      );
    });
  }

  @override
  void didChangePlatformBrightness() {
    final systemBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (appSystemBrightnessNotifier.value != systemBrightness) {
      appSystemBrightnessNotifier.value = systemBrightness;
    }
  }

  @override
  void dispose() {
    _textScalePollTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Android and iOS expose the current text-size setting through the
      // native bridge. Re-read it after returning from Settings so the
      // System thumb and captured scaler track the newly selected OS value.
      unawaited(initializeDeviceTextScaleProfile());
      unawaited(refreshSystemFirstDayOfWeek());
      unawaited(refreshSystemDateFormat());
      unawaited(refreshSystemAccentColor());
      final dynamicColorState = _dynamicColorBuilderKey.currentState;
      if (dynamicColorState != null) {
        unawaited(dynamicColorState.initPlatformState());
      }
    }
  }

  void _publishDynamicAccent(CupertinoDynamicColor accent) {
    if (hasSameAccentColorPair(appSystemAccentColorNotifier.value, accent) ||
        (_pendingDynamicAccent != null &&
            hasSameAccentColorPair(_pendingDynamicAccent!, accent))) {
      return;
    }
    _pendingDynamicAccent = accent;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = _pendingDynamicAccent;
      if (!mounted ||
          pending == null ||
          !hasSameAccentColorPair(pending, accent)) {
        return;
      }
      _pendingDynamicAccent = null;
      if (!hasSameAccentColorPair(appSystemAccentColorNotifier.value, accent)) {
        appSystemAccentColorNotifier.value = accent;
      }
    });
  }

  CupertinoDynamicColor _cacheDynamicAccent(CupertinoDynamicColor accent) {
    final cached = _cachedDynamicAccent;
    if (cached != null && hasSameAccentColorPair(cached, accent)) {
      return cached;
    }
    _cachedDynamicAccent = accent;
    return accent;
  }

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      key: _dynamicColorBuilderKey,
      builder: (lightDynamic, darkDynamic) {
        return ListenableBuilder(
          listenable: Listenable.merge([
            appBrightnessNotifier,
            appSystemBrightnessNotifier,
            appTextSizeUsesSystemNotifier,
            appTextSizeIndexNotifier,
            appSystemTextScaleNotifier,
            appSkeddoTextScaleMappingNotifier,
            appCustomTextScalerNotifier,
            appAccentNotifier,
            appAccentUsesSystemNotifier,
            appSystemAccentColorNotifier,
            appDateLocaleNotifier,
            appDateFormatNotifier,
            appDateFormatUsesSystemNotifier,
            appSystemDateFormatPatternNotifier,
            appFullMonthNameNotifier,
          ]),
          builder: (context, _) {
            final brightness = appBrightnessNotifier.value;
            final followsSystemTextSize = appTextSizeUsesSystemNotifier.value;
            final customTextSizeIndex = appTextSizeIndexNotifier.value;
            final systemTextScale =
                MediaQuery.textScalerOf(context).scale(16) / 16;
            // Native Android/iOS profiles are authoritative. MediaQuery is only
            // the compatibility fallback for web and older binaries without the
            // text-scale bridge; overwriting a native profile here makes the
            // System thumb point at a different stop than the rendered text.
            if (!appHasNativeTextScaleProfile &&
                appSystemTextScaleNotifier.value != systemTextScale) {
              appSystemTextScaleNotifier.value = systemTextScale;
            }
            final selectedAppAccent = kAccentSwatches[appAccentNotifier.value];
            final dynamicAccentCandidate = systemAccentFromDynamicColors(
              lightDynamic?.primary,
              darkDynamic?.primary,
            );
            final dynamicAccent = dynamicAccentCandidate == null
                ? null
                : _cacheDynamicAccent(dynamicAccentCandidate);
            if (dynamicAccent != null) {
              _publishDynamicAccent(dynamicAccent);
            }
            final systemAccent =
                dynamicAccent ?? appSystemAccentColorNotifier.value;
            final targetAccent = appAccentUsesSystemNotifier.value
                ? systemAccent
                : selectedAppAccent;
            final effectiveBrightness =
                brightness ?? appSystemBrightnessNotifier.value;
            WindowCaptionAppearance.synchronize(effectiveBrightness);

            // Status-bar icon brightness tracks the active mode so icons remain
            // legible: dark mode → light icons; light (or system) → dark icons.
            final statusIconBrightness = effectiveBrightness == Brightness.dark
                ? Brightness.light
                : Brightness.dark;
            final dynamicOverlayStyle = SystemUiOverlayStyle(
              statusBarColor: const Color(0x00000000),
              statusBarBrightness: effectiveBrightness,
              statusBarIconBrightness: statusIconBrightness,
              systemNavigationBarColor: const Color(0x00000000),
              systemNavigationBarIconBrightness: statusIconBrightness,
              systemNavigationBarDividerColor: const Color(0x00000000),
              systemNavigationBarContrastEnforced: false,
            );

            return TweenAnimationBuilder<CupertinoDynamicColor>(
              tween: _CupertinoAccentColorTween(
                begin: targetAccent,
                end: targetAccent,
              ),
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOut,
              builder: (context, accentSwatch, _) => AnnotatedRegion<SystemUiOverlayStyle>(
                value: dynamicOverlayStyle,
                child: CupertinoApp(
                  debugShowCheckedModeBanner: false,
                  navigatorKey: _rootNavigatorKey,
                  theme: CupertinoThemeData(
                    // Keep System mode on the same platform-brightness snapshot used
                    // by the Settings label; app-only modes override this value.
                    brightness: effectiveBrightness,
                    // Drives the text-selection highlight + handles for every
                    // CupertinoTextField in the app (cursor color is set per-field).
                    // Updated live when the user changes the accent colour.
                    primaryColor: accentSwatch,
                    textTheme: CupertinoTextThemeData(
                      textStyle: TextStyle(
                        fontFamily: kSFProText,
                        fontStyle: FontStyle.normal,
                      ),
                    ),
                  ),
                  // Paints the color revealed behind the app's Navigator/Overlay stack —
                  // most visibly the furthest-back layer seen around/behind a receding
                  // CupertinoSheetRoute page as it scales down.  Without this the gap
                  // defaults to the engine's black clear color regardless of theme.
                  builder: (context, child) {
                    // AppAccentColor wraps the entire Navigator subtree so every
                    // descendant can call resolveAccentColor(context).
                    Widget result = AppAccentColor(
                      accent: accentSwatch,
                      child: child ?? const SizedBox.shrink(),
                    );
                    // Icons are visual controls, not text. Keep every Flutter icon
                    // at its authored size even when the app's text scaler changes.
                    // SF Symbols and other font-backed icons get the same treatment
                    // through FixedSFIcon and SearchWeightedIcon.
                    result = IconTheme(
                      data: IconTheme.of(
                        context,
                      ).copyWith(applyTextScaling: false),
                      child: result,
                    );
                    // System mode intentionally leaves Flutter's ambient
                    // MediaQuery.textScaler untouched. Only Custom mode receives
                    // SKEDDO's frozen selected scaler.
                    if (!followsSystemTextSize &&
                        appCustomTextScalerNotifier.value != null) {
                      result = MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                          textScaler: appCustomTextScalerNotifier.value,
                        ),
                        child: result,
                      );
                    } else if (!followsSystemTextSize) {
                      final mapping = appSkeddoTextScaleMappingNotifier.value;
                      final mappedScale = customTextSizeIndex < mapping.length
                          ? mapping[customTextSizeIndex].scale
                          : skeddoTextScaleForIndex(customTextSizeIndex);
                      result = MediaQuery.withClampedTextScaling(
                        minScaleFactor: mappedScale,
                        maxScaleFactor: mappedScale,
                        child: result,
                      );
                    }
                    // Keep MediaQuery-based dynamic colors on the same effective
                    // brightness as CupertinoTheme in System and app-only modes.
                    result = MediaQuery(
                      data: MediaQuery.of(
                        context,
                      ).copyWith(platformBrightness: effectiveBrightness),
                      child: result,
                    );
                    // Publish the symmetric landscape positioning constraint above
                    // the Navigator without constraining its full-width surfaces.
                    result = AppWindowContentBoundary(child: result);
                    // Keep the dedicated sheet-stack surface outside the content
                    // boundary so it paints across the full physical window. This
                    // is the color revealed behind receding modal sheets.
                    result = ColoredBox(
                      color: resolveThemeColor(
                        kAddCategorySheetBackground,
                        context,
                      ),
                      child: result,
                    );
                    // Keep one live, metrics-derived rotation state above every
                    // screen and sheet. Adaptive widgets use this only for geometry
                    // interpolation; it is not a whole-app orientation animation.
                    // This must stay outside AppWindowContentBoundary so its
                    // windowSize remains the physical live window during rotation.
                    result = LiveRotationGeometry(child: result);
                    // This sits above the root Navigator so taps in AppShell screens
                    // and root-level sheets both dismiss stale text focus.
                    result = InteractiveTapFocusDismissal(child: result);
                    return result;
                  },
                  home: const AppShell(),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _CupertinoAccentColorTween extends Tween<CupertinoDynamicColor> {
  _CupertinoAccentColorTween({required super.begin, required super.end});

  @override
  CupertinoDynamicColor lerp(double t) {
    final start = begin ?? end!;
    final finish = end ?? start;
    return CupertinoDynamicColor.withBrightness(
      color: Color.lerp(start.color, finish.color, t)!,
      darkColor: Color.lerp(start.darkColor, finish.darkColor, t)!,
    );
  }
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> with TickerProviderStateMixin {
  static const double _dcvColorSnapThreshold = 0.5;

  final _notesTabKey = GlobalKey<NotesTabState>();
  final _calendarTabKey = GlobalKey<CalendarTabState>();
  final _eventsTabKey = GlobalKey<EventsTabState>();
  final _floatingTabPillKey = GlobalKey();

  // Kept in AppShell so the header AnimatedBuilder rebuilds immediately when
  // the CalendarTab transitions views (via the onViewChanged callback).
  CalendarView _calendarView = calendarViewForDefaultViewSetting(
    appDefaultViewNotifier.value,
  );
  int _calendarDisplayYear = DateTime.now().year;
  String _calendarPrevTitle = '';
  String _calendarTitle = '';
  String _calendarNextTitle = '';
  // In settled portrait Month/Year views, the calendar title and its
  // navigation controls are rendered by the calendar's own scrollable content.
  bool _calendarTitleInScrollContent = true;

  // True when the header is displaying a month name — drives view-mode icon
  // visibility so it syncs with the shared midpoint title handoff rather than
  // the animation endpoint. Month titles have no digits and no spaces.
  bool get _calendarShowsMonthTitle =>
      _calendarTitle.isNotEmpty &&
      int.tryParse(_calendarTitle) == null &&
      !_calendarTitle.contains(' ');

  // True when the header is displaying a day title (e.g. "Jun 30") — drives
  // the Day View sub-mode icon visibility.  Day titles always contain a space.
  bool get _calendarShowsDayTitle =>
      _calendarTitle.isNotEmpty && _calendarTitle.contains(' ');

  // True when the header is displaying a year title — drives the Year View
  // "today" calendar shortcut in the same shared slot as the Month/Day icons.
  bool get _calendarShowsYearTitle =>
      _calendarTitle.isNotEmpty && int.tryParse(_calendarTitle) != null;

  String get _calendarToolbarVariant {
    if (_calendarShowsYearTitle) return 'year';
    if (_calendarShowsDayTitle) {
      return 'day-${_activeDaySubMode.name}';
    }
    if (_calendarShowsMonthTitle) {
      return 'month-${_activeViewMode.name}';
    }
    return switch (_calendarView) {
      CalendarView.year => 'year',
      CalendarView.month => 'month-${_activeViewMode.name}',
      CalendarView.day => 'day-${_activeDaySubMode.name}',
    };
  }

  // Driven by CalendarTab.onStripSlide — slides the calendar header row in
  // lock-step with the week strip in Day View.  Starts and ends at 0.0.
  final _calendarStripSlide = ValueNotifier<double>(0.0);

  int _selectedIndex = 0;
  String? _activeToolbarRouteKey = 'home';
  final GlobalKey<NavigatorState> _appShellNavigatorKey =
      GlobalKey<NavigatorState>();
  final Set<Route<void>> _toolbarStateRoutes = <Route<void>>{};
  Route<void>? _currentToolbarStateRoute;
  final ValueNotifier<int> _appShellRouteRevision = ValueNotifier<int>(0);
  late final AppShellNavigationObserver _appShellNavigationObserver =
      AppShellNavigationObserver(_appShellRouteRevision);
  final AppHeaderTitleTransition _headerTitleTransition =
      AppHeaderTitleTransition();
  static const _nativeTabBarChannel = MethodChannel(
    'com.smartscheduler/native_tab_bar',
  );
  bool _usesNativeTabBar = false;
  int? _lastNativeActiveTabBarColorArgb;
  int? _lastNativeInactiveTabBarColorArgb;
  bool _menuOpen = false;
  String? _dcvCategory;
  String? _previousDcvCategory;
  Color? _previousDcvColor;
  // The tapped category's own colour, captured at DCV-entry time. While DCV
  // is visible this replaces kAccentColor for the header icons and the
  // active tab indicator; cleared on exit so the app reverts to the default
  // accent blue. Categories that were never customised resolve to
  // kAccentColor already (see resolveCategorySwatch's default), so this is a
  // visual no-op for them — no separate "has been edited" check needed.
  Color? _dcvColor;
  final ValueNotifier<Color?> _dcvToolbarAccent = ValueNotifier<Color?>(null);
  bool _dcvToolbarVisible = false;

  // Drives the DCV slide: 0.0 = grid fully visible, 1.0 = DCV fully visible.
  // Owned here in AppShell so the header AnimatedBuilder and EventsTab both
  // listen to the SAME object — Flutter guarantees they rebuild and paint in
  // the exact same frame, making one-frame header/content desync physically
  // impossible on Impeller/Skia.
  late final AnimationController _dcvSlideController;
  late final CurvedAnimation _dcvSlideProgress;
  // A category change inside an already-open landscape split only animates
  // the new detail page over the previous one; it must not restart the pane
  // transition that owns the master width and header geometry.
  late final AnimationController _dcvCategoryTransitionController;
  late final CurvedAnimation _dcvCategoryTransitionProgress;

  // Settings is a Navigator destination so the route-aware glass toolbar can
  // morph the existing shell item instead of drawing a separate button.
  bool _settingsOpen = false;

  /// Kept for the landscape split Settings layout, where detail content stays
  /// in the same route rather than pushing a portrait sub-screen route.
  final ValueNotifier<VoidCallback?> _settingsBackAction = ValueNotifier(null);
  final ValueNotifier<bool> _settingsInlineBackVisible = ValueNotifier(false);

  // True when _dcvCategory is set AND we are on the Events tab.
  // Only used for LOGICAL decisions (e.g. whether _exitDCV has been called).
  // All VISUAL decisions (title, icons, tap handlers) use isDCVVisual inside
  // the header AnimatedBuilder, derived from _dcvSlideController.value.
  bool get _isDCV => _dcvCategory != null && _selectedIndex == 2;

  bool _isHeaderScrollSource({
    required ScrollMetrics metrics,
    required int depth,
    required BuildContext? notificationContext,
  }) {
    final viewportHeight = metrics.viewportDimension;
    if (metrics.axis != Axis.vertical ||
        depth != 0 ||
        viewportHeight < max(240, MediaQuery.sizeOf(context).height * 0.35)) {
      return false;
    }
    // Kept-alive tabs also emit viewport metrics when the shared header
    // changes. They must not replace the visible tab's owning position.
    if (notificationContext != null) {
      if ((_selectedIndex != 0 &&
              notificationContext.findAncestorStateOfType<NotesTabState>() !=
                  null) ||
          (_selectedIndex != 1 &&
              notificationContext.findAncestorStateOfType<CalendarTabState>() !=
                  null) ||
          (_selectedIndex != 2 &&
              notificationContext.findAncestorStateOfType<EventsTabState>() !=
                  null)) {
        return false;
      }
    }

    // Adjacent Year/Month previews have separate positions. Only the active
    // calendar panel may drive the shared shell title.
    if (_selectedIndex == 1 &&
        (_calendarView == CalendarView.year ||
            _calendarView == CalendarView.month)) {
      final activePosition = _calendarTabKey.currentState?.headerScrollPosition;
      final sourcePosition = notificationContext == null
          ? null
          : Scrollable.maybeOf(
              notificationContext,
              axis: Axis.vertical,
            )?.position;
      if (activePosition == null ||
          !identical(sourcePosition, activePosition)) {
        return false;
      }
    }

    // Day timelines are independent scroll surfaces; the list mode remains
    // part of the shell's normal header scroll hierarchy.
    if (_selectedIndex == 1 &&
        _calendarView == CalendarView.day &&
        _activeDaySubMode != DayViewSubMode.list) {
      return false;
    }
    return true;
  }

  void _bindHeaderPositionFromContext(BuildContext? notificationContext) {
    if (notificationContext == null) return;
    final position = Scrollable.maybeOf(
      notificationContext,
      axis: Axis.vertical,
    )?.position;
    if (position != null) {
      _headerTitleTransition.bindTo(position, preserveCollapseProgress: true);
    }
  }

  bool _onHeaderScrollNotification(ScrollNotification notification) {
    if (_settingsOpen || _searchEnteredOffScreen) {
      return false;
    }
    if (_searchModeController.value > 0.01) {
      _headerTitleTransition.suspend();
      return false;
    }
    if (!_isHeaderScrollSource(
      metrics: notification.metrics,
      depth: notification.depth,
      notificationContext: notification.context,
    )) {
      return false;
    }
    _bindHeaderPositionFromContext(notification.context);
    return false;
  }

  bool _onHeaderScrollMetricsNotification(
    ScrollMetricsNotification notification,
  ) {
    if (_settingsOpen) {
      return false;
    }
    if (_searchModeController.value > 0.01) {
      _headerTitleTransition.suspend();
      return false;
    }
    if (!_isHeaderScrollSource(
      metrics: notification.metrics,
      depth: notification.depth,
      notificationContext: notification.context,
    )) {
      return false;
    }
    _bindHeaderPositionFromContext(notification.context);
    return false;
  }

  ScrollPosition? _headerPositionForController(ScrollController? controller) {
    if (controller == null) return null;
    final outerPosition = AppHeaderScrollView.headerPositionFor(controller);
    if (outerPosition != null) return outerPosition;
    if (!controller.hasClients) return null;
    for (final position in controller.positions) {
      if (position.hasContentDimensions) return position;
    }
    return null;
  }

  void _restoreHeaderScrollOffset() =>
      _syncHeaderScrollOffsetToParent(preserveCollapseProgress: true);

  void _settleShellTransitionsForSearch() {
    if (_dcvCategoryTransitionController.isAnimating) {
      _dcvCategoryTransitionController.value = 1.0;
    }
    if (_previousDcvCategory != null) {
      setState(() {
        _previousDcvCategory = null;
        _previousDcvColor = null;
      });
    }

    if (_dcvSlideController.isAnimating) {
      final isExiting = _dcvSlideController.status == AnimationStatus.reverse;
      final target = isExiting ? 0.0 : 1.0;
      _dcvSlideController.stop(canceled: false);
      _dcvSlideController.value = target;
      if (isExiting) _finishDcvExit();
    }
  }

  void _syncHeaderScrollOffsetToParent({
    bool preserveCollapseProgress = false,
  }) {
    // The blank You destination has no scroll position of its own. Keep the
    // shared header state while it is selected instead of binding to null and
    // resetting the title to its expanded position.
    if (_selectedIndex == 3) return;
    final position = _selectedIndex == 2 && _dcvCategory != null
        ? null
        : switch (_selectedIndex) {
            0 => _headerPositionForController(
              _notesTabKey.currentState?.scrollController,
            ),
            1 => _calendarTabKey.currentState?.headerScrollPosition,
            2 => _headerPositionForController(
              _eventsTabKey.currentState?.scrollController,
            ),
            _ => null,
          };
    // Calendar Day View intentionally has no header-owning scroll position:
    // its timeline scrolls independently. Keep the shell's last shared title
    // state instead of treating the missing position as an expanded header.
    final preserveCalendarDayHeader = _selectedIndex == 1 && position == null;
    _headerTitleTransition.bindTo(
      position,
      preserveCollapseProgress:
          preserveCollapseProgress ||
          preserveCalendarDayHeader ||
          AppHeaderScrollView.isHeaderPosition(position),
    );
  }

  void _onDcvCategoryTransitionStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed &&
        _previousDcvCategory != null &&
        mounted) {
      setState(() {
        _previousDcvCategory = null;
        _previousDcvColor = null;
      });
    }
  }

  void _enterDCV(String label, Color color) {
    if (_dcvCategory == label) {
      if (_dcvColor != color) {
        setState(() => _dcvColor = color);
        _dcvToolbarAccent.value = color;
      }
      return;
    }

    _headerTitleTransition.bindTo(null, preserveCollapseProgress: true);
    _dcvToolbarVisible = true;
    _dcvToolbarAccent.value = color;

    _dcvCategoryTransitionController.value = 1.0;
    setState(() {
      _previousDcvCategory = null;
      _previousDcvColor = null;
      _dcvCategory = label;
      _dcvColor = color;
    });
    _toolbarMenuRevision.value++;
    _dcvSlideController.forward(from: 0.0);
    _syncToolbarDestination();
  }

  void _exitDCV() {
    if (!_isDCV || _dcvSlideController.status == AnimationStatus.reverse) {
      return;
    }
    // If a category replacement is underway, settle it before the shared
    // pane animation starts so no detail-page motion can finish after it.
    _dcvCategoryTransitionController.value = 1.0;
    // Reverse the slide first; clear _dcvCategory only after the animation
    // completes so the DCV content stays mounted and visible while sliding out.
    _dcvToolbarVisible = false;
    _dcvToolbarAccent.value = null;
    _syncToolbarDestination();
    _dcvSlideController
        .reverse()
        .then((_) => _finishDcvExit())
        .catchError((_) => _finishDcvExit());
  }

  void _finishDcvExit() {
    if (!mounted || (_dcvCategory == null && _dcvColor == null)) return;
    _dcvToolbarVisible = false;
    _dcvToolbarAccent.value = null;
    setState(() {
      _dcvCategory = null;
      _dcvColor = null;
    });
    _restoreHeaderScrollOffset();
  }

  // ── Settings panel open / close ──────────────────────────────────────────
  void _openSettings() {
    if (_settingsOpen) return;
    setState(() => _settingsOpen = true);
    final topInset = MediaQuery.paddingOf(context).top;
    final bottomInset = systemSafeAreaBottomInset(context);
    final navigator = _appShellNavigatorKey.currentState;
    if (navigator == null) return;
    navigator
        .push<void>(
          PageRouteBuilder<void>(
            settings: const RouteSettings(name: 'settings-panel'),
            opaque: true,
            barrierDismissible: true,
            barrierLabel: 'Dismiss settings',
            barrierColor: const Color.fromRGBO(0, 0, 0, 0.4),
            transitionDuration: const Duration(milliseconds: 320),
            reverseTransitionDuration: const Duration(milliseconds: 320),
            pageBuilder: (routeContext, animation, secondaryAnimation) => Stack(
              fit: StackFit.expand,
              children: [
                SettingsPanel(
                  topInset: topInset,
                  bottomInset: bottomInset,
                  isOpen: true,
                  onClose: _closeSettings,
                  subScreenBackAction: _settingsBackAction,
                  inlineSubScreenBackVisible: _settingsInlineBackVisible,
                  headerTitleTransition: _headerTitleTransition,
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedBuilder(
                    animation: _settingsInlineBackVisible,
                    builder: (context, _) {
                      final showBack = _settingsInlineBackVisible.value;
                      return AppShellPinnedToolbar(
                        glyph: showBack
                            ? AppShellToolbarGlyph.back
                            : AppShellToolbarGlyph.close,
                        semanticLabel: showBack
                            ? 'Back to Settings'
                            : 'Close settings',
                        horizontalInset:
                            AppWindowContentScope.of(
                              routeContext,
                            ).horizontalInset +
                            16.0,
                        onTap: _handlePrimaryToolbarTap,
                      );
                    },
                  ),
                ),
              ],
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
                  final curved = CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeInOut,
                    reverseCurve: Curves.easeInOut,
                  );
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(-1.0, 0.0),
                      end: Offset.zero,
                    ).animate(curved),
                    child: child,
                  );
                },
          ),
        )
        .then((_) {
          if (mounted && _settingsOpen) _onSettingsRoutePopped();
        });
  }

  void _closeSettings() {
    if (!_settingsOpen) return;
    _settingsBackAction.value = null;
    _settingsInlineBackVisible.value = false;
    final navigator = _appShellNavigatorKey.currentState;
    if (navigator == null) return;
    if (navigator.canPop()) navigator.pop();
  }

  void _handlePrimaryToolbarTap() {
    if (_settingsOpen) {
      if (_settingsInlineBackVisible.value) {
        _settingsBackAction.value?.call();
        return;
      }
      final navigator = _appShellNavigatorKey.currentState;
      if (navigator?.canPop() == true) navigator!.pop();
      return;
    }
    if (_isDCV && _dcvSlideController.status == AnimationStatus.reverse) {
      return;
    }
    if (_toolbarDestinationKey() == 'events-dcv') {
      _exitDCV();
      return;
    }
    _openSettings();
  }

  void _onSettingsRoutePopped() {
    if (!_settingsOpen || !mounted) return;
    setState(() => _settingsOpen = false);
    _settingsBackAction.value = null;
    _settingsInlineBackVisible.value = false;
    _restoreHeaderScrollOffset();
    _syncToolbarDestination();
  }

  // ── DCV ellipsis context menu ────────────────────────────────────────────
  final GlobalKey _ellipsisKey = GlobalKey();
  final GlobalKey _splitDcvEllipsisKey = GlobalKey();
  final ValueNotifier<bool> _dcvMenuClosing = ValueNotifier(false);
  OverlayEntry? _dcvMenuOverlay;
  bool _dcvMenuOpen = false;
  // Per-category sort settings: keyed by category label, defaulting to
  // 'Manual' / '' when absent.  Each DCV maintains its own independent sort.
  final Map<String, String> _dcvSortByMap = {};
  final Map<String, String> _dcvSortDirMap = {};
  bool _dcvShowCompleted = true;
  bool _dcvViewAsList = false;
  final ValueNotifier<int> _toolbarMenuRevision = ValueNotifier(0);

  // ── Calendar view-mode menu (Month View) ─────────────────────────────────
  final GlobalKey _viewModeKey = GlobalKey();
  final ValueNotifier<bool> _viewModeClosing = ValueNotifier(false);
  OverlayEntry? _viewModeOverlay;
  bool _viewModeMenuOpen = false;
  CalendarViewMode _activeViewMode = CalendarViewMode.compact;

  // ── Calendar day-view sub-mode menu (Day View) ───────────────────────────
  final GlobalKey _dayViewModeKey = GlobalKey();
  final ValueNotifier<bool> _dayViewModeClosing = ValueNotifier(false);
  OverlayEntry? _dayViewModeOverlay;
  bool _dayViewModeMenuOpen = false;
  DayViewSubMode _activeDaySubMode =
      calendarDaySubModeForDefaultViewSetting(appDefaultViewNotifier.value) ??
      DayViewSubMode.singleDay;

  void _showSplitDcvMenu() {
    _showDcvMenuAt(_splitDcvEllipsisKey);
  }

  void _showDcvMenuAt(GlobalKey anchorKey) {
    final box = anchorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    _showDcvMenuAtRect(Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height));
  }

  void _showDcvMenuAtRect(Rect btnRect) {
    if (_dcvMenuOpen) return;
    _dcvMenuClosing.value = false;
    _dcvMenuOpen = true;
    setState(() {});

    final isSmartCategory = _kSmartCategoryLabels.contains(_dcvCategory);
    final isUtilityCategory = _kUtilityDcvLabels.contains(_dcvCategory);
    final userSmartCategory =
        _eventsTabKey.currentState?.isUserSmartCategoryLabel(_dcvCategory) ??
        false;
    final sectionsEnabled =
        !userSmartCategory && _dcvSectionsEnabled(_dcvCategory);
    final initialSortBy = isUtilityCategory
        ? 'Creation Date'
        : (_dcvSortByMap[_dcvCategory] ?? 'Manual');
    final storedSortDir = _dcvSortDirMap[_dcvCategory];
    final initialSortDir =
        isUtilityCategory &&
            storedSortDir != 'Oldest First' &&
            storedSortDir != 'Newest First'
        ? 'Newest First'
        : (storedSortDir ?? '');
    final manageSections =
        initialSortBy == 'Manual' &&
        (_eventsTabKey.currentState?.dcvHasSections(_dcvCategory) ?? false);
    final showSectionAction = sectionsEnabled && initialSortBy == 'Manual';

    // Pre-compute panel origin based on the FULL item set so the position
    // stays stable even when Sort By expands (removing rows below it).
    final mq = MediaQuery.of(context);
    final screenH = mq.size.height;
    final screenW = mq.size.width;
    final safeTop = mq.padding.top + 16.0;
    final safeBtm = mq.padding.bottom + 16.0;
    const basePanelW = ExpandableActionMenu.panelW;
    final fullItems = <ActionItem>[
      const ActionItem(label: 'View as List', icon: SFIcons.sf_list_bullet),
      const ActionItem(
        label: 'Edit Category Info',
        icon: SFIcons.sf_pencil,
        iconSize: 22,
        iconWeight: FontWeight.w500,
        groupBreakAbove: true,
      ),
      const ActionItem(
        label: 'Select Events',
        icon: SFIcons.sf_checkmark_circle,
      ),
      if (showSectionAction)
        ActionItem(
          label: manageSections ? 'Manage Sections' : 'New Section',
          icon: SFIcons.sf_list_bullet,
          hasChevron: manageSections,
          iconOffset: const Offset(-7.0, 0),
          iconBuilder: (color) => NewSectionIcon(size: 16, color: color),
        ),
      const ActionItem(
        label: 'Sort By',
        icon: SFIcons.sf_arrow_up_arrow_down,
        hasChevron: true,
        subtitle: 'x',
      ),
      const ActionItem(label: 'Show Completed', icon: SFIcons.sf_eye),
      if (!isUtilityCategory)
        const ActionItem(
          label: 'Archive Category',
          icon: SFIcons.sf_archivebox,
        ),
      if (!isUtilityCategory && !isSmartCategory)
        const ActionItem(
          label: 'Delete Category',
          icon: SFIcons.sf_trash,
          isDestructive: true,
        ),
    ];
    final panelW = min(
      ActionItem.panelWidthForItems(
        fullItems,
        context: context,
        minWidth: basePanelW,
        chevronColumn: true,
      ),
      max(1.0, screenW - 32.0),
    );
    final fullH = ActionItem.panelHeightForItems(
      fullItems,
      context: context,
      panelWidth: panelW,
      chevronColumn: true,
    );
    final spaceAbove = btnRect.top - safeTop;
    final spaceBelow = screenH - safeBtm - btnRect.bottom;
    const panelGap = 8.0;
    final aboveRoom = max(1.0, spaceAbove - panelGap);
    final belowRoom = max(1.0, spaceBelow - panelGap);
    final goAbove = aboveRoom > belowRoom;
    final availableRoom = goAbove ? aboveRoom : belowRoom;
    final visiblePanelHeight = min(fullH, availableRoom);
    final panelTop = goAbove
        ? btnRect.top - panelGap - visiblePanelHeight
        : btnRect.bottom + panelGap;
    var panelLeft = btnRect.left;
    panelLeft = panelLeft.clamp(16.0, screenW - panelW - 16.0);

    _dcvMenuOverlay = OverlayEntry(
      builder: (ctx) => _DcvMenuContent(
        panelTop: panelTop,
        panelLeft: panelLeft,
        panelWidth: panelW,
        maxHeight: availableRoom,
        isClosing: _dcvMenuClosing,
        onDismiss: () => _hideDcvMenu(),
        onDismissThen: (afterClosed) => _hideDcvMenu(
          afterClosed: afterClosed,
          closeDuration: const Duration(milliseconds: 260),
        ),
        isSmartCategory: isSmartCategory,
        isUtilityCategory: isUtilityCategory,
        sectionsEnabled: sectionsEnabled,
        initialManageSections: manageSections,
        initialSortBy: initialSortBy,
        onSortChanged: (s) {
          final cat = _dcvCategory;
          if (cat != null && mounted) {
            setState(() => _dcvSortByMap[cat] = s);
            LocalStorage.instance.saveCategorySortMaps(
              _dcvSortByMap,
              _dcvSortDirMap,
            );
          }
        },
        initialSortDir: initialSortDir,
        onSortDirChanged: (d) {
          final cat = _dcvCategory;
          if (cat != null && mounted) {
            setState(() => _dcvSortDirMap[cat] = d);
            LocalStorage.instance.saveCategorySortMaps(
              _dcvSortByMap,
              _dcvSortDirMap,
            );
          }
        },
        initialShowCompleted: _dcvShowCompleted,
        onShowCompletedChanged: (v) {
          if (mounted) setState(() => _dcvShowCompleted = v);
        },
        initialViewAsList: _dcvViewAsList,
        onViewAsListChanged: (v) {
          if (mounted) setState(() => _dcvViewAsList = v);
        },
        onArchiveCategory: isUtilityCategory
            ? null
            : () {
                final cat = _dcvCategory;
                if (cat != null) {
                  _eventsTabKey.currentState?.archiveCategory(
                    cat,
                    onConfirmed: _exitDCV,
                  );
                }
              },
        onDeleteCategory: isUtilityCategory
            ? null
            : () {
                final cat = _dcvCategory;
                if (cat != null) {
                  _eventsTabKey.currentState?.deleteCategory(
                    cat,
                    onConfirmed: _exitDCV,
                  );
                }
              },
        onEditCategory: () {
          final cat = _dcvCategory;
          if (cat != null) _eventsTabKey.currentState?.editCategory(cat);
        },
        onManageSectionsTriggered: () {
          final cat = _dcvCategory;
          if (cat != null && mounted) {
            _eventsTabKey.currentState?.addDcvSection(cat);
          }
        },
        onEditSectionsTriggered: () {
          final cat = _dcvCategory;
          if (cat != null) {
            _eventsTabKey.currentState?.editDcvSections(
              cat,
              _dcvColor ?? resolveAccentColor(context),
            );
          }
        },
      ),
    );
    Overlay.of(context).insert(_dcvMenuOverlay!);
  }

  void _hideDcvMenu({
    VoidCallback? afterClosed,
    Duration closeDuration = const Duration(milliseconds: 400),
  }) {
    if (!_dcvMenuOpen) {
      afterClosed?.call();
      return;
    }
    _dcvMenuOpen = false;
    setState(() {}); // snap ellipsis back to full opacity immediately
    _dcvMenuClosing.value = true;
    // Close animation ≤ 325 ms + 75 ms buffer (covers both main + sort panels).
    Future.delayed(closeDuration, () {
      _dcvMenuOverlay?.remove();
      _dcvMenuOverlay = null;
      if (mounted) {
        _dcvMenuClosing.value = false;
        setState(() {});
      }
      afterClosed?.call();
    });
  }

  Widget _buildViewModeHeaderIcon({
    CalendarViewMode? mode,
    bool applyOpticalOffset = true,
  }) {
    final c = resolveAccentColor(context);
    final landscapeDy =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height
        ? 1.0
        : 0.0;
    Widget place(Widget child, Offset offset) => applyOpticalOffset
        ? Transform.translate(offset: offset, child: child)
        : child;
    switch (mode ?? _activeViewMode) {
      case CalendarViewMode.compact:
        return place(
          CompactViewIcon(color: c, size: 24),
          Offset(1.9, -1 + landscapeDy),
        );
      case CalendarViewMode.stacked:
        return place(
          StackedViewIcon(color: c, size: 24),
          Offset(1.9, -1 + landscapeDy),
        );
      case CalendarViewMode.details:
        return place(
          DetailsViewIcon(color: c, size: 24),
          Offset(2.4, landscapeDy),
        );
      case CalendarViewMode.list:
        return place(
          ListViewIcon(color: c, size: 24),
          Offset(2.4, landscapeDy),
        );
    }
  }

  Widget _buildYearViewHeaderIcon({bool applyOpticalOffset = true}) {
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    final icon = SizedBox(
      // Preserve the same 24×24 alignment box as the Month View icon while
      // rendering the calendar glyph slightly smaller inside it.
      width: 24,
      height: 24,
      child: Center(
        child: FixedSFIcon(
          SFIcons.sf_calendar,
          fontSize: 20,
          fontWeight: FontWeight.w500,
          color: resolveAccentColor(context),
        ),
      ),
    );
    if (!applyOpticalOffset) return icon;
    // Match the ordinary header's optical centre. The trailing toolbar uses
    // the unshifted icon centered by its shared action slot.
    return Transform.translate(
      offset: Offset(2.2, isLandscape ? 0 : -0.5),
      child: icon,
    );
  }

  Widget _toolbarMenuCheckmark(Color accent, {bool selected = true}) {
    final textScaler = MediaQuery.textScalerOf(context);
    if (!selected) return SizedBox(width: textScaler.scale(18));
    return Icon(
      CupertinoIcons.checkmark,
      size: textScaler.scale(17),
      color: resolveThemeColor(accent, context),
    );
  }

  Widget _toolbarMenuSfIcon(
    IconData icon,
    Color color, {
    double size = 20,
    FontWeight weight = FontWeight.w500,
  }) => FixedSFIcon(
    icon,
    fontSize: MediaQuery.textScalerOf(context).scale(size),
    fontWeight: weight,
    color: resolveThemeColor(color, context),
  );

  // Horizontal corrections center rendered ink inside the shared icon slot.
  // Vertical placement is shared by leading icons, labels, and trailing
  // controls through the menu row's center alignment.
  Offset _toolbarMenuIconInkCorrection(
    Widget icon, {
    Offset additionalCorrection = Offset.zero,
  }) {
    final measuredCorrection = switch (icon) {
      // SF glyphs use per-glyph ink corrections; eye_slash reuses eye's.
      FixedSFIcon sfIcon => _toolbarMenuSfIconInkCorrection(sfIcon),
      // The plus is an overlay; align the New Section base to Manage Sections.
      NewSectionIcon() => const Offset(-0.75, 0),
      _ => Offset.zero,
    };
    return measuredCorrection + additionalCorrection;
  }

  Offset _toolbarMenuSfIconInkCorrection(FixedSFIcon icon) {
    final horizontal = icon.icon == SFIcons.sf_arrow_up_arrow_down
        ? -1.75
        : icon.icon == SFIcons.sf_eye || icon.icon == SFIcons.sf_eye_slash
        ? -3.25
        : icon.icon == SFIcons.sf_archivebox
        ? -0.25
        : 0.0;
    return Offset(horizontal, 0);
  }

  Color _toolbarMenuDefaultLabelColor() {
    return resolveThemeColor(kPrimaryLabel, context).withValues(alpha: 0.9);
  }

  GlassMenuItem _toolbarMenuItem({
    required String title,
    required VoidCallback onTap,
    Widget? icon,
    Widget? trailing,
    double? trailingWidth,
    Widget Function(BuildContext context, bool submenuOpen)? trailingBuilder,
    String? subtitle,
    List<Widget>? submenu,
    bool isDestructive = false,
    Color? labelColor,
    Offset iconInkCorrection = Offset.zero,
  }) {
    final resolvedLabelColor = resolveThemeColor(
      isDestructive
          ? CupertinoColors.destructiveRed
          : (labelColor ?? _toolbarMenuDefaultLabelColor()),
      context,
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final iconSlotSize = textScaler.scale(24);
    final iconVisualScale = iconSlotSize / 24;
    final iconInkScale = icon is FixedSFIcon
        ? textScaler.scale(20) / 20
        : iconVisualScale;
    final iconContent = icon == null
        ? const SizedBox.shrink()
        : icon is FixedSFIcon
        ? Center(child: icon)
        : Transform.scale(
            scale: iconVisualScale,
            child: Center(child: icon),
          );
    return GlassMenuItem(
      title: title,
      titleStyle: TextStyle(
        color: resolvedLabelColor,
        fontSize: 17,
        fontWeight: FontWeight.w400,
      ),
      iconColor: resolvedLabelColor,
      icon: SizedBox(
        width: iconSlotSize,
        height: iconSlotSize,
        child: icon == null
            ? const SizedBox.shrink()
            : Transform.translate(
                offset:
                    _toolbarMenuIconInkCorrection(
                      icon,
                      additionalCorrection: iconInkCorrection,
                    ) *
                    iconInkScale,
                child: iconContent,
              ),
      ),
      iconSize: iconSlotSize,
      trailing: trailing,
      trailingWidth: trailing == null && trailingBuilder == null
          ? null
          : (trailingWidth ?? textScaler.scale(18)),
      trailingBuilder: trailingBuilder,
      subtitle: subtitle,
      allowTextWrapping: true,
      submenu: submenu,
      isDestructive: isDestructive,
      onTap: onTap,
    );
  }

  List<Widget> _calendarViewModeMenuItems(Color accent) {
    final current =
        _calendarTabKey.currentState?.viewMode ?? CalendarViewMode.list;
    final labelColor = _toolbarMenuDefaultLabelColor();
    void select(CalendarViewMode mode) {
      _calendarTabKey.currentState?.setViewMode(mode);
      setState(() => _activeViewMode = mode);
      _toolbarMenuRevision.value++;
      if (_selectedIndex == 1) _syncToolbarDestination();
    }

    Widget check(bool selected) =>
        _toolbarMenuCheckmark(accent, selected: selected);
    return [
      _toolbarMenuItem(
        title: 'Compact',
        icon: CompactViewIcon(
          color: current == CalendarViewMode.compact ? accent : labelColor,
          size: 24,
        ),
        labelColor: current == CalendarViewMode.compact ? accent : labelColor,
        trailing: check(current == CalendarViewMode.compact),
        onTap: () => select(CalendarViewMode.compact),
      ),
      _toolbarMenuItem(
        title: 'Stacked',
        icon: StackedViewIcon(
          color: current == CalendarViewMode.stacked ? accent : labelColor,
          size: 24,
        ),
        labelColor: current == CalendarViewMode.stacked ? accent : labelColor,
        trailing: check(current == CalendarViewMode.stacked),
        onTap: () => select(CalendarViewMode.stacked),
      ),
      _toolbarMenuItem(
        title: 'Details',
        icon: DetailsViewIcon(
          color: current == CalendarViewMode.details ? accent : labelColor,
          size: 24,
        ),
        labelColor: current == CalendarViewMode.details ? accent : labelColor,
        trailing: check(current == CalendarViewMode.details),
        onTap: () => select(CalendarViewMode.details),
      ),
      const GlassMenuDivider(height: 8),
      _toolbarMenuItem(
        title: 'List',
        icon: ListViewIcon(
          color: current == CalendarViewMode.list ? accent : labelColor,
          size: 24,
        ),
        labelColor: current == CalendarViewMode.list ? accent : labelColor,
        trailing: check(current == CalendarViewMode.list),
        onTap: () => select(CalendarViewMode.list),
      ),
    ];
  }

  List<Widget> _calendarDayModeMenuItems(Color accent) {
    final current = _activeDaySubMode;
    final labelColor = _toolbarMenuDefaultLabelColor();
    void select(DayViewSubMode mode) {
      setState(() => _activeDaySubMode = mode);
      _toolbarMenuRevision.value++;
      if (_selectedIndex == 1) {
        _syncToolbarDestination();
        _restoreHeaderScrollOffset();
      }
      SharedPreferences.getInstance().then(
        (prefs) => prefs.setString('day_view_sub_mode', mode.name),
      );
    }

    Widget modeIcon(String asset, Color color) => SvgPicture.asset(
      asset,
      width: 24,
      height: 24,
      colorFilter: ColorFilter.mode(
        resolveThemeColor(color, context),
        BlendMode.srcIn,
      ),
    );
    Widget check(bool selected) =>
        _toolbarMenuCheckmark(accent, selected: selected);
    return [
      _toolbarMenuItem(
        title: 'Single Day',
        icon: modeIcon(
          'assets/icons/day_view_single_day.svg',
          current == DayViewSubMode.singleDay ? accent : labelColor,
        ),
        labelColor: current == DayViewSubMode.singleDay ? accent : labelColor,
        trailing: check(current == DayViewSubMode.singleDay),
        onTap: () => select(DayViewSubMode.singleDay),
      ),
      _toolbarMenuItem(
        title: 'Multi Day',
        icon: modeIcon(
          'assets/icons/day_view_multi_day.svg',
          current == DayViewSubMode.multiDay ? accent : labelColor,
        ),
        labelColor: current == DayViewSubMode.multiDay ? accent : labelColor,
        trailing: check(current == DayViewSubMode.multiDay),
        onTap: () => select(DayViewSubMode.multiDay),
      ),
      _toolbarMenuItem(
        title: 'List',
        icon: modeIcon(
          'assets/icons/day_view_list.svg',
          current == DayViewSubMode.list ? accent : labelColor,
        ),
        iconInkCorrection: const Offset(0.5, 0),
        labelColor: current == DayViewSubMode.list ? accent : labelColor,
        trailing: check(current == DayViewSubMode.list),
        onTap: () => select(DayViewSubMode.list),
      ),
    ];
  }

  List<Widget> _dcvToolbarMenuItems(Color accent) {
    final category = _dcvCategory;
    if (category == null) return const [];

    final labelColor = _toolbarMenuDefaultLabelColor();
    final isSmartCategory = _kSmartCategoryLabels.contains(category);
    final isUtilityCategory = _kUtilityDcvLabels.contains(category);
    final userSmartCategory =
        _eventsTabKey.currentState?.isUserSmartCategoryLabel(category) ?? false;
    final sectionsEnabled = !userSmartCategory && _dcvSectionsEnabled(category);
    final sortBy = isUtilityCategory
        ? 'Creation Date'
        : (_dcvSortByMap[category] ?? 'Manual');
    final storedSortDir = _dcvSortDirMap[category];
    final directions = <String, List<String>>{
      'Deadline': ['Earliest First', 'Latest First'],
      'Creation Date': ['Oldest First', 'Newest First'],
      'Priority': ['Lowest First', 'Highest First'],
      'Title': ['Ascending', 'Descending'],
    };
    final sortDir =
        isUtilityCategory &&
            storedSortDir != 'Oldest First' &&
            storedSortDir != 'Newest First'
        ? 'Newest First'
        : (storedSortDir ?? directions[sortBy]?.first ?? '');
    final hasSections =
        sectionsEnabled &&
        sortBy == 'Manual' &&
        (_eventsTabKey.currentState?.dcvHasSections(category) ?? false);

    void saveSort(String mode, {String? direction}) {
      if (mode != sortBy && direction == null) {
        final defaultDirection = directions[mode]?.first;
        if (defaultDirection != null) {
          _dcvSortDirMap[category] = defaultDirection;
        }
      }
      _dcvSortByMap[category] = mode;
      if (direction != null) _dcvSortDirMap[category] = direction;
      LocalStorage.instance.saveCategorySortMaps(_dcvSortByMap, _dcvSortDirMap);
      _toolbarMenuRevision.value++;
      if (mounted) setState(() {});
    }

    Widget check(bool selected) =>
        _toolbarMenuCheckmark(labelColor, selected: selected);
    Widget sf(IconData icon, {double size = 20, Color? color}) =>
        _toolbarMenuSfIcon(icon, color ?? labelColor, size: size);
    Widget modeSubmenuIcon(
      bool selected, {
      bool hasChevron = true,
      bool isOpen = false,
    }) {
      final textScaler = MediaQuery.textScalerOf(context);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (selected)
            Icon(
              CupertinoIcons.checkmark,
              size: textScaler.scale(17),
              color: resolveThemeColor(labelColor, context),
            ),
          if (selected) SizedBox(width: textScaler.scale(6)),
          if (hasChevron)
            AnimatedRotation(
              turns: isOpen ? 0.25 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeInOut,
              child: FixedSFIcon(
                SFIcons.sf_chevron_right,
                fontSize: textScaler.scale(17),
                fontWeight: FontWeight.w500,
                color: resolveThemeColor(labelColor, context),
              ),
            )
          else
            SizedBox(width: textScaler.scale(17)),
        ],
      );
    }

    double modeSubmenuIconWidth(bool selected) =>
        MediaQuery.textScalerOf(context).scale(selected ? 40 : 17);

    final sortItems = <Widget>[];
    if (isUtilityCategory) {
      for (final direction in const ['Oldest First', 'Newest First']) {
        sortItems.add(
          _toolbarMenuItem(
            title: direction,
            trailing: check(sortDir == direction),
            onTap: () => saveSort('Creation Date', direction: direction),
          ),
        );
      }
    } else {
      const sortOptions = [
        'Manual',
        'Deadline',
        'Creation Date',
        'Priority',
        'Title',
      ];
      for (final option in sortOptions) {
        final optionDirections = directions[option];
        if (optionDirections == null) {
          sortItems.add(
            _toolbarMenuItem(
              title: option,
              trailing: modeSubmenuIcon(sortBy == option, hasChevron: false),
              trailingWidth: modeSubmenuIconWidth(sortBy == option),
              onTap: () => saveSort(option),
            ),
          );
        } else {
          final selected = sortBy == option;
          sortItems.add(
            _toolbarMenuItem(
              title: option,
              subtitle: selected ? sortDir : null,
              trailingBuilder: (context, isOpen) =>
                  modeSubmenuIcon(selected, isOpen: isOpen),
              trailingWidth: modeSubmenuIconWidth(selected),
              submenu: [
                for (final direction in optionDirections)
                  _toolbarMenuItem(
                    title: direction,
                    trailing: check(selected && sortDir == direction),
                    onTap: () => saveSort(option, direction: direction),
                  ),
              ],
              onTap: () {},
            ),
          );
        }
      }
    }

    return [
      _toolbarMenuItem(
        title: _dcvViewAsList ? 'View as List' : 'View as Columns',
        icon: _dcvViewAsList
            ? sf(SFIcons.sf_list_bullet)
            : ColumnsViewIcon(color: labelColor, size: 24),
        labelColor: labelColor,
        onTap: () {
          setState(() => _dcvViewAsList = !_dcvViewAsList);
          _toolbarMenuRevision.value++;
        },
      ),
      const GlassMenuDivider(height: 8),
      _toolbarMenuItem(
        title: 'Edit Category Info',
        icon: sf(SFIcons.sf_pencil),
        onTap: () => _eventsTabKey.currentState?.editCategory(category),
      ),
      _toolbarMenuItem(
        title: 'Select Events',
        icon: sf(SFIcons.sf_checkmark_circle),
        onTap: () {},
      ),
      if (sectionsEnabled && sortBy == 'Manual')
        if (hasSections)
          _toolbarMenuItem(
            title: 'Manage Sections',
            icon: NewSectionIcon(size: 16, color: labelColor),
            trailingBuilder: (context, isOpen) =>
                modeSubmenuIcon(false, isOpen: isOpen),
            trailingWidth: modeSubmenuIconWidth(false),
            submenu: [
              _toolbarMenuItem(
                title: 'New Section',
                onTap: () =>
                    _eventsTabKey.currentState?.addDcvSection(category),
              ),
              _toolbarMenuItem(
                title: 'Edit Sections',
                onTap: () => _eventsTabKey.currentState?.editDcvSections(
                  category,
                  _dcvColor ?? accent,
                ),
              ),
            ],
            onTap: () {},
          )
        else
          _toolbarMenuItem(
            title: 'New Section',
            icon: NewSectionIcon(
              size: 16,
              color: labelColor,
              showPlusBadge: true,
            ),
            onTap: () => _eventsTabKey.currentState?.addDcvSection(category),
          ),
      _toolbarMenuItem(
        title: 'Sort By',
        subtitle: isUtilityCategory ? sortDir : sortBy,
        icon: sf(SFIcons.sf_arrow_up_arrow_down),
        labelColor: labelColor,
        trailingBuilder: (context, isOpen) =>
            modeSubmenuIcon(false, isOpen: isOpen),
        trailingWidth: modeSubmenuIconWidth(false),
        submenu: sortItems,
        onTap: () {},
      ),
      _toolbarMenuItem(
        title: _dcvShowCompleted ? 'Show Completed' : 'Hide Completed',
        icon: sf(_dcvShowCompleted ? SFIcons.sf_eye : SFIcons.sf_eye_slash),
        labelColor: labelColor,
        onTap: () {
          setState(() => _dcvShowCompleted = !_dcvShowCompleted);
          _toolbarMenuRevision.value++;
        },
      ),
      if (!isUtilityCategory)
        _toolbarMenuItem(
          title: 'Archive Category',
          icon: sf(SFIcons.sf_archivebox),
          onTap: () => _eventsTabKey.currentState?.archiveCategory(
            category,
            onConfirmed: _exitDCV,
          ),
        ),
      if (!isUtilityCategory && !isSmartCategory)
        _toolbarMenuItem(
          title: 'Delete Category',
          icon: sf(SFIcons.sf_trash, color: CupertinoColors.destructiveRed),
          isDestructive: true,
          onTap: () => _eventsTabKey.currentState?.deleteCategory(
            category,
            onConfirmed: _exitDCV,
          ),
        ),
    ];
  }

  void _showViewModeMenu({Rect? anchorRect}) {
    if (_viewModeMenuOpen) return;
    final box = anchorRect == null
        ? _viewModeKey.currentContext?.findRenderObject() as RenderBox?
        : null;
    if (anchorRect == null && box == null) return;
    final buttonRect =
        anchorRect ??
        Rect.fromLTWH(
          box!.localToGlobal(Offset.zero).dx,
          box.localToGlobal(Offset.zero).dy,
          box.size.width,
          box.size.height,
        );
    _viewModeClosing.value = false;
    _viewModeMenuOpen = true;
    setState(() {});

    final current =
        _calendarTabKey.currentState?.viewMode ?? CalendarViewMode.list;
    void doSelect(CalendarViewMode mode) {
      _hideViewModeMenu();
      _calendarTabKey.currentState?.setViewMode(mode);
      setState(() => _activeViewMode = mode);
      if (_selectedIndex == 1) _syncToolbarDestination();
    }

    final items = [
      ActionItem(
        label: 'Compact',
        icon: SFIcons.sf_square_grid_2x2,
        iconBuilder: (c) => CompactViewIcon(color: c, size: 24),
        iconOffset: const Offset(-2, 0),
        checkmark: current == CalendarViewMode.compact,
        onTap: () => doSelect(CalendarViewMode.compact),
      ),
      ActionItem(
        label: 'Stacked',
        icon: SFIcons.sf_square_stack,
        iconBuilder: (c) => StackedViewIcon(color: c, size: 24),
        iconOffset: const Offset(-2, 0),
        checkmark: current == CalendarViewMode.stacked,
        onTap: () => doSelect(CalendarViewMode.stacked),
      ),
      ActionItem(
        label: 'Details',
        icon: SFIcons.sf_list_bullet,
        iconBuilder: (c) => DetailsViewIcon(color: c, size: 24),
        iconOffset: const Offset(-2, 0),
        checkmark: current == CalendarViewMode.details,
        onTap: () => doSelect(CalendarViewMode.details),
      ),
      ActionItem(
        label: 'List',
        icon: SFIcons.sf_list_bullet_below_rectangle,
        iconBuilder: (c) => ListViewIcon(color: c, size: 24),
        iconOffset: const Offset(-2, 0),
        checkmark: current == CalendarViewMode.list,
        groupBreakAbove: true,
        onTap: () => doSelect(CalendarViewMode.list),
      ),
    ];

    _viewModeOverlay = OverlayEntry(
      builder: (ctx) => ActionMenuOverlay(
        buttonRect: buttonRect,
        isClosing: _viewModeClosing,
        onDismiss: _hideViewModeMenu,
        actions: items,
        chevronColumn: true,
      ),
    );
    Overlay.of(context).insert(_viewModeOverlay!);
  }

  void _hideViewModeMenu() {
    if (!_viewModeMenuOpen) return;
    _viewModeMenuOpen = false;
    setState(() {});
    _viewModeClosing.value = true;
    // 4-item close ≈ 280 ms + 80 ms buffer.
    Future.delayed(const Duration(milliseconds: 360), () {
      _viewModeOverlay?.remove();
      _viewModeOverlay = null;
      if (mounted) {
        _viewModeClosing.value = false;
        setState(() {});
      }
    });
  }

  // ── Day View sub-mode ──────────────────────────────────────────────────────

  Widget _buildDayViewModeHeaderIcon({
    DayViewSubMode? mode,
    bool applyOpticalOffset = true,
  }) {
    final c = resolveAccentColor(context);
    const sz = 26.0;
    final cf = ColorFilter.mode(c, BlendMode.srcIn);
    final landscapeDy =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height
        ? 0.5
        : 0.0;
    Widget place(Widget child, Offset offset) => applyOpticalOffset
        ? Transform.translate(offset: offset, child: child)
        : child;
    // Ordinary header icons shift optically; trailing toolbar actions remain
    // centered in their shared action slots.
    switch (mode ?? _activeDaySubMode) {
      case DayViewSubMode.singleDay:
        return place(
          SvgPicture.asset(
            'assets/icons/day_view_single_day.svg',
            width: sz,
            height: sz,
            colorFilter: cf,
          ),
          Offset(2, -0.5 + landscapeDy),
        );
      case DayViewSubMode.multiDay:
        return place(
          SvgPicture.asset(
            'assets/icons/day_view_multi_day.svg',
            width: sz,
            height: sz,
            colorFilter: cf,
          ),
          Offset(2, -0.5 + landscapeDy),
        );
      case DayViewSubMode.list:
        return place(
          SvgPicture.asset(
            'assets/icons/day_view_list.svg',
            width: sz,
            height: sz,
            colorFilter: cf,
          ),
          Offset(2, -0.3 + landscapeDy),
        );
    }
  }

  void _showDayViewModeMenu({Rect? anchorRect}) {
    if (_dayViewModeMenuOpen) return;
    final box = anchorRect == null
        ? _dayViewModeKey.currentContext?.findRenderObject() as RenderBox?
        : null;
    if (anchorRect == null && box == null) return;
    final buttonRect =
        anchorRect ??
        Rect.fromLTWH(
          box!.localToGlobal(Offset.zero).dx,
          box.localToGlobal(Offset.zero).dy,
          box.size.width,
          box.size.height,
        );
    _dayViewModeClosing.value = false;
    _dayViewModeMenuOpen = true;
    setState(() {});

    final current = _activeDaySubMode;
    void doSelect(DayViewSubMode mode) {
      _hideDayViewModeMenu();
      setState(() => _activeDaySubMode = mode);
      if (_selectedIndex == 1) _syncToolbarDestination();
      if (_selectedIndex == 1) _restoreHeaderScrollOffset();
      SharedPreferences.getInstance().then(
        (p) => p.setString('day_view_sub_mode', mode.name),
      );
    }

    final items = [
      ActionItem(
        label: 'Single Day',
        icon: SFIcons.sf_calendar,
        iconBuilder: (c) => SvgPicture.asset(
          'assets/icons/day_view_single_day.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
        ),
        iconOffset: const Offset(-2, 0),
        checkmark: current == DayViewSubMode.singleDay,
        onTap: () => doSelect(DayViewSubMode.singleDay),
      ),
      ActionItem(
        label: 'Multi Day',
        icon: SFIcons.sf_calendar,
        iconBuilder: (c) => SvgPicture.asset(
          'assets/icons/day_view_multi_day.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
        ),
        iconOffset: const Offset(-2, 0),
        checkmark: current == DayViewSubMode.multiDay,
        onTap: () => doSelect(DayViewSubMode.multiDay),
      ),
      ActionItem(
        label: 'List',
        icon: SFIcons.sf_list_bullet,
        iconBuilder: (c) => SvgPicture.asset(
          'assets/icons/day_view_list.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
        ),
        iconOffset: const Offset(-2, 0),
        checkmark: current == DayViewSubMode.list,
        onTap: () => doSelect(DayViewSubMode.list),
      ),
    ];

    _dayViewModeOverlay = OverlayEntry(
      builder: (ctx) => ActionMenuOverlay(
        buttonRect: buttonRect,
        isClosing: _dayViewModeClosing,
        onDismiss: _hideDayViewModeMenu,
        actions: items,
        chevronColumn: true,
      ),
    );
    Overlay.of(context).insert(_dayViewModeOverlay!);
  }

  void _hideDayViewModeMenu() {
    if (!_dayViewModeMenuOpen) return;
    _dayViewModeMenuOpen = false;
    setState(() {});
    _dayViewModeClosing.value = true;
    // Three rows close in about 358 ms at the shared ActionPanel duration.
    // Match the other three-row panels and leave time for the close to settle.
    Future.delayed(const Duration(milliseconds: 420), () {
      _dayViewModeOverlay?.remove();
      _dayViewModeOverlay = null;
      if (mounted) {
        _dayViewModeClosing.value = false;
        setState(() {});
      }
    });
  }

  // True while the search bar in the currently-visible tab is focused.
  bool _searchFocused = false;
  // Removes the pinned registration only after it has moved above the
  // viewport. This keeps the surface visible during the search handoff.
  final ValueNotifier<bool> _searchToolbarHidden = ValueNotifier(false);
  final ValueNotifier<bool> _searchToolbarInteractionsEnabled = ValueNotifier(
    true,
  );
  final ValueNotifier<int> _searchOverlayRevision = ValueNotifier(0);
  late final AnimationController _searchToolbarSlideController;
  late final CurvedAnimation _searchToolbarSlideProgress;
  // True if the current search session was entered via the off-screen path
  // (header search icon tapped while bar is scrolled out of view).  Used to
  // decide whether to snap or animate the header back on exit.
  bool _searchEnteredOffScreen = false;

  // Fires at midnight so the Calendar-tab header title updates live when the
  // month rolls over, without requiring the user to navigate away and back.
  Timer? _midnightTimer;

  void _scheduleMidnightRefresh() {
    final now = DateTime.now();
    final nextMidnight = DateTime(now.year, now.month, now.day + 1);
    _midnightTimer = Timer(nextMidnight.difference(now), () {
      if (mounted) setState(() {});
      _scheduleMidnightRefresh();
    });
  }

  // Drives every search-mode visual transition — header height, header
  // background colour (white → background grey so the status-bar inset
  // blends in), bottom border + drop-shadow fade, and the icon-row + title
  // fade-out — from a single AnimationController so they advance in
  // lockstep frame-for-frame. Independently-driven AnimatedFoo widgets
  // can drift by a frame or two and feel laggy; one controller + one
  // AnimatedBuilder feels noticeably more premium.
  late final AnimationController _searchModeController;
  late final Animation<double> _searchModeAnim;
  // Pre-built Tween-of-the-curve for the icons-row + title fade-out.
  // Driving a FadeTransition off this is significantly cheaper than
  // wrapping the same subtree in Opacity, because FadeTransition can
  // skip its saveLayer entirely at fully-transparent / fully-opaque
  // endpoints — which removes the offscreen-buffer cost that was
  // making the transition feel laggy on lower-end Android devices.
  late final Animation<double> _searchModeContentOpacity;

  // Module-wide curve constants so NotesTab's Cancel-button animation can
  // match these exactly without duplicating magic numbers.
  //
  // We deliberately use a SINGLE easeOutCubic for both forward and reverse
  // (instead of asymmetric easeOut / easeIn). NotesTab's _CancelXButton is
  // an implicit AnimatedSize, which only accepts one curve and applies it
  // both ways — keeping the AppShell controller's curve symmetric here
  // means the header collapse/expand and the X-button reveal/hide stay in
  // perfect lockstep on BOTH directions, which is the actual premium feel.
  //
  // 200 ms hits the sweet spot for a "modal reveal" transition: short
  // enough to feel snappy and responsive (anything ≥250 ms reads as
  // sluggish for a single-axis collapse on mobile), but long enough that
  // the eye still tracks the motion as continuous instead of a snap.
  static const _kSearchModeDuration = Duration(milliseconds: 250);
  static const _kSearchModeCurve = Curves.easeInOutCubic;

  @override
  void initState() {
    super.initState();
    appDefaultViewNotifier.addListener(_onDefaultViewSettingChanged);
    _nativeTabBarChannel.setMethodCallHandler(_handleNativeTabBarCall);
    unawaited(_configureNativeTabBar());

    // Restore persisted per-category sort settings.
    LocalStorage.instance.loadCategorySortMaps().then((maps) {
      if (mounted)
        setState(() {
          _dcvSortByMap.addAll(maps.$1);
          _dcvSortDirMap.addAll(maps.$2);
        });
    });
    // A previous build could leave a crash report in app documents.  Never
    // surface that diagnostic as a startup dialog: showCupertinoDialog adds a
    // modal barrier before the user has any way to recover, and persisted
    // reports survive ordinary restarts, APK replacement, and Shorebird
    // patches.  The report has already been read and removed in main(); keep
    // the value available for debugger inspection without blocking startup.
    _pendingCrashReport = null;

    _searchModeController = AnimationController(
      vsync: this,
      duration: _kSearchModeDuration,
    );
    _searchModeAnim = CurvedAnimation(
      parent: _searchModeController,
      curve: _kSearchModeCurve,
    );
    _searchModeContentOpacity = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(_searchModeAnim);
    _searchToolbarSlideController = AnimationController(
      vsync: this,
      duration: _kSearchModeDuration,
    )..addStatusListener(_onSearchToolbarSlideStatus);
    _searchToolbarSlideProgress = CurvedAnimation(
      parent: _searchToolbarSlideController,
      curve: _kSearchModeCurve,
    );
    _dcvSlideController = AnimationController(
      vsync: this,
      duration: kDcvPaneTransitionDuration,
    );
    _dcvSlideProgress = CurvedAnimation(
      parent: _dcvSlideController,
      curve: Curves.easeInOutCubic,
    );
    _dcvCategoryTransitionController = AnimationController(
      vsync: this,
      duration: kDcvPaneTransitionDuration,
    )..value = 1.0;
    _dcvCategoryTransitionProgress = CurvedAnimation(
      parent: _dcvCategoryTransitionController,
      curve: Curves.easeInOutCubic,
    );
    _dcvCategoryTransitionController.addStatusListener(
      _onDcvCategoryTransitionStatus,
    );
    _scheduleMidnightRefresh();
    SharedPreferences.getInstance().then((prefs) {
      if (!mounted) return;
      final stored = prefs.getString('calendar_view_mode');
      final mode = CalendarViewMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => CalendarViewMode.compact,
      );
      // Load persisted day-view sub-mode (default: singleDay on fresh install).
      final storedSub = prefs.getString('day_view_sub_mode');
      final subMode = DayViewSubMode.values.firstWhere(
        (m) => m.name == storedSub,
        orElse: () => DayViewSubMode.singleDay,
      );
      final defaultDaySubMode = calendarDaySubModeForDefaultViewSetting(
        appDefaultViewNotifier.value,
      );
      setState(() {
        _activeViewMode = mode;
        _activeDaySubMode = defaultDaySubMode ?? subMode;
      });
    });
  }

  void _onDefaultViewSettingChanged() {
    if (!mounted) return;
    final setting = appDefaultViewNotifier.value;
    final targetView = calendarViewForDefaultViewSetting(setting);
    final targetDaySubMode = calendarDaySubModeForDefaultViewSetting(setting);
    setState(() {
      _calendarView = targetView;
      if (targetDaySubMode != null) {
        _activeDaySubMode = targetDaySubMode;
      }
    });
    _calendarTabKey.currentState?.applyDefaultView(targetView);
    _syncToolbarDestination();
  }

  @override
  void dispose() {
    appDefaultViewNotifier.removeListener(_onDefaultViewSettingChanged);
    _nativeTabBarChannel.setMethodCallHandler(null);
    _midnightTimer?.cancel();
    _dcvCategoryTransitionController.removeStatusListener(
      _onDcvCategoryTransitionStatus,
    );
    _dcvCategoryTransitionProgress.dispose();
    _dcvCategoryTransitionController.dispose();
    _dcvSlideProgress.dispose();
    _dcvSlideController.dispose();
    _dcvToolbarAccent.dispose();
    _searchModeController.dispose();
    _searchToolbarSlideController.removeStatusListener(
      _onSearchToolbarSlideStatus,
    );
    _searchToolbarSlideProgress.dispose();
    _searchToolbarSlideController.dispose();
    _searchToolbarHidden.dispose();
    _searchToolbarInteractionsEnabled.dispose();
    _searchOverlayRevision.dispose();
    _toolbarMenuRevision.dispose();
    _calendarStripSlide.dispose();
    _appShellNavigationObserver.dispose();
    _appShellRouteRevision.dispose();
    _settingsBackAction.dispose();
    _settingsInlineBackVisible.dispose();
    _headerTitleTransition.dispose();
    super.dispose();
  }

  // ── OS back gesture / back button handler ────────────────────────────────
  // Priority (highest → lowest):
  //   1. Any action panel open          → dismiss it
  //        • DCV ellipsis menu
  //        • Calendar month view-mode menu
  //        • Calendar day view-mode menu
  //        • Notes Tab attach panel / attachment preview
  //        • Events Tab category long-press context menu
  //   2. Search mode active             → cancel search (also dismisses keyboard)
  //   3. DCV active                     → exit DCV
  //   4. Calendar Day or Month view     → navigate down (Day→Month, Month→Year)
  //   5. Keyboard focused               → dismiss keyboard
  //   6. Nothing to dismiss             → allow natural pop (exits app on Android)
  bool get _hasBackInterceptable =>
      _settingsOpen ||
      _dcvMenuOpen ||
      _viewModeMenuOpen ||
      _dayViewModeMenuOpen ||
      (_notesTabKey.currentState?.hasOpenPanel == true) ||
      (_eventsTabKey.currentState?.hasOpenContextMenu == true) ||
      _searchFocused ||
      _isDCV ||
      (_selectedIndex == 1 &&
          (_calendarView == CalendarView.month ||
              _calendarView == CalendarView.day)) ||
      (FocusManager.instance.primaryFocus?.hasFocus == true);

  void _handleBackGesture() {
    // ── 0. Settings panel ─────────────────────────────────────────────────
    if (_settingsOpen) {
      if (_settingsInlineBackVisible.value) {
        _settingsBackAction.value?.call();
        return;
      }
      _appShellNavigatorKey.currentState?.maybePop();
      return;
    }
    // ── 1. Action panels — dismiss the topmost open one ──────────────────
    if (_dcvMenuOpen) {
      _hideDcvMenu();
    } else if (_viewModeMenuOpen) {
      _hideViewModeMenu();
    } else if (_dayViewModeMenuOpen) {
      _hideDayViewModeMenu();
    } else if (_notesTabKey.currentState?.hasOpenPanel == true) {
      _notesTabKey.currentState!.dismissOpenPanel();
    } else if (_eventsTabKey.currentState?.hasOpenContextMenu == true) {
      _eventsTabKey.currentState!.dismissContextMenu();
      // ── 2. Search mode ────────────────────────────────────────────────────
    } else if (_searchFocused) {
      if (_selectedIndex == 0) {
        _notesTabKey.currentState?.cancelSearch();
      } else if (_selectedIndex == 1) {
        _calendarTabKey.currentState?.cancelSearch();
      } else {
        _eventsTabKey.currentState?.cancelSearch();
      }
      // ── 3. DCV ────────────────────────────────────────────────────────────
    } else if (_isDCV) {
      _exitDCV();
      // ── 4. Calendar depth ─────────────────────────────────────────────────
    } else if (_selectedIndex == 1 &&
        (_calendarView == CalendarView.month ||
            _calendarView == CalendarView.day)) {
      // Calendar: Day → Month → Year
      _calendarTabKey.currentState?.navigateDown();
      // ── 5. Keyboard ───────────────────────────────────────────────────────
    } else if (FocusManager.instance.primaryFocus?.hasFocus == true) {
      NativeTextInput.unfocusAll();
      FocusManager.instance.primaryFocus?.unfocus();
    }
  }

  void _onSearchToolbarSlideStatus(AnimationStatus status) {
    if (!mounted) return;
    if (status == AnimationStatus.completed && _searchFocused) {
      if (!_searchToolbarHidden.value) {
        _searchToolbarHidden.value = true;
        _syncToolbarDestination();
      }
    } else if (status == AnimationStatus.dismissed && !_searchFocused) {
      _searchToolbarInteractionsEnabled.value = true;
    }
  }

  void _setSearchFocused(bool focused) {
    if (_searchFocused == focused) return;
    final enteredOffScreen = _searchEnteredOffScreen;
    if (enteredOffScreen) {
      setState(() {
        _searchFocused = focused;
        if (!focused) _searchEnteredOffScreen = false;
      });
      _syncToolbarDestination();
      return;
    }
    _searchToolbarHidden.value = focused && enteredOffScreen;
    _searchToolbarInteractionsEnabled.value = false;
    if (focused && !enteredOffScreen) {
      // The tab settles its own scroll position before reporting focus. Sync
      // the shell title from that settled parent so a stale overscroll value
      // cannot hide the second-level header after Search closes.
      _settleShellTransitionsForSearch();
      _syncHeaderScrollOffsetToParent(preserveCollapseProgress: true);
      // Freeze the settled parent state before the search layout changes the
      // viewport. Search chrome can animate independently without becoming a
      // new source for the parent's shared header state.
      _headerTitleTransition.suspend();
    }
    setState(() => _searchFocused = focused);
    _syncToolbarDestination();
    if (focused) {
      if (!enteredOffScreen) {
        _searchToolbarSlideController.forward();
        _searchModeController.forward();
      }
    } else {
      if (enteredOffScreen) {
        // Off-screen search never changed the parent's scroll geometry.
        // Keep the existing header binding and scroll position untouched.
        _searchToolbarInteractionsEnabled.value = true;
      } else {
        _searchToolbarSlideController.reverse();
        _searchModeController.reverse();
      }
      _searchEnteredOffScreen = false;
    }
  }

  void _notifySearchOverlayChanged() {
    if (mounted) _searchOverlayRevision.value++;
  }

  /// Called by the header search icon.  Focuses whichever tab's search bar is
  /// active, and either animates or snaps the header depending on whether the
  /// search bar is currently visible in the viewport.
  void _activateTabSearch() {
    if (_searchFocused) return;

    // The You destination is currently empty, so its search control uses the
    // existing off-screen Events search experience without changing tabs.
    if (_selectedIndex == 3) {
      _searchEnteredOffScreen = true;
      setState(() => _searchFocused = true);
      _syncToolbarDestination();
      _eventsTabKey.currentState?.activateSearchMode();
      return;
    }

    // Calendar tab: always use the off-screen path so its own search overlay
    // appears over the untouched parent screen.
    if (_selectedIndex == 1) {
      _searchEnteredOffScreen = true;
      setState(() => _searchFocused = true);
      _syncToolbarDestination();
      _calendarTabKey.currentState?.activateSearchMode();
      return;
    }

    final scrollCtrl = _selectedIndex == 0
        ? _notesTabKey.currentState?.scrollController
        : _eventsTabKey.currentState?.scrollController;

    // In DCV the search bar lives on page 0 of the PageView and is completely
    // hidden — always force the off-screen animation path so the slide plays.
    final bool isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final headerPosition = AppHeaderScrollView.headerPositionFor(scrollCtrl);
    final bool visible =
        !isLandscape &&
        !_isDCV &&
        (headerPosition != null
            ? _headerTitleTransition.searchBarCollapseProgress < 1.0
            : (scrollCtrl == null ||
                  !scrollCtrl.hasClients ||
                  scrollCtrl.offset < searchBarHostRowHeight(context)));

    if (!visible) {
      // Search is a genuine overlay. Do not settle, save, resize, or otherwise
      // touch the parent's scrollable or its shared header position.
      _searchEnteredOffScreen = true;
      setState(() => _searchFocused = true); // AppShell state
      _syncToolbarDestination();
      if (_selectedIndex == 0) {
        _notesTabKey.currentState?.activateSearchMode();
      } else {
        _eventsTabKey.currentState?.activateSearchMode();
      }
    } else {
      _settleShellTransitionsForSearch();
      switch (_selectedIndex) {
        case 0:
          _notesTabKey.currentState?.prepareParentForSearch();
        case 1:
          _calendarTabKey.currentState?.prepareParentForSearch();
        case 2:
          _eventsTabKey.currentState?.prepareParentForSearch();
      }
      _syncHeaderScrollOffsetToParent(preserveCollapseProgress: true);
      _headerTitleTransition.suspend();
      // Search bar is visible: just focus it and let the normal async
      // onFocusChanged chain animate the header and update tab state.
      _searchEnteredOffScreen = false;
      if (_selectedIndex == 0) {
        _notesTabKey.currentState?.focusSearch();
      } else {
        _eventsTabKey.currentState?.focusSearch();
      }
    }
  }

  // When the user switches tabs we:
  //   1. If leaving the Notes tab while search mode is active, call
  //      its explicit tab-switch reset to clear the query and search-mode UI.
  //      Framework deactivate() is not an app-level cancellation hook: a
  //      temporary subtree reparent during layout must preserve the draft.
  //   2. Dismiss the keyboard and any active text-input focus.
  void _switchTab(int index) {
    if (index < 0 || index > 3) return;
    if (_selectedIndex == index) return;

    // Cleanly cancel search on whichever tab we're leaving.
    if (_searchFocused) {
      if (_selectedIndex == 0) {
        _notesTabKey.currentState?.resetSearchForTabSwitch();
      }
      if (_selectedIndex == 1) _calendarTabKey.currentState?.cancelSearch();
      if (_selectedIndex == 2 || _selectedIndex == 3) {
        _eventsTabKey.currentState?.resetSearchForTabSwitch();
      }
    }

    NativeTextInput.unfocusAll();
    FocusManager.instance.primaryFocus?.unfocus();
    sbResetSearchMode();
    _searchToolbarHidden.value = false;
    _searchToolbarInteractionsEnabled.value = true;
    _searchToolbarSlideController.value = 0.0;

    setState(() {
      _selectedIndex = index;
      _searchFocused = false;
      // _dcvCategory intentionally NOT cleared — DCV persists when switching
      // tabs and is restored when the user returns to Events tab.
    });
    _searchModeController.value = 0;
    if (index == 3) {
      _headerTitleTransition.suspend();
    } else {
      _restoreHeaderScrollOffset();
    }
    if (_usesNativeTabBar) {
      unawaited(
        _nativeTabBarChannel.invokeMethod<void>(
          'setSelectedIndex',
          _selectedIndex,
        ),
      );
    }
    _syncToolbarDestination();
  }

  Future<void> _handleNativeTabBarCall(MethodCall call) async {
    if (call.method != 'tabSelected') return;
    final index = call.arguments is int ? call.arguments as int : null;
    if (index == null || index < 0 || index > 3 || !mounted) return;
    _switchTab(index);
  }

  Future<void> _configureNativeTabBar() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    try {
      final available = await _nativeTabBarChannel.invokeMethod<bool>(
        'isAvailable',
      );
      if (!mounted || available != true) return;

      // Older iOS releases have a standard bottom UITabBar; iOS 26+ presents
      // the floating native style. Keep the older native bridge compatible:
      // before this query existed, an available native bar meant iOS 26+.
      var isFloatingNativeTabBar = true;
      try {
        isFloatingNativeTabBar =
            await _nativeTabBarChannel.invokeMethod<bool>('isFloating') ?? true;
      } on MissingPluginException {
        // An earlier iOS 26 build already used the floating native tab bar.
      } on PlatformException {
        // Preserve the existing floating native behavior if the style query
        // is unavailable in an older installed native shell.
      }

      if (!mounted) return;
      usesClassicNativeTabBarForLayout.value = !isFloatingNativeTabBar;
      setState(() => _usesNativeTabBar = true);
      if (_usesNativeTabBar) {
        await _nativeTabBarChannel.invokeMethod<void>(
          'setSelectedIndex',
          _selectedIndex,
        );
        final isDcvAccentActive =
            _selectedIndex == 2 &&
            _dcvSlideController.value >= _dcvColorSnapThreshold;
        _syncNativeTabBarColors(
          isDcvAccentActive && _dcvColor != null
              ? _dcvColor!
              : resolveAccentColor(context),
          CupertinoDynamicColor.resolve(kTabBarInactiveColor, context),
        );
      }
    } on MissingPluginException {
      // Older app builds can still fall back to the Flutter tab pill.
    } on PlatformException {
      // Keep the Flutter tab bar if the native bridge is unavailable.
    }
  }

  void _syncNativeTabBarColors(Color activeColor, Color inactiveColor) {
    if (!_usesNativeTabBar) return;
    final activeArgb = activeColor.toARGB32();
    final inactiveArgb = inactiveColor.toARGB32();
    if (_lastNativeActiveTabBarColorArgb == activeArgb &&
        _lastNativeInactiveTabBarColorArgb == inactiveArgb) {
      return;
    }
    _lastNativeActiveTabBarColorArgb = activeArgb;
    _lastNativeInactiveTabBarColorArgb = inactiveArgb;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_usesNativeTabBar ||
          _lastNativeActiveTabBarColorArgb != activeArgb ||
          _lastNativeInactiveTabBarColorArgb != inactiveArgb) {
        return;
      }
      unawaited(_sendNativeTabBarColors(activeArgb, inactiveArgb));
    });
  }

  Future<void> _sendNativeTabBarColors(int activeArgb, int inactiveArgb) async {
    try {
      await _nativeTabBarChannel.invokeMethod<void>('setTabBarColors', {
        'active': activeArgb,
        'inactive': inactiveArgb,
      });
    } on MissingPluginException {
      // Older installed native shells can keep their system-default tint.
    } on PlatformException {
      // Native tab styling must not prevent the Flutter app from working.
    }
  }

  String get _headerTitle {
    final dcv = _selectedIndex == 2 ? _dcvCategory : null;
    if (dcv != null) return dcv;
    switch (_selectedIndex) {
      case 0:
        return 'All Notes';
      case 1:
        return _calendarTitle.isEmpty
            ? _formattedCalendarMonthTitle(
                _monthNames[DateTime.now().month - 1],
              )
            : _formattedCalendarMonthTitle(_calendarTitle);
      case 2:
        return 'All Events';
      case 3:
        return 'You';
      default:
        return '';
    }
  }

  bool get _calendarTitleOwnedByScrollContent =>
      _calendarTabKey.currentState?.calendarTitleInScrollContent ??
      _calendarTitleInScrollContent;

  // The tab's own title without any DCV override — used by the fade-out layer
  // in the header so it stays correct while the DCV title fades in.
  String get _nonDCVHeaderTitle {
    switch (_selectedIndex) {
      case 0:
        return 'All Notes';
      case 1:
        return _calendarTitle.isEmpty
            ? _formattedCalendarMonthTitle(
                _monthNames[DateTime.now().month - 1],
              )
            : _formattedCalendarMonthTitle(_calendarTitle);
      case 2:
        return 'All Events';
      case 3:
        return 'You';
      default:
        return '';
    }
  }

  Widget _buildLargeHeaderTitle({
    required bool isDCVVisual,
    required Color headerColor,
    required Color primaryLabel,
  }) {
    if (!isDCVVisual && _selectedIndex == 1) {
      if (_calendarTitleOwnedByScrollContent) return const SizedBox.shrink();
      // Use the same complete slot as the scroll-owned title. In particular,
      // keep the bottom inset inside this fixed-height slot; the header parent
      // must not position the title by aligning it inside its taller toolbar
      // plus title region.
      return _buildCalendarTitleSlot(
        child: _buildCalendarTitleRow(compactFadeColor: headerColor),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: HeaderTitleScroller(
        title: isDCVVisual ? (_dcvCategory ?? '') : _nonDCVHeaderTitle,
        fadeColor: headerColor,
        style: TextStyle(
          fontFamily: kSFProText,
          fontSize: 34,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.normal,
          color: primaryLabel,
          letterSpacing: -1.2,
        ),
      ),
    );
  }

  // ── Calendar-tab header row (title + ↕ + < >) ────────────────────────────
  // Portrait keeps the three-panel title transition. Compact landscape keeps
  // the complete, rubberbandable control group stationary and switches its
  // period at the horizontal content slide's midpoint.
  Widget _buildCalendarTitleRow({
    bool compact = false,
    Color? compactFadeColor,
  }) {
    Widget buildPanel(String title, {required bool isActive}) =>
        _buildCalendarTitlePanel(
          context: context,
          title: title,
          displayYear: _calendarDisplayYear,
          view: _calendarView,
          isActive: isActive,
          compact: compact,
          compactFadeColor: compactFadeColor,
          titleTextKey:
              isActive && !compact && !_calendarTitleOwnedByScrollContent
              ? _calendarTabKey.currentState?.yearMonthMorphHeaderTitleKey
              : null,
        );

    return ValueListenableBuilder<double>(
      valueListenable: _calendarStripSlide,
      builder: (context, slideX, _) {
        if (compact) {
          final physicalWidth = AppWindowContentScope.of(context).physicalWidth;
          final title = physicalWidth > 0 && slideX.abs() >= physicalWidth * 0.5
              ? (slideX > 0 ? _calendarPrevTitle : _calendarNextTitle)
              : _calendarTitle;
          // Keep the complete title-and-chevron group stationary during the
          // content slide. It snaps to the incoming period at exactly halfway.
          return buildPanel(title, isActive: true);
        }

        final sw = MediaQuery.of(context).size.width;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(slideX - sw, 0),
                child: IgnorePointer(
                  child: buildPanel(_calendarPrevTitle, isActive: false),
                ),
              ),
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(slideX, 0),
                child: buildPanel(_calendarTitle, isActive: true),
              ),
            ),
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(slideX + sw, 0),
                child: IgnorePointer(
                  child: buildPanel(_calendarNextTitle, isActive: false),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// The fixed second-level Calendar title geometry shared by the shell and
  /// the scroll-content owner. The slot begins immediately below the toolbar;
  /// its bottom inset is part of the 57px slot, not part of its parent.
  Widget _buildCalendarTitleSlot({required Widget child}) {
    return SizedBox(
      height: kAppHeaderTitleHeight,
      child: AppWindowContentPadding(
        child: Padding(
          padding: const EdgeInsets.only(
            left: 16,
            right: 16,
            bottom: kHeaderTitleBottomInset,
          ),
          child: Align(
            alignment: Alignment.bottomLeft,
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );
  }

  Widget _buildCalendarTitlePanel({
    required BuildContext context,
    required String title,
    required int displayYear,
    required CalendarView view,
    required bool isActive,
    bool compact = false,
    Color? compactFadeColor,
    GlobalKey? titleTextKey,
  }) {
    final activeView = isActive
        ? (_calendarTabKey.currentState?.view ?? view)
        : view;
    final canUp = activeView != CalendarView.day;
    final canDown = activeView != CalendarView.year;
    final hierarchyNavigationReady =
        !isActive ||
        (_calendarTabKey.currentState?.canNavigateHierarchy ?? true);
    final canShowActiveHierarchyNavigation =
        !isActive || hierarchyNavigationReady;
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    const compactArrowWidth = 40.0;
    const compactTrailingControlsWidth = compactArrowWidth + 24.0;
    final compactToolbarHeight =
        MediaQuery.orientationOf(context) == Orientation.landscape
        ? kAppHeaderLandscapeToolbarHeight
        : kAppHeaderToolbarHeight;
    final displayTitle = _formattedCalendarMonthTitle(title);
    final isToday = _isTodayTitle(displayTitle, displayYear);
    final titleStyle = TextStyle(
      fontFamily: kSFProText,
      fontSize: compact ? 17 : 34,
      fontWeight: compact ? FontWeight.w600 : FontWeight.bold,
      fontStyle: FontStyle.normal,
      color: isToday ? resolveAccentColor(context) : primaryLabel,
      letterSpacing: compact ? -0.6 : -1.2,
    );
    // Keep controls painted on the adjacent title panels so they travel with
    // the incoming/outgoing screen instead of disappearing during the slide.
    // Their callbacks are already null on inactive panels; this also protects
    // the whole control from receiving input while it is only a preview.
    Widget panelControl(Widget child) =>
        IgnorePointer(ignoring: !isActive, child: child);

    Widget compactArrow({
      required _ChevronDir direction,
      required VoidCallback? onTap,
    }) {
      return SizedBox(
        key: ValueKey('calendar-compact-period-${direction.name}'),
        width: compactArrowWidth,
        height: compactToolbarHeight,
        child: Center(
          child: SizedBox(
            width: compactArrowWidth,
            height: 40,
            child: _CalendarNavTapTarget(
              // AnimatedTapIcon handles pointer input without a gesture
              // recognizer. This no-op tap target prevents the surrounding
              // title tap from also firing (which would return Day View to
              // Month View when a landscape day-navigation chevron is tapped).
              onTapAt: null,
              child: AnimatedTapIcon(
                // Keep the thin chevron strokes optically stable while pressed.
                scaleEnabled: false,
                padding: const EdgeInsets.all(11),
                onTap: onTap,
                child: _ChevronIcon(
                  direction: direction,
                  color: resolveAccentColor(context),
                  size: 18,
                  strokeWidth: 1.6,
                ),
              ),
            ),
          ),
        ),
      );
    }

    final titleScroller = HeaderTitleScroller(
      title: displayTitle,
      titleTextKey: titleTextKey,
      fadeColor: compactFadeColor ?? resolveThemeColor(kCardColor, context),
      onTap: isActive && (isToday || activeView == CalendarView.day)
          ? () {
              if (isToday) {
                _advanceCurrentCalendarHeader();
              } else {
                // A non-today Day title still represents a real hierarchy
                // level. Tapping it returns to that date's containing month.
                _calendarTabKey.currentState?.navigateDown();
              }
            }
          : null,
      showTrailingFade: true,
      fadeOnlyDuringHorizontalDrag: true,
      leadingContentWidth: compact ? compactArrowWidth : null,
      leadingGap: 0,
      trailingContentWidth: compact ? compactTrailingControlsWidth : null,
      centerWhenContentFits: compact,
      contentAlignment: compact ? Alignment.centerLeft : Alignment.bottomLeft,
      // Expanded Calendar titles share a row with taller vertical chevrons;
      // center-aligning the inner text lifts its baseline above other tabs.
      contentCrossAxisAlignment: compact
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.end,
      leadingBuilder: compact
          ? (_) => compactArrow(
              direction: _ChevronDir.left,
              onTap: isActive
                  ? () => _calendarTabKey.currentState?.navigatePrev()
                  : null,
            )
          : null,
      trailingBuilder: (titleFontSize) {
        final titlePainter = TextPainter(
          text: TextSpan(
            text: displayTitle,
            style: titleStyle.copyWith(fontSize: titleFontSize),
          ),
          textDirection: Directionality.of(context),
          textScaler: TextScaler.noScaling,
          maxLines: 1,
        )..layout();
        final verticalNavigation = _CalendarNavChevron(
          titleFontSize: titleFontSize,
          titleLineHeight: titlePainter.height,
          // The preview panel should look like the same view once settled;
          // its pointer and semantic actions remain disabled until activation.
          canUp: canUp && canShowActiveHierarchyNavigation,
          canDown: canDown && canShowActiveHierarchyNavigation,
          compact: compact,
          onUp: isActive && hierarchyNavigationReady && canUp
              ? () => _calendarTabKey.currentState?.navigateUp()
              : null,
          onDown: isActive && hierarchyNavigationReady && canDown
              ? () => _calendarTabKey.currentState?.navigateDown()
              : null,
        );
        if (!compact) return panelControl(verticalNavigation);

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            verticalNavigation,
            compactArrow(
              direction: _ChevronDir.right,
              onTap: isActive
                  ? () => _calendarTabKey.currentState?.navigateNext()
                  : null,
            ),
          ],
        );
      },
      style: titleStyle,
    );

    if (compact) {
      return SizedBox.expand(child: titleScroller);
    }

    final previousArrow = AnimatedTapIcon(
      // Press opacity is retained; scaling thin strokes causes a doubled edge.
      scaleEnabled: false,
      padding: const EdgeInsets.fromLTRB(18, 12, 4, 8),
      onTap: isActive
          ? () => _calendarTabKey.currentState?.navigatePrev()
          : null,
      child: _ChevronIcon(
        direction: _ChevronDir.left,
        color: resolveAccentColor(context),
        size: 18,
        strokeWidth: 1.6,
      ),
    );
    final nextArrow = AnimatedTapIcon(
      scaleEnabled: false,
      padding: const EdgeInsets.fromLTRB(10, 12, 0, 8),
      onTap: isActive
          ? () => _calendarTabKey.currentState?.navigateNext()
          : null,
      child: _ChevronIcon(
        direction: _ChevronDir.right,
        color: resolveAccentColor(context),
        size: 18,
        strokeWidth: 1.6,
      ),
    );

    return Row(
      // Keep the title's text baseline on the same bottom edge as the
      // standard Notes/Events header title.
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(child: titleScroller),
        panelControl(previousArrow),
        panelControl(nextArrow),
      ],
    );
  }

  Widget _buildScrollableCalendarTitle(
    BuildContext context,
    String title,
    int displayYear,
    CalendarView view,
    bool isActive,
  ) {
    Widget titleContent(bool yearMonthMorphActive) => SizedBox(
      height: kAppHeaderTitleHeight,
      child: Offstage(
        // AppShell owns the title and controls throughout the Year↔Month zoom.
        // Listen to the transition state directly: cached scroll panels can
        // keep this widget alive even when CalendarTab's title builder is
        // replaced. Offstage reports zero size, so retain its 57px slot outside
        // Offstage while suppressing duplicate custom-painted chevrons.
        // Month↔Day ownership is unchanged.
        offstage: yearMonthMorphActive,
        child: _buildCalendarTitleSlot(
          child: _buildCalendarTitlePanel(
            context: context,
            title: title,
            displayYear: displayYear,
            view: view,
            isActive: isActive,
            titleTextKey:
                isActive && !yearMonthMorphActive && view != CalendarView.day
                ? _calendarTabKey.currentState?.yearMonthMorphHeaderTitleKey
                : null,
            compactFadeColor: resolveThemeColor(kBackgroundColor, context),
          ),
        ),
      ),
    );
    final calendarState = _calendarTabKey.currentState;
    if (calendarState == null) return titleContent(false);
    return ValueListenableBuilder<bool>(
      valueListenable: calendarState.calendarYearMonthMorphActiveListenable,
      builder: (context, yearMonthMorphActive, _) =>
          titleContent(yearMonthMorphActive),
    );
  }

  Widget _buildCompactHeaderTitle({
    required bool isDCVVisual,
    required Color headerColor,
    required Color primaryLabel,
  }) {
    return HeaderTitleScroller(
      title: isDCVVisual ? (_dcvCategory ?? '') : _nonDCVHeaderTitle,
      fadeColor: headerColor,
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
    );
  }

  List<navigation_glass.GlassBarItem> _buildPinnedHeaderActions({
    required Color accent,
    required double opacity,
    required bool interactionsEnabled,
    required String configurationKey,
  }) {
    final visible = opacity.clamp(0.0, 1.0).toDouble();
    final menuSliderPosition = liquidGlassSliderPositionForOpacity(
      appLiquidGlassOpacityNotifier.value,
    );
    final menuGlassSettings = skeddoNavigationGlassSettingsFromShared(
      skeddoPopoverGlassSettingsFor(
        MediaQuery.platformBrightnessOf(context),
        resolveThemeColor(kCardColor, context),
        sliderPosition: menuSliderPosition,
      ),
    );
    Widget icon(String asset) => SvgPicture.asset(
      asset,
      width: 26,
      height: 26,
      colorFilter: ColorFilter.mode(accent, BlendMode.srcIn),
    );
    Widget anchoredIcon(Widget child) =>
        SizedBox(width: 36, height: 36, child: Center(child: child));
    Widget visibleIcon(Widget child) =>
        Opacity(opacity: visible, child: child);
    Widget shiftedVisibleIcon(Widget child) => Opacity(
      opacity: visible,
      child: Transform.translate(
        offset: const Offset(-3.5, 0),
        child: child,
      ),
    );

    final actions = <navigation_glass.GlassBarItem>[];
    final searchAction = navigation_glass.GlassBarItem.icon(
      id: 'app-shell-search-action',
      label: 'Search',
      enabled: interactionsEnabled && visible > 0.01,
      background: navigation_glass.GlassBarItemBackground.shared,
      icon: visibleIcon(icon('assets/icons/search.svg')),
      onTap: _activateTabSearch,
    );
    actions.add(searchAction);

    Widget? leadingActionIcon;
    String? leadingActionId;
    String? leadingActionLabel;
    VoidCallback? leadingActionOnTap;
    List<Widget>? leadingActionMenuItems;
    var leadingActionMenuWidth = 260.0;

    if (configurationKey == 'events') {
      leadingActionId = 'app-shell-add-category-action';
      leadingActionLabel = 'Add category';
      leadingActionIcon = shiftedVisibleIcon(
        AddCategoryHeaderIcon(size: 36.8, color: accent, opacity: visible),
      );
      leadingActionOnTap = () => _eventsTabKey.currentState?.addCategory();
    } else if (configurationKey == 'events-dcv') {
      leadingActionId = 'app-shell-dcv-ellipsis-action';
      leadingActionLabel = 'Category actions';
      leadingActionIcon = shiftedVisibleIcon(
        anchoredIcon(
          SearchWeightedIcon(
            CupertinoIcons.ellipsis,
            size: 21,
            color: accent,
            weight: 0,
          ),
        ),
      );
      leadingActionMenuItems = _dcvToolbarMenuItems(accent);
      leadingActionMenuWidth = 300;
    } else if (configurationKey == 'calendar-year') {
      leadingActionId = 'app-shell-calendar-year-action';
      leadingActionLabel = 'Go to today';
      leadingActionIcon = shiftedVisibleIcon(
        _buildYearViewHeaderIcon(applyOpticalOffset: false),
      );
      leadingActionOnTap = _enterTodayCalendarDay;
    } else if (configurationKey.startsWith('calendar-month-')) {
      final mode = CalendarViewMode.values.firstWhere(
        (value) => configurationKey == 'calendar-month-${value.name}',
        orElse: () => _activeViewMode,
      );
      leadingActionId = 'app-shell-$configurationKey-action';
      leadingActionLabel = 'Calendar view options';
      leadingActionIcon = shiftedVisibleIcon(
        anchoredIcon(
          _buildViewModeHeaderIcon(mode: mode, applyOpticalOffset: false),
        ),
      );
      leadingActionMenuItems = _calendarViewModeMenuItems(accent);
    } else if (configurationKey.startsWith('calendar-day-')) {
      final mode = DayViewSubMode.values.firstWhere(
        (value) => configurationKey == 'calendar-day-${value.name}',
        orElse: () => _activeDaySubMode,
      );
      leadingActionId = 'app-shell-$configurationKey-action';
      leadingActionLabel = 'Day view options';
      leadingActionIcon = shiftedVisibleIcon(
        anchoredIcon(
          _buildDayViewModeHeaderIcon(mode: mode, applyOpticalOffset: false),
        ),
      );
      leadingActionMenuItems = _calendarDayModeMenuItems(accent);
    }

    if (leadingActionIcon != null &&
        leadingActionId != null &&
        leadingActionLabel != null) {
      if (leadingActionMenuItems != null) {
        actions.add(
          navigation_glass.GlassBarItem.menu(
            id: leadingActionId,
            label: leadingActionLabel,
            background: navigation_glass.GlassBarItemBackground.shared,
            menuSettings: menuGlassSettings,
            icon: leadingActionIcon,
            menuItems: leadingActionMenuItems,
            menuWidth: leadingActionMenuWidth,
          ),
        );
      } else if (leadingActionOnTap != null) {
        actions.add(
          navigation_glass.GlassBarItem.icon(
            id: leadingActionId,
            label: leadingActionLabel,
            enabled: interactionsEnabled && visible > 0.01,
            background: navigation_glass.GlassBarItemBackground.shared,
            icon: leadingActionIcon,
            onTap: leadingActionOnTap,
          ),
        );
      }
    }

    // Search is leftmost in two-action groups; the screen-specific action is
    // rightmost. Home and You keep Search as their only action.
    return actions;
  }

  String _toolbarDestinationKey() {
    return appShellToolbarConfigurationKey(
      // Offscreen search covers the page; it is not a new toolbar
      // destination. Keep the existing route so leaving the overlay cannot
      // replay the package's materialize/blur transition.
      searchFocused: _searchToolbarHidden.value && !_searchEnteredOffScreen,
      selectedTabIndex: _selectedIndex,
      dcvToolbarVisible: _dcvToolbarVisible,
      calendarToolbarVariant: _calendarToolbarVariant,
    );
  }

  Route<void> _toolbarStateRouteForKey(String key) {
    final isDcv = key == 'events-dcv';

    final route = appShellToolbarStateRoute(
      name: 'app-shell-toolbar-$key',
      opaque: true,
      onSystemBack: _handleToolbarRouteSystemBack,
      toolbarBuilder: key == 'search'
          ? (_) => const SizedBox.shrink()
          : (routeContext) => AnimatedBuilder(
              animation: Listenable.merge([
                appAccentNotifier,
                appAccentUsesSystemNotifier,
                appSystemAccentColorNotifier,
                appLiquidGlassOpacityNotifier,
                _dcvToolbarAccent,
                _searchToolbarInteractionsEnabled,
                _toolbarMenuRevision,
              ]),
              builder: (context, _) {
                final accent = isDcv && _dcvToolbarAccent.value != null
                    ? _dcvToolbarAccent.value!
                    : resolveAccentColor(routeContext);
                return AppShellPinnedToolbar(
                  glyph: isDcv
                      ? AppShellToolbarGlyph.back
                      : AppShellToolbarGlyph.menu,
                  semanticLabel: isDcv ? 'Back' : 'Open settings',
                  horizontalInset:
                      AppWindowContentScope.of(routeContext).horizontalInset +
                      16.0,
                  color: accent,
                  hideWhen: _searchToolbarHidden,
                  interactionsEnabled: _searchToolbarInteractionsEnabled,
                  actions: _buildPinnedHeaderActions(
                    accent: accent,
                    opacity: 1.0,
                    interactionsEnabled:
                        _searchToolbarInteractionsEnabled.value,
                    configurationKey: key,
                  ),
                  onTap: _handlePrimaryToolbarTap,
                );
              },
            ),
    );
    _toolbarStateRoutes.add(route);
    _currentToolbarStateRoute = route;
    return route;
  }

  void _syncToolbarDestination() {
    if (!mounted || _settingsOpen) return;

    final key = _toolbarDestinationKey();
    if (key == _activeToolbarRouteKey) return;

    final navigator = _appShellNavigatorKey.currentState;
    if (navigator == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _syncToolbarDestination();
      });
      return;
    }

    final route = _toolbarStateRouteForKey(key);
    _activeToolbarRouteKey = key;
    unawaited(navigator.push<void>(route));

    // Let GlassNavigationShell see both registered routes for the full
    // materialize transition. pushReplacement marks the outgoing route
    // inactive before the shell can use it as the morph source.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !navigator.mounted ||
          !identical(_currentToolbarStateRoute, route)) {
        return;
      }
      final animation = (route as TransitionRoute<void>).animation;
      if (animation == null || animation.status == AnimationStatus.completed) {
        _pruneToolbarStateRoutes(navigator, route);
        return;
      }

      void onStatusChanged(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(onStatusChanged);
        _pruneToolbarStateRoutes(navigator, route);
      }

      animation.addStatusListener(onStatusChanged);
    });
  }

  void _pruneToolbarStateRoutes(
    NavigatorState navigator,
    Route<void> currentRoute,
  ) {
    if (!mounted ||
        !navigator.mounted ||
        !identical(_currentToolbarStateRoute, currentRoute)) {
      return;
    }
    for (final route in _toolbarStateRoutes.toList()) {
      if (identical(route, currentRoute)) continue;
      if (route.isActive && identical(route.navigator, navigator)) {
        navigator.removeRoute(route);
      }
      _toolbarStateRoutes.remove(route);
    }
  }

  void _handleToolbarRouteSystemBack() {
    if (_hasBackInterceptable) {
      _handleBackGesture();
      return;
    }
    // The chrome-only route must not consume Android's normal app-exit back.
    SystemNavigator.pop();
  }

  Widget _buildLandscapeDcvPaneHeader({
    required Color accent,
    required Color headerColor,
    required Color primaryLabel,
  }) {
    return SizedBox(
      height: 52,
      child: Padding(
        // Match the full-width Events header's 8 px leading inset and 16 px
        // trailing action inset. The action slots below use the same visual
        // centers as its search and plus icons.
        padding: const EdgeInsets.only(left: 8, right: 16),
        child: AnimatedBuilder(
          animation: _dcvCategoryTransitionProgress,
          builder: (context, _) => LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final transitionProgress = _dcvCategoryTransitionProgress.value
                  .clamp(0.0, 1.0);
              final slideWidth = AppWindowContentScope.of(
                context,
              ).physicalWidth;
              final incomingOffset = _previousDcvCategory == null
                  ? 0.0
                  : slideWidth * (1.0 - transitionProgress);

              Widget headerPage({
                required String title,
                required Color pageAccent,
                required bool interactive,
              }) {
                final titleOpacity = ((width - 144.0) / 72.0)
                    .clamp(0.0, 1.0)
                    .toDouble();

                Widget headerButton({
                  Key? key,
                  required VoidCallback onTap,
                  required Widget child,
                }) {
                  return SizedBox(
                    key: key,
                    width: 36,
                    height: 52,
                    child: AnimatedTapIcon(
                      padding: EdgeInsets.zero,
                      onTap: onTap,
                      // The slot is a fixed 36×52 tap target. Center loosens
                      // the constraints for fixed-size icons so they keep
                      // their authored size instead of filling the whole slot.
                      child: Center(child: child),
                    ),
                  );
                }

                return IgnorePointer(
                  ignoring: !interactive,
                  child: Stack(
                    fit: StackFit.expand,
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        child: headerButton(
                          onTap: _exitDCV,
                          child: SearchWeightedIcon(
                            CupertinoIcons.back,
                            size: 19,
                            color: pageAccent,
                            weight: 0,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 36,
                        top: 0,
                        bottom: 0,
                        child: headerButton(
                          key: interactive ? _splitDcvEllipsisKey : null,
                          onTap: _showSplitDcvMenu,
                          child: SearchWeightedIcon(
                            CupertinoIcons.ellipsis,
                            size: 21,
                            color: pageAccent,
                            weight: 0,
                          ),
                        ),
                      ),
                      if (width > 144)
                        Positioned(
                          left: 72,
                          right: 72,
                          top: 0,
                          bottom: 0,
                          child: Opacity(
                            opacity: titleOpacity,
                            child: HeaderTitleScroller(
                              key: ValueKey('landscape-dcv-title-$title'),
                              title: title,
                              fadeColor: headerColor,
                              centerWhenContentFits: true,
                              contentAlignment: Alignment.center,
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
                    ],
                  ),
                );
              }

              return Stack(
                fit: StackFit.expand,
                // The outer reveal clip owns the viewport and extends through
                // the trailing system inset while the right pane is entering.
                // Clipping here to the content width cuts off the page during
                // that part of its slide.
                clipBehavior: Clip.none,
                children: [
                  if (_previousDcvCategory != null)
                    Positioned.fill(
                      child: headerPage(
                        title: _previousDcvCategory!,
                        pageAccent: _previousDcvColor ?? accent,
                        interactive: false,
                      ),
                    ),
                  Positioned.fill(
                    child: Transform.translate(
                      offset: Offset(incomingOffset, 0),
                      child: ColoredBox(
                        color: headerColor,
                        child: headerPage(
                          title: _dcvCategory ?? '',
                          pageAccent: accent,
                          interactive: true,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  String _formattedCalendarMonthTitle(String title) {
    if (title.contains(' ') || int.tryParse(title) != null) return title;

    final fullIndex = _monthNames.indexOf(title);
    const shortNames = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final shortIndex = shortNames.indexOf(title);
    final monthIndex = fullIndex >= 0 ? fullIndex : shortIndex;
    if (monthIndex < 0) return title;
    return appFullMonthNameNotifier.value
        ? _monthNames[monthIndex]
        : shortNames[monthIndex];
  }

  void _advanceCurrentCalendarHeader() {
    final future = _calendarTabKey.currentState?.advanceCurrentHeader();
    if (future != null) unawaited(future);
  }

  void _enterTodayCalendarDay() {
    final future = _calendarTabKey.currentState?.enterTodayDay();
    if (future != null) unawaited(future);
  }

  // Returns true when [title] matches the REAL-WORLD today period.
  // Detects title type by FORMAT rather than _calendarView so the accent colour
  // is correct during the year↔month zoom transition, when _calendarView may
  // still reflect the previous view while the title has already snapped to the
  // new one (e.g. view=month but title="2026" mid-transition).
  //
  //   4-digit integer  →  year title  (blue iff == today.year)
  //   contains space   →  day title   (blue iff it matches the active Medium
  //                                   date order for today and displayYear)
  //   otherwise        →  month title (blue iff == today's full month name AND displayYear == today.year)
  // displayYear is the year the calendar is actually showing (from _calendarDisplayYear),
  // so "June 2027" and "Jun 26, 2027" are never incorrectly highlighted.
  bool _isTodayTitle(String title, int displayYear) {
    final today = DateTime.now();
    final parsedYear = int.tryParse(title);
    if (parsedYear != null) return parsedYear == today.year;
    if (title.contains(' ')) {
      if (displayYear != today.year) return false;
      return title == formatAppDateMedium(today, includeYear: false);
    }
    if (displayYear != today.year) return false;
    return title == _monthNames[today.month - 1] ||
        title ==
            const [
              'Jan',
              'Feb',
              'Mar',
              'Apr',
              'May',
              'Jun',
              'Jul',
              'Aug',
              'Sep',
              'Oct',
              'Nov',
              'Dec',
            ][today.month - 1];
  }

  // IndexedStack keeps every tab's subtree alive so the native text-input
  // PlatformViews inside NotesTab are NOT recreated every time we leave and
  // re-enter the Notes tab. That eliminates the brief placeholder-flicker
  // (~1 frame) caused by re-instantiating UITextField / EditText whenever
  // Flutter rebuilt the tab. The hidden tabs are wrapped in Offstage by
  // IndexedStack so they don't paint or hit-test, just keep their state.
  Widget _buildContent() {
    // RepaintBoundary around each tab isolates its repaint layer from its
    // siblings. When the visible tab repaints (e.g. a search result changes)
    // the engine skips the offstage tabs entirely, and vice-versa.
    return IndexedStack(
      index: _selectedIndex,
      // Scroll views in these pages paint through their own viewport and this
      // page stack into the full-screen AppShell, where the physical viewport
      // is the only top clipping boundary.
      clipBehavior: Clip.none,
      children: [
        RepaintBoundary(
          child: NotesTab(
            key: _notesTabKey,
            onSearchFocusChanged: _setSearchFocused,
            onSearchOverlayChanged: _notifySearchOverlayChanged,
            searchModeAnimation: _searchModeAnim,
            onEditEvent: (event) => _calendarTabKey.currentState
                ?.showEditEventSheet(context, event),
          ),
        ),
        RepaintBoundary(
          child: CalendarTab(
            key: _calendarTabKey,
            initialView: _calendarView,
            daySubMode: _activeDaySubMode,
            onViewChanged:
                (view, displayYear, prev, curr, next, titleInScrollContent) {
                  final viewChanged = _calendarView != view;
                  final keepHeaderScrollPosition =
                      viewChanged &&
                      _selectedIndex == 1 &&
                      (_calendarTabKey
                              .currentState
                              ?.calendarYearMonthMorphActive ??
                          false);
                  if (mounted) {
                    setState(() {
                      _calendarView = view;
                      _calendarDisplayYear = displayYear;
                      _calendarPrevTitle = prev;
                      _calendarTitle = curr;
                      _calendarNextTitle = next;
                      _calendarTitleInScrollContent = titleInScrollContent;
                    });
                    if (viewChanged && _selectedIndex == 1) {
                      if (keepHeaderScrollPosition) {
                        // The hierarchy handoff happens halfway through the
                        // morph. Do not restore another view's saved collapse
                        // offset here: that translates the shell title while the
                        // shared elements are still moving. Carry the current
                        // header position into the new scope instead.
                        _syncHeaderScrollOffsetToParent();
                      } else {
                        _restoreHeaderScrollOffset();
                      }
                    }
                    if (_selectedIndex == 1) _syncToolbarDestination();
                  }
                },
            scrollableTitleBuilder: _buildScrollableCalendarTitle,
            onStripSlide: (x) => _calendarStripSlide.value = x,
            onSearchCancel: () => _setSearchFocused(false),
            onSearchOverlayChanged: _notifySearchOverlayChanged,
            searchModeAnimation: _searchModeAnim,
            onEditEvent: (event) => _calendarTabKey.currentState
                ?.showEditEventSheet(context, event),
            dcvSectionNamesProvider: () =>
                _eventsTabKey.currentState?.dcvCustomSectionNamesSnapshot(),
            dcvSectionEventIdsProvider: () =>
                _eventsTabKey.currentState?.dcvCustomSectionEventIdsSnapshot(),
            onDcvSectionEventIdsChanged: (label, sectionEventIds) =>
                _eventsTabKey.currentState?.updateDcvSectionEventIds(
                  label,
                  sectionEventIds,
                ),
          ),
        ),
        RepaintBoundary(
          child: EventsTab(
            key: _eventsTabKey,
            onSearchFocusChanged: _setSearchFocused,
            onSearchOverlayChanged: _notifySearchOverlayChanged,
            searchModeAnimation: _searchModeAnim,
            activeDCV: _dcvCategory,
            dcvSortBy: _dcvSortByMap[_dcvCategory] ?? 'Manual',
            dcvSortDir: _dcvSortDirMap[_dcvCategory] ?? '',
            onUtilityBecameEmpty: _exitDCV,
            // Section-enabled categories open in their initial flat manual
            // view.  Built-in date Smart Categories retain their date
            // grouping.  This is intentionally independent from the menu's
            // Live section membership is resolved by the Events tab so the
            // menu state always matches the currently visible DCV sections.
            dcvShowManualDateSections:
                !(_eventsTabKey.currentState?.isUserSmartCategoryLabel(
                      _dcvCategory,
                    ) ??
                    false) &&
                !_dcvSectionsEnabled(_dcvCategory),
            onTileTapped: (label, color) => _enterDCV(label, color),
            onActiveDCVCategoryChanged: (label, color) {
              // The category currently shown in the DCV had its color edited
              // via "Edit Category Info" — refresh the header's cached
              // accent colour immediately instead of leaving it stale until
              // the user leaves and re-enters the DCV.
              if (_dcvCategory == label && mounted) {
                setState(() => _dcvColor = color);
              }
            },
            dcvSlideController: _dcvSlideController,
            dcvSlideProgress: _dcvSlideProgress,
            dcvCategoryTransitionProgress: _dcvCategoryTransitionProgress,
            onEditEvent: (event) => _calendarTabKey.currentState
                ?.showEditEventSheet(context, event),
          ),
        ),
        const RepaintBoundary(child: SizedBox.expand()),
      ],
    );
  }

  Widget _buildFloatingTabBar() {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _dcvSlideController,
        appAccentNotifier,
        appAccentUsesSystemNotifier,
        appSystemAccentColorNotifier,
      ]),
      builder: (context, _) {
        final pageP = _dcvSlideController.value.clamp(0.0, 1.0);
        final isDCVVisual =
            pageP >= _dcvColorSnapThreshold && _selectedIndex == 2;
        final eventsAccent = isDCVVisual
            ? (_dcvColor ?? resolveAccentColor(context))
            : resolveAccentColor(context);
        _syncNativeTabBarColors(
          _selectedIndex == 2 ? eventsAccent : resolveAccentColor(context),
          CupertinoDynamicColor.resolve(kTabBarInactiveColor, context),
        );
        return Positioned.fill(
          child: AppWindowContentPadding(
            child: _usesNativeTabBar
                ? const SizedBox.shrink()
                : FloatingTabPill(
                    key: _floatingTabPillKey,
                    selectedIndex: _selectedIndex,
                    eventsAccent: eventsAccent,
                    onTabSelected: _switchTab,
                    onCreateEvent: () =>
                        _calendarTabKey.currentState?.showNewEventSheet(
                          context,
                          initialCategoryId: _selectedIndex == 2
                              ? _eventsTabKey
                                    .currentState
                                    ?.activeStandardDcvCategoryId
                              : null,
                        ),
                  ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final topInset = MediaQuery.of(context).padding.top;
    final headerContentHeight = isLandscape
        ? kAppHeaderLandscapeToolbarHeight
        : 101.0;
    final headerToolbarHeight = isLandscape
        ? headerContentHeight
        : kAppHeaderToolbarHeight;
    final searchChromeTravel =
        topInset +
        headerToolbarHeight +
        (isLandscape ? 0.0 : kAppHeaderTitleHeight) +
        8.0;
    final keyboardBottomInset = MediaQuery.of(context).viewInsets.bottom;
    final backgroundColor = resolveThemeColor(kBackgroundColor, context);
    final headerSurfaceColor = isLandscape
        ? backgroundColor
        : const Color(0x00000000);
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    // AppShell uses a custom Stack instead of Scaffold, so the framework does
    // not automatically shrink the content viewport when the IME appears.
    // Reserve keyboard space while editing a DCV section; otherwise
    // ensureVisible measures against the full screen and the keyboard can
    // still cover the active New Section field. DCV search results handle
    // their own keyboard-safe viewport, so do not apply that inset twice.
    final dcvKeyboardBottomInset = dcvKeyboardContentBottomInset(
      hasActiveDcv: _selectedIndex == 2 && _dcvCategory != null,
      searchFocused: _searchFocused,
      keyboardBottomInset: keyboardBottomInset,
    );

    // TapRegionSurface provides the registry that TapRegion widgets in the
    // tree (around each NativeTextInput) need so that tap-outside-to-dismiss
    // works. Importantly, TapRegion uses raw pointer event listeners — it
    // does NOT enter the Flutter gesture arena, so it never competes with
    // the inner AnimatedTapIcon / Save Event GestureDetectors. That means
    // press-state micro-interactions on icons & buttons play immediately on
    // pointer down (a competing outer GestureDetector would delay onTapDown
    // until arena resolution at pointer up, killing the animation).
    return PopScope(
      canPop: !_hasBackInterceptable,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackGesture();
      },
      child: TapRegionSurface(
        child: RoundedSheetAppShellDimmer(
          backgroundColor: backgroundColor,
          child: AppShellNavigationScope(
            navigatorKey: _appShellNavigatorKey,
            routeRevision: _appShellRouteRevision,
            child: Stack(
              fit: StackFit.expand,
              clipBehavior: Clip.none,
              children: [
                AnimatedBuilder(
                  animation: _searchToolbarSlideProgress,
                  builder: (context, child) {
                    final offset =
                        searchChromeTravel * _searchToolbarSlideProgress.value;
                    return Transform.translate(
                      key: const ValueKey<String>(
                        'app-shell-search-toolbar-offset',
                      ),
                      offset: Offset(0, -offset),
                      transformHitTests: false,
                      child: child,
                    );
                  },
                  child: navigation_glass.GlassNavigationShell(
                    effectTransition:
                        navigation_glass.GlassEffectTransition.materialize,
                    child: AnimatedBuilder(
                      animation: _searchToolbarSlideProgress,
                      builder: (context, child) {
                        final offset =
                            searchChromeTravel *
                            _searchToolbarSlideProgress.value;
                        return Transform.translate(
                          offset: Offset(0, offset),
                          transformHitTests: false,
                          child: child,
                        );
                      },
                      child: Stack(
                        children: [
                          Stack(
                            fit: StackFit.expand,
                            children: [
                              // Header + Content share a Stack so the scrolling glass edge
                              // paints above content without changing the page's scroll layout.
                              // Previously the header was a Column sibling above the content;
                              // Column paints children in order, so the content layer painted
                              // over the header's shadow and made it invisible. Now the content
                              // is the first (bottom) Stack child and the header is the last
                              // (top) Stack child — guaranteeing the shadow/hairline are always
                              // rendered above whatever the scroll view draws.
                              Positioned.fill(
                                child: NotificationListener<ScrollMetricsNotification>(
                                  onNotification:
                                      _onHeaderScrollMetricsNotification,
                                  child: NotificationListener<ScrollNotification>(
                                    onNotification: _onHeaderScrollNotification,
                                    child: Stack(
                                      children: [
                                        // Content — fills the full Stack area but gets an animated
                                        // top-padding equal to the current header height so the
                                        // scroll view's content starts below the header, exactly
                                        // as it did when the header was a Column sibling.
                                        AnimatedBuilder(
                                          animation: _searchModeAnim,
                                          builder: (context, child) {
                                            final t = _searchModeAnim.value
                                                .clamp(0.0, 1.0);
                                            final leadingInset =
                                                topInset +
                                                headerToolbarHeight * (1 - t);
                                            return AppHeaderScrollInsetScope(
                                              leadingInset: leadingInset,
                                              titleTransition:
                                                  _headerTitleTransition,
                                              titleCollapseExtent: isLandscape
                                                  ? 0.0
                                                  : kAppHeaderTitleCollapseDistance,
                                              child: Padding(
                                                padding: EdgeInsets.only(
                                                  top: leadingInset,
                                                  bottom:
                                                      dcvKeyboardBottomInset,
                                                ),
                                                child: child,
                                              ),
                                            );
                                          },
                                          child: _buildContent(),
                                        ),

                                        // Header — last Stack child so it paints above the content.
                                        // While the search bar is focused the header collapses to
                                        // just the status-bar inset (icons row + title slide off
                                        // screen) and the border + shadow fade out so the surface
                                        // reads as continuous.
                                        Positioned(
                                          top: 0,
                                          left: 0,
                                          right: 0,
                                          child: IgnorePointer(
                                            ignoring: _searchEnteredOffScreen,
                                            child: Opacity(
                                              opacity: _searchEnteredOffScreen
                                                  ? 0.0
                                                  : 1.0,
                                              child: AnimatedBuilder(
                                                // Both _searchModeAnim and _dcvSlideController are
                                                // AnimationControllers owned by AppShell.  EventsTab's
                                                // SlideTransitions also listen to _dcvSlideController —
                                                // same object, same tick, same paint call.  Flutter
                                                // guarantees zero lag between header and content on
                                                // Impeller/Skia, eliminating the 1-frame flicker.
                                                animation: Listenable.merge([
                                                  _searchModeAnim,
                                                  _searchToolbarSlideProgress,
                                                  _dcvSlideProgress,
                                                  _dcvCategoryTransitionProgress,
                                                  _headerTitleTransition,
                                                ]),
                                                builder: (context, _) {
                                                  final t = _searchModeAnim
                                                      .value
                                                      .clamp(0.0, 1.0);
                                                  final searchHeaderExitOffset =
                                                      searchChromeTravel *
                                                      _searchToolbarSlideProgress
                                                          .value;
                                                  final pageP =
                                                      _dcvSlideController.value
                                                          .clamp(0.0, 1.0);
                                                  // Midpoint snap: header shows DCV state once the slide
                                                  // passes 50 % in either direction.  Because pageP comes
                                                  // from the same controller tick as the SlideTransition,
                                                  // the snap and the content cross exactly the same frame.
                                                  final isDCVVisual =
                                                      pageP >=
                                                          _dcvColorSnapThreshold &&
                                                      _selectedIndex == 2;
                                                  // Header icons swap to the category's own colour while
                                                  // its DCV is visible, snapping at the same 50 % pageP
                                                  // threshold as the icons themselves (see comment above).
                                                  final accent =
                                                      (isDCVVisual &&
                                                          _dcvColor != null)
                                                      ? _dcvColor!
                                                      : resolveAccentColor(
                                                          context,
                                                        );
                                                  final innerHeight =
                                                      headerToolbarHeight *
                                                      (1 - t);
                                                  final scrollOffset =
                                                      _headerTitleTransition
                                                          .contentOffset;
                                                  final collapseProgress =
                                                      _headerTitleTransition
                                                          .collapseProgress;
                                                  final titleCollapseProgress =
                                                      collapseProgress *
                                                      (1 - t);
                                                  final titleScrollOffset =
                                                      AppHeaderScrollBehavior.shellLargeTitleTravelOffset(
                                                        scrollOffset,
                                                      );
                                                  final largeTitleFadeProgress =
                                                      AppHeaderScrollBehavior.packageLargeTitleFadeProgress(
                                                        collapseProgress,
                                                      );
                                                  final compactTitleFadeProgress =
                                                      AppHeaderScrollBehavior.packageCompactTitleFadeProgress(
                                                        collapseProgress,
                                                      );
                                                  final edgeProgress =
                                                      AppHeaderScrollBehavior.scrollEdgeProgress(
                                                        scrollOffset,
                                                      ) *
                                                      (1 - t);
                                                  final calendarTitleInContent =
                                                      !isDCVVisual &&
                                                      _selectedIndex == 1 &&
                                                      _calendarTitleOwnedByScrollContent;
                                                  // Search overlays begin at the shell's current
                                                  // content inset. In portrait the normal header
                                                  // surface is transparent, which lets scrolled
                                                  // page content bleed through the status-bar band.
                                                  // Switch directly to the opaque search surface
                                                  // while search is active; interpolating from
                                                  // transparent tints the moving page underneath
                                                  // and creates a transient grey band.
                                                  final headerColor =
                                                      _searchFocused
                                                      ? backgroundColor
                                                      : headerSurfaceColor;
                                                  final headerBaseHeight =
                                                      topInset + innerHeight;
                                                  final expandedTitleDownshift =
                                                      appHeaderExpandedTitleDownshiftForProgress(
                                                        titleCollapseProgress,
                                                      );
                                                  final shellTitleHitTestHeight =
                                                      !isLandscape &&
                                                          !calendarTitleInContent
                                                      ? (kAppHeaderTitleHeight +
                                                                kAppHeaderExpandedTitleDownshift) *
                                                            (1 - t)
                                                      : 0.0;
                                                  final headerBackgroundColor =
                                                      headerColor.withValues(
                                                        alpha:
                                                            (1.0 -
                                                                titleCollapseProgress) *
                                                            headerColor.a,
                                                      );
                                                  final calendarShellTitle =
                                                      !isDCVVisual &&
                                                      _selectedIndex == 1;
                                                  final largeHeaderTitle =
                                                      _buildLargeHeaderTitle(
                                                        isDCVVisual:
                                                            isDCVVisual,
                                                        headerColor:
                                                            backgroundColor,
                                                        primaryLabel:
                                                            primaryLabel,
                                                      );
                                                  // Calendar's fixed slot owns its complete
                                                  // vertical geometry. Align that slot to the
                                                  // toolbar boundary instead of nesting it in the
                                                  // generic title padding, whose bottom inset is
                                                  // outside the slot and shifts the row upward.
                                                  final largeHeaderTitleLayout =
                                                      calendarShellTitle
                                                      ? Align(
                                                          alignment: Alignment
                                                              .bottomLeft,
                                                          child:
                                                              largeHeaderTitle,
                                                        )
                                                      : AppWindowContentPadding(
                                                          child: Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  left: 16,
                                                                  right: 16,
                                                                  bottom:
                                                                      kHeaderTitleBottomInset,
                                                                ),
                                                            child: Align(
                                                              alignment: Alignment
                                                                  .bottomLeft,
                                                              child:
                                                                  largeHeaderTitle,
                                                            ),
                                                          ),
                                                        );
                                                  return SizedBox(
                                                    width: double.infinity,
                                                    height:
                                                        headerBaseHeight +
                                                        shellTitleHitTestHeight,
                                                    child: Stack(
                                                      clipBehavior: Clip.none,
                                                      children: [
                                                        // The large shell-owned title is painted
                                                        // below the toolbar. Keep its hit-test area
                                                        // inside this Stack while leaving the
                                                        // header surface at its original height.
                                                        Positioned(
                                                          top: 0,
                                                          left: 0,
                                                          right: 0,
                                                          height:
                                                              headerBaseHeight,
                                                          child: DecoratedBox(
                                                            decoration:
                                                                BoxDecoration(
                                                                  color:
                                                                      headerBackgroundColor,
                                                                ),
                                                          ),
                                                        ),
                                                        if (!isLandscape &&
                                                            !calendarTitleInContent)
                                                          Positioned(
                                                            top: topInset,
                                                            left: 0,
                                                            right: 0,
                                                            height:
                                                                headerToolbarHeight +
                                                                kAppHeaderTitleHeight +
                                                                expandedTitleDownshift,
                                                            child: Transform.translate(
                                                              offset: Offset(
                                                                0,
                                                                -titleScrollOffset -
                                                                    searchHeaderExitOffset,
                                                              ),
                                                              child: FadeTransition(
                                                                opacity:
                                                                    _searchModeContentOpacity,
                                                                child: Container(
                                                                  color: headerSurfaceColor.withValues(
                                                                    alpha:
                                                                        (1.0 -
                                                                            titleCollapseProgress) *
                                                                        headerSurfaceColor
                                                                            .a,
                                                                  ),
                                                                  child: AppHeaderLargeTitleHandoff(
                                                                    progress:
                                                                        largeTitleFadeProgress,
                                                                    expandedDownshift:
                                                                        expandedTitleDownshift,
                                                                    child:
                                                                        largeHeaderTitleLayout,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                        if (!isLandscape)
                                                          AppHeaderScrollEdge(
                                                            progress:
                                                                edgeProgress,
                                                            surfaceColor:
                                                                backgroundColor,
                                                            headerHeight:
                                                                headerBaseHeight,
                                                            backgroundGradientHeight:
                                                                topInset +
                                                                headerToolbarHeight *
                                                                    (1 - t),
                                                          ),
                                                        AppWindowContentPadding(
                                                          child: LayoutBuilder(
                                                            builder:
                                                                (
                                                                  context,
                                                                  constraints,
                                                                ) {
                                                                  final leftHeaderWidth =
                                                                      constraints
                                                                          .maxWidth;
                                                                  final headerRowWidth =
                                                                      constraints
                                                                          .maxWidth;
                                                                  final headerRow = Row(
                                                                    children: [
                                                                      SizedBox(
                                                                        width:
                                                                            leftHeaderWidth,
                                                                        child: ClipRect(
                                                                          child: OverflowBox(
                                                                            alignment:
                                                                                Alignment.topLeft,
                                                                            minHeight:
                                                                                0,
                                                                            maxHeight:
                                                                                topInset +
                                                                                headerToolbarHeight,
                                                                            child: SizedBox(
                                                                              height:
                                                                                  topInset +
                                                                                  headerToolbarHeight,
                                                                              child: Padding(
                                                                                padding: EdgeInsets.only(
                                                                                  top: topInset,
                                                                                ),
                                                                                child: Transform.translate(
                                                                                  key:
                                                                                      const ValueKey<
                                                                                        String
                                                                                      >(
                                                                                        'app-shell-search-header-offset',
                                                                                      ),
                                                                                  offset: Offset(
                                                                                    0,
                                                                                    -searchHeaderExitOffset,
                                                                                  ),
                                                                                  child: FadeTransition(
                                                                                    opacity: _searchModeContentOpacity,
                                                                                    child: Column(
                                                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                                                      children: [
                                                                                        SizedBox(
                                                                                          height: isLandscape
                                                                                              ? 52
                                                                                              : 44,
                                                                                          child: Stack(
                                                                                            fit: StackFit.expand,
                                                                                            children: [
                                                                                              Padding(
                                                                                                padding: EdgeInsets.only(
                                                                                                  left: 6,
                                                                                                  right: 16,
                                                                                                  bottom: isLandscape
                                                                                                      ? 0
                                                                                                      : 6,
                                                                                                ),
                                                                                                child: Row(
                                                                                                  crossAxisAlignment: isLandscape
                                                                                                      ? CrossAxisAlignment.center
                                                                                                      : CrossAxisAlignment.end,
                                                                                                  children: [
                                                                                                    // Hamburger / X is lifted to the root Stack so it
                                                                                                    // always paints above the scrim and settings panel.
                                                                                                    // This SizedBox preserves the Row's layout exactly.
                                                                                                    const SizedBox(
                                                                                                      width: 36,
                                                                                                      height: 38,
                                                                                                    ),
                                                                                                    // Keep this former secondary-action slot empty so the
                                                                                                    // centered title retains its established geometry. These
                                                                                                    // actions now live in the pinned trailing toolbar.
                                                                                                    SizedBox(
                                                                                                      width: 36,
                                                                                                      height: isLandscape
                                                                                                          ? 52
                                                                                                          : 38,
                                                                                                      child: IgnorePointer(
                                                                                                        ignoring: true,
                                                                                                        child: Opacity(
                                                                                                          opacity: 0,
                                                                                                          child: Stack(
                                                                                                            clipBehavior: Clip.none,
                                                                                                            children: [
                                                                                                              // ── Ellipsis (DCV) ─────────────────────────────────
                                                                                                              // Landscape uses a full-height centered slot; portrait
                                                                                                              // retains the previous bottom-aligned placement.
                                                                                                              Opacity(
                                                                                                                opacity: isDCVVisual
                                                                                                                    ? 1.0
                                                                                                                    : 0.0,
                                                                                                                child: IgnorePointer(
                                                                                                                  ignoring: !isDCVVisual,
                                                                                                                  child: AnimatedOpacity(
                                                                                                                    opacity: _dcvMenuOpen
                                                                                                                        ? 0.45
                                                                                                                        : 1.0,
                                                                                                                    duration: const Duration(
                                                                                                                      milliseconds: 150,
                                                                                                                    ),
                                                                                                                    curve: Curves.easeInOut,
                                                                                                                    child: Align(
                                                                                                                      alignment: isLandscape
                                                                                                                          ? Alignment.centerLeft
                                                                                                                          : Alignment.bottomLeft,
                                                                                                                      child: SizedBox(
                                                                                                                        key: _ellipsisKey,
                                                                                                                        child: AnimatedTapIcon(
                                                                                                                          scaleEnabled: false,
                                                                                                                          // Center the full tap target in the landscape
                                                                                                                          // header; keep portrait placement unchanged.
                                                                                                                          padding: EdgeInsets.fromLTRB(
                                                                                                                            0,
                                                                                                                            10,
                                                                                                                            4,
                                                                                                                            isLandscape
                                                                                                                                ? 10
                                                                                                                                : 0,
                                                                                                                          ),
                                                                                                                          onTap: () => _showDcvMenuAt(
                                                                                                                            _ellipsisKey,
                                                                                                                          ),
                                                                                                                          child: Transform.translate(
                                                                                                                            offset: Offset(
                                                                                                                              11.5,
                                                                                                                              isLandscape
                                                                                                                                  ? -0.5
                                                                                                                                  : -3,
                                                                                                                            ),
                                                                                                                            child: SearchWeightedIcon(
                                                                                                                              CupertinoIcons.ellipsis,
                                                                                                                              size: 21,
                                                                                                                              color: accent,
                                                                                                                              weight: 0.0,
                                                                                                                            ),
                                                                                                                          ),
                                                                                                                        ),
                                                                                                                      ),
                                                                                                                    ),
                                                                                                                  ),
                                                                                                                ),
                                                                                                              ),
                                                                                                              // ── Today shortcut (Calendar → Year) ───────────────
                                                                                                              // Shares the exact slot and alignment used by the
                                                                                                              // Month/Day view-mode icons. Year View has no view-mode
                                                                                                              // menu, so this snaps directly to today's Day View.
                                                                                                              Opacity(
                                                                                                                opacity:
                                                                                                                    (!isDCVVisual &&
                                                                                                                        _selectedIndex ==
                                                                                                                            1 &&
                                                                                                                        _calendarShowsYearTitle)
                                                                                                                    ? 1.0
                                                                                                                    : 0.0,
                                                                                                                child: IgnorePointer(
                                                                                                                  ignoring:
                                                                                                                      !(!isDCVVisual &&
                                                                                                                          _selectedIndex ==
                                                                                                                              1 &&
                                                                                                                          _calendarShowsYearTitle),
                                                                                                                  child: Align(
                                                                                                                    alignment: isLandscape
                                                                                                                        ? Alignment.centerLeft
                                                                                                                        : Alignment.bottomLeft,
                                                                                                                    child: AnimatedTapIcon(
                                                                                                                      scaleEnabled: false,
                                                                                                                      padding: EdgeInsets.fromLTRB(
                                                                                                                        8,
                                                                                                                        10,
                                                                                                                        4,
                                                                                                                        isLandscape
                                                                                                                            ? 10
                                                                                                                            : 0,
                                                                                                                      ),
                                                                                                                      onTap: _enterTodayCalendarDay,
                                                                                                                      child: _buildYearViewHeaderIcon(),
                                                                                                                    ),
                                                                                                                  ),
                                                                                                                ),
                                                                                                              ),
                                                                                                              // ── View-mode (Calendar → Month) ───────────────────
                                                                                                              // Visibility driven by _calendarShowsMonthTitle so
                                                                                                              // it syncs to the shared midpoint title handoff
                                                                                                              // during year↔month zoom, not the animation endpoint.
                                                                                                              // Landscape centers the icon in the header; portrait
                                                                                                              // keeps its established bottom alignment.
                                                                                                              // Left padding 12 shifts 2 px right of the ellipsis.
                                                                                                              Opacity(
                                                                                                                opacity:
                                                                                                                    (!isDCVVisual &&
                                                                                                                        _selectedIndex ==
                                                                                                                            1 &&
                                                                                                                        _calendarShowsMonthTitle)
                                                                                                                    ? 1.0
                                                                                                                    : 0.0,
                                                                                                                child: IgnorePointer(
                                                                                                                  ignoring:
                                                                                                                      !(!isDCVVisual &&
                                                                                                                          _selectedIndex ==
                                                                                                                              1 &&
                                                                                                                          _calendarShowsMonthTitle),
                                                                                                                  child: AnimatedOpacity(
                                                                                                                    opacity: _viewModeMenuOpen
                                                                                                                        ? 0.45
                                                                                                                        : 1.0,
                                                                                                                    duration: const Duration(
                                                                                                                      milliseconds: 150,
                                                                                                                    ),
                                                                                                                    curve: Curves.easeInOut,
                                                                                                                    child: Align(
                                                                                                                      alignment: isLandscape
                                                                                                                          ? Alignment.centerLeft
                                                                                                                          : Alignment.bottomLeft,
                                                                                                                      child: SizedBox(
                                                                                                                        key: _viewModeKey,
                                                                                                                        child: AnimatedTapIcon(
                                                                                                                          scaleEnabled: false,
                                                                                                                          padding: EdgeInsets.fromLTRB(
                                                                                                                            8,
                                                                                                                            10,
                                                                                                                            4,
                                                                                                                            isLandscape
                                                                                                                                ? 10
                                                                                                                                : 0,
                                                                                                                          ),
                                                                                                                          onTap: () => _showViewModeMenu(),
                                                                                                                          child: _buildViewModeHeaderIcon(),
                                                                                                                        ),
                                                                                                                      ),
                                                                                                                    ),
                                                                                                                  ),
                                                                                                                ),
                                                                                                              ),
                                                                                                              // ── Day-view sub-mode (Calendar → Day) ─────────────
                                                                                                              // Visible only while the header shows a day title
                                                                                                              // (format "Jun 30" — contains a space).  Shares the
                                                                                                              // same slot and alignment as the Month view-mode icon
                                                                                                              // so exactly one is visible at a time.
                                                                                                              Opacity(
                                                                                                                opacity:
                                                                                                                    (!isDCVVisual &&
                                                                                                                        _selectedIndex ==
                                                                                                                            1 &&
                                                                                                                        _calendarShowsDayTitle)
                                                                                                                    ? 1.0
                                                                                                                    : 0.0,
                                                                                                                child: IgnorePointer(
                                                                                                                  ignoring:
                                                                                                                      !(!isDCVVisual &&
                                                                                                                          _selectedIndex ==
                                                                                                                              1 &&
                                                                                                                          _calendarShowsDayTitle),
                                                                                                                  child: AnimatedOpacity(
                                                                                                                    opacity: _dayViewModeMenuOpen
                                                                                                                        ? 0.45
                                                                                                                        : 1.0,
                                                                                                                    duration: const Duration(
                                                                                                                      milliseconds: 150,
                                                                                                                    ),
                                                                                                                    curve: Curves.easeInOut,
                                                                                                                    child: Align(
                                                                                                                      alignment: isLandscape
                                                                                                                          ? Alignment.centerLeft
                                                                                                                          : Alignment.bottomLeft,
                                                                                                                      child: SizedBox(
                                                                                                                        key: _dayViewModeKey,
                                                                                                                        child: AnimatedTapIcon(
                                                                                                                          scaleEnabled: false,
                                                                                                                          padding: EdgeInsets.fromLTRB(
                                                                                                                            8,
                                                                                                                            10,
                                                                                                                            4,
                                                                                                                            isLandscape
                                                                                                                                ? 10
                                                                                                                                : 0,
                                                                                                                          ),
                                                                                                                          onTap: () => _showDayViewModeMenu(),
                                                                                                                          child: _buildDayViewModeHeaderIcon(),
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
                                                                                                    const Spacer(),
                                                                                                  ],
                                                                                                ),
                                                                                              ),
                                                                                              Positioned.fill(
                                                                                                left: 84,
                                                                                                right: 84,
                                                                                                child: Center(
                                                                                                                    child: AppHeaderCompactTitle(
                                                                                                      progress: compactTitleFadeProgress,
                                                                                                      isLandscape: isLandscape,
                                                                                                      child:
                                                                                                          !isDCVVisual &&
                                                                                                              _selectedIndex ==
                                                                                                                  1
                                                                                                          ? _buildCalendarTitleRow(
                                                                                                              compact: true,
                                                                                                              compactFadeColor: backgroundColor,
                                                                                                            )
                                                                                                          : _buildCompactHeaderTitle(
                                                                                                              isDCVVisual: isDCVVisual,
                                                                                                              headerColor: backgroundColor,
                                                                                                              primaryLabel: primaryLabel,
                                                                                                                    ),
                                                                                                  ),
                                                                                                ),
                                                                                              ),
                                                                                            ],
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
                                                                    ],
                                                                  );
                                                                  return OverflowBox(
                                                                    alignment:
                                                                        Alignment
                                                                            .topLeft,
                                                                    minWidth:
                                                                        constraints
                                                                            .maxWidth,
                                                                    maxWidth:
                                                                        headerRowWidth,
                                                                    child: SizedBox(
                                                                      width:
                                                                          headerRowWidth,
                                                                      child:
                                                                          headerRow,
                                                                    ),
                                                                  );
                                                                },
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // In normal navigation the pinned Navigator must remain above
                          // the tab bar so Settings and modal destinations cover it.
                          // Offscreen search reverses that order: its full-height results
                          // scroll under the tab bar, which remains the top interactive
                          // layer.
                          if (!_searchEnteredOffScreen || !_searchFocused)
                            _buildFloatingTabBar(),

                          // Keep tab bodies mounted while the sibling Navigator owns the
                          // toolbar destinations and Settings routes. Global modal routes
                          // use the root Navigator so they cover and dim this whole shell.
                          Positioned.fill(
                            child: IgnorePointer(
                              // Search removes all pinned toolbar chrome. Let taps pass
                              // through the full-screen toolbar Navigator to the still
                              // visible tab bar and the active search page.
                              ignoring: _searchFocused,
                              child: Navigator(
                                key: _appShellNavigatorKey,
                                observers: [_appShellNavigationObserver],
                                initialRoute: 'app-shell-toolbar-home',
                                onGenerateRoute: (settings) {
                                  const prefix = 'app-shell-toolbar-';
                                  final routeName =
                                      settings.name ?? '${prefix}home';
                                  final key = routeName.startsWith(prefix)
                                      ? routeName.substring(prefix.length)
                                      : 'home';
                                  return _toolbarStateRouteForKey(key);
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                    ), // child offset
                  ),
                ), // GlassNavigationShell / outer chrome animation
                if (_searchEnteredOffScreen && _searchFocused)
                  Positioned.fill(
                    child: ColoredBox(
                      key: const ValueKey(
                        'offscreen-search-safe-area-background',
                      ),
                      color: backgroundColor,
                      child: Padding(
                        padding: EdgeInsets.only(
                          top: MediaQuery.paddingOf(context).top,
                        ),
                        child: ValueListenableBuilder<int>(
                          valueListenable: _searchOverlayRevision,
                          builder: (context, _, __) {
                            final overlay = switch (_selectedIndex) {
                              0 =>
                                _notesTabKey.currentState
                                    ?.buildOffscreenSearchOverlay(),
                              1 =>
                                _calendarTabKey.currentState
                                    ?.buildOffscreenSearchOverlay(),
                              2 =>
                                _eventsTabKey.currentState
                                    ?.buildOffscreenSearchOverlay(),
                              // You is currently an empty destination, so its
                              // Search action presents the existing Events
                              // search experience over the unchanged You page.
                              3 =>
                                _eventsTabKey.currentState
                                    ?.buildOffscreenSearchOverlay(),
                              _ => null,
                            };
                            return overlay ?? const SizedBox.shrink();
                          },
                        ),
                      ),
                    ),
                  ),

                if (_searchEnteredOffScreen && _searchFocused)
                  _buildFloatingTabBar(),
              ],
            ),
          ), // AppShellNavigationScope
        ),
      ),
    ); // PopScope
  }
}

// ── Custom chevron icons (CustomPainter) ─────────────────────────────────────
// Using CustomPainter ensures a real stroke width that matches the search/plus
// SVG icons (stroke-width 4 in a 56×56 viewBox at 26px → ~1.86px visual).
// SFIcon font-weight changes are unreliable on the web renderer.

enum _ChevronDir { left, right, up, down }

class _ChevronIcon extends StatelessWidget {
  const _ChevronIcon({
    super.key,
    required this.direction,
    required this.color,
    this.size = 18.0,
    this.strokeWidth = 1.9,
  });

  final _ChevronDir direction;
  final Color color;
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size(size, size),
    painter: _ChevronPainter(
      direction: direction,
      color: color,
      strokeWidth: strokeWidth,
    ),
  );
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({
    required this.direction,
    required this.color,
    required this.strokeWidth,
  });

  final _ChevronDir direction;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    final w = size.width;
    final h = size.height;
    final path = Path();

    switch (direction) {
      case _ChevronDir.left:
        path.moveTo(w * 0.65, h * 0.15);
        path.lineTo(w * 0.32, h * 0.50);
        path.lineTo(w * 0.65, h * 0.85);
      case _ChevronDir.right:
        path.moveTo(w * 0.35, h * 0.15);
        path.lineTo(w * 0.68, h * 0.50);
        path.lineTo(w * 0.35, h * 0.85);
      case _ChevronDir.up:
        path.moveTo(w * 0.15, h * 0.72);
        path.lineTo(w * 0.50, h * 0.28);
        path.lineTo(w * 0.85, h * 0.72);
      case _ChevronDir.down:
        path.moveTo(w * 0.15, h * 0.28);
        path.lineTo(w * 0.50, h * 0.72);
        path.lineTo(w * 0.85, h * 0.28);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter old) =>
      old.direction != direction ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}

// ── Calendar nav chevron: two independently-tappable halves in one visual ────
// Top half  → go deeper  (Year→Month, Month→Day)
// Bottom half → go back  (Day→Month, Month→Year)
class _CalendarNavChevron extends StatelessWidget {
  const _CalendarNavChevron({
    required this.titleFontSize,
    required this.titleLineHeight,
    required this.canUp,
    required this.canDown,
    this.compact = false,
    this.onUp,
    this.onDown,
  });

  final double titleFontSize;
  final double titleLineHeight;
  final bool canUp, canDown;
  final bool compact;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    final safeTitleFontSize = titleFontSize.isFinite && titleFontSize > 0
        ? titleFontSize
        : kHeaderTitleBaseFontSize;
    final scale = safeTitleFontSize / kHeaderTitleBaseFontSize;
    final iconSize = 12.0 * scale;
    // Keep the chevron group shorter than the rendered title line. This makes
    // the title, rather than the trailing control, determine the row height at
    // every bounded text-size position and therefore preserves the shared
    // Notes baseline.
    final halfHeight = safeTitleFontSize / 2;
    final iconCenterInHalf = halfHeight * 0.6;
    final firstTop = iconCenterInHalf - iconSize / 2;
    final firstBottom = halfHeight - firstTop - iconSize;
    final secondTop = firstBottom;
    final secondBottom = firstTop;
    final disabledColor = resolveThemeColor(kSecondaryLabel, context);

    if (compact) {
      final compactIconScale = max(1.0, scale * 2.0);
      final compactIconSize = 12.0 * compactIconScale;
      // Match landscape's two-arrow spacing in both toolbar heights. The
      // arrows sit at the same fixed distance from the shared title center;
      // only the transparent tap zones change height with the toolbar.
      final compactControlHeight =
          MediaQuery.orientationOf(context) == Orientation.landscape
          ? kAppHeaderLandscapeToolbarHeight
          : kAppHeaderToolbarHeight;
      final compactHalfHeight = compactControlHeight / 2;
      final compactIconCenterOffset = safeTitleFontSize * 0.3;
      final compactIconOffset = compactHalfHeight / 2 - compactIconCenterOffset;

      Widget compactHalf({
        required _ChevronDir direction,
        required Color color,
        required VoidCallback? onTap,
      }) {
        final isUp = direction == _ChevronDir.up;
        return Positioned(
          left: 0,
          right: 0,
          top: isUp ? 0 : compactHalfHeight,
          height: compactHalfHeight,
          child: Semantics(
            button: true,
            enabled: onTap != null,
            label: isUp ? 'Go to more detail' : 'Return to calendar overview',
            onTap: onTap,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              excludeFromSemantics: true,
              // Keep a child tap recognizer even when this direction is
              // unavailable so the title's parent tap cannot fire instead.
              onTap: onTap ?? () {},
              child: IgnorePointer(
                child: Center(
                  child: Transform.translate(
                    offset: Offset(
                      0,
                      isUp ? compactIconOffset : -compactIconOffset,
                    ),
                    child: _ChevronIcon(
                      direction: direction,
                      color: color,
                      size: compactIconSize,
                      strokeWidth: 1.6 * compactIconScale,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }

      return SizedBox(
        width: 24,
        height: compactControlHeight,
        child: Stack(
          fit: StackFit.expand,
          children: [
            compactHalf(
              direction: _ChevronDir.up,
              color: canUp ? resolveAccentColor(context) : disabledColor,
              onTap: onUp,
            ),
            compactHalf(
              direction: _ChevronDir.down,
              color: canDown ? resolveAccentColor(context) : disabledColor,
              onTap: onDown,
            ),
          ],
        ),
      );
    }

    const double hitW = 48.0;
    const double hitHalfHeight = 24.0;
    const double iconLeft = 8.0;
    final overflowY = hitHalfHeight - halfHeight;
    // The title is bottom-aligned in the expanded row. Shift only the visible
    // chevrons so their center remains aligned with the title; hit zones retain
    // their authored 48px geometry.
    final titleCenterOffset = (hitHalfHeight * 2 - titleLineHeight) / 2;

    Widget half({
      required _ChevronDir direction,
      required Color color,
      required VoidCallback? onTap,
      required double top,
      required double iconTop,
    }) {
      return Positioned(
        left: 0,
        top: top,
        width: hitW,
        height: hitHalfHeight,
        child: Semantics(
          button: true,
          enabled: onTap != null,
          label: direction == _ChevronDir.up
              ? 'Go to more detail'
              : 'Return to calendar overview',
          onTap: onTap,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            excludeFromSemantics: true,
            // This child recognizer wins over the title tap underneath. A
            // no-op still consumes taps on a visibly disabled direction.
            onTap: onTap ?? () {},
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: iconLeft,
                  top: iconTop,
                  child: _ChevronIcon(
                    direction: direction,
                    color: color,
                    size: iconSize,
                    strokeWidth: 1.6 * scale,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return SizedBox(
      width: hitW,
      height: hitHalfHeight * 2,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          half(
            direction: _ChevronDir.up,
            color: canUp ? resolveAccentColor(context) : disabledColor,
            onTap: onUp,
            top: 0,
            iconTop: firstTop + overflowY + titleCenterOffset,
          ),
          half(
            direction: _ChevronDir.down,
            color: canDown ? resolveAccentColor(context) : disabledColor,
            onTap: onDown,
            top: hitHalfHeight,
            iconTop:
                halfHeight +
                secondTop +
                overflowY -
                hitHalfHeight +
                titleCenterOffset,
          ),
        ],
      ),
    );
  }
}

/// A split chevron hit target that remains reliable inside the horizontally
/// rubber-banding title scroller. The raw pointer listener tracks tap slop
/// independently of the scroll gesture arena, while the nested no-op tap
/// recognizer keeps a chevron tap from also activating the title underneath.
class _CalendarNavTapTarget extends StatefulWidget {
  const _CalendarNavTapTarget({required this.onTapAt, required this.child});

  final ValueChanged<Offset>? onTapAt;
  final Widget child;

  @override
  State<_CalendarNavTapTarget> createState() => _CalendarNavTapTargetState();
}

class _CalendarNavTapTargetState extends State<_CalendarNavTapTarget> {
  static const double _tapSlop = 18.0;
  int? _activePointer;
  Offset? _downPosition;

  void _onPointerDown(event) {
    if (_activePointer != null) return;
    _activePointer = event.pointer;
    _downPosition = event.localPosition;
  }

  void _onPointerMove(event) {
    if (event.pointer != _activePointer) return;
    final downPosition = _downPosition;
    if (downPosition == null ||
        (event.localPosition - downPosition).distance > _tapSlop) {
      _activePointer = null;
      _downPosition = null;
    }
  }

  void _onPointerUp(event) {
    if (event.pointer != _activePointer) return;
    final downPosition = _downPosition;
    _activePointer = null;
    _downPosition = null;
    if (downPosition != null) widget.onTapAt?.call(downPosition);
  }

  void _onPointerCancel(event) {
    if (event.pointer != _activePointer) return;
    _activePointer = null;
    _downPosition = null;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      // This recognizer intentionally does not invoke the action. It wins
      // over the outer title tap for a tap in the chevron's own hit area.
      onTap: () {},
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerUp,
        onPointerCancel: _onPointerCancel,
        child: widget.child,
      ),
    );
  }
}
