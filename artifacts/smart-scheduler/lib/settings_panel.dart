import 'package:flutter/cupertino.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'ai/ai_services.dart';
import 'ai/parsed_date.dart';
import 'app_settings.dart';
import 'app_theme.dart';
import 'widgets/app_switch.dart';
import 'widgets/fixed_size_icon.dart';

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
//   • Main list  : separator bottom → top of first section label = 17.5 pt
//   • Sub-screen : separator bottom → top of first card group    = 18 pt
// ══════════════════════════════════════════════════════════════════════════════

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
  const _SettingsRoute({
    required this.title,
    required this.options,
    required this.defaultValue,
    this.isAccentColor = false,
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
    options: ['Compact', 'Default', 'Large'],
    defaultValue: 'Default',
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
    return ListenableBuilder(
      listenable: Listenable.merge([
        appAccentNotifier,
        appBrightnessNotifier,
        appTextSizeNotifier,
        appStartOfWeekNotifier,
        appDefaultViewNotifier,
        appEventDurationNotifier,
        appDateLocaleNotifier,
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
        final textSizeLabel = appTextSizeNotifier.value;
        final startOfWeekLabel = appStartOfWeekNotifier.value;
        final defaultViewLabel = appDefaultViewNotifier.value;
        final eventDurationLabel = appEventDurationNotifier.value;
        final dateFormatLabel =
            appDateLocaleNotifier.value == DateLocalePreference.dayFirst
            ? 'Day first (D/M/Y)'
            : 'Month first (M/D/Y)';

        final headerHeight = widget.topInset + 101;

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
                        bottomInset: widget.bottomInset,
                        onPush: _push,
                        accentColor: accentColor,
                        accentSwatch: swatch,
                        themeLabel: themeLabel,
                        textSizeLabel: textSizeLabel,
                        startOfWeekLabel: startOfWeekLabel,
                        defaultViewLabel: defaultViewLabel,
                        eventDurationLabel: eventDurationLabel,
                        dateFormatLabel: dateFormatLabel,
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
                          bottomInset: widget.bottomInset,
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
                          topInset: widget.topInset,
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
  final String dateFormatLabel;

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
    required this.dateFormatLabel,
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
        // 17.5 pt from header separator bottom to first section label top.
        const SliverToBoxAdapter(child: SizedBox(height: 17.5)),

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

        const SliverToBoxAdapter(child: SizedBox(height: 15)),

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
          ],
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 15)),

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
              title: 'Date Format',
              trailing: _ValueTrailing(dateFormatLabel),
              onTap: () => _tap('Date Format'),
            ),
          ],
        ),

        const SliverToBoxAdapter(child: SizedBox(height: 15)),

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

        const SliverToBoxAdapter(child: SizedBox(height: 15)),

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

        SliverPadding(padding: EdgeInsets.only(bottom: bottomInset + 32)),
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
      'Text Size' => appTextSizeNotifier.value,
      'Start of Week' => appStartOfWeekNotifier.value,
      'Default View' => appDefaultViewNotifier.value,
      'Default Event Duration' => appEventDurationNotifier.value,
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
        appTextSizeNotifier.value = opt;
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
          // 18 pt gap below the shared header separator.
          const SliverToBoxAdapter(child: SizedBox(height: 18)),

          // Branch: accent-color picker vs. standard option list.
          if (widget.route.isAccentColor)
            _AccentColorSection(accentNotifier: widget.accentNotifier)
          else
            _SubScreenSection(
              options: widget.route.options,
              selectedOption: _selected,
              accentColor: widget.accentColor,
              onSelect: _onSelect,
            ),

          SliverPadding(
            padding: EdgeInsets.only(bottom: widget.bottomInset + 32),
          ),
        ],
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
                      bottom: 10,
                    ),
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: kSFProDisplay,
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
            // Section header label — 10 pt gap to card gives visual breathing
            // room between the uppercase label and the card below.
            Padding(
              padding: const EdgeInsets.only(left: 16, bottom: 10),
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
    final ShapeBorder shape = rows.length == 1
        ? const SquircleStadiumBorder()
        : BoundedContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(kCardCornerRadius),
          );
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
const double _kSettingsRowVerticalPadding = 10.0;

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
            // Checkmark — only visible for the selected option.
            // Match the action-panel checkmark size and weight.
            if (widget.selected)
              FixedSFIcon(
                SFIcons.sf_checkmark,
                fontSize: _settingsScaledFontSize(context, 17),
                fontWeight: FontWeight.w500,
                color: widget.accentColor,
              ),
            // Reserve checkmark width when unselected so the text column is stable.
            if (!widget.selected) const SizedBox(width: 18),
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
        height: _kSettingsRowHeight,
        padding: const EdgeInsets.symmetric(horizontal: 16),
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
            // Checkmark — only for the selected swatch.
            // Match the action-panel checkmark size and weight.
            // Reserve width for unselected rows so the text column is stable.
            if (widget.selected)
              FixedSFIcon(
                SFIcons.sf_checkmark,
                fontSize: _settingsScaledFontSize(context, 17),
                fontWeight: FontWeight.w500,
                color: widget.accentColor,
              )
            else
              const SizedBox(width: 18),
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
    return Text(
      smartWrapChevronValue(text),
      textAlign: TextAlign.right,
      softWrap: true,
      style: style,
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
          child: Text(
            name,
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
