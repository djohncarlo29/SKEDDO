import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'ai/ai_services.dart';
import 'ai/parsed_date.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'widgets/app_switch.dart';
import 'widgets/accent_tinted_image.dart';
import 'widgets/fixed_size_icon.dart';
import 'widgets/floating_tab_pill.dart';
import 'widgets/header_title_scroller.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SettingsPanel — full-screen slide-in settings surface with sub-screen nav.
//
// Positioned at Offset(0,0) in the root Stack when open.  The AppShell owns
// the AnimationController (_settingsController) and wraps this widget in a
// SlideTransition + GestureDetector.
//
// Navigation model
//   • _push(route)  — animates sub-screen in from right; main content shifts
//     left with a 30 % parallax (matches DCV slide feel).
//   • _pop()        — reverses the animation then clears the active route.
//   • The X button in AppShell's overlay always closes the whole panel.
//   • The "< Settings" back button lives inside the sub-screen header's
//     44 pt icon-row slot.  Because the X overlay from AppShell is rendered
//     above this widget, taps inside the X's hit-area close the panel; taps
//     outside (but still within the back button row) trigger _pop().  Both
//     results are correct from the sub-screen context.
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
  'Start of Week': _SettingsRoute(
    title: 'Start of Week',
    options: ['Sunday', 'Monday', 'Saturday'],
    defaultValue: 'Sunday',
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
    options: ['Month first (M/D/Y)', 'Day first (D/M/Y)'],
    defaultValue: 'Month first (M/D/Y)',
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

  /// Called when the X button is tapped — triggers controller.reverse()
  /// on the parent.
  final VoidCallback onClose;

  /// Set to the pop callback when a sub-screen is active, null otherwise.
  /// AppShell listens to this so the shared overlay button morphs into a
  /// back-chevron and calls _pop() — exactly matching the DCV back mechanic.
  final ValueNotifier<VoidCallback?> subScreenBackAction;

  const SettingsPanel({
    super.key,
    required this.topInset,
    required this.bottomInset,
    required this.onClose,
    required this.subScreenBackAction,
  });

  @override
  State<SettingsPanel> createState() => _SettingsPanelState();
}

class _SettingsPanelState extends State<SettingsPanel>
    with SingleTickerProviderStateMixin {
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

  _SettingsRoute? _activeRoute;

  // Listener added to _navCtrl when a push starts; fires the hard-snap of the
  // overlay icon to "<" at the 50 % midpoint — matching the DCV timing.
  VoidCallback? _snapListener;

  void _push(_SettingsRoute route) {
    // Clean up any leftover snap listener from a previous push.
    if (_snapListener != null) {
      _navCtrl.removeListener(_snapListener!);
      _snapListener = null;
    }
    setState(() => _activeRoute = route);
    _navCtrl.forward(from: 0.0);

    // Hard-snap to "<" at the 50 % midpoint of the sub-screen slide, identical
    // to how DCV snaps the hamburger at pageP >= 0.5 of _dcvSlideController.
    void listener() {
      if (_navCtrl.value >= 0.5) {
        widget.subScreenBackAction.value = _pop;
        _navCtrl.removeListener(listener);
        _snapListener = null;
      }
    }

    _snapListener = listener;
    _navCtrl.addListener(listener);
  }

  void _pop() {
    // Remove any pending snap listener (pop before reaching 50 %).
    if (_snapListener != null) {
      _navCtrl.removeListener(_snapListener!);
      _snapListener = null;
    }
    // Immediately clear the back action so the overlay icon snaps back.
    widget.subScreenBackAction.value = null;
    _navCtrl.reverse().then((_) {
      if (mounted) setState(() => _activeRoute = null);
    });
  }

  @override
  void dispose() {
    if (_snapListener != null) _navCtrl.removeListener(_snapListener!);
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
        appBrightnessNotifier,
        appTextSizeUsesSystemNotifier,
        appTextSizeIndexNotifier,
        appSystemTextScaleNotifier,
        appStartOfWeekNotifier,
        appDefaultViewNotifier,
        appEventDurationNotifier,
         appDefaultCategoryNotifier,
         appDefaultCategoryLabelNotifier,
        appDateLocaleNotifier,
        appLiquidGlassOpacityNotifier,
      ]),
      builder: (context, _) {
        final swatch = _kAccentSwatches[appAccentNotifier.value];
        final accentColor = CupertinoDynamicColor.resolve(
          swatch.color,
          context,
        );

        final themeLabel = switch (appBrightnessNotifier.value) {
          Brightness.light => 'Light',
          Brightness.dark => 'Dark',
          _ => 'System',
        };
        final textSizeLabel = appTextSizeUsesSystemNotifier.value
            ? 'System'
            : 'Custom';
        final startOfWeekLabel = appStartOfWeekNotifier.value;
        final defaultViewLabel = appDefaultViewNotifier.value;
        final eventDurationLabel = appEventDurationNotifier.value;
        final defaultCategoryLabel = appDefaultCategoryLabelNotifier.value;
        final dateFormatLabel =
            appDateLocaleNotifier.value == DateLocalePreference.dayFirst
            ? 'Day first (D/M/Y)'
            : 'Month first (M/D/Y)';
        final liquidGlassRange =
            kLiquidGlassMaximumOpacity - kLiquidGlassMinimumOpacity;
        final liquidGlassOpacityLabel =
            '${((appLiquidGlassOpacityNotifier.value - kLiquidGlassMinimumOpacity) / liquidGlassRange * 100).round()}%';

        final headerHeight = topInset + 101;

        return ClipRect(
          child: ColoredBox(
            color: resolveThemeColor(kBackgroundColor, context),
            child: SizedBox.expand(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // ── Main body — slides right (parallax) during sub-screen push ──
                  Positioned.fill(
                    top: headerHeight,
                    child: SlideTransition(
                      position: _mainParallax,
                      child: _MainSettingsContent(
                        bottomInset: bottomInset,
                        onPush: _push,
                        accentColor: accentColor,
                        accentSwatch: swatch,
                        themeLabel: themeLabel,
                        textSizeLabel: textSizeLabel,
                        startOfWeekLabel: startOfWeekLabel,
                        defaultViewLabel: defaultViewLabel,
                        eventDurationLabel: eventDurationLabel,
                         defaultCategoryLabel: defaultCategoryLabel,
                        dateFormatLabel: dateFormatLabel,
                        liquidGlassOpacityLabel: liquidGlassOpacityLabel,
                      ),
                    ),
                  ),

                  // ── Sub-screen body — slides in from right; no header ───────
                  if (_activeRoute != null)
                    Positioned.fill(
                      top: headerHeight,
                      child: SlideTransition(
                        position: _subSlide,
                        child: _SubScreen(
                          bottomInset: bottomInset,
                          route: _activeRoute!,
                          accentColor: accentColor,
                          accentNotifier: appAccentNotifier,
                        ),
                      ),
                    ),

                  // ── Unified snapping header — never slides ──────────────────
                  // Title snaps from "Settings" → sub-screen name at the 50 %
                  // midpoint of _navCtrl, matching the overlay icon snap timing.
                  // Must be Positioned so StackFit.expand doesn't force it to
                  // fill the entire stack (which would cover all content below).
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedBuilder(
                      animation: _navCtrl,
                      builder: (context, _) {
                        final isSubScreen =
                            _activeRoute != null && _navCtrl.value >= 0.5;
                        return _SettingsHeader(
                          topInset: topInset,
                          title: isSubScreen ? _activeRoute!.title : 'Settings',
                        );
                      },
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
  final void Function(_SettingsRoute) onPush;
  // Current resolved accent color — used for the Accent Color row trailing.
  final Color accentColor;
  // Current accent swatch — name + color for the trailing circle + label.
  final _AccentSwatch accentSwatch;
  // Live labels derived from app-level notifiers in _SettingsPanelState.build().
  final String themeLabel;
  final String textSizeLabel;
  final String startOfWeekLabel;
  final String defaultViewLabel;
  final String eventDurationLabel;
  final String defaultCategoryLabel;
  final String dateFormatLabel;
  final String liquidGlassOpacityLabel;

  const _MainSettingsContent({
    required this.bottomInset,
    required this.onPush,
    required this.accentColor,
    required this.accentSwatch,
    required this.themeLabel,
    required this.textSizeLabel,
    required this.startOfWeekLabel,
    required this.defaultViewLabel,
    required this.eventDurationLabel,
    required this.defaultCategoryLabel,
    required this.dateFormatLabel,
    required this.liquidGlassOpacityLabel,
  });

  void _tap(String title) {
    final route = _kRoutes[title];
    if (route != null) onPush(route);
  }

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        // Keep the settings rhythm on the 8 pt grid.
        const SliverToBoxAdapter(child: SizedBox(height: 16)),

        // ── Account ─────────────────────────────────────────────────────────
        _SettingsSection(
          label: 'Account',
          rows: [
            _SettingsRow(
              title: 'Profile',
              trailing: const _ChevronTrailing(),
              onTap: () => _tap('Profile'),
            ),
            _SettingsRow(
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
              title: 'Theme',
              trailing: _ValueTrailing(themeLabel),
              onTap: () => _tap('Theme'),
            ),
            _SettingsRow(
              title: 'Accent Color',
              trailing: _ColorTrailing(
                color: accentColor,
                name: accentSwatch.name,
              ),
              onTap: () => _tap('Accent Color'),
            ),
            _SettingsRow(
              title: 'Text Size',
              trailing: _ValueTrailing(textSizeLabel),
              onTap: () => _tap('Text Size'),
            ),
            _SettingsRow(
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
              title: 'Default View',
              trailing: _ValueTrailing(defaultViewLabel),
              onTap: () => _tap('Default View'),
            ),
            _SettingsRow(
              title: 'Start of Week',
              trailing: _ValueTrailing(startOfWeekLabel),
              onTap: () => _tap('Start of Week'),
            ),
            _SettingsRow(
              title: 'Default Event Duration',
              trailing: _ValueTrailing(eventDurationLabel),
              onTap: () => _tap('Default Event Duration'),
            ),
            _SettingsRow(
              title: 'Default Category',
              trailing: _ValueTrailing(defaultCategoryLabel),
              onTap: () => _tap('Default Category'),
            ),
            _SettingsRow(
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
              title: 'Event Reminders',
              value: true,
              onChanged: (_) {},
            ),
            _SettingsToggleRow(
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
              title: 'Privacy',
              trailing: const _ChevronTrailing(),
              onTap: () => _tap('Privacy'),
            ),
            _SettingsRow(
              title: 'Check for Updates',
              trailing: const _ChevronTrailing(),
              onTap: () => _tap('Check for Updates'),
            ),
            _SettingsRow(
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
  // Current resolved accent color — forwarded to _SubScreenSection for
  // checkmarks and selection highlights.
  final Color accentColor;
  // Notifier owned by _SettingsPanelState — passed to _AccentColorSection so
  // tapping a swatch immediately updates the live accent everywhere.
  final ValueNotifier<int> accentNotifier;

  const _SubScreen({
    required this.bottomInset,
    required this.route,
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
      'Start of Week' => appStartOfWeekNotifier.value,
      'Default View' => appDefaultViewNotifier.value,
      'Default Event Duration' => appEventDurationNotifier.value,
      'Default Category' => appDefaultCategoryLabelNotifier.value,
      'Date Format' =>
        appDateLocaleNotifier.value == DateLocalePreference.dayFirst
            ? 'Day first (D/M/Y)'
            : 'Month first (M/D/Y)',
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
      case 'Start of Week':
        appStartOfWeekNotifier.value = opt;
        saveAppSetting('Start of Week', opt);
      case 'Default View':
        appDefaultViewNotifier.value = opt;
        saveAppSetting('Default View', opt);
      case 'Default Event Duration':
        appEventDurationNotifier.value = opt;
        saveAppSetting('Default Event Duration', opt);
      case 'Date Format':
        final preference = opt.startsWith('Day')
            ? DateLocalePreference.dayFirst
            : DateLocalePreference.monthFirst;
        appDateLocaleNotifier.value = preference;
        AIServices.setDateLocalePreference(preference);
        saveAppSetting('Date Format', opt);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: resolveThemeColor(kBackgroundColor, context),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        slivers: [
          // Keep the settings rhythm on the 8 pt grid.
          const SliverToBoxAdapter(child: SizedBox(height: 16)),

          // Branch: accent-color picker vs. standard option list.
          if (widget.route.isAccentColor)
            _AccentColorSection(accentNotifier: widget.accentNotifier)
          else if (widget.route.isLiquidGlass)
            const _LiquidGlassSection()
          else if (widget.route.isTextSize)
            _TextSizeSection(accentColor: widget.accentColor)
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
      ),
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
    final prefs = await SharedPreferences.getInstance();
    final records = <_DefaultCategoryOption>[];
    final seen = <String>{};
    final raw = [
      ...?prefs.getStringList('events_user_categories'),
      ...?prefs.getStringList('events_pinned_categories'),
    ];

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
        child: _SettingsCard(
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

// ── Unified snapping header (shared by main settings and sub-screens) ─────────
// The title is swapped by _SettingsPanelState at the 50 % midpoint of the
// nav animation — no slide, just an instant snap matching the DCV timing.
class _SettingsHeader extends StatelessWidget {
  final double topInset;
  final String title;

  const _SettingsHeader({required this.topInset, required this.title});

  @override
  Widget build(BuildContext context) {
    final cardColor = resolveThemeColor(kCardColor, context);
    final separatorColor = resolveThemeColor(kSeparatorColor, context);
    final shadowColor = resolveThemeColor(kTabBarShadowColor, context);
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    return Container(
      width: double.infinity,
      height: topInset + 101,
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: resolveThemeShadows([
          BoxShadow(color: shadowColor, blurRadius: 6, offset: Offset(0, 2)),
        ], context),
      ),
      child: Stack(
        children: [
          // Hairline separator at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(height: 0.75, color: separatorColor),
          ),
          Padding(
            padding: EdgeInsets.only(top: topInset),
            child: Column(
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
                          fadeColor: cardColor,
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
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: kSFProText,
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: resolveThemeColor(kSecondaryLabel, context),
                  letterSpacing: 0.06,
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
        child: _SettingsCard(
          rows: rows,
          cardBg: cardBg,
          shadowColor: shadowColor,
        ),
      ),
    );
  }
}

// ── Text-size mode and seven-position custom slider ────────────────────────────
class _TextSizeSection extends StatelessWidget {
  final Color accentColor;

  const _TextSizeSection({required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final cardBg = resolveThemeColor(kCardColor, context);
    final shadowColor = resolveThemeColor(kCardShadowColor, context);

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
            child: _SettingsCard(
              rows: [
                _OptionRow(
                  title: 'System',
                  selected: usesSystem,
                  accentColor: accentColor,
                  onTap: selectSystem,
                ),
                _TextSizeSliderRow(
                  index: customIndex,
                  animateValue: usesSystem,
                  accentColor: accentColor,
                  onChanged: previewCustom,
                  onChangeEnd: selectCustom,
                ),
              ],
              cardBg: cardBg,
              shadowColor: shadowColor,
            ),
          ),
        );
      },
    );
  }
}

class _TextSizeSliderRow extends StatefulWidget {
  final int index;
  final bool animateValue;
  final Color accentColor;
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;

  const _TextSizeSliderRow({
    required this.index,
    required this.animateValue,
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

  @override
  void initState() {
    super.initState();
    _indexAnimation = AlwaysStoppedAnimation(widget.index.toDouble());
  }

  @override
  void didUpdateWidget(_TextSizeSliderRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animateValue && oldWidget.index != widget.index) {
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
                child: LiquidGlassSlider(
                  value: _indexAnimation.value / 6,
                  minimumValue: 0,
                  maximumValue: 1,
                  width: sliderWidth,
                  height: _kSettingsRowHeight,
                  layout: _liquidGlassSliderLayout,
                  isContinuous: true,
                  divisions: 6,
                  activeColor: widget.accentColor,
                  inactiveColor: inactiveColor,
                  thumbColor: const Color(0xFFFDFDFD),
                  onChanged: (raw) => widget.onChanged(raw * 6),
                  onChangeEnd: (raw) => widget.onChangeEnd(raw * 6),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
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
    final secondaryLabel = resolveThemeColor(kSecondaryLabel, context);
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final backgroundAsset = isDark
        ? 'assets/liquid_glass_background_dark.webp'
        : 'assets/liquid_glass_background_light.webp';
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
                shape: const BoundedSquircleStadiumBorder(),
              ),
              child: SizedBox(
                width: double.infinity,
                height: 154,
                child: ClipPath(
                  clipper: ShapeBorderClipper(
                    shape: const BoundedSquircleStadiumBorder(),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      AccentTintedImage(
                        assetName: backgroundAsset,
                        accentColor: accent,
                      ),
                      const Center(child: FloatingTabBarGlassPreview()),
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: ValueListenableBuilder<double>(
                    valueListenable: appLiquidGlassOpacityNotifier,
                    builder: (context, value, _) {
                      return LayoutBuilder(
                        builder: (context, constraints) {
                          // The slider sits inside the row's fixed 18 px
                          // horizontal content inset.  Widen it only by the
                          // difference between that inset and the required
                          // settled-thumb edge inset, so the package's thumb
                          // centers resolve to:
                          //   rowLeft + 16 + thumbWidth / 2
                          //   rowRight - 16 - thumbWidth / 2
                          final sliderWidth =
                              constraints.maxWidth +
                              2 *
                                  (_kLiquidGlassRowHorizontalPadding -
                                      _kLiquidGlassSettledEdgeInset);
                          return OverflowBox(
                            alignment: Alignment.center,
                            minWidth: sliderWidth,
                            maxWidth: sliderWidth,
                            child: LiquidGlassSlider(
                              value:
                                  ((value - kLiquidGlassMinimumOpacity) /
                                          (kLiquidGlassMaximumOpacity -
                                              kLiquidGlassMinimumOpacity))
                                      .clamp(0.0, 1.0),
                              minimumValue: 0,
                              maximumValue: 1,
                              // Extend the package's internal geometry by one
                              // resting-thumb width and center it. Its built-in
                              // half-thumb center offsets then place the 0.0
                              // and 1.0 centers on the visible row edges.
                              width: sliderWidth,
                              height: _kSettingsRowHeight,
                              layout: _liquidGlassSliderLayout,
                              // Publish every drag update so the preview and
                              // the rest of the app track the slider in real
                              // time. The endpoint callback still commits the
                              // final snapped value after the drag settles.
                              isContinuous: true,
                              divisions: 10,
                              activeColor: accent,
                              inactiveColor: inactive,
                              thumbColor: const Color(0xFFFDFDFD),
                              onChanged: _setLiquidGlassOpacity,
                              onChangeEnd: _setLiquidGlassOpacity,
                            ),
                          );
                        },
                      );
                    },
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
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _LiquidGlassTestIcons(
                      surfaceColor: cardBg,
                      secondaryColor: secondaryLabel,
                    ),
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
  final Color surfaceColor;
  final Color secondaryColor;

  const _LiquidGlassTestIcons({
    required this.surfaceColor,
    required this.secondaryColor,
  });

  @override
  State<_LiquidGlassTestIcons> createState() => _LiquidGlassTestIconsState();
}

class _LiquidGlassTestIconsState extends State<_LiquidGlassTestIcons> {
  late final Future<List<String>> _svgSources = Future.wait([
    rootBundle.loadString('assets/icons/Liquid_Glass_left.svg'),
    rootBundle.loadString('assets/icons/Liquid_Glass_right.svg'),
  ]);

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
    return FutureBuilder<List<String>>(
      future: _svgSources,
      builder: (context, snapshot) {
        final sources = snapshot.data;
        if (sources == null || sources.length != 2) {
          return const SizedBox.expand();
        }
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            SvgPicture.string(
              _withThemeColors(sources[0]),
              width: 34,
              height: 34,
            ),
            SvgPicture.string(
              _withThemeColors(sources[1]),
              width: 34,
              height: 34,
            ),
          ],
        );
      },
    );
  }
}

// The slider row has a fixed 18 px content inset. The settled thumb must sit
// 16 px inside the stadium row edge at either endpoint.
const double _kLiquidGlassRowHorizontalPadding = 18.0;
const double _kLiquidGlassSettledEdgeInset = 16.0;
// The package's own track coordinates are also the endpoint tick centers.
const double _kLiquidGlassSliderInset = 0.0;
const LiquidGlassSliderLayout _liquidGlassSliderLayout =
    LiquidGlassSliderLayout(horizontalInset: _kLiquidGlassSliderInset);

void _setLiquidGlassOpacity(double raw) {
  final normalized = (raw.clamp(0.0, 1.0) * 10).round() / 10;
  final snapped =
      kLiquidGlassMinimumOpacity +
      normalized * (kLiquidGlassMaximumOpacity - kLiquidGlassMinimumOpacity);
  if (snapped != appLiquidGlassOpacityNotifier.value) {
    appLiquidGlassOpacityNotifier.value = snapped;
    saveAppSetting('Liquid Glass', snapped.toString());
  }
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

class _SettingsRow extends StatefulWidget {
  final String title;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsRow({required this.title, this.trailing, this.onTap});

  @override
  State<_SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<_SettingsRow> {
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
        child: _buildSettingsRowContent(context),
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

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
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
                    onChanged: (v) {
                      setState(() => _value = v);
                      widget.onChanged(v);
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Option row (sub-screen) ───────────────────────────────────────────────────
// Renders a tappable row with an SF checkmark on the right when selected.
// Row label always stays kPrimaryLabel; only the checkmark takes accent color.
class _OptionRow extends StatefulWidget {
  final String title;
  final bool selected;
  final Color accentColor;
  final VoidCallback? onTap;

  const _OptionRow({
    required this.title,
    required this.selected,
    required this.accentColor,
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

// Full card of 12 swatch rows.  Wraps in ValueListenableBuilder so only this
// section rebuilds when the notifier changes — the outer ListenableBuilder in
// _SettingsPanelState handles the accent-dependent rebuild of the rest of the
// panel (trailing swatch, checkmarks in other sub-screens, etc.).
class _AccentColorSection extends StatelessWidget {
  final ValueNotifier<int> accentNotifier;

  const _AccentColorSection({required this.accentNotifier});

  @override
  Widget build(BuildContext context) {
    final cardBg = CupertinoDynamicColor.resolve(kCardColor, context);
    final shadowColor = CupertinoDynamicColor.resolve(
      kCardShadowColor,
      context,
    );
    return ValueListenableBuilder<int>(
      valueListenable: accentNotifier,
      builder: (context, selectedIndex, _) {
        final resolvedAccent = CupertinoDynamicColor.resolve(
          _kAccentSwatches[selectedIndex].color,
          context,
        );
        final rows = List.generate(_kAccentSwatches.length, (i) {
          final swatch = _kAccentSwatches[i];
          final resolvedColor = CupertinoDynamicColor.resolve(
            swatch.color,
            context,
          );
          return _AccentSwatchRow(
            swatch: swatch,
            resolvedColor: resolvedColor,
            selected: i == selectedIndex,
            accentColor: resolvedAccent,
            onTap: () {
              accentNotifier.value = i;
              saveAccentIndex(i);
            },
          );
        });
        return SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _SettingsCard(
              rows: rows,
              cardBg: cardBg,
              shadowColor: shadowColor,
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
