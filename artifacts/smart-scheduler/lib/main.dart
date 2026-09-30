import 'dart:async';
import 'dart:io';
import 'dart:math' show max, min;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:path_provider/path_provider.dart';
import 'ai/ai_services.dart';
import 'ai/event_pipeline.dart';
import 'app_theme.dart';
import 'services/event_store.dart';
import 'services/local_storage.dart';
import 'tabs/calendar_tab.dart';
import 'tabs/events_tab.dart';
import 'tabs/notes_tab.dart';
import 'widgets/action_panel.dart';
import 'widgets/accent_tinted_image.dart';
import 'widgets/app_window_content_boundary.dart';
import 'widgets/fixed_size_icon.dart';
import 'widgets/floating_tab_pill.dart';
import 'widgets/header_title_scroller.dart';
import 'widgets/live_rotation_geometry.dart';
import 'widgets/native_text_input.dart';
import 'widgets/search_bar_widget.dart';
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
    _sortDir =
        widget.isUtilityCategory
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

const _kUtilityDcvLabels = {
  'Archived Items',
  'Recently Deleted',
};

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
  // Wire the AI pipeline into EventStore before any events are created.
  // Initialise the AI stack (loads HNSW index + ONNX model on native).
  // On native first-launch this copies the 23 MB model file to documents;
  // subsequent launches are instant.
  // Guard against any uncaught exception from AI initialisation so a model
  // loading failure never prevents the app from starting.
  try {
    await AIServices.init().timeout(const Duration(seconds: 8));
  } catch (_) {
    // App continues without AI embeddings; keyword matching still works.
  }
  EventPipeline.instance.init();
  // Load persisted events so the initial build has the correct state.
  try {
    await EventStore.instance.loadFromStorage().timeout(
      const Duration(seconds: 3),
    );
  } catch (_) {
    // The store remains empty and will be populated by later user actions.
  }
  // Re-embed any stale events in the background (does not block the UI).
  // Events already at the current embedding version are registered into the
  // HybridMatcher from their stored HNSW vectors without a model call.
  EventPipeline.instance.scheduleBackgroundReembed(
    EventStore.instance.events.value,
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(_overlayStyle);
  runApp(const SKEDDOApp());
}

class SKEDDOApp extends StatefulWidget {
  const SKEDDOApp({super.key});

  @override
  State<SKEDDOApp> createState() => _SKEDDOAppState();
}

class _SKEDDOAppState extends State<SKEDDOApp> with WidgetsBindingObserver {
  Timer? _textScalePollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        appBrightnessNotifier,
        appTextSizeUsesSystemNotifier,
        appTextSizeIndexNotifier,
        appSystemTextScaleNotifier,
        appSkeddoTextScaleMappingNotifier,
        appCustomTextScalerNotifier,
        appAccentNotifier,
        appDateLocaleNotifier,
        appFullMonthNameNotifier,
      ]),
      builder: (context, _) {
        final brightness = appBrightnessNotifier.value;
        final followsSystemTextSize = appTextSizeUsesSystemNotifier.value;
        final customTextSizeIndex = appTextSizeIndexNotifier.value;
        final systemTextScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        // Native Android/iOS profiles are authoritative. MediaQuery is only
        // the compatibility fallback for web and older binaries without the
        // text-scale bridge; overwriting a native profile here makes the
        // System thumb point at a different stop than the rendered text.
        if (!appHasNativeTextScaleProfile &&
            appSystemTextScaleNotifier.value != systemTextScale) {
          appSystemTextScaleNotifier.value = systemTextScale;
        }
        // The selected accent swatch (strongly typed CupertinoDynamicColor).
        final accentSwatch = kAccentSwatches[appAccentNotifier.value];
        final effectiveBrightness =
            brightness ?? MediaQuery.platformBrightnessOf(context);

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

        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: dynamicOverlayStyle,
          child: CupertinoApp(
            debugShowCheckedModeBanner: false,
            theme: CupertinoThemeData(
              // null → follow platform brightness (System mode).
              // Brightness.light / .dark → override.
              brightness: brightness,
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
                data: IconTheme.of(context).copyWith(applyTextScaling: false),
                child: result,
              );
              // System mode intentionally leaves Flutter's ambient
              // MediaQuery.textScaler untouched. Only Custom mode receives
              // SKEDDO's frozen selected scaler.
              if (!followsSystemTextSize &&
                  appCustomTextScalerNotifier.value != null) {
                result = MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: appCustomTextScalerNotifier.value),
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
              // Brightness override: propagate through MediaQuery so that
              // CupertinoDynamicColor.resolve() returns the correct variant
              // everywhere, including widgets that read platformBrightness
              // rather than CupertinoTheme directly.
              if (brightness != null) {
                result = MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(platformBrightness: brightness),
                  child: result,
                );
              }
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
              return result;
            },
            home: const AppShell(),
          ),
        );
      },
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

  // Kept in AppShell so the header AnimatedBuilder rebuilds immediately when
  // the CalendarTab transitions views (via the onViewChanged callback).
  CalendarView _calendarView = CalendarView.month;
  int _calendarDisplayYear = DateTime.now().year;
  String _calendarPrevTitle = '';
  String _calendarTitle = '';
  String _calendarNextTitle = '';

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

  // Driven by CalendarTab.onStripSlide — slides the calendar header row in
  // lock-step with the week strip in Day View.  Starts and ends at 0.0.
  final _calendarStripSlide = ValueNotifier<double>(0.0);

  int _selectedIndex = 0;
  static const _nativeTabBarChannel = MethodChannel(
    'com.smartscheduler/native_tab_bar',
  );
  bool _usesNativeTabBar = false;
  bool _menuOpen = false;
  String? _dcvCategory;
  // The tapped category's own colour, captured at DCV-entry time. While DCV
  // is visible this replaces kAccentColor for the header icons and the
  // active tab indicator; cleared on exit so the app reverts to the default
  // accent blue. Categories that were never customised resolve to
  // kAccentColor already (see resolveCategorySwatch's default), so this is a
  // visual no-op for them — no separate "has been edited" check needed.
  Color? _dcvColor;

  // Drives the DCV slide: 0.0 = grid fully visible, 1.0 = DCV fully visible.
  // Owned here in AppShell so the header AnimatedBuilder and EventsTab both
  // listen to the SAME object — Flutter guarantees they rebuild and paint in
  // the exact same frame, making one-frame header/content desync physically
  // impossible on Impeller/Skia.
  late final AnimationController _dcvSlideController;

  // ── Settings panel slide animation ──────────────────────────────────────
  // One controller governs everything: panel slide, scrim fade, and the
  // hamburger→X icon morph.
  //   0.0 = panel fully off-screen to the left (Offset(-1, 0))
  //   1.0 = panel at Offset(0, 0), fully covering the app
  late final AnimationController _settingsController;
  late final Animation<Offset> _settingsPanelOffset;

  // Tracks the *intended* open state independently from the controller value.
  // Using controller.value > 0 as the `open` prop keeps it true all the way
  // to the last frame when closing, so the TweenAnimationBuilder inside
  // _MorphingMenuIcon never fires the reverse animation — the icon snaps
  // instead of morphing back.  This bool flips immediately on open/close so
  // the morph starts in sync with the panel slide in both directions.
  bool _settingsOpen = false;

  /// Non-null while a settings sub-screen is pushed.  Holds the _pop callback
  /// so the shared overlay button can act as a back-chevron (same mechanic as
  /// the DCV back button) without any GlobalKey or tight coupling.
  final ValueNotifier<VoidCallback?> _settingsBackAction = ValueNotifier(null);

  // Gesture drag tracking — used to map finger position directly to the
  // controller value so the panel follows the user's finger in real time.
  double _settingsDragStartX = 0.0;
  double _settingsDragStartValue = 1.0;

  // True when _dcvCategory is set AND we are on the Events tab.
  // Only used for LOGICAL decisions (e.g. whether _exitDCV has been called).
  // All VISUAL decisions (title, icons, tap handlers) use isDCVVisual inside
  // the header AnimatedBuilder, derived from _dcvSlideController.value.
  bool get _isDCV => _dcvCategory != null && _selectedIndex == 2;

  void _enterDCV(String label, Color color) {
    setState(() {
      _dcvCategory = label;
      _dcvColor = color;
    });
    _dcvSlideController.forward(from: 0.0);
  }

  void _exitDCV() {
    // Reverse the slide first; clear _dcvCategory only after the animation
    // completes so the DCV content stays mounted and visible while sliding out.
    _dcvSlideController
        .reverse()
        .then((_) {
          if (mounted)
            setState(() {
              _dcvCategory = null;
              _dcvColor = null;
            });
        })
        .catchError((_) {
          if (mounted)
            setState(() {
              _dcvCategory = null;
              _dcvColor = null;
            });
        });
  }

  // ── Settings panel open / close ──────────────────────────────────────────
  void _openSettings() {
    setState(() => _settingsOpen = true);
    _settingsController.forward();
  }

  void _closeSettings() {
    setState(() => _settingsOpen = false);
    _settingsBackAction.value = null; // clear any active sub-screen
    _settingsController.reverse();
  }

  // ── Settings gesture handlers ────────────────────────────────────────────
  // The panel follows the user's finger in real time.  On release, if the
  // velocity or position passes the dismiss threshold the panel exits; otherwise
  // it snaps back to fully open.
  void _onSettingsDragStart(DragStartDetails details) {
    _settingsDragStartX = details.globalPosition.dx;
    _settingsDragStartValue = _settingsController.value;
    _settingsController.stop();
  }

  void _onSettingsDragUpdate(DragUpdateDetails details) {
    final screenWidth = MediaQuery.of(context).size.width;
    final delta = details.globalPosition.dx - _settingsDragStartX;
    // Dragging right (positive delta) closes the panel (decreases value).
    final newValue = (_settingsDragStartValue - delta / screenWidth).clamp(
      0.0,
      1.0,
    );
    _settingsController.value = newValue;
  }

  void _onSettingsDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0.0;
    // Dismiss: fast rightward fling OR position past 40% of the way closed.
    if (velocity > 300 || _settingsController.value < 0.6) {
      _closeSettings();
    } else {
      _settingsController.forward();
    }
  }

  // ── DCV ellipsis context menu ────────────────────────────────────────────
  final GlobalKey _ellipsisKey = GlobalKey();
  final ValueNotifier<bool> _dcvMenuClosing = ValueNotifier(false);
  OverlayEntry? _dcvMenuOverlay;
  bool _dcvMenuOpen = false;
  // Per-category sort settings: keyed by category label, defaulting to
  // 'Manual' / '' when absent.  Each DCV maintains its own independent sort.
  final Map<String, String> _dcvSortByMap = {};
  final Map<String, String> _dcvSortDirMap = {};
  bool _dcvShowCompleted = true;
  bool _dcvViewAsList = false;

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
  DayViewSubMode _activeDaySubMode = DayViewSubMode.singleDay;

  void _showDcvMenu() {
    if (_dcvMenuOpen) return;
    final box = _ellipsisKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
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
    final initialSortBy =
        isUtilityCategory
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
    final btnRect = Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height);
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
          _exitDCV();
          if (cat != null) _eventsTabKey.currentState?.archiveCategory(cat);
         },
         onDeleteCategory: isUtilityCategory
             ? null
             : () {
          final cat = _dcvCategory;
          _exitDCV();
          if (cat != null) _eventsTabKey.currentState?.deleteCategory(cat);
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

  Widget _buildViewModeHeaderIcon() {
    final c = resolveAccentColor(context);
    final landscapeDy = MediaQuery.sizeOf(context).width >
            MediaQuery.sizeOf(context).height
        ? 1.0
        : 0.0;
    switch (_activeViewMode) {
      case CalendarViewMode.compact:
        return Transform.translate(
          offset: Offset(1.9, -1 + landscapeDy),
          child: CompactViewIcon(color: c, size: 24),
        );
      case CalendarViewMode.stacked:
        return Transform.translate(
          offset: Offset(1.9, -1 + landscapeDy),
          child: StackedViewIcon(color: c, size: 24),
        );
      case CalendarViewMode.details:
        return Transform.translate(
          offset: Offset(2.4, landscapeDy),
          child: DetailsViewIcon(color: c, size: 24),
        );
      case CalendarViewMode.list:
        return Transform.translate(
          offset: Offset(2.4, landscapeDy),
          child: ListViewIcon(color: c, size: 24),
        );
    }
  }

  Widget _buildYearViewHeaderIcon() {
    final isLandscape =
        MediaQuery.sizeOf(context).width > MediaQuery.sizeOf(context).height;
    return Transform.translate(
      // Match the Month View icon slot's optical centre.
      offset: Offset(2.2, isLandscape ? 0 : -0.5),
      child: SizedBox(
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
      ),
    );
  }

  void _showViewModeMenu() {
    if (_viewModeMenuOpen) return;
    final box = _viewModeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    _viewModeClosing.value = false;
    _viewModeMenuOpen = true;
    setState(() {});

    final current =
        _calendarTabKey.currentState?.viewMode ?? CalendarViewMode.list;
    void doSelect(CalendarViewMode mode) {
      _hideViewModeMenu();
      _calendarTabKey.currentState?.setViewMode(mode);
      setState(() => _activeViewMode = mode);
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
        buttonRect: Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height),
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

  Widget _buildDayViewModeHeaderIcon() {
    final c = resolveAccentColor(context);
    const sz = 26.0;
    final cf = ColorFilter.mode(c, BlendMode.srcIn);
    final landscapeDy = MediaQuery.sizeOf(context).width >
            MediaQuery.sizeOf(context).height
        ? 0.5
        : 0.0;
    // All icons shifted for optical alignment with the header title.
    switch (_activeDaySubMode) {
      case DayViewSubMode.singleDay:
        return Transform.translate(
          offset: Offset(2, -0.5 + landscapeDy),
          child: SvgPicture.asset(
            'assets/icons/day_view_single_day.svg',
            width: sz,
            height: sz,
            colorFilter: cf,
          ),
          // Preserved painter-based alternatives (uncomment to revert):
          // child: SingleDayViewIcon(color: c, size: sz),
        );
      case DayViewSubMode.multiDay:
        return Transform.translate(
          offset: Offset(2, -0.5 + landscapeDy),
          child: SvgPicture.asset(
            'assets/icons/day_view_multi_day.svg',
            width: sz,
            height: sz,
            colorFilter: cf,
          ),
        );
      case DayViewSubMode.list:
        return Transform.translate(
          offset: Offset(2, -0.3 + landscapeDy),
          child: SvgPicture.asset(
            'assets/icons/day_view_list.svg',
            width: sz,
            height: sz,
            colorFilter: cf,
          ),
        );
    }
  }

  void _showDayViewModeMenu() {
    if (_dayViewModeMenuOpen) return;
    final box =
        _dayViewModeKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    _dayViewModeClosing.value = false;
    _dayViewModeMenuOpen = true;
    setState(() {});

    final current = _activeDaySubMode;
    void doSelect(DayViewSubMode mode) {
      _hideDayViewModeMenu();
      setState(() => _activeDaySubMode = mode);
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
        buttonRect: Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height),
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
    _dcvSlideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _settingsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _settingsPanelOffset =
        Tween<Offset>(begin: const Offset(-1.0, 0.0), end: Offset.zero).animate(
          CurvedAnimation(parent: _settingsController, curve: Curves.easeInOut),
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
      setState(() {
        _activeViewMode = mode;
        _activeDaySubMode = subMode;
      });
    });
  }

  @override
  void dispose() {
    _nativeTabBarChannel.setMethodCallHandler(null);
    _midnightTimer?.cancel();
    _dcvSlideController.dispose();
    _searchModeController.dispose();
    _settingsController.dispose();
    _calendarStripSlide.dispose();
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
      _settingsController.value > 0 ||
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
    if (_settingsController.value > 0) {
      // If a sub-screen is active, OS back navigates to the main Settings
      // screen first.  A second OS back press (when no sub-screen) then
      // closes the panel entirely.
      if (_settingsBackAction.value != null) {
        _settingsBackAction.value!();
      } else {
        _closeSettings();
      }
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

  void _setSearchFocused(bool focused) {
    if (_searchFocused == focused) return;
    setState(() => _searchFocused = focused);
    if (focused) {
      _searchModeController.forward();
    } else {
      if (_searchEnteredOffScreen) {
        // Off-screen entry: snap header back to full size instantly so the
        // user never sees it growing — the tab's scroll position was already
        // locked at _savedScrollOffset and the lock releases the moment the
        // animation reaches dismissed (which is immediate here).
        _searchModeController.value = 0.0;
      } else {
        // Normal (visible) entry: animate the header back down.
        _searchModeController.reverse();
      }
      _searchEnteredOffScreen = false;
    }
  }

  /// Called by the header search icon.  Focuses whichever tab's search bar is
  /// active, and either animates or snaps the header depending on whether the
  /// search bar is currently visible in the viewport.
  void _activateTabSearch() {
    if (_searchFocused) return;

    // Calendar tab: always use the off-screen path so the header collapses
    // instantly and the calendar's own search overlay slides in from above.
    if (_selectedIndex == 1) {
      _searchEnteredOffScreen = true;
      _searchModeController.value = 1.0;
      setState(() => _searchFocused = true);
      _calendarTabKey.currentState?.activateSearchMode();
      return;
    }

    final scrollCtrl = _selectedIndex == 0
        ? _notesTabKey.currentState?.scrollController
        : _eventsTabKey.currentState?.scrollController;

    // In DCV the search bar lives on page 0 of the PageView and is completely
    // hidden — always force the off-screen animation path so the slide plays.
    final bool visible =
        !_isDCV &&
        (scrollCtrl == null ||
            !scrollCtrl.hasClients ||
            scrollCtrl.offset < searchBarHostRowHeight(context));

    if (!visible) {
      // Search bar is off-screen. Collapse the header immediately, then let
      // the tab animate its own off-screen transition and focus the keyboard.
      _searchEnteredOffScreen = true;
      _searchModeController.value = 1.0; // collapse header instantly
      setState(() => _searchFocused = true); // AppShell state
      if (_selectedIndex == 0) {
        _notesTabKey.currentState?.activateSearchMode();
      } else {
        _eventsTabKey.currentState?.activateSearchMode();
      }
    } else {
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
  //      deactivate() on the Notes tab state to cleanly clear the search
  //      query and reset all search-mode UI (cancel button, collapsed header).
  //      Returning to Notes always shows a clean, non-search Notes view.
  //   2. Dismiss the keyboard and any active text-input focus.
  void _switchTab(int index) {
    if (_selectedIndex == index) return;

    // Cleanly cancel search on whichever tab we're leaving.
    if (_searchFocused) {
      if (_selectedIndex == 0) _notesTabKey.currentState?.deactivate();
      if (_selectedIndex == 1) _calendarTabKey.currentState?.cancelSearch();
      if (_selectedIndex == 2) _eventsTabKey.currentState?.deactivate();
    }

    NativeTextInput.unfocusAll();
    FocusManager.instance.primaryFocus?.unfocus();
    sbResetSearchMode();

    setState(() {
      _selectedIndex = index;
      _searchFocused = false;
      // _dcvCategory intentionally NOT cleared — DCV persists when switching
      // tabs and is restored when the user returns to Events tab.
    });
    _searchModeController.value = 0;
    if (_usesNativeTabBar) {
      unawaited(
        _nativeTabBarChannel.invokeMethod<void>(
          'setSelectedIndex',
          _selectedIndex,
        ),
      );
    }
  }

  Future<void> _handleNativeTabBarCall(MethodCall call) async {
    if (call.method != 'tabSelected') return;
    final index = call.arguments is int ? call.arguments as int : null;
    if (index == null || index < 0 || index > 2 || !mounted) return;
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
            await _nativeTabBarChannel.invokeMethod<bool>('isFloating') ??
            true;
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
      }
    } on MissingPluginException {
      // Older app builds can still fall back to the Flutter tab pill.
    } on PlatformException {
      // Keep the Flutter tab bar if the native bridge is unavailable.
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
      default:
        return '';
    }
  }

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
      default:
        return '';
    }
  }

  // ── Calendar-tab header row (title + ↕ + < >) ────────────────────────────
  // The title, ↕ chevron, and < > arrows stay inside the three-panel sliding
  // Stack so the whole Calendar header group moves together on swipes.
  Widget _buildCalendarTitleRow({bool compact = false}) {
    final canUp = _calendarView != CalendarView.day;
    final canDown = _calendarView != CalendarView.year;
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);

    Widget buildPanel(String title, {required bool isActive}) {
      final displayTitle = _formattedCalendarMonthTitle(title);
      final isToday = _isTodayTitle(displayTitle, _calendarDisplayYear);
      final titleStyle = TextStyle(
        fontFamily: kSFProText,
        fontSize: compact ? 17 : 34,
        fontWeight: compact ? FontWeight.w600 : FontWeight.bold,
        fontStyle: FontStyle.normal,
        color: isToday ? resolveAccentColor(context) : primaryLabel,
        letterSpacing: compact ? -0.6 : -1.2,
      );
      final titleScroller = HeaderTitleScroller(
        title: displayTitle,
        fadeColor: resolveThemeColor(kCardColor, context),
        onTap: isActive && isToday ? _advanceCurrentCalendarHeader : null,
        // The title area ends immediately before the calendar arrows, so its
        // trailing boundary must fade instead of hard-clipping.
        showTrailingFade: true,
        trailingBuilder: (titleFontSize) => _CalendarNavChevron(
          titleFontSize: titleFontSize,
          canUp: canUp,
          canDown: canDown,
          compact: compact,
          onUp: isActive && canUp
              ? () => _calendarTabKey.currentState?.navigateUp()
              : null,
          onDown: isActive && canDown
              ? () => _calendarTabKey.currentState?.navigateDown()
              : null,
        ),
        style: titleStyle,
      );

      final previousArrow = AnimatedTapIcon(
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

      if (compact) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final availableWidth = constraints.maxWidth.isFinite
                ? constraints.maxWidth
                : MediaQuery.sizeOf(context).width;
            final titlePainter = TextPainter(
              text: TextSpan(
                text: displayTitle,
                style: titleStyle.copyWith(
                  fontSize: headerTitleFontSize(
                    context,
                    baseFontSize: titleStyle.fontSize ?? 34,
                  ),
                ),
              ),
              textDirection: Directionality.of(context),
              textScaler: TextScaler.noScaling,
              maxLines: 1,
            )..layout();
            const compactArrowWidth = 40.0;
            final maxTitleWidth = max(
              0.0,
              availableWidth - compactArrowWidth * 2,
            );
            // The landscape up/down control sits immediately beside the text,
            // instead of reserving the portrait chevron's wide hit-test slot.
            final naturalTitleWidth = titlePainter.width + 28.0;
            final titleWidth = min(maxTitleWidth, naturalTitleWidth);
            Widget compactArrow({
              required _ChevronDir direction,
              required VoidCallback? onTap,
            }) {
              return SizedBox(
                width: compactArrowWidth,
                height: 52,
                child: Center(
                  child: SizedBox(
                    width: compactArrowWidth,
                    height: 40,
                    child: AnimatedTapIcon(
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
              );
            }

            return Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  compactArrow(
                    direction: _ChevronDir.left,
                    onTap: isActive
                        ? () => _calendarTabKey.currentState?.navigatePrev()
                        : null,
                  ),
                  SizedBox(width: titleWidth, child: titleScroller),
                  compactArrow(
                    direction: _ChevronDir.right,
                    onTap: isActive
                        ? () => _calendarTabKey.currentState?.navigateNext()
                        : null,
                  ),
                ],
              ),
            );
          },
        );
      }

      return Row(
        // Keep the title's text baseline on the same bottom edge as the
        // standard Notes/Events header title.
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(child: titleScroller),
          previousArrow,
          nextArrow,
        ],
      );
    }

    return ValueListenableBuilder<double>(
      valueListenable: _calendarStripSlide,
      builder: (context, slideX, _) {
        final sw = MediaQuery.of(context).size.width;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: Transform.translate(
                offset: Offset(slideX - sw, 0),
                child: buildPanel(_calendarPrevTitle, isActive: false),
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
                child: buildPanel(_calendarNextTitle, isActive: false),
              ),
            ),
          ],
        );
      },
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
  //   contains space   →  day title   (blue iff == "MMM d" for today AND displayYear == today.year)
  //   otherwise        →  month title (blue iff == today's full month name AND displayYear == today.year)
  // displayYear is the year the calendar is actually showing (from _calendarDisplayYear),
  // so "June 2027" and "Jun 26, 2027" are never incorrectly highlighted.
  bool _isTodayTitle(String title, int displayYear) {
    final today = DateTime.now();
    final parsedYear = int.tryParse(title);
    if (parsedYear != null) return parsedYear == today.year;
    if (title.contains(' ')) {
      if (displayYear != today.year) return false;
      const s = [
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
      return title == '${s[today.month - 1]} ${today.day}';
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
      children: [
        RepaintBoundary(
          child: NotesTab(
            key: _notesTabKey,
            onSearchFocusChanged: _setSearchFocused,
            searchModeAnimation: _searchModeAnim,
            onEditEvent: (event) => _calendarTabKey.currentState
                ?.showEditEventSheet(context, event),
          ),
        ),
        RepaintBoundary(
          child: CalendarTab(
            key: _calendarTabKey,
            daySubMode: _activeDaySubMode,
            onViewChanged: (view, displayYear, prev, curr, next) {
              if (mounted)
                setState(() {
                  _calendarView = view;
                  _calendarDisplayYear = displayYear;
                  _calendarPrevTitle = prev;
                  _calendarTitle = curr;
                  _calendarNextTitle = next;
                });
            },
            onStripSlide: (x) => _calendarStripSlide.value = x,
            onSearchCancel: () => _setSearchFocused(false),
            searchModeAnimation: _searchModeAnim,
            onEditEvent: (event) => _calendarTabKey.currentState
                ?.showEditEventSheet(context, event),
            dcvSectionNamesProvider: () =>
                _eventsTabKey.currentState?.dcvCustomSectionNamesSnapshot(),
            dcvSectionEventIdsProvider: () =>
                 _eventsTabKey.currentState
                    ?.dcvCustomSectionEventIdsSnapshot(),
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
            onEditEvent: (event) => _calendarTabKey.currentState
                ?.showEditEventSheet(context, event),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final windowSize = MediaQuery.sizeOf(context);
    final isLandscape = windowSize.width > windowSize.height;
    final topInset = MediaQuery.of(context).padding.top;
    final headerContentHeight = isLandscape ? 52.0 : 101.0;
    final keyboardBottomInset = MediaQuery.of(context).viewInsets.bottom;
    final bottomInset = systemSafeAreaBottomInset(context);
    final backgroundColor = resolveThemeColor(kBackgroundColor, context);
    final cardColor = resolveThemeColor(kCardColor, context);
    final separatorColor = resolveThemeColor(kSeparatorColor, context);
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    final shadowBlack = resolveThemeColor(kShadowBlack, context);
    // AppShell uses a custom Stack instead of Scaffold, so the framework does
    // not automatically shrink the content viewport when the IME appears.
    // Reserve the keyboard's space while editing a DCV section; otherwise
    // ensureVisible measures against the full screen and the keyboard can
    // still cover the active New Section field.
    final dcvKeyboardBottomInset =
        _selectedIndex == 2 && _dcvCategory != null
            ? keyboardBottomInset
            : 0.0;

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
        child: ColoredBox(
          color: backgroundColor,
          child: Stack(
            children: [
              Stack(
                fit: StackFit.expand,
                children: [
                  // Header + Content share a Stack so the header (with its drop-shadow
                  // and hairline separator) paints on top of the scrolling content.
                  // Previously the header was a Column sibling above the content;
                  // Column paints children in order, so the content layer painted
                  // over the header's shadow and made it invisible. Now the content
                  // is the first (bottom) Stack child and the header is the last
                  // (top) Stack child — guaranteeing the shadow/hairline are always
                  // rendered above whatever the scroll view draws.
                  Positioned.fill(
                    child: Stack(
                      children: [
                        // Content — fills the full Stack area but gets an animated
                        // top-padding equal to the current header height so the
                        // scroll view's content starts below the header, exactly
                        // as it did when the header was a Column sibling.
                        AnimatedBuilder(
                          animation: _searchModeAnim,
                          builder: (context, child) {
                            final t = _searchModeAnim.value.clamp(0.0, 1.0);
                            return Padding(
                              padding: EdgeInsets.only(
                                top: topInset + headerContentHeight * (1 - t),
                                bottom: dcvKeyboardBottomInset,
                              ),
                              child: child,
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
                          child: AnimatedBuilder(
                            // Both _searchModeAnim and _dcvSlideController are
                            // AnimationControllers owned by AppShell.  EventsTab's
                            // SlideTransitions also listen to _dcvSlideController —
                            // same object, same tick, same paint call.  Flutter
                            // guarantees zero lag between header and content on
                            // Impeller/Skia, eliminating the 1-frame flicker.
                            animation: Listenable.merge([
                              _searchModeAnim,
                              _dcvSlideController,
                              _settingsController,
                            ]),
                            builder: (context, _) {
                              final t = _searchModeAnim.value.clamp(0.0, 1.0);
                              final pageP = _dcvSlideController.value.clamp(
                                0.0,
                                1.0,
                              );
                              // Midpoint snap: header shows DCV state once the slide
                              // passes 50 % in either direction.  Because pageP comes
                              // from the same controller tick as the SlideTransition,
                              // the snap and the content cross exactly the same frame.
                              final isDCVVisual =
                                  pageP >= _dcvColorSnapThreshold &&
                                  _selectedIndex == 2;
                              // Header icons swap to the category's own colour while
                              // its DCV is visible, snapping at the same 50 % pageP
                              // threshold as the icons themselves (see comment above).
                              final accent = (isDCVVisual && _dcvColor != null)
                                  ? _dcvColor!
                                  : resolveAccentColor(context);
                               final innerHeight =
                                   headerContentHeight * (1 - t);
                              final headerColor = Color.lerp(
                                cardColor,
                                backgroundColor,
                                t,
                              )!;
                              final borderAlpha = (1 - t).clamp(0.0, 1.0);
                              final shadowAlpha = (1 - t).clamp(0.0, 1.0);
                              return Container(
                                width: double.infinity,
                                height: topInset + innerHeight,
                                decoration: BoxDecoration(
                                  color: headerColor,
                                  boxShadow: shadowAlpha > 0.001
                                      ? resolveThemeShadows([
                                          BoxShadow(
                                            color: shadowBlack.withValues(
                                              alpha: 0.094 * shadowAlpha,
                                            ),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ], context)
                                      : const [],
                                ),
                                child: Stack(
                                  children: [
                                    AppWindowContentPadding(
                                      child: ClipRect(
                                      child: OverflowBox(
                                        alignment: Alignment.topLeft,
                                        minHeight: 0,
                                maxHeight: topInset + headerContentHeight,
                                        child: SizedBox(
                                          height: topInset + headerContentHeight,
                                          child: Padding(
                                            padding: EdgeInsets.only(
                                              top: topInset,
                                            ),
                                            child: FadeTransition(
                                              opacity:
                                                  _searchModeContentOpacity,
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  SizedBox(
                                                    height: isLandscape
                                                        ? 52
                                                        : 44,
                                                    child: Stack(
                                                      fit: StackFit.expand,
                                                      children: [
                                                        Padding(
                                                          padding:
                                                              EdgeInsets.only(
                                                                left: 6,
                                                                right: 16,
                                                                bottom:
                                                                    isLandscape
                                                                    ? 0
                                                                    : 6,
                                                              ),
                                                          child: Row(
                                                            crossAxisAlignment:
                                                                isLandscape
                                                                ? CrossAxisAlignment
                                                                      .center
                                                                : CrossAxisAlignment
                                                                      .end,
                                                            children: [
                                                          // Hamburger / X is lifted to the root Stack so it
                                                          // always paints above the scrim and settings panel.
                                                          // This SizedBox preserves the Row's layout exactly.
                                                          const SizedBox(
                                                            width: 36,
                                                            height: 38,
                                                          ),
                                                           // Shared slot for the mutually-exclusive secondary header
                                                           // actions. Add Category is painted as a shell overlay below
                                                           // so its transparent badge can punch through the header layer;
                                                           // this slot preserves the header's layout for the other actions.
                                                          SizedBox(
                                                            width: 36,
                                                            height: isLandscape
                                                                ? 52
                                                                : 38,
                                                            child: Stack(
                                                              clipBehavior:
                                                                  Clip.none,
                                                              children: [
                                                                // ── Ellipsis (DCV) ─────────────────────────────────
                                                                // Landscape uses a full-height centered slot; portrait
                                                                // retains the previous bottom-aligned placement.
                                                                Opacity(
                                                                  opacity:
                                                                      isDCVVisual
                                                                      ? 1.0
                                                                      : 0.0,
                                                                  child: IgnorePointer(
                                                                    ignoring:
                                                                        !isDCVVisual,
                                                                    child: AnimatedOpacity(
                                                                      opacity:
                                                                          _dcvMenuOpen
                                                                          ? 0.45
                                                                          : 1.0,
                                                                      duration: const Duration(
                                                                        milliseconds:
                                                                            150,
                                                                      ),
                                                                      curve: Curves
                                                                          .easeInOut,
                                                                      child: Align(
                                                                        alignment:
                                                                            isLandscape
                                                                            ? Alignment.centerLeft
                                                                            : Alignment.bottomLeft,
                                                                        child: SizedBox(
                                                                          key:
                                                                              _ellipsisKey,
                                                                          child: AnimatedTapIcon(
                                                                            scaleEnabled:
                                                                                false,
                                                                            // Center the full tap target in the landscape
                                                                            // header; keep portrait placement unchanged.
                                                                            padding: EdgeInsets.fromLTRB(
                                                                              0,
                                                                              10,
                                                                              4,
                                                                              isLandscape ? 10 : 0,
                                                                            ),
                                                                            onTap:
                                                                                _showDcvMenu,
                                                                            child: Transform.translate(
                                                                              offset: Offset(
                                                                                11.5,
                                                                                 isLandscape ? -0.5 : -3,
                                                                              ),
                                                                              child: SearchWeightedIcon(
                                                                                CupertinoIcons.ellipsis_circle,
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
                                                                       alignment:
                                                                            isLandscape
                                                                            ? Alignment.centerLeft
                                                                            : Alignment.bottomLeft,
                                                                       child: AnimatedTapIcon(
                                                                         scaleEnabled:
                                                                             false,
                                                                          padding: EdgeInsets.fromLTRB(
                                                                            8,
                                                                            10,
                                                                            4,
                                                                            isLandscape ? 10 : 0,
                                                                          ),
                                                                         onTap: _enterTodayCalendarDay,
                                                                         child:
                                                                             _buildYearViewHeaderIcon(),
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
                                                                      opacity:
                                                                          _viewModeMenuOpen
                                                                          ? 0.45
                                                                          : 1.0,
                                                                      duration: const Duration(
                                                                        milliseconds:
                                                                            150,
                                                                      ),
                                                                      curve: Curves
                                                                          .easeInOut,
                                                                      child: Align(
                                                                        alignment:
                                                                            isLandscape
                                                                            ? Alignment.centerLeft
                                                                            : Alignment.bottomLeft,
                                                                        child: SizedBox(
                                                                          key:
                                                                              _viewModeKey,
                                                                          child: AnimatedTapIcon(
                                                                            scaleEnabled:
                                                                                false,
                                                                            padding: EdgeInsets.fromLTRB(
                                                                              8,
                                                                              10,
                                                                              4,
                                                                              isLandscape ? 10 : 0,
                                                                            ),
                                                                            onTap:
                                                                                _showViewModeMenu,
                                                                            child:
                                                                                _buildViewModeHeaderIcon(),
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
                                                                      opacity:
                                                                          _dayViewModeMenuOpen
                                                                          ? 0.45
                                                                          : 1.0,
                                                                      duration: const Duration(
                                                                        milliseconds:
                                                                            150,
                                                                      ),
                                                                      curve: Curves
                                                                          .easeInOut,
                                                                      child: Align(
                                                                        alignment:
                                                                            isLandscape
                                                                            ? Alignment.centerLeft
                                                                            : Alignment.bottomLeft,
                                                                        child: SizedBox(
                                                                          key:
                                                                              _dayViewModeKey,
                                                                          child: AnimatedTapIcon(
                                                                            scaleEnabled:
                                                                                false,
                                                                            padding: EdgeInsets.fromLTRB(
                                                                              8,
                                                                              10,
                                                                              4,
                                                                              isLandscape ? 10 : 0,
                                                                            ),
                                                                            onTap:
                                                                                _showDayViewModeMenu,
                                                                            child:
                                                                                _buildDayViewModeHeaderIcon(),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const Spacer(),
                                                          AnimatedTapIcon(
                                                            padding: EdgeInsets.fromLTRB(
                                                              18,
                                                              10,
                                                              4,
                                                              isLandscape ? 10 : 0,
                                                            ),
                                                            onTap:
                                                                _activateTabSearch,
                                                            child: Transform.translate(
                                                              offset:
                                                                  const Offset(
                                                                    5,
                                                                    0,
                                                                  ),
                                                              child: SvgPicture.asset(
                                                                'assets/icons/search.svg',
                                                                width: 26,
                                                                height: 26,
                                                                colorFilter:
                                                                    ColorFilter.mode(
                                                                      accent,
                                                                      BlendMode
                                                                          .srcIn,
                                                                    ),
                                                              ),
                                                            ),
                                                          ),
                                                          AnimatedTapIcon(
                                                            padding: EdgeInsets.fromLTRB(
                                                              10,
                                                              10,
                                                              0,
                                                              isLandscape ? 10 : 0,
                                                            ),
                                                            onTap: () => _calendarTabKey
                                                                .currentState
                                                                ?.showNewEventSheet(
                                                                  context,
                                                                  initialCategoryId:
                                                                      isDCVVisual &&
                                                                          _selectedIndex ==
                                                                              2
                                                                      ? _eventsTabKey
                                                                            .currentState
                                                                            ?.activeStandardDcvCategoryId
                                                                      : null,
                                                                ),
                                                            child: SvgPicture.asset(
                                                              'assets/icons/plus.svg',
                                                              width: 26,
                                                              height: 26,
                                                              colorFilter:
                                                                  ColorFilter.mode(
                                                                    accent,
                                                                    BlendMode
                                                                        .srcIn,
                                                                  ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                   if (isLandscape)
                                                     Positioned.fill(
                                                       left: 84,
                                                       right: 84,
                                                       child: Center(
                                                         child:
                                                             !isDCVVisual &&
                                                                     _selectedIndex ==
                                                                         1
                                                                 ? _buildCalendarTitleRow(
                                                                     compact: true,
                                                                   )
                                                                 : _buildCompactHeaderTitle(
                                                                     isDCVVisual:
                                                                         isDCVVisual,
                                                                     headerColor:
                                                                         headerColor,
                                                                     primaryLabel:
                                                                         primaryLabel,
                                                                   ),
                                                       ),
                                                     ),
                                                 ],
                                               ),
                                             ),
                                     if (!isLandscape)
                                       Expanded(
                                         child: Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            left: 16,
                                                            right: 16,
                                                            bottom:
                                                                kHeaderTitleBottomInset,
                                                          ),
                                                      child:
                                                          !isDCVVisual &&
                                                              _selectedIndex ==
                                                                  1
                                                          ? _buildCalendarTitleRow()
                                                          : Align(
                                                              alignment: Alignment
                                                                  .bottomLeft,
                                                              // Clean snap: _isDCV switches atomically in the
                                                              // same setState that starts the slide, so both
                                                              // the title and the content change at t=0 with
                                                              // no overlap, no crossfade, no flicker.
                                                              child: isDCVVisual
                                                                  ? SizedBox(
                                                                      width: double
                                                                          .infinity,
                                                                      child: HeaderTitleScroller(
                                                                        title:
                                                                            _dcvCategory ??
                                                                            '',
                                                                        fadeColor:
                                                                            headerColor,
                                                                        style: TextStyle(
                                                                          fontFamily:
                                                                              kSFProText,
                                                                          fontSize:
                                                                              34,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontStyle:
                                                                              FontStyle.normal,
                                                                          color:
                                                                              primaryLabel,
                                                                          letterSpacing:
                                                                              -1.2,
                                                                        ),
                                                                      ),
                                                                    )
                                                                  : SizedBox(
                                                                      width: double
                                                                          .infinity,
                                                                      child: HeaderTitleScroller(
                                                                        title:
                                                                            _nonDCVHeaderTitle,
                                                                        fadeColor:
                                                                            headerColor,
                                                                        style: TextStyle(
                                                                          fontFamily:
                                                                              kSFProText,
                                                                          fontSize:
                                                                              34,
                                                                          fontWeight:
                                                                              FontWeight.bold,
                                                                          fontStyle:
                                                                              FontStyle.normal,
                                                                          color:
                                                                              primaryLabel,
                                                                          letterSpacing:
                                                                              -1.2,
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
                                      ),
                                    ),
                                    ),
                                    if (borderAlpha > 0.001)
                                      Positioned(
                                        left: 0,
                                        right: 0,
                                        bottom: 0,
                                        child: IgnorePointer(
                                          child: Opacity(
                                            opacity: borderAlpha,
                                            child: Container(
                                              height: 0.75,
                                              color: separatorColor,
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // Add Category overlay — the CustomPaint must remain on the
              // AppShell canvas.  Do not put this icon below an Opacity or
              // Transform layer: BlendMode.clear must see the header/content
              // destination to create a real hole in both themes and during a
              // sheet's scale/color-filter transition.
              AnimatedBuilder(
                animation: Listenable.merge([
                  _dcvSlideController,
                  _searchModeAnim,
                ]),
                builder: (context, _) {
                  final pageP = _dcvSlideController.value.clamp(0.0, 1.0);
                  final isDCVVisual =
                      pageP >= _dcvColorSnapThreshold && _selectedIndex == 2;
                  final opacity = !isDCVVisual && _selectedIndex == 2
                      ? (1.0 - _searchModeAnim.value).clamp(0.0, 1.0)
                      : 0.0;
                  if (opacity <= 0.0) return const SizedBox.shrink();
                  return Positioned(
                    left:
                        AppWindowContentScope.of(context).horizontalInset + 42,
                    top: topInset,
                    child: IgnorePointer(
                      ignoring: opacity < 0.01,
                      child: SizedBox(
                        width: 42,
                        height: 46,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () =>
                              _eventsTabKey.currentState?.addCategory(),
                          child: Padding(
                            // These are the old header slot's visual
                            // coordinates, expressed as layout instead of
                            // Transform/Opacity layers.
                            padding: const EdgeInsets.only(
                              left: 3.2,
                              top: 6.1,
                            ),
                            child: MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                textScaler: TextScaler.noScaling,
                              ),
                              child: AddCategoryHeaderIcon(
                                size: 36.8,
                                opacity: opacity,
                                color: resolveAccentColor(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // The tab bar is now a floating shell control. It is placed
              // above the content but below the settings scrim so it stays
              // available across tabs and is naturally covered by shell
              // overlays.
              AnimatedBuilder(
                animation: Listenable.merge([
                  _dcvSlideController,
                  appLiquidGlassOpacityNotifier,
                ]),
                builder: (context, _) {
                  final pageP = _dcvSlideController.value.clamp(0.0, 1.0);
                  final isDCVVisual =
                      pageP >= _dcvColorSnapThreshold && _selectedIndex == 2;
                  final eventsAccent = isDCVVisual
                      ? (_dcvColor ?? resolveAccentColor(context))
                      : resolveAccentColor(context);
                  return Positioned.fill(
                    child: AppWindowContentPadding(
                      child: _usesNativeTabBar
                          ? const SizedBox.shrink()
                          : FloatingTabPill(
                              selectedIndex: _selectedIndex,
                              eventsAccent: eventsAccent,
                              onTabSelected: _switchTab,
                            ),
                    ),
                  );
                },
              ),

              // Settings scrim — fades in with the settings panel and sits
              // above the floating tab bar, matching the original shell
              // behavior.  The explicit state/animation guard is important:
              // a stale non-zero controller value must never leave this
              // full-screen hit-test layer over the closed app.
              AnimatedBuilder(
                animation: _settingsController,
                builder: (context, _) {
                  final v = _settingsController.value;
                  final scrimActive =
                      _settingsOpen || _settingsController.isAnimating;
                  if (!scrimActive || v <= 0.0) {
                    return const SizedBox.shrink();
                  }
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _closeSettings,
                    child: ColoredBox(
                      color: Color.fromRGBO(0, 0, 0, 0.4 * v),
                      child: const SizedBox.expand(),
                    ),
                  );
                },
              ),

              // Settings panel — slides in from the left edge.
              //
              // Keep the panel mounted only while it is opening, open, or
              // closing.  SettingsPanel is intentionally a full-screen
              // ColoredBox inside a SlideTransition.  Leaving that full-screen
              // layer mounted at Offset(-1, 0) is harmless on iOS/Web, but
              // Android can retain the transformed composited layer and paint
              // a grey veil over the app; it can also keep winning hit tests
              // even though the panel is visually off-screen.  Offstage
              // removes both paint and hit testing once the close animation
              // has settled while preserving the panel's state.
              AnimatedBuilder(
                animation: _settingsController,
                builder: (context, _) {
                  final panelActive =
                      _settingsOpen || _settingsController.isAnimating;
                  return Offstage(
                    offstage: !panelActive,
                    child: SlideTransition(
                      position: _settingsPanelOffset,
                      child: SettingsPanel(
                        topInset: topInset,
                        bottomInset: bottomInset,
                        onClose: _closeSettings,
                        subScreenBackAction: _settingsBackAction,
                      ),
                    ),
                  );
                },
              ),

              // Hamburger → X overlay — always the topmost child so it paints
              // above the scrim and the settings panel.  Mirrors the exact
              // position, padding, and behaviour of the header slot it replaced.
              // Fades out in search mode (same as the rest of the header) and
              // becomes non-hittable when invisible so search-bar taps pass through.
              AnimatedBuilder(
                animation: Listenable.merge([
                  _settingsController,
                  _dcvSlideController,
                  _searchModeAnim,
                  _settingsBackAction,
                ]),
                builder: (context, _) {
                  final pageP = _dcvSlideController.value.clamp(0.0, 1.0);
                  final isDCVVisual = pageP >= 0.5 && _selectedIndex == 2;
                  // Sub-screen is active when a back action is registered AND
                  // the settings panel is at least partially open.
                  final backAction = _settingsBackAction.value;
                  final isSubScreen =
                      backAction != null && _settingsController.value > 0;
                  final accent = (isDCVVisual && _dcvColor != null)
                      ? _dcvColor!
                      : resolveAccentColor(context);
                  final fadeOpacity = (1.0 - _searchModeAnim.value).clamp(
                    0.0,
                    1.0,
                  );
                  return Positioned(
                    left:
                        AppWindowContentScope.of(context).horizontalInset +
                        16.0, // 6 (Row left padding) + 10 (inner Positioned left)
                    top:
                        topInset +
                        2, // +2: original slot used Positioned(bottom:0) inside 38px slot, Padding height=36, so top = 38-36 = 2 below topInset
                    child: IgnorePointer(
                      ignoring: fadeOpacity < 0.01,
                      child: Opacity(
                        opacity: fadeOpacity,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: isDCVVisual
                              ? _exitDCV
                              : isSubScreen
                              ? backAction
                              : _settingsController.value > 0
                              ? _closeSettings
                              : _openSettings,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(0, 10, 10, 0),
                            child: Transform.translate(
                              offset: Offset(
                                0,
                                isLandscape
                                    ? (isDCVVisual
                                          ? 1.0
                                          : isSubScreen
                                          ? 1.0
                                          : 0.8)
                                    : 0,
                              ),
                              child: _MorphingMenuIcon(
                                // Show hamburger/X only when settings is open
                                // but NOT in a sub-screen (sub-screen uses the
                                // same back-chevron as DCV).
                                open: _settingsOpen && !isSubScreen,
                                isDCV: isDCVVisual || isSubScreen,
                                color: accent,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ), // TapRegionSurface
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
    required this.canUp,
    required this.canDown,
    this.compact = false,
    this.onUp,
    this.onDown,
  });

  final double titleFontSize;
  final bool canUp, canDown;
  final bool compact;
  final VoidCallback? onUp;
  final VoidCallback? onDown;

  @override
  Widget build(BuildContext context) {
    // Strategy: the whole widget is shifted 26 px to the LEFT via
    // Transform.translate (which moves both visuals AND hit testing).
    // Each GestureDetector is a 86 px wide SizedBox so the icon lands
    // at exactly +8 px from the title's right edge:
    //   visual icon left = –26 (shift) + 34 (left padding inside box) = +8 px ✓
    // The hit area extends 26 px into the tap-dead title region (left)
    // and 40 px beyond the icon (right), covering ≈±35 px of chevron
    // drift as the title length changes between views.
    const double shift = 26.0;
    const double hitW = 86.0; // 34 left-of-icon + 12 icon + 40 right ext
    const double iconLeft = 34.0; // shift + 8 px visual gap
    final safeTitleFontSize =
        titleFontSize.isFinite && titleFontSize > 0
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
      final compactIconSize = 18.0 * compactIconScale;
      // Keep the landscape pair compact around the title center while retaining
      // the two full-height tap zones.
      final compactIconOffset = 13.0 - compactIconSize * 0.36;

      Widget compactHalf({
        required _ChevronDir direction,
        required Color color,
        required VoidCallback? onTap,
      }) {
        return Expanded(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onTap,
            child: SizedBox.expand(
              child: Center(
                child: Transform.translate(
                  offset: Offset(
                    0,
                    direction == _ChevronDir.up
                        ? compactIconOffset
                        : -compactIconOffset,
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
        );
      }

      return SizedBox(
        width: 24,
        height: 52,
        child: Column(
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

    Widget half({
      required _ChevronDir direction,
      required Color color,
      required VoidCallback? onTap,
      required double top,
      required double bottom,
    }) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: hitW,
          height: halfHeight,
          child: Padding(
            padding: EdgeInsets.fromLTRB(iconLeft, top, 0, bottom),
            child: Align(
              alignment: Alignment.centerLeft,
              child: _ChevronIcon(
                direction: direction,
                color: color,
                size: iconSize,
                strokeWidth: 1.6 * scale,
              ),
            ),
          ),
        ),
      );
    }

    return Transform.translate(
      offset: const Offset(-shift, 0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          half(
            direction: _ChevronDir.up,
            color: canUp ? resolveAccentColor(context) : disabledColor,
            onTap: onUp,
            top: firstTop,
            bottom: firstBottom,
          ),
          half(
            direction: _ChevronDir.down,
            color: canDown ? resolveAccentColor(context) : disabledColor,
            onTap: onDown,
            top: secondTop,
            bottom: secondBottom,
          ),
        ],
      ),
    );
  }
}

class _MorphingMenuIcon extends StatelessWidget {
  final bool open;
  final bool isDCV;
  final Color color;

  const _MorphingMenuIcon({
    required this.open,
    this.isDCV = false,
    this.color = kAccentColor,
  });

  // Paints the icon at parameter t:
  //   t = -1 → chevron <   t = 0 → hamburger   t = 1 → X
  Widget _buildIcon(double t) {
    final double topX, topY, topAngle, bottomX, bottomY, bottomAngle;
    final double s = t <= 0 ? -t : 0.0;
    final double strokeWidth = 22.0 - 10.0 * s;

    if (t <= 0) {
      // Hamburger ↔ Chevron <  (t: 0 → −1)
      // topX/bottomX = 0 so both strokes stay centred on x=0.  At t=−1 the
      // two strokes run from x≈−4.6 (apex) to x≈+4.6 (open ends), making the
      // geometric centre of the < land exactly at the icon centre — the same
      // point as the hamburger × intersection.
      topX = 0;
      topY = -4.5 + 0.64 * s;
      topAngle = -0.6981317007977318 * s;
      bottomX = 0;
      bottomY = 4.5 - 0.64 * s;
      bottomAngle = 0.6981317007977318 * s;
    } else {
      // Hamburger ↔ X  (t: 0 → 1)
      topX = 0;
      topY = -4.5 + (4.5 * t);
      topAngle = 0.7853981633974483 * t;
      bottomX = 0;
      bottomY = 4.5 - (4.5 * t);
      bottomAngle = -0.7853981633974483 * t;
    }

    return SizedBox(
      width: 26,
      height: 26,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.translate(
            offset: Offset(topX, topY),
            child: Transform.rotate(
              angle: topAngle,
              child: _MenuStroke(width: strokeWidth, color: color),
            ),
          ),
          Transform.translate(
            offset: Offset(bottomX, bottomY),
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
    // DCV mode: draw the chevron synchronously — no TweenAnimationBuilder,
    // no animation lifecycle, zero flicker on enter/exit.
    if (isDCV) return _buildIcon(-1.0);

    // Normal mode: animate hamburger ↔ X when the menu opens/closes.
    // The chevron morph is intentionally excluded here so it always snaps.
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: open ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      builder: (context, t, _) => _buildIcon(t),
    );
  }
}

class _MenuStroke extends StatelessWidget {
  final double width;

  /// Stroke thickness in logical pixels. Matches the thinner header icon
  /// treatment used by the Day View and View Mode controls.
  final double height;
  final Color color;
  const _MenuStroke({
    this.width = 22,
    this.height = 1.6,
    this.color = kAccentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: ShapeDecoration(
        color: color,
        shape: const BoundedSquircleStadiumBorder(
          radius: kSquircleStadiumRadius,
        ),
      ),
    );
  }
}
