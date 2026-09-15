import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show lerpDouble;
import 'package:path_provider/path_provider.dart';
import 'package:flutter/gestures.dart' show DeviceGestureSettings, kTouchSlop;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:super_drag_and_drop/super_drag_and_drop.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_theme.dart';
import '../app_settings.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import '../widgets/fixed_size_icon.dart';
import '../widgets/native_text_input.dart';
import '../widgets/text_editing_helpers.dart';
import '../widgets/rounded_cupertino_sheet.dart';
import '../widgets/search_bar_widget.dart';
import '../widgets/vertical_edge_fade.dart';
import '../widgets/horizontal_edge_fade.dart';
import '../widgets/action_panel.dart';
import '../widgets/view_mode_icons.dart';
import '../widgets/app_switch.dart';
import '../services/event_store.dart';
import '../services/category_registry.dart';
import '../services/alert_sequence.dart';
import '../ai/search/search_service.dart';
import 'events_tab.dart'
    show
      buildDcvEventCard,
      buildDcvSectionLabel,
      buildDcvEventList,
      dcvTimeSectionKey,
      resolveEventCategoryColor,
      wrapSearchEventTileWithActions,
      wrapSearchEventTileWithPressScale;
import '../widgets/smart_search_results.dart';
import '../widgets/delete_confirmation_sheet.dart';

void _dismissModalSheetFocus() {
  NativeTextInput.unfocusAll();
  FocusManager.instance.primaryFocus?.unfocus();
}

// ── Name tables ───────────────────────────────────────────────────────────────
const _kMonthNames = [
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
const _kShortMonthNames = [
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
const _kDayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

// ── Layout constants ──────────────────────────────────────────────────────────
const double _kRowHeightList = 52.0;
const double _kRowHeightMonthList = 64.0;
// Month List content changes to Day View at the same midpoint used by the
// header/content transition. Keep all List-only adornments on this boundary so
// they cannot leak into the incoming Day View week strip.
const double _kMonthDayTransitionThreshold = 0.5;
const double _kMonthListDotDiameter = 5.0;
// The embedded DCV keeps one 16 pt trailing section gap outside its
// AnimatedSize. That gap remains after a section's event card collapses, so it
// is the correct existing trailing padding for both an event tile and a
// collapsed section header.
const double _kMonthListSectionTrailingContentPadding = 16.0;
const double _kMonthListFinalContentGap = 16.0;
const double _kDayIndicatorDiameter = 36.0;
const double _kDayIndicatorBottomGap = 8.0;
const double _kRowHeightCompact = 68.0;
const double _kRowHeightStacked = 96.0;
const double _kRowHeightDetails = 128.0;
const double kFixedTopPadding = 8.0; // top padding above the day circle
const double kDayCircleOffset =
    26.0; // circle centre from row top (= kFixedTopPadding + 18)
const double _kDayLabelHeight = 28.0;
const double _kWeekNumWidth = 28.0;
const double _kYearOuterPad = 16.0;
const double _kYearColGap = 12.0;
const double _kYearRowGap = 27.0;
const double _kHourHeight = 64.0;
const double _kTimelinePad =
    8.0; // breathing room above 12 am and below midnight
const double _kDayBannerHeight = 36.0;
// Fixed 8 pt breathing room between the large app header and the Month/Day
// DOW row. Keep this independent from text scaling and the shared 16 pt
// vertical padding token.
const double _kCalendarHeaderToDowGap = 8.0;

double _dayViewWeekStripHeight(BuildContext context) {
  final indicatorSize =
      _kDayIndicatorDiameter * textScaleRatioFor(context, 17.0);
  return math.max(
    _kRowHeightList,
    kFixedTopPadding + indicatorSize + _kDayIndicatorBottomGap,
  );
}

/// Year View keeps its authored geometry at the default OS size or larger.
/// Smaller accessibility/text-size settings are still honoured.
TextScaler _yearViewTextScaler(BuildContext context) =>
    MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.0);

// ── Date utilities ────────────────────────────────────────────────────────────
int _daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

// 0 = Monday … 6 = Sunday
int _firstWeekday(int year, int month) => DateTime(year, month, 1).weekday - 1;

int _isoWeekNumber(DateTime date) {
  final thu = date.subtract(Duration(days: date.weekday - DateTime.thursday));
  final jan4 = DateTime(thu.year, 1, 4);
  final w1 = jan4.subtract(Duration(days: jan4.weekday - DateTime.monday));
  return ((thu.difference(w1).inDays) / 7).floor() + 1;
}

int _totalWeekRows(int year, int month) {
  final offset = _firstWeekday(year, month);
  final days = _daysInMonth(year, month);
  return ((offset + days) / 7).ceil();
}

// 0-based week-row index for [date] within its month grid.
int _weekRowForDate(DateTime date) {
  final offset = _firstWeekday(date.year, date.month);
  return (date.day + offset - 1) ~/ 7;
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _calendarDateKey(DateTime date) =>
    '${date.year}-${date.month}-${date.day}';

DateTime? _calendarEventDate(String? rawDate) {
  if (rawDate == null || rawDate.trim().isEmpty) return null;
  final parsed = DateTime.tryParse(rawDate.trim());
  if (parsed != null) {
    return DateTime(parsed.year, parsed.month, parsed.day);
  }
  final match = RegExp(r'^(\w+) (\d+), (\d{4})$').firstMatch(rawDate.trim());
  if (match == null) return null;
  final month = _kMonthNames.indexOf(match.group(1)!);
  if (month < 0) return null;
  final day = int.tryParse(match.group(2)!);
  final year = int.tryParse(match.group(3)!);
  if (day == null || year == null) return null;
  return DateTime(year, month + 1, day);
}

DateTime? _calendarEventStartDate(ScheduledEvent event) =>
    event.parsedDate?.absoluteDate != null
    ? DateTime(
        event.parsedDate!.absoluteDate!.year,
        event.parsedDate!.absoluteDate!.month,
        event.parsedDate!.absoluteDate!.day,
      )
    : _calendarEventDate(event.date);

DateTime? _calendarEventEndDate(ScheduledEvent event) =>
    _calendarEventDate(event.endDate) ?? _calendarEventStartDate(event);

int _calendarTimeToMinutes(String? value) {
  if (value == null) return 0;
  final parts = value.trim().split(' ');
  if (parts.length < 2) return 0;
  final hm = parts[0].split(':');
  var hour = int.tryParse(hm.first) ?? 0;
  final minute = hm.length > 1 ? int.tryParse(hm[1]) ?? 0 : 0;
  final isPm = parts[1].toUpperCase() == 'PM';
  if (isPm && hour != 12) hour += 12;
  if (!isPm && hour == 12) hour = 0;
  return hour * 60 + minute;
}

// ── View enum ─────────────────────────────────────────────────────────────────
enum CalendarView { year, month, day }

// ── View-mode enum (month-grid density) ───────────────────────────────────────
enum CalendarViewMode { list, compact, stacked, details }

extension CalendarViewModeExt on CalendarViewMode {
  double get rowHeight {
    switch (this) {
      case CalendarViewMode.list:
        return _kRowHeightMonthList;
      case CalendarViewMode.compact:
        return _kRowHeightCompact;
      case CalendarViewMode.stacked:
        return _kRowHeightStacked;
      case CalendarViewMode.details:
        return _kRowHeightDetails;
    }
  }

  String get label {
    switch (this) {
      case CalendarViewMode.list:
        return 'List';
      case CalendarViewMode.compact:
        return 'Compact';
      case CalendarViewMode.stacked:
        return 'Stacked';
      case CalendarViewMode.details:
        return 'Details';
    }
  }
}

const _kViewModePrefsKey = 'calendar_view_mode';

// ══════════════════════════════════════════════════════════════════════════════
// CalendarTab
// ══════════════════════════════════════════════════════════════════════════════
class CalendarTab extends StatefulWidget {
  const CalendarTab({
    super.key,
    required this.onViewChanged,
    this.onStripSlide,
    this.onSearchCancel,
    this.searchModeAnimation,
    this.onEditEvent,
    this.dcvSectionNamesProvider,
    this.dcvSectionEventIdsProvider,
    this.onDcvSectionEventIdsChanged,
    this.daySubMode = DayViewSubMode.singleDay,
  });

  final void Function(
    CalendarView view,
    int displayYear,
    String prevTitle,
    String title,
    String nextTitle,
  )
  onViewChanged;
  // Called with the current week-strip slide offset (logical px, 0.0 when idle)
  // so AppShell can translate the calendar header in lock-step with the strip.
  final void Function(double slideX)? onStripSlide;
  // Called when the calendar's own search overlay is dismissed so AppShell can
  // reset its _searchFocused flag and restore the header.
  final VoidCallback? onSearchCancel;
  // Shared animation from AppShell — 0=header visible, 1=search mode active.
  final Animation<double>? searchModeAnimation;

  /// Opens the shared event editor for a search result long-press action.
  final void Function(ScheduledEvent event)? onEditEvent;
  /// Live DCV section state owned by EventsTab. The event sheet uses these
  /// providers so it does not race a just-finished DCV edit against prefs.
  final Map<String, List<String>>? Function()? dcvSectionNamesProvider;
  final Map<String, List<List<String>>>? Function()?
      dcvSectionEventIdsProvider;
  final void Function(String label, List<List<String>> sectionEventIds)?
      onDcvSectionEventIdsChanged;
  // Active Day View sub-mode — drives the timeline layout and week-strip
  // multi-day indicator.  Owned by AppShell; passed in on every rebuild.
  final DayViewSubMode daySubMode;

  @override
  State<CalendarTab> createState() => CalendarTabState();
}

class CalendarTabState extends State<CalendarTab>
    with TickerProviderStateMixin {
  // ── Logical state ────────────────────────────────────────────────────────────
  CalendarView _view = CalendarView.month;
  late DateTime _today = DateTime.now();
  late DateTime _selected = DateTime.now();
  int _dispYear = DateTime.now().year;
  int _dispMonth = DateTime.now().month; // 1–12

  // ── Year ↔ Month  (0 = year fully shown, 1 = month fully shown) ─────────────
  late final AnimationController _zoomCtrl;
  late final CurvedAnimation _zoomAnim;
  int _zoomMonthIdx = 0; // 0–11, which mini-month was tapped (sets zoom origin)
  double _zoomScrollOffset =
      0.0; // year-view scroll offset captured the moment zoom begins
  double _zoomPrevT = 1.0; // tracks previous t for t=0.5 header-snap crossing
  ScrollController _yearScrollCtrl = ScrollController();

  // ── Year scroll offset — same single carried-forward source-of-truth model
  // as _savedMonthScrollOffset above (see that field's doc for the full
  // rationale). Whichever year is departed last, its live scroll offset is
  // what the year swiped into opens at.
  double _savedYearScrollOffset = 0.0;

  // Cached ScrollControllers for the prev/next preview _YearView panels
  // shown on either side of the current year while a year swipe is in
  // flight — mirrors _prevPreviewScrollCtrl/_nextPreviewScrollCtrl for Month
  // View. Kept live-synced to the current year's scroll via
  // _syncYearPreviewScrollToCurrent so a swipe to an adjacent year already
  // shows the right scroll position from the first frame, with no
  // scroll-to-it-first requirement and no snap/flicker on commit.
  ScrollController? _prevYearPreviewScrollCtrl;
  String? _prevYearPreviewScrollKey;
  ScrollController? _nextYearPreviewScrollCtrl;
  String? _nextYearPreviewScrollKey;

  // ── Month scroll offset — single carried-forward source of truth ────────────
  // _savedMonthScrollOffset is NOT per-month memory. It is a single running
  // value: "wherever the Month View was scrolled to the moment it was last
  // left". That exact value is what the NEXT month shown — whichever one it
  // is, by swipe, by Day View, or by Year View — starts at. E.g.: scroll July
  // down, swipe to August → August opens already at that offset (not its own
  // remembered position, not top). Scroll August back to top, swipe back to
  // July → July now opens at top too, because top is what August (the month
  // being left) last held. The currently-departed month's offset always wins;
  // no month "owns" a private scroll memory.
  //
  // Every transition keeps this single value current and applies it to
  // whatever mounts next:
  //   • Month ↔ Month (_applyPrev/_applyNext, month case): capture the
  //     outgoing month's live offset, then recreate _monthViewScrollCtrl with
  //     it as the initial offset (the panel remounts under a new ValueKey, so
  //     the controller must already own the value before that Scrollable
  //     attaches — jumpTo() alone is not reliable across a remount, and this
  //     avoids any flicker from landing at 0 first).
  //   • Month → Day  (_enterDay):       captures current offset into it.
  //   • Day   → Month (_exitToMonth):   sets _collapseScrollOffset = saved AND
  //                                     jumpTo(saved) BEFORE reverse() so the
  //                                     animation carries the offset throughout.
  //   • Month → Year (_exitToYear):     captures current offset into it.
  //   • Year  → Month (_onZoomTick):    jumpTo(saved) on the first frame zoomT
  //                                     crosses 0.999 (MonthView just mounted).
  //   • Morph overlay:                  monthScrollOffset = saved is passed so
  //                                     the morph's t=1 frame matches the
  //                                     scrolled MonthView with no pop.
  //
  // _collapseScrollOffset: the value of _savedMonthScrollOffset at the moment
  //   _enterDay / _exitToMonth is called.  Factored into each _AnimatedWeekRow's
  //   translateY so the selected row slides to visual-y = 0 (enter) or back
  //   to its scrolled natural position (exit) regardless of prior scrolling.
  //   Reset to 0 once collapseCtrl settles in either direction (collapseProgress
  //   is 0 or 1, so any value × 0 has no effect after the animation).
  ScrollController _monthViewScrollCtrl = ScrollController();
  final GlobalKey _monthViewScrollViewportKey = GlobalKey();
  final Map<String, List<String>> _monthListOrderByDay = {};
  double _collapseScrollOffset = 0.0;
  double _savedMonthScrollOffset = 0.0;

  // Cached ScrollControllers for the prev/next preview _MonthView panels
  // shown (IgnorePointer'd) on either side of the current panel while a
  // month swipe is in flight. Without their own controller they always
  // render scrolled to top (offset 0), so a swipe into a month the user
  // had previously scrolled produces a visible flicker — unscrolled for
  // the whole slide, then snapping to the right offset only at commit
  // (when _applyPrev/_applyNext promotes the panel to "current" and hands
  // it the real, correctly-offset _monthViewScrollCtrl). Keeping a
  // same-offset controller alive for the preview panel's whole lifetime
  // (recreated only when its ValueKey changes) makes it look correct from
  // the first frame of the slide.
  ScrollController? _prevPreviewScrollCtrl;
  String? _prevPreviewScrollKey;
  ScrollController? _nextPreviewScrollCtrl;
  String? _nextPreviewScrollKey;

  // While at rest in Day View, _collapseScrollOffset is always 0.0 (it is
  // only non-zero mid-animation, during the enter/exit collapse itself —
  // see the field doc above). The pinned week-row's on-screen position is
  // (content top, which reads _collapseScrollOffset) minus (the "current"
  // panel's live SingleChildScrollView pixel offset, i.e.
  // _monthViewScrollCtrl's actual attached offset). Those two must match
  // for the row to land at y = 0.
  //
  // Day-view navigation that crosses a month/year boundary changes the
  // "current" _MonthView's ValueKey ('$_dispYear-$_dispMonth'), forcing a
  // full remount. A remounted Scrollable re-attaches to the SAME
  // _monthViewScrollCtrl instance via createScrollPosition(), which seeds
  // the new position from the controller's *original* initialScrollOffset
  // (fixed at the controller's last dispose+recreate — e.g. whatever the
  // user had scrolled to in Month View) — NOT from wherever jumpTo() last
  // left it. That stale, usually-nonzero offset no longer matches
  // _collapseScrollOffset's steady-state 0.0, so the pinned row renders
  // offset from the viewport and the week strip appears to vanish.
  //
  // Fix: whenever a Day-View navigation step is about to cross a
  // month/year boundary, dispose+recreate the controller with
  // initialScrollOffset: 0.0 so the remounted Scrollable starts in sync
  // with _collapseScrollOffset.
  void _resyncMonthCtrlForDayView() {
    _monthViewScrollCtrl.removeListener(_syncPreviewScrollToCurrent);
    _monthViewScrollCtrl.dispose();
    _monthViewScrollCtrl = ScrollController()
      ..addListener(_syncPreviewScrollToCurrent);
  }

  // Keeps the (already-mounted, IgnorePointer'd) prev/next preview MonthView
  // panels' scroll offsets mirrored to the current month's LIVE scroll
  // position as the user scrolls — not just at the moment a preview panel is
  // first created (see _previewScrollCtrl doc below). Per the single
  // carried-forward source-of-truth model, whatever the current month is
  // scrolled to right now is what an adjacent month should also show the
  // instant a swipe begins; without this, scrolling the current month after
  // its preview panels were built leaves those panels stale at whatever
  // offset they had when created, so swiping to one produces a visible
  // snap/flicker as it catches up only at commit.
  void _syncPreviewScrollToCurrent() {
    if (!_monthViewScrollCtrl.hasClients) return;
    final double offset = _monthViewScrollCtrl.offset;
    if (_prevPreviewScrollCtrl?.hasClients == true) {
      _prevPreviewScrollCtrl!.jumpTo(offset);
    }
    if (_nextPreviewScrollCtrl?.hasClients == true) {
      _nextPreviewScrollCtrl!.jumpTo(offset);
    }
  }

  // Mirrors _syncPreviewScrollToCurrent for Year View — keeps the prev/next
  // preview _YearView panels' scroll offsets pinned to _yearScrollCtrl's
  // LIVE offset as the user scrolls the current year, not just at the
  // moment a preview panel is created.
  void _syncYearPreviewScrollToCurrent() {
    if (!_yearScrollCtrl.hasClients) return;
    final double offset = _yearScrollCtrl.offset;
    if (_prevYearPreviewScrollCtrl?.hasClients == true) {
      _prevYearPreviewScrollCtrl!.jumpTo(offset);
    }
    if (_nextYearPreviewScrollCtrl?.hasClients == true) {
      _nextYearPreviewScrollCtrl!.jumpTo(offset);
    }
  }

  ScrollController _previewYearScrollCtrl({
    required bool isPrev,
    required String key,
  }) {
    final double offset = _yearScrollCtrl.hasClients
        ? _yearScrollCtrl.offset
        : _savedYearScrollOffset;
    if (isPrev) {
      if (_prevYearPreviewScrollKey != key) {
        _prevYearPreviewScrollCtrl?.dispose();
        _prevYearPreviewScrollCtrl = ScrollController(
          initialScrollOffset: offset,
        );
        _prevYearPreviewScrollKey = key;
      }
      return _prevYearPreviewScrollCtrl!;
    } else {
      if (_nextYearPreviewScrollKey != key) {
        _nextYearPreviewScrollCtrl?.dispose();
        _nextYearPreviewScrollCtrl = ScrollController(
          initialScrollOffset: offset,
        );
        _nextYearPreviewScrollKey = key;
      }
      return _nextYearPreviewScrollCtrl!;
    }
  }

  ScrollController _previewScrollCtrl({
    required bool isPrev,
    required String key,
  }) {
    final double offset = _monthViewScrollCtrl.hasClients
        ? _monthViewScrollCtrl.offset
        : _savedMonthScrollOffset;
    if (isPrev) {
      if (_prevPreviewScrollKey != key) {
        _prevPreviewScrollCtrl?.dispose();
        _prevPreviewScrollCtrl = ScrollController(initialScrollOffset: offset);
        _prevPreviewScrollKey = key;
      }
      return _prevPreviewScrollCtrl!;
    } else {
      if (_nextPreviewScrollKey != key) {
        _nextPreviewScrollCtrl?.dispose();
        _nextPreviewScrollCtrl = ScrollController(initialScrollOffset: offset);
        _nextPreviewScrollKey = key;
      }
      return _nextPreviewScrollCtrl!;
    }
  }

  // GlobalKeys placed on each of the 4 year-view row groups so we can read
  // their actual rendered top positions right before the zoom animation starts.
  // Measured tops are stored here and fed to _MorphOverlay so it uses exact
  // Flutter-layout positions rather than a formula that can drift due to
  // sub-pixel font metrics or layout rounding.
  final List<GlobalKey> _yearRowKeys = List.generate(4, (_) => GlobalKey());
  List<double>?
  _yearMeasuredRowTops; // natural tops (scroll-offset-independent)

  // GlobalKey for the center _DayBanner — keeps morph animation state alive
  // when the parent switches between the Single Day 3-panel Stack and the
  // Multi Day single-instance layout (local keys cannot survive that change).
  final GlobalKey<_DayBannerState> _bannerCenterKey =
      GlobalKey<_DayBannerState>();

  // ── Month ↔ Day  (0 = month, 1 = day) ────────────────────────────────────────
  late final AnimationController _collapseCtrl;
  late final CurvedAnimation _collapseAnim;
  int _collapseRow = 0; // which week-row stays pinned during day transition
  int _settleCount =
      0; // incremented on cross-week navigation; triggers settle anim

  // ── Slide / swipe-between-adjacent-views ─────────────────────────────────────
  double _slideX = 0.0; // live drag or snap offset (logical px)
  double _blobDeltaX = 0.0; // current-frame gesture delta → blob stretch
  int _blobSnapCount = 0; // incremented on release → triggers spring-back
  // Per-frame drag invalidation stays local to the calendar animation builder.
  // Unlike setState(), this does not rebuild CalendarTab's surrounding state
  // or update every unrelated subtree while a finger is moving.
  final ValueNotifier<int> _dragFrameTick = ValueNotifier<int>(0);
  double _screenW = 393.0; // updated from LayoutBuilder each build
  int _snapGeneration =
      0; // incremented on each _animateSlide call; stale Futures compare and bail
  bool _snapThenFired =
      false; // true once doThen() fires; guards interrupt restore
  bool _navLocked = false; // true from nav-commit until anim fully settles
  bool _weekStripDrag =
      false; // true when drag started in the Day-View week strip
  Timer? _bloomTimer; // fires onBloom at 55% for pre-bloom visual
  DateTime? _pendingBloomDate; // target day for the 55% pre-bloom animation
  late final AnimationController _snapCtrl;
  late Animation<double> _snapAnim;

  // ── Real-time clock for the Day View time indicator ──────────────────────────
  // ValueNotifier updated at every minute boundary so _DayTimeline rebuilds
  // in lock-step with the real-world clock without any internal polling.
  late final ValueNotifier<DateTime> _nowNotifier;
  Timer? _clockTimer;

  // ── List-mode strip-slide ─────────────────────────────────────────────────────
  // Drives the week strip off-screen above the header when in List Day View.
  //   0.0 → strip at its normal Day View pinned position
  //   1.0 → strip translated -(kDayLabelHeight + kRowHeightList) above viewport
  // Multiplied by colT so the effect is zero while in Month/Year View.
  late final AnimationController _listModeCtrl;

  // ── View-mode state ───────────────────────────────────────────────────────────
  CalendarViewMode _viewMode = CalendarViewMode.compact;
  // _fromHeight / _toHeight are captured before each animation so
  // mid-animation mode switches start from the current interpolated value.
  double _fromHeight = _kRowHeightCompact;
  double _toHeight = _kRowHeightCompact;
  late final AnimationController _viewModeCtrl;

  // ── Search overlay ────────────────────────────────────────────────────────────
  final TextEditingController _searchCtrl = TextEditingController();
  final _searchBarKey = GlobalKey<AppSearchBarState>();
  // Keep the Liquid Glass cancel control alive when the search row moves
  // between the calendar content and its full-screen search overlay.
  final _searchCancelKey = GlobalKey();
  bool _greyActive = false;
  bool _greyFadeIn = false;
  bool _searchFocused = false;
  String _searchText = '';

  // ── Smart search results (filled asynchronously by _scheduleSearch) ────────
  List<SearchHit> _searchHits = [];
  String? _searchSuggestion;
  Timer? _searchDebounce;

  // ── Public API used by AppShell header ───────────────────────────────────────

  /// Opens the New Event modal sheet.  Called from AppShell's + button.
  void showNewEventSheet(
    BuildContext shellContext, {
    String? initialCategoryId,
  }) {
    showRoundedCupertinoSheet<void>(
      context: shellContext,
      pageBuilder: (ctx) =>
          _NewEventSheet(
            initialCategoryId: initialCategoryId,
            dcvSectionNamesProvider: widget.dcvSectionNamesProvider,
            dcvSectionEventIdsProvider: widget.dcvSectionEventIdsProvider,
            onDcvSectionEventIdsChanged: widget.onDcvSectionEventIdsChanged,
          ),
    );
  }

  /// Opens the event sheet pre-populated with [event] so the user can
  /// change its fields.  Saving calls [EventStore.update] instead of
  /// [EventStore.create], preserving the original event id.
  ///
  /// Called from AppShell when EventsTab's onEditEvent fires.
  void showEditEventSheet(BuildContext shellContext, ScheduledEvent event) {
    showRoundedCupertinoSheet<void>(
      context: shellContext,
      pageBuilder: (ctx) => _NewEventSheet(
        initial: event,
        dcvSectionNamesProvider: widget.dcvSectionNamesProvider,
        dcvSectionEventIdsProvider: widget.dcvSectionEventIdsProvider,
        onDcvSectionEventIdsChanged: widget.onDcvSectionEventIdsChanged,
      ),
    );
  }

  String get headerTitle {
    final t = _zoomCtrl.value;
    switch (_view) {
      case CalendarView.year:
        // month→year reverse: keep month title until t drops below 0.35
        if (t >= 0.35) return _kMonthNames[_zoomMonthIdx];
        return '$_dispYear';
      case CalendarView.month:
        // year→month forward: keep year title until t reaches 0.65
        if (t < 0.65) return '$_dispYear';
        return _kMonthNames[_dispMonth - 1];
      case CalendarView.day:
        return '${_kShortMonthNames[_selected.month - 1]} ${_selected.day}';
    }
  }

  // Prev / current / next titles for the three-panel header slide.
  (String, String, String) _adjacentTitles() {
    final curr = headerTitle;
    final t = _zoomCtrl.value;
    // During morph, return adjacent titles matching whichever view owns the title
    if (t > 0.01 && t < 0.99) {
      if (t >= 0.65) {
        final prevM = _dispMonth == 1
            ? (_dispYear - 1, 12)
            : (_dispYear, _dispMonth - 1);
        final nextM = _dispMonth == 12
            ? (_dispYear + 1, 1)
            : (_dispYear, _dispMonth + 1);
        return (_kMonthNames[prevM.$2 - 1], curr, _kMonthNames[nextM.$2 - 1]);
      } else {
        return ('${_dispYear - 1}', curr, '${_dispYear + 1}');
      }
    }
    switch (_view) {
      case CalendarView.year:
        return ('${_dispYear - 1}', curr, '${_dispYear + 1}');
      case CalendarView.month:
        final prevM = _dispMonth == 1
            ? (_dispYear - 1, 12)
            : (_dispYear, _dispMonth - 1);
        final nextM = _dispMonth == 12
            ? (_dispYear + 1, 1)
            : (_dispYear, _dispMonth + 1);
        return (_kMonthNames[prevM.$2 - 1], curr, _kMonthNames[nextM.$2 - 1]);
      case CalendarView.day:
        final prevD = _selected.subtract(const Duration(days: 1));
        final nextD = _selected.add(const Duration(days: 1));
        return (
          '${_kShortMonthNames[prevD.month - 1]} ${prevD.day}',
          curr,
          '${_kShortMonthNames[nextD.month - 1]} ${nextD.day}',
        );
    }
  }

  // ── Search overlay public API ─────────────────────────────────────────────────
  void activateSearchMode() {
    if (_searchFocused) return;
    setState(() {
      _greyActive = true;
      _greyFadeIn = true;
      _searchFocused = true;
    });
    sbSearchModeActive = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        NativeTextInput.focus(_searchCtrl);
        NativeTextInput.lockFocus(_searchCtrl);
      }
    });
  }

  /// Unfocus the keyboard but keep the overlay alive (called when switching
  /// away from the Calendar tab while search is active).
  void preserveSearch() {
    NativeTextInput.unlockFocus(_searchCtrl);
    NativeTextInput.unfocusAll();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  /// Re-focus the search bar when returning to the Calendar tab while the
  /// preserved overlay is still showing.
  void restoreSearch() {
    sbSearchModeActive = true;
    NativeTextInput.focus(_searchCtrl);
    NativeTextInput.lockFocus(_searchCtrl);
  }

  void cancelSearch() {
    _searchBarKey.currentState?.cancelMic();
    _searchDebounce?.cancel();
    sbSearchModeActive = false;
    _searchCtrl.clear();
    NativeTextInput.unlockFocus(_searchCtrl);
    NativeTextInput.unfocusAll();
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _searchFocused = false;
      _searchText = '';
      _searchSuggestion = null;
      _greyFadeIn = false;
      _greyActive = false;
      _searchHits = [];
    });
    widget.onSearchCancel?.call();
  }

  /// Debounced 150 ms smart search across all events.
  void _scheduleSearch() {
    _searchDebounce?.cancel();
    final q = _searchText.trim();
    if (q.isEmpty) {
      if (_searchHits.isNotEmpty) {
        setState(() {
          _searchHits = [];
          _searchSuggestion = null;
        });
      }
      return;
    }
    _searchDebounce = Timer(const Duration(milliseconds: 150), () async {
      // Search globally across concrete recurring occurrences, not only the
      // raw events currently visible in this calendar view.
      final all = EventStore.instance.expandedEvents();
      final results = await SearchService().query(q, all);
      if (!mounted || _searchText.trim() != q) return;
      setState(() {
        _searchHits = results.all;
        _searchSuggestion = results.suggestedQuery;
      });
    });
  }

  void _applySearchSuggestion(String suggestion) {
    _searchCtrl.value = TextEditingValue(
      text: suggestion,
      selection: TextSelection.collapsed(offset: suggestion.length),
    );
    NativeTextInput.focus(_searchCtrl);
  }

  // ↑ = go deeper into detail
  void navigateUp() {
    switch (_view) {
      case CalendarView.year:
        _enterMonth(_dispMonth - 1);
        break;
      case CalendarView.month:
        final target =
            _selected.month == _dispMonth && _selected.year == _dispYear
            ? _selected
            : DateTime(_dispYear, _dispMonth, 1);
        _enterDay(target);
        break;
      case CalendarView.day:
        break;
    }
  }

  // ↓ = go back to overview
  void navigateDown() {
    switch (_view) {
      case CalendarView.year:
        break;
      case CalendarView.month:
        _exitToYear();
      case CalendarView.day:
        _exitToMonth();
    }
  }

  // Chevrons call these — both now drive the same slide animation
  void navigatePrev() => _swipeNavigate(1);
  void navigateNext() => _swipeNavigate(-1);

  /// Immediately opens today's Day View.
  ///
  /// This is kept as the fallback for callers that need a hard reset (for
  /// example, when the shortcut is pressed while showing a different year).
  void jumpToTodayDay() {
    final today = DateTime.now();

    _snapCtrl.stop();
    _zoomCtrl.stop();
    _collapseCtrl.stop();
    _slideX = 0.0;
    _weekStripDrag = false;
    _navLocked = false;
    _zoomPrevT = 1.0;

    setState(() {
      _view = CalendarView.day;
      _selected = today;
      _today = today;
      _dispYear = today.year;
      _dispMonth = today.month;
      _collapseRow = _weekRowForDate(today);
      _collapseScrollOffset = 0.0;
      _savedMonthScrollOffset = 0.0;
      _zoomCtrl.value = 1.0;
      _collapseCtrl.value = 1.0;
    });
    _notify();
  }

  /// Opens today's Day View from Year View using the same hierarchy transition
  /// as the current-date header title, but in the opposite direction:
  /// Year → Month → Day.
  Future<void> enterTodayDay() async {
    if (_snapCtrl.isAnimating ||
        _zoomCtrl.isAnimating ||
        _collapseCtrl.isAnimating) {
      return;
    }

    final today = DateTime.now();
    if (_view != CalendarView.year) {
      jumpToTodayDay();
      return;
    }
    final displayedYear = _dispYear;

    // Let the existing Year → Month morph fully land before starting the
    // existing Month → Day collapse.  This keeps the two transitions visually
    // continuous instead of replacing the year grid with a day timeline.
    await _enterMonth(today.month - 1, fast: true);
    if (!mounted || _view != CalendarView.month) return;
    if (displayedYear != today.year) {
      // The shortcut always targets the real current day.  If the user was
      // browsing another year, keep the animated hierarchy transition and
      // switch the settled month panel to today's year before collapsing it.
      setState(() {
        _dispYear = today.year;
        _dispMonth = today.month;
      });
      _notify();
    }
    _enterDay(today, fast: true);
  }

  /// Advances through today's calendar hierarchy when the current header title
  /// is tapped: Year → Month → Day → Year.
  ///
  /// The title callback is only exposed for today's visible title by AppShell,
  /// but the date/view checks stay here so the state transition remains safe
  /// if another caller invokes this method.
  Future<void> advanceCurrentHeader() async {
    if (_snapCtrl.isAnimating ||
        _zoomCtrl.isAnimating ||
        _collapseCtrl.isAnimating) {
      return;
    }

    final today = DateTime.now();
    switch (_view) {
      case CalendarView.year:
        if (_dispYear == today.year) {
          await _enterMonth(today.month - 1);
        }
        return;
      case CalendarView.month:
        if (_dispYear == today.year && _dispMonth == today.month) {
          _enterDay(today);
        }
        return;
      case CalendarView.day:
        if (!_sameDay(_selected, today)) return;
        await _exitToMonth(fast: true);
        if (!mounted) return;
        await _exitToYear(fast: true);
    }
  }

  // dir = +1: content slides RIGHT → previous appears from the left
  // dir = -1: content slides LEFT  → next appears from the right
  void _swipeNavigate(int dir) {
    if (_snapCtrl.isAnimating) return;
    final isNext = dir < 0;
    _animateSlide(
      from: 0.0,
      to: dir * _screenW,
      then: isNext ? _applyNext : _applyPrev,
      onBloom: _computeBloom(isNext: isNext),
    );
  }

  void _applyPrev() {
    switch (_view) {
      case CalendarView.year:
        // Carry the outgoing year's live offset forward, mirroring the Month
        // View carry-forward model above _monthViewScrollCtrl.
        if (_yearScrollCtrl.hasClients) {
          _savedYearScrollOffset = _yearScrollCtrl.offset;
        }
        _yearScrollCtrl.removeListener(_syncYearPreviewScrollToCurrent);
        _yearScrollCtrl.dispose();
        _yearScrollCtrl = ScrollController(
          initialScrollOffset: _savedYearScrollOffset,
        )..addListener(_syncYearPreviewScrollToCurrent);
        setState(() => _dispYear--);
        _notify();
      case CalendarView.month:
        // Carry the outgoing month's live offset forward as-is — it becomes
        // the source of truth the incoming month opens at (see the field doc
        // above _monthViewScrollCtrl for the exact carry-forward model).
        if (_monthViewScrollCtrl.hasClients) {
          _savedMonthScrollOffset = _monthViewScrollCtrl.offset;
        }
        // A fresh Scrollable mounts under the new ValueKey('$year-$month'),
        // so the controller must already own the carried value as its
        // initialScrollOffset before that Scrollable attaches — this avoids
        // any flicker from landing at 0 first.
        _monthViewScrollCtrl.removeListener(_syncPreviewScrollToCurrent);
        _monthViewScrollCtrl.dispose();
        _monthViewScrollCtrl = ScrollController(
          initialScrollOffset: _savedMonthScrollOffset,
        )..addListener(_syncPreviewScrollToCurrent);
        setState(() {
          _dispMonth--;
          if (_dispMonth < 1) {
            _dispMonth = 12;
            _dispYear--;
          }
        });
        _notify();
      case CalendarView.day:
        final d = _selected.subtract(const Duration(days: 1));
        // The collapse formula is built around the PAIR (collapseRow, savedOffset)
        // captured when the user entered Day View.  If navigation changes the
        // collapse row (different week, or different month) the two values become
        // inconsistent: the formula tries to animate the new row to the old
        // scroll target, which puts the strip above the viewport.
        // Resetting savedOffset whenever the row changes keeps the pair in sync.
        final newRowPrev = _weekRowForDate(d);
        final crossedMonthPrev =
            d.month != _selected.month || d.year != _selected.year;
        if (crossedMonthPrev || newRowPrev != _collapseRow) {
          _savedMonthScrollOffset = 0.0;
        }
        if (crossedMonthPrev) _resyncMonthCtrlForDayView();
        setState(() {
          _selected = d;
          _dispYear = d.year;
          _dispMonth = d.month;
          _collapseRow = newRowPrev;
        });
        _notify();
    }
  }

  void _applyNext() {
    switch (_view) {
      case CalendarView.year:
        // Carry the outgoing year's live offset forward, mirroring the Month
        // View carry-forward model above _monthViewScrollCtrl.
        if (_yearScrollCtrl.hasClients) {
          _savedYearScrollOffset = _yearScrollCtrl.offset;
        }
        _yearScrollCtrl.removeListener(_syncYearPreviewScrollToCurrent);
        _yearScrollCtrl.dispose();
        _yearScrollCtrl = ScrollController(
          initialScrollOffset: _savedYearScrollOffset,
        )..addListener(_syncYearPreviewScrollToCurrent);
        setState(() => _dispYear++);
        _notify();
      case CalendarView.month:
        // Carry the outgoing month's live offset forward as-is — it becomes
        // the source of truth the incoming month opens at (see the field doc
        // above _monthViewScrollCtrl for the exact carry-forward model).
        if (_monthViewScrollCtrl.hasClients) {
          _savedMonthScrollOffset = _monthViewScrollCtrl.offset;
        }
        // A fresh Scrollable mounts under the new ValueKey('$year-$month'),
        // so the controller must already own the carried value as its
        // initialScrollOffset before that Scrollable attaches — this avoids
        // any flicker from landing at 0 first.
        _monthViewScrollCtrl.removeListener(_syncPreviewScrollToCurrent);
        _monthViewScrollCtrl.dispose();
        _monthViewScrollCtrl = ScrollController(
          initialScrollOffset: _savedMonthScrollOffset,
        )..addListener(_syncPreviewScrollToCurrent);
        setState(() {
          _dispMonth++;
          if (_dispMonth > 12) {
            _dispMonth = 1;
            _dispYear++;
          }
        });
        _notify();
      case CalendarView.day:
        final d = _selected.add(const Duration(days: 1));
        // See _applyPrev Day case: reset savedOffset whenever the collapse row
        // changes to keep the (collapseRow, savedOffset) pair consistent.
        final newRowNext = _weekRowForDate(d);
        final crossedMonthNext =
            d.month != _selected.month || d.year != _selected.year;
        if (crossedMonthNext || newRowNext != _collapseRow) {
          _savedMonthScrollOffset = 0.0;
        }
        if (crossedMonthNext) _resyncMonthCtrlForDayView();
        setState(() {
          _selected = d;
          _dispYear = d.year;
          _dispMonth = d.month;
          _collapseRow = newRowNext;
        });
        _notify();
    }
  }

  // Animate _slideX from [from] → [to], commit navigation, then reset.
  //
  // Navigation ([then]) fires at animation COMPLETION (100%), not early.
  // This prevents the ±2 panel-remap bug (see calendar-3panel-plusminus2-bug.md).
  //
  // [onBloom] is an OPTIONAL visual-only callback fired at ~55% of the
  // animation.  It sets _pendingBloomDate so _BloomDayCircle on the incoming
  // day starts its settle animation while the slide is still in motion — the
  // bloom is ~70% complete when the swipe lands.  It does NOT touch panel
  // slots, so the ±2 issue cannot recur.
  void _animateSlide({
    required double from,
    required double to,
    required VoidCallback then,
    VoidCallback? onBloom,
  }) {
    _snapThenFired = false;
    final myGen = ++_snapGeneration;

    setState(() => _slideX = from);
    _snapAnim = Tween<double>(
      begin: from,
      end: to,
    ).animate(CurvedAnimation(parent: _snapCtrl, curve: Curves.easeOutCubic));

    // Fire pre-bloom at 55% of animation (≈102ms of 185ms).
    if (onBloom != null) {
      _bloomTimer = Timer(
        Duration(
          milliseconds: (_snapCtrl.duration!.inMilliseconds * 0.55).round(),
        ),
        () {
          if (!mounted || _snapGeneration != myGen) return;
          onBloom();
        },
      );
    }

    _snapCtrl.forward(from: 0).then((_) {
      _bloomTimer?.cancel();
      if (!mounted || _snapGeneration != myGen) return;
      _snapThenFired = true;
      _slideX = 0.0;
      widget.onStripSlide?.call(0.0);
      then();
      // Clear pending bloom now that nav has committed.
      if (_pendingBloomDate != null) setState(() => _pendingBloomDate = null);
      _snapCtrl.reset();
      if (mounted) setState(() => _navLocked = false);
    });
  }

  // Pre-computes whether the upcoming swipe should start a bloom animation on
  // the target day, and returns a callback that sets _pendingBloomDate.
  // Returns null when no bloom is needed (non-day views, no week/month crossing).
  VoidCallback? _computeBloom({required bool isNext}) {
    if (_view != CalendarView.day) return null;
    late final DateTime target;
    late final bool shouldBloom;
    if (_weekStripDrag) {
      // Week-strip swipe: always bloom the incoming day (any 7-day jump is
      // a significant step and deserves visual confirmation).
      target = isNext
          ? _selected.add(const Duration(days: 7))
          : _selected.subtract(const Duration(days: 7));
      shouldBloom = true;
    } else {
      // Single-day swipe: bloom only on cross-week or cross-month boundary.
      target = isNext
          ? _selected.add(const Duration(days: 1))
          : _selected.subtract(const Duration(days: 1));
      final isCrossWeek = isNext
          ? _selected.weekday ==
                7 // Sun → Mon
          : _selected.weekday == 1; // Mon → Sun
      final isCrossMonth = target.month != _selected.month;
      shouldBloom = isCrossWeek || isCrossMonth;
    }
    if (!shouldBloom) return null;
    return () => setState(() => _pendingBloomDate = target);
  }

  void _applyPrevWeek() {
    final d = _selected.subtract(const Duration(days: 7));
    final newRow = _weekRowForDate(d);
    final crossedMonth = d.month != _selected.month || d.year != _selected.year;
    // Keep (collapseRow, savedOffset) pair consistent — see _applyPrev Day case.
    if (crossedMonth || newRow != _collapseRow) {
      _savedMonthScrollOffset = 0.0;
    }
    if (crossedMonth) _resyncMonthCtrlForDayView();
    setState(() {
      _selected = d;
      _dispYear = d.year;
      _dispMonth = d.month;
      _collapseRow = newRow;
    });
    _notify();
  }

  void _applyNextWeek() {
    final d = _selected.add(const Duration(days: 7));
    final newRow = _weekRowForDate(d);
    final crossedMonth = d.month != _selected.month || d.year != _selected.year;
    // Keep (collapseRow, savedOffset) pair consistent — see _applyPrev Day case.
    if (crossedMonth || newRow != _collapseRow) {
      _savedMonthScrollOffset = 0.0;
    }
    if (crossedMonth) _resyncMonthCtrlForDayView();
    setState(() {
      _selected = d;
      _dispYear = d.year;
      _dispMonth = d.month;
      _collapseRow = newRow;
    });
    _notify();
  }

  // ── Horizontal drag callbacks (attached only when fully in one view) ─────────
  void _onHDragStart(DragStartDetails d) {
    if (_snapCtrl.isAnimating) {
      _snapCtrl.stop();
      _bloomTimer?.cancel(); // cancels timer so stale doThen() never fires;
      // stale .then() Future is neutralised by _snapGeneration.
      // _navLocked is already true (set in _onHDragEnd the moment navigation
      // was committed), so nothing extra needs to be set here.
      //
      // Restore _slideX: if doThen() already fired it reset _slideX to 0 —
      // use that rather than the now-stale animation position.
      setState(() => _slideX = _snapThenFired ? 0.0 : _snapAnim.value);
    }
    // In Day View, track whether drag started inside the pinned week strip
    // so _onHDragEnd can navigate weeks instead of days.
    // In List mode the week strip is hidden behind the cover overlay, so a
    // drag in that zone should NOT be treated as a week-strip navigation drag.
    _weekStripDrag =
        _view == CalendarView.day &&
        widget.daySubMode != DayViewSubMode.list &&
        d.localPosition.dy <
            _kDayLabelHeight + _dayViewWeekStripHeight(context);
  }

  void _onHDragUpdate(DragUpdateDetails d) {
    _slideX = (_slideX + d.delta.dx).clamp(-_screenW, _screenW);
    _blobDeltaX = d.delta.dx; // per-frame velocity for blob stretch
    _dragFrameTick.value++;
    widget.onStripSlide?.call(_slideX);
  }

  void _onHDragEnd(DragEndDetails d) {
    // Reset blob delta and trigger spring-back before the snap animation fires.
    setState(() {
      _blobDeltaX = 0.0;
      _blobSnapCount++;
    });

    // Hard guard: a navigation was already committed by a previous gesture but
    // its settle animation hasn't finished yet (or the gesture system fired a
    // stale end event before the widget rebuilt with null callbacks).
    // Snap the rubber-band back to centre — do NOT clear _navLocked here.
    // The _animateSlide completion callback (line ~390) releases the lock once
    // the snap-back settles, preventing a rapid second drag-end from firing a
    // second navigation step (the ±2 bug).
    if (_navLocked) {
      _animateSlide(from: _slideX, to: 0.0, then: () {});
      return;
    }

    final vel = d.velocity.pixelsPerSecond.dx;
    const frac = 0.35;
    // Week-strip drag navigates weeks; everything else navigates days/months/years.
    final applyP = _weekStripDrag ? _applyPrevWeek : _applyPrev;
    final applyN = _weekStripDrag ? _applyNextWeek : _applyNext;
    if (_slideX > _screenW * frac || vel > 500) {
      _navLocked = true;
      _animateSlide(
        from: _slideX,
        to: _screenW,
        then: applyP,
        onBloom: _computeBloom(isNext: false),
      );
    } else if (_slideX < -_screenW * frac || vel < -500) {
      _navLocked = true;
      _animateSlide(
        from: _slideX,
        to: -_screenW,
        then: applyN,
        onBloom: _computeBloom(isNext: true),
      );
    } else {
      _animateSlide(from: _slideX, to: 0.0, then: () {});
    }
  }

  // ── Private helpers ───────────────────────────────────────────────────────────
  void _notify() {
    final (prev, curr, next) = _adjacentTitles();
    widget.onViewChanged(_view, _dispYear, prev, curr, next);
  }

  // Physics spring: mass 1, stiffness 180, damping 23 (lightly underdamped —
  // fast acceleration with a micro-snap at the end, no visible bounce).
  static const _kZoomSpring = SpringDescription(
    mass: 1.0,
    stiffness: 180.0,
    damping: 25.0,
  );

  // Chained Year ↔ Month ↔ Day transitions use the same visual springs but
  // complete each leg in roughly half the time, keeping the full two-step
  // journey close to the duration of a normal single navigation.
  static const _kHierarchyZoomSpring = SpringDescription(
    mass: 1.0,
    stiffness: 720.0,
    damping: 50.0,
  );

  // Exit spring: high stiffness + strong initial velocity so the collapse
  // starts fast and lands crisply — perceptibly quicker than the enter spring.
  static const _kZoomSpringExit = SpringDescription(
    mass: 1.0,
    stiffness: 680.0,
    damping: 46.0,
  );

  static const _kHierarchyZoomSpringExit = SpringDescription(
    mass: 1.0,
    stiffness: 2720.0,
    damping: 92.0,
  );

  static const _kHierarchyCollapseDuration = Duration(milliseconds: 185);

  // Reads each year-view row's actual rendered top from the GlobalKeys.
  // Must be called while the year view is in the tree (zoomT ≈ 0).
  // Stores scroll-independent "natural" y coordinates so _MorphOverlay can
  // use them in place of its formulaic rowTop, eliminating layout drift.
  void _measureYearRowTops() {
    final calBox = context.findRenderObject() as RenderBox?;
    if (calBox == null) return;
    final scrollOffset = _yearScrollCtrl.hasClients
        ? _yearScrollCtrl.offset
        : 0.0;
    final tops = <double>[];
    for (final key in _yearRowKeys) {
      final rowBox = key.currentContext?.findRenderObject() as RenderBox?;
      if (rowBox == null) return; // layout not ready; keep previous measurement
      final globalPos = rowBox.localToGlobal(Offset.zero);
      final localY = calBox.globalToLocal(globalPos).dy;
      // localY is the screen position; add scroll offset to get the natural
      // (scroll-independent) y so the overlay can subtract it back itself.
      tops.add(localY + scrollOffset);
    }
    if (tops.length == 4) _yearMeasuredRowTops = tops;
  }

  Future<void> _enterMonth(int monthIdx, {bool fast = false}) async {
    // Capture exact row positions before the zoom animation hides the YearView.
    _measureYearRowTops();
    _zoomScrollOffset = _yearScrollCtrl.hasClients
        ? _yearScrollCtrl.offset
        : 0.0;
    setState(() {
      _zoomMonthIdx = monthIdx;
      _dispMonth = monthIdx + 1;
      _view = CalendarView.month;
    });
    _notify();
    await _zoomCtrl.animateWith(
      SpringSimulation(
        fast ? _kHierarchyZoomSpring : _kZoomSpring,
        _zoomCtrl.value,
        1.0,
        0.0,
      ),
    );
    // Spring tolerance (~0.001) can leave the value just below 1.0.
    // Snap to the exact target so the morph condition (zoomT < 1.0) is
    // false and the overlay is cleared.
    if (mounted) _zoomCtrl.value = 1.0;
  }

  Future<void> _exitToYear({bool fast = false}) async {
    // Capture current month scroll before leaving so the position survives the
    // Year View excursion and is restored when the user taps back into a month.
    if (_monthViewScrollCtrl.hasClients) {
      _savedMonthScrollOffset = _monthViewScrollCtrl.offset;
    }
    setState(() => _zoomMonthIdx = _dispMonth - 1);
    await _zoomCtrl.animateWith(
      SpringSimulation(
        fast ? _kHierarchyZoomSpringExit : _kZoomSpringExit,
        _zoomCtrl.value,
        0.0,
        fast ? -28.0 : -14.0,
      ),
    );
    if (mounted) {
      _zoomCtrl.value = 0.0;
      setState(() => _view = CalendarView.year);
      _notify();
    }
  }

  // Fires _notify() at the header-snap thresholds:
  //   year→month: snap to month title at t = 0.65 (grid feels "landed")
  //   month→year: snap to year  title at t = 0.35 (65 % of reverse done)
  //
  // Year→Month scroll restoration:
  //   _MonthView is conditionally mounted only when zoomT > 0.999.  When
  //   _savedMonthScrollOffset > 0 we must NOT use addPostFrameCallback because
  //   that fires *after* the first _MonthView frame is already painted — causing
  //   a one-frame flash of the unscrolled grid.
  //
  //   Instead, the moment zoomT crosses 0.999 going upward we recreate
  //   _monthViewScrollCtrl with initialScrollOffset = _savedMonthScrollOffset
  //   and call setState().  Flutter then rebuilds with zoomT > 0.999 (so
  //   _MonthView IS mounted this rebuild) and the new controller already starts
  //   at the saved offset — _MonthView is first painted at the correct position
  //   with no flash whatsoever.
  //
  //   At that moment _monthViewScrollCtrl has no clients (zoomT was < 0.999 the
  //   previous frame, so _MonthView was unmounted), making dispose() safe.
  void _onZoomTick() {
    final t = _zoomCtrl.value;
    if (_zoomPrevT < 0.65 && t >= 0.65) _notify();
    if (_zoomPrevT >= 0.35 && t < 0.35) _notify();
    if (_zoomPrevT < 0.999 && t >= 0.999 && _savedMonthScrollOffset > 0) {
      // Recreate the controller with the saved offset as its initial position.
      // The old controller has no clients at this point (safe to dispose).
      _monthViewScrollCtrl.removeListener(_syncPreviewScrollToCurrent);
      _monthViewScrollCtrl.dispose();
      _monthViewScrollCtrl = ScrollController(
        initialScrollOffset: _savedMonthScrollOffset,
      )..addListener(_syncPreviewScrollToCurrent);
      // setState triggers a rebuild in which zoomT > 0.999, so _MonthView
      // mounts for the first time already positioned at _savedMonthScrollOffset.
      setState(() {});
    }
    _zoomPrevT = t;
  }

  void _enterDay(DateTime date, {bool fast = false}) {
    // Capture the current scroll offset of the month-view content area BEFORE
    // setState triggers a rebuild.  This value is used by _AnimatedWeekRow to
    // offset its Y-translation so the selected row lands at visual-y = 0 even
    // when the user has scrolled in Details mode.
    final capturedOffset = _monthViewScrollCtrl.hasClients
        ? _monthViewScrollCtrl.offset
        : 0.0;
    setState(() {
      _selected = date;
      _collapseRow = _weekRowForDate(date);
      _collapseScrollOffset = capturedOffset;
      _savedMonthScrollOffset = capturedOffset; // remembered for exit
      _view = CalendarView.day;
    });
    _notify();
    final collapse = fast
        ? _collapseCtrl.animateTo(
            1.0,
            duration: _kHierarchyCollapseDuration,
            curve: Curves.easeInOutCubic,
          )
        : _collapseCtrl.forward(from: _collapseCtrl.value);
    collapse.then((_) {
      if (!mounted) return;
      // Animation settled at colT=1.  The selected row is visually at y=0.
      // Reset the scroll controller and the captured compensation offset so
      // subsequent same-month Day-View navigation (fresh scroll at 0) works
      // without inheriting a stale base.  _savedMonthScrollOffset is kept
      // intact — it is only cleared once the user exits back to Month View.
      if (_monthViewScrollCtrl.hasClients) {
        _monthViewScrollCtrl.jumpTo(0);
      }
      if (mounted) setState(() => _collapseScrollOffset = 0.0);
    });
  }

  Future<void> _exitToMonth({bool fast = false}) async {
    // Restore the saved scroll position BEFORE starting the reverse animation
    // so that _collapseScrollOffset is non-zero throughout the reverse.
    // With _collapseScrollOffset = saved, _AnimatedWeekRow's translateY formula
    // keeps the selected row at visual-y = 0 at colT=1 and moves it smoothly
    // to its natural scrolled position at colT=0 — no pop, no jump.
    if (_savedMonthScrollOffset > 0) {
      if (_monthViewScrollCtrl.hasClients) {
        _monthViewScrollCtrl.jumpTo(_savedMonthScrollOffset);
      }
      setState(() => _collapseScrollOffset = _savedMonthScrollOffset);
    }
    if (fast) {
      await _collapseCtrl.animateBack(
        0.0,
        duration: _kHierarchyCollapseDuration,
        curve: Curves.easeInOutCubic,
      );
    } else {
      await _collapseCtrl.reverse();
    }
    if (!mounted) return;
    // Animation settled at colT=0.  collapseProgress is 0, so
    // _collapseScrollOffset no longer affects row positions — safe to clear.
    // _savedMonthScrollOffset is intentionally kept: the user is back in
    // Month View at that exact offset, and it must survive any subsequent
    // Year View excursion.
    setState(() {
      _view = CalendarView.month;
      _collapseScrollOffset = 0.0;
    });
    _notify();
  }

  @override
  void initState() {
    super.initState();
    _today = DateTime.now();
    _selected = DateTime.now();
    _monthViewScrollCtrl.addListener(_syncPreviewScrollToCurrent);
    _yearScrollCtrl.addListener(_syncYearPreviewScrollToCurrent);
    CategoryRegistry.revision.addListener(_onCategoryRegistryChanged);
    _zoomCtrl = AnimationController(
      vsync: this,
      value: 1.0, // start in month view
    );
    // Spring drives its own curve — linear passthrough keeps _zoomAnim ≡ _zoomCtrl
    _zoomAnim = CurvedAnimation(parent: _zoomCtrl, curve: Curves.linear);
    _collapseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 370),
    );
    _collapseAnim = CurvedAnimation(
      parent: _collapseCtrl,
      curve: Curves.easeInOutCubic,
    );
    _snapCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 185),
    );
    _snapAnim = const AlwaysStoppedAnimation(0.0);
    _searchCtrl.addListener(() {
      final t = _searchCtrl.text;
      if (t != _searchText) {
        setState(() => _searchText = t);
        _scheduleSearch();
      }
    });
    // Keep the AppShell header in sync with the week-strip during snap animations.
    // Guard with isAnimating so the extra listener tick fired by _snapCtrl.reset()
    // (which would restore the stale drag offset) is ignored.
    _snapCtrl.addListener(() {
      if (_snapCtrl.isAnimating) {
        widget.onStripSlide?.call(_snapAnim.value);
      }
    });
    // Snap the AppShell header title at t=0.5 during year↔month transition.
    _zoomCtrl.addListener(_onZoomTick);
    // List-mode strip-slide controller (280 ms, ease-in-out).
    // Pre-loaded to 1.0 when the app launches directly into List mode so the
    // strip starts off-screen without playing an enter animation.
    _listModeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.daySubMode == DayViewSubMode.list ? 1.0 : 0.0,
    );
    // View-mode transition controller (200 ms, ease-in-out).
    _viewModeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    // Load persisted view mode.
    SharedPreferences.getInstance().then((prefs) {
      final stored = prefs.getString(_kViewModePrefsKey);
      if (!mounted) return;
      final mode = CalendarViewMode.values.firstWhere(
        (m) => m.name == stored,
        orElse: () => CalendarViewMode.compact,
      );
      if (mode != CalendarViewMode.compact) setViewMode(mode, persist: false);
    });
    // Clock: fire at the next full minute, then every subsequent minute,
    // so the time indicator always jumps exactly when the real clock ticks over.
    _nowNotifier = ValueNotifier<DateTime>(DateTime.now());
    _scheduleClock();
    WidgetsBinding.instance.addPostFrameCallback((_) => _notify());
  }

  // Advances selection to [now] across all views when midnight rolls over.
  // Day View:              full panel slide (existing _swipeNavigate path).
  // Month/Year same panel: selection jumps + settle-bloom on the new day.
  // Month/Year cross panel: panel slide + settle-bloom on the new day.
  void _midnightAdvance(DateTime now) {
    if (_screenW == 0) return;
    final yesterday = now.subtract(const Duration(days: 1));
    if (!_sameDay(_selected, yesterday)) return;

    switch (_view) {
      case CalendarView.day:
        _swipeNavigate(-1); // slides panel; _applyNext updates _selected

      case CalendarView.month:
        final crossBoundary =
            now.month != yesterday.month || now.year != yesterday.year;
        if (crossBoundary) {
          // Slide to next month panel, then commit selection to today.
          _animateSlide(
            from: 0.0,
            to: -_screenW,
            then: () {
              setState(() {
                _selected = now;
                _dispYear = now.year;
                _dispMonth = now.month;
                _collapseRow = _weekRowForDate(now);
              });
              _notify();
            },
            onBloom: () => setState(() => _pendingBloomDate = now),
          );
        } else {
          // Same month — no panel slide; advance selection + bloom new cell.
          setState(() {
            _selected = now;
            _collapseRow = _weekRowForDate(now);
            _blobSnapCount++; // lets pre-bloom animate without restart
            _pendingBloomDate = now;
          });
          _notify();
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted && _pendingBloomDate != null) {
              setState(() => _pendingBloomDate = null);
            }
          });
        }

      case CalendarView.year:
        final crossBoundary = now.year != yesterday.year;
        if (crossBoundary) {
          _animateSlide(
            from: 0.0,
            to: -_screenW,
            then: () {
              setState(() {
                _selected = now;
                _dispYear = now.year;
                _dispMonth = now.month;
                _collapseRow = _weekRowForDate(now);
              });
              _notify();
            },
            onBloom: () => setState(() => _pendingBloomDate = now),
          );
        } else {
          setState(() {
            _selected = now;
            _collapseRow = _weekRowForDate(now);
            _blobSnapCount++;
            _pendingBloomDate = now;
          });
          _notify();
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted && _pendingBloomDate != null) {
              setState(() => _pendingBloomDate = null);
            }
          });
        }
    }
  }

  void _scheduleClock() {
    // Fire every second to keep the Day View time indicator live.
    // We deliberately do NOT call setState here on every tick — doing so
    // would rebuild the AnimatedBuilder/GestureDetector tree each second and
    // re-deliver stale drag-end events on web (the ±2 nav bug).
    // Instead: push the current time into _nowNotifier (picked up by
    // _DayTimeline's own ValueListenableBuilder) and call setState only on
    // the rare midnight transition so "today" highlights stay correct.
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final now = DateTime.now();
      final oldDay = _today;
      // Always update _nowNotifier so _DayTimeline's indicator ticks.
      _nowNotifier.value = now;
      // ── Midnight auto-advance ─────────────────────────────────────────────
      // When the calendar day rolls over, update _today via setState so the
      // "today" circle in month/year view repaints, then animate selection
      // forward in all views when the user was viewing yesterday.
      final dayChanged =
          now.day != oldDay.day ||
          now.month != oldDay.month ||
          now.year != oldDay.year;
      if (dayChanged) {
        setState(() => _today = now);
        _midnightAdvance(now);
      } else {
        // Not midnight — just keep _today in sync without triggering a rebuild.
        _today = now;
      }
    });
  }

  // ── View-mode public API ──────────────────────────────────────────────────────
  CalendarViewMode get viewMode => _viewMode;

  void setViewMode(CalendarViewMode mode, {bool persist = true}) {
    if (mode == _viewMode) return;
    // Snapshot the current interpolated height as the new "from" so a
    // mid-animation mode-switch starts from wherever the bar currently is.
    setState(() {
      _fromHeight = lerpDouble(_fromHeight, _toHeight, _viewModeCtrl.value)!;
      _toHeight = mode.rowHeight;
      _viewMode = mode;
    });
    _viewModeCtrl.forward(from: 0.0);
    if (persist) {
      SharedPreferences.getInstance().then(
        (p) => p.setString(_kViewModePrefsKey, mode.name),
      );
    }
  }

  @override
  void didUpdateWidget(covariant CalendarTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate the week strip on/off screen when the sub-mode changes while
    // already in Day View.  If the view is still collapsing (colT < 1) the
    // strip offset is driven purely by colT*_listModeCtrl so no extra gesture
    // is needed — the collapse animation carries it.
    if (oldWidget.daySubMode != widget.daySubMode) {
      // When the strip isn't visible (e.g. Month View on cold-start pref restore),
      // snap the controller value directly so there is no visible animation.
      // When already in Day View, animate so the strip slides smoothly on/off.
      final inDayView = _collapseAnim.value > 0.1;
      if (widget.daySubMode == DayViewSubMode.list) {
        if (inDayView)
          _listModeCtrl.forward();
        else
          _listModeCtrl.value = 1.0;
      } else {
        if (inDayView)
          _listModeCtrl.reverse();
        else
          _listModeCtrl.value = 0.0;
      }
    }
  }

  @override
  void dispose() {
    CategoryRegistry.revision.removeListener(_onCategoryRegistryChanged);
    _clockTimer?.cancel();
    _searchDebounce?.cancel();
    _dragFrameTick.dispose();
    _nowNotifier.dispose();
    _zoomAnim.dispose();
    _zoomCtrl.dispose();
    _collapseAnim.dispose();
    _collapseCtrl.dispose();
    _snapCtrl.dispose();
    _listModeCtrl.dispose();
    _viewModeCtrl.dispose();
    _yearScrollCtrl.dispose();
    _prevYearPreviewScrollCtrl?.dispose();
    _nextYearPreviewScrollCtrl?.dispose();
    _monthViewScrollCtrl.dispose();
    _prevPreviewScrollCtrl?.dispose();
    _nextPreviewScrollCtrl?.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onCategoryRegistryChanged() {
    if (mounted) setState(() {});
  }

  void _onMonthListOrderChanged(
    String dayKey,
    List<ScheduledEvent> orderedEvents,
  ) {
    _monthListOrderByDay[dayKey] = [
      for (final event in orderedEvents) event.id,
    ];
    if (mounted) setState(() {});
  }

  // ── Full-screen search overlay (mirrors EventsTab._buildGridSearchOverlay) ──
  Widget _buildSearchOverlay() {
    final showResults = _searchFocused && _searchText.isNotEmpty;
    final searchBarRow = Padding(
      padding: const EdgeInsets.fromLTRB(16, kSearchBarHostTopPadding, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: AppSearchBar(
              key: _searchBarKey,
              controller: _searchCtrl,
              placeholder: 'Search',
            ),
          ),
          SearchCancelButton(
            key: _searchCancelKey,
            searchFocused: true,
            onTap: cancelSearch,
            animation: widget.searchModeAnimation,
          ),
        ],
      ),
    );
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: _greyFadeIn ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        child: ColoredBox(
          color: resolveThemeColor(kBackgroundColor, context),
          child: CustomScrollView(
            primary: false,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
            slivers: [
              SliverPersistentHeader(
                pinned: true,
                delegate: _CalSearchHeaderDelegate(
                  searchBarRow: searchBarRow,
                  extent: searchBarHeaderExtent(context),
                  showSeparator: true,
                ),
              ),
              if (showResults)
                SmartSearchResultsSliver(
                  hits: _searchHits,
                  suggestedQuery: _searchSuggestion,
                  onSuggestionTap: _applySearchSuggestion,
                  eventTopPadding: 18,
                  eventTileWrapper: (hit, child, previewBuilder) =>
                      wrapSearchEventTileWithActions(
                        hit: hit,
                        child: child,
                        previewBuilder: previewBuilder,
                        onEdit: widget.onEditEvent == null
                            ? null
                            : () {
                                // Exit Calendar's overlay search session
                                // before presenting the edit sheet.  The
                                // search field is focus-locked while search
                                // mode is active; leaving it mounted makes
                                // it reclaim focus when a sheet text field is
                                // tapped.
                                cancelSearch();
                                widget.onEditEvent!(hit.event);
                              },
                        onDelete: () => confirmDeleteEvent(context, hit.event),
                      ),
                  eventTilePressWrapper: wrapSearchEventTileWithPressScale,
                )
              else
                const SliverFillRemaining(
                  hasScrollBody: false,
                  child: SizedBox.expand(),
                ),
              if (!showResults || _searchHits.isNotEmpty)
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: floatingTabBarContentBottomClearance(
                      context,
                      existingTrailingContentPadding: 32,
                      finalContentGap: 20,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _screenW = constraints.maxWidth;
        final sw = _screenW;
        final sh = constraints.maxHeight;

        return AnimatedBuilder(
          // _nowNotifier is intentionally excluded here. It fires every second
          // and would rebuild the entire GestureDetector subtree on each tick,
          // which on web causes stale drag-end events to be re-delivered to the
          // new callbacks — the root cause of the ±2 navigation bug.
          // _DayTimeline uses ValueListenableBuilder(nowNotifier) internally to
          // update the time indicator, so no functionality is lost.
          // _today rebuilds (midnight) are handled by setState() in _scheduleClock.
          animation: Listenable.merge([
            _zoomAnim,
            _collapseAnim,
            _snapCtrl,
            _viewModeCtrl,
            _listModeCtrl,
            _dragFrameTick,
          ]),
          builder: (context, _) {
            final zoomT = _zoomAnim.value;
            final colT = _collapseAnim.value;
            final dayWeekStripHeight = _dayViewWeekStripHeight(context);
            // Animated row height driven by the view-mode transition.
            final rowHeight = lerpDouble(
              _fromHeight,
              _toHeight,
              _viewModeCtrl.value,
            )!;
            // How far the week strip has slid upward out of the viewport.
            //   0.0 = strip at normal Day View pinned position
            //   1.0 = strip fully above the app header (off-screen)
            // Multiplied by colT so the offset is zero in Month/Year View.
            final double listModeT = colT * _listModeCtrl.value;
            final double stripSlideY =
                -listModeT *
                    (_kCalendarHeaderToDowGap +
                        _kDayLabelHeight +
                        dayWeekStripHeight);
            // During a snap animation use the interpolated value; during a
            // free drag use the raw _slideX field.
            final slideX = _snapCtrl.isAnimating ? _snapAnim.value : _slideX;

            // Adjacent year / month / day for the three-panel rendering
            final prevYear = _dispYear - 1;
            final nextYear = _dispYear + 1;
            final prevMY = _dispMonth == 1
                ? (_dispYear - 1, 12)
                : (_dispYear, _dispMonth - 1);
            final nextMY = _dispMonth == 12
                ? (_dispYear + 1, 1)
                : (_dispYear, _dispMonth + 1);

            // In Day View the week strip swipe navigates ±7 days; the timeline
            // swipe navigates ±1 day. Use _weekStripDrag to pick the right offset.
            final bool inDayView = colT > 0.95;

            final int adjDayOff = (_weekStripDrag && inDayView) ? 7 : 1;
            final prevDay = _selected.subtract(Duration(days: adjDayOff));
            final nextDay = _selected.add(Duration(days: adjDayOff));

            // Adjacent MonthView panels — which selected-date drives each panel:
            //   Month/Year view           → _selected (month stays full-view)
            //   Day view, week-strip drag → ±7 days (jump to adjacent week)
            //   Day view, content drag    → ±1 day  (circle slides with the swipe)
            final DateTime prevPanelSel;
            final DateTime nextPanelSel;
            if (!inDayView) {
              prevPanelSel = _selected;
              nextPanelSel = _selected;
            } else if (_weekStripDrag) {
              prevPanelSel = _selected.subtract(const Duration(days: 7));
              nextPanelSel = _selected.add(const Duration(days: 7));
            } else {
              prevPanelSel = _selected.subtract(const Duration(days: 1));
              nextPanelSel = _selected.add(const Duration(days: 1));
            }
            final int prevPanelYear = inDayView ? prevPanelSel.year : prevMY.$1;
            final int prevPanelMonth = inDayView
                ? prevPanelSel.month
                : prevMY.$2;
            final int nextPanelYear = inDayView ? nextPanelSel.year : nextMY.$1;
            final int nextPanelMonth = inDayView
                ? nextPanelSel.month
                : nextMY.$2;
            final double prevColT = inDayView ? 1.0 : 0.0;
            final double nextColT = inDayView ? 1.0 : 0.0;
            final int prevColRow = inDayView
                ? _weekRowForDate(prevPanelSel)
                : 0;
            final int nextColRow = inDayView
                ? _weekRowForDate(nextPanelSel)
                : 0;

            // Week strip slides only for Year/Month view swipes and Day View
            // week-strip drags. For Day View content drags, the strip stays
            // fixed — only the selected-day circle slides (see circleSlideX).
            // Cross-week detection: when the next/prev day is in a different
            // week row (Sun→Mon, Mon→Sun) or a different month, the strip must
            // slide instead of the circle, so the new week row comes into view.
            bool isCrossWeek = false;
            if (inDayView && !_weekStripDrag) {
              final bool goingNext = slideX < 0;
              final bool goingPrev = slideX > 0;
              if (goingNext && _selected.weekday == 7)
                isCrossWeek = true; // Sun → Mon
              if (goingPrev && _selected.weekday == 1)
                isCrossWeek = true; // Mon → Sun
              if (slideX != 0) {
                final DateTime target = goingNext
                    ? _selected.add(const Duration(days: 1))
                    : _selected.subtract(const Duration(days: 1));
                if (target.month != _selected.month) isCrossWeek = true;
              }
            }
            // Same-week Day View drag: circle slides, strip stays.
            // Cross-week Day View drag: strip slides, circle stays.
            final bool circleMode =
                inDayView && !_weekStripDrag && !isCrossWeek;
            final double monthSlideX = circleMode ? 0.0 : slideX;
            final double circleSlideX = circleMode ? slideX : 0.0;
            // Timeline stays fixed when the user is dragging the week strip.
            final double timelineSlideX = (inDayView && _weekStripDrag)
                ? 0.0
                : slideX;

            // Swipe gesture is enabled only when fully settled in one view.
            final swipeEnabled =
                !_snapCtrl.isAnimating &&
                ((zoomT < 0.05) || // year view
                    (zoomT > 0.95 && colT < 0.05) || // month view
                    (colT > 0.95)); // day view

            return GestureDetector(
              behavior: HitTestBehavior.translucent,
              onHorizontalDragStart: swipeEnabled ? _onHDragStart : null,
              onHorizontalDragUpdate: swipeEnabled ? _onHDragUpdate : null,
              onHorizontalDragEnd: swipeEnabled ? _onHDragEnd : null,
              child: ColoredBox(
                color: resolveThemeColor(kBackgroundColor, context),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    // ── Year view ─────────────────────────────────────────
                    // Only shown when truly at rest (t < 0.001). The morph
                    // appears fully opaque from t = 0.001 and covers the
                    // widgets with its solid background from the first frame.
                    if (zoomT < 0.001)
                      Positioned.fill(
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned(
                              left: slideX - sw,
                              top: 0,
                              bottom: 0,
                              width: sw,
                              child: _YearView(
                                key: ValueKey(prevYear),
                                year: prevYear,
                                today: _today,
                                selectedDate: _selected,
                                onMonthTap: _enterMonth,
                                controller: _previewYearScrollCtrl(
                                  isPrev: true,
                                  key: '$prevYear',
                                ),
                              ),
                            ),
                            Positioned(
                              left: slideX,
                              top: 0,
                              bottom: 0,
                              width: sw,
                              child: _YearView(
                                key: ValueKey(_dispYear),
                                year: _dispYear,
                                today: _today,
                                selectedDate: _selected,
                                onMonthTap: _enterMonth,
                                controller: _yearScrollCtrl,
                                rowKeys: _yearRowKeys,
                              ),
                            ),
                            Positioned(
                              left: slideX + sw,
                              top: 0,
                              bottom: 0,
                              width: sw,
                              child: _YearView(
                                key: ValueKey(nextYear),
                                year: nextYear,
                                today: _today,
                                selectedDate: _selected,
                                onMonthTap: _enterMonth,
                                controller: _previewYearScrollCtrl(
                                  isPrev: false,
                                  key: '$nextYear',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // ── Morph overlay — per-element shared-element transition ─
                    // Renders for 0 < t < 1.  Selected month cells travel from
                    // year positions → month positions individually; other months
                    // follow the zoom and leave the viewport.
                    //
                    // The morph is ALWAYS FULLY OPAQUE while active.  No Opacity
                    // wrapper is used: crossfading a canvas over widgets that draw
                    // the same content causes both layers to show simultaneously
                    // (doubling).  Instead the thresholds are set very tight
                    // (0.001 / 0.999) so the morph and each static view swap in
                    // a single frame while the animation is essentially at rest —
                    // the visual difference at those values is imperceptible.
                    if (zoomT >= 0.001 && zoomT <= 0.999)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: _MorphOverlay(
                            t: zoomT.clamp(0.0, 1.0),
                            zoomMonthIdx: _zoomMonthIdx,
                            year: _dispYear,
                            today: _today,
                            selectedDate: _selected,
                            scrollOffset: _zoomScrollOffset,
                            monthScrollOffset: _savedMonthScrollOffset,
                            screenW: sw,
                            measuredRowTops: _yearMeasuredRowTops,
                            viewModeRowHeight: rowHeight,
                          ),
                        ),
                      ),

                    // ── Month view — three horizontal panels ───────────────
                    // Only mounted when the morph has fully settled (t > 0.999).
                    if (zoomT > 0.999)
                      Positioned.fill(
                        child: Stack(
                          children: [
                            // Prev panel — display only, no tap
                            Positioned(
                              left: monthSlideX - sw,
                              top: 0,
                              bottom: 0,
                              width: sw,
                               child: ClipRect(
                                 child: Transform.translate(
                                   offset: Offset(0, stripSlideY),
                                   child: IgnorePointer(
                                     child: _MonthView(
                                    key: ValueKey(
                                      '$prevPanelYear-$prevPanelMonth-${prevPanelSel.day}',
                                    ),
                                    year: prevPanelYear,
                                    month: prevPanelMonth,
                                    today: _today,
                                    selectedDate: prevPanelSel,
                                    collapseProgress: prevColT,
                                    collapseWeekRow: prevColRow,
                                    rowHeight: rowHeight,
                                     viewMode: _viewMode,
                                    pendingBloomDate: _pendingBloomDate,
                                    scrollController: _previewScrollCtrl(
                                      isPrev: true,
                                      key:
                                          '$prevPanelYear-$prevPanelMonth-${prevPanelSel.day}',
                                    ),
                                     monthListOrderByDay:
                                         _monthListOrderByDay,
                                     onMonthListOrderChanged:
                                         _onMonthListOrderChanged,
                                    onDayTap: (_) {},
                                     ),
                                   ),
                                ),
                              ),
                            ),
                            // Current month — fully interactive
                            Positioned(
                              left: monthSlideX,
                              top: 0,
                              bottom: 0,
                              width: sw,
                               child: ClipRect(
                                 child: Transform.translate(
                                   offset: Offset(0, stripSlideY),
                                   child: _MonthView(
                                  key: ValueKey('$_dispYear-$_dispMonth'),
                                  year: _dispYear,
                                  month: _dispMonth,
                                  today: _today,
                                  selectedDate: _selected,
                                  collapseProgress: colT,
                                  collapseWeekRow: _collapseRow,
                                  rowHeight: rowHeight,
                                   viewMode: _viewMode,
                                  circleSlideX: circleSlideX,
                                  settleCount: _settleCount,
                                  blobDeltaX: circleMode ? _blobDeltaX : 0.0,
                                  blobSnapCount: _blobSnapCount,
                                  pendingBloomDate: _pendingBloomDate,
                                  daySubMode: widget.daySubMode,
                                   onEditEvent: widget.onEditEvent,
                                  scrollController: _monthViewScrollCtrl,
                                  scrollViewportKey:
                                      _monthViewScrollViewportKey,
                                   monthListOrderByDay:
                                       _monthListOrderByDay,
                                   onMonthListOrderChanged:
                                       _onMonthListOrderChanged,
                                  collapseScrollOffset: _collapseScrollOffset,
                                  onDayTap: (date) {
                                    if (colT < 0.1) {
                                      // Month view: tap selects; tap the
                                      // already-selected day enters Day View.
                                      if (_sameDay(date, _selected)) {
                                        _enterDay(date);
                                      } else {
                                        setState(() {
                                          _selected = date;
                                          _dispMonth = date.month;
                                          _dispYear = date.year;
                                          _collapseRow = _weekRowForDate(date);
                                        });
                                        _notify();
                                      }
                                    } else {
                                      setState(() {
                                        _selected = date;
                                        _dispMonth = date.month;
                                        _dispYear = date.year;
                                        _collapseRow = _weekRowForDate(date);
                                      });
                                      _notify();
                                    }
                                  },
                                  onDayLongPress: (date) {
                                    if (colT < 0.1) {
                                      // Long press always enters Day View,
                                      // selecting the day if not already.
                                      if (!_sameDay(date, _selected)) {
                                        setState(() {
                                          _selected = date;
                                          _dispMonth = date.month;
                                          _dispYear = date.year;
                                          _collapseRow = _weekRowForDate(date);
                                        });
                                        _notify();
                                      }
                                      _enterDay(date);
                                    }
                                  },
                                   ),
                                 ),
                              ),
                            ),
                            // Next panel — display only, no tap
                            Positioned(
                              left: monthSlideX + sw,
                              top: 0,
                              bottom: 0,
                              width: sw,
                               child: ClipRect(
                                 child: Transform.translate(
                                   offset: Offset(0, stripSlideY),
                                   child: IgnorePointer(
                                     child: _MonthView(
                                    key: ValueKey(
                                      '$nextPanelYear-$nextPanelMonth-${nextPanelSel.day}',
                                    ),
                                    year: nextPanelYear,
                                    month: nextPanelMonth,
                                    today: _today,
                                    selectedDate: nextPanelSel,
                                    collapseProgress: nextColT,
                                    collapseWeekRow: nextColRow,
                                    rowHeight: rowHeight,
                                     viewMode: _viewMode,
                                    scrollController: _previewScrollCtrl(
                                      isPrev: false,
                                      key:
                                          '$nextPanelYear-$nextPanelMonth-${nextPanelSel.day}',
                                    ),
                                     monthListOrderByDay:
                                         _monthListOrderByDay,
                                     onMonthListOrderChanged:
                                         _onMonthListOrderChanged,
                                    onDayTap: (_) {},
                                     ),
                                   ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // ── Day-view DOW mask ───────────────────────────────────
                    // The three month panels each contain their own DOW row,
                    // but their translated week rows can still paint across
                    // that row before an individual panel's clip is applied.
                    // Paint one opaque mask at the parent level, above all
                    // three panels, and render the labels again inside it so
                    // the DOW alignment remains independent of panel motion.
                    if (colT > 0.01 &&
                        widget.daySubMode != DayViewSubMode.list)
                      const Positioned(
                        // Cover the complete boundary below the app header.
                        // The week rows are vertically transformed while
                        // collapsing into Day View and can otherwise paint
                    // through the small gap above the DOW letters.
                        top: 0,
                        left: 0,
                        right: 0,
                        height: _kCalendarHeaderToDowGap + _kDayLabelHeight,
                        child: _DayViewDowMask(),
                      ),
                    // (Strip slides off-screen via stripSlideY Transform on each
                    // _MonthView panel; the mask above also seals the header
                    // boundary while the strip is settling.)

                    // ── Day banner (weekday + full date) below week strip ──
                    // Multi Day: single banner instance handles column-level
                    // sliding — the shared day shifts at half speed.
                    // Single Day: classic 3-panel full-width approach.
                    // Suppressed in List mode — the placeholder takes the
                    // full area below the week strip instead.
                    if (colT > 0.01 && widget.daySubMode != DayViewSubMode.list)
                      Positioned(
                        left: 0,
                        right: 0,
                        top:
                            _kCalendarHeaderToDowGap +
                            _kDayLabelHeight +
                            dayWeekStripHeight,
                        height: _kDayBannerHeight,
                        child: Opacity(
                          opacity: ((colT - 0.55) / 0.45).clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 36.0 * (1.0 - colT)),
                            child: IgnorePointer(
                              child:
                                  widget.daySubMode == DayViewSubMode.multiDay
                                  // Single instance keyed by GlobalKey so the morph
                                  // animation state survives the subtree-type switch
                                  // from the 3-panel Stack to the single-widget form.
                                  ? _DayBanner(
                                      key: _bannerCenterKey,
                                      date: _selected,
                                      today: _today,
                                      daySubMode: widget.daySubMode,
                                      slideX: slideX,
                                      screenW: sw,
                                    )
                                  : Stack(
                                      children: [
                                        Positioned(
                                          left: slideX - sw,
                                          top: 0,
                                          bottom: 0,
                                          width: sw,
                                          child: _DayBanner(
                                            date: prevDay,
                                            today: _today,
                                            daySubMode: widget.daySubMode,
                                          ),
                                        ),
                                        Positioned(
                                          left: slideX,
                                          top: 0,
                                          bottom: 0,
                                          width: sw,
                                          child: _DayBanner(
                                            key: _bannerCenterKey,
                                            date: _selected,
                                            today: _today,
                                            daySubMode: widget.daySubMode,
                                          ),
                                        ),
                                        Positioned(
                                          left: slideX + sw,
                                          top: 0,
                                          bottom: 0,
                                          width: sw,
                                          child: _DayBanner(
                                            date: nextDay,
                                            today: _today,
                                            daySubMode: widget.daySubMode,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),

                    // ── Day timeline — three horizontal panels ─────────────
                    // Multi Day: _DayTimelineMulti uses column-level sliding
                    // so the shared day shifts at half speed; exiting/entering
                    // days slide at full speed for seamless continuity.
                    // Single Day: classic 3-panel full-width approach.
                    // Suppressed in List mode — placeholder used instead.
                    if (colT > 0.01 && widget.daySubMode != DayViewSubMode.list)
                      Positioned(
                        left: 0,
                        right: 0,
                        top:
                            _kCalendarHeaderToDowGap +
                            _kDayLabelHeight +
                            dayWeekStripHeight +
                            _kDayBannerHeight,
                        bottom: 0,
                        child: Opacity(
                          opacity: ((colT - 0.55) / 0.45).clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 36.0 * (1.0 - colT)),
                            child: IgnorePointer(
                              ignoring: colT < 0.85,
                              child:
                                  widget.daySubMode == DayViewSubMode.multiDay
                                  ? _DayTimelineMulti(
                                      // Constant key → state survives date navigation
                                      // so sep-entrance animation only plays once on
                                      // mode-enter, not on every day change.
                                      key: const Key('multi-timeline'),
                                      selectedDate: _selected,
                                      today: _today,
                                      nowNotifier: _nowNotifier,
                                      slideX: timelineSlideX,
                                      screenW: sw,
                                    )
                                  : Stack(
                                      children: [
                                        Positioned(
                                          left: timelineSlideX - sw,
                                          top: 0,
                                          bottom: 0,
                                          width: sw,
                                          child: _DayTimeline(
                                            key: ValueKey(
                                              'day-${prevDay.year}${prevDay.month}${prevDay.day}',
                                            ),
                                            selectedDate: prevDay,
                                            today: _today,
                                            nowNotifier: _nowNotifier,
                                            daySubMode: widget.daySubMode,
                                          ),
                                        ),
                                        Positioned(
                                          left: timelineSlideX,
                                          top: 0,
                                          bottom: 0,
                                          width: sw,
                                          child: _DayTimeline(
                                            key: ValueKey(
                                              'day-${_selected.year}${_selected.month}${_selected.day}',
                                            ),
                                            selectedDate: _selected,
                                            today: _today,
                                            nowNotifier: _nowNotifier,
                                            daySubMode: widget.daySubMode,
                                          ),
                                        ),
                                        Positioned(
                                          left: timelineSlideX + sw,
                                          top: 0,
                                          bottom: 0,
                                          width: sw,
                                          child: _DayTimeline(
                                            key: ValueKey(
                                              'day-${nextDay.year}${nextDay.month}${nextDay.day}',
                                            ),
                                            selectedDate: nextDay,
                                            today: _today,
                                            nowNotifier: _nowNotifier,
                                            daySubMode: widget.daySubMode,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    // ── List mode placeholder ──────────────────────────────
                    // Occupies the FULL content area (top:0, bottom:0) because
                    // the week strip is now off-screen above the app header.
                    // Centering via SliverFillRemaining works correctly when the
                    // Positioned spans the full height.
                    if (colT > 0.01 && widget.daySubMode == DayViewSubMode.list)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: 0,
                        bottom: 0,
                        child: Opacity(
                          opacity: ((colT - 0.55) / 0.45).clamp(0.0, 1.0),
                          child: Transform.translate(
                            offset: Offset(0, 36.0 * (1.0 - colT)),
                            child: const _DayListPlaceholder(),
                          ),
                        ),
                      ),
                    // ── Full-screen search overlay (same pattern as EventsTab) ──
                    if (_greyActive) _buildSearchOverlay(),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _CalSearchHeaderDelegate — pinned search bar row for the calendar overlay
// ══════════════════════════════════════════════════════════════════════════════
class _CalSearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  const _CalSearchHeaderDelegate({
    required this.searchBarRow,
    required this.extent,
    required this.showSeparator,
  });
  final Widget searchBarRow;
  final double extent;
  final bool showSeparator;

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext ctx, double shrinkOffset, bool overlapsContent) =>
      ColoredBox(
        color: resolveThemeColor(kBackgroundColor, ctx),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            searchBarRow,
            if (showSeparator) ...[
              const SizedBox(height: kSearchBarHeaderSeparatorGap),
              Container(
                height: kSearchBarSeparatorHeight,
                color: resolveThemeColor(kSeparatorColor, ctx),
              ),
            ],
          ],
        ),
      );

  @override
  bool shouldRebuild(_CalSearchHeaderDelegate old) => true;
}

// ══════════════════════════════════════════════════════════════════════════════
// _YearView — scrollable 4-row × 3-col grid of mini month grids
// ══════════════════════════════════════════════════════════════════════════════
class _YearView extends StatelessWidget {
  const _YearView({
    super.key,
    required this.year,
    required this.today,
    required this.selectedDate,
    required this.onMonthTap,
    this.controller,
    this.rowKeys,
  });

  final int year;
  final DateTime today;
  final DateTime selectedDate;
  final void Function(int monthIndex) onMonthTap;
  // Scroll controller — supplied only for the current-year panel so the
  // parent can read the scroll offset when the zoom animation starts.
  final ScrollController? controller;
  // One key per row (0–3). Supplied only for the current-year panel so
  // CalendarTabState can measure actual rendered row positions before zooming.
  final List<GlobalKey>? rowKeys;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final miniW = (totalW - 2 * _kYearOuterPad - 2 * _kYearColGap) / 3;

        return SingleChildScrollView(
          controller: controller,
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          clipBehavior: Clip.hardEdge,
          padding: EdgeInsets.fromLTRB(
            _kYearOuterPad,
            17.5,
            _kYearOuterPad,
            14.5 + floatingTabBarContentBottomClearance(context),
          ),
          child: Column(
            children: [
              for (int row = 0; row < 4; row++) ...[
                // KeyedSubtree lets CalendarTabState measure exact row positions
                // via GlobalKey before the zoom animation starts, so _MorphOverlay
                // can use actual Flutter-layout y coordinates instead of a formula.
                KeyedSubtree(
                  key: rowKeys?[row],
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int col = 0; col < 3; col++) ...[
                        if (col > 0) const SizedBox(width: _kYearColGap),
                        SizedBox(
                          width: miniW,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => onMonthTap(row * 3 + col),
                            child: _MiniMonthGrid(
                              year: year,
                              month: row * 3 + col + 1,
                              today: today,
                              selectedDate: selectedDate,
                              width: miniW,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (row < 3) const SizedBox(height: _kYearRowGap),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Compact month grid used inside _YearView ──────────────────────────────────
class _MiniMonthGrid extends StatelessWidget {
  const _MiniMonthGrid({
    required this.year,
    required this.month,
    required this.today,
    required this.selectedDate,
    required this.width,
  });

  final int year;
  final int month; // 1–12
  final DateTime today;
  final DateTime selectedDate;
  final double width;

  @override
  Widget build(BuildContext context) {
    final isCurrentMonth = year == today.year && month == today.month;
    final cellSize = width / 7;
    final rows = _totalWeekRows(year, month);
    final offset = _firstWeekday(year, month);
    final days = _daysInMonth(year, month);

    final Color primaryC = resolveThemeColor(kPrimaryLabel, context);
    final Color secondaryC = resolveThemeColor(kSecondaryLabel, context);
    final Color tertiaryC = resolveThemeColor(kTertiaryLabel, context);
    final Color nameC = isCurrentMonth ? resolveAccentColor(context) : primaryC;
    final Color letterC = tertiaryC;
    final Color numC = primaryC;
    const Color whiteC = CupertinoColors.white;
    final Color accentC = resolveAccentColor(context);
    final Color accentFadedC = resolveAccentColor(context).withOpacity(0.40);
    final yearViewDayScaler = _yearViewTextScaler(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Month name label — year-view natural size; morph is handled by
        // _MorphOverlay during the transition so this always renders at the
        // static year-view size (cellSize*1.35).  height:1.0 keeps
        // line-height = font-size, matching the rowLettersTop geometry.
        SizedBox(
          width: 3 * cellSize,
          child: Text(
            _kShortMonthNames[month - 1],
            maxLines: 1,
            overflow: TextOverflow.clip,
            // This month label is sized from the fixed mini-grid geometry,
            // so applying an extreme OS text scale would clip it and push
            // the calendar numbers out of their cells.
            textScaler: TextScaler.noScaling,
            style: TextStyle(
              fontFamily: kSFProText,
              fontSize: cellSize * 1.35,
              height: 1.0,
              fontWeight: FontWeight.w700,
              color: nameC,
              letterSpacing: -0.3,
            ),
          ),
        ),
        SizedBox(height: 5),
        // Single-letter day-of-week header
        Row(
          children: _kDayLetters
              .map(
                (d) => SizedBox(
                  width: cellSize,
                  height: cellSize,
                  child: Center(
                    child: Text(
                      d,
                      textScaler: TextScaler.noScaling,
                      style: TextStyle(
                        fontFamily: kSFProText,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w500,
                        color: letterC,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 2),
        // Week rows
        for (int row = 0; row < rows; row++)
          Row(
            children: List.generate(7, (col) {
              final idx = row * 7 + col;
              final day = idx - offset + 1;
              if (day < 1 || day > days) {
                return SizedBox(width: cellSize, height: cellSize);
              }
              final date = DateTime(year, month, day);
              final isToday = _sameDay(date, today);
              final isSel = _sameDay(date, selectedDate);
              // Year View shows ONLY today highlighted (full blue circle).
              // The Month/Day selected day is not reflected here — users
              // tap a month to enter that view, not to select days.
              // Circle is slightly larger than the cell so it reads clearly
              // at the mini-grid scale.
              final fontSize = cellSize * 0.62 + 1.0;
              final dayScale = yearViewDayScaler.scale(fontSize) / fontSize;
              final circleSize = cellSize * 1.15 * dayScale;

              final Widget dayCell;
              if (isSel) {
                dayCell = Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    color: accentC,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      textScaler: yearViewDayScaler,
                      style: TextStyle(
                        fontFamily: kSFProText,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: whiteC,
                      ),
                    ),
                  ),
                );
              } else if (isToday) {
                dayCell = Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    color: accentFadedC,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '$day',
                      textScaler: yearViewDayScaler,
                      style: TextStyle(
                        fontFamily: kSFProText,
                        fontSize: fontSize,
                        fontWeight: FontWeight.w600,
                        color: whiteC,
                      ),
                    ),
                  ),
                );
              } else {
                dayCell = Text(
                  '$day',
                  textScaler: yearViewDayScaler,
                  style: TextStyle(
                    fontFamily: kSFProText,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                    color: numC,
                  ),
                );
              }

              return SizedBox(
                width: cellSize,
                height: cellSize,
                child: Center(child: dayCell),
              );
            }),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _MorphOverlay — resolves colors then delegates all drawing to _MorphPainter.
// Zero widget allocation per frame: the painter draws directly onto the canvas.
// ══════════════════════════════════════════════════════════════════════════════
class _MorphOverlay extends StatelessWidget {
  const _MorphOverlay({
    required this.t,
    required this.zoomMonthIdx,
    required this.year,
    required this.today,
    required this.selectedDate,
    required this.scrollOffset,
    required this.monthScrollOffset,
    required this.screenW,
    required this.viewModeRowHeight,
    this.measuredRowTops,
  });

  final double t; // 0 = year view, 1 = month view
  final int zoomMonthIdx; // 0-based month index (0 = January)
  final int year;
  final DateTime today;
  final DateTime selectedDate;
  final double scrollOffset; // _yearScrollCtrl offset at zoom start
  /// Saved month-view scroll offset (_savedMonthScrollOffset).  Applied to all
  /// month-side (t=1) positions in the morph so the painter's end-frame matches
  /// the _MonthView that appears at zoomT > 0.999 — no pop at the swap point.
  final double monthScrollOffset;
  final double screenW;
  final double viewModeRowHeight;
  // Actual Flutter-layout row tops measured from GlobalKeys (natural /
  // scroll-offset-independent).  When supplied, replaces the formula-derived
  // rowTop so non-selected months track the year-view grid with pixel accuracy.
  final List<double>? measuredRowTops;

  @override
  Widget build(BuildContext context) {
    // Resolve CupertinoDynamicColors here — the painter has no BuildContext.
    final bgC = CupertinoDynamicColor.resolve(kBackgroundColor, context);
    final priC = CupertinoDynamicColor.resolve(kPrimaryLabel, context);
    final accC = resolveAccentColor(context);
    final secC = CupertinoDynamicColor.resolve(kSecondaryLabel, context);
    final terC = CupertinoDynamicColor.resolve(kTertiaryLabel, context);
    final sepC = CupertinoDynamicColor.resolve(kSeparatorColor, context);
    final miniW = (screenW - 2 * _kYearOuterPad - 2 * _kYearColGap) / 3;
    final yearFontSize = miniW / 7 * 0.62 + 1.0;
    final yearDayScale =
        _yearViewTextScaler(context).scale(yearFontSize) / yearFontSize;
    final monthDayScale = textScaleRatioFor(context, 17.0);
    return ClipRect(
      child: CustomPaint(
        painter: _MorphPainter(
          t: t,
          zoomMonthIdx: zoomMonthIdx,
          year: year,
          today: today,
          selectedDate: selectedDate,
          scrollOffset: scrollOffset,
          monthScrollOffset: monthScrollOffset,
          screenW: screenW,
          measuredRowTops: measuredRowTops,
          viewModeRowHeight: viewModeRowHeight,
          bgColor: bgC,
          primaryColor: priC,
          accentColor: accC,
          secondaryColor: secC,
          tertiaryColor: terC,
          separatorColor: sepC,
          yearDayScale: yearDayScale,
          monthDayScale: monthDayScale,
        ),
      ),
    );
  }
}

// ─── CustomPainter: all morph drawing via canvas calls, zero widget tree ──────
class _MorphPainter extends CustomPainter {
  _MorphPainter({
    required this.t,
    required this.zoomMonthIdx,
    required this.year,
    required this.today,
    required this.selectedDate,
    required this.scrollOffset,
    required this.monthScrollOffset,
    required this.screenW,
    required this.bgColor,
    required this.primaryColor,
    required this.accentColor,
    required this.secondaryColor,
    required this.tertiaryColor,
    required this.separatorColor,
    required this.viewModeRowHeight,
    required this.yearDayScale,
    required this.monthDayScale,
    this.measuredRowTops,
  });

  final double t;
  final int zoomMonthIdx;
  final int year;
  final DateTime today;
  final DateTime selectedDate;
  final double scrollOffset;
  final double monthScrollOffset;
  final double screenW;
  final Color bgColor;
  final Color primaryColor;
  final Color accentColor;
  final Color secondaryColor;
  final Color tertiaryColor;
  final Color separatorColor;
  final double viewModeRowHeight;
  final double yearDayScale;
  final double monthDayScale;
  final List<double>? measuredRowTops;

  final Paint _p = Paint()..isAntiAlias = true;

  @override
  bool shouldRepaint(_MorphPainter o) =>
      o.t != t ||
      o.zoomMonthIdx != zoomMonthIdx ||
      o.year != year ||
      o.selectedDate != selectedDate ||
      o.scrollOffset != scrollOffset ||
      o.monthScrollOffset != monthScrollOffset ||
      o.screenW != screenW ||
      o.viewModeRowHeight != viewModeRowHeight ||
      o.yearDayScale != yearDayScale ||
      o.monthDayScale != monthDayScale ||
      o.bgColor != bgColor;

  // ── Multiply a color's alpha by [a] without discarding its inherent opacity ─
  static Color _fade(Color color, double a) =>
      color.withAlpha((color.alpha * a.clamp(0.0, 1.0)).round());

  // ── Draw text centred at [centre] with alpha multiplier [a] ───────────────
  // [wght] drives SFPro's variable weight axis continuously (e.g. 400.0–600.0)
  // instead of the 9-step discrete FontWeight snaps.
  void _textC(
    Canvas canvas,
    String str,
    double sz,
    FontWeight fw,
    Color color,
    double a,
    Offset centre, {
    double ls = 0.0,
    double? wght,
  }) {
    if (a <= 0 || sz < 1) return;
    final tp = TextPainter(
      text: TextSpan(
        text: str,
        style: TextStyle(
          fontFamily: kSFProText,
          fontSize: sz,
          // No explicit height — use the font's natural line metrics, matching
          // how Flutter widget Text lays out. Setting height:1.0 here made the
          // canvas layout box 17px while widget Text used ~20.4px (SFPro
          // natural metrics), so the glyphs were centred at different vertical
          // positions. Removing it makes _textC centre by the same bounding
          // box height as the widget's Center() wrapper, eliminating the snap.
          fontWeight: fw,
          fontVariations: wght != null ? [FontVariation('wght', wght)] : null,
          color: _fade(color, a),
          letterSpacing: ls,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    tp.paint(canvas, centre - Offset(tp.width / 2, tp.height / 2));
  }

  // ── Draw text left-aligned, top at [topLeft], with alpha multiplier [a] ───
  void _textL(
    Canvas canvas,
    String str,
    double sz,
    FontWeight fw,
    Color color,
    double a,
    Offset topLeft, {
    double ls = 0.0,
  }) {
    if (a <= 0 || sz < 1) return;
    final tp = TextPainter(
      text: TextSpan(
        text: str,
        style: TextStyle(
          fontFamily: kSFProText,
          fontSize: sz,
          height: 1.0,
          fontWeight: fw,
          color: _fade(color, a),
          letterSpacing: ls,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, topLeft);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final sw = screenW;
    final miniW = (sw - 2 * _kYearOuterPad - 2 * _kYearColGap) / 3;
    final cellSz = miniW / 7;
    final sFinal = sw / miniW;
    final s = 1.0 + (sFinal - 1.0) * t;

    final zCol = zoomMonthIdx % 3;
    final zRow = zoomMonthIdx ~/ 3;
    final zMonth = zoomMonthIdx + 1;

    // ── Row geometry ─────────────────────────────────────────────────────────
    final List<double> rowTop;
    if (measuredRowTops != null && measuredRowTops!.length == 4) {
      rowTop = measuredRowTops!;
    } else {
      final rowMaxWeeks = List.generate(4, (r) {
        var mx = 0;
        for (var c = 1; c <= 3; c++)
          mx = math.max(mx, _totalWeekRows(year, r * 3 + c));
        return mx;
      });
      final rowH = List.generate(
        4,
        (r) => cellSz * (2.35 + rowMaxWeeks[r]) + 7.0,
      );
      final computed = <double>[];
      var ry = 17.5;
      for (var r = 0; r < 4; r++) {
        computed.add(ry);
        ry += rowH[r] + _kYearRowGap;
      }
      rowTop = computed;
    }

    // Focal point: selected month's DOW-row top-left in year-view screen coords
    final focalX = _kYearOuterPad + zCol * (miniW + _kYearColGap);
    final focalY = rowTop[zRow] + cellSz * 1.35 + 5.0 - scrollOffset;

    // Zoom-transform helpers
    double xZ(double px) => s * px - sFinal * focalX * t;
    double yZ(double py) => s * py - sFinal * focalY * t;

    final mCellW = (sw - 7) / 8;
    final offset = _firstWeekday(year, zMonth);
    final daysInMonth = _daysInMonth(year, zMonth);
    final totalRows = _totalWeekRows(year, zMonth);
    final nameColor = (today.year == year && today.month == zMonth)
        ? accentColor
        : primaryColor;

    // 1. Background ────────────────────────────────────────────────────────────
    _p.color = bgColor;
    canvas.drawRect(Offset.zero & size, _p);

    // 2. Non-selected mini months — headers + per-cell shared-element morph ───
    for (var mi = 0; mi < 12; mi++) {
      if (mi == zoomMonthIdx) continue;
      final mCol = mi % 3;
      final mRow = mi ~/ 3;
      final mMon = mi + 1;
      final mnX = _kYearOuterPad + mCol * (miniW + _kYearColGap);
      final mnY = rowTop[mRow] - scrollOffset;
      final otherFocalY = rowTop[mRow] + cellSz * 1.35 + 5.0 - scrollOffset;

      final isHoriz = mRow == zRow;
      final cellAlpha = isHoriz ? 1.0 : ((0.95 - t) / 0.95).clamp(0.0, 1.0);
      final hdrAlpha = (1.0 - t / 0.42).clamp(0.0, 1.0);

      if (cellAlpha <= 0 && hdrAlpha <= 0) continue;

      // Month name (left-aligned, zoom-following, quick fade)
      if (hdrAlpha > 0) {
        final fSz = (cellSz * 1.35 * s).clamp(1.0, 200.0);
        final isCurrMonth = year == today.year && today.month == mMon;
        _textL(
          canvas,
          _kShortMonthNames[mMon - 1],
          fSz,
          FontWeight.w700,
          isCurrMonth ? accentColor : primaryColor,
          hdrAlpha,
          Offset(xZ(mnX), yZ(mnY)),
          ls: -0.3,
        );

        // DOW letters (centred, zoom-following, quick fade)
        final lSz = (cellSz * 0.55 * s).clamp(1.0, 200.0);
        for (int i = 0; i < 7; i++) {
          _textC(
            canvas,
            _kDayLetters[i],
            lSz,
            FontWeight.w500,
            tertiaryColor,
            hdrAlpha,
            Offset(xZ(mnX + (i + 0.5) * cellSz), yZ(otherFocalY + cellSz / 2)),
            ls: -0.1,
          );
        }
      }

      // Day cells (per-cell shared-element morph)
      if (cellAlpha > 0) {
        final otherOffset = _firstWeekday(year, mMon);
        final otherDays = _daysInMonth(year, mMon);
        for (var d = 1; d <= otherDays; d++) {
          final idx = otherOffset + d - 1;
          final dow = idx % 7;
          final weekRow = idx ~/ 7;

          // Year-view cell centre. +2.0 = SizedBox(height:2) gap in _MiniMonthGrid.
          final yearCX = mnX + (dow + 0.5) * cellSz;
          final yearCY =
              otherFocalY + (weekRow + 1) * cellSz + cellSz / 2 + 2.0;

          // Destination at t=1: zoom-transform equivalent (sFinal*(pos−focal))
          final cx = lerpDouble(yearCX, sFinal * (yearCX - focalX), t)!;
          final cy = lerpDouble(yearCY, sFinal * (yearCY - focalY), t)!;
          final r = lerpDouble(
            cellSz * 0.575 * yearDayScale,
            18.0 * monthDayScale,
            t,
          )!;
          final fSize = lerpDouble(
            (cellSz * 0.62 + 1.0) * yearDayScale,
            17.0 * monthDayScale,
            t,
          )!.clamp(1.0, 200.0);

          final date = DateTime(year, mMon, d);
          final isToday = _sameDay(date, today);
          final isSelected = _sameDay(date, selectedDate);

          if (isSelected || isToday) {
            _p.color = _fade(
              accentColor,
              (isSelected ? 1.0 : 0.40) * cellAlpha,
            );
            canvas.drawCircle(Offset(cx, cy), r, _p);
          }
          // Font weight lerps continuously via fontVariations (variable font axis)
          // and discretely via FontWeight.lerp as a reliable fallback.
          final fwStart = (isToday || isSelected)
              ? FontWeight.w600
              : FontWeight.w500;
          final fwEnd = (isToday || isSelected)
              ? FontWeight.w600
              : FontWeight.w400;
          final wght = lerpDouble(
            (isToday || isSelected) ? 600.0 : 500.0,
            (isToday || isSelected) ? 600.0 : 400.0,
            t,
          )!;
          _textC(
            canvas,
            '$d',
            fSize,
            FontWeight.lerp(fwStart, fwEnd, t)!,
            (isSelected || isToday) ? const Color(0xFFFFFFFF) : primaryColor,
            cellAlpha,
            Offset(cx, cy),
            ls: -0.3,
            wght: wght,
          );
        }
      }
    }

    final monthDayCircleOffset =
        kFixedTopPadding + (_kDayIndicatorDiameter * monthDayScale) / 2;

    // 3. Selected-month day cells — per-element lerp year → month ─────────────
    for (var d = 1; d <= daysInMonth; d++) {
      final idx = offset + d - 1;
      final dow = idx % 7;
      final weekRow = idx ~/ 7;

      // Year-view cell centre (focalY = top of DOW row; +2.0 = height:2 gap)
      final yearCX = focalX + (dow + 0.5) * cellSz;
      final yearCY = focalY + (weekRow + 1) * cellSz + cellSz / 2 + 2.0;

      // Month-view cell centre.
      // Circles are pinned at kFixedTopPadding (8) from the row top, so
      // the centre is the scaled circle offset — NOT rowHeight/2.
      // monthScrollOffset shifts the end position up so the morph's t=1 frame
      // matches the _MonthView that is scrolled to _savedMonthScrollOffset.
      final monthCX = mCellW * (dow + 1.5);
      final monthCY =
          _kCalendarHeaderToDowGap +
          _kDayLabelHeight +
          weekRow * viewModeRowHeight +
          monthDayCircleOffset -
          monthScrollOffset;

      final cx = lerpDouble(yearCX, monthCX, t)!;
      final cy = lerpDouble(yearCY, monthCY, t)!;
      final r = lerpDouble(
        cellSz * 0.575 * yearDayScale,
        18.0 * monthDayScale,
        t,
      )!;
      final fSize = lerpDouble(
        (cellSz * 0.62 + 1.0) * yearDayScale,
        17.0 * monthDayScale,
        t,
      )!.clamp(1.0, 200.0);

      final date = DateTime(year, zMonth, d);
      final isToday = _sameDay(date, today);
      final isSelected = _sameDay(date, selectedDate);

      if (isSelected || isToday) {
        _p.color = _fade(accentColor, isSelected ? 1.0 : 0.40);
        canvas.drawCircle(Offset(cx, cy), r, _p);
      }
      // Font weight lerps continuously via fontVariations (variable font axis)
      // and discretely via FontWeight.lerp as a reliable fallback.
      final fwStart = (isToday || isSelected)
          ? FontWeight.w600
          : FontWeight.w500;
      final fwEnd = (isToday || isSelected) ? FontWeight.w600 : FontWeight.w400;
      final wght = lerpDouble(
        (isToday || isSelected) ? 600.0 : 500.0,
        (isToday || isSelected) ? 600.0 : 400.0,
        t,
      )!;
      _textC(
        canvas,
        '$d',
        fSize,
        FontWeight.lerp(fwStart, fwEnd, t)!,
        (isSelected || isToday) ? const Color(0xFFFFFFFF) : primaryColor,
        1.0,
        Offset(cx, cy),
        ls: lerpDouble(-0.3, 0.0, t)!,
        wght: wght,
      );
    }

    // 4. Week numbers + separator lines ────────────────────────────────────────
    // Week numbers travel from the mini-month left edge to the wk-num column.
    // Separators widen from mini-month width → full screen width.
    for (var wr = 0; wr < totalRows; wr++) {
      final firstDayNum = wr * 7 - offset + 1;
      final wkNum = _isoWeekNumber(DateTime(year, zMonth, firstDayNum));

      final wkCX = lerpDouble(focalX, mCellW / 2, t)!;
      final wkCY = lerpDouble(
        focalY + (wr + 1) * cellSz + cellSz / 2,
        _kCalendarHeaderToDowGap +
            _kDayLabelHeight +
            wr * viewModeRowHeight +
            monthDayCircleOffset -
            monthScrollOffset,
        t,
      )!;
      _textC(
        canvas,
        '$wkNum',
        12,
        FontWeight.w400,
        secondaryColor,
        t,
        Offset(wkCX, wkCY),
        ls: lerpDouble(-0.1, 0.0, t)!,
      );

      final sepY = lerpDouble(
        focalY + (wr + 1) * cellSz,
        _kCalendarHeaderToDowGap +
            _kDayLabelHeight +
            (wr + 1) * viewModeRowHeight -
            monthScrollOffset,
        t,
      )!;
      final sepLeft = lerpDouble(focalX, 0.0, t)!;
      final sepRight = lerpDouble(focalX + miniW, sw, t)!;
      _p.color = _fade(separatorColor, t.clamp(0.0, 1.0));
      canvas.drawRect(
        Rect.fromLTWH(sepLeft, sepY, sepRight - sepLeft, 0.5),
        _p,
      );
    }

    // 5. DOW header background (fades in over second half to cover zooming cells)
    // The background tracks the DOW row's month-view y position, which is
    // shifted up by monthScrollOffset (the row may be partially or fully above
    // the viewport when the user had scrolled in Details mode).  Lerp the top-y
    // from 0 (natural, at the moment the rect starts appearing, hdrBgA=0) to
    // the fixed DOW-row position minus monthScrollOffset (fully at the
    // month-view scrolled position, hdrBgA=1).
    // ClipRect clips any portion that extends above y=0.
    final hdrBgA = ((t - 0.5) / 0.5).clamp(0.0, 1.0);
    if (hdrBgA > 0) {
      final dowTopY = lerpDouble(
        0.0,
        _kCalendarHeaderToDowGap - monthScrollOffset,
        hdrBgA,
      )!;
      _p.color = _fade(bgColor, hdrBgA);
      canvas.drawRect(Rect.fromLTWH(0, dowTopY, sw, _kDayLabelHeight), _p);
    }

    // 6. DOW letters stay unified through the Year → Month morph ─────────────
    //    The settled Year, Month, and Day views all use the same single-letter
    //    weekday labels.
    {
      // Continuously lerp the base color tertiary→secondary across the whole
      // animation so the letters transition smoothly into the Month View row.
      final dowColor = Color.lerp(tertiaryColor, secondaryColor, t)!;
      for (int i = 0; i < 7; i++) {
        final cx = lerpDouble(
          focalX + (i + 0.5) * cellSz,
          mCellW * (i + 1.5),
          t,
        )!;
        // Month-side cy is shifted up by monthScrollOffset so the labels land
        // at the same visual position as in the scrolled _MonthView.
        final cy = lerpDouble(
          focalY + cellSz / 2,
          _kCalendarHeaderToDowGap +
              _kDayLabelHeight / 2 -
              monthScrollOffset,
          t,
        )!;
        final fSz = lerpDouble(cellSz * 0.55, 11.0, t)!.clamp(1.0, 200.0);
        _textC(
          canvas,
          _kDayLetters[i],
          fSz,
          FontWeight.w500,
          dowColor,
          1.0,
          Offset(cx, cy),
          ls: -0.1,
        );
      }
    }

    // 7. Selected month name label (zoom-following, fades out by t = 0.4) ─────
    {
      final labelAlpha = ((0.4 - t) / 0.3).clamp(0.0, 1.0);
      if (labelAlpha > 0) {
        final fSz = (cellSz * 1.35 * s).clamp(1.0, 200.0);
        _textL(
          canvas,
          _kShortMonthNames[zMonth - 1],
          fSz,
          FontWeight.w700,
          nameColor,
          labelAlpha,
          Offset(xZ(focalX), yZ(rowTop[zRow] - scrollOffset)),
          ls: -0.3,
        );
      }
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
List<List<ScheduledEvent>> _groupMonthEvents(List<ScheduledEvent> events) {
  final allDay = <ScheduledEvent>[];
  final timed = <ScheduledEvent>[];
  for (final event in events) {
    (event.isAllDay || event.time == null ? allDay : timed).add(event);
  }
  timed.sort((a, b) {
    final byTime = _calendarTimeToMinutes(a.time) -
        _calendarTimeToMinutes(b.time);
    return byTime;
  });
  final groups = <String, List<ScheduledEvent>>{};
  for (final event in timed) {
    (groups[dcvTimeSectionKey(event.time!)] ??= []).add(event);
  }
  return [
    if (allDay.isNotEmpty) allDay,
    ...groups.values,
  ];
}

double _monthListEstimatedHeight(List<List<ScheduledEvent>> groups) {
  if (groups.isEmpty) return 80.0;
  // Mirror the embedded DCV's natural layout: one 16 pt list inset, a compact
  // section label, each event row, and one 16 pt section tail. Keeping this
  // estimate aligned with the actual child height is important because the
  // parent uses it to determine the maximum scroll offset and final 16 pt gap.
  final eventCount = groups.fold<int>(0, (sum, group) => sum + group.length);
  const listTopPadding = 16.0;
  const sectionLabelHeight = 26.0;
  const eventRowHeight = 72.0;
  const sectionBottomPadding = 16.0;
  return
      listTopPadding +
      groups.length * (sectionLabelHeight + sectionBottomPadding) +
      eventCount * eventRowHeight;
}

List<ScheduledEvent> _applyMonthListOrder(
  List<ScheduledEvent> events,
  List<String>? savedOrder,
) {
  if (events.length < 2 || savedOrder == null || savedOrder.isEmpty) {
    return List<ScheduledEvent>.of(events);
  }
  final byId = {for (final event in events) event.id: event};
  final ordered = <ScheduledEvent>[];
  for (final id in savedOrder) {
    final event = byId.remove(id);
    if (event != null) ordered.add(event);
  }
  ordered.addAll(byId.values);
  return ordered;
}

// _MonthView — full month grid with collapse-to-day animation
// ══════════════════════════════════════════════════════════════════════════════
class _MonthView extends StatelessWidget {
  const _MonthView({
    super.key,
    required this.year,
    required this.month,
    required this.today,
    required this.selectedDate,
    required this.collapseProgress,
    required this.collapseWeekRow,
    required this.onDayTap,
    required this.rowHeight,
    required this.viewMode,
    this.onDayLongPress,
    this.onEditEvent,
    this.circleSlideX = 0.0,
    this.settleCount = 0,
    this.blobDeltaX = 0.0,
    this.blobSnapCount = 0,
    this.pendingBloomDate,
    this.daySubMode = DayViewSubMode.singleDay,
    this.scrollController,
    this.scrollViewportKey,
    this.monthListOrderByDay = const {},
    this.onMonthListOrderChanged,
    this.collapseScrollOffset = 0.0,
  });

  final int year, month;
  final DateTime today, selectedDate;
  final double collapseProgress; // 0 = full month  1 = day view
  final int collapseWeekRow; // 0-based row to keep pinned
  final double rowHeight; // animated view-mode row height
  final CalendarViewMode viewMode;
  final void Function(DateTime) onDayTap;
  final void Function(DateTime)? onDayLongPress;
  final void Function(ScheduledEvent event)? onEditEvent;
  final double circleSlideX; // non-zero in Day View during content drags
  final int settleCount; // cross-week settle trigger
  final double blobDeltaX; // per-frame gesture delta → blob stretch
  final int blobSnapCount; // incremented on release → spring-back
  final DateTime? pendingBloomDate; // pre-bloom target for incoming navigation
  final DayViewSubMode daySubMode;

  /// External scroll controller attached to the SingleChildScrollView so the
  /// parent can read the scroll offset at the moment _enterDay is called.
  final ScrollController? scrollController;
  final GlobalKey? scrollViewportKey;
  final Map<String, List<String>> monthListOrderByDay;
  final void Function(String dayKey, List<ScheduledEvent> orderedEvents)?
      onMonthListOrderChanged;

  /// Scroll offset captured when the Month→Day collapse began.  Passed to
  /// each _AnimatedWeekRow so the selected row translates to visual-y = 0
  /// even when the user previously scrolled in Details view-mode.
  final double collapseScrollOffset;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<ScheduledEvent>>(
      valueListenable: EventStore.instance.events,
      builder: (context, _, __) {
        final firstGridDay = DateTime(year, month, 1).subtract(
          Duration(days: _firstWeekday(year, month)),
        );
        final totalRows = _totalWeekRows(year, month);
        final lastGridDay = firstGridDay.add(
          Duration(days: totalRows * 7 - 1),
        );
        final events = EventStore.instance.expandedEvents(
          from: firstGridDay,
          to: lastGridDay.add(const Duration(days: 1)),
        );
        final eventsByDay = <String, List<ScheduledEvent>>{};
        for (final event in events) {
          final start = _calendarEventStartDate(event);
          if (start == null) continue;
          final end = _calendarEventEndDate(event) ?? start;
          if (end.isBefore(firstGridDay) || start.isAfter(lastGridDay)) {
            continue;
          }
          var day = start.isBefore(firstGridDay) ? firstGridDay : start;
          final clampedEnd = end.isAfter(lastGridDay) ? lastGridDay : end;
          while (!day.isAfter(clampedEnd)) {
            (eventsByDay[_calendarDateKey(day)] ??= []).add(event);
            day = day.add(const Duration(days: 1));
          }
        }
        final orderedEventsByDay = <String, List<ScheduledEvent>>{
          for (final entry in eventsByDay.entries)
            entry.key: _applyMonthListOrder(
              entry.value,
              monthListOrderByDay[entry.key],
            ),
        };
        final listDayKeys = [
          for (var i = 0; i < totalRows * 7; i++)
            _calendarDateKey(firstGridDay.add(Duration(days: i))),
        ];
        final listDayGroups = [
          for (final dayKey in listDayKeys)
            _groupMonthEvents(orderedEventsByDay[dayKey] ?? const []),
        ];
        final selectedDayKey = _calendarDateKey(selectedDate);
        final selectedListIndex = listDayKeys.indexOf(selectedDayKey);
        final selectedListChildIndex =
            selectedListIndex < 0 ? 0 : selectedListIndex;
        final selectedListGroups =
            listDayGroups[selectedListChildIndex];
        final showMonthList =
            viewMode == CalendarViewMode.list &&
            collapseProgress < _kMonthDayTransitionThreshold;
        final estimatedListContentH = showMonthList
            ? _monthListEstimatedHeight(selectedListGroups)
            : 80.0;
        final gridH =
            _kCalendarHeaderToDowGap + _kDayLabelHeight + totalRows * rowHeight;

        return LayoutBuilder(
          builder: (context, constraints) {
        final secondaryC = resolveThemeColor(kSecondaryLabel, context);
        final floatingClearance = floatingTabBarContentBottomClearance(context);
        final emptyStateFloatingClearance =
            floatingTabBarContentBottomClearance(
              context,
              finalContentGap: 16.0,
            );
        // An empty selected day is a viewport placeholder, not a list item.
        // Keep the pill clearance inside the viewport rather than appending it
        // to the scroll document.  That leaves the scroll position at zero
        // while AlwaysScrollable+BouncingScrollPhysics still permits the
        // placeholder to move during a rubber-band overscroll.
        final availableListEmptyStateH = math.max(
          0.0,
          constraints.maxHeight - gridH - emptyStateFloatingClearance,
        );
        final selectedDayIsEmpty =
            listDayGroups[selectedListChildIndex].isEmpty;
        final emptyStateLabelH =
            kEmptyStateLabelFontSize * kLineHeight;
        final emptyStateFallbackH = emptyStateLabelH + 32.0;
        final emptyStateNeedsScrollableFallback =
            selectedDayIsEmpty &&
            availableListEmptyStateH < emptyStateFallbackH;
        final selectedListIsEmpty =
            showMonthList &&
            selectedDayIsEmpty;
        final listContentH = showMonthList
            ? selectedListIsEmpty
                ? emptyStateNeedsScrollableFallback
                    ? emptyStateFallbackH
                    : availableListEmptyStateH
                : estimatedListContentH
            : 80.0;
        // The embedded DCV already supplies a 16 pt trailing section gap
        // outside the collapsible event card. Account for the Floating Tab
        // Bar's height and bottom inset as well, then keep a separate 16 pt
        // gap between whichever element is last (event tile or section
        // header) and the pill.
        final eventContentClearance =
            showMonthList
                ? floatingTabBarContentBottomClearance(
                    context,
                    existingTrailingContentPadding:
                        _kMonthListSectionTrailingContentPadding,
                    finalContentGap: _kMonthListFinalContentGap,
                  )
                : floatingClearance;
        final contentH = selectedDayIsEmpty
            ? showMonthList
                ? emptyStateNeedsScrollableFallback
                    ? gridH +
                        emptyStateFallbackH +
                        emptyStateFloatingClearance
                    : math.max(
                        constraints.maxHeight,
                        gridH +
                            availableListEmptyStateH +
                            emptyStateFloatingClearance,
                      )
                : // Compact, Stacked, and Details end at the grid. Keep only
                  // enough scroll tail to place its final separator 16 pt
                  // above the Floating Tab Bar.
                  math.max(
                    constraints.maxHeight,
                    gridH + emptyStateFloatingClearance,
                  )
            : // Keep a short event list at zero positive scroll extent. The
              // final-content clearance only contributes when the list is
              // long enough to require scrolling; it must not be appended
              // after a viewport-sized document.
              math.max(
                constraints.maxHeight,
                gridH + listContentH + eventContentClearance,
              );
        final emptyH =
            selectedDayIsEmpty && showMonthList ? contentH - gridH : 0.0;
        final emptyStateH = selectedDayIsEmpty
            ? showMonthList
                ? emptyStateNeedsScrollableFallback
                    ? emptyStateFallbackH
                    : availableListEmptyStateH
                : 0.0
            : math.max(0.0, emptyH - eventContentClearance);

        // A non-empty Month List must use the selected DCV's measured height.
        // A collapsed final section therefore measures as its header plus the
        // section wrapper's trailing 16 pt, rather than retaining an estimated
        // event-tile height.
        final monthListUsesNaturalHeight = showMonthList && !selectedDayIsEmpty;

        final document = ClipRect(
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // ── Scrollable body ───────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: _kCalendarHeaderToDowGap),
                  SizedBox(height: _kDayLabelHeight),
                  SizedBox(
                    height: totalRows * rowHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        for (int row = 0; row < totalRows; row++)
                          _AnimatedWeekRow(
                            year: year,
                            month: month,
                            row: row,
                            today: today,
                            selectedDate: selectedDate,
                            collapseProgress: collapseProgress,
                            collapseWeekRow: collapseWeekRow,
                            viewModeRowHeight: rowHeight,
                            screenHeight: constraints.maxHeight,
                            scrollOffset: collapseScrollOffset,
                            eventsByDay: orderedEventsByDay,
                            viewMode: viewMode,
                            onDayTap: onDayTap,
                            onDayLongPress: onDayLongPress,
                            circleSlideX: row == collapseWeekRow
                                ? circleSlideX
                                : 0.0,
                            settleCount: settleCount,
                            blobDeltaX: row == collapseWeekRow
                                ? blobDeltaX
                                : 0.0,
                            blobSnapCount: blobSnapCount,
                            pendingBloomDate: pendingBloomDate,
                            daySubMode: daySubMode,
                          ),
                      ],
                    ),
                  ),
                  if (showMonthList) ...[
                    _MonthSelectedEvents(
                      dayKeys: listDayKeys,
                      dayGroups: listDayGroups,
                      selectedDayIndex: selectedListChildIndex,
                      height: monthListUsesNaturalHeight ? null : listContentH,
                      emptyStateHeight: selectedListIsEmpty
                          ? listContentH
                          : availableListEmptyStateH,
                      onEditEvent: onEditEvent,
                      scrollController: scrollController,
                      scrollViewportKey: scrollViewportKey,
                      onOrderChanged: onMonthListOrderChanged,
                    ),
                    if (monthListUsesNaturalHeight)
                      SizedBox(height: eventContentClearance),
                  ] else if (emptyH > 0)
                    SizedBox(
                      height: emptyH,
                      child: Column(
                        children: [
                          SizedBox(
                            height: emptyStateH,
                            child: Opacity(
                              opacity: collapseProgress <
                                      _kMonthDayTransitionThreshold
                                  ? (1.0 - collapseProgress * 4.0).clamp(
                                      0.0,
                                      1.0,
                                    )
                                  : 0.0,
                              child: Center(
                                child: Text(
                                  'No Events',
                                  style: TextStyle(
                                    inherit: false,
                                    fontFamily: kSFProText,
                                    fontWeight: FontWeight.w400,
                                    fontStyle: FontStyle.normal,
                                    letterSpacing: kTracking16,
                                    height: kLineHeight,
                                    fontSize: kEmptyStateLabelFontSize,
                                    color: secondaryC,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: emptyH - emptyStateH),
                        ],
                      ),
                    ),
                ],
              ),

              // ── Day-of-week header overlay ────────────────────────
              // Painted last = highest z-order, covers rows that overflow
              // upward during the collapse animation.
              // 10px right margin mirrors the day-row inset;
              // week-num column is Expanded (equal to day columns).
              //
              // Scroll-offset compensation: when entering Day View from a
              // scrolled Month View the viewport scroll stays at
              // capturedOffset during the animation.  The DOW header sits
              // at content-y=the fixed header gap, so its viewport-y is
              // fixed relative to the header (minus capturedOffset)
              // (above the fold, invisible).  Translating it DOWN by
              // collapseScrollOffset × collapseProgress brings it into
              // view in lock-step with the week strip arriving at y=28.
              Positioned(
                top: _kCalendarHeaderToDowGap,
                left: 0,
                right: 0,
                height: _kDayLabelHeight,
                child: Transform.translate(
                  offset: Offset(
                    0,
                    collapseScrollOffset * collapseProgress,
                  ),
                  child: ColoredBox(
                    color: resolveThemeColor(kBackgroundColor, context),
                    child: Row(
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        ...List.generate(
                          7,
                          (i) => Expanded(
                            child: Center(
                              child: Text(
                                _kDayLetters[i],
                                style: TextStyle(
                                  fontFamily: kSFProText,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: secondaryC,
                                  letterSpacing: -0.1,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );

        return SingleChildScrollView(
          key: scrollViewportKey,
          controller: scrollController,
          physics: collapseProgress < _kMonthDayTransitionThreshold
              ? const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                )
              : const NeverScrollableScrollPhysics(),
          clipBehavior: Clip.none,
          child: monthListUsesNaturalHeight
              ? ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: document,
                )
              : SizedBox(height: contentH, child: document),
        );
          },
        );
      },
    );
  }
}

// Each individual week row with its Y-translation driven by collapseProgress.
class _AnimatedWeekRow extends StatelessWidget {
  const _AnimatedWeekRow({
    required this.year,
    required this.month,
    required this.row,
    required this.today,
    required this.selectedDate,
    required this.collapseProgress,
    required this.collapseWeekRow,
    required this.viewModeRowHeight,
    required this.screenHeight,
    required this.onDayTap,
    this.onDayLongPress,
    this.circleSlideX = 0.0,
    this.settleCount = 0,
    this.blobDeltaX = 0.0,
    this.blobSnapCount = 0,
    this.pendingBloomDate,
    this.daySubMode = DayViewSubMode.singleDay,
    this.scrollOffset = 0.0,
    this.eventsByDay = const {},
    required this.viewMode,
  });

  final int year, month, row;
  final DateTime today, selectedDate;
  final double collapseProgress;
  final int collapseWeekRow;
  // The mode-switch target height (before collapse interpolation).
  final double viewModeRowHeight;
  final double screenHeight;
  final void Function(DateTime) onDayTap;
  final void Function(DateTime)? onDayLongPress;
  final double circleSlideX;
  final int settleCount;
  final double blobDeltaX;
  final int blobSnapCount;
  final DateTime? pendingBloomDate;
  final DayViewSubMode daySubMode;
  final Map<String, List<ScheduledEvent>> eventsByDay;
  final CalendarViewMode viewMode;

  /// Scroll offset captured at the start of the collapse animation.
  /// Added to translateY (scaled by collapseProgress) for rows that move
  /// upward, so the selected row arrives at visual-y = 0 regardless of how
  /// far the user scrolled in Details view-mode before entering Day View.
  final double scrollOffset;

  @override
  Widget build(BuildContext context) {
    // Current row height: lerps from the Month View mode height to the Day
    // View strip height. The latter grows only when needed to preserve the
    // indicator's minimum bottom gap.
    final currentRowHeight = lerpDouble(
      viewModeRowHeight,
      _dayViewWeekStripHeight(context),
      collapseProgress,
    )!;

    // Natural Y-position in month view (with current animated row height).
    final naturalY = row * currentRowHeight;

    double translateY;

    if (row <= collapseWeekRow) {
      // Selected row + all rows ABOVE it move as one solid block upward.
      // Every row in the block gets the same delta so relative spacing is preserved.
      // At collapseProgress == 1 the selected row lands at y = 0 and all
      // rows above it have negative y — they slide out past the header.
      //
      // scrollOffset compensation: the SingleChildScrollView may have been
      // scrolled before _enterDay was called (Details mode).  The selected
      // row's absolute-top in the scroll-content must equal the viewport's
      // scroll position so that its visual-y is 0.  Adding scrollOffset *
      // collapseProgress achieves this: at colT=0 no effect; at colT=1 the
      // row sits at (collapseWeekRow*h - collapseWeekRow*h + scrollOffset) =
      // scrollOffset, exactly cancelling the viewport's own scrollOffset.
      translateY =
          -(collapseWeekRow * currentRowHeight * collapseProgress) +
          scrollOffset * collapseProgress;
    } else {
      // All rows BELOW the selected row move as one solid block downward.
      // Every row in the block gets the same large delta so they stay together
      // and slide off the bottom of the screen as a unit.
      translateY = screenHeight * collapseProgress;
    }

    return Positioned(
      left: 0,
      right: 0,
      top: naturalY + translateY,
      child: _WeekRow(
        year: year,
        month: month,
        row: row,
        today: today,
        selectedDate: selectedDate,
        rowHeight: currentRowHeight,
        onDayTap: onDayTap,
        onDayLongPress: onDayLongPress,
        eventsByDay: eventsByDay,
        viewMode: viewMode,
        showOverflow:
            collapseProgress > _kMonthDayTransitionThreshold,
        circleSlideX: circleSlideX,
        settleCount: settleCount,
        blobDeltaX: blobDeltaX,
        blobSnapCount: blobSnapCount,
        pendingBloomDate: pendingBloomDate,
        daySubMode: daySubMode,
        collapseProgress: collapseProgress,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _BloomDayCircle — gel/bloom animation wrapper for day-selection circles.
//
// Wraps any day-cell child.  Triggers:
//   • false→true isSel  : bloom in from small scale.
//   • re-tap same day   : pulse (tapCount increments, isSel stays true).
//   • settleCount++     : settle bounce after a cross-week swipe lands.
// ══════════════════════════════════════════════════════════════════════════════
enum _DayAnim { bloomIn, pulse, settle, popBloom, shrink, none }

class _BloomDayCircle extends StatefulWidget {
  const _BloomDayCircle({
    super.key,
    required this.child,
    required this.isSel,
    required this.tapCount,
    required this.lastTappedDate,
    required this.myDate,
    required this.settleCount,
    this.blobSnapCount = 0,
    this.pendingBloomDate,
    this.circleColor,
    required this.circleSize,
  });

  final Widget child; // always rendered at scale 1.0 (day number text)
  final bool isSel;
  final int tapCount;
  final DateTime? lastTappedDate;
  final DateTime myDate;
  final int settleCount;
  final int blobSnapCount;
  // When non-null and equal to myDate, the pre-bloom timer has fired and this
  // circle should start its settle animation before selection is committed.
  final DateTime? pendingBloomDate;
  // Background circle color.  Only the circle scales; the day-number text
  // (child) is never scaled.  null = no background circle (plain day cell).
  final Color? circleColor;
  final double circleSize;

  @override
  State<_BloomDayCircle> createState() => _BloomDayCircleState();
}

class _BloomDayCircleState extends State<_BloomDayCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _bloomIn;
  late final Animation<double> _pulse;
  late final Animation<double> _settle;
  late final Animation<double> _popBloom;
  late final Animation<double> _shrink;
  _DayAnim _activeAnim = _DayAnim.none;
  // Color captured at the moment a selected circle begins deselecting,
  // held for the shrink animation so the circle stays visible while fading.
  Color? _shrinkColor;

  static const double _kPeak = 1.15;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _bloomIn = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 0.55,
          end: _kPeak,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 55,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: _kPeak,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 45,
      ),
    ]).animate(_ctrl);
    _pulse = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: _kPeak,
        ).chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 52,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: _kPeak,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 48,
      ),
    ]).animate(_ctrl);
    // Settle: immediate upward pop (no squash lead-in) then springy return.
    // Starts at 1.0 so the first visible frame is the circle growing — feels
    // instantaneous compared to a squash-first sequence.
    _settle = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.18,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.18,
          end: 0.96,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.96,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_ctrl);
    // popBloom: for incoming days that are already selected in the next panel.
    // Pops dramatically to 1.35x and springs back — more visible than settle.
    _popBloom = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(
          begin: 1.0,
          end: 1.35,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 1.35,
          end: 0.88,
        ).chain(CurveTween(curve: Curves.easeInOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween(
          begin: 0.88,
          end: 1.0,
        ).chain(CurveTween(curve: Curves.easeOut)),
        weight: 30,
      ),
    ]).animate(_ctrl);
    // Shrink: plays when a selected circle is deselected, so it fades out
    // smoothly instead of disappearing in a single frame.  Gives the
    // midnight same-month advance a "drag away" feel.
    _shrink = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).chain(CurveTween(curve: Curves.easeIn)).animate(_ctrl);
    // Always start at rest — do not bloom on mount.
    // The month view mounts fresh each time a zoom-in settles (zoomT crosses
    // 0.999), so initState fires for every day cell, including the selected one.
    // Blooming here would play the animation on every year→month zoom, which
    // is wrong.  All legitimate blooms (tap-select, re-tap pulse, cross-week
    // settle) are triggered from didUpdateWidget instead.
    _ctrl.value = 1.0;
  }

  @override
  void didUpdateWidget(_BloomDayCircle old) {
    super.didUpdateWidget(old);

    // ── Pre-bloom: incoming navigation target ─────────────────────────────
    // The 55% bloom timer set _pendingBloomDate to this day before the nav
    // commit.  Start the settle animation NOW — while the slide is still
    // ~45% from landing — so it's 70% through by the time the swipe ends.
    final isNowPendingBloom =
        widget.pendingBloomDate != null &&
        _sameDay(widget.pendingBloomDate!, widget.myDate) &&
        (old.pendingBloomDate == null ||
            !_sameDay(old.pendingBloomDate!, widget.myDate));
    if (isNowPendingBloom) {
      if (!widget.isSel) {
        // Circle not yet visible (overflow / unselected cell): bloom it in
        // from 0.55 scale — same drama as a tap-select.  This is the typical
        // backward cross-month case (target appears as an overflow cell).
        _activeAnim = _DayAnim.bloomIn;
      } else {
        // Circle already visible (pre-selected in the incoming panel): use a
        // dramatic pop to 1.35× so forward cross-month nav is equally visible
        // even though the circle existed before the bloom timer fired.
        _activeAnim = _DayAnim.popBloom;
      }
      _ctrl.forward(from: 0.0);
      return;
    }

    if (!old.isSel && widget.isSel) {
      if (widget.blobSnapCount > old.blobSnapCount) {
        // Swipe navigation: day was pre-bloomed → let it finish; otherwise rest.
        if (!_ctrl.isAnimating) {
          _ctrl.stop();
          _ctrl.value = 1.0;
          _activeAnim = _DayAnim.none;
        }
      } else {
        // Tap navigation: bloom in from small scale.
        _activeAnim = _DayAnim.bloomIn;
        _ctrl.forward(from: 0.0);
      }
    } else if (widget.isSel &&
        widget.tapCount > old.tapCount &&
        widget.lastTappedDate != null &&
        _sameDay(widget.lastTappedDate!, widget.myDate)) {
      // Re-tap on the already-selected day (enters Day View): pulse.
      _activeAnim = _DayAnim.pulse;
      _ctrl.forward(from: 0.0);
    } else if (widget.isSel && widget.settleCount > old.settleCount) {
      // Cross-week swipe settled: bounce the circle into place.
      _activeAnim = _DayAnim.settle;
      _ctrl.forward(from: 0.0);
    } else if (old.isSel && !widget.isSel) {
      // Deselected: snap instantly back to rest so the circle disappears
      // without any lingering animation (today's faded circle must reappear
      // immediately on the same frame the new day blooms in).
      _ctrl.stop();
      _ctrl.value = 1.0;
      _activeAnim = _DayAnim.none;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      // widget.child (the day-number Text) is cached here — it never scales.
      child: widget.child,
      builder: (ctx, label) {
        final double scale = switch (_activeAnim) {
          _DayAnim.bloomIn => _bloomIn.value,
          _DayAnim.pulse => _pulse.value,
          _DayAnim.settle => _settle.value,
          _DayAnim.popBloom => _popBloom.value,
          _DayAnim.shrink => _shrink.value,
          _DayAnim.none => 1.0,
        };
        // effectiveColor logic:
        //  • Normal selected/today: widget.circleColor (set by parent).
        //  • Pre-bloom on unselected cell: kAccentColor injected while the
        //    incoming circle is still blooming in (bloomIn animation).
        //  • Shrinking deselected circle: use the colour captured at deselect
        //    time so the circle stays visible while it shrinks to 0.
        final Color? effectiveColor = switch (_activeAnim) {
          _DayAnim.bloomIn when !widget.isSel => resolveAccentColor(context),
          _DayAnim.shrink => _shrinkColor,
          _ => widget.circleColor,
        };
        return SizedBox(
          width: widget.circleSize,
          height: widget.circleSize,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (effectiveColor != null)
                Transform.scale(
                  scale: scale,
                  child: Container(
                    width: widget.circleSize,
                    height: widget.circleSize,
                    decoration: BoxDecoration(
                      color: effectiveColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              label!, // day number — always scale 1.0
            ],
          ),
        );
      },
    );
  }
}

class _WeekRow extends StatefulWidget {
  const _WeekRow({
    required this.year,
    required this.month,
    required this.row,
    required this.today,
    required this.selectedDate,
    required this.onDayTap,
    required this.rowHeight,
    this.onDayLongPress,
    this.showOverflow = true,
    this.circleSlideX = 0.0,
    this.settleCount = 0,
    this.blobDeltaX = 0.0,
    this.blobSnapCount = 0,
    this.pendingBloomDate,
    this.daySubMode = DayViewSubMode.singleDay,
    this.collapseProgress = 1.0,
    this.eventsByDay = const {},
    required this.viewMode,
  });

  final int year, month, row;
  final DateTime today, selectedDate;
  final double rowHeight; // current animated row height (view-mode × collapse)
  final void Function(DateTime) onDayTap;
  final void Function(DateTime)? onDayLongPress;
  final bool showOverflow;
  // Non-zero only during Day View content drags: the strip stays fixed and
  // only the selection circle translates in lock-step with the gesture.
  final double circleSlideX;
  // Incremented by the parent on cross-week navigation; triggers settle anim.
  final int settleCount;
  // Blob physics: per-frame drag delta and release stamp.
  final double blobDeltaX;
  final int blobSnapCount;
  // Target date for pre-bloom: circle starts settle animation before selection.
  final DateTime? pendingBloomDate;
  final DayViewSubMode daySubMode;
  // 0 = month view, 1 = day view — used to fade the multi-day pill so it
  // doesn't persist while transitioning back to Month View.
  final double collapseProgress;
  final Map<String, List<ScheduledEvent>> eventsByDay;
  final CalendarViewMode viewMode;

  @override
  State<_WeekRow> createState() => _WeekRowState();
}

class _WeekRowState extends State<_WeekRow> {
  // Tracks taps so _BloomDayCircle can distinguish re-taps from new selections.
  int _tapCount = 0;
  DateTime? _lastTappedDate;

  void _onDayTap(DateTime date) {
    setState(() {
      _tapCount++;
      _lastTappedDate = date;
    });
    widget.onDayTap(date);
  }

  @override
  Widget build(BuildContext context) {
    final offset = _firstWeekday(widget.year, widget.month);
    final days = _daysInMonth(widget.year, widget.month);
    final firstIdx = widget.row * 7;
    final firstDayNum = firstIdx - offset + 1;

    final firstDayOfRow = DateTime(widget.year, widget.month, firstDayNum);
    final weekNum = _isoWeekNumber(firstDayOfRow);
    final isSliding = widget.circleSlideX != 0.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalW = constraints.maxWidth;
        final dayIndicatorSize =
            _kDayIndicatorDiameter * textScaleRatioFor(context, 17.0);
        final separatorColor = resolveThemeColor(kSeparatorColor, context);
        final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
        final secondaryLabel = resolveThemeColor(kSecondaryLabel, context);
        // 8 equally-spaced columns: col 0 = week-num, col 1-7 = Mon-Sun.
        // A 7px right margin keeps the last day column from being too tight.
        final cellW = (totalW - 7) / 8;

        // Pre-compute the selected column for Multi Day mode.
        // Used both to style the next-day cell text AND to draw the pill.
        // multiDayHasExtension is true only when the selected day is in this
        // row AND is not the last column (Sunday), so the next day fits here.
        int? multiDaySelCol;
        if (widget.daySubMode == DayViewSubMode.multiDay) {
          for (int c = 0; c < 7; c++) {
            final i2 = firstIdx + c;
            final d2 = i2 - offset + 1;
            final dt2 = DateTime(widget.year, widget.month, d2);
            if (_sameDay(dt2, widget.selectedDate)) {
              multiDaySelCol = c;
              break;
            }
          }
        }
        final bool multiDayHasExtension =
            multiDaySelCol != null && multiDaySelCol < 6;

        final rowContent = Container(
          height: widget.rowHeight,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: separatorColor, width: 0.5),
            ),
          ),
          child: Row(
            children: [
              // Week number — equal-width column (same as day columns)
              // Top-aligned to match day-circle vertical centre (kDayCircleOffset).
              Expanded(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: kFixedTopPadding),
                    child: SizedBox(
                      height: dayIndicatorSize,
                      child: Center(
                        child: Text(
                          '$weekNum',
                          style: TextStyle(
                            fontFamily: kSFProText,
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                            color: secondaryLabel,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Day cells
              ...List.generate(7, (col) {
                final idx = firstIdx + col;
                final day = idx - offset + 1;
                final date = DateTime(widget.year, widget.month, day);
                final isOverflow = day < 1 || day > days;
                final displayDay = date.day;
                final isToday = _sameDay(date, widget.today);
                final isSel = _sameDay(date, widget.selectedDate);
                // The month-list dot follows the first event in the same
                // ordering shown below: all-day events first, then timed
                // sections in time order. Do not use the raw EventStore order
                // here, or a timed event can incorrectly win over an all-day
                // event for the dot color.
                final dayEvents = [
                  for (final group in _groupMonthEvents(
                    widget.eventsByDay[_calendarDateKey(date)] ?? const [],
                  ))
                    ...group,
                ];

                if (isOverflow && !widget.showOverflow) {
                  return const Expanded(child: SizedBox.shrink());
                }

                final Widget dayCell;
                if (isSliding) {
                  // In sliding mode every per-cell background is suppressed.
                  // The today indicator is rendered as a separate non-deforming
                  // Positioned layer in the Stack below the blob, so the blob's
                  // teardrop shape never distorts the today circle.
                  dayCell = const SizedBox.shrink();
                } else {
                  // Normal (non-sliding) mode — wrap in gel/bloom animation.
                  //
                  // Only the circle background is animated (scales).  The day
                  // number text is always rendered at scale 1.0 — it's passed
                  // as _BloomDayCircle.child and never included in the scale.
                  //
                  // isPendingBloom: the 55% timer has fired for this cell and
                  // the settle animation is about to start (or is running).
                  // Show white text + kAccentColor circle the same instant the
                  // circle begins growing, before isSel becomes true.
                  final bool isPendingBloom =
                      widget.pendingBloomDate != null &&
                      _sameDay(widget.pendingBloomDate!, date);

                  // In Multi Day mode the day after the selection is part of
                  // the extended view — render it with white text so it is
                  // readable against the 40%-opacity circle added in the Stack.
                  // Only true when the selected day is in THIS row AND is not
                  // Sunday (selCol < 6), i.e. when the extension is drawn.
                  // Gated on collapseProgress > 0.0 — same snap threshold as the
                  // 40%-opacity pill — so the white text and the pill appear and
                  // disappear together, in sync with the header-title transition.
                  final bool isNextDayMulti =
                      multiDayHasExtension &&
                      widget.collapseProgress > 0.0 &&
                      _sameDay(
                        date,
                        widget.selectedDate.add(const Duration(days: 1)),
                      );

                  final Color? circleColor;
                  final Color textColor;
                  final FontWeight fontWeight;
                  if (isSel || isPendingBloom) {
                    circleColor = resolveAccentColor(context);
                    textColor = CupertinoColors.white;
                    fontWeight = FontWeight.w600;
                  } else if (isNextDayMulti) {
                    // No circle here — the 40%-opacity indicator is drawn as
                    // a Positioned layer in the Stack after rowContent.
                    circleColor = null;
                    textColor = CupertinoColors.white;
                    fontWeight = FontWeight.w600;
                  } else if (isToday) {
                    circleColor = resolveAccentColor(context).withOpacity(0.40);
                    textColor = CupertinoColors.white;
                    fontWeight = FontWeight.w600;
                  } else {
                    circleColor = null;
                    textColor = isOverflow ? secondaryLabel : primaryLabel;
                    fontWeight = FontWeight.w400;
                  }

                    dayCell = _BloomDayCircle(
                      key: ValueKey(date),
                      isSel: isSel,
                      tapCount: _tapCount,
                      lastTappedDate: _lastTappedDate,
                      myDate: date,
                      settleCount: widget.settleCount,
                      blobSnapCount: widget.blobSnapCount,
                      pendingBloomDate: widget.pendingBloomDate,
                      circleColor: circleColor,
                       circleSize: dayIndicatorSize,
                      child: Text(
                        '$displayDay',
                        style: TextStyle(
                          fontFamily: kSFProText,
                          fontSize: 17,
                          fontWeight: fontWeight,
                          color: textColor,
                        ),
                      ),
                    );
                }

                return Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _onDayTap(date),
                    onLongPress: widget.onDayLongPress != null
                        ? () => widget.onDayLongPress!(date)
                        : null,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: Padding(
                        padding: const EdgeInsets.only(top: kFixedTopPadding),
                        child: SizedBox(
                          height: widget.rowHeight - kFixedTopPadding,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.topCenter,
                            children: [
                              dayCell,
                              if (widget.viewMode == CalendarViewMode.list &&
                                  widget.collapseProgress <
                                      _kMonthDayTransitionThreshold &&
                                  dayEvents.isNotEmpty &&
                                  !isOverflow)
                                Positioned(
                                  top: _monthListDotTop(widget.rowHeight),
                                  child: _MonthEventDots(
                                    events: dayEvents,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // 7px right margin — last day column ends 7px from the edge.
              const SizedBox(width: 7),
            ],
          ),
        );

        if (!isSliding) {
          // In Multi Day mode draw a single pill spanning both the selected day
          // and the next day.  The pill sits BEHIND rowContent so the full-opacity
          // selected-day circle (_BloomDayCircle, inside rowContent) renders on top.
          // The pill is gated on collapseProgress so it fades out when transitioning
          // back to Month View and never bleeds into the non-Day-View grid.
          if (multiDayHasExtension) {
            final selCol = multiDaySelCol!;
            final nextCol = selCol + 1;
            // Column centres (col 0 = week-number, day cols are 1–7).
            final selCX = (selCol + 1.5) * cellW;
            final nextCX = (nextCol + 1.5) * cellW;

            return Stack(
              children: [
                // True pill: left-rounded at selDay, right-rounded at nextDay.
                // 40 % opacity — the full-opacity circle from rowContent sits on top.
                // Snaps in sync with the header title: _view becomes CalendarView.day
                // BEFORE _collapseCtrl.forward() fires, so the title reads "Jul 09"
                // from frame 0 of the enter animation (colT > 0).  On exit, _view
                // stays day until reverse() fully completes (colT → 0), so the pill
                // also stays visible for the whole exit.  Result: both snap together.
                if (widget.collapseProgress > 0.0)
                  Positioned(
                    left: selCX - dayIndicatorSize / 2,
                    top: kFixedTopPadding,
                    width: nextCX - selCX + dayIndicatorSize,
                    height: dayIndicatorSize,
                    child: Container(
                      decoration: ShapeDecoration(
                        color: resolveAccentColor(context).withOpacity(0.40),
                        shape: BoundedSquircleStadiumBorder(
                          radius: dayIndicatorSize / 2,
                        ),
                      ),
                    ),
                  ),
                // rowContent on top: selected-day full circle, next-day white text.
                rowContent,
              ],
            );
          }
          return rowContent;
        }

        // ── Sliding-circle overlay ─────────────────────────────────────────
        // The week strip (labels, week number, today faded circle) stays
        // completely stationary.  Only the selected-day full-opacity circle
        // translates between column positions as the user drags.
        //
        // circleSlideX < 0 → dragging left → next day (circle moves RIGHT)
        // circleSlideX > 0 → dragging right → prev day (circle moves LEFT)
        //
        // At a full swipe (|circleSlideX| == totalW) the circle has moved
        // exactly one cellW — landing precisely on the adjacent column.
        // Column centres: weekday 1 (Mon) → col 1 → (1 + 0.5) * cellW, etc.
        final curCX = (widget.selectedDate.weekday + 0.5) * cellW;
        final circleTranslateX = -widget.circleSlideX * cellW / totalW;

        // ── Numbers overlay (top layer) ────────────────────────────────
        // Drawn above the sliding circle so numbers never move, only the
        // blue circle slides beneath them. IgnorePointer passes all taps
        // through to rowContent's GestureDetectors below.
        final numbersOverlay = IgnorePointer(
          child: SizedBox(
            height: widget.rowHeight,
            child: Row(
              children: [
                const Expanded(child: SizedBox.shrink()), // week-num spacer
                ...List.generate(7, (col) {
                  final idx2 = firstIdx + col;
                  final day2 = idx2 - offset + 1;
                  final date2 = DateTime(widget.year, widget.month, day2);
                  final isOverflow2 = day2 < 1 || day2 > days;
                  final isToday2 = _sameDay(date2, widget.today);
                  final isSel2 = _sameDay(date2, widget.selectedDate);

                  if (isOverflow2 && !widget.showOverflow) {
                    return const Expanded(child: SizedBox.shrink());
                  }

                  // White if the sliding circle is currently over this column,
                  // or if today's faded circle sits here, or if this column is
                  // covered by the Multi Day pill's second cell (the extension
                  // that slides one cell to the right of the blob).  Without
                  // this last condition the "next day" text snaps to normal
                  // at the very first frame of a drag instead of tracking the
                  // pill smoothly.
                  final double circleCenter = curCX + circleTranslateX;
                  final double colCenter = (col + 1.5) * cellW;
                  final bool isUnderCircle =
                      (circleCenter - colCenter).abs() < cellW * 0.5;
                  // The sliding pill always extends one cellW to the right of the
                  // blob centre.  A column is "under the pill extension" when its
                  // centre is within half a cell of that extended position.
                  final bool isUnderPillExtension =
                      multiDayHasExtension &&
                      widget.collapseProgress > 0.0 &&
                      (circleCenter + cellW - colCenter).abs() < cellW * 0.5;

                  final Color c;
                  final FontWeight fw;
                  if (isUnderCircle || isUnderPillExtension || isToday2) {
                    c = CupertinoColors.white;
                    fw = FontWeight.w600;
                  } else {
                    c = isOverflow2 ? secondaryLabel : primaryLabel;
                    fw = FontWeight.w400;
                  }

                  return Expanded(
                    child: Center(
                      child: Text(
                        '${date2.day}',
                        style: TextStyle(
                          fontFamily: kSFProText,
                          fontSize: 17,
                          fontWeight: fw,
                          color: c,
                        ),
                      ),
                    ),
                  );
                }),
                const SizedBox(width: 7),
              ],
            ),
          ),
        );

        // Locate today's column in this row — includes overflow cells so the
        // indicator stays visible when today falls in a cross-month week strip.
        // Dart's DateTime handles out-of-range day numbers correctly (e.g.
        // DateTime(2026, 6, 0) == May 31, 2026), so no bounds guard is needed.
        double? todayCX;
        for (int c = 0; c < 7; c++) {
          final i2 = firstIdx + c;
          final d2 = i2 - offset + 1;
          if (_sameDay(DateTime(widget.year, widget.month, d2), widget.today)) {
            todayCX = (c + 1.5) * cellW;
            break;
          }
        }

        // Whether today's cell falls within the sliding pill's range.
        // When true the pill already provides the 40%-opacity tint, so
        // the separate Positioned today indicator is suppressed to prevent
        // double-compositing (two 40%-opacity layers stacking to ~64%).
        // The pill spans from the blob centre (circleCenter) to one cellW
        // to its right; a today circle at todayCX is "under the pill" if
        // it sits within half a cell of either of those two positions.
        final double circleCenter2 = curCX + circleTranslateX;
        final bool todayUnderPill =
            todayCX != null &&
            multiDayHasExtension &&
            widget.collapseProgress > 0.0 &&
            ((circleCenter2 - todayCX!).abs() < cellW * 0.5 ||
                (circleCenter2 + cellW - todayCX!).abs() < cellW * 0.5);

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            rowContent,
            // ── Today indicator: fixed circle, not affected by blob shape ─
            // Suppressed when today is already covered by the sliding Multi
            // Day pill — the pill alone provides the 40% tint, and rendering
            // both would compound two semi-transparent layers.
            if (todayCX != null && !todayUnderPill)
              Positioned(
                left: todayCX - dayIndicatorSize / 2,
                top: kFixedTopPadding,
                child: Container(
                  width: dayIndicatorSize,
                  height: dayIndicatorSize,
                  decoration: BoxDecoration(
                    color: resolveAccentColor(context).withOpacity(0.40),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            // ── Multi Day sliding pill — translates with the blob circle ─
            // Same snap timing as the static pill and the header title.
            // Width matches the static pill exactly: selCX to nextCX + one pill
            // diameter (36) so it keeps its two-day pill shape while sliding,
            // instead of collapsing to a single-day circle-with-offset.
            if (multiDayHasExtension && widget.collapseProgress > 0.0)
              Positioned(
                left:
                    (multiDaySelCol! + 1.5) * cellW -
                    dayIndicatorSize / 2 +
                    circleTranslateX,
                top: kFixedTopPadding,
                width:
                    cellW +
                    dayIndicatorSize, // spans selDay centre to nextDay centre + caps
                height: dayIndicatorSize,
                child: Container(
                  decoration: ShapeDecoration(
                    color: resolveAccentColor(context).withOpacity(0.40),
                    shape: BoundedSquircleStadiumBorder(
                      radius: dayIndicatorSize / 2,
                    ),
                  ),
                ),
              ),
            // ── Blob: full-opacity sliding circle (no text) ──────────────
            Positioned(
              left: curCX - dayIndicatorSize / 2 + circleTranslateX,
              top: kFixedTopPadding,
              child: _BlobCircle(
                dragDeltaX: widget.blobDeltaX,
                snapCount: widget.blobSnapCount,
                size: dayIndicatorSize,
              ),
            ),
            // ── Numbers: always on top, never move ───────────────────────
            numbersOverlay,
          ],
        );
      },
    );
  }
}

class _MonthEventDots extends StatelessWidget {
  const _MonthEventDots({required this.events});

  final List<ScheduledEvent> events;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(
        color: resolveEventCategoryColor(context, events.first),
        shape: BoxShape.circle,
      ),
    );
  }
}

double _monthListDotTop(double rowHeight) =>
    ((rowHeight - kFixedTopPadding + _kDayIndicatorDiameter) / 2) -
    (_kMonthListDotDiameter / 2);

class _MonthSelectedEvents extends StatelessWidget {
  const _MonthSelectedEvents({
    required this.dayKeys,
    required this.dayGroups,
    required this.selectedDayIndex,
    required this.height,
    required this.emptyStateHeight,
    this.onEditEvent,
    this.scrollController,
    this.scrollViewportKey,
    this.onOrderChanged,
  });

  final List<String> dayKeys;
  final List<List<List<ScheduledEvent>>> dayGroups;
  final int selectedDayIndex;
  final double? height;
  final double emptyStateHeight;
  final void Function(ScheduledEvent event)? onEditEvent;
  final ScrollController? scrollController;
  final GlobalKey? scrollViewportKey;
  final void Function(String dayKey, List<ScheduledEvent> orderedEvents)?
      onOrderChanged;

  @override
  Widget build(BuildContext context) {
    final selectedIndex =
        selectedDayIndex.clamp(0, dayGroups.length - 1) as int;
    final children = [
      for (var dayIndex = 0; dayIndex < dayGroups.length; dayIndex++)
        KeyedSubtree(
          key: ValueKey(dayKeys[dayIndex]),
          child: Builder(
            builder: (context) {
              final events = [
                for (final group in dayGroups[dayIndex]) ...group,
              ];
              if (events.isEmpty) {
                return SizedBox(
                  height: emptyStateHeight,
                  child: Center(
                    child: Text(
                      'No Events',
                      style: TextStyle(
                        inherit: false,
                        fontFamily: kSFProText,
                        fontWeight: FontWeight.w400,
                        fontStyle: FontStyle.normal,
                        letterSpacing: kTracking16,
                        height: kLineHeight,
                        fontSize: kEmptyStateLabelFontSize,
                        color: resolveThemeColor(kSecondaryLabel, context),
                      ),
                    ),
                  ),
                );
              }
              return buildDcvEventList(
                events: events,
                onEditEvent: onEditEvent,
                onManualOrderChanged: (orderedEvents) {
                  onOrderChanged?.call(dayKeys[dayIndex], orderedEvents);
                },
                scrollController: scrollController,
                scrollViewportKey: scrollViewportKey,
              );
            },
          ),
        ),
    ];
    if (height == null) {
      return children[selectedIndex];
    }
    return SizedBox(
      width: double.infinity,
      height: height,
      child: IndexedStack(
        index: selectedIndex,
        alignment: Alignment.topCenter,
        children: children,
      ),
    );
  }
}

class _MonthEventGroup extends StatefulWidget {
  const _MonthEventGroup({
    required this.events,
    this.onEditEvent,
  });

  final List<ScheduledEvent> events;
  final void Function(ScheduledEvent event)? onEditEvent;

  @override
  State<_MonthEventGroup> createState() => _MonthEventGroupState();
}

class _MonthEventGroupState extends State<_MonthEventGroup> {
  bool _isCollapsed = false;
  late List<ScheduledEvent> _orderedEvents;
  final Map<String, GlobalKey> _eventKeys = {};
  String? _draggingEventId;
  OverlayEntry? _dragOverlay;
  double _dragGlobalY = 0.0;

  @override
  void initState() {
    super.initState();
    _orderedEvents = List<ScheduledEvent>.of(widget.events);
  }

  @override
  void didUpdateWidget(covariant _MonthEventGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_draggingEventId != null) return;

    final incomingById = {for (final event in widget.events) event.id: event};
    final incomingIds = incomingById.keys.toSet();
    final currentIds = _orderedEvents.map((event) => event.id).toSet();
    if (incomingIds.length != currentIds.length ||
        !incomingIds.containsAll(currentIds)) {
      _orderedEvents = List<ScheduledEvent>.of(widget.events);
      _eventKeys.removeWhere((id, _) => !incomingIds.contains(id));
      return;
    }

    // Preserve a local manual reorder while refreshing event objects from the
    // store after an edit or category-color update.
    _orderedEvents = [
      for (final event in _orderedEvents) incomingById[event.id]!,
    ];
  }

  @override
  void dispose() {
    _dragOverlay?.remove();
    _dragOverlay = null;
    super.dispose();
  }

  void _startReorder(ScheduledEvent event, Offset globalPosition) {
    if (_draggingEventId != null) return;
    final key = _eventKeys[event.id];
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached || !box.hasSize) return;

    final offset = box.localToGlobal(Offset.zero);
    final size = box.size;
    _dragGlobalY = globalPosition.dy;
    setState(() => _draggingEventId = event.id);

    _dragOverlay = OverlayEntry(
      builder: (context) => Positioned(
        left: offset.dx,
        top: _dragGlobalY - size.height / 2,
        width: size.width,
        child: IgnorePointer(
          child: Transform.scale(
            scale: 1.05,
            child: buildDcvEventCard(
              event: event,
              dotColor: _monthEventDotColor(context, event),
              isFirst: true,
              isLast: true,
              isGrouped: false,
              elevatedShadow: true,
            ),
          ),
        ),
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _dragOverlay != null) {
        Overlay.of(context).insert(_dragOverlay!);
      }
    });
  }

  void _updateReorder(Offset globalPosition) {
    if (_draggingEventId == null) return;
    _dragGlobalY = globalPosition.dy;
    _dragOverlay?.markNeedsBuild();

    final currentIndex =
        _orderedEvents.indexWhere((event) => event.id == _draggingEventId);
    if (currentIndex < 0) return;

    var targetIndex = _orderedEvents.length;
    for (var index = 0; index < _orderedEvents.length; index++) {
      final event = _orderedEvents[index];
      if (event.id == _draggingEventId) continue;
      final key = _eventKeys[event.id];
      final box = key?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (globalPosition.dy < top + box.size.height / 2) {
        targetIndex = index;
        break;
      }
    }
    if (targetIndex > currentIndex) targetIndex--;
    if (targetIndex == currentIndex) return;

    final next = List<ScheduledEvent>.of(_orderedEvents);
    final moving = next.removeAt(currentIndex);
    next.insert(targetIndex.clamp(0, next.length), moving);
    setState(() => _orderedEvents = next);
  }

  void _endReorder() {
    _dragOverlay?.remove();
    _dragOverlay = null;
    if (mounted) setState(() => _draggingEventId = null);
  }

  @override
  Widget build(BuildContext context) {
    final events = _orderedEvents;
    final isAllDay = events.first.isAllDay || events.first.time == null;
    final header =
        isAllDay ? 'All-day' : dcvTimeSectionKey(events.first.time!);
    final dotColors = [
      for (final event in events) _monthEventDotColor(context, event),
    ];
    return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            buildDcvSectionLabel(
              text: header,
              isFirst: true,
               isCollapsed: _isCollapsed,
              accentColor: resolveAccentColor(context),
               onTap: () => setState(() => _isCollapsed = !_isCollapsed),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeInOut,
               child: _isCollapsed
                  ? const SizedBox.shrink()
                  : Container(
                      clipBehavior: Clip.antiAlias,
                      decoration: ShapeDecoration(
                        color: resolveThemeColor(kSbSurface, context),
                        shape: const BoundedSquircleStadiumBorder(
                          radius: kSbCornerRadius,
                        ),
                        shadows: resolveThemeShadows(kCardShadow, context),
                      ),
                      child: Column(
                        children: [
                          for (var index = 0; index < events.length; index++)
                            KeyedSubtree(
                              key: _eventKeys.putIfAbsent(
                                events[index].id,
                                GlobalKey.new,
                              ),
                              child: Opacity(
                                opacity: events[index].id == _draggingEventId
                                    ? 0.0
                                    : 1.0,
                                child: buildDcvEventCard(
                                  event: events[index],
                                  dotColor: dotColors[index],
                                  isFirst: index == 0,
                                  isLast: index == events.length - 1,
                                  reorderable: true,
                                  onReorderStart: (position) =>
                                      _startReorder(events[index], position),
                                  onReorderUpdate: _updateReorder,
                                  onReorderEnd: _endReorder,
                                  onReorderCancel: _endReorder,
                                  onEdit: widget.onEditEvent == null
                                      ? null
                                      : () => widget.onEditEvent!(events[index]),
                                  onDelete: () => confirmDeleteEvent(
                                    context,
                                    events[index],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        );
  }
}

Color _monthEventDotColor(BuildContext context, ScheduledEvent event) {
  return resolveEventCategoryColor(context, event);
}

// ══════════════════════════════════════════════════════════════════════════════
// _DayListPlaceholder — shown in the content area when List sub-mode is active.
//
// Mirrors the Events Tab's _CategoryDetailView empty-state exactly:
//   list_bullet icon (64 px, kSecondaryLabel)
//   "No Events"  headline  (22 px SFProText w700)
//   Subtitle     body copy (15 px SFProText   w400)
// ══════════════════════════════════════════════════════════════════════════════
class _DayListPlaceholder extends StatelessWidget {
  const _DayListPlaceholder();

  @override
  Widget build(BuildContext context) {
    final primaryLabel = resolveThemeColor(kPrimaryLabel, context);
    final secondaryLabel = resolveThemeColor(kSecondaryLabel, context);
    final emptyIcon = resolveThemeColor(kEmptyStateIcon, context);
    // CustomScrollView gives the content area the same rubber-band overscroll
    // feel as the other screens (Month View, Events Tab).  SliverFillRemaining
    // with hasScrollBody:false keeps the content centred while still allowing
    // the bounce gesture to register.
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      slivers: [
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FixedSFIcon(
                    SFIcons.sf_list_bullet,
                    fontSize: 65,
                    color: emptyIcon,
                    fontWeight: FontWeight.w600,
                  ),
                  SizedBox(height: 18),
                  Text(
                    'No Events',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      inherit: false,
                      color: primaryLabel,
                      fontSize: 22,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w700,
                      fontStyle: FontStyle.normal,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Add a new event by tapping + button',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      inherit: false,
                      color: secondaryLabel,
                      fontSize: 15,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w400,
                      fontStyle: FontStyle.normal,
                      letterSpacing: kTracking16,
                      height: kLineHeight,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: floatingTabBarContentBottomClearance(context),
          ),
        ),
      ],
    );
  }
}

// Parent-level opaque cover for the Day View DOW row. This deliberately
// duplicates the letters from _MonthView: the cover must sit above all three
// horizontally-sliding month panels, otherwise an adjacent panel's translated
// week row can bleed through the DOW boundary.
class _DayViewDowMask extends StatelessWidget {
  const _DayViewDowMask();

  @override
  Widget build(BuildContext context) {
    final secondaryLabel = resolveThemeColor(kSecondaryLabel, context);
    return ColoredBox(
      color: resolveThemeColor(kBackgroundColor, context),
      child: Column(
        children: [
          const SizedBox(height: _kCalendarHeaderToDowGap),
          SizedBox(
            height: _kDayLabelHeight,
            child: Row(
              children: [
                const Expanded(child: SizedBox.shrink()),
                ...List.generate(
                  7,
                  (i) => Expanded(
                    child: Center(
                      child: Text(
                        _kDayLetters[i],
                        style: TextStyle(
                          fontFamily: kSFProText,
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: secondaryLabel,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _BlobCircle — velocity-driven gel blob for Day View drags.
//
// Physics (matches Apple Liquid Glass):
//   • stretch  = f(per-frame drag speed)  — faster swipe → more elongation
//   • squash   = 1 / √stretch             — preserves visual "mass/volume"
//   • rotation = atan2(0, dragDeltaX)     — always aligns along travel axis
//   • on release → AnimationController(elasticOut) springs back to circle
//
// The blob is a plain circle Container scaled by a Transform matrix each
// frame.  No CustomPainter — the GPU handles smooth antialiasing of the
// scaled circle automatically.
// ══════════════════════════════════════════════════════════════════════════════
class _BlobCircle extends StatefulWidget {
  const _BlobCircle({
    required this.dragDeltaX,
    required this.snapCount,
    required this.size,
  });

  /// Horizontal gesture delta in logical px for the current frame.
  /// Non-zero while the finger is moving; zero between frames and after release.
  final double dragDeltaX;

  /// Incremented each time the finger is lifted.  Used to trigger spring-back.
  final int snapCount;
  final double size;

  @override
  State<_BlobCircle> createState() => _BlobCircleState();
}

class _BlobCircleState extends State<_BlobCircle>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _springAnim;

  // Current stretch factor (≥ 1.0).  Updated every drag frame; animated
  // back to 1.0 by _springAnim on release.
  double _stretch = 1.0;

  // Rotation in radians — aligns the elongation axis with the drag direction.
  double _rotation = 0.0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    // Start with a no-op animation so _springAnim is always valid.
    _springAnim = Tween<double>(begin: 1.0, end: 1.0).animate(_ctrl);
  }

  @override
  void didUpdateWidget(_BlobCircle old) {
    super.didUpdateWidget(old);

    if (widget.snapCount != old.snapCount) {
      // Finger lifted — smoothly settle back to a perfect circle (no overshoot).
      _springAnim = Tween<double>(
        begin: _stretch,
        end: 1.0,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0.0);
    } else if (widget.dragDeltaX != 0.0) {
      if (_ctrl.isAnimating) _ctrl.stop();

      final speed = widget.dragDeltaX.abs();
      setState(() {
        // Map speed (px/frame) → stretch.  Coefficient raised to 0.06 so even
        // slow drags produce a visible response; cap lowered to 0.50 for a
        // subtler maximum deformation.
        //   slow drag  ~3 px  → stretch ≈ 1.18
        //   medium     ~8 px  → stretch ≈ 1.48
        //   fast fling ~15 px → stretch ≈ 1.50  (cap = 1.50)
        _stretch = 1.0 + (speed * 0.06).clamp(0.0, 0.50);
        // Align blob axis with travel direction (left vs right).
        _rotation = math.atan2(0, widget.dragDeltaX); // 0 or π
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = resolveThemeColor(kBackgroundColor, context);
    final separatorColor = resolveThemeColor(kSeparatorColor, context);
    final secondaryLabel = resolveThemeColor(kSecondaryLabel, context);
    return AnimatedBuilder(
      animation: _ctrl,
      // Cache the circle widget — only the Transform wrapper rebuilds.
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: resolveAccentColor(context),
          shape: BoxShape.circle,
        ),
      ),
      builder: (context, child) {
        final s = _ctrl.isAnimating ? _springAnim.value : _stretch;
        final squash = 1.0 / math.sqrt(s); // mass preservation

        return Transform.rotate(
          angle: _rotation,
          child: Transform.scale(scaleX: s, scaleY: squash, child: child),
        );
      },
    );
  }
}

// _DayBanner — animated strip below the week strip.
// Single Day: "Wednesday – Jun 24, 2026" centred.
// Multi Day: separators slide in from right; single-day label slides left and
// is clipped by the incoming centre separator; two short labels fade/slide in.
class _DayBanner extends StatefulWidget {
  const _DayBanner({
    super.key,
    required this.date,
    required this.today,
    this.daySubMode = DayViewSubMode.singleDay,
    // slideX / screenW are non-zero only in Multi Day navigation mode.
    // When set, the banner renders column-level sliding (shared day at half
    // speed) instead of the normal static/morphing layout.
    this.slideX = 0.0,
    this.screenW = 0.0,
  });
  final DateTime date;
  final DateTime today;
  final DayViewSubMode daySubMode;
  final double slideX;
  final double screenW;

  @override
  State<_DayBanner> createState() => _DayBannerState();
}

class _DayBannerState extends State<_DayBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  static const _kWeekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  static const _kWeekdaysShort = [
    'Mon',
    'Tue',
    'Wed',
    'Thu',
    'Fri',
    'Sat',
    'Sun',
  ];
  static const _kMonths = [
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
  static final _kLabelStyleBase = TextStyle(
    fontFamily: kSFProText,
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: kPrimaryLabel,
    letterSpacing: -0.1,
  );

  /// Returns the accent style when [d] is today, normal style otherwise.
  TextStyle _styleFor(DateTime d, BuildContext context) {
    final t = widget.today;
    final base = resolveThemeTextStyle(_kLabelStyleBase, context);
    if (d.year == t.year && d.month == t.month && d.day == t.day) {
      return base.copyWith(
        color: resolveAccentColor(context),
        fontWeight: FontWeight.w600,
      );
    }
    return base;
  }

  String _shortLabel(DateTime d) =>
      '${_kWeekdaysShort[d.weekday - 1]}, '
      '${_kMonths[d.month - 1]} ${d.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      // Always start at 0 so the separator-slide animation plays every time
      // the banner enters the tree (i.e. each time Day View is opened).
      value: 0.0,
    );
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
    // Multi Day mode: play the morph immediately on first appearance.
    // Single Day mode: stays at 0 (no separators needed).
    if (widget.daySubMode == DayViewSubMode.multiDay) _ctrl.forward();
  }

  @override
  void didUpdateWidget(_DayBanner old) {
    super.didUpdateWidget(old);
    if (widget.daySubMode != old.daySubMode) {
      widget.daySubMode == DayViewSubMode.multiDay
          ? _ctrl.forward()
          : _ctrl.reverse();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = resolveThemeColor(kBackgroundColor, context);
    final separatorColor = resolveThemeColor(kSeparatorColor, context);
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final t = _anim.value;
        return Container(
          decoration: BoxDecoration(
            color: backgroundColor,
            border: Border(
              bottom: BorderSide(color: separatorColor, width: 0.5),
            ),
          ),
          child: LayoutBuilder(
            builder: (ctx, cons) {
              final totalW = cons.maxWidth;
              final labelColW = _hourLabelColW(MediaQuery.textScalerOf(ctx));
              final contentW = totalW - labelColW;
              final midX = labelColW + contentW / 2;

              // Left separator slides in from BEYOND the LEFT viewport edge.
              // At t=0 it sits at -0.5 (hidden); at t=1 it lands on the
              // shifted Multi-Day label divider.
              final sep1Target =
                  labelColW + _kMultiDayIndicatorDividerShift - 0.25;
              final sep1X = -0.5 + (sep1Target + 0.5) * t;
              // Centre separator slides in from BEYOND the RIGHT viewport edge.
              // At t=0 it sits at totalW (hidden); at t=1 it lands at midX-0.25.
              final sep2X = totalW + (midX - 0.25 - totalW) * t;

              final nextDate = widget.date.add(const Duration(days: 1));

              // Text segments that morph from the single-day label to the
              // multi-day left label.  Letters shared by both states stay put;
              // letters that disappear clip out from the right; the comma clips in.
              //
              //  Single-day:  [shortDay][tailDay][ – ][monthDay][, year]
              //  Multi-day:   [shortDay][       ][, ][monthDay][      ]
              //
              final shortDay = _kWeekdaysShort[widget.date.weekday - 1];
              final tailDay = _kWeekdays[widget.date.weekday - 1].substring(
                shortDay.length,
              ); // e.g. "day", "sday"
              final monthDay =
                  '${_kMonths[widget.date.month - 1]} '
                  '${widget.date.day.toString().padLeft(2, '0')}';
              final yearStr = ', ${widget.date.year}';

              // ── Multi Day sliding layout ─────────────────────────────────
              // When fully morphed into Multi Day mode AND the user is actively
              // sliding between days, render individual label columns with the
              // same half-speed / full-speed column formula as _DayTimelineMulti.
              // At slideX == 0 (rest state) use the normal static layout below.
              if (t >= 0.99 && widget.slideX != 0.0) {
                final bool goingLeft = widget.slideX <= 0;
                final double colW = contentW / 2;
                final double sw = widget.screenW > 0 ? widget.screenW : totalW;
                final double slideX = widget.slideX;

                final DateTime A = widget.date;
                final DateTime Aplus1 = A.add(const Duration(days: 1));
                final DateTime Aplus2 = A.add(const Duration(days: 2));
                final DateTime Aminus1 = A.subtract(const Duration(days: 1));

                // Content-area positions (add labelColW for screen x).
                final double posA = goingLeft
                    ? slideX * contentW / sw
                    : slideX * colW / sw;
                final double posAplus1 = goingLeft
                    ? colW + slideX * colW / sw
                    : colW + slideX * contentW / sw;
                final double posAminus1 = -contentW + slideX * contentW / sw;
                final double posAplus2 =
                    colW + contentW + slideX * contentW / sw;

                // Returns a Positioned label for [date] in a half-width slot
                // starting at [contentPos] from the content-area origin.
                // Returns null when the slot is entirely off-screen.
                Positioned? labelAt(DateTime date, double contentPos) {
                  final absLeft = labelColW + contentPos;
                  if (absLeft >= totalW || absLeft + colW <= 0) return null;
                  return Positioned(
                    left: absLeft,
                    width: colW,
                    top: 0,
                    bottom: 0,
                    child: ClipRect(
                      child: Center(
                        child: Text(
                          _shortLabel(date),
                          style: _styleFor(date, ctx),
                        ),
                      ),
                    ),
                  );
                }

                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: [
                    // Fixed vertical separators at their fully-open positions.
                    Positioned(
                      left:
                          labelColW +
                          _kMultiDayIndicatorDividerShift -
                          0.25,
                      top: 0,
                      bottom: 0,
                      width: 0.5,
                      child: ColoredBox(color: separatorColor),
                    ),
                    Positioned(
                      left: midX - 0.25,
                      top: 0,
                      bottom: 0,
                      width: 0.5,
                      child: ColoredBox(color: separatorColor),
                    ),
                    Positioned(
                      right: 0,
                      top: 0,
                      bottom: 0,
                      width: 0.5,
                      child: ColoredBox(color: separatorColor),
                    ),
                    // Sliding day labels.
                    if (!goingLeft && labelAt(Aminus1, posAminus1) != null)
                      labelAt(Aminus1, posAminus1)!,
                    if (labelAt(A, posA) != null) labelAt(A, posA)!,
                    if (labelAt(Aplus1, posAplus1) != null)
                      labelAt(Aplus1, posAplus1)!,
                    if (goingLeft && labelAt(Aplus2, posAplus2) != null)
                      labelAt(Aplus2, posAplus2)!,
                  ],
                );
              }

              return Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  // ── Morphing label — one shared element ─────────────────
                  // The Positioned box itself animates:
                  //   t=0 → spans full width  → text Centers in the full banner
                  //   t=1 → spans left half   → text Centers in the left half
                  // As the box narrows, its right edge tracks sep2X so the text
                  // is naturally clipped by the incoming centre separator.
                  //
                  // Inside, each text segment is individually animated:
                  //   • shortDay  — static ("Mon") — shared by both states
                  //   • tailDay   — clips out rightward as t→1 ("day")
                  //   • " – "     — clips out rightward as t→1
                  //   • ", "      — clips  in from left   as t→1
                  //   • monthDay  — static ("Jul 06") — shared by both states
                  //   • yearStr   — clips out rightward as t→1 (", 2026")
                  Positioned(
                    left: labelColW * t,
                    right: (totalW - midX) * t,
                    top: 0,
                    bottom: 0,
                    child: ClipRect(
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(shortDay, style: _styleFor(widget.date, ctx)),
                            // "day" / "sday" etc. clips out from the right.
                            // ClipRect is required: Align(widthFactor:0) collapses
                            // its layout width but the Text child still paints and
                            // bleeds into adjacent siblings without an explicit clip.
                            ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: (1.0 - t).clamp(0.0, 1.0),
                                child: Text(
                                  tailDay,
                                  style: _styleFor(widget.date, ctx),
                                  softWrap: false,
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                            ),
                            // " – " clips out from the right
                            ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: (1.0 - t).clamp(0.0, 1.0),
                                child: Text(
                                  ' \u2013 ',
                                  style: _styleFor(widget.date, ctx),
                                  softWrap: false,
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                            ),
                            // ", " clips in from the left
                            ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: t.clamp(0.0, 1.0),
                                child: Text(
                                  ', ',
                                  style: _styleFor(widget.date, ctx),
                                  softWrap: false,
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                            ),
                            Text(monthDay, style: _styleFor(widget.date, ctx)),
                            // ", 2026" clips out from the right
                            ClipRect(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                widthFactor: (1.0 - t).clamp(0.0, 1.0),
                                child: Text(
                                  yearStr,
                                  style: _styleFor(widget.date, ctx),
                                  softWrap: false,
                                  overflow: TextOverflow.clip,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // ── Second-day label: slides in from beyond right, no fade ─
                  Positioned(
                    left: midX,
                    right: 0,
                    top: 0,
                    bottom: 0,
                    child: ClipRect(
                      child: Transform.translate(
                        offset: Offset((totalW - midX) * (1.0 - t), 0),
                        child: Center(
                          child: Text(
                            _shortLabel(nextDate),
                            style: _styleFor(nextDate, ctx),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Left separator: slides in from beyond the left edge
                  Positioned(
                    left: sep1X,
                    top: 0,
                    bottom: 0,
                    width: 0.5,
                    child: ColoredBox(color: separatorColor),
                  ),
                  // Centre separator: slides in from beyond the right edge
                  if (sep2X < totalW)
                    Positioned(
                      left: sep2X,
                      top: 0,
                      bottom: 0,
                      width: 0.5,
                      child: ColoredBox(color: separatorColor),
                    ),
                  // Right-edge separator: mirrors the timeline's rightmost line
                  // so the Day Banner and timeline columns stay visually aligned.
                  Positioned(
                    right: 0,
                    top: 0,
                    bottom: 0,
                    width: 0.5,
                    child: Opacity(
                      opacity: t.clamp(0.0, 1.0),
                      child: ColoredBox(color: separatorColor),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DayTimeline — scrollable hour grid + current-time indicator
// ══════════════════════════════════════════════════════════════════════════════
// Multi-Day keeps the current-time dot on the label divider, but gives that
// divider the same small breathing offset that the Single-Day dot gets from
// its left margin after the label column.
const double _kMultiDayIndicatorDividerShift = 5.5;
// Horizontal hour hairlines begin at the left edge of the shifted divider,
// rather than underneath the label-column breathing offset.
const double _kMultiDayHourLineInset =
    _kMultiDayIndicatorDividerShift - 0.25;

class _DayTimeline extends StatefulWidget {
  const _DayTimeline({
    super.key,
    required this.selectedDate,
    required this.today,
    required this.nowNotifier,
    this.daySubMode = DayViewSubMode.singleDay,
  });

  final DateTime selectedDate;
  final DateTime today;
  // Notifier updated at every real-world minute boundary by CalendarTabState.
  final ValueNotifier<DateTime> nowNotifier;
  // When multiDay, the timeline shows selectedDate and selectedDate+1 side
  // by side with hairline vertical separators.
  final DayViewSubMode daySubMode;

  @override
  State<_DayTimeline> createState() => _DayTimelineState();
}

class _DayTimelineState extends State<_DayTimeline>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scroll;
  late final AnimationController _sepCtrl;
  late final Animation<double> _sepAnim;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final startHour = math.max(0, now.hour - 2).toDouble();
    _scroll = ScrollController(
      initialScrollOffset: _kTimelinePad + startHour * _kHourHeight,
    );
    _sepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: widget.daySubMode == DayViewSubMode.multiDay ? 1.0 : 0.0,
    );
    _sepAnim = CurvedAnimation(parent: _sepCtrl, curve: Curves.easeInOut);
    // When the reverse animation finishes (value reaches 0), trigger a rebuild
    // so the branch condition `_sepAnim.value > 0` immediately flips to false
    // and we return to the single-day layout path without waiting for an
    // unrelated rebuild (minute tick, parent, etc.).
    _sepCtrl.addStatusListener((status) {
      if ((status == AnimationStatus.dismissed ||
              status == AnimationStatus.completed) &&
          mounted) {
        setState(() {});
      }
    });
  }

  @override
  void didUpdateWidget(_DayTimeline old) {
    super.didUpdateWidget(old);
    if (widget.daySubMode != old.daySubMode) {
      widget.daySubMode == DayViewSubMode.multiDay
          ? _sepCtrl.forward()
          : _sepCtrl.reverse();
    }
  }

  @override
  void dispose() {
    _sepCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The time indicator is shown when today falls on either of the displayed
    // days (selectedDate in single-day mode; selectedDate or selectedDate+1
    // in multi-day mode).
    final isToday =
        _sameDay(widget.selectedDate, widget.today) ||
        (widget.daySubMode == DayViewSubMode.multiDay &&
            _sameDay(
              widget.selectedDate.add(const Duration(days: 1)),
              widget.today,
            ));

    final isMultiDay = widget.daySubMode == DayViewSubMode.multiDay;
    final separatorColor = resolveThemeColor(kSeparatorColor, context);

    return ColoredBox(
      color: resolveThemeColor(kBackgroundColor, context),
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          // Extra _kTimelinePad at both ends prevents the indicator and the
          // first/last hour labels from being hard-clipped by the Stack.
          // The extra +8 preserves the breathing room below the 12:00 am
          // end-of-day line (which itself sits +8 into its slot).
          // Keep the end-of-day hairline immediately above the shared
          // floating-pill clearance.  This makes the visible gap from the
          // midnight line to the pill match the category-card gap.
          height:
              _kTimelinePad +
              24 * _kHourHeight +
              8.5 +
              floatingTabBarContentBottomClearance(context),
          // ValueListenableBuilder rebuilds only this subtree at every minute
          // boundary driven by the parent's clock notifier — guaranteed real-time.
          child: ValueListenableBuilder<DateTime>(
            valueListenable: widget.nowNotifier,
            builder: (context, now, _) {
              // Snap to the current minute — the timer still fires every second
              // so today's highlight stays fresh, but the indicator position
              // only advances once per minute (no sub-minute drift).
              final curSecs = now.hour * 3600 + now.minute * 60;
              // All hour slots are shifted down by _kTimelinePad so there is
              // breathing room above 12:00 am and the indicator is never clipped.
              final indicatorTop =
                  _kTimelinePad + (curSecs / 3600.0) * _kHourHeight;

              // Always run the LayoutBuilder path so we can animate the
              // separators both when entering AND leaving Multi Day mode.
              if (isMultiDay || _sepAnim.value > 0) {
                return LayoutBuilder(
                  builder: (ctx, cons) {
                    final labelColW = _hourLabelColW(
                      MediaQuery.textScalerOf(ctx),
                    );
                    final totalW = cons.maxWidth;
                    final contentW = totalW - labelColW;
                    return AnimatedBuilder(
                      animation: _sepAnim,
                      builder: (_, __) {
                        final t = _sepAnim.value;
                        // Left separator slides in from BEYOND the LEFT edge.
                        // At t=0: -0.5 (hidden left). At t=1: the label
                        // divider plus the same visual offset used by the
                        // Multi-Day current-time indicator.
                        final sep1Target =
                            labelColW +
                            _kMultiDayIndicatorDividerShift -
                            0.25;
                        final sep1X = -0.5 + (sep1Target + 0.5) * t;
                        // Centre separator slides in from BEYOND the RIGHT edge.
                        // At t=0: totalW (hidden right). At t=1: midpoint.
                        final sep2X =
                            totalW +
                            (labelColW + contentW / 2 - 0.25 - totalW) * t;
                        return Stack(
                          clipBehavior: Clip.none,
                          children: [
                            // Hour slot lines + labels
                            for (int h = 0; h < 24; h++)
                              Positioned(
                                left: 0,
                                right: 0,
                                top: _kTimelinePad + h * _kHourHeight,
                                child: _HourSlot(
                                  hour: h,
                                  lineStartInset:
                                      _kMultiDayHourLineInset * t,
                                ),
                              ),

                            // End-of-day hairline — offset by 8 px to match the
                            // ~8 px internal offset of _HourSlot hairlines, so the
                            // time indicator aligns with this line exactly at midnight.
                            Positioned(
                              left: 0,
                              right: 0,
                              top: _kTimelinePad + 24 * _kHourHeight + 8,
                              child: Container(
                                height: 0.5,
                                color: separatorColor,
                              ),
                            ),

                            // Left separator — extends far beyond content bounds so
                            // rubber-band overscroll never reveals the line ends.
                            Positioned(
                              left: sep1X,
                              top: -9999,
                              bottom: -9999,
                              width: 0.5,
                              child: Container(color: separatorColor),
                            ),
                            // Centre separator
                            if (sep2X < totalW)
                              Positioned(
                                left: sep2X,
                                top: -9999,
                                bottom: -9999,
                                width: 0.5,
                                child: Container(color: separatorColor),
                              ),
                            // Right-edge separator
                            Positioned(
                              right: 0,
                              top: -9999,
                              bottom: -9999,
                              width: 0.5,
                              child: Opacity(
                                opacity: t.clamp(0.0, 1.0),
                                child: Container(color: separatorColor),
                              ),
                            ),

                          ],
                        );
                      },
                    );
                  },
                );
              }
              if (isMultiDay) {
                return LayoutBuilder(
                  builder: (ctx, cons) {
                    final labelColW = _hourLabelColW(
                      MediaQuery.textScalerOf(ctx),
                    );
                    final totalW = cons.maxWidth;
                    final contentW = totalW - labelColW;
                    return Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // Hour slot lines + labels
                        for (int h = 0; h < 24; h++)
                          Positioned(
                            left: 0,
                            right: 0,
                            top: _kTimelinePad + h * _kHourHeight,
                            child: _HourSlot(
                              hour: h,
                              lineStartInset: _kMultiDayHourLineInset,
                            ),
                          ),

                        // End-of-day hairline — same +8 offset as the animated
                        // path (line above) so the hairline sits at the same
                        // visual depth as every _HourSlot hairline (~7-8 px
                        // from the slot top) and the indicator crosses it
                        // exactly at midnight.
                        Positioned(
                          left: 0,
                          right: 0,
                          top: _kTimelinePad + 24 * _kHourHeight + 8,
                          child: Container(height: 0.5, color: separatorColor),
                        ),

                        // ── Multi Day vertical separators — extended far beyond
                        // content bounds so rubber-band overscroll never shows ends.
                        // Left separator: the hour-label divider with the same
                        // breathing offset used by the current-time indicator.
                        Positioned(
                          left:
                              labelColW +
                              _kMultiDayIndicatorDividerShift -
                              0.25,
                          top: -9999,
                          bottom: -9999,
                          width: 0.5,
                          child: Container(color: separatorColor),
                        ),
                        // Centre separator: divides the content area in half.
                        Positioned(
                          left: labelColW + contentW / 2 - 0.25,
                          top: -9999,
                          bottom: -9999,
                          width: 0.5,
                          child: Container(color: separatorColor),
                        ),
                        // Right-edge separator.
                        Positioned(
                          right: 0,
                          top: -9999,
                          bottom: -9999,
                          width: 0.5,
                          child: Container(color: separatorColor),
                        ),

                      ],
                    );
                  },
                );
              }

              // ── Single-day layout (unchanged) ──────────────────────────────
              return Stack(
                children: [
                  // Hour slot lines + labels — shifted down by the top pad.
                  for (int h = 0; h < 24; h++)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: _kTimelinePad + h * _kHourHeight,
                      child: _HourSlot(hour: h),
                    ),

                  // End-of-day hairline — +8 px so it sits at the same visual
                  // depth as every _HourSlot hairline (~7-8 px from slot top).
                  // The indicator's visual line is also ~8 px below indicatorTop,
                  // so it reaches this line exactly at midnight.
                  Positioned(
                    left: 0,
                    right: 0,
                    top: _kTimelinePad + 24 * _kHourHeight + 8,
                    child: ColoredBox(
                      color: resolveThemeColor(kSeparatorColor, context),
                      child: const SizedBox(height: 0.5),
                    ),
                  ),

                  // Current-time indicator — shown only on today, positioned
                  // exactly at the fractional-second offset within the hour grid.
                  if (isToday)
                    Positioned(
                      left: 0,
                      right: 0,
                      top: indicatorTop,
                      child: _CurrentTimeIndicator(
                        hour: now.hour,
                        minute: now.minute,
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
}

// Hour-label column width: 16 px left margin + widest label text + 8 px gap.
// Measured fresh each call — no cache — so fonts are guaranteed to be loaded.
final _kHourLabelStyle = TextStyle(
  fontFamily: kSFProText,
  fontSize: 11,
  color: kSecondaryLabel,
);
final _kHourMeasureStyle = TextStyle(fontFamily: kSFProText, fontSize: 11);

// Measures the hour-label column width at the device's current text scale so
// the column never mismatches the rendered label width.
double _hourLabelColW(TextScaler scaler) {
  final tp = TextPainter(
    text: TextSpan(text: '10:00 pm', style: _kHourMeasureStyle),
    textDirection: TextDirection.ltr,
    textScaler: scaler,
  )..layout();
  return 16.0 + tp.width + 8.0;
}

class _HourSlot extends StatelessWidget {
  const _HourSlot({
    required this.hour,
    this.lineStartInset = 0.0,
  });
  final int hour;
  final double lineStartInset;

  String get _label {
    if (hour == 0) return '12:00 am';
    if (hour < 12) return '$hour:00 am';
    if (hour == 12) return '12:00 pm';
    return '${hour - 12}:00 pm';
  }

  @override
  Widget build(BuildContext context) {
    final double colW = _hourLabelColW(MediaQuery.textScalerOf(context));
    final hourLabelStyle = _kHourLabelStyle.copyWith(
      color: resolveThemeColor(kSecondaryLabel, context),
    );
    final separatorColor = resolveThemeColor(kSeparatorColor, context);
    // The label and hairline are placed in a Row with CrossAxisAlignment.center
    // so their midpoints align exactly.  The Row is pinned near the top of the
    // slot (top: 8 − half-of-row-height ≈ a few px) via an Align so the visual
    // position of the hairline stays close to where it was before (≈ 8 px from
    // the slot top).  Because Row height = max(label height, 0.5) ≈ label
    // height (~13 px at 11 sp), the whole row is ≈ 13 px tall, pinned at top ≈
    // 1–2 px, giving a hairline centre at ~7–8 px — identical to the old layout.
    return SizedBox(
      height: _kHourHeight,
      child: Align(
        alignment: Alignment.topLeft,
        child: Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Time label — right-aligned inside the measured label column.
              SizedBox(
                width: colW,
                child: Padding(
                  padding: const EdgeInsets.only(left: 16, right: 8),
                  child: Text(
                    _label,
                    textAlign: TextAlign.right,
                    style: hourLabelStyle,
                  ),
                ),
              ),
              SizedBox(width: lineStartInset),
              // Hairline separator — its vertical centre aligns with the label centre.
              Expanded(child: Container(height: 0.5, color: separatorColor)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurrentTimeIndicator extends StatelessWidget {
  const _CurrentTimeIndicator({
    required this.hour,
    required this.minute,
    this.multiDay = false,
    this.multiDayMarkerShiftX = 0.0,
    this.multiDayWholeShiftX = 0.0,
  });
  final int hour, minute;
  final bool multiDay;
  final double multiDayMarkerShiftX;
  // Used when the left-hand day is today and exits the viewport. In that
  // case the pill must travel with the dot and line instead of remaining
  // anchored in the hour-label column.
  final double multiDayWholeShiftX;

  String get _label {
    final suffix = hour < 12 ? 'am' : 'pm';
    final displayH = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    final mm = minute.toString().padLeft(2, '0');
    return '$displayH:$mm $suffix';
  }

  @override
  Widget build(BuildContext context) {
    final labelColW = _hourLabelColW(MediaQuery.textScalerOf(context));
    final pill = SizedBox(
      width: labelColW,
      child: Align(
        alignment: Alignment.centerRight,
        child: Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: ShapeDecoration(
            color: resolveAccentColor(context),
            shape: const BoundedSquircleStadiumBorder(radius: 10),
          ),
          child: Text(
            _label,
            style: TextStyle(
              fontFamily: kSFProText,
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
        ),
      ),
    );

    if (multiDay) {
      final marker = Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // The left divider is intentionally offset by 5.5 px, so the
          // default marker center is labelColW + 5.5.  The caller supplies
          // the additional live swipe translation.
          const SizedBox(width: _kMultiDayIndicatorDividerShift - 3.5),
          const SizedBox(
            width: 7,
            height: 7,
            child: _CurrentTimeDot(),
          ),
          // Keep this full-width. The marker's translation and the viewport
          // clipping make the right-side state end at the screen edge.
          Expanded(
            child: Container(
              height: 1.5,
              color: resolveAccentColor(context),
            ),
          ),
        ],
      );

      return ClipRect(
        child: Transform.translate(
          offset: Offset(multiDayWholeShiftX, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              pill,
              // Normally the pill remains anchored in the left label column
              // and only the marker moves. During a left-side exit,
              // multiDayWholeShiftX carries both as one element.
              Expanded(
                child: ClipRect(
                  child: Transform.translate(
                    offset: Offset(
                      multiDayWholeShiftX == 0.0
                          ? multiDayMarkerShiftX
                          : 0.0,
                      0,
                    ),
                    child: marker,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Time pill — fits inside the same measured label column as the hour
        // text, right-aligned so it sits flush with the hairline separator.
        pill,
        Container(
          width: 7,
          height: 7,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: resolveAccentColor(context),
            shape: BoxShape.circle,
          ),
        ),
        // Line to right edge
        Expanded(
          child: Container(height: 1.5, color: resolveAccentColor(context)),
        ),
      ],
    );
  }
}

class _CurrentTimeDot extends StatelessWidget {
  const _CurrentTimeDot();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: resolveAccentColor(context),
        shape: BoxShape.circle,
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _DayTimelineMulti
//
// Multi Day timeline with column-level sliding.
//
// Instead of the parent sliding full 2-day panels as one block, this widget
// renders each day column individually with different speeds:
//
//   • Exiting day  (A going left / A+1 going right) → full speed out
//   • Shared day   (A+1 going left / A going right) → half speed, slot shift
//   • Entering day (A+2 going left / A−1 going right) → full speed in
//
// The shared day travels from one column slot to the adjacent one — the same
// distance as a column width — which is exactly half the total content width,
// giving it half the apparent speed relative to the screen.
//
// Position formulas (content-area coordinates; add labelColW for screen x):
//
//   Going left (slideX ≤ 0):
//     posA       = slideX * contentW / sw          (full speed exit left)
//     posAplus1  = colW + slideX * colW / sw        (half speed, right→left)
//     posAplus2  = colW + contentW + slideX * contentW / sw  (full speed entry)
//
//   Going right (slideX > 0):
//     posAminus1 = −contentW + slideX * contentW / sw       (full speed entry)
//     posA       = slideX * colW / sw              (half speed, left→right)
//     posAplus1  = colW + slideX * contentW / sw   (full speed exit right)
//
// All formulas are continuous at slideX = 0.
// ══════════════════════════════════════════════════════════════════════════════
class _DayTimelineMulti extends StatefulWidget {
  const _DayTimelineMulti({
    super.key,
    required this.selectedDate,
    required this.today,
    required this.nowNotifier,
    required this.slideX,
    required this.screenW,
  });

  final DateTime selectedDate;
  final DateTime today;
  final ValueNotifier<DateTime> nowNotifier;

  /// Live swipe offset from the parent, range [−screenW, +screenW].
  final double slideX;

  /// Total screen width — used to scale column positions correctly.
  final double screenW;

  @override
  State<_DayTimelineMulti> createState() => _DayTimelineMultiState();
}

class _DayTimelineMultiState extends State<_DayTimelineMulti>
    with SingleTickerProviderStateMixin {
  late final ScrollController _scroll;
  late final AnimationController _sepCtrl;
  late final CurvedAnimation _sepAnim;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final startHour = math.max(0, now.hour - 2).toDouble();
    _scroll = ScrollController(
      initialScrollOffset: _kTimelinePad + startHour * _kHourHeight,
    );
    // Separator entrance animation — plays once when Multi Day mode is first
    // entered.  Because the parent uses const Key('multi-timeline'), this
    // state persists across date navigation so the animation does NOT replay
    // every time the user swipes to a new day pair.
    _sepCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      value: 0.0,
    )..forward();
    _sepAnim = CurvedAnimation(parent: _sepCtrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _sepCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime A = widget.selectedDate;
    final DateTime Aplus1 = A.add(const Duration(days: 1));
    final DateTime Aplus2 = A.add(const Duration(days: 2));
    final DateTime Aminus1 = A.subtract(const Duration(days: 1));

    final backgroundColor = resolveThemeColor(kBackgroundColor, context);
    final separatorColor = resolveThemeColor(kSeparatorColor, context);

    return ColoredBox(
      color: backgroundColor,
      child: SingleChildScrollView(
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        child: SizedBox(
          // Keep the end-of-day hairline immediately above the shared
          // floating-pill clearance.  This makes the visible gap from the
          // midnight line to the pill match the category-card gap.
          height:
              _kTimelinePad +
              24 * _kHourHeight +
              8.5 +
              floatingTabBarContentBottomClearance(context),
          child: ValueListenableBuilder<DateTime>(
            valueListenable: widget.nowNotifier,
            builder: (context, now, _) {
              final curSecs = now.hour * 3600 + now.minute * 60;
              final indicatorTop =
                  _kTimelinePad + (curSecs / 3600.0) * _kHourHeight;

              return LayoutBuilder(
                builder: (ctx, cons) {
                  final totalW = cons.maxWidth;
                  final labelColW = _hourLabelColW(
                    MediaQuery.textScalerOf(ctx),
                  );
                  final contentW = totalW - labelColW;
                  final colW = contentW / 2;
                  final sw = widget.screenW > 0 ? widget.screenW : totalW;
                  final slideX = widget.slideX;
                  final bool goingLeft = slideX <= 0;

                  // ── Column position formula ─────────────────────────────
                  // Positions are left-edge offsets within the content area
                  // (add labelColW to get absolute screen x).
                  final double posA = goingLeft
                      ? slideX * contentW / sw
                      : slideX * colW / sw;
                  final double posAplus1 = goingLeft
                      ? colW + slideX * colW / sw
                      : colW + slideX * contentW / sw;
                  final double posAminus1 = -contentW + slideX * contentW / sw;
                  final double posAplus2 =
                      colW + contentW + slideX * contentW / sw;

                   // The pill/marker exists only while today's actual column
                   // intersects the visible content area. Checking the
                   // candidate dates alone is not enough during a swipe:
                   // Aplus2/Aminus1 is mounted just outside the viewport before
                   // it enters, and would otherwise leave a time pill behind
                   // even though today is not on screen.
                   bool isVisibleColumn(DateTime date, double contentPos) {
                     if (!_sameDay(date, widget.today)) return false;
                     final left = labelColW + contentPos;
                     final right = left + colW;
                     return right > labelColW && left < totalW;
                   }

                   // Keep the whole indicator mounted for the complete
                   // Single-Day-style panel travel.  The day column itself
                   // becomes "invisible" as soon as it reaches the label
                   // divider, but the pill/circle/line must remain alive
                   // while its full-width transform carries it to the
                   // viewport edge.
                   final bool wholeIndicatorActive =
                       (goingLeft && _sameDay(A, widget.today)) ||
                       (!goingLeft && _sameDay(Aminus1, widget.today));
                   final bool showIndicator =
                       wholeIndicatorActive ||
                       isVisibleColumn(A, posA) ||
                       isVisibleColumn(Aplus1, posAplus1) ||
                       (!goingLeft && isVisibleColumn(Aminus1, posAminus1)) ||
                       (goingLeft && isVisibleColumn(Aplus2, posAplus2));

                   // Indicator slide rules:
                   //   • The indicator belongs to today's day column, so its
                   //     dot/line anchor follows that column's left edge.
                   //   • A shared day moves at half speed with its column.
                   //   • An entering or exiting day uses the same full-speed
                   //     column position, which carries the whole indicator
                   //     cleanly off-screen.
                  //
                  // goingLeft (slideX ≤ 0): final pair = [A+1, A+2]
                  //   A exits left, A+1 stays, A+2 enters right.
                  // goingRight (slideX > 0):  final pair = [A-1, A]
                  //   A+1 exits right, A stays, A-1 enters left.
                    double markerShiftX = 0.0;
                    double wholeIndicatorShiftX = 0.0;
                  if (showIndicator) {
                     if (goingLeft) {
                       if (_sameDay(A, widget.today)) {
                          // Match the Single-Day panel transform exactly:
                          // the current panel leaves from its resting x=0
                          // origin at the full screen-width slide offset.
                          wholeIndicatorShiftX = slideX;
                       } else if (_sameDay(Aplus1, widget.today)) {
                         // Shared right-side today moves toward the left
                         // divider. Interpolate between the shifted left
                         // divider and the exact center divider.
                         markerShiftX =
                             (posAplus1 / colW) *
                             (colW - _kMultiDayIndicatorDividerShift);
                       } else if (_sameDay(Aplus2, widget.today)) {
                         // Entering right-side today must arrive centered on
                         // the center divider, not 5.5 px beyond it.
                         markerShiftX =
                             posAplus2 - _kMultiDayIndicatorDividerShift;
                       }
                     } else {
                       if (_sameDay(Aminus1, widget.today)) {
                          // Match the Single-Day previous-panel transform
                          // exactly.  The indicator starts one full screen
                          // width off the left edge and arrives at x=0
                          // together with that panel.
                          wholeIndicatorShiftX = slideX - sw;
                       } else if (_sameDay(A, widget.today)) {
                         // Shared today moves from the left divider to the
                         // exact center divider.
                         markerShiftX =
                             (posA / colW) *
                             (colW - _kMultiDayIndicatorDividerShift);
                       } else if (_sameDay(Aplus1, widget.today)) {
                         // Right-side today exits from the exact center line.
                         markerShiftX =
                             posAplus1 - _kMultiDayIndicatorDividerShift;
                       }
                     }
                  }

                  // Returns a Positioned for a sliding day column.
                  // Columns carry no visible content of their own — all
                  // drawing (hour lines, indicator, separators) lives in the
                  // layers above/below this function's output.
                  Widget contentColumn(DateTime date, double contentPos) {
                    final absLeft = labelColW + contentPos;
                    if (absLeft >= totalW || absLeft + colW <= 0) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      left: absLeft,
                      width: colW,
                      top: 0,
                      bottom: 0,
                      child: const ClipRect(child: SizedBox.expand()),
                    );
                  }

                  return AnimatedBuilder(
                    animation: _sepAnim,
                    builder: (_, __) {
                      final t = _sepAnim.value;
                      // Left separator slides in from beyond the left edge.
                      // At t=0: -0.5 (hidden). At t=1: the shifted label
                      // divider used by the current-time indicator.
                      final sep1Target =
                          labelColW +
                          _kMultiDayIndicatorDividerShift -
                          0.25;
                      final sep1X = -0.5 + (sep1Target + 0.5) * t;
                      // Centre separator slides in from beyond the right edge.
                      // At t=0: totalW (hidden). At t=1: midpoint.
                      final sep2X =
                          totalW + (labelColW + colW - 0.25 - totalW) * t;

                      return Stack(
                        // The vertical separators intentionally extend beyond
                        // the scroll content.  Without Clip.none, Flutter
                        // trims them back to the Stack's own height and a
                        // rubber-band overscroll exposes their top/bottom
                        // endpoints.
                        clipBehavior: Clip.none,
                        children: [
                          // ── Base layer: hour labels + full-width hairlines ──
                          for (int h = 0; h < 24; h++)
                            Positioned(
                              left: 0,
                              right: 0,
                              top: _kTimelinePad + h * _kHourHeight,
                              child: _HourSlot(
                                hour: h,
                                lineStartInset: _kMultiDayHourLineInset,
                              ),
                            ),
                          // End-of-day hairline — +8 px so it sits at the same
                          // visual depth as every _HourSlot hairline (~7-8 px
                          // from slot top) and the indicator crosses it at midnight.
                          Positioned(
                            left: 0,
                            right: 0,
                            top: _kTimelinePad + 24 * _kHourHeight + 8,
                            child: Container(
                              height: 0.5,
                              color: separatorColor,
                            ),
                          ),

                          // ── Sliding day content columns ─────────────────
                          if (!goingLeft) contentColumn(Aminus1, posAminus1),
                          contentColumn(A, posA),
                          contentColumn(Aplus1, posAplus1),
                          if (goingLeft) contentColumn(Aplus2, posAplus2),

                          // ── Animated vertical separators ───────────────
                          // Left sep slides from beyond-left → label-col edge.
                          Positioned(
                            left: sep1X,
                            top: -9999,
                            bottom: -9999,
                            width: 0.5,
                            child: ColoredBox(color: separatorColor),
                          ),
                          // Centre sep slides from beyond-right → midpoint.
                          if (sep2X < totalW)
                            Positioned(
                              left: sep2X,
                              top: -9999,
                              bottom: -9999,
                              width: 0.5,
                              child: ColoredBox(color: separatorColor),
                            ),
                          // Right-edge sep fades in with the transition.
                          Positioned(
                            right: 0,
                            top: -9999,
                            bottom: -9999,
                            width: 0.5,
                            child: Opacity(
                              opacity: t.clamp(0.0, 1.0),
                              child: ColoredBox(color: separatorColor),
                            ),
                          ),

                            // Current-time marker belongs to the active day
                            // column. The pill normally remains in the left
                            // label column; the exception is a left-side
                            // today entering from off-screen, where the
                            // entire indicator returns as one element. Paint
                            // it after the separators so the dot sits visibly
                            // on top of the vertical divider.
                           if (showIndicator)
                             Positioned(
                               left: 0,
                               right: 0,
                               top: indicatorTop,
                               child: _CurrentTimeIndicator(
                                 hour: now.hour,
                                 minute: now.minute,
                                 multiDay: true,
                                 multiDayMarkerShiftX: markerShiftX,
                                  multiDayWholeShiftX: wholeIndicatorShiftX,
                               ),
                             ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// _CalModalCircleButton
// Circle icon button used in the New Event sheet header.
// Mirrors _ModalCircleButton from events_tab.dart.
// ══════════════════════════════════════════════════════════════════════════════
class _CalModalCircleButton extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color containerColor;
  final VoidCallback onTap;
  final Duration tapDelay;
  final Offset iconOffset;

  const _CalModalCircleButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.containerColor = kModalCard,
    this.tapDelay = Duration.zero,
    this.iconOffset = Offset.zero,
  });

  @override
  Widget build(BuildContext context) {
    final fontFamily = icon.fontPackage != null
        ? 'packages/${icon.fontPackage}/${icon.fontFamily}'
        : (icon.fontFamily ?? '');

    final resolvedContainerColor = resolveThemeColor(containerColor, context);
    final resolvedIconColor = resolveThemeColor(iconColor, context);

    return GelBloomButton(
      peakScale: 1.15,
      tapDelay: tapDelay,
      onTap: onTap,
      child: LiquidGlassGelCircle(
        color: resolvedContainerColor,
        isCheckmark: icon == CupertinoIcons.checkmark,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: Center(
              child: Transform.translate(
                offset: iconOffset,
                child: RichText(
                  textHeightBehavior: const TextHeightBehavior(
                    applyHeightToFirstAscent: false,
                    applyHeightToLastDescent: false,
                  ),
                  text: TextSpan(
                    text: String.fromCharCode(icon.codePoint),
                    style: TextStyle(
                      inherit: false,
                      color: resolvedIconColor,
                      fontSize: 20,
                      fontFamily: fontFamily,
                      fontStyle: FontStyle.normal,
                      shadows: resolveThemeTextShadows([
                        Shadow(
                          color: resolvedIconColor,
                          blurRadius: kGelBloomIconWeight,
                        ),
                      ], context),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// Lightweight category model used only inside _NewEventSheetState.
// Parsed from the same SharedPreferences JSON that EventsTabState writes.
// ══════════════════════════════════════════════════════════════════════════════
class _NewEventCategory {
  final String id;
  final String name;
  final Color color;
  // Preset values read from the saved category and applied to the sheet.
  final String? presetLocation;
  final String? presetDestination;
  final String? presetTravelTime;
  final String? presetTravelMode;
  final String? presetRepeat;
  final String? presetRepeatEndType;
  final String? presetRepeatEndDate;
  final Map<String, dynamic>? presetCustomRepeatConfig;
  final String? presetAlert;
  final String? presetSecondAlert;
  final List<String>? presetAlerts;

  const _NewEventCategory({
    required this.id,
    required this.name,
    required this.color,
    this.presetLocation,
    this.presetDestination,
    this.presetTravelTime,
    this.presetTravelMode,
    this.presetRepeat,
    this.presetRepeatEndType,
    this.presetRepeatEndDate,
    this.presetCustomRepeatConfig,
    this.presetAlert,
    this.presetSecondAlert,
    this.presetAlerts,
  });
}

// These are navigation-only utility rows in the Events tab, not storage
// categories. They can exist in persisted category data because the Events
// tab owns their lifecycle, but they must never be selectable for an event.
const _kEventPickerUtilityCategoryIds = {
  'sys-archived-categories',
  'sys-recently-deleted',
};
const _kEventPickerUtilityCategoryNames = {
  'Archived Items',
  'Recently Deleted',
};

// ══════════════════════════════════════════════════════════════════════════════
// _NewEventSheet
// Modal sheet opened by the + button in the Calendar tab header.
// ══════════════════════════════════════════════════════════════════════════════
// ── Attachment data ───────────────────────────────────────────────────────────

class _AttachmentFile {
  final String name;
  final String ext;
  final Uint8List? bytes;
  final bool isImage;
  // Non-null when this attachment already has a persisted path on disk
  // (i.e. loaded from an existing event during editing). The save handler
  // reuses this path instead of writing a new copy.
  final String? path;
  // Fallback source path supplied by file_picker when it cannot provide bytes.
  // This is copied into the app-owned attachment directory during save.
  final String? sourcePath;

  const _AttachmentFile({
    required this.name,
    required this.ext,
    this.bytes,
    this.isImage = false,
    this.path,
    this.sourcePath,
  });
}

/// Gives every filename its own horizontal rubberbandable viewport. The
/// shared edge fade remains overflow-driven, so a name that is fully visible
/// does not show a fade at either end.
class _AttachmentFilename extends StatelessWidget {
  final String name;
  final TextStyle style;
  final Color fadeColor;
  final ScrollController scrollController;

  const _AttachmentFilename({
    super.key,
    required this.name,
    required this.style,
    required this.fadeColor,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return HorizontalEdgeFade(
          fadeColor: fadeColor,
          fadeOnRubberbandWhenContentFits: true,
          scrollController: scrollController,
          child: SingleChildScrollView(
            controller: scrollController,
            primary: false,
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            child: ConstrainedBox(
              // A short filename must occupy the full filename lane just
              // like an overflowing one; otherwise its rubberband range and
              // clipping boundary stop at the text's intrinsic width.
              constraints: BoxConstraints(minWidth: constraints.maxWidth),
              child: Text(
                name,
                style: style,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.visible,
              ),
            ),
        ),
        );
      },
    );
  }
}

// ── Import progress ring painter ─────────────────────────────────────────────

class _ImportProgressPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color fillColor;

  const _ImportProgressPainter({
    required this.progress,
    required this.trackColor,
    required this.fillColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.shortestSide - 8.0) / 2;
    // Background ring — always present at low opacity.
    final trackPaint = Paint()
      ..color = trackColor.withOpacity(0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, trackPaint);
    // Filled arc — category color, sweeps clockwise from 12 o'clock.
    if (progress > 0.001) {
      final fillPaint = Paint()
        ..color = fillColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * progress.clamp(0.0, 1.0),
        false,
        fillPaint,
      );
    }
  }

  @override
  bool shouldRepaint(_ImportProgressPainter old) =>
      old.progress != progress ||
      old.trackColor != trackColor ||
      old.fillColor != fillColor;
}

class _NewEventSheet extends StatefulWidget {
  /// When non-null the sheet opens in edit mode: all fields are pre-populated
  /// from the existing event and saving calls [EventStore.update] instead of
  /// [EventStore.create], preserving the original event id.
  final ScheduledEvent? initial;
  final String? initialCategoryId;
  final Map<String, List<String>>? Function()? dcvSectionNamesProvider;
  final Map<String, List<List<String>>>? Function()?
      dcvSectionEventIdsProvider;
  final void Function(String label, List<List<String>> sectionEventIds)?
      onDcvSectionEventIdsChanged;

  const _NewEventSheet({
    this.initial,
    this.initialCategoryId,
    this.dcvSectionNamesProvider,
    this.dcvSectionEventIdsProvider,
    this.onDcvSectionEventIdsChanged,
  });

  bool get isEditing => initial != null;

  @override
  State<_NewEventSheet> createState() => _NewEventSheetState();
}

class _NewEventSheetState extends State<_NewEventSheet>
    with TickerProviderStateMixin {
  static const double _kHeaderBtnSize = kModalSheetButtonDiameter;
  static const double _kHeaderEdge = kModalSheetButtonEdgeGap;

  final _titleCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _titleScrollCtrl = ScrollController();
  final _subtitleScrollCtrl = ScrollController();
  final _titleFocus = FocusNode();
  final _subtitleFocus = FocusNode();

  // ── URL / Notes ───────────────────────────────────────────────────────────
  final _urlCtrl = TextEditingController();
  final _urlScrollCtrl = ScrollController();
  final _urlFocus = FocusNode();
  final _notesCtrl = TextEditingController();
  final _notesScrollCtrl = ScrollController();
  final _notesFocus = FocusNode();

  // ── Expandable multiline fields ───────────────────────────────────────────
  bool _subtitleExpanded = false;
  bool _notesExpanded = false;

  // ── Attachments ───────────────────────────────────────────────────────────
  final List<_AttachmentFile> _attachments = [];
  // Keep filename viewport state outside AnimatedList rows. AnimatedList may
  // rebuild neighboring rows while a removal is animating; controllers keyed
  // by the attachment object keep those rows at their existing offsets.
  final Map<_AttachmentFile, ScrollController> _attachmentScrollControllers =
      <_AttachmentFile, ScrollController>{};
  final GlobalKey<AnimatedListState> _attachmentListKey =
      GlobalKey<AnimatedListState>();
  // Pre-existing attachment paths loaded from the event being edited.
  // Preserved unchanged on save unless the user explicitly removes them.
  List<String>? _existingAttachmentPaths;

  // Import-progress overlay state
  bool _importingActive = false;
  int _importTotal = 0;
  int _importRemaining = 0;
  bool _importCancelled = false;
  late final AnimationController _importProgressCtrl;
  OverlayEntry? _importOverlayEntry;

  // External drag-and-drop state.  The native drop region is attached only to
  // the "Add attachment…" row so the rest of the sheet keeps its normal
  // gesture behavior.
  late final AnimationController _attachmentDropCtrl;
  late final AnimationController _attachmentConsumeCtrl;
  bool _attachmentDropHovered = false;
  bool _readingAttachmentDrop = false;

  bool _allDay = false;
  bool _unscheduled = false;
  late DateTime _starts;
  late DateTime _ends;

  // ── Inline date-picker state ──────────────────────────────────────────────
  // _activePicker: '' | 'starts' | 'ends'
  String _activePicker = '';
  late DateTime _pickerCalMonth; // month shown in the 3-panel grid
  bool _pickerBarrelMode = false; // month grid ↔ barrel toggle
  double _pickerDragOffset = 0.0; // live 1:1 drag / animation offset
  double _pickerPanelWidth = 0.0; // cached from LayoutBuilder
  Tween<double>? _pickerSlideTween; // non-null while a commit/snap runs
  late final AnimationController
  _startsPickerCtrl; // drives Starts SizeTransition
  late final AnimationController _endsPickerCtrl; // drives Ends SizeTransition
  late final AnimationController _pickerSlideCtrl; // drives month swipe

  // ── Duration tracking ─────────────────────────────────────────────────────
  // Default 1-hour interval between Starts and Ends.  Future: user-selectable.
  int _durationMinutes = 60;

  // ── Scheduled-rows collapse (All-day / Starts / Ends collapse when Unscheduled)
  late final AnimationController _schedRowsCtrl;

  // ── Location ──────────────────────────────────────────────────────────────
  final _locationTextCtrl = TextEditingController();
  final _locationScrollCtrl = ScrollController();
  final _locationFocus = FocusNode();
  final _destCtrl = TextEditingController();
  final _destScrollCtrl = ScrollController();
  final _destFocus = FocusNode();

  // ── Travel ────────────────────────────────────────────────────────────────
  String _travelTime = 'None';
  String _travelMode = 'None';

  // ── Repeat ────────────────────────────────────────────────────────────────
  String _repeat = 'Never';
  _NewEventCustomRepeatConfig? _savedCustomConfig;

  // ── Alerts ────────────────────────────────────────────────────────────────
  List<String> _alerts = ['At time of event'];

  String get _alert => _alerts.isEmpty ? 'None' : _alerts.first;

  set _alert(String value) => _setAlertAt(0, value);

  String get _secondAlert => _alerts.length > 1 ? _alerts[1] : 'None';

  set _secondAlert(String value) => _setAlertAt(1, value);

  // ── Unscheduled Reminder ──────────────────────────────────────────────────
  String _reminder = 'Never'; // 'Never' | 'On Date'
  String _repeatReminder =
      'Never'; // built-in label or generated custom recurrence wording
  _NewEventCustomRepeatConfig? _savedReminderCustomConfig;
  late DateTime _reminderDate; // date+time of the reminder notification

  // Minutes-before-event for each alert label.  -1 = 'None' (no alert).
  // All-day entries use ordering-only values (higher = fires earlier):
  //   On day of event (9 AM) = 31, Night before (9 PM) = 180,
  //   1 day before (9 AM) = 900, 2 days before (9 AM) = 2340.
  static const _kAlertMinutes = <String, int>{
    'None': -1,
    'At time of event': 0,
    '5 minutes before': 5,
    '10 minutes before': 10,
    '15 minutes before': 15,
    '30 minutes before': 30,
    '1 hour before': 60,
    '1 hour, 30 minutes before': 90,
    '2 hours before': 120,
    '1 day before': 1440,
    '2 days before': 2880,
    '1 week before': 10080,
    // ── All-day alert options ──────────────────────────────────────────────
    'On day of event (9 AM)': 31,
    'Night before (9 PM)': 180,
    '1 day before (9 AM)': 900,
    '2 days before (9 AM)': 2340,
  };
  static const _kAlertAllBase = [
    'None',
    'At time of event',
    '5 minutes before',
    '10 minutes before',
    '15 minutes before',
    '30 minutes before',
    '1 hour before',
    '1 hour, 30 minutes before',
    '2 hours before',
    '1 day before',
    '2 days before',
    '1 week before',
  ];
  // Options shown in Alert / Second Alert when All-day is on.
  // Display order: None → gap → closest-to-event first, then outward.
  static const _kAlertAllDayBase = [
    'None',
    'Night before (9 PM)',
    'On day of event (9 AM)',
    '1 day before (9 AM)',
    '2 days before (9 AM)',
    '1 week before',
  ];

  List<String> _normaliseAlertState(Iterable<String?> values) =>
      AlertSequence.compact(values);

  void _setAlertAt(int index, String value) {
    if (value == 'None') {
      if (_alerts.length > index) {
        _alerts.removeRange(index, _alerts.length);
      }
      return;
    }
    while (_alerts.length <= index) {
      _alerts.add(value);
    }
    _alerts[index] = value;
  }

  String _alertRowLabel(int index) {
    const names = [
      'First',
      'Second',
      'Third',
      'Fourth',
      'Fifth',
      'Sixth',
      'Seventh',
      'Eighth',
      'Ninth',
      'Tenth',
      'Eleventh',
      'Twelfth',
    ];
    final name = index < names.length ? names[index] : '${index + 1}th';
    return '$name Alert';
  }

  // ── Category ──────────────────────────────────────────────────────────────
  String _categoryId = 'uncategorized';
  String _categoryName = 'Uncategorized';
  Color _categoryColor = kAccentColor;
  List<_NewEventCategory> _standardCategories = [];
  // Color of the Uncategorized category, loaded from prefs.
  Color _uncategorizedColor = kAccentColor;
  bool _hasUncategorized = true;

  // Custom DCV sections are owned by EventsTabState, but the event sheet
  // reads the same persisted maps so a new or edited event can be placed in
  // the section the user selected here.
  static const _kPrefsDcvCustomSections = 'events_dcv_custom_sections';
  static const _kPrefsDcvCustomSectionEventIds =
      'events_dcv_custom_section_event_ids';
  Map<String, List<String>> _dcvCustomSectionNames = {};
  Map<String, List<List<String>>> _dcvCustomSectionEventIds = {};
  String? _initialCategoryName;
  int _selectedSectionIndex = 0;
  String? _initialDraftSignature;
  bool _discarding = false;
  // Keep the outgoing row's content mounted while its SizeTransition
  // collapses. Without this, changing to a category with no sections replaces
  // the row with a zero-height child before the dismissal animation can run.
  List<String> _renderedSectionNames = const <String>[];

  // Resolved accent-aware category color for widget rendering.
  // Use everywhere a widget consumes _categoryColor so kCatBlue sentinel
  // is correctly mapped to the live accent regardless of stored value.
  Color get _resolvedCategoryColor =>
      renderCategoryColor(_categoryColor, context);

  // ── End Repeat / End Date (cascading subcard) ─────────────────────────────
  String _endRepeat = 'Never';
  late DateTime _endDate;
  late DateTime _calendarMonth;
  bool _calendarBarrelMode = false;
  double _calendarDragOffset = 0.0;
  double _calPanelWidth = 0.0;
  Tween<double>? _monthSlideTween;

  // ── Extra animation controllers ───────────────────────────────────────────
  late final AnimationController
  _travelRowCtrl; // collapses Travel Time when All-day on
  late final AnimationController _travelModeCtrl;
  late final AnimationController
  _repeatCardCtrl; // collapses Repeat card when Unscheduled on
  late final AnimationController _endRepeatCtrl;
  late final AnimationController _endDateCtrl;
  late final AnimationController _datePickerCtrl;
  late final AnimationController _secondAlertCtrl;
  // Reminder-section controllers (Unscheduled events only).
  late final AnimationController
  _alertCardCtrl; // collapses Alert card when Unscheduled ON
  late final AnimationController
  _reminderCardCtrl; // expands Reminder card when Unscheduled ON
  late final AnimationController
  _reminderDateCtrl; // expands Remind Date + Repeat subcard
  late final AnimationController
  _reminderPickerCtrl; // drives inline picker for reminder date
  late final AnimationController _monthSlideCtrl;
  late final AnimationController
  _sectionRowCtrl; // expands the Section subrow for categories with DCV sections

  // ── Picker overlay (Category / Repeat / Alert) ────────────────────────────
  OverlayEntry? _pickerEntry;
  final ValueNotifier<bool> _pickerIsClosing = ValueNotifier(false);
  bool _pickerMenuOpen = false;
  String? _openPickerLabel;

  @override
  void initState() {
    super.initState();
    if (widget.initial == null) {
      final requestedId = widget.initialCategoryId ?? appDefaultCategoryId;
      _categoryId = requestedId == kDefaultCategoryFallbackId
          ? 'uncategorized'
          : requestedId;
    }
    final now = DateTime.now();
    // Next full hour, minute = 0.  DateTime handles the 23→0 midnight rollover.
    _starts = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    _ends = _starts.add(Duration(minutes: _durationMinutes));
    _pickerCalMonth = DateTime(_starts.year, _starts.month);
    // End Date defaults to today + 1 month (matches events_tab).
    _endDate = DateTime(now.year, now.month + 1, now.day);
    _calendarMonth = DateTime(now.year, now.month + 1);
    const dur = Duration(milliseconds: 280);
    _startsPickerCtrl = AnimationController(vsync: this, duration: dur);
    _endsPickerCtrl = AnimationController(vsync: this, duration: dur);
    // Starts at 1.0 (fully visible); animates to 0.0 when Unscheduled is on.
    _schedRowsCtrl = AnimationController(
      vsync: this,
      duration: dur,
      value: 1.0,
    );
    _pickerSlideCtrl = AnimationController(vsync: this, duration: dur);
    _pickerSlideCtrl.addListener(_onPickerSlideUpdate);
    // Travel row collapse (All-day on → row hidden; starts visible).
    _travelRowCtrl = AnimationController(
      vsync: this,
      duration: dur,
      value: 1.0,
    );
    // Travel / Repeat / Alert / Month cascading controllers.
    _travelModeCtrl = AnimationController(vsync: this, duration: dur);
    _repeatCardCtrl = AnimationController(
      vsync: this,
      duration: dur,
      value: 1.0, // visible by default; collapses to 0 when Unscheduled is on
    );
    _endRepeatCtrl = AnimationController(vsync: this, duration: dur);
    _endDateCtrl = AnimationController(vsync: this, duration: dur);
    _datePickerCtrl = AnimationController(vsync: this, duration: dur);
    // Second Alert is visible by default (Alert ≠ 'None').
    _secondAlertCtrl = AnimationController(
      vsync: this,
      duration: dur,
      value: 1.0,
    );
    // Alert card visible by default; Reminder card hidden.  They cross-fade
    // when Unscheduled is toggled: alert collapses, reminder expands.
    _alertCardCtrl = AnimationController(
      vsync: this,
      duration: dur,
      value: 1.0,
    );
    _reminderCardCtrl = AnimationController(vsync: this, duration: dur);
    _reminderDateCtrl = AnimationController(vsync: this, duration: dur);
    _reminderPickerCtrl = AnimationController(vsync: this, duration: dur);
    _sectionRowCtrl = AnimationController(vsync: this, duration: dur);
    // Default reminder date: tomorrow at 9 AM.
    _reminderDate = DateTime(now.year, now.month, now.day + 1, 9, 0);
    _monthSlideCtrl = AnimationController(vsync: this, duration: dur);
    _monthSlideCtrl.addListener(_onMonthSlideUpdate);
    _importProgressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _attachmentDropCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _attachmentConsumeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 340),
    );
    // Focus listeners drive placeholder-slide animations and trailing-icon
    // visibility.  They MUST NOT call setState synchronously: FocusNode
    // notifies listeners during the pointer-down phase of a tap, so a
    // synchronous setState causes a widget rebuild mid-gesture.  That rebuild
    // confuses TapAndDragGestureRecognizer — it treats the tap as a drag and
    // extends the text selection from the tap point to the existing cursor
    // position instead of simply moving the cursor there.
    // Deferring to the next frame (addPostFrameCallback) preserves all the UI
    // update behaviour while keeping the gesture recogniser state clean.
    void deferredSetState() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    }

    _titleFocus.addListener(deferredSetState);
    _subtitleFocus.addListener(deferredSetState);
    _locationFocus.addListener(deferredSetState);
    _destFocus.addListener(deferredSetState);
    _urlFocus.addListener(deferredSetState);
    _notesFocus.addListener(deferredSetState);
    _loadCategories();
    // Pre-populate fields when editing an existing event.
    // Must run after all controllers are created (above) so that
    // _initFromEvent can set their initial values directly.
    if (widget.initial != null) _initFromEvent(widget.initial!);
    _initialDraftSignature = _draftSignature();
    // Auto-focus title on new events only; when editing the user may want
    // to review existing content rather than immediately enter the title.
    if (!widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _titleFocus.requestFocus();
      });
    }
  }

  Map<String, dynamic>? _repeatConfigSignature(
    _NewEventCustomRepeatConfig? config,
  ) {
    if (config == null) return null;
    return {
      'frequency': config.frequency,
      'everyCount': config.everyCount,
      'selectedDays': config.selectedDays.toList()..sort(),
      'monthlyMode': config.monthlyMode,
      'selectedDates': config.selectedDates.toList()..sort(),
      'onThePositionIndex': config.onThePositionIndex,
      'onTheDayIndex': config.onTheDayIndex,
      'selectedMonths': config.selectedMonths.toList()..sort(),
      'yearlyDaysEnabled': config.yearlyDaysEnabled,
      'yearlyPositionIndex': config.yearlyPositionIndex,
      'yearlyDayIndex': config.yearlyDayIndex,
    };
  }

  List<String> _attachmentSignatures() => [
    for (final attachment in _attachments)
      '${attachment.path ?? ''}|${attachment.name}|${attachment.bytes?.length ?? 0}',
  ];

  String _draftSignature() => jsonEncode({
    'title': _titleCtrl.text.trim(),
    'subtitle': _subtitleCtrl.text.trim(),
    'location': _locationTextCtrl.text.trim(),
    'destination': _destCtrl.text.trim(),
    'url': _urlCtrl.text.trim(),
    'notes': _notesCtrl.text.trim(),
    'allDay': _allDay,
    'unscheduled': _unscheduled,
    'starts': _starts.toIso8601String(),
    'ends': _ends.toIso8601String(),
    'travelTime': _travelTime,
    'travelMode': _travelMode,
    'repeat': _repeat,
    'repeatConfig': _repeatConfigSignature(_savedCustomConfig),
    'endRepeat': _endRepeat,
    'endDate': _endRepeat == 'On Date' ? _endDate.toIso8601String() : null,
    'alerts': List<String>.of(_alerts),
    'reminder': _unscheduled ? _reminder : null,
    'reminderDate': _unscheduled && _reminder == 'On Date'
        ? _reminderDate.toIso8601String()
        : null,
    'repeatReminder': _unscheduled && _reminder == 'On Date'
        ? _repeatReminder
        : null,
    'reminderConfig': _unscheduled && _reminder == 'On Date'
        ? _repeatConfigSignature(_savedReminderCustomConfig)
        : null,
    'categoryId': _categoryId,
    'attachments': _attachmentSignatures(),
  });

  bool get _hasUnsavedChanges =>
      _initialDraftSignature != null &&
      _draftSignature() != _initialDraftSignature;

  Future<void> _requestDismiss({required bool fromXmark}) async {
    if (dismissActiveDiscardChangesConfirmationSheet()) return;
    if (_pickerMenuOpen) {
      _dismissPickerOverlay();
      return;
    }
    if (!_hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDiscardChangesConfirmationSheet(
      context,
      entityLabel: 'event',
      isNew: !widget.isEditing,
      fromXmark: fromXmark,
    );
    if (!mounted || discard != true) return;
    setState(() => _discarding = true);
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _pickerEntry?.remove();
    _importOverlayEntry?.remove();
    _pickerIsClosing.dispose();
    _startsPickerCtrl.dispose();
    _endsPickerCtrl.dispose();
    _schedRowsCtrl.dispose();
    _pickerSlideCtrl.dispose();
    _travelRowCtrl.dispose();
    _travelModeCtrl.dispose();
    _repeatCardCtrl.dispose();
    _endRepeatCtrl.dispose();
    _endDateCtrl.dispose();
    _datePickerCtrl.dispose();
    _secondAlertCtrl.dispose();
    _alertCardCtrl.dispose();
    _reminderCardCtrl.dispose();
    _reminderDateCtrl.dispose();
    _reminderPickerCtrl.dispose();
    _monthSlideCtrl.dispose();
    _sectionRowCtrl.dispose();
    _importProgressCtrl.dispose();
    _attachmentDropCtrl.dispose();
    _attachmentConsumeCtrl.dispose();
    _titleCtrl.dispose();
    _subtitleCtrl.dispose();
    _titleScrollCtrl.dispose();
    _subtitleScrollCtrl.dispose();
    _locationTextCtrl.dispose();
    _locationScrollCtrl.dispose();
    _destCtrl.dispose();
    _destScrollCtrl.dispose();
    _urlCtrl.dispose();
    _urlScrollCtrl.dispose();
    _notesCtrl.dispose();
    _notesScrollCtrl.dispose();
    _titleFocus.dispose();
    _subtitleFocus.dispose();
    _locationFocus.dispose();
    _destFocus.dispose();
    _urlFocus.dispose();
    _notesFocus.dispose();
    for (final controller in _attachmentScrollControllers.values) {
      controller.dispose();
    }
    _attachmentScrollControllers.clear();
    super.dispose();
  }

  ScrollController _attachmentScrollControllerFor(_AttachmentFile file) {
    return _attachmentScrollControllers.putIfAbsent(
      file,
      ScrollController.new,
    );
  }

  // ── Formatting ────────────────────────────────────────────────────────────

  static const _kMonthAbbr = [
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

  String _fmtDate(DateTime d) =>
      '${_kMonthAbbr[d.month - 1]} ${d.day}, ${d.year}';

  String _fmtTime(DateTime d) {
    final h = d.hour == 0 ? 12 : (d.hour > 12 ? d.hour - 12 : d.hour);
    final mm = d.minute.toString().padLeft(2, '0');
    return '$h:$mm ${d.hour < 12 ? 'AM' : 'PM'}';
  }

  // ── Shared text styles ────────────────────────────────────────────────────

  static final _kLabelStyleBase = TextStyle(
    inherit: false,
    color: kPrimaryLabel,
    fontSize: 17,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
    height: kLineHeight,
  );

  static final _kPlaceholderStyleBase = TextStyle(
    inherit: false,
    color: kTertiaryLabel,
    fontSize: 17,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
    height: kLineHeight,
  );

  static final _kPillStyleBase = TextStyle(
    inherit: false,
    color: kPrimaryLabel,
    fontSize: 15,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w500,
    letterSpacing: kTracking17,
  );

  static final _kRowValueStyleBase = TextStyle(
    inherit: false,
    color: kSecondaryLabel,
    fontSize: 15,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
    height: kLineHeight,
  );

  static final _kPickerItemStyleBase = TextStyle(
    inherit: false,
    color: kPrimaryLabel,
    fontSize: 16,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
  );

  TextStyle get _kLabelStyle =>
      resolveThemeTextStyle(_kLabelStyleBase, context);
  TextStyle get _kPlaceholderStyle =>
      resolveThemeTextStyle(_kPlaceholderStyleBase, context);
  TextStyle get _kPillStyle => resolveThemeTextStyle(_kPillStyleBase, context);
  TextStyle get _kRowValueStyle =>
      resolveThemeTextStyle(_kRowValueStyleBase, context);
  TextStyle get _kPickerItemStyle =>
      resolveThemeTextStyle(_kPickerItemStyleBase, context);
  Color get _resolvedPillColor => resolveThemeColor(kPillColor, context);

  // ── Card wrapper ──────────────────────────────────────────────────────────

  Widget _card(List<Widget> rows) {
    final cardColor = resolveThemeColor(kModalCard, context);
    final shadows = resolveThemeShadows(kCardShadow, context);
    final ShapeBorder shape = const BoundedSquircleStadiumBorder();
    return Container(
      decoration: ShapeDecoration(
        color: cardColor,
        shape: shape,
        shadows: shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _sep() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      height: 0.5,
      color: resolveThemeColor(kSeparatorColor, context),
    ),
  );

  Widget _cardWithRadius(
    List<Widget> rows,
    BorderRadius radius, {
    bool stadium = false,
  }) {
    final cardColor = resolveThemeColor(kModalCard, context);
    final shadows = resolveThemeShadows(kCardShadow, context);
    final resolvedRadius = radius.resolve(Directionality.of(context));
    final effectiveRadius = [
      resolvedRadius.topLeft.x,
      resolvedRadius.topLeft.y,
      resolvedRadius.topRight.x,
      resolvedRadius.topRight.y,
      resolvedRadius.bottomLeft.x,
      resolvedRadius.bottomLeft.y,
      resolvedRadius.bottomRight.x,
      resolvedRadius.bottomRight.y,
    ].reduce((a, b) => a > b ? a : b);
    final hasTopCorners =
        resolvedRadius.topLeft.x > 0 || resolvedRadius.topRight.x > 0;
    final hasBottomCorners =
        resolvedRadius.bottomLeft.x > 0 || resolvedRadius.bottomRight.x > 0;
    final shape = BoundedSquircleStadiumBorder(
      radius: effectiveRadius,
      topOnly: !stadium && hasTopCorners && !hasBottomCorners,
      bottomOnly: !stadium && hasBottomCorners && !hasTopCorners,
    );
    return Container(
      decoration: ShapeDecoration(
        color: cardColor,
        shape: shape,
        shadows: shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  // ── Text field with animated sliding placeholder ──────────────────────────

  Widget _textField({
    required TextEditingController ctrl,
    required FocusNode focus,
    required String placeholder,
    bool caretToEndOnTap = false,
    ScrollController? scrollController,
    bool multiline = false,
    int? minLinesOverride,
    int? maxLinesOverride,
    EdgeInsets? paddingOverride,
  }) {
    final clearIconSize = scaledSearchIconSize(context, 18);
    final resolvedSurface = resolveThemeColor(kModalCard, context);
    final textField = CupertinoTheme(
      data: CupertinoTheme.of(context).copyWith(
        primaryColor: renderCategoryColor(_categoryColor, context),
      ),
      child: DefaultSelectionStyle(
        selectionColor: renderCategoryColor(
          _categoryColor,
          context,
        ).withValues(alpha: 0.20),
        child: trackTextFieldPointerDown(
          focusNode: focus,
          child: CupertinoTextField(
          controller: ctrl,
          focusNode: focus,
          scrollController: scrollController,
          placeholder: '',
          style: _kLabelStyle,
          cursorColor: renderCategoryColor(_categoryColor, context),
          decoration: null,
          textCapitalization: TextCapitalization.sentences,
          maxLines: maxLinesOverride ?? (multiline ? null : 1),
          minLines: minLinesOverride ?? (multiline ? 3 : 1),
          onTap: caretToEndOnTap
              ? () {
                  if (shouldMoveTextFieldCaretToEnd(focus)) {
                    scheduleTextFieldCaretToEnd(
                      ctrl,
                      scrollController: scrollController,
                      isMounted: () => mounted,
                    );
                  }
                }
              : null,
          scrollPhysics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
           padding:
               multiline
                   ? EdgeInsets.only(right: math.max(28.0, clearIconSize))
                   : EdgeInsets.only(
                       left: 0,
                       right: clearIconSize + kHorizontalFadeContentGap,
                     ),
          onChanged: (_) => setState(() {}),
          ),
        ),
      ),
    );
    return Padding(
      padding:
          paddingOverride ??
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Stack(
        alignment: Alignment.topLeft,
        children: [
          multiline
              ? VerticalEdgeFade(
                  fadeColor: resolvedSurface,
                  fadeHeight: 48,
                  fadeOnRubberbandWhenContentFits: true,
                  controller: ctrl,
                  scrollController: scrollController,
                  placeholderText: placeholder,
                  placeholderTextStyle: _kPlaceholderStyle,
                  placeholderAlignment: Alignment.topLeft,
                  placeholderFocusNode: focus,
                  child: textField,
                )
              : HorizontalEdgeFade(
                  fadeColor: resolvedSurface,
                  fadeOnRubberbandWhenContentFits: true,
                  // This field is already 16 px inside the card from the
                  // outer row padding, so the card-edge fade begins here.
                   leadingInset: 0,
                   trailingInset: clearIconSize + kHorizontalFadeContentGap,
                   placeholderText: multiline ? null : placeholder,
                   placeholderTextStyle: multiline
                       ? null
                       : _kPlaceholderStyle,
                   placeholderFocusNode: multiline ? null : focus,
                  controller: ctrl,
                  scrollController: scrollController,
                  child: textField,
                ),
          // Clear button
          AnimatedBuilder(
            animation: ctrl,
            builder: (_, __) {
              if (ctrl.text.isEmpty) return const SizedBox.shrink();
              return Positioned(
                right: 0,
                top: modalFirstLineActionTop(
                  context,
                  actionHeight: clearIconSize,
                ),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    ctrl.clear();
                    setState(() {});
                  },
                  child: Icon(
                    kSearchClearCircleIcon,
                    color: kEmptyStateIcon,
                    size: clearIconSize,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ── Expandable multiline field (capped at 10 lines with Show More/Less) ──

  static const int _kExpandableMaxLines = 10;

  Widget _expandableField({
    required TextEditingController ctrl,
    required FocusNode focus,
    required String placeholder,
    required bool expanded,
    required VoidCallback onToggle,
    int? minLinesOverride,
  }) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (ctx, _) => LayoutBuilder(
        builder: (ctx2, constraints) {
          // Measure whether text exceeds 10 lines at the available width.
          // Subtract horizontal padding (16 × 2) + clear-button right space (28).
          final availableWidth = constraints.maxWidth - 32 - 28;
          final tp = TextPainter(
            text: TextSpan(
              text: ctrl.text.isEmpty ? ' ' : ctrl.text,
              style: TextStyle(
                fontSize: 17,
                fontFamily: kSFProText,
                fontWeight: FontWeight.w400,
                letterSpacing: kTracking17,
                height: kLineHeight,
              ),
            ),
            maxLines: _kExpandableMaxLines,
            textDirection: TextDirection.ltr,
          )..layout(maxWidth: availableWidth.clamp(1.0, double.infinity));

          final overflows = ctrl.text.isNotEmpty && tp.didExceedMaxLines;
          final showToggle = overflows || expanded;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _textField(
                ctrl: ctrl,
                focus: focus,
                placeholder: placeholder,
                multiline: true,
                minLinesOverride: minLinesOverride,
                maxLinesOverride: expanded ? null : _kExpandableMaxLines,
                // Reduce bottom padding when the Show More/Less row follows.
                paddingOverride: showToggle
                    ? const EdgeInsets.fromLTRB(16, 14, 16, 4)
                    : null,
              ),
              if (showToggle)
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onToggle,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: Text(
                      expanded ? 'Show Less\u2026' : 'Show More\u2026',
                      style: TextStyle(
                        inherit: false,
                        color: kSecondaryLabel,
                        fontSize: 13,
                        fontFamily: kSFProText,
                        fontWeight: FontWeight.w400,
                        letterSpacing: kTracking17,
                        height: kLineHeight,
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  // ── Pill ──────────────────────────────────────────────────────────────────

  Widget _pill(String text) => Container(
    decoration: const ShapeDecoration(
      color: kModalBackground,
      shape: BoundedSquircleStadiumBorder(radius: 100),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    child: Text(text, style: _kPillStyle),
  );

  // ── Switch row ────────────────────────────────────────────────────────────

  Widget _switchRow(String label, bool value, VoidCallback onToggle) =>
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text(label, style: _kLabelStyle),
              const Spacer(),
              // height: 30 matches pill height so switch rows == date rows
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
                      value: value,
                      onChanged: (_) => onToggle(),
                      color: _resolvedCategoryColor,
                      height: 31,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );

  // ── Date/time row (Starts / Ends) — date pill opens inline picker ─────────

  static const _kPickerMonthNames = [
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
  static const _kDayLetters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

  Widget _buildDateRow(String label, DateTime dt, String target) {
    final dateOpen = _activePicker == target;
    final timeOpen = _activePicker == '${target}_time';
    return AnimatedSize(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: AdaptiveLabelPillRow(
          label: label,
          labelStyle: _kLabelStyle,
          // Starts and Ends use a date + time pill pair. Keep that pair
          // together below the label when the complete row cannot fit.
          pillsBelowLabelOnWrap: !_allDay,
          verticalWrapGap: kWrappedLabelValueGap,
          onLabelTap: () => _togglePicker(target),
          pills: [
            AdaptivePillSpec(
              text: _fmtDate(dt),
              backgroundColor: _resolvedPillColor,
              style: TextStyle(
                inherit: false,
                color: dateOpen
                    ? _resolvedCategoryColor
                    : resolveThemeColor(kPrimaryLabel, context),
                fontSize: 15,
                fontFamily: kSFProText,
                fontWeight: FontWeight.w500,
                letterSpacing: kTracking17,
              ),
              onTap: () => _togglePicker(target),
            ),
            if (!_allDay)
              AdaptivePillSpec(
                text: _fmtTime(dt),
                backgroundColor: _resolvedPillColor,
                style: TextStyle(
                  inherit: false,
                  color: timeOpen
                      ? _resolvedCategoryColor
                      : resolveThemeColor(kPrimaryLabel, context),
                  fontSize: 15,
                  fontFamily: kSFProText,
                  fontWeight: FontWeight.w500,
                  letterSpacing: kTracking17,
                ),
                onTap: () => _togglePicker('${target}_time'),
              ),
          ],
        ),
      ),
    );
  }

  // ── Picker toggle ──────────────────────────────────────────────────────────

  // Returns the controller responsible for the given picker target.
  // Returns the AnimationController that drives the picker for [target].
  // Supports 'starts', 'starts_time', 'ends', 'ends_time', 'reminder',
  // and 'reminder_time'.
  AnimationController _ctrlFor(String target) {
    if (target == 'starts' || target == 'starts_time') return _startsPickerCtrl;
    if (target == 'ends' || target == 'ends_time') return _endsPickerCtrl;
    return _reminderPickerCtrl;
  }

  void _togglePicker(String target) {
    final ctrl = _ctrlFor(target);

    if (_activePicker == target && ctrl.value > 0.5) {
      // Same picker tapped again — close it.
      ctrl.animateTo(0.0, curve: Curves.easeIn).then((_) {
        if (mounted) setState(() => _activePicker = '');
      });
      return;
    }

    void openTarget() {
      setState(() {
        _activePicker = target;
        _pickerCalMonth = _monthFor(target);
        _pickerBarrelMode = false;
        _pickerDragOffset = 0.0;
        _pickerSlideTween = null;
      });
      ctrl.animateTo(1.0, curve: Curves.easeOut);
    }

    if (_activePicker.isNotEmpty) {
      // Close whichever picker is currently open, then open target.
      _ctrlFor(_activePicker).animateTo(0.0, curve: Curves.easeIn).then((_) {
        if (mounted) openTarget();
      });
    } else {
      openTarget();
    }
  }

  DateTime _monthFor(String target) {
    if (target == 'starts' || target == 'starts_time') {
      return DateTime(_starts.year, _starts.month);
    }
    if (target == 'reminder' || target == 'reminder_time') {
      return DateTime(_reminderDate.year, _reminderDate.month);
    }
    return DateTime(_ends.year, _ends.month);
  }

  // The date (and time) currently being edited by the open picker.
  DateTime get _pickerDate {
    if (_activePicker == 'starts' || _activePicker == 'starts_time') {
      return _starts;
    }
    if (_activePicker == 'reminder' || _activePicker == 'reminder_time') {
      return _reminderDate;
    }
    return _ends;
  }

  void _setPickerDate(DateTime d) {
    setState(() {
      if (_activePicker == 'starts') {
        final newStarts = DateTime(
          d.year,
          d.month,
          d.day,
          _starts.hour,
          _starts.minute,
        );
        _starts = newStarts;
        if (_allDay) {
          // All-day: clamp Ends to Starts if it would fall before.
          final endsDateOnly = DateTime(_ends.year, _ends.month, _ends.day);
          final newStartsDateOnly = DateTime(d.year, d.month, d.day);
          if (endsDateOnly.isBefore(newStartsDateOnly)) {
            _ends = DateTime(d.year, d.month, d.day, _ends.hour, _ends.minute);
          }
        } else {
          // Timed event: auto-adjust Ends to maintain the duration interval.
          _ends = _starts.add(Duration(minutes: _durationMinutes));
        }
      } else if (_activePicker == 'reminder') {
        // Reminder date: just update the date component, preserve time.
        _reminderDate = DateTime(
          d.year,
          d.month,
          d.day,
          _reminderDate.hour,
          _reminderDate.minute,
        );
      } else {
        // Ends picker: defensive clamp.
        final startsDateOnly = DateTime(
          _starts.year,
          _starts.month,
          _starts.day,
        );
        final proposedDateOnly = DateTime(d.year, d.month, d.day);
        final clamped = proposedDateOnly.isBefore(startsDateOnly)
            ? startsDateOnly
            : proposedDateOnly;
        _ends = DateTime(
          clamped.year,
          clamped.month,
          clamped.day,
          _ends.hour,
          _ends.minute,
        );
      }
    });
  }

  void _setPickerTime(DateTime dt) {
    setState(() {
      if (_activePicker == 'starts_time') {
        _starts = DateTime(
          _starts.year,
          _starts.month,
          _starts.day,
          dt.hour,
          dt.minute,
        );
        _ends = _starts.add(Duration(minutes: _durationMinutes));
      } else if (_activePicker == 'ends_time') {
        var proposed = DateTime(
          _ends.year,
          _ends.month,
          _ends.day,
          dt.hour,
          dt.minute,
        );
        final sameDay =
            _ends.year == _starts.year &&
            _ends.month == _starts.month &&
            _ends.day == _starts.day;
        if (sameDay && !proposed.isAfter(_starts)) {
          proposed = _starts.add(const Duration(minutes: 15));
        }
        _ends = proposed;
        _durationMinutes = _ends.difference(_starts).inMinutes.clamp(15, 1440);
      } else if (_activePicker == 'reminder_time') {
        // Update only the time component of the reminder date.
        _reminderDate = DateTime(
          _reminderDate.year,
          _reminderDate.month,
          _reminderDate.day,
          dt.hour,
          dt.minute,
        );
      }
    });
  }

  // ── All-day / Unscheduled toggles ─────────────────────────────────────────

  void _toggleAllDay() {
    // Close any open picker menu before its labels and option set change.
    if (_pickerMenuOpen) {
      _dismissPickerOverlay();
    }
    // Close any open time picker first so the pill resets correctly.
    if (_activePicker.endsWith('_time')) {
      _ctrlFor(_activePicker).animateTo(0.0, curve: Curves.easeIn).then((_) {
        if (mounted) setState(() => _activePicker = '');
      });
    }
    final turningOn = !_allDay;
    setState(() {
      _allDay = turningOn;
      if (turningOn) {
        // Reset travel selections so they don't bleed into alert labels and
        // so toggling All-day back off always starts fresh with 'None'.
        _travelTime = 'None';
        _travelMode = 'None';
        // All-day default: remind the user the night before and expose the
        // optional second reminder. Choosing None in the Reminder picker
        // remains the deliberate opt-out and collapses the second row.
        _alert = 'Night before (9 PM)';
        _secondAlert = 'None';
      } else {
        // Restore sensible non-all-day defaults.
        _alert = 'At time of event';
        _secondAlert = 'None';
      }
    });
    if (turningOn) {
      // All-day ON → collapse Travel Time and Travel Mode. The default
      // Reminder is active, so keep Second Reminder visible.
      _travelRowCtrl.animateTo(0.0, curve: Curves.easeIn);
      _travelModeCtrl.animateTo(0.0, curve: Curves.easeIn);
      _secondAlertCtrl.animateTo(1.0, curve: Curves.easeOut);
    } else {
      // All-day OFF → restore Travel Time row; Second Alert visible again
      // because alert is now 'At time of event' (not 'None').
      _travelRowCtrl.animateTo(1.0, curve: Curves.easeOut);
      _secondAlertCtrl.animateTo(1.0, curve: Curves.easeOut);
    }
  }

  void _toggleUnscheduled() {
    final turningOn = !_unscheduled;
    setState(() {
      _unscheduled = turningOn;
    });
    if (turningOn) {
      // Close any starts/ends picker; reminder picker stays (its section is
      // already about to animate in).
      if (_activePicker.isNotEmpty &&
          _activePicker != 'reminder' &&
          _activePicker != 'reminder_time') {
        _ctrlFor(_activePicker).value = 0.0;
        setState(() => _activePicker = '');
      }
      // Animate scheduled rows, Travel Time, Travel Mode, Repeat, and Alert
      // all out; animate the Reminder card in simultaneously.
      _schedRowsCtrl.animateTo(0.0, curve: Curves.easeIn).then((_) {
        // All-day is hidden during the collapse. Reset it only after the
        // scheduled rows are fully gone, so the switch never visibly turns
        // off as it is being hidden.
        if (!mounted || !_unscheduled || !_allDay) return;
        setState(() => _allDay = false);
      });
      _travelRowCtrl.animateTo(0.0, curve: Curves.easeIn);
      _travelModeCtrl.animateTo(0.0, curve: Curves.easeIn);
      _repeatCardCtrl.animateTo(0.0, curve: Curves.easeIn);
      _alertCardCtrl.animateTo(0.0, curve: Curves.easeIn);
      _reminderCardCtrl.animateTo(1.0, curve: Curves.easeOut);
    } else {
      // Close reminder picker if open before the section collapses.
      if (_activePicker == 'reminder' || _activePicker == 'reminder_time') {
        _reminderPickerCtrl.value = 0.0;
        setState(() => _activePicker = '');
      }
      // All-day must be OFF before the scheduled rows begin returning.
      // This also handles an early Unscheduled-off tap before the collapse
      // animation has fully settled.
      if (_allDay) setState(() => _allDay = false);
      _schedRowsCtrl.animateTo(1.0, curve: Curves.easeOut);
      _travelRowCtrl.animateTo(1.0, curve: Curves.easeOut);
      if (_travelTime != 'None') {
        _travelModeCtrl.animateTo(1.0, curve: Curves.easeOut);
      }
      _repeatCardCtrl.animateTo(1.0, curve: Curves.easeOut);
      _alertCardCtrl.animateTo(1.0, curve: Curves.easeOut);
      _reminderCardCtrl.animateTo(0.0, curve: Curves.easeIn);
    }
  }

  // ── Month-slide animation helpers ─────────────────────────────────────────

  void _onPickerSlideUpdate() {
    if (_pickerSlideTween == null) return;
    final t = Curves.easeInOut.transform(_pickerSlideCtrl.value);
    setState(() {
      _pickerDragOffset =
          _pickerSlideTween!.begin! +
          (_pickerSlideTween!.end! - _pickerSlideTween!.begin!) * t;
    });
  }

  void _commitPickerMonthSlide({required bool next}) {
    if (_pickerSlideTween != null) return;
    final target = next ? -_pickerPanelWidth : _pickerPanelWidth;
    _pickerSlideTween = Tween<double>(begin: _pickerDragOffset, end: target);
    _pickerSlideCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _pickerCalMonth = next
            ? DateTime(_pickerCalMonth.year, _pickerCalMonth.month + 1)
            : DateTime(_pickerCalMonth.year, _pickerCalMonth.month - 1);
        _pickerDragOffset = 0;
        _pickerSlideTween = null;
      });
      _pickerSlideCtrl.reset();
    });
  }

  void _snapBackPickerMonthSlide() {
    _pickerSlideTween = Tween<double>(begin: _pickerDragOffset, end: 0);
    _pickerSlideCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _pickerDragOffset = 0;
        _pickerSlideTween = null;
      });
      _pickerSlideCtrl.reset();
    });
  }

  void _prevPickerMonth() => _commitPickerMonthSlide(next: false);
  void _nextPickerMonth() => _commitPickerMonthSlide(next: true);

  void _togglePickerBarrelMode() =>
      setState(() => _pickerBarrelMode = !_pickerBarrelMode);

  // ── Save event ────────────────────────────────────────────────────────────

  Future<void> _saveEvent() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) return;

    // Helper: format a DateTime as "August 8, 2026".
    String _fmtDateSave(DateTime dt) {
      const months = [
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
      return '${months[dt.month - 1]} ${dt.day}, ${dt.year}';
    }

    // Helper: format a DateTime as "3:00 PM".
    String _fmtTimeSave(DateTime dt) {
      final h = dt.hour;
      final m = dt.minute;
      final ampm = h >= 12 ? 'PM' : 'AM';
      final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      return '$h12:${m.toString().padLeft(2, '0')} $ampm';
    }

    String? dateStr;
    String? timeStr;
    String? endDateStr;
    String? endTimeStr;

    if (!_unscheduled) {
      dateStr = _fmtDateSave(_starts);
      endDateStr = _fmtDateSave(_ends);
      if (!_allDay) {
        timeStr = _fmtTimeSave(_starts);
        endTimeStr = _fmtTimeSave(_ends);
      }
    }

    final subtitle = _subtitleCtrl.text.trim();
    final location = _locationTextCtrl.text.trim();

    // Normalise the legacy 'uncategorized' sentinel to the system id so the
    // events_tab filter can match against 'sys-uncategorized' consistently.
    final categoryId = _categoryId == 'uncategorized'
        ? 'sys-uncategorized'
        : _categoryId;

    // ── Repeat ──────────────────────────────────────────────────────────────
    String? repeatStr;
    String? repeatEndTypeStr;
    String? repeatEndDateStr;
    Map<String, dynamic>? customRepeatCfg;

    if (_repeat != 'Never') {
      repeatStr = _repeat;
      repeatEndTypeStr = _endRepeat;
      if (_endRepeat == 'On Date') {
        repeatEndDateStr = _fmtDateSave(_endDate);
      }
      // Serialise custom repeat config if this is a custom rule.
      if (_savedCustomConfig != null) {
        final c = _savedCustomConfig!;
        customRepeatCfg = {
          'frequency': c.frequency,
          'everyCount': c.everyCount,
          'selectedDays': c.selectedDays.toList(),
          'monthlyMode': c.monthlyMode,
          'selectedDates': c.selectedDates.toList(),
          'onThePositionIndex': c.onThePositionIndex,
          'onTheDayIndex': c.onTheDayIndex,
          'selectedMonths': c.selectedMonths.toList(),
          'yearlyDaysEnabled': c.yearlyDaysEnabled,
          'yearlyPositionIndex': c.yearlyPositionIndex,
          'yearlyDayIndex': c.yearlyDayIndex,
        };
      }
    }

    // ── Attachments — persist bytes to the app's documents directory ────────
    List<String>? attachmentPaths;
    if (_attachments.isNotEmpty) {
      try {
        final docsDir = await getApplicationDocumentsDirectory();
        final attachDir = Directory('${docsDir.path}/skeddo_attachments');
        if (!attachDir.existsSync()) attachDir.createSync(recursive: true);
        final paths = <String>[];
        for (final a in _attachments) {
          if (a.path != null) {
            // Already persisted on disk — reuse the existing path without
            // writing a duplicate copy.
            paths.add(a.path!);
          } else if (a.bytes != null || a.sourcePath != null) {
            final ts = DateTime.now().microsecondsSinceEpoch;
            final safeName = a.name.replaceAll(RegExp(r'[^\w.\-]'), '_');
            final file = File('${attachDir.path}/${ts}_$safeName');
            if (a.bytes != null) {
              await file.writeAsBytes(a.bytes!, flush: true);
            } else {
              final source = File(a.sourcePath!);
              if (!await source.exists()) continue;
              await source.copy(file.path);
            }
            paths.add(file.path);
          }
        }
        if (paths.isNotEmpty) attachmentPaths = paths;
      } catch (_) {
        // If file I/O fails, continue without attachments rather than
        // blocking the save.
      }
    }
    // When editing, preserve any existing attachments the user didn't touch
    // (e.g. if they only changed the title, _attachments is empty because
    // _initFromEvent loaded them separately via _existingAttachmentPaths).
    if (widget.isEditing && attachmentPaths == null) {
      attachmentPaths = _existingAttachmentPaths;
    }

    // ── Orphan cleanup on edit ───────────────────────────────────────────────
    // Delete any attachment files that were present on the original event but
    // are absent from the final saved list (i.e. the user removed them).
    if (widget.isEditing) {
      final originalPaths = widget.initial!.attachmentPaths ?? const [];
      final savedPaths = attachmentPaths ?? const [];
      for (final p in originalPaths) {
        if (!savedPaths.contains(p)) {
          try {
            final f = File(p);
            if (f.existsSync()) f.deleteSync();
          } catch (_) {
            // Best-effort — never block the save if the file is already gone.
          }
        }
      }
    }

    if (widget.isEditing) {
      // ── Edit path — preserve original event id, call update() ──────────
      // The store is the single owner of temporal parsing. In particular, do
      // not parse the display strings as one combined value here:
      // "August 8, 2026 3:00 PM" is a UI representation, while the store
      // intentionally parses date and time fields separately. Passing a
      // second, lossy ParsedDate from the sheet could overwrite a valid
      // scheduled event with an unscheduled one.
      EventStore.instance.update(
        ScheduledEvent(
          id: widget.initial!.id,
          title: title,
          subtitle: subtitle.isEmpty ? null : subtitle,
          date: dateStr,
          time: timeStr,
          endDate: endDateStr,
          endTime: endTimeStr,
          isAllDay: _allDay,
          location: location.isEmpty ? null : location,
          destination: _destCtrl.text.trim().isEmpty
              ? null
              : _destCtrl.text.trim(),
          travelTime: _travelTime == 'None' ? null : _travelTime,
          travelMode: _travelMode == 'None' ? null : _travelMode,
          repeat: repeatStr,
          repeatEndType: repeatEndTypeStr,
          repeatEndDate: repeatEndDateStr,
          customRepeatConfig: customRepeatCfg,
          alert: _alert == 'None' ? null : _alert,
          secondAlert: _secondAlert == 'None' ? null : _secondAlert,
          alerts: AlertSequence.compact(_alerts),
          reminderOption: _unscheduled ? _reminder : null,
          reminderDateTime: (_unscheduled && _reminder == 'On Date')
              ? _reminderDate.toIso8601String()
              : null,
          reminderRepeat: (_unscheduled && _reminder == 'On Date')
              ? _repeatReminder
              : null,
          reminderCustomRepeatConfig: (_unscheduled && _reminder == 'On Date')
              ? _customConfigToMap(_savedReminderCustomConfig)
              : null,
          url: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          attachmentPaths: attachmentPaths,
          categoryId: categoryId,
        ),
      );
      await _persistSectionAssignment(widget.initial!.id);
    } else {
      // ── Create path ─────────────────────────────────────────────────────
      final created = EventStore.instance.create(
        title: title,
        subtitle: subtitle.isEmpty ? null : subtitle,
        date: dateStr,
        time: timeStr,
        endDate: endDateStr,
        endTime: endTimeStr,
        isAllDay: _allDay,
        location: location.isEmpty ? null : location,
        destination: _destCtrl.text.trim().isEmpty
            ? null
            : _destCtrl.text.trim(),
        travelTime: _travelTime == 'None' ? null : _travelTime,
        travelMode: _travelMode == 'None' ? null : _travelMode,
        repeat: repeatStr,
        repeatEndType: repeatEndTypeStr,
        repeatEndDate: repeatEndDateStr,
        customRepeatConfig: customRepeatCfg,
        alert: _alert == 'None' ? null : _alert,
        secondAlert: _secondAlert == 'None' ? null : _secondAlert,
        alerts: AlertSequence.compact(_alerts),
        reminderOption: _unscheduled ? _reminder : null,
        reminderDateTime: (_unscheduled && _reminder == 'On Date')
            ? _reminderDate.toIso8601String()
            : null,
        reminderRepeat: (_unscheduled && _reminder == 'On Date')
            ? _repeatReminder
            : null,
        reminderCustomRepeatConfig: (_unscheduled && _reminder == 'On Date')
            ? _customConfigToMap(_savedReminderCustomConfig)
            : null,
        url: _urlCtrl.text.trim().isEmpty ? null : _urlCtrl.text.trim(),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        attachmentPaths: attachmentPaths,
        categoryId: categoryId,
      );
      await _persistSectionAssignment(created.id);
    }

    Navigator.of(context).pop();
  }

  // ── Edit pre-population ───────────────────────────────────────────────────

  /// Parses a stored date string ("August 8, 2026") and optional time string
  /// ("3:00 PM") back to a [DateTime].  Returns null when the format doesn't
  /// match (e.g. the event was entered with a different date parser path).
  static DateTime? _parseStoredDate(String? date, String? time) {
    if (date == null) return null;
    const months = [
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
    final dm = RegExp(r'^(\w+) (\d+), (\d{4})$').firstMatch(date.trim());
    if (dm == null) return null;
    final monthIdx = months.indexOf(dm.group(1)!);
    if (monthIdx < 0) return null;
    final day = int.tryParse(dm.group(2)!) ?? 1;
    final year = int.tryParse(dm.group(3)!) ?? 2000;
    if (time == null) return DateTime(year, monthIdx + 1, day);
    final tm = RegExp(
      r'^(\d+):(\d+) ?(AM|PM)$',
      caseSensitive: false,
    ).firstMatch(time.trim());
    if (tm == null) return DateTime(year, monthIdx + 1, day);
    var hour = int.tryParse(tm.group(1)!) ?? 0;
    final minute = int.tryParse(tm.group(2)!) ?? 0;
    final isPm = tm.group(3)!.toUpperCase() == 'PM';
    if (isPm && hour != 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;
    return DateTime(year, monthIdx + 1, day, hour, minute);
  }

  /// Reconstructs a [_NewEventCustomRepeatConfig] from the JSON map stored
  /// in [ScheduledEvent.customRepeatConfig].  Mirrors the local
  /// [_configFromMap] function used in [_categoryItems].
  static _NewEventCustomRepeatConfig? _configFromEventMap(
    Map<String, dynamic>? m,
  ) {
    if (m == null) return null;
    return _NewEventCustomRepeatConfig(
      frequency: (m['frequency'] as String?) ?? 'Daily',
      everyCount: (m['everyCount'] as int?) ?? 1,
      selectedDays: Set<String>.from(
        (m['selectedDays'] as List?)?.cast<String>() ?? [],
      ),
      monthlyMode: (m['monthlyMode'] as String?) ?? 'Each',
      selectedDates: Set<int>.from(
        (m['selectedDates'] as List?)?.cast<int>() ?? [],
      ),
      onThePositionIndex: (m['onThePositionIndex'] as int?) ?? 0,
      onTheDayIndex: (m['onTheDayIndex'] as int?) ?? 0,
      selectedMonths: Set<int>.from(
        (m['selectedMonths'] as List?)?.cast<int>() ?? [],
      ),
      yearlyDaysEnabled: (m['yearlyDaysEnabled'] as bool?) ?? false,
      yearlyPositionIndex: (m['yearlyPositionIndex'] as int?) ?? 0,
      yearlyDayIndex: (m['yearlyDayIndex'] as int?) ?? 0,
    );
  }

  static Map<String, dynamic>? _customConfigToMap(
    _NewEventCustomRepeatConfig? c,
  ) {
    if (c == null) return null;
    return {
      'frequency': c.frequency,
      'everyCount': c.everyCount,
      'selectedDays': c.selectedDays.toList(),
      'monthlyMode': c.monthlyMode,
      'selectedDates': c.selectedDates.toList(),
      'onThePositionIndex': c.onThePositionIndex,
      'onTheDayIndex': c.onTheDayIndex,
      'selectedMonths': c.selectedMonths.toList(),
      'yearlyDaysEnabled': c.yearlyDaysEnabled,
      'yearlyPositionIndex': c.yearlyPositionIndex,
      'yearlyDayIndex': c.yearlyDayIndex,
    };
  }

  Future<void> _persistSectionAssignment(String eventId) async {
    final previousCategory = _initialCategoryName;
    final currentCategory = _categoryName;
    final currentNames = _currentSectionNames;
    final previousIds = previousCategory == null
        ? null
        : _dcvCustomSectionEventIds[previousCategory];
    final currentIds = _dcvCustomSectionEventIds[currentCategory] ??=
        <List<String>>[];

    // An edited event may have moved categories. Remove its old membership
    // before assigning it to the newly selected category.
    if (previousCategory != null && previousCategory != currentCategory) {
      for (final section in previousIds ?? const <List<String>>[]) {
        section.remove(eventId);
      }
    }

    if (currentNames.isNotEmpty) {
      while (currentIds.length < currentNames.length) {
        currentIds.add(<String>[]);
      }
      while (currentIds.length > currentNames.length) {
        currentIds.removeLast();
      }
      for (final section in currentIds) {
        section.remove(eventId);
      }
      final index = _selectedSectionIndex
          .clamp(0, currentNames.length - 1)
          .toInt();
      currentIds[index].add(eventId);
    } else if (currentIds.isEmpty) {
      _dcvCustomSectionEventIds.remove(currentCategory);
    }

    final notifyEventsTab = widget.onDcvSectionEventIdsChanged;
    if (notifyEventsTab != null) {
      notifyEventsTab(
        currentCategory,
        _dcvCustomSectionEventIds[currentCategory]
                ?.map(List<String>.of)
                .toList() ??
            const <List<String>>[],
      );
    } else {
      // Keep a safe fallback for callers that create the sheet without the
      // AppShell-owned live section bridge.
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _kPrefsDcvCustomSectionEventIds,
        jsonEncode(_dcvCustomSectionEventIds),
      );
    }
    // The Events tab now owns the live map, so notify the event list after
    // that map is updated and the newly saved event appears immediately.
    EventStore.instance.events.notifyListeners();
    _initialCategoryName = currentCategory;
  }

  /// Pre-populate all sheet fields from an existing [ScheduledEvent].
  ///
  /// Called from [initState] immediately after all animation controllers are
  /// created, so their [.value] can be set directly (no animation).
  void _initFromEvent(ScheduledEvent e) {
    // ── Text fields ────────────────────────────────────────────────────────
    _titleCtrl.text = e.title;
    _subtitleCtrl.text = e.subtitle ?? '';
    _locationTextCtrl.text = e.location ?? '';
    _destCtrl.text = e.destination ?? '';
    _urlCtrl.text = e.url ?? '';
    _notesCtrl.text = e.notes ?? '';

    // Show multiline fields expanded when they already have content.
    _subtitleExpanded = e.subtitle?.isNotEmpty == true;
    _notesExpanded = e.notes?.isNotEmpty == true;

    // ── Dates / times ──────────────────────────────────────────────────────
    _allDay = e.isAllDay;
    _unscheduled = e.date == null;
    if (e.date != null) {
      final startDt = _parseStoredDate(e.date, _allDay ? null : e.time);
      if (startDt != null) {
        _starts = startDt;
        final endDt = _parseStoredDate(e.endDate, _allDay ? null : e.endTime);
        _ends = endDt ?? _starts.add(Duration(minutes: _durationMinutes));
        _pickerCalMonth = DateTime(_starts.year, _starts.month);
      }
    }

    // ── Travel ────────────────────────────────────────────────────────────
    _travelTime = e.travelTime ?? 'None';
    _travelMode = e.travelMode ?? 'None';

    // ── Repeat ────────────────────────────────────────────────────────────
    _repeat = e.repeat ?? 'Never';
    _savedCustomConfig = _configFromEventMap(e.customRepeatConfig);
    _endRepeat = e.repeatEndType ?? 'Never';
    if (e.repeatEndDate != null) {
      final ed = _parseStoredDate(e.repeatEndDate, null);
      if (ed != null) {
        _endDate = ed;
        _calendarMonth = DateTime(ed.year, ed.month);
      }
    }

    // ── Alerts ────────────────────────────────────────────────────────────
    _alerts = _normaliseAlertState(e.alertSequence);
    if (_alerts.isEmpty && e.alerts == null && e.alert == null) {
      _alerts = ['At time of event'];
    }

    // ── Reminder (Unscheduled events only) ────────────────────────────────
    if (_unscheduled) {
      _reminder = e.reminderOption ?? 'Never';
      _repeatReminder = e.reminderRepeat ?? 'Never';
      _savedReminderCustomConfig = _configFromEventMap(
        e.reminderCustomRepeatConfig,
      );
      if (e.reminderDateTime != null) {
        final rd = DateTime.tryParse(e.reminderDateTime!);
        if (rd != null) _reminderDate = rd;
      }
    }

    // ── Category ──────────────────────────────────────────────────────────
    // Normalize system sentinel → sheet sentinel so the category picker
    // checkmark and colour resolve correctly.
    _categoryId = e.categoryId == 'sys-uncategorized'
        ? 'uncategorized'
        : e.categoryId;

    // ── Attachments ───────────────────────────────────────────────────────
    // Carry the existing paths forward; they are merged into the save
    // result by _saveEvent so the user doesn't lose files they didn't touch.
    _existingAttachmentPaths = e.attachmentPaths?.isEmpty == true
        ? null
        : e.attachmentPaths;
    // Load existing files into the attachment list so the user can see
    // and optionally remove them.
    for (final p in e.attachmentPaths ?? []) {
      try {
        final file = File(p);
        if (!file.existsSync()) continue;
        final rawName = p.split('/').last;
        // Strip the "<timestamp>_" prefix written by the save handler.
        final displayName = rawName.replaceFirst(RegExp(r'^\d+_'), '');
        final ext = displayName.contains('.')
            ? displayName.split('.').last.toLowerCase()
            : '';
        final bytes = file.readAsBytesSync();
        const imageExts = {'png', 'jpg', 'jpeg', 'gif', 'webp', 'heic', 'heif'};
        _attachments.add(
          _AttachmentFile(
            name: displayName,
            ext: ext,
            bytes: bytes,
            isImage: imageExts.contains(ext),
            path: p, // reuse on save; prevents duplicate copies
          ),
        );
      } catch (_) {
        // Skip unreadable files silently.
      }
    }

    // ── Animation controllers ─────────────────────────────────────────────
    // All controllers were just created with their default values.  Correct
    // the ones that differ based on the loaded event state.
    if (_unscheduled) {
      _schedRowsCtrl.value = 0.0;
      _travelRowCtrl.value = 0.0;
      _repeatCardCtrl.value = 0.0;
      _alertCardCtrl.value = 0.0;
      _reminderCardCtrl.value = 1.0;
      if (_reminder == 'On Date') _reminderDateCtrl.value = 1.0;
    }
    if (_allDay) _travelRowCtrl.value = 0.0;
    if (_travelTime != 'None') _travelModeCtrl.value = 1.0;
    if (_repeat != 'Never') {
      _endRepeatCtrl.value = 1.0;
      if (_endRepeat == 'On Date') _endDateCtrl.value = 1.0;
    }
    if (_alert == 'None') _secondAlertCtrl.value = 0.0;
  }

  // ── Category loading ──────────────────────────────────────────────────────

  Future<void> _loadCategories() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('events_user_categories') ?? [];
    final rawDcvSections = prefs.getString(_kPrefsDcvCustomSections);
    final rawDcvSectionEventIds = prefs.getString(
      _kPrefsDcvCustomSectionEventIds,
    );
    final loadedSectionNames = <String, List<String>>{};
    final loadedSectionEventIds = <String, List<List<String>>>{};
    try {
      final decoded = rawDcvSections == null
          ? null
          : jsonDecode(rawDcvSections);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          loadedSectionNames[entry.key.toString()] = entry.value is List
              ? [for (final name in entry.value as List) name.toString()]
              : <String>[];
        }
      }
    } catch (_) {
      // A malformed section preference must not prevent the category picker
      // from opening. The Events tab will repair the preference on its next
      // successful section edit.
    }
    try {
      final decoded = rawDcvSectionEventIds == null
          ? null
          : jsonDecode(rawDcvSectionEventIds);
      if (decoded is Map) {
        for (final entry in decoded.entries) {
          final value = entry.value;
          loadedSectionEventIds[entry.key.toString()] = value is List
              ? [
                  for (final section in value)
                    section is List
                        ? [for (final id in section) id.toString()]
                        : <String>[],
                ]
              : <List<String>>[];
        }
      }
    } catch (_) {
      // See the section-name guard above.
    }

    // EventsTab is the live owner of section state. Preference reads are only
    // the cold-start fallback; prefer the live snapshot when the DCV was just
    // edited and its queued write has not completed yet.
    final liveSectionNames = widget.dcvSectionNamesProvider?.call();
    if (liveSectionNames != null) {
      loadedSectionNames
        ..clear()
        ..addAll({
          for (final entry in liveSectionNames.entries)
            entry.key: List<String>.of(entry.value),
        });
    }
    final liveSectionEventIds = widget.dcvSectionEventIdsProvider?.call();
    if (liveSectionEventIds != null) {
      loadedSectionEventIds
        ..clear()
        ..addAll({
          for (final entry in liveSectionEventIds.entries)
            entry.key: entry.value.map(List<String>.of).toList(),
        });
    }

    if (!mounted) return;
    final parsed = <_NewEventCategory>[];
    Color uncatColor = kAccentColor;
    for (final s in raw) {
      try {
        final m = jsonDecode(s) as Map<String, dynamic>;
        if ((m['archived'] as bool?) == true) continue;
        final id = (m['id'] as String?) ?? '';
        final name = (m['name'] as String?) ?? '';
        // Archived Items and Recently Deleted are utility/navigation
        // entries, not places where an event can be stored. Check the
        // persisted marker, reserved IDs, and display names so this remains
        // correct for both current and legacy records.
        if (m['isSystemUtility'] == true ||
            _kEventPickerUtilityCategoryIds.contains(id) ||
            _kEventPickerUtilityCategoryNames.contains(name)) {
          continue;
        }
        final color = resolveCategorySwatch(
          Color((m['colorValue'] as int?) ?? kAccentColor.value),
        );
        // Capture Uncategorized color (stored with id 'uncategorized' or
        // name 'Uncategorized').
        if (id == 'uncategorized' || name == 'Uncategorized') {
          uncatColor = color;
          continue; // don't add to standard list
        }
        if ((m['categoryType'] as String?) != 'Standard') continue;
        if (name.isNotEmpty) {
          final rawCrc = m['presetCustomRepeatConfig'];
          parsed.add(
            _NewEventCategory(
              id: id.isNotEmpty ? id : 'usr-$name',
              name: name,
              color: color,
              presetLocation: m['presetLocation'] as String?,
              presetDestination: m['presetDestination'] as String?,
              presetTravelTime: m['presetTravelTime'] as String?,
              presetTravelMode: m['presetTravelMode'] as String?,
              presetRepeat: m['presetRepeat'] as String?,
              presetRepeatEndType: m['presetRepeatEndType'] as String?,
              presetRepeatEndDate: m['presetRepeatEndDate'] as String?,
              presetCustomRepeatConfig: rawCrc is Map<String, dynamic>
                  ? rawCrc
                  : null,
              presetAlert: m['presetAlert'] as String?,
              presetSecondAlert: m['presetSecondAlert'] as String?,
              presetAlerts: (m['presetAlerts'] as List?)
                  ?.map((value) => value.toString())
                  .toList(),
            ),
          );
        }
      } catch (_) {}
    }

    // The Events tab owns the built-in category definitions, but a clean
    // install has no persisted category records yet.  Keep those permanent
    // system categories available to the New Event picker independently of
    // SharedPreferences so the first-launch sheet has the same choices as
    // the rest of the app.
    if (!parsed.any((cat) => cat.name == 'Unnamed')) {
      parsed.insert(
        0,
        const _NewEventCategory(
          id: 'sys-unnamed',
          name: 'Unnamed',
          color: kAccentColor,
        ),
      );
    }

    setState(() {
      _dcvCustomSectionNames
        ..clear()
        ..addAll(loadedSectionNames);
      _dcvCustomSectionEventIds
        ..clear()
        ..addAll(loadedSectionEventIds);
      _standardCategories = parsed;
      _uncategorizedColor = uncatColor;
      // Uncategorized is also a permanent system category.  A legacy or
      // partially-written preference list must not make it disappear.
      _hasUncategorized = true;
      // If user hasn't changed category, update default to match current
      // Uncategorized color.
      if (_categoryId == 'uncategorized') _categoryColor = uncatColor;
      // When editing, resolve the name and colour for the pre-selected
      // category (set by _initFromEvent before categories were loaded).
      if (_categoryId != 'uncategorized') {
        final match = parsed.cast<_NewEventCategory?>().firstWhere(
          (c) => c?.id == _categoryId,
          orElse: () => null,
        );
        if (match != null) {
          _categoryName = match.name;
          _categoryColor = match.color;
          _initialCategoryName = _categoryName;
        }
      } else if (widget.initial == null) {
        final match = parsed.cast<_NewEventCategory?>().firstWhere(
          (c) => c?.id == _categoryId,
          orElse: () => null,
        );
        if (match != null) {
          _categoryName = match.name;
          _categoryColor = match.color;
        } else {
          _categoryId = 'uncategorized';
          _categoryName = 'Uncategorized';
          _categoryColor = uncatColor;
        }
      }
      if (widget.initial != null && _initialCategoryName == null) {
        _initialCategoryName = _categoryName;
      }
      _selectedSectionIndex = _sectionIndexForCurrentEvent();
    });
    // Initial sheet rendering should not slide the row in from zero. Later
    // category changes use the animated path below.
    _syncSectionRowAnimation(animate: false);
  }

  // ── Picker overlay (Category / Repeat / Alert) ────────────────────────────

  void _dismissPickerOverlay({bool animate = true}) {
    if (!_pickerMenuOpen) return;
    _pickerIsClosing.value = true;
    if (mounted) setState(() => _openPickerLabel = null);
    final delay = animate ? const Duration(milliseconds: 420) : Duration.zero;
    Future.delayed(delay, () {
      _pickerEntry?.remove();
      _pickerEntry = null;
      if (mounted) {
        _pickerIsClosing.value = false;
        setState(() => _pickerMenuOpen = false);
      }
    });
  }

  void _showPickerOverlay(
    BuildContext rowCtx,
    String rowLabel,
    List<ActionItem> items,
  ) {
    if (_pickerMenuOpen) _dismissPickerOverlay(animate: false);
    FocusManager.instance.primaryFocus?.unfocus();
    final box = rowCtx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    _pickerIsClosing.value = false;
    setState(() {
      _pickerMenuOpen = true;
      _openPickerLabel = rowLabel;
    });
    _pickerEntry = OverlayEntry(
      builder: (ctx) => ActionMenuOverlay(
        buttonRect: Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height),
        isClosing: _pickerIsClosing,
        onDismiss: _dismissPickerOverlay,
        actions: items,
        panelWidth: kPickerPanelWidth,
        chevronColumn: true,
        anchorToRight: true,
        labelFontSize: 15,
        bouncingScroll: true,
        isPickerMiniPanel: true,
      ),
    );
    Overlay.of(context).insert(_pickerEntry!);
  }

  // ── _pickerRow ────────────────────────────────────────────────────────────
  // Identical to _AddCategorySheetState._pickerRow in events_tab.dart.
  // [items] non-null → row is tappable; null → non-interactive (used for
  // read-only summary rows inside the Custom repeat sheet).
  // [showChevron] can be suppressed for the Every row.
  // [valueColor] overrides value text color (accent for highlighted rows).
  // [onTap] is used when items is null but the row should still respond.

  Widget _pickerRow(
    String label,
    String value, {
    List<ActionItem>? items,
    bool showChevron = true,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    final isOpen = items != null && _openPickerLabel == label;
    final TextStyle valueStyle = valueColor != null
        ? _kRowValueStyle.copyWith(
            color: valueColor,
            fontWeight: FontWeight.w500,
          )
        : _kRowValueStyle;
    return Builder(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: items != null
            ? () => _showPickerOverlay(ctx, label, items)
            : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kModalSheetPickerRowHorizontalInset,
            vertical: 14,
          ),
          child: MinGapLabelValueRow(
            label: label,
            labelStyle: _kLabelStyle,
            value: value,
            valueStyle: valueStyle,
            trailing: AnimatedOpacity(
              opacity: isOpen ? kPickerRowOpenDimOpacity : 1.0,
              duration: const Duration(milliseconds: 150),
              child: ModalSheetPickerTrailing(
                value: value,
                style: valueStyle,
                chevronColor: resolveThemeColor(kSecondaryLabel, context),
                showChevron: showChevron,
              ),
            ),
            trailingExtraWidth: modalSheetPickerTrailingExtraWidth(
              ctx,
              showChevron: showChevron,
            ),
          ),
        ),
      ),
    );
  }

  // ── Category picker row ───────────────────────────────────────────────────
  // Colored dot for the selected category; always shows Uncategorized or a
  // user category — "None" is not a valid selection.

  Widget _buildCategoryRow() {
    final isOpen = _openPickerLabel == 'Category';
    final valueWidget = AnimatedOpacity(
      opacity: isOpen ? kPickerRowOpenDimOpacity : 1.0,
      duration: const Duration(milliseconds: 150),
      child: ModalSheetPickerTrailing(
        value: _categoryName,
        style: _kRowValueStyle,
        chevronColor: resolveThemeColor(kSecondaryLabel, context),
        valuePrefix: Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: renderCategoryColor(_categoryColor, context),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
    return Builder(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _showPickerOverlay(ctx, 'Category', _categoryItems()),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kModalSheetPickerRowHorizontalInset,
            vertical: 14,
          ),
          child: MinGapLabelValueRow(
            label: 'Category',
            labelStyle: _kLabelStyle,
            value: _categoryName,
            valueStyle: _kRowValueStyle,
            trailing: valueWidget,
            trailingExtraWidth: modalSheetPickerTrailingExtraWidth(
              ctx,
              hasValuePrefix: true,
            ),
          ),
        ),
      ),
    );
  }

  List<String> get _currentSectionNames =>
      _dcvCustomSectionNames[_categoryName] ?? const <String>[];

  String _sectionDisplayName(String name) =>
      name.trim().isEmpty ? 'New Section' : name.trim();

  int _sectionIndexForCurrentEvent() {
    if (widget.initial == null) return 0;
    final eventId = widget.initial!.id;
    final eventSections = _dcvCustomSectionEventIds[_categoryName];
    if (eventSections == null) return 0;
    final index = eventSections.indexWhere((ids) => ids.contains(eventId));
    if (index < 0 || index >= _currentSectionNames.length) return 0;
    return index;
  }

  void _syncSectionRowAnimation({required bool animate}) {
    final shouldShow = _currentSectionNames.isNotEmpty;
    final target = shouldShow ? 1.0 : 0.0;
    if (!animate) {
      _renderedSectionNames = List<String>.of(_currentSectionNames);
      _sectionRowCtrl.value = target;
      return;
    }
    if (shouldShow) {
      _renderedSectionNames = List<String>.of(_currentSectionNames);
    }
    _sectionRowCtrl
        .animateTo(
          target,
          curve: target == 1.0 ? Curves.easeOut : Curves.easeIn,
        )
        .then((_) {
          if (!mounted || shouldShow || _currentSectionNames.isNotEmpty) return;
          setState(() => _renderedSectionNames = const <String>[]);
        });
  }

  List<ActionItem> _sectionItems() {
    final names = _renderedSectionNames;
    return [
      for (var index = 0; index < names.length; index++)
        ActionItem(
          label: _sectionDisplayName(names[index]),
          icon: SFIcons.sf_circle,
          iconBuilder: (_) => const SizedBox.shrink(),
          checkmark: index == _selectedSectionIndex,
          checkmarkColor: _resolvedCategoryColor,
          onTap: () {
            setState(() => _selectedSectionIndex = index);
            Future.delayed(
              const Duration(milliseconds: 80),
              _dismissPickerOverlay,
            );
          },
        ),
    ];
  }

  Widget _buildSectionRow() {
    final names = _renderedSectionNames;
    if (names.isEmpty) return const SizedBox.shrink();
    final safeIndex = _selectedSectionIndex.clamp(0, names.length - 1).toInt();
    final label = names.length == 1 ? 'Section' : 'Sections';
    return _pickerRow(
      label,
      _sectionDisplayName(names[safeIndex]),
      items: _sectionItems(),
    );
  }

  // ── Generic picker-item factory ───────────────────────────────────────────

  List<ActionItem> _makeItems(
    List<String> options,
    String current,
    void Function(String) onSelect, {
    Set<String> groupBreakBefore = const {},
    Color? checkmarkColor,
  }) => options
      .map(
        (label) => ActionItem(
          label: label,
          icon: SFIcons.sf_circle,
          iconBuilder: (_) => const SizedBox.shrink(),
          checkmark: label == current,
          checkmarkColor: checkmarkColor,
          groupBreakAbove: groupBreakBefore.contains(label),
          onTap: () {
            onSelect(label);
            Future.delayed(
              const Duration(milliseconds: 80),
              _dismissPickerOverlay,
            );
          },
        ),
      )
      .toList();

  // ── Category items (no None; Uncategorized is first) ─────────────────────

  List<ActionItem> _categoryItems() {
    // _loadCategories always supplies the built-in Unnamed fallback, while
    // preserving a persisted record when one exists (for its saved colour).
    final unnamed = _standardCategories.where((cat) => cat.name == 'Unnamed');
    final remaining = _standardCategories.where((cat) => cat.name != 'Unnamed');
    final items = <ActionItem>[];

    /// Reconstruct a _NewEventCustomRepeatConfig from the serialised map
    /// stored in _NewEventCategory.presetCustomRepeatConfig.
    _NewEventCustomRepeatConfig? _configFromMap(Map<String, dynamic>? m) {
      if (m == null) return null;
      return _NewEventCustomRepeatConfig(
        frequency: (m['frequency'] as String?) ?? 'Daily',
        everyCount: (m['everyCount'] as int?) ?? 1,
        selectedDays: Set<String>.from(
          (m['selectedDays'] as List?)?.cast<String>() ?? [],
        ),
        monthlyMode: (m['monthlyMode'] as String?) ?? 'Each',
        selectedDates: Set<int>.from(
          (m['selectedDates'] as List?)?.cast<int>() ?? [],
        ),
        onThePositionIndex: (m['onThePositionIndex'] as int?) ?? 0,
        onTheDayIndex: (m['onTheDayIndex'] as int?) ?? 0,
        selectedMonths: Set<int>.from(
          (m['selectedMonths'] as List?)?.cast<int>() ?? [],
        ),
        yearlyDaysEnabled: (m['yearlyDaysEnabled'] as bool?) ?? false,
        yearlyPositionIndex: (m['yearlyPositionIndex'] as int?) ?? 0,
        yearlyDayIndex: (m['yearlyDayIndex'] as int?) ?? 0,
      );
    }

    /// Apply a category's preset values to the sheet state and sync all
    /// dependent animation controllers.
    void _applyPreset(_NewEventCategory cat) {
      _locationTextCtrl.text = cat.presetLocation ?? '';
      _destCtrl.text = cat.presetDestination ?? '';
      _travelTime = cat.presetTravelTime ?? 'None';
      _travelMode = cat.presetTravelMode ?? 'None';
      _repeat = cat.presetRepeat ?? 'Never';
      _savedCustomConfig = _configFromMap(cat.presetCustomRepeatConfig);
      _endRepeat = cat.presetRepeatEndType ?? 'Never';
      final presetAlerts = _normaliseAlertState(
        cat.presetAlerts ?? [cat.presetAlert, cat.presetSecondAlert],
      );
      _alerts = presetAlerts.isEmpty ? ['At time of event'] : presetAlerts;
    }

    ActionItem itemFor(_NewEventCategory cat) => ActionItem(
      label: cat.name,
      icon: CupertinoIcons.circle_fill,
      iconBuilder: (_) => Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: renderCategoryColor(cat.color, context),
          shape: BoxShape.circle,
        ),
      ),
      checkmark: _categoryId == cat.id,
      checkmarkColor: renderCategoryColor(cat.color, context),
      onTap: () {
        setState(() {
          _categoryId = cat.id;
          _categoryName = cat.name;
          _categoryColor = cat.color;
          _selectedSectionIndex = 0;
          _applyPreset(cat);
        });
        _syncSectionRowAnimation(animate: true);
        // Sync animation controllers to the newly applied preset state.
        _travelModeCtrl.animateTo(
          _travelTime != 'None' ? 1.0 : 0.0,
          curve: Curves.easeOut,
        );
        _endRepeatCtrl.animateTo(
          _repeat != 'Never' ? 1.0 : 0.0,
          curve: Curves.easeOut,
        );
        _endDateCtrl.animateTo(
          _endRepeat == 'On Date' ? 1.0 : 0.0,
          curve: Curves.easeOut,
        );
        // Second alert row is visible whenever there is a primary alert
        // (so the user can optionally add a second one).
        _secondAlertCtrl.animateTo(
          _alert != 'None' ? 1.0 : 0.0,
          curve: Curves.easeOut,
        );
        _pickerEntry?.markNeedsBuild();
        _dismissPickerOverlay();
      },
    );

    items.addAll(unnamed.map(itemFor));
    if (_hasUncategorized) {
      items.add(
        ActionItem(
          label: 'Uncategorized',
          icon: CupertinoIcons.circle_fill,
          iconBuilder: (_) => Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: renderCategoryColor(_uncategorizedColor, context),
              shape: BoxShape.circle,
            ),
          ),
          checkmark: _categoryId == 'uncategorized',
          checkmarkColor: renderCategoryColor(_uncategorizedColor, context),
          onTap: () {
            setState(() {
              _categoryId = 'uncategorized';
              _categoryName = 'Uncategorized';
              _categoryColor = _uncategorizedColor;
              _selectedSectionIndex = 0;
              // Apply system defaults — every category, including Uncategorized,
              // defaults the alert to "At time of event".
              _applyPreset(
                _NewEventCategory(
                  id: 'uncategorized',
                  name: 'Uncategorized',
                  color: _uncategorizedColor,
                  // no preset fields → all fallbacks in _applyPreset apply
                ),
              );
            });
            _syncSectionRowAnimation(animate: true);
            _travelModeCtrl.animateTo(0.0, curve: Curves.easeIn);
            _endRepeatCtrl.animateTo(0.0, curve: Curves.easeIn);
            _endDateCtrl.animateTo(0.0, curve: Curves.easeIn);
            // Alert defaults to 'At time of event' → second alert row stays visible.
            _secondAlertCtrl.animateTo(1.0, curve: Curves.easeOut);
            _pickerEntry?.markNeedsBuild();
            _dismissPickerOverlay();
          },
        ),
      );
    }
    items.addAll(remaining.map(itemFor));
    return items;
  }

  // ── Open Maps helper ──────────────────────────────────────────────────────

  Future<void> _openMaps(String query) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1'
      '&query=${Uri.encodeComponent(query.isEmpty ? 'location' : query)}',
    );
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  // ── Location row (identical to _AddCategorySheetState._locationRow) ───────
  // Animated placeholder + CupertinoTextField + fade-through trailing action.
  // Cursor / selection / pin circle use _categoryColor so they track the
  // current category selection.

  Widget _locationRow(
    TextEditingController ctrl,
    String hint,
    FocusNode focusNode,
    String trailKeyPrefix,
    ScrollController scrollController,
  ) => Row(
    children: [
      Expanded(
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            HorizontalEdgeFade(
              fadeColor: resolveThemeColor(kModalCard, context),
              fadeOnRubberbandWhenContentFits: true,
              leadingInset: kHorizontalFadeEdgeGap,
              trailingInset: _locationClearFieldGap(),
              placeholderText: hint,
              placeholderTextStyle: _kPlaceholderStyle,
              placeholderFocusNode: focusNode,
              controller: ctrl,
              scrollController: scrollController,
              child: CupertinoTheme(
                data: CupertinoTheme.of(context).copyWith(
                  primaryColor: renderCategoryColor(_categoryColor, context),
                ),
                child: DefaultSelectionStyle(
                  selectionColor: renderCategoryColor(
                    _categoryColor,
                    context,
                  ).withOpacity(0.20),
                  child: trackTextFieldPointerDown(
                    focusNode: focusNode,
                    child: CupertinoTextField(
                    controller: ctrl,
                    focusNode: focusNode,
                    scrollController: scrollController,
                    placeholder: '',
                    placeholderStyle: _kPlaceholderStyle,
                    style: _kLabelStyle,
                    cursorColor: renderCategoryColor(_categoryColor, context),
                    padding: EdgeInsets.only(
                      left: kHorizontalFadeEdgeGap,
                      right: _locationClearFieldGap(),
                      top: 14,
                      bottom: 14,
                    ),
                    clearButtonMode: OverlayVisibilityMode.never,
                    scrollPhysics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    onChanged: (_) => setState(() {}),
                    textCapitalization: TextCapitalization.sentences,
                    decoration: null,
                    textInputAction: TextInputAction.next,
                    onTap: () {
                      if (shouldMoveTextFieldCaretToEnd(focusNode)) {
                        scheduleTextFieldCaretToEnd(
                          ctrl,
                          scrollController: scrollController,
                          isMounted: () => mounted,
                        );
                      }
                    },
                  ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      Padding(
        padding: const EdgeInsets.only(right: kModalRowHorizontalInset),
        child: _buildLocationTrailingAction(ctrl, trailKeyPrefix),
      ),
    ],
  );

  double _locationClearFieldGap() {
    final mapPinSize = MediaQuery.textScalerOf(context).scale(28);
    final clearIconSize = scaledSearchIconSize(context, 17);
    final actionSize = math.max(mapPinSize, clearIconSize);
    final clearIconLeadingInset = (actionSize - clearIconSize) / 2;
    return math.max(
      0.0,
      kHorizontalFadeContentGap - clearIconLeadingInset,
    );
  }

  Widget _buildLocationTrailingAction(
    TextEditingController ctrl,
    String prefix,
  ) {
    final hasText = ctrl.text.isNotEmpty;
    final mapPinSize = MediaQuery.textScalerOf(context).scale(28);
    final clearIconSize = scaledSearchIconSize(context, 17);
    final actionSize = math.max(mapPinSize, clearIconSize);
    return SizedBox(
      width: actionSize,
      height: actionSize,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.centerRight,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        ),
        transitionBuilder: (child, animation) =>
            FadeTransition(opacity: animation, child: child),
        child: hasText
            ? SizedBox(
                key: ValueKey('$prefix-clear'),
                width: actionSize,
                height: actionSize,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    ctrl.clear();
                    setState(() {});
                  },
                  child: Align(
                    // Center the smaller clear icon in the same action slot as
                    // the map pin. _locationClearFieldGap() measures this
                    // visual leading inset so the fade ends 8 px before it.
                    alignment: Alignment.center,
                    child: Icon(
                      kSearchClearCircleIcon,
                      color: kEmptyStateIcon,
                      size: clearIconSize,
                    ),
                  ),
                ),
              )
            : SizedBox(
                key: ValueKey('$prefix-pin'),
                width: actionSize,
                height: actionSize,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => _openMaps(ctrl.text),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      width: mapPinSize,
                      height: mapPinSize,
                      decoration: BoxDecoration(
                        color: _resolvedCategoryColor,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: FixedSFIcon(
                          SFIcons.sf_mappin,
                          fontSize: mapPinSize * (17 / 28),
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  // ── Travel helpers ────────────────────────────────────────────────────────

  void _setTravelTime(String v) {
    setState(() {
      _travelTime = v;
      if (v == 'None') _travelMode = 'None';
    });
    if (v == 'None') {
      _travelModeCtrl.animateTo(0.0, curve: Curves.easeIn);
    } else {
      _travelModeCtrl.animateTo(1.0, curve: Curves.easeOut);
    }
  }

  List<ActionItem> _travelTimeItems() => _makeItems(
    [
      'None',
      '5 minutes',
      '10 minutes',
      '15 minutes',
      '30 minutes',
      '1 hour',
      '1 hour, 30 minutes',
      '2 hours',
    ],
    _travelTime,
    _setTravelTime,
    groupBreakBefore: {'5 minutes'},
    checkmarkColor: _resolvedCategoryColor,
  );

  List<ActionItem> _travelModeItems() => _makeItems(
    ['None', 'Motorcycle', 'Car', 'Walking', 'Transit', 'Cycling'],
    _travelMode,
    (v) => setState(() => _travelMode = v),
    groupBreakBefore: {'Motorcycle'},
    checkmarkColor: _resolvedCategoryColor,
  );

  // ── Location section (Card 3): Starting Location + Destination + Travel ───

  Widget _buildLocationSection() => AnimatedBuilder(
    animation: Listenable.merge([_travelModeCtrl, _travelRowCtrl]),
    builder: (ctx, _) => _card([
      _locationRow(
        _locationTextCtrl,
        'Starting Location',
        _locationFocus,
        'start',
        _locationScrollCtrl,
      ),
      _sep(),
      _locationRow(
        _destCtrl,
        'Destination',
        _destFocus,
        'dest',
        _destScrollCtrl,
      ),
      // Travel Time row collapses when All-day is on.
      SizeTransition(
        sizeFactor: _travelRowCtrl,
        axisAlignment: 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sep(),
            _pickerRow('Travel Time', _travelTime, items: _travelTimeItems()),
          ],
        ),
      ),
      // Travel Mode stays in this same card as Travel Time.
      SizeTransition(
        sizeFactor: _travelModeCtrl,
        axisAlignment: 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sep(),
            _pickerRow('Travel Mode', _travelMode, items: _travelModeItems()),
          ],
        ),
      ),
    ]),
  );

  // ── Repeat helpers ────────────────────────────────────────────────────────

  Future<void> _setRepeat(String v) async {
    if (v == 'Custom') {
      final result =
          await showRoundedCupertinoSheet<_NewEventCustomRepeatResult?>(
            context: context,
            pageBuilder: (ctx) => _NewEventCustomRepeatSheet(
              accentColor: _resolvedCategoryColor,
              config: _savedCustomConfig,
            ),
          );
      if (result != null && mounted) {
        setState(() {
          _repeat = result.label;
          _savedCustomConfig = result.config;
          _endRepeat = 'On Date';
        });
        _endRepeatCtrl.animateTo(1.0, curve: Curves.easeOut);
        _endDateCtrl.animateTo(1.0, curve: Curves.easeOut);
      }
      return;
    }
    _savedCustomConfig = null;
    if (v == 'Never') {
      final now = DateTime.now();
      setState(() {
        _repeat = v;
        _endRepeat = 'Never';
        _endDate = DateTime(now.year, now.month + 1, now.day);
        _calendarMonth = DateTime(now.year, now.month + 1);
        _calendarBarrelMode = false;
        _calendarDragOffset = 0.0;
      });
      _endRepeatCtrl.animateTo(0.0, curve: Curves.easeIn);
      _endDateCtrl.animateTo(0.0, curve: Curves.easeIn);
      _datePickerCtrl.animateTo(0.0, curve: Curves.easeIn);
    } else {
      setState(() {
        _repeat = v;
        _endRepeat = 'On Date';
      });
      _endRepeatCtrl.animateTo(1.0, curve: Curves.easeOut);
      _endDateCtrl.animateTo(1.0, curve: Curves.easeOut);
    }
  }

  void _setEndRepeat(String v) {
    if (v == 'Never') {
      final now = DateTime.now();
      setState(() {
        _endRepeat = v;
        _endDate = DateTime(now.year, now.month + 1, now.day);
        _calendarMonth = DateTime(now.year, now.month + 1);
        _calendarBarrelMode = false;
      });
      _endDateCtrl.animateTo(0.0, curve: Curves.easeIn);
      _datePickerCtrl.animateTo(0.0, curve: Curves.easeIn);
    } else {
      setState(() => _endRepeat = v);
      _endDateCtrl.animateTo(1.0, curve: Curves.easeOut);
    }
  }

  void _toggleDatePicker() {
    if (_datePickerCtrl.value > 0.5) {
      _datePickerCtrl.animateTo(0.0, curve: Curves.easeIn);
    } else {
      _datePickerCtrl.animateTo(1.0, curve: Curves.easeOut);
    }
  }

  List<ActionItem> _repeatItems() {
    const options = [
      'Never',
      'Every Day',
      'Every Week',
      'Every 2 Weeks',
      'Every Month',
      'Every Year',
      'Custom',
    ];
    final effectiveCurrent = options.contains(_repeat) ? _repeat : 'Custom';
    return _makeItems(
      options,
      effectiveCurrent,
      _setRepeat,
      groupBreakBefore: {'Custom'},
      checkmarkColor: _resolvedCategoryColor,
    );
  }

  List<ActionItem> _endRepeatItems() => _makeItems(
    ['Never', 'On Date'],
    _endRepeat,
    _setEndRepeat,
    checkmarkColor: _resolvedCategoryColor,
  );

  // ── Month-slide animation helpers (for inline End Date calendar) ──────────

  void _onMonthSlideUpdate() {
    if (_monthSlideTween == null) return;
    final t = Curves.easeInOut.transform(_monthSlideCtrl.value);
    setState(() {
      _calendarDragOffset =
          _monthSlideTween!.begin! +
          (_monthSlideTween!.end! - _monthSlideTween!.begin!) * t;
    });
  }

  void _commitMonthSlide({required bool next}) {
    if (_monthSlideTween != null) return;
    final target = next ? -_calPanelWidth : _calPanelWidth;
    _monthSlideTween = Tween<double>(begin: _calendarDragOffset, end: target);
    _monthSlideCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _calendarMonth = next
            ? DateTime(_calendarMonth.year, _calendarMonth.month + 1)
            : DateTime(_calendarMonth.year, _calendarMonth.month - 1);
        _calendarDragOffset = 0;
        _monthSlideTween = null;
      });
      _monthSlideCtrl.reset();
    });
  }

  void _snapBackMonthSlide() {
    _monthSlideTween = Tween<double>(begin: _calendarDragOffset, end: 0);
    _monthSlideCtrl.forward(from: 0).then((_) {
      if (!mounted) return;
      setState(() {
        _calendarDragOffset = 0;
        _monthSlideTween = null;
      });
      _monthSlideCtrl.reset();
    });
  }

  void _prevCalMonth() => _commitMonthSlide(next: false);
  void _nextCalMonth() => _commitMonthSlide(next: true);
  void _toggleBarrelMode() =>
      setState(() => _calendarBarrelMode = !_calendarBarrelMode);

  // ── End Date row ──────────────────────────────────────────────────────────

  static const _kRepeatMonthNames = [
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
  static const _kRepeatDayLabels = [
    'M',
    'T',
    'W',
    'T',
    'F',
    'S',
    'S',
  ];

  String _formatEndDate(DateTime d) =>
      '${_kRepeatMonthNames[d.month - 1]} ${d.day}, ${d.year}';

  Widget _buildEndDateRow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    child: AdaptiveLabelPillRow(
      label: 'End Date',
      labelStyle: _kLabelStyle,
      onLabelTap: _toggleDatePicker,
      pills: [
        AdaptivePillSpec(
          text: _formatEndDate(_endDate),
          compactText:
              '${_kRepeatMonthNames[_endDate.month - 1].substring(0, 3)} '
              '${_endDate.day}, ${_endDate.year}',
          backgroundColor: resolveThemeColor(kPillColor, context),
          style: TextStyle(
            inherit: false,
            color: _datePickerCtrl.value > 0
                ? _resolvedCategoryColor
                : resolveThemeColor(kPrimaryLabel, context),
            fontSize: 15,
            fontFamily: kSFProText,
            fontWeight: FontWeight.w500,
            letterSpacing: kTracking17,
          ),
          onTap: _toggleDatePicker,
        ),
      ],
    ),
  );

  // ── Month-grid cell builder (for the inline End Date calendar) ────────────

  Widget _buildEndDateMonthGrid({
    required int year,
    required int month,
    required DateTime today,
  }) {
    final startOffset = DateTime(year, month, 1).weekday - 1;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final isSelectedMonth = _endDate.year == year && _endDate.month == month;
    final isCurrentMonth = today.year == year && today.month == month;
    final gridScale = textScaleRatioFor(context, 15.0);
    final gridCircleSize = 30.0 * gridScale;
    final gridRowHeight = 38.0 * gridScale;
    final Color todayFill = _resolvedCategoryColor.withOpacity(0.40);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          6,
          (row) => Row(
            children: List.generate(7, (col) {
              final day = row * 7 + col - startOffset + 1;
              if (day < 1 || day > daysInMonth) {
                return Expanded(child: SizedBox(height: gridRowHeight));
              }
              final selected = isSelectedMonth && _endDate.day == day;
              final isToday = isCurrentMonth && today.day == day;
              final isPast = DateTime(
                year,
                month,
                day,
              ).isBefore(DateTime(today.year, today.month, today.day));

              final Widget circle;
              if (selected) {
                circle = Container(
                  width: gridCircleSize,
                  height: gridCircleSize,
                  decoration: BoxDecoration(
                    color: _resolvedCategoryColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      inherit: false,
                      color: Color(0xFFFFFFFF),
                      fontSize: 15,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w600,
                      letterSpacing: kTracking17,
                    ),
                  ),
                );
              } else if (isToday) {
                circle = Container(
                  width: gridCircleSize,
                  height: gridCircleSize,
                  decoration: BoxDecoration(
                    color: todayFill,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      inherit: false,
                      color: Color(0xFFFFFFFF),
                      fontSize: 15,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w500,
                      letterSpacing: kTracking17,
                    ),
                  ),
                );
              } else if (isPast) {
                circle = Container(
                  width: gridCircleSize,
                  height: gridCircleSize,
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      inherit: false,
                      color: resolveThemeColor(kTertiaryLabel, context),
                      fontSize: 15,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w400,
                      letterSpacing: kTracking17,
                    ),
                  ),
                );
              } else {
                circle = Container(
                  width: gridCircleSize,
                  height: gridCircleSize,
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      inherit: false,
                      color: resolveThemeColor(kPrimaryLabel, context),
                      fontSize: 15,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w400,
                      letterSpacing: kTracking17,
                    ),
                  ),
                );
              }

              if (isPast) {
                return Expanded(
                  child: SizedBox(
                    height: gridRowHeight,
                    child: Center(child: circle),
                  ),
                );
              }
              return Expanded(
                child: GelBloomButton(
                  onTap: () {
                    setState(() => _endDate = DateTime(year, month, day));
                    _datePickerCtrl.animateTo(0.0, curve: Curves.easeIn);
                  },
                  peakScale: 1.15,
                  child: SizedBox(
                    height: gridRowHeight,
                    child: Center(child: circle),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _buildEndDateMonthPanelHeader(
    DateTime month,
    DateTime today, {
    required bool isCenter,
  }) {
    final isCurrent = month.year == today.year && month.month == today.month;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isCenter ? _toggleBarrelMode : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_kRepeatMonthNames[month.month - 1]} ${month.year}',
                  style: TextStyle(
                    inherit: false,
                    color: isCurrent
                        ? _resolvedCategoryColor
                        : resolveThemeColor(kPrimaryLabel, context),
                    fontSize: 17,
                    fontFamily: kSFProText,
                    fontWeight: FontWeight.w600,
                    letterSpacing: kTracking17,
                  ),
                ),
                const SizedBox(width: 5),
                AnimatedRotation(
                  turns: _calendarBarrelMode ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 13,
                    color: _resolvedCategoryColor,
                    shadows: resolveThemeTextShadows([
                      Shadow(color: _resolvedCategoryColor, blurRadius: 0.8),
                    ], context),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Visibility(
            visible: !_calendarBarrelMode,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isCenter ? _prevCalMonth : null,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      CupertinoIcons.chevron_left,
                      size: 16,
                      color: _resolvedCategoryColor,
                      shadows: resolveThemeTextShadows([
                        Shadow(color: _resolvedCategoryColor, blurRadius: 0.8),
                      ], context),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isCenter ? _nextCalMonth : null,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: _resolvedCategoryColor,
                      shadows: resolveThemeTextShadows([
                        Shadow(color: _resolvedCategoryColor, blurRadius: 0.8),
                      ], context),
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

  Widget _buildEndDateMonthPanel(
    DateTime month,
    DateTime today, {
    required bool isCenter,
    bool showHeader = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader)
          _buildEndDateMonthPanelHeader(month, today, isCenter: isCenter),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: _kRepeatDayLabels
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          inherit: false,
                          color: resolveThemeColor(kSecondaryLabel, context),
                          fontSize: 11,
                          fontFamily: kSFProText,
                          fontWeight: FontWeight.w500,
                          letterSpacing: kTracking17,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 2),
        _buildEndDateMonthGrid(
          year: month.year,
          month: month.month,
          today: today,
        ),
      ],
    );
  }

  Widget _buildInlineMonthPicker() {
    final today = DateTime.now();
    final prevMonth = DateTime(_calendarMonth.year, _calendarMonth.month - 1);
    final nextMonth = DateTime(_calendarMonth.year, _calendarMonth.month + 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildEndDateMonthPanelHeader(_calendarMonth, today, isCenter: true),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: _calendarBarrelMode
                ? SizedBox(
                    height: cupertinoDatePickerHeight(context),
                    child: CupertinoTheme(
                      data: CupertinoTheme.of(context).copyWith(
                        primaryColor: _resolvedCategoryColor,
                        textTheme: CupertinoTheme.of(context).textTheme
                            .copyWith(
                              dateTimePickerTextStyle: TextStyle(
                                inherit: false,
                                fontFamily: kSFProText,
                                fontSize: cupertinoDatePickerFontSize(context),
                                color: resolveThemeColor(
                                  kPrimaryLabel,
                                  context,
                                ),
                                letterSpacing: kTracking17,
                              ),
                            ),
                      ),
                      child: CupertinoDatePicker(
                        itemExtent: cupertinoDatePickerItemExtent(context),
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: _endDate,
                        minimumDate: DateTime(
                          today.year,
                          today.month,
                          today.day,
                        ),
                        onDateTimeChanged: (dt) => setState(() {
                          _endDate = dt;
                          _calendarMonth = DateTime(dt.year, dt.month);
                        }),
                      ),
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) {
                      if (_monthSlideTween != null) return;
                      setState(() => _calendarDragOffset = 0.0);
                    },
                    onHorizontalDragUpdate: (d) {
                      if (_monthSlideTween != null) return;
                      setState(() => _calendarDragOffset += d.delta.dx);
                    },
                    onHorizontalDragEnd: (d) {
                      if (_monthSlideTween != null) return;
                      final v = d.primaryVelocity ?? 0;
                      if (v < -200 || _calendarDragOffset < -40) {
                        _commitMonthSlide(next: true);
                      } else if (v > 200 || _calendarDragOffset > 40) {
                        _commitMonthSlide(next: false);
                      } else {
                        _snapBackMonthSlide();
                      }
                    },
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        _calPanelWidth = constraints.maxWidth;
                        return ClipRect(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: OverflowBox(
                                    alignment: Alignment.topLeft,
                                    maxHeight: double.infinity,
                                    child: Transform.translate(
                                      offset: Offset(
                                        -_calPanelWidth + _calendarDragOffset,
                                        0,
                                      ),
                                      child: SizedBox(
                                        width: _calPanelWidth,
                                        child: _buildEndDateMonthPanel(
                                          prevMonth,
                                          today,
                                          isCenter: false,
                                          showHeader: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: OverflowBox(
                                    alignment: Alignment.topLeft,
                                    maxHeight: double.infinity,
                                    child: Transform.translate(
                                      offset: Offset(
                                        _calPanelWidth + _calendarDragOffset,
                                        0,
                                      ),
                                      child: SizedBox(
                                        width: _calPanelWidth,
                                        child: _buildEndDateMonthPanel(
                                          nextMonth,
                                          today,
                                          isCenter: false,
                                          showHeader: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(_calendarDragOffset, 0),
                                child: SizedBox(
                                  width: _calPanelWidth,
                                  child: _buildEndDateMonthPanel(
                                    _calendarMonth,
                                    today,
                                    isCenter: true,
                                    showHeader: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Repeat section (Card 4) ───────────────────────────────────────────────

  Widget _buildRepeatSection() => AnimatedBuilder(
    animation: Listenable.merge([
      _endRepeatCtrl,
      _endDateCtrl,
      _datePickerCtrl,
    ]),
    builder: (ctx, _) => _card([
      _pickerRow('Repeat', _repeat, items: _repeatItems()),
      SizeTransition(
        sizeFactor: _endRepeatCtrl,
        axisAlignment: 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sep(),
            _pickerRow('End Repeat', _endRepeat, items: _endRepeatItems()),
            SizeTransition(
              sizeFactor: _endDateCtrl,
              axisAlignment: 1.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _sep(),
                  _buildEndDateRow(),
                  SizeTransition(
                    sizeFactor: _datePickerCtrl,
                    axisAlignment: 1.0,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [_sep(), _buildInlineMonthPicker()],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ]),
  );

  // ── Alert helpers ─────────────────────────────────────────────────────────

  // When Travel Time ≠ 'None', alert labels transform to "…before travel time"
  // and "At start of travel time".  Base labels (state keys) never change.
  String _alertDisplayLabel(String base) {
    if (_travelTime == 'None' || base == 'None') return base;
    if (base == 'At time of event') return 'At start of travel time';
    return '$base travel time';
  }

  List<ActionItem> _buildAlertActionItems(
    List<String> visibleBase,
    String current,
    void Function(String base) onSelect, {
    Set<String> groupBreakBefore = const {},
    Color? checkmarkColor,
  }) => visibleBase
      .map(
        (base) => ActionItem(
          label: _alertDisplayLabel(base),
          icon: SFIcons.sf_circle,
          iconBuilder: (_) => const SizedBox.shrink(),
          checkmark: base == current,
          checkmarkColor: checkmarkColor,
          groupBreakAbove: groupBreakBefore.contains(base),
          onTap: () {
            onSelect(base);
            Future.delayed(
              const Duration(milliseconds: 80),
              _dismissPickerOverlay,
            );
          },
        ),
      )
      .toList();

  List<ActionItem> _alertItems() {
    return _alertItemsFor(0);
  }

  List<ActionItem> _alertItemsFor(int index) {
    final list = _allDay ? _kAlertAllDayBase : _kAlertAllBase;
    final breakBefore = _allDay
        ? {'Night before (9 PM)'}
        : {'At time of event'};
    final current = index < _alerts.length ? _alerts[index] : 'None';
    final previousMinutes = index == 0 || index > _alerts.length
        ? -1
        : _kAlertMinutes[_alerts[index - 1]] ?? -1;
    final visible = list.where((base) {
      final minutes = _kAlertMinutes[base] ?? -1;
      return index == 0 ||
          base == 'None' ||
          previousMinutes == -1 ||
          minutes < previousMinutes;
    }).toList();
    return _buildAlertActionItems(
      visible,
      current,
      (base) {
        setState(() {
          _selectAlert(index, base);
        });
        if (index == 0 && base == 'None') {
          _secondAlertCtrl.animateTo(0.0, curve: Curves.easeIn);
        } else if (index == 0) {
          _secondAlertCtrl.animateTo(1.0, curve: Curves.easeOut);
        }
      },
      groupBreakBefore: breakBefore,
      checkmarkColor: _resolvedCategoryColor,
    );
  }

  void _selectAlert(int index, String base) {
    final list = _allDay ? _kAlertAllDayBase : _kAlertAllBase;
    if (base == 'None') {
      if (_alerts.length > index) {
        _alerts.removeRange(index, _alerts.length);
      }
      return;
    }
    while (_alerts.length <= index) {
      _alerts.add(base);
    }
    _alerts[index] = base;

    // A change to an earlier row may invalidate later selections. Keep the
    // valid prefix and remove the invalid tail rather than leaving an alert
    // that the picker can no longer select.
    var previousMinutes = _kAlertMinutes[base] ?? -1;
    var cursor = index + 1;
    while (cursor < _alerts.length) {
      final candidate = _alerts[cursor];
      final candidateMinutes = _kAlertMinutes[candidate];
      if (candidateMinutes == null ||
          candidateMinutes >= previousMinutes ||
          _alerts.sublist(0, cursor).contains(candidate)) {
        _alerts.removeRange(cursor, _alerts.length);
        break;
      }
      previousMinutes = candidateMinutes;
      cursor++;
    }
    assert(AlertSequence.isValid(_alerts, _kAlertMinutes));
    // Keep only options present in this mode's picker after a mode switch.
    // The first row is always valid when it was selected from the same list.
    if (_alerts.any((value) => !list.contains(value))) {
      _alerts.removeWhere((value) => !list.contains(value));
    }
  }

  Widget _buildAnimatedAlertRow(int index) {
    final visible = index <= _alerts.length;
    return AnimatedSize(
      key: ValueKey('alert-row-$index'),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: visible
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [_sep(), _buildAnimatedAlertPickerRow(index)],
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildAnimatedAlertPickerRow(int index) {
    final label = _allDay
        ? _alertRowLabel(index).replaceFirst('Alert', 'Reminder')
        : _alertRowLabel(index);
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      clipBehavior: Clip.hardEdge,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 260),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SizeTransition(
            sizeFactor: animation,
            axis: Axis.vertical,
            axisAlignment: -1.0,
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(label),
          child: _pickerRow(
            label,
            _alertDisplayLabel(
              index < _alerts.length ? _alerts[index] : 'None',
            ),
            items: _alertItemsFor(index),
          ),
        ),
      ),
    );
  }

  // ── Attachment rows (Card 7) ──────────────────────────────────────────────

  static const _kImageExts = {
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'heic',
    'heif',
    'bmp',
    'tiff',
    'tif',
  };

  static const _kRecurringAttachmentFooter =
      'Attachments will be applied to all recurrences';

  /// "Add attachment…" row — always at the bottom of Card 7.
  ///
  /// [DropRegion] is a native drop target rather than Flutter's [DragTarget],
  /// so it can receive files dragged from Files, a desktop file manager, or
  /// another app. The tap path remains the existing file picker.
  Widget _buildAttachmentRow() {
    return DropRegion(
      formats: Formats.standardFormats,
      hitTestBehavior: HitTestBehavior.opaque,
      onDropOver: _onAttachmentDropOver,
      onDropEnter: (_) => _setAttachmentDropHovered(true),
      onDropLeave: (_) => _setAttachmentDropHovered(false),
      onDropEnded: (_) => _setAttachmentDropHovered(false),
      onPerformDrop: _onAttachmentDrop,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _pickAndImport,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _attachmentDropCtrl,
            _attachmentConsumeCtrl,
          ]),
          builder: (context, _) {
            final hoverProgress = _attachmentDropCtrl.value.clamp(0.0, 1.0);
            final consumeProgress = _attachmentConsumeCtrl.value.clamp(
              0.0,
              1.0,
            );
            // A drop feels like the row briefly catches and settles the item.
            // It deliberately does not alter color, label, or add an overlay.
            final reaction = math.max(hoverProgress, consumeProgress);
            return Transform.translate(
              offset: Offset(0, reaction * 1.5),
              child: Transform.scale(
                scale: 1.0 - reaction * 0.025,
                alignment: Alignment.center,
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                    child: Text('Add attachment\u2026', style: _kLabelStyle),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  bool _dropItemHasFile(DropItem item) {
    if (item.canProvide(Formats.fileUri)) return true;
    return Formats.standardFormats.whereType<FileFormat>().any(item.canProvide);
  }

  FutureOr<DropOperation> _onAttachmentDropOver(DropOverEvent event) {
    final canAccept = event.session.items.any(_dropItemHasFile);
    if (canAccept &&
        event.session.allowedOperations.contains(DropOperation.copy)) {
      return DropOperation.copy;
    }
    return DropOperation.none;
  }

  void _setAttachmentDropHovered(bool hovered) {
    if (!mounted ||
        _readingAttachmentDrop ||
        hovered == _attachmentDropHovered) {
      return;
    }
    _attachmentDropHovered = hovered;
    if (hovered) {
      HapticFeedback.lightImpact();
      _attachmentDropCtrl.forward();
    } else {
      _attachmentDropCtrl.reverse();
    }
  }

  Future<List<PlatformFile>> _readDroppedAttachments(
    PerformDropEvent event,
  ) async {
    final dropped = <PlatformFile>[];
    for (final item in event.session.items) {
      if (!_dropItemHasFile(item)) continue;
      final reader = item.dataReader;
      if (reader == null) continue;

      // Some Android drag providers expose a content:// URI without putting
      // the display name on DataReaderFile. Read the URI name before consuming
      // the file so the row can preserve the source filename.
      String? uriName;
      if (reader.canProvide(Formats.fileUri)) {
        final uriCompleter = Completer<Uri?>();
        final uriProgress = reader.getValue<Uri>(
          Formats.fileUri,
          (uri) async {
            if (!uriCompleter.isCompleted) uriCompleter.complete(uri);
          },
          onError: (_) {
            if (!uriCompleter.isCompleted) uriCompleter.complete(null);
          },
        );
        if (uriProgress != null) {
          final uri = await uriCompleter.future;
          if (uri != null && uri.pathSegments.isNotEmpty) {
            final lastSegment = Uri.decodeComponent(uri.pathSegments.last);
            if (lastSegment.trim().isNotEmpty) uriName = lastSegment;
          }
        }
      }

      final fileFormats = reader
          .getFormats(Formats.standardFormats)
          .whereType<FileFormat>()
          .toList(growable: false);
      final format = fileFormats.isEmpty ? null : fileFormats.first;
      final completer = Completer<PlatformFile?>();

      void complete(PlatformFile? file) {
        if (!completer.isCompleted) completer.complete(file);
      }

      final progress = reader.getFile(format, (dataFile) async {
        try {
          final bytes = await dataFile.readAll();
          final suggestedName = await reader.getSuggestedName();
          final name =
              _usableDroppedFileName(dataFile.fileName) ??
              _usableDroppedFileName(suggestedName) ??
              _usableDroppedFileName(uriName) ??
              'Attachment';
          complete(PlatformFile(name: name, size: bytes.length, bytes: bytes));
        } catch (_) {
          complete(null);
        }
      }, onError: (_) => complete(null));
      if (progress == null) complete(null);

      final file = await completer.future;
      if (file != null) dropped.add(file);
    }
    return dropped;
  }

  /// Reject names emitted by drag providers as placeholders. Smart Hub can
  /// expose "DROP" as a drag label rather than the source file name.
  String? _usableDroppedFileName(String? value) {
    final name = value?.trim();
    if (name == null || name.isEmpty) return null;
    final normalized = name.toLowerCase();
    if (normalized == 'drop' ||
        normalized == 'dropped attachment' ||
        normalized == 'dropped file') {
      return null;
    }
    return name;
  }

  Future<void> _onAttachmentDrop(PerformDropEvent event) async {
    if (_readingAttachmentDrop || !mounted) return;
    _readingAttachmentDrop = true;
    await _attachmentDropCtrl.forward();

    final files = await _readDroppedAttachments(event);
    if (!mounted) return;
    if (files.isEmpty) {
      _readingAttachmentDrop = false;
      await _attachmentDropCtrl.reverse();
      return;
    }

    HapticFeedback.mediumImpact();
    // Briefly press and release the row, then start the existing importing
    // sheet directly. There is no intermediate confirmation overlay.
    _attachmentConsumeCtrl.value = 0.0;
    await _attachmentConsumeCtrl.forward();
    await _attachmentConsumeCtrl.reverse();
    if (!mounted) return;

    _readingAttachmentDrop = false;
    _attachmentDropHovered = false;
    await _attachmentDropCtrl.reverse();
    await _runImport(files);
  }

  /// One row per already-added attachment file.
  Widget _buildAttachmentFileRow(int index) {
    return _buildAttachmentFileRowForFile(
      _attachments[index],
      onRemove: () => _removeAttachment(index),
    );
  }

  Widget _buildAttachmentFileRowForFile(
    _AttachmentFile file, {
    VoidCallback? onRemove,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final double sq = textScaler.scale(32.0);
    final double sqR = sq * 0.52; // ContinuousRectangleBorder squircle radius
    final clearIconSize = scaledSearchIconSize(context, 18);

    Widget icon;
    if (file.isImage && file.bytes != null) {
      icon = ClipPath(
        clipper: ShapeBorderClipper(shape: const CircleBorder()),
        child: Container(
          width: sq,
          height: sq,
          child: Image.memory(
            file.bytes!,
            width: sq,
            height: sq,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) =>
                _fileIconBox(file.ext, sq, sqR, context: context),
          ),
        ),
      );
    } else {
      icon = _fileIconBox(file.ext, sq, sqR, context: context);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Padding(
        // The shared 32 px container has an even 8 px top and bottom inset.
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          // Center the filename baseline and remove action against the
          // thumbnail's 32 px row, matching the other single-line modal rows.
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            icon,
            const SizedBox(width: kHorizontalFadeEdgeGap),
            Expanded(
              child: _AttachmentFilename(
                key: ValueKey(file),
                name: file.name,
                style: _kLabelStyle,
                fadeColor: resolveThemeColor(kModalCard, context),
                scrollController: _attachmentScrollControllerFor(file),
              ),
            ),
            const SizedBox(width: kHorizontalFadeEdgeGap),
            SizedBox(
              width: clearIconSize,
              height: clearIconSize,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Icon(
                  kSearchClearCircleIcon,
                  color: kEmptyStateIcon,
                  size: clearIconSize,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _removeAttachment(int index) {
    if (index < 0 || index >= _attachments.length) return;
    final removedFile = _attachments.removeAt(index);
    final listState = _attachmentListKey.currentState;

    setState(() {});
    listState?.removeItem(
      index,
      (context, animation) => SizeTransition(
        sizeFactor: animation,
        axisAlignment: -1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [_buildAttachmentFileRowForFile(removedFile), _sep()],
        ),
      ),
      duration: const Duration(milliseconds: 280),
    );
    // Keep the removed row's controller alive until its SizeTransition has
    // finished using it, then release only that row's state.
    Future.delayed(const Duration(milliseconds: 280), () {
      final controller = _attachmentScrollControllers.remove(removedFile);
      if (controller != null) controller.dispose();
    });
  }

  Widget _fileIconBox(
    String ext,
    double sq,
    double sqR, {
    required BuildContext context,
  }) {
    final textScaler = MediaQuery.textScalerOf(context);
    final tileColor = resolveThemeColor(
      const CupertinoDynamicColor.withBrightness(
        color: Color(0xFFEAEAEA),
        darkColor: Color(0xFF3C3C3C),
      ),
      context,
    );
    return Container(
      width: sq,
      height: sq,
      decoration: ShapeDecoration(
        color: tileColor,
        shape: const CircleBorder(),
      ),
      alignment: Alignment.center,
      child: Text(
        ext.isEmpty ? '?' : ext.toUpperCase(),
        style: TextStyle(
          inherit: false,
          color: resolveThemeColor(kSecondaryLabel, context),
          fontSize: textScaler.scale(10),
          fontFamily: kSFProText,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
          height: 1.2,
        ),
        textScaler: TextScaler.noScaling,
        maxLines: 1,
        overflow: TextOverflow.clip,
      ),
    );
  }

  // ── File picker + simulated per-file import ───────────────────────────────

  void _showImportingOverlay() {
    _importOverlayEntry?.remove();
    _importOverlayEntry = OverlayEntry(
      builder: (ctx) => _buildImportingOverlay(ctx),
    );
    Overlay.of(context, rootOverlay: true).insert(_importOverlayEntry!);
  }

  void _removeImportingOverlay() {
    _importOverlayEntry?.remove();
    _importOverlayEntry = null;
  }

  Future<void> _pickAndImport() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty || !mounted) return;
    await _runImport(result.files);
  }

  // ── Actual import loop ────────────────────────────────────────────────────

  Future<void> _runImport(List<PlatformFile> files) async {
    if (files.isEmpty || !mounted) return;
    setState(() {
      _importingActive = true;
      _importTotal = files.length;
      _importRemaining = files.length;
      _importCancelled = false;
    });
    _importProgressCtrl.value = 0.0;
    _showImportingOverlay();

    final List<_AttachmentFile> newFiles = [];
    for (int i = 0; i < files.length; i++) {
      if (_importCancelled || !mounted) break;
      await Future.delayed(const Duration(milliseconds: 380));
      if (!mounted || _importCancelled) break;

      final pf = files[i];
      final ext = (pf.extension ?? _attachmentExtension(pf.name)).toLowerCase();
      final isImg = _kImageExts.contains(ext);
      newFiles.add(
        _AttachmentFile(
          name: pf.name,
          ext: ext,
          // Keep the original bytes for every file type. Previously this was
          // intentionally limited to images, which left document/audio/video
          // rows with no data to persist when the event was saved.
          bytes: pf.bytes,
          isImage: isImg,
          sourcePath: pf.path,
        ),
      );
      setState(() => _importRemaining = files.length - (i + 1));
      _importOverlayEntry?.markNeedsBuild();
      await _importProgressCtrl.animateTo(
        (i + 1) / files.length,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      if (!mounted) return;
    }
    if (!mounted) return;

    if (!_importCancelled) {
      await Future.delayed(const Duration(milliseconds: 450));
      if (!mounted) return;
      _removeImportingOverlay();
      final insertIndex = _attachments.length;
      setState(() {
        _attachments.addAll(newFiles);
        _importingActive = false;
      });
      final listState = _attachmentListKey.currentState;
      if (listState != null) {
        for (var i = 0; i < newFiles.length; i++) {
          listState.insertItem(
            insertIndex + i,
            duration: const Duration(milliseconds: 280),
          );
        }
      }
    } else {
      _removeImportingOverlay();
      setState(() => _importingActive = false);
    }
  }

  String _attachmentExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot <= 0 || dot == name.length - 1) return '';
    return name.substring(dot + 1);
  }

  void _cancelImport() {
    _removeImportingOverlay();
    setState(() {
      _importCancelled = true;
      _importingActive = false;
    });
  }

  // ── Importing progress overlay ────────────────────────────────────────────

  Widget _buildImportingOverlay(BuildContext context) {
    final catColor = _resolvedCategoryColor;
    final trackColor = CupertinoDynamicColor.resolve(kTertiaryLabel, context);
    final priColor = CupertinoDynamicColor.resolve(kPrimaryLabel, context);
    final secColor = CupertinoDynamicColor.resolve(kSecondaryLabel, context);
    final cardBg = CupertinoDynamicColor.resolve(kCardColor, context);
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    final n = _importTotal;
    final rem = _importRemaining;
    final title = 'Importing ${n == 1 ? 'one item' : '$n items'}';
    final subtitle = '${rem == 1 ? 'one item' : '$rem items'} remaining.';

    return Positioned.fill(
      child: ColoredBox(
        color: resolveThemeColor(kImportOverlayScrim, context),
        child: Center(
          child: Container(
            width: 270,
            decoration: ShapeDecoration(
              color: cardBg,
              shape: BoundedSquircleStadiumBorder(
                radius: kConfirmationSheetCornerRadius,
                side: isDark
                    ? BorderSide(
                        color: resolveThemeColor(kTertiaryLabel, context),
                        width: 0.5,
                      )
                    : BorderSide.none,
              ),
              shadows: resolveThemeShadows(kCardShadow, context),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: TextStyle(
                        inherit: false,
                        color: priColor,
                        fontSize: 17,
                        fontFamily: kSFProText,
                        fontWeight: FontWeight.w600,
                        letterSpacing: kTracking17,
                        height: kLineHeight,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      subtitle,
                      style: TextStyle(
                        inherit: false,
                        color: secColor,
                        fontSize: 15,
                        fontFamily: kSFProText,
                        fontWeight: FontWeight.w400,
                        letterSpacing: kTracking17,
                        height: kLineHeight,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                AnimatedBuilder(
                  animation: _importProgressCtrl,
                  builder: (_, __) => CustomPaint(
                    size: const Size(72, 72),
                    painter: _ImportProgressPainter(
                      progress: _importProgressCtrl.value,
                      trackColor: trackColor,
                      fillColor: catColor,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _cancelImport,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                      decoration: ShapeDecoration(
                        color: resolveThemeColor(kPillColor, context),
                        shape: const BoundedSquircleStadiumBorder(
                          radius: kConfirmationButtonCornerRadius,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          inherit: false,
                          color: priColor,
                          fontSize: 17,
                          fontFamily: kSFProText,
                          fontWeight: FontWeight.w500,
                          letterSpacing: kTracking17,
                          height: kLineHeight,
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
    );
  }

  // ── Reminder section (Card 6 alt — Unscheduled events only) ─────────────────

  List<ActionItem> _reminderPickerItems() {
    const opts = ['Never', 'On Date'];
    return opts
        .map(
          (opt) => ActionItem(
            label: opt,
            icon: SFIcons.sf_circle,
            iconBuilder: (_) => const SizedBox.shrink(),
            checkmark: _reminder == opt,
            checkmarkColor: _resolvedCategoryColor,
            onTap: () {
              setState(() => _reminder = opt);
              if (opt == 'On Date') {
                _reminderDateCtrl.animateTo(1.0, curve: Curves.easeOut);
              } else {
                _reminderDateCtrl.animateTo(0.0, curve: Curves.easeIn);
                // Also close the inline reminder picker if open.
                if (_activePicker == 'reminder' ||
                    _activePicker == 'reminder_time') {
                  _reminderPickerCtrl.value = 0.0;
                  setState(() => _activePicker = '');
                }
              }
              Future.delayed(
                const Duration(milliseconds: 80),
                _dismissPickerOverlay,
              );
            },
          ),
        )
        .toList();
  }

  Future<void> _setReminderRepeat(String value) async {
    if (value == 'Custom') {
      final result =
          await showRoundedCupertinoSheet<_NewEventCustomRepeatResult?>(
            context: context,
            pageBuilder: (ctx) => _NewEventCustomRepeatSheet(
              accentColor: _resolvedCategoryColor,
              config: _savedReminderCustomConfig,
              subjectLabel: 'Reminder',
            ),
          );
      if (result != null && mounted) {
        setState(() {
          _repeatReminder = result.label;
          _savedReminderCustomConfig = result.config;
        });
      }
      return;
    }

    setState(() {
      _repeatReminder = value;
      _savedReminderCustomConfig = null;
    });
  }

  List<ActionItem> _repeatReminderItems() {
    const opts = ['Never', 'Daily', 'Every 2 Days', 'Weekly', 'Custom'];
    final current = opts.contains(_repeatReminder) ? _repeatReminder : 'Custom';
    return opts
        .map(
          (opt) => ActionItem(
            label: opt,
            icon: SFIcons.sf_circle,
            iconBuilder: (_) => const SizedBox.shrink(),
            checkmark: current == opt,
            checkmarkColor: _resolvedCategoryColor,
            groupBreakAbove: opt == 'Custom',
            onTap: () {
              _setReminderRepeat(opt);
              Future.delayed(
                const Duration(milliseconds: 80),
                _dismissPickerOverlay,
              );
            },
          ),
        )
        .toList();
  }

  /// Row showing the reminder date + time pills (always both; no all-day case).
  Widget _buildReminderDateRow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    child: AnimatedSize(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeInOut,
      alignment: Alignment.topCenter,
      child: AdaptiveLabelPillRow(
        // Keep the label on the first level and move both values together to
        // a right-aligned second level when the complete row cannot fit.
        label: 'Reminder Date',
        labelStyle: _kLabelStyle,
        pillsBelowLabelOnWrap: true,
        verticalWrapGap: kWrappedLabelValueGap,
        labelValueGap: 8.0,
        onLabelTap: () => _togglePicker('reminder'),
        pills: [
          AdaptivePillSpec(
            text: _fmtDate(_reminderDate),
            backgroundColor: _resolvedPillColor,
            style: TextStyle(
              inherit: false,
              color: _activePicker == 'reminder'
                  ? _resolvedCategoryColor
                  : resolveThemeColor(kPrimaryLabel, context),
              fontSize: 15,
              fontFamily: kSFProText,
              fontWeight: FontWeight.w500,
              letterSpacing: kTracking17,
            ),
            onTap: () => _togglePicker('reminder'),
          ),
          AdaptivePillSpec(
            text: _fmtTime(_reminderDate),
            backgroundColor: _resolvedPillColor,
            style: TextStyle(
              inherit: false,
              color: _activePicker == 'reminder_time'
                  ? _resolvedCategoryColor
                  : resolveThemeColor(kPrimaryLabel, context),
              fontSize: 15,
              fontFamily: kSFProText,
              fontWeight: FontWeight.w500,
              letterSpacing: kTracking17,
            ),
            onTap: () => _togglePicker('reminder_time'),
          ),
        ],
      ),
    ),
  );

  /// The Reminder card — swaps in for the Alerts card when Unscheduled is ON.
  Widget _buildReminderSection() => AnimatedBuilder(
    animation: Listenable.merge([_reminderDateCtrl, _reminderPickerCtrl]),
    builder: (ctx, _) => _card([
      _pickerRow('Reminder', _reminder, items: _reminderPickerItems()),
      SizeTransition(
        sizeFactor: _reminderDateCtrl,
        axisAlignment: 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sep(),
            _buildReminderDateRow(),
            // The date/time picker belongs directly to the Reminder Date
            // row. Keep it above Repeat Reminder so the recurrence control
            // never moves out from under the active picker.
            SizeTransition(
              sizeFactor: _reminderPickerCtrl,
              axisAlignment: 1.0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [_sep(), _buildInlineDatePicker()],
              ),
            ),
            _sep(),
            _pickerRow(
              'Repeat Reminder',
              _repeatReminder,
              items: _repeatReminderItems(),
            ),
          ],
        ),
      ),
    ]),
  );

  // ── Alerts section (Card 6): Alert + optional ordered alerts ──────────────

  Widget _buildAlertsSection() => AnimatedBuilder(
    animation: _secondAlertCtrl,
    builder: (ctx, _) => _card([
      _buildAnimatedAlertPickerRow(0),
      SizeTransition(
        sizeFactor: _secondAlertCtrl,
        axisAlignment: 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var index = 1; index < _kAlertAllBase.length; index++)
              _buildAnimatedAlertRow(index),
          ],
        ),
      ),
    ]),
  );

  // ── Month-grid cell builder ────────────────────────────────────────────────

  Widget _buildPickerMonthGrid({
    required int year,
    required int month,
    required DateTime today,
  }) {
    final startOffset = DateTime(year, month, 1).weekday - 1; // Mon-first
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final selected = _pickerDate;
    final isSelectedMonth = selected.year == year && selected.month == month;
    final isCurrentMonth = today.year == year && today.month == month;
    final gridScale = textScaleRatioFor(context, 15.0);
    final gridCircleSize = 30.0 * gridScale;
    final gridRowHeight = 38.0 * gridScale;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(
          6,
          (row) => Row(
            children: List.generate(7, (col) {
              final day = row * 7 + col - startOffset + 1;
              if (day < 1 || day > daysInMonth) {
                return Expanded(child: SizedBox(height: gridRowHeight));
              }
              final isSel = isSelectedMonth && selected.day == day;
              final isToday = isCurrentMonth && today.day == day;
              final dateOnly = DateTime(year, month, day);
              final todayOnly = DateTime(today.year, today.month, today.day);
              final startsOnly = DateTime(
                _starts.year,
                _starts.month,
                _starts.day,
              );
              // A day is unselectable if it's in the past, OR if the Ends
              // picker is open and the day falls before the Starts date.
              final isPast =
                  dateOnly.isBefore(todayOnly) ||
                  (_activePicker == 'ends' && dateOnly.isBefore(startsOnly));

              final Widget circle;
              if (isSel) {
                circle = Container(
                  width: gridCircleSize,
                  height: gridCircleSize,
                  decoration: BoxDecoration(
                    color: _resolvedCategoryColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      inherit: false,
                      color: Color(0xFFFFFFFF),
                      fontSize: 15,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w600,
                      letterSpacing: kTracking17,
                    ),
                  ),
                );
              } else if (isToday) {
                circle = Container(
                  width: gridCircleSize,
                  height: gridCircleSize,
                  decoration: BoxDecoration(
                    color: _resolvedCategoryColor.withOpacity(0.40),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      inherit: false,
                      color: Color(0xFFFFFFFF),
                      fontSize: 15,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w500,
                      letterSpacing: kTracking17,
                    ),
                  ),
                );
              } else if (isPast) {
                circle = Container(
                  width: gridCircleSize,
                  height: gridCircleSize,
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      inherit: false,
                      color: resolveThemeColor(kTertiaryLabel, context),
                      fontSize: 15,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w400,
                      letterSpacing: kTracking17,
                    ),
                  ),
                );
              } else {
                circle = Container(
                  width: gridCircleSize,
                  height: gridCircleSize,
                  alignment: Alignment.center,
                  child: Text(
                    '$day',
                    style: TextStyle(
                      inherit: false,
                      color: resolveThemeColor(kPrimaryLabel, context),
                      fontSize: 15,
                      fontFamily: kSFProText,
                      fontWeight: FontWeight.w400,
                      letterSpacing: kTracking17,
                    ),
                  ),
                );
              }

              if (isPast) {
                return Expanded(
                  child: SizedBox(
                    height: gridRowHeight,
                    child: Center(child: circle),
                  ),
                );
              }
              return Expanded(
                child: GelBloomButton(
                  onTap: () {
                    _setPickerDate(DateTime(year, month, day));
                    _ctrlFor(
                      _activePicker,
                    ).animateTo(0.0, curve: Curves.easeIn).then((_) {
                      if (mounted) setState(() => _activePicker = '');
                    });
                  },
                  peakScale: 1.15,
                  child: SizedBox(
                    height: gridRowHeight,
                    child: Center(child: circle),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Month-panel header ─────────────────────────────────────────────────────

  Widget _buildPickerPanelHeader(
    DateTime month,
    DateTime today, {
    required bool isCenter,
  }) {
    final isCurrent = month.year == today.year && month.month == today.month;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: isCenter ? _togglePickerBarrelMode : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${_kPickerMonthNames[month.month - 1]} ${month.year}',
                  style: TextStyle(
                    inherit: false,
                    color: isCurrent
                        ? _resolvedCategoryColor
                        : resolveThemeColor(kPrimaryLabel, context),
                    fontSize: 16,
                    fontFamily: kSFProText,
                    fontWeight: FontWeight.w600,
                    letterSpacing: kTracking17,
                  ),
                ),
                const SizedBox(width: 5),
                AnimatedRotation(
                  turns: _pickerBarrelMode ? 0.25 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  child: Icon(
                    CupertinoIcons.chevron_right,
                    size: 13,
                    color: _resolvedCategoryColor,
                    shadows: resolveThemeTextShadows([
                      Shadow(color: _resolvedCategoryColor, blurRadius: 0.8),
                    ], context),
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          Visibility(
            visible: !_pickerBarrelMode,
            maintainSize: true,
            maintainAnimation: true,
            maintainState: true,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isCenter ? _prevPickerMonth : null,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      CupertinoIcons.chevron_left,
                      size: 16,
                      color: _resolvedCategoryColor,
                      shadows: resolveThemeTextShadows([
                        Shadow(color: _resolvedCategoryColor, blurRadius: 0.8),
                      ], context),
                    ),
                  ),
                ),
                const SizedBox(width: 2),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: isCenter ? _nextPickerMonth : null,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      CupertinoIcons.chevron_right,
                      size: 16,
                      color: _resolvedCategoryColor,
                      shadows: resolveThemeTextShadows([
                        Shadow(color: _resolvedCategoryColor, blurRadius: 0.8),
                      ], context),
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

  // ── Month panel (DOW row + grid) ───────────────────────────────────────────

  Widget _buildPickerMonthPanel(
    DateTime month,
    DateTime today, {
    required bool isCenter,
    bool showHeader = true,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showHeader)
          _buildPickerPanelHeader(month, today, isCenter: isCenter),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: _kDayLetters
                .map(
                  (d) => Expanded(
                    child: Center(
                      child: Text(
                        d,
                        style: TextStyle(
                          inherit: false,
                          color: resolveThemeColor(kSecondaryLabel, context),
                          fontSize: 11,
                          fontFamily: kSFProText,
                          fontWeight: FontWeight.w500,
                          letterSpacing: kTracking17,
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
        const SizedBox(height: 2),
        _buildPickerMonthGrid(
          year: month.year,
          month: month.month,
          today: today,
        ),
      ],
    );
  }

  // ── Inline date picker (month-grid + barrel toggle) ────────────────────────

  Widget _buildInlineDatePicker() {
    // ── Time picker ────────────────────────────────────────────────────────
    if (_activePicker.endsWith('_time')) {
      return _EventTimePicker(
        key: ValueKey('time_$_activePicker'),
        initialTime: _pickerDate,
        onChanged: _setPickerTime,
      );
    }

    // ── Date picker (month grid + barrel) ──────────────────────────────────
    final today = DateTime.now();
    final prevMonth = DateTime(_pickerCalMonth.year, _pickerCalMonth.month - 1);
    final nextMonth = DateTime(_pickerCalMonth.year, _pickerCalMonth.month + 1);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPickerPanelHeader(_pickerCalMonth, today, isCenter: true),
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOut,
            child: _pickerBarrelMode
                ? SizedBox(
                    height: cupertinoDatePickerHeight(context),
                    child: CupertinoTheme(
                      data: CupertinoTheme.of(context).copyWith(
                        primaryColor: _resolvedCategoryColor,
                        textTheme: CupertinoTheme.of(context).textTheme
                            .copyWith(
                              dateTimePickerTextStyle: TextStyle(
                                inherit: false,
                                fontFamily: kSFProText,
                                fontSize: cupertinoDatePickerFontSize(context),
                                color: resolveThemeColor(
                                  kPrimaryLabel,
                                  context,
                                ),
                                letterSpacing: kTracking17,
                              ),
                            ),
                      ),
                      child: CupertinoDatePicker(
                        itemExtent: cupertinoDatePickerItemExtent(context),
                        key: ValueKey('barrel_$_activePicker'),
                        mode: CupertinoDatePickerMode.date,
                        initialDateTime: _pickerDate,
                        onDateTimeChanged: (dt) {
                          _setPickerDate(dt);
                          setState(
                            () => _pickerCalMonth = DateTime(dt.year, dt.month),
                          );
                        },
                      ),
                    ),
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragStart: (_) {
                      if (_pickerSlideTween != null) return;
                      setState(() => _pickerDragOffset = 0.0);
                    },
                    onHorizontalDragUpdate: (d) {
                      if (_pickerSlideTween != null) return;
                      setState(() => _pickerDragOffset += d.delta.dx);
                    },
                    onHorizontalDragEnd: (d) {
                      if (_pickerSlideTween != null) return;
                      final v = d.primaryVelocity ?? 0;
                      if (v < -200 || _pickerDragOffset < -40) {
                        _commitPickerMonthSlide(next: true);
                      } else if (v > 200 || _pickerDragOffset > 40) {
                        _commitPickerMonthSlide(next: false);
                      } else {
                        _snapBackPickerMonthSlide();
                      }
                    },
                    child: LayoutBuilder(
                      builder: (ctx, constraints) {
                        _pickerPanelWidth = constraints.maxWidth;
                        return ClipRect(
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: OverflowBox(
                                    alignment: Alignment.topLeft,
                                    maxHeight: double.infinity,
                                    child: Transform.translate(
                                      offset: Offset(
                                        -_pickerPanelWidth + _pickerDragOffset,
                                        0,
                                      ),
                                      child: SizedBox(
                                        width: _pickerPanelWidth,
                                        child: _buildPickerMonthPanel(
                                          prevMonth,
                                          today,
                                          isCenter: false,
                                          showHeader: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Positioned.fill(
                                child: IgnorePointer(
                                  child: OverflowBox(
                                    alignment: Alignment.topLeft,
                                    maxHeight: double.infinity,
                                    child: Transform.translate(
                                      offset: Offset(
                                        _pickerPanelWidth + _pickerDragOffset,
                                        0,
                                      ),
                                      child: SizedBox(
                                        width: _pickerPanelWidth,
                                        child: _buildPickerMonthPanel(
                                          nextMonth,
                                          today,
                                          isCenter: false,
                                          showHeader: false,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Transform.translate(
                                offset: Offset(_pickerDragOffset, 0),
                                child: SizedBox(
                                  width: _pickerPanelWidth,
                                  child: _buildPickerMonthPanel(
                                    _pickerCalMonth,
                                    today,
                                    isCenter: true,
                                    showHeader: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_pickerMenuOpen && (!_hasUnsavedChanges || _discarding),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _requestDismiss(fromXmark: false);
      },
      child: Stack(
      // The rounded sheet route gives this page a finite 92% viewport.
      // Expand the scaffold to that viewport so its header and Expanded
      // scroll body receive the same bounded height as the Category sheet.
      fit: StackFit.expand,
      children: [
        CupertinoPageScaffold(
          backgroundColor: kModalBackground,
          child: SafeArea(
            bottom: false,
            child: Column(
              children: [
                // ── Header ────────────────────────────────────────────────────
                SizedBox(height: _kHeaderEdge),
                RoundedCupertinoSheetHeader(
                  child: SizedBox(
                    height: _kHeaderBtnSize,
                    width: double.infinity,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Text(
                          widget.isEditing ? 'Edit Event' : 'New Event',
                          style: TextStyle(
                            inherit: false,
                            color: resolveThemeColor(kPrimaryLabel, context),
                            fontSize: 17,
                            fontFamily: kSFProText,
                            fontWeight: FontWeight.w600,
                            fontStyle: FontStyle.normal,
                            letterSpacing: kTracking17,
                            height: kLineHeight,
                          ),
                        ),
                        Positioned(
                          left: _kHeaderEdge,
                          child: _CalModalCircleButton(
                            icon: CupertinoIcons.xmark,
                            iconColor: resolveThemeColor(
                              kPrimaryLabel,
                              context,
                            ),
                            tapDelay: const Duration(milliseconds: 130),
                            onTap: () => _requestDismiss(fromXmark: true),
                          ),
                        ),
                        Positioned(
                          right: _kHeaderEdge,
                          child: _CalModalCircleButton(
                            // Remount the stateful glass lens when the title
                            // becomes empty so the enabled accent surface
                            // cannot linger in the disabled state.
                            key: ValueKey<bool>(
                              _titleCtrl.text.trim().isNotEmpty,
                            ),
                            icon: CupertinoIcons.checkmark,
                            containerColor: _titleCtrl.text.trim().isEmpty
                                ? resolveThemeColor(
                                    kDisabledActionSurface,
                                    context,
                                  )
                                : _resolvedCategoryColor,
                            iconColor: CupertinoColors.white,
                            tapDelay: const Duration(milliseconds: 130),
                            onTap: _titleCtrl.text.trim().isEmpty
                                ? () {}
                                : () {
                                    _saveEvent();
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // ── Scrollable cards ──────────────────────────────────────────
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _dismissModalSheetFocus,
                    child: SingleChildScrollView(
                      // This sheet owns its scroll position. Without this,
                      // it can inherit the calendar's primary controller and
                      // open at the calendar's old offset, leaving only the
                      // fixed header visible.
                      primary: false,
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        16,
                        8,
                        16,
                        math.max(16, systemSafeAreaBottomInset(context)),
                      ),
                      child: Column(
                        children: [
                          // Card 1 — Title + Subtitle
                          _card([
                            _textField(
                              ctrl: _titleCtrl,
                              focus: _titleFocus,
                              placeholder: 'Title',
                              caretToEndOnTap: true,
                              scrollController: _titleScrollCtrl,
                            ),
                            _sep(),
                            _textField(
                              ctrl: _subtitleCtrl,
                              focus: _subtitleFocus,
                              placeholder: 'Subtitle',
                              caretToEndOnTap: true,
                              multiline: true,
                              maxLinesOverride: 10,
                              scrollController: _subtitleScrollCtrl,
                            ),
                          ]),
                          const SizedBox(height: kModalCardGap),
                          // Card 2 — All-day / Starts / Ends / Unscheduled.
                          // Unscheduled is always at the bottom.  When toggled ON,
                          // the All-day + Starts + Ends block collapses above it via
                          // SizeTransition; the separator between that block and
                          // Unscheduled lives inside the transition so it disappears
                          // with the rows, leaving only Unscheduled in the card.
                          _card([
                            // Scheduled rows collapse when Unscheduled is on.
                            SizeTransition(
                              sizeFactor: _schedRowsCtrl,
                              axisAlignment: -1.0,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _switchRow('All-day', _allDay, _toggleAllDay),
                                  _sep(),
                                  _buildDateRow('Starts', _starts, 'starts'),
                                  // Starts picker — slides in below the Starts row.
                                  SizeTransition(
                                    sizeFactor: _startsPickerCtrl,
                                    axisAlignment: 1.0,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _sep(),
                                        _buildInlineDatePicker(),
                                      ],
                                    ),
                                  ),
                                  _sep(),
                                  _buildDateRow('Ends', _ends, 'ends'),
                                  // Ends picker — slides in below the Ends row.
                                  SizeTransition(
                                    sizeFactor: _endsPickerCtrl,
                                    axisAlignment: 1.0,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _sep(),
                                        _buildInlineDatePicker(),
                                      ],
                                    ),
                                  ),
                                  // Separator between Ends and Unscheduled — collapses
                                  // with the block so no orphan line remains.
                                  _sep(),
                                ],
                              ),
                            ),
                            _switchRow(
                              'Unscheduled',
                              _unscheduled,
                              _toggleUnscheduled,
                            ),
                          ]),
                          const SizedBox(height: kModalCardGap),
                          // Card 3 — Starting Location + Destination + Travel Time
                          // + conditional Travel Mode subcard.
                          _buildLocationSection(),
                          // Card 4 — Repeat + conditional End Repeat + End Date
                          // + inline calendar picker + Custom subsheet.
                          // Wrapped in SizeTransition so it animates away (rather
                          // than snapping) when Unscheduled is toggled on.
                          SizeTransition(
                            sizeFactor: _repeatCardCtrl,
                            axisAlignment: 1.0,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: kModalCardGap),
                                _buildRepeatSection(),
                              ],
                            ),
                          ),
                          const SizedBox(height: kModalCardGap),
                          // Card 5 — Category + the optional custom-DCV Section
                          // subrow. The section row stays in the same card so
                          // its separator and rounded container behave like
                          // the other dismissible modal-sheet subrows.
                          AnimatedBuilder(
                            animation: _sectionRowCtrl,
                            builder: (_, __) => _card([
                              _buildCategoryRow(),
                              SizeTransition(
                                sizeFactor: _sectionRowCtrl,
                                axisAlignment: -1.0,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [_sep(), _buildSectionRow()],
                                ),
                              ),
                            ]),
                          ),
                          // Card 6 — Alert (normal events) / Reminder (Unscheduled).
                          // The two sections cross-fade via _alertCardCtrl and
                          // _reminderCardCtrl; each carries its own top SizedBox
                          // so the gap disappears when the card collapses.
                          SizeTransition(
                            sizeFactor: _alertCardCtrl,
                            axisAlignment: 1.0,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: kModalCardGap),
                                _buildAlertsSection(),
                              ],
                            ),
                          ),
                          SizeTransition(
                            sizeFactor: _reminderCardCtrl,
                            axisAlignment: 1.0,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(height: kModalCardGap),
                                _buildReminderSection(),
                              ],
                            ),
                          ),
                          const SizedBox(height: kModalCardGap),
                          // Card 7 — attached files + "Add attachment…"
                          //
                          // AnimatedList owns the row insertion/removal height
                          // animation. The outer card deliberately keeps one
                          // fixed-radius shape in both empty and populated
                          // states, so its corners do not morph as the list
                          // grows or shrinks.
                          _card([
                            AnimatedList(
                              key: _attachmentListKey,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              initialItemCount: _attachments.length,
                              itemBuilder: (context, index, animation) =>
                                  SizeTransition(
                                    sizeFactor: animation,
                                    axisAlignment: -1.0,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        _buildAttachmentFileRow(index),
                                        _sep(),
                                      ],
                                    ),
                                  ),
                            ),
                            _buildAttachmentRow(),
                          ]),
                           AnimatedSize(
                             duration: const Duration(milliseconds: 180),
                             curve: Curves.easeOutCubic,
                             alignment: Alignment.topCenter,
                             child: _repeat != 'Never'
                                 ? SizedBox(
                                     width: double.infinity,
                                     child: Padding(
                                       padding: const EdgeInsets.only(
                                         top: 8,
                                         left:
                                             kModalSheetContextFooterHorizontalInset,
                                         right:
                                             kModalSheetContextFooterHorizontalInset,
                                       ),
                                       child: Text(
                                         _kRecurringAttachmentFooter,
                                         style: modalSheetContextFooterStyle(
                                           context,
                                         ),
                                         textAlign: TextAlign.left,
                                       ),
                                     ),
                                   )
                                 : const SizedBox(
                                     width: double.infinity,
                                     height: 0,
                                   ),
                           ),
                          const SizedBox(height: kModalCardGap),
                          // Card 8 — URL + Notes
                          _card([
                            _textField(
                              ctrl: _urlCtrl,
                              focus: _urlFocus,
                              placeholder: 'URL',
                              caretToEndOnTap: true,
                              scrollController: _urlScrollCtrl,
                            ),
                            _sep(),
                            _textField(
                              ctrl: _notesCtrl,
                              focus: _notesFocus,
                              placeholder: 'Notes',
                              caretToEndOnTap: true,
                              multiline: true,
                              maxLinesOverride: 10,
                              minLinesOverride: 5,
                              scrollController: _notesScrollCtrl,
                            ),
                          ]),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Custom time picker — three columns (h / min / AM-PM).
// Hours and minutes use ListWheelChildLoopingListDelegate — a true circular
// barrel with only 12 / 60 real items.  AM/PM uses a plain CupertinoPicker
// (2 items, no loop needed).  All three share the same visual properties as
// the "first/second… Monday/Tuesday…" recurrence pickers.
// ═════════════════════════════════════════════════════════════════════════════
class _EventTimePicker extends StatefulWidget {
  const _EventTimePicker({
    super.key,
    required this.initialTime,
    required this.onChanged,
  });

  final DateTime initialTime;
  final ValueChanged<DateTime> onChanged;

  @override
  State<_EventTimePicker> createState() => _EventTimePickerState();
}

class _EventTimePickerState extends State<_EventTimePicker> {
  static const double _kMagnification = 2.35 / 2.1;

  static final _kStyleBase = TextStyle(
    inherit: false,
    fontFamily: kSFProText,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: kPrimaryLabel,
    letterSpacing: kTracking17,
  );

  late FixedExtentScrollController _hourCtrl;
  late FixedExtentScrollController _minuteCtrl;
  late FixedExtentScrollController _periodCtrl;

  late int _hour12; // 1–12
  late int _minute; // 0–59
  late int _period; // 0 = AM, 1 = PM

  @override
  void initState() {
    super.initState();
    final t = widget.initialTime;
    _period = t.hour >= 12 ? 1 : 0;
    _hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
    _minute = t.minute;
    // With a looping delegate the index can be any integer; start at the
    // natural position (0-based).
    _hourCtrl = FixedExtentScrollController(initialItem: _hour12 - 1);
    _minuteCtrl = FixedExtentScrollController(initialItem: _minute);
    _periodCtrl = FixedExtentScrollController(initialItem: _period);
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _minuteCtrl.dispose();
    _periodCtrl.dispose();
    super.dispose();
  }

  void _notify() {
    final hour24 = _period == 0
        ? (_hour12 == 12 ? 0 : _hour12)
        : (_hour12 == 12 ? 12 : _hour12 + 12);
    widget.onChanged(
      DateTime(
        widget.initialTime.year,
        widget.initialTime.month,
        widget.initialTime.day,
        hour24,
        _minute,
      ),
    );
  }

  double get _itemExtent => cupertinoDatePickerItemExtent(context);

  double get _height => cupertinoDatePickerHeight(context);

  // Builds a barrel column using ListWheelScrollView.useDelegate.
  // loop:true  → ListWheelChildLoopingListDelegate (infinite circular scroll).
  // loop:false → ListWheelChildListDelegate (finite, stops at ends) — used for
  //              AM/PM so the barrel doesn't wrap, while keeping the same widget
  //              type as hours/minutes so the shared selection-pill overlay is
  //              rendered identically across all three columns.
  Widget _loopingBarrel({
    required FixedExtentScrollController ctrl,
    required List<Widget> children,
    required void Function(int) onChanged,
    double offAxisFraction = 0.0,
    bool capStart = true,
    bool capEnd = true,
    bool loop = true,
  }) {
    final count = children.length;
    return Stack(
      children: [
        ListWheelScrollView.useDelegate(
          controller: ctrl,
          itemExtent: _itemExtent,
          physics: const FixedExtentScrollPhysics(),
          diameterRatio: 1.07,
          perspective: 0.003,
          squeeze: 1.25,
          magnification: _kMagnification,
          useMagnifier: true,
          overAndUnderCenterOpacity: 0.447,
          offAxisFraction: offAxisFraction,
          childDelegate: loop
              ? ListWheelChildLoopingListDelegate(children: children)
              : ListWheelChildListDelegate(children: children),
          onSelectedItemChanged: loop
              ? (i) => onChanged(((i % count) + count) % count)
              : (i) => onChanged(i),
        ),
        // Mirror how CupertinoPicker positions its selectionOverlay: a
        // SizedBox(height: itemExtent) centred over the wheel.
        IgnorePointer(
          child: Center(
            child: SizedBox(
              height: _itemExtent,
              width: double.infinity,
              child: CupertinoPickerDefaultSelectionOverlay(
                capStartEdge: capStart,
                capEndEdge: capEnd,
                // Default grey — matches the "first/second… Monday/Tuesday…"
                // reference pickers which use no custom background.
              ),
            ),
          ),
        ),
      ],
    );
  }

  TextStyle get _kStyle => resolveThemeTextStyle(_kStyleBase, context);

  @override
  Widget build(BuildContext context) => SizedBox(
    height: _height,
    child: Row(
      children: [
        // ── Hours 1–12 — loops, leans right toward minutes ───────────────
        Expanded(
          child: _loopingBarrel(
            ctrl: _hourCtrl,
            offAxisFraction: -0.45,
            capStart: true,
            capEnd: false,
            onChanged: (i) {
              _hour12 = i + 1;
              _notify();
            },
            children: List.generate(
              12,
              (i) => Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Text('${i + 1}', style: _kStyle),
                ),
              ),
            ),
          ),
        ),

        // ── Minutes 00–59 — loops, centred ───────────────────────────────
        Expanded(
          child: _loopingBarrel(
            ctrl: _minuteCtrl,
            offAxisFraction: 0,
            capStart: false,
            capEnd: false,
            onChanged: (i) {
              _minute = i;
              _notify();
            },
            children: List.generate(
              60,
              (i) => Center(
                child: Text(i.toString().padLeft(2, '0'), style: _kStyle),
              ),
            ),
          ),
        ),

        // ── AM / PM — same _loopingBarrel widget for a uniform pill;
        // loop:false so the barrel stops at the two real items and never wraps.
        Expanded(
          child: _loopingBarrel(
            ctrl: _periodCtrl,
            offAxisFraction: 0.45,
            capStart: false,
            capEnd: true,
            loop: false,
            onChanged: (i) {
              _period = i;
              _notify();
            },
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text('AM', style: _kStyle),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: Text('PM', style: _kStyle),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// _NewEventCustomRepeat* — mirrors _CustomRepeat* in events_tab.dart but
// scoped to the Calendar-tab New Event sheet (uses _CalModalCircleButton).
// ═════════════════════════════════════════════════════════════════════════════

class _NewEventCustomRepeatConfig {
  final String frequency;
  final int everyCount;
  final Set<String> selectedDays;
  final String monthlyMode;
  final Set<int> selectedDates;
  final int onThePositionIndex;
  final int onTheDayIndex;
  final Set<int> selectedMonths;
  final bool yearlyDaysEnabled;
  final int yearlyPositionIndex;
  final int yearlyDayIndex;
  const _NewEventCustomRepeatConfig({
    this.frequency = 'Daily',
    this.everyCount = 1,
    this.selectedDays = const {},
    this.monthlyMode = 'Each',
    this.selectedDates = const {},
    this.onThePositionIndex = 0,
    this.onTheDayIndex = 0,
    this.selectedMonths = const {},
    this.yearlyDaysEnabled = false,
    this.yearlyPositionIndex = 0,
    this.yearlyDayIndex = 0,
  });
}

class _NewEventCustomRepeatResult {
  final String label;
  final _NewEventCustomRepeatConfig config;
  const _NewEventCustomRepeatResult(this.label, this.config);
}

const double _kPickerSelectionPillMargin = 9.0;
const double _kPickerSelectionPillTextInset = 4.0;

class _PickerSelectionPillClipper extends CustomClipper<Rect> {
  const _PickerSelectionPillClipper({
    required this.capStartEdge,
    required this.capEndEdge,
  });

  final bool capStartEdge;
  final bool capEndEdge;

  @override
  Rect getClip(Size size) {
    return Rect.fromLTRB(
      capStartEdge ? _kPickerSelectionPillMargin : 0,
      0,
      size.width - (capEndEdge ? _kPickerSelectionPillMargin : 0),
      size.height,
    );
  }

  @override
  bool shouldReclip(_PickerSelectionPillClipper oldClipper) {
    return capStartEdge != oldClipper.capStartEdge ||
        capEndEdge != oldClipper.capEndEdge;
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _NewEventCustomRepeatSheet extends StatefulWidget {
  final Color accentColor;
  final _NewEventCustomRepeatConfig? config;
  final String subjectLabel;
  const _NewEventCustomRepeatSheet({
    required this.accentColor,
    this.config,
    this.subjectLabel = 'Event',
  });

  @override
  State<_NewEventCustomRepeatSheet> createState() =>
      _NewEventCustomRepeatSheetState();
}

class _NewEventCustomRepeatSheetState extends State<_NewEventCustomRepeatSheet>
    with TickerProviderStateMixin {
  // ── Frequency ─────────────────────────────────────────────────────────────
  String _frequency = 'Daily';

  static const List<String> _kFrequencyOptions = [
    'Daily',
    'Weekly',
    'Monthly',
    'Yearly',
  ];

  static const Map<String, String> _kFrequencyUnit = {
    'Daily': 'Day',
    'Weekly': 'Week',
    'Monthly': 'Month',
    'Yearly': 'Year',
  };

  static const Map<String, String> _kFrequencyUnitPlural = {
    'Daily': 'Days',
    'Weekly': 'Weeks',
    'Monthly': 'Months',
    'Yearly': 'Years',
  };

  String get _everyUnit => _everyCount == 1
      ? _kFrequencyUnit[_frequency]!
      : _kFrequencyUnitPlural[_frequency]!;

  // ── Weekly ────────────────────────────────────────────────────────────────
  static const List<String> _kDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  final Set<String> _selectedDays = {};

  // ── Monthly ───────────────────────────────────────────────────────────────
  static const List<String> _kPositions = [
    'first',
    'second',
    'third',
    'fourth',
    'fifth',
    'last',
  ];
  String _monthlyMode = 'Each';
  final Set<int> _selectedDates = {};
  int _onThePositionIndex = 0;
  int _onTheDayIndex = 0;
  late final FixedExtentScrollController _onThePositionCtrl;
  late final FixedExtentScrollController _onTheDayCtrl;

  // ── Yearly ────────────────────────────────────────────────────────────────
  static const List<String> _kMonths = [
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
  static const List<String> _kMonthsFull = [
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
  final Set<int> _selectedMonths = {};
  bool _yearlyDaysEnabled = false;
  int _yearlyPositionIndex = 0;
  int _yearlyDayIndex = 0;
  late final FixedExtentScrollController _yearlyPositionCtrl;
  late final FixedExtentScrollController _yearlyDayCtrl;
  late final AnimationController _yearlyDaysCtrl;

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    switch (n % 10) {
      case 1:
        return '${n}st';
      case 2:
        return '${n}nd';
      case 3:
        return '${n}rd';
      default:
        return '${n}th';
    }
  }

  List<String> get _orderedSelectedDays =>
      _kDays.where(_selectedDays.contains).toList();

  static String _joinDays(List<String> days) {
    if (days.length == 1) return days[0];
    if (days.length == 2) return '${days[0]} and ${days[1]}';
    return '${days.take(days.length - 1).join(', ')}, and ${days.last}';
  }

  String get _footerText {
    final subject = widget.subjectLabel;
    final unit = _everyUnit.toLowerCase();
    final every = _everyCount == 1 ? 'every $unit' : 'every $_everyCount $unit';
    if (_frequency == 'Weekly' && _selectedDays.isNotEmpty) {
      return '$subject will occur $every on ${_joinDays(_orderedSelectedDays)}.';
    }
    if (_frequency == 'Monthly') {
      if (_monthlyMode == 'Each' && _selectedDates.isNotEmpty) {
        final sorted = _selectedDates.toList()..sort();
        final ordinals = sorted.map(_ordinal).toList();
        return '$subject will occur $every on the ${_joinDays(ordinals)}.';
      }
      if (_monthlyMode == 'OnThe') {
        final pos = _kPositions[_onThePositionIndex];
        final day = _kDays[_onTheDayIndex];
        return '$subject will occur $every on the $pos $day.';
      }
    }
    if (_frequency == 'Yearly') {
      final sortedMonths = _selectedMonths.toList()..sort();
      final monthNames = sortedMonths.map((i) => _kMonthsFull[i - 1]).toList();
      final String base = monthNames.isEmpty
          ? '$subject will occur $every'
          : '$subject will occur $every in ${_joinDays(monthNames)}';
      if (_yearlyDaysEnabled) {
        final pos = _kPositions[_yearlyPositionIndex];
        final day = _kDays[_yearlyDayIndex];
        return '$base on the $pos $day.';
      }
      return '$base.';
    }
    return '$subject will occur $every.';
  }

  // ── Every subcard ─────────────────────────────────────────────────────────
  int _everyCount = 1;
  late final FixedExtentScrollController _everyCountCtrl;
  late final AnimationController _everyPickerCtrl;

  // ── Picker overlay ────────────────────────────────────────────────────────
  final _pickerIsClosing = ValueNotifier<bool>(false);
  OverlayEntry? _pickerEntry;
  bool _pickerMenuOpen = false;
  String? _openPickerLabel;

  @override
  void initState() {
    super.initState();
    final c = widget.config;
    if (c != null) {
      _frequency = c.frequency;
      _everyCount = c.everyCount;
      _selectedDays.addAll(c.selectedDays);
      _monthlyMode = c.monthlyMode;
      _selectedDates.addAll(c.selectedDates);
      _onThePositionIndex = c.onThePositionIndex;
      _onTheDayIndex = c.onTheDayIndex;
      _selectedMonths.addAll(c.selectedMonths);
      _yearlyDaysEnabled = c.yearlyDaysEnabled;
      _yearlyPositionIndex = c.yearlyPositionIndex;
      _yearlyDayIndex = c.yearlyDayIndex;
    }
    _everyCountCtrl = FixedExtentScrollController(initialItem: _everyCount - 1);
    _onThePositionCtrl = FixedExtentScrollController(
      initialItem: _onThePositionIndex,
    );
    _onTheDayCtrl = FixedExtentScrollController(initialItem: _onTheDayIndex);
    _yearlyPositionCtrl = FixedExtentScrollController(
      initialItem: _yearlyPositionIndex,
    );
    _yearlyDayCtrl = FixedExtentScrollController(initialItem: _yearlyDayIndex);
    _everyPickerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _yearlyDaysCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
      value: _yearlyDaysEnabled ? 1.0 : 0.0,
    );
  }

  @override
  void dispose() {
    _everyCountCtrl.dispose();
    _onThePositionCtrl.dispose();
    _onTheDayCtrl.dispose();
    _yearlyPositionCtrl.dispose();
    _yearlyDayCtrl.dispose();
    _everyPickerCtrl.dispose();
    _yearlyDaysCtrl.dispose();
    _pickerIsClosing.dispose();
    _pickerEntry?.remove();
    super.dispose();
  }

  void _toggleEveryPicker() {
    if (_everyPickerCtrl.isDismissed) {
      _everyPickerCtrl.forward();
    } else {
      _everyPickerCtrl.reverse();
    }
  }

  void _dismissPickerOverlay({bool animate = true}) {
    if (!_pickerMenuOpen) return;
    _pickerIsClosing.value = true;
    if (mounted) setState(() => _openPickerLabel = null);
    final delay = animate ? const Duration(milliseconds: 420) : Duration.zero;
    Future.delayed(delay, () {
      _pickerEntry?.remove();
      _pickerEntry = null;
      if (mounted) {
        _pickerIsClosing.value = false;
        setState(() => _pickerMenuOpen = false);
      }
    });
  }

  void _showPickerOverlay(
    BuildContext rowCtx,
    String rowLabel,
    List<ActionItem> items,
  ) {
    if (_pickerMenuOpen) _dismissPickerOverlay(animate: false);
    FocusManager.instance.primaryFocus?.unfocus();
    final box = rowCtx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final pos = box.localToGlobal(Offset.zero);
    final size = box.size;
    _pickerIsClosing.value = false;
    setState(() {
      _pickerMenuOpen = true;
      _openPickerLabel = rowLabel;
    });
    _pickerEntry = OverlayEntry(
      builder: (ctx) => ActionMenuOverlay(
        buttonRect: Rect.fromLTWH(pos.dx, pos.dy, size.width, size.height),
        isClosing: _pickerIsClosing,
        onDismiss: _dismissPickerOverlay,
        actions: items,
        panelWidth: kPickerPanelWidth,
        chevronColumn: true,
        anchorToRight: true,
        labelFontSize: 15,
        bouncingScroll: true,
        isPickerMiniPanel: true,
      ),
    );
    Overlay.of(context).insert(_pickerEntry!);
  }

  List<ActionItem> _makeItems(
    List<String> options,
    String current,
    void Function(String) onSelect, {
    Color? checkmarkColor,
  }) => options
      .map(
        (label) => ActionItem(
          label: label,
          icon: SFIcons.sf_circle,
          iconBuilder: (_) => const SizedBox.shrink(),
          checkmark: label == current,
          checkmarkColor: checkmarkColor,
          onTap: () {
            onSelect(label);
            Future.delayed(
              const Duration(milliseconds: 80),
              _dismissPickerOverlay,
            );
          },
        ),
      )
      .toList();

  // ── Card / row helpers ────────────────────────────────────────────────────

  static final _kRowLabelStyleBase = TextStyle(
    inherit: false,
    color: kPrimaryLabel,
    fontSize: 17,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
    height: kLineHeight,
  );

  static final _kRowValueStyleBase = TextStyle(
    inherit: false,
    color: kSecondaryLabel,
    fontSize: 15,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
    height: kLineHeight,
  );

  static final _kPickerItemStyleBase = TextStyle(
    inherit: false,
    color: kPrimaryLabel,
    fontSize: 16,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
  );

  static final _kDateCellStyleBase = TextStyle(
    inherit: false,
    color: kPrimaryLabel,
    fontSize: 17,
    fontFamily: kSFProText,
    fontWeight: FontWeight.w400,
    letterSpacing: kTracking17,
    height: kLineHeight,
  );

  TextStyle get _kRowLabelStyle =>
      resolveThemeTextStyle(_kRowLabelStyleBase, context);
  TextStyle get _kRowValueStyle =>
      resolveThemeTextStyle(_kRowValueStyleBase, context);
  TextStyle get _kPickerItemStyle =>
      resolveThemeTextStyle(_kPickerItemStyleBase, context);
  TextStyle get _kDateCellStyle =>
      resolveThemeTextStyle(_kDateCellStyleBase, context);

  static const double _kPickerMagnification = 2.35 / 2.1;

  double get _pickerItemExtent {
    final linePainter = TextPainter(
      text: TextSpan(text: 'Wednesday', style: _kPickerItemStyle),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    return math.max(32.0, linePainter.height * _kPickerMagnification + 4.0);
  }

  TextStyle _pickerTextStyleThatFits(String text, double availableWidth) {
    final baseStyle = _kPickerItemStyle;
    final baseFontSize = baseStyle.fontSize ?? 16.0;
    // Keep the text inside the pill edge rather than letting a tight option
    // touch it. The selected row is magnified by the wheel, so reserve that
    // same amount of horizontal room before choosing the un-magnified size.
    final targetWidth = math.max(
      1.0,
      (availableWidth -
              _kPickerSelectionPillMargin -
              _kPickerSelectionPillTextInset) /
          _kPickerMagnification,
    );
    final scaler = MediaQuery.textScalerOf(context);

    double measuredWidth(double fontSize) {
      final scale = fontSize / baseFontSize;
      final style = baseStyle.copyWith(
        fontSize: fontSize,
        letterSpacing: baseStyle.letterSpacing == null
            ? null
            : baseStyle.letterSpacing! * scale,
      );
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: Directionality.of(context),
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      return painter.width;
    }

    if (!availableWidth.isFinite ||
        measuredWidth(baseFontSize) <= targetWidth) {
      return baseStyle;
    }

    // Binary search keeps the authored size whenever it fits and only reduces
    // it as much as the actual pill width requires.
    var low = 1.0;
    var high = baseFontSize;
    for (var i = 0; i < 20; i++) {
      final candidate = (low + high) / 2;
      if (measuredWidth(candidate) <= targetWidth) {
        low = candidate;
      } else {
        high = candidate;
      }
    }
    final scale = low / baseFontSize;
    return baseStyle.copyWith(
      fontSize: low,
      letterSpacing: baseStyle.letterSpacing == null
          ? null
          : baseStyle.letterSpacing! * scale,
    );
  }

  Widget _pickerText(String text, Alignment alignment) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.hasBoundedWidth
            ? constraints.maxWidth
            : (MediaQuery.sizeOf(context).width - 32) / 2 - 20;
        return Text(
          text,
          style: _pickerTextStyleThatFits(text, availableWidth),
          maxLines: 1,
          softWrap: false,
        );
      },
    );
  }

  Widget _clipPicker(
    Widget picker, {
    required bool capStartEdge,
    required bool capEndEdge,
  }) {
    return ClipRect(
      clipper: _PickerSelectionPillClipper(
        capStartEdge: capStartEdge,
        capEndEdge: capEndEdge,
      ),
      child: picker,
    );
  }

  Widget _card(List<Widget> rows) {
    final cardColor = resolveThemeColor(kModalCard, context);
    final shadows = resolveThemeShadows(kCardShadow, context);
    return Container(
      decoration: ShapeDecoration(
        color: cardColor,
        shape: const BoundedSquircleStadiumBorder(),
        shadows: shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _cardWithRadius(List<Widget> rows, BorderRadius radius) {
    final cardColor = resolveThemeColor(kModalCard, context);
    final shadows = resolveThemeShadows(kCardShadow, context);
    final resolvedRadius = radius.resolve(Directionality.of(context));
    final effectiveRadius = [
      resolvedRadius.topLeft.x,
      resolvedRadius.topLeft.y,
      resolvedRadius.topRight.x,
      resolvedRadius.topRight.y,
      resolvedRadius.bottomLeft.x,
      resolvedRadius.bottomLeft.y,
      resolvedRadius.bottomRight.x,
      resolvedRadius.bottomRight.y,
    ].reduce((a, b) => a > b ? a : b);
    final hasTopCorners =
        resolvedRadius.topLeft.x > 0 || resolvedRadius.topRight.x > 0;
    final hasBottomCorners =
        resolvedRadius.bottomLeft.x > 0 || resolvedRadius.bottomRight.x > 0;
    final shape = BoundedSquircleStadiumBorder(
      radius: effectiveRadius,
      topOnly: hasTopCorners && !hasBottomCorners,
      bottomOnly: hasBottomCorners && !hasTopCorners,
    );
    return Container(
      decoration: ShapeDecoration(
        color: cardColor,
        shape: shape,
        shadows: shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }

  Widget _sep() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Container(
      height: 0.5,
      color: resolveThemeColor(kSeparatorColor, context),
    ),
  );

  Widget _pickerRow(
    String label,
    String value, {
    List<ActionItem>? items,
    bool showChevron = true,
    Color? valueColor,
    VoidCallback? onTap,
  }) {
    final isOpen = items != null && _openPickerLabel == label;
    final TextStyle valueStyle = valueColor != null
        ? modalSheetAccentValueStyle(context, valueColor)
        : _kRowValueStyle;
    return Builder(
      builder: (ctx) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: items != null
            ? () => _showPickerOverlay(ctx, label, items)
            : onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: kModalSheetPickerRowHorizontalInset,
            vertical: 14,
          ),
          child: MinGapLabelValueRow(
            label: label,
            labelStyle: _kRowLabelStyle,
            value: value,
            valueStyle: valueStyle,
            trailing: AnimatedOpacity(
              opacity: isOpen ? kPickerRowOpenDimOpacity : 1.0,
              duration: const Duration(milliseconds: 150),
              child: ModalSheetPickerTrailing(
                value: value,
                style: valueStyle,
                chevronColor: resolveThemeColor(kSecondaryLabel, context),
                showChevron: showChevron,
              ),
            ),
            trailingExtraWidth: modalSheetPickerTrailingExtraWidth(
              ctx,
              showChevron: showChevron,
            ),
          ),
        ),
      ),
    );
  }

  // ── Every drum-picker subcard ─────────────────────────────────────────────

  Widget _buildEverySubcard() => SizeTransition(
    sizeFactor: _everyPickerCtrl,
    axisAlignment: 1.0,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _sep(),
        SizedBox(
          height: math.max(216.0, _pickerItemExtent * 5.5),
          child: Row(
            children: [
              Expanded(
                child: _clipPicker(
                  CupertinoPicker(
                    scrollController: _everyCountCtrl,
                    itemExtent: _pickerItemExtent,
                    backgroundColor: CupertinoColors.transparent,
                    useMagnifier: true,
                    magnification: 2.35 / 2.1,
                    squeeze: 1.25,
                    offAxisFraction: -0.45,
                    selectionOverlay:
                        const CupertinoPickerDefaultSelectionOverlay(
                          capStartEdge: true,
                          capEndEdge: false,
                        ),
                    onSelectedItemChanged: (i) =>
                        setState(() => _everyCount = i + 1),
                    children: List.generate(
                      999,
                      (i) => Align(
                        alignment: Alignment.centerRight,
                        child: Padding(
                          padding: const EdgeInsets.only(right: 20),
                          child: _pickerText('${i + 1}', Alignment.centerRight),
                        ),
                      ),
                    ),
                  ),
                  capStartEdge: true,
                  capEndEdge: false,
                ),
              ),
              Expanded(
                child: _clipPicker(
                  CupertinoPicker(
                    itemExtent: _pickerItemExtent,
                    backgroundColor: CupertinoColors.transparent,
                    useMagnifier: true,
                    magnification: 2.35 / 2.1,
                    squeeze: 1.25,
                    offAxisFraction: 0.45,
                    selectionOverlay:
                        const CupertinoPickerDefaultSelectionOverlay(
                          capStartEdge: false,
                          capEndEdge: true,
                        ),
                    onSelectedItemChanged: (_) {},
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 20),
                          child: _pickerText(_everyUnit, Alignment.centerLeft),
                        ),
                      ),
                    ],
                  ),
                  capStartEdge: false,
                  capEndEdge: true,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  // ── Weekly day-selection card ─────────────────────────────────────────────

  Widget _dayRow(String day) {
    final selected = _selectedDays.contains(day);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (selected)
          _selectedDays.remove(day);
        else
          _selectedDays.add(day);
      }),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(day, style: _kRowLabelStyle),
            const Spacer(),
            if (selected)
              FixedSFIcon(
                SFIcons.sf_checkmark,
                fontSize: MediaQuery.textScalerOf(context).scale(17),
                color: widget.accentColor,
                fontWeight: FontWeight.w500,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWeekDaysCard() => _card([
    for (int i = 0; i < _kDays.length; i++) ...[
      if (i > 0) _sep(),
      _dayRow(_kDays[i]),
    ],
  ]);

  // ── Monthly unified card ──────────────────────────────────────────────────

  Widget _buildMonthlyUnifiedCard() => _card([
    _monthlyModeRow('Each', 'Each'),
    _sep(),
    _monthlyModeRow('On the\u2026', 'OnThe'),
    _sep(),
    if (_monthlyMode == 'Each') ...[
      for (int row = 0; row < 5; row++) ...[
        if (row > 0)
          Container(
            height: 0.5,
            color: resolveThemeColor(kSeparatorColor, context),
          ),
        SizedBox(
          height: 44,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (int col = 0; col < 7; col++) ...[
                if (col > 0)
                  Container(
                    width: 0.5,
                    color: resolveThemeColor(kSeparatorColor, context),
                  ),
                Expanded(child: _dateCell(row * 7 + col + 1)),
              ],
            ],
          ),
        ),
      ],
    ] else ...[
      SizedBox(
        height: math.max(216.0, _pickerItemExtent * 5.5),
        child: Row(
          children: [
            Expanded(
              child: _clipPicker(
                CupertinoPicker(
                  scrollController: _onThePositionCtrl,
                  itemExtent: _pickerItemExtent,
                  backgroundColor: CupertinoColors.transparent,
                  useMagnifier: true,
                  magnification: 2.35 / 2.1,
                  squeeze: 1.25,
                  offAxisFraction: -0.45,
                  selectionOverlay:
                      const CupertinoPickerDefaultSelectionOverlay(
                        capStartEdge: true,
                        capEndEdge: false,
                      ),
                  onSelectedItemChanged: (i) =>
                      setState(() => _onThePositionIndex = i),
                  children: _kPositions
                      .map(
                        (p) => Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(right: 20),
                            child: _pickerText(p, Alignment.centerRight),
                          ),
                        ),
                      )
                      .toList(),
                ),
                capStartEdge: true,
                capEndEdge: false,
              ),
            ),
            Expanded(
              child: _clipPicker(
                CupertinoPicker(
                  scrollController: _onTheDayCtrl,
                  itemExtent: _pickerItemExtent,
                  backgroundColor: CupertinoColors.transparent,
                  useMagnifier: true,
                  magnification: 2.35 / 2.1,
                  squeeze: 1.25,
                  offAxisFraction: 0.45,
                  selectionOverlay:
                      const CupertinoPickerDefaultSelectionOverlay(
                        capStartEdge: false,
                        capEndEdge: true,
                      ),
                  onSelectedItemChanged: (i) =>
                      setState(() => _onTheDayIndex = i),
                  children: _kDays
                      .map(
                        (d) => Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 20),
                            child: _pickerText(d, Alignment.centerLeft),
                          ),
                        ),
                      )
                      .toList(),
                ),
                capStartEdge: false,
                capEndEdge: true,
              ),
            ),
          ],
        ),
      ),
    ],
  ]);

  Widget _monthlyModeRow(String label, String key) {
    final selected = _monthlyMode == key;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _monthlyMode = key),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Text(label, style: _kRowLabelStyle),
            const Spacer(),
            if (selected)
              FixedSFIcon(
                SFIcons.sf_checkmark,
                fontSize: MediaQuery.textScalerOf(context).scale(17),
                color: widget.accentColor,
                fontWeight: FontWeight.w500,
              ),
          ],
        ),
      ),
    );
  }

  Widget _dateCell(int n) {
    if (n > 31) return SizedBox(height: 44);
    final selected = _selectedDates.contains(n);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (selected)
          _selectedDates.remove(n);
        else
          _selectedDates.add(n);
      }),
      child: SizedBox(
        height: 44,
        child: ColoredBox(
          color: selected ? widget.accentColor : const Color(0x00000000),
          child: Center(
            child: Text(
              '$n',
              style: _kDateCellStyle.copyWith(
                color: selected
                    ? CupertinoColors.white
                    : resolveThemeColor(kPrimaryLabel, context),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Yearly month grid ─────────────────────────────────────────────────────

  Widget _monthCell(int monthIndex) {
    final selected = _selectedMonths.contains(monthIndex);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() {
        if (selected)
          _selectedMonths.remove(monthIndex);
        else
          _selectedMonths.add(monthIndex);
      }),
      child: SizedBox(
        height: 44,
        child: ColoredBox(
          color: selected ? widget.accentColor : const Color(0x00000000),
          child: Center(
            child: Text(
              _kMonths[monthIndex - 1],
              style: _kDateCellStyle.copyWith(
                fontSize: 16,
                color: selected
                    ? CupertinoColors.white
                    : resolveThemeColor(kPrimaryLabel, context),
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildYearlyMonthCard() => _card([
    for (int row = 0; row < 3; row++) ...[
      if (row > 0)
        Container(
          height: 0.5,
          color: resolveThemeColor(kSeparatorColor, context),
        ),
      SizedBox(
        height: 44,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (int col = 0; col < 4; col++) ...[
              if (col > 0)
                Container(
                  width: 0.5,
                  color: resolveThemeColor(kSeparatorColor, context),
                ),
              Expanded(child: _monthCell(row * 4 + col + 1)),
            ],
          ],
        ),
      ),
    ],
  ]);

  // ── Yearly days-of-week toggle + picker ───────────────────────────────────

  void _toggleYearlyDays() {
    setState(() => _yearlyDaysEnabled = !_yearlyDaysEnabled);
    if (_yearlyDaysEnabled) {
      _yearlyDaysCtrl.forward();
    } else {
      _yearlyDaysCtrl.reverse();
    }
  }

  Widget _buildYearlyDaysCard() => AnimatedBuilder(
    animation: _yearlyDaysCtrl,
    builder: (ctx, _) => _card([
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleYearlyDays,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              Text('Days of Week', style: _kRowLabelStyle),
              const Spacer(),
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
                      value: _yearlyDaysEnabled,
                      onChanged: (_) => _toggleYearlyDays(),
                      color: widget.accentColor,
                      height: 31,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      SizeTransition(
        sizeFactor: _yearlyDaysCtrl,
        axisAlignment: 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _sep(),
            SizedBox(
              height: math.max(216.0, _pickerItemExtent * 5.5),
              child: Row(
                children: [
                  Expanded(
                    child: _clipPicker(
                      CupertinoPicker(
                        scrollController: _yearlyPositionCtrl,
                        itemExtent: _pickerItemExtent,
                        backgroundColor: CupertinoColors.transparent,
                        useMagnifier: true,
                        magnification: 2.35 / 2.1,
                        squeeze: 1.25,
                        offAxisFraction: -0.45,
                        selectionOverlay:
                            const CupertinoPickerDefaultSelectionOverlay(
                              capStartEdge: true,
                              capEndEdge: false,
                            ),
                        onSelectedItemChanged: (i) =>
                            setState(() => _yearlyPositionIndex = i),
                        children: _kPositions
                            .map(
                              (p) => Align(
                                alignment: Alignment.centerRight,
                                child: Padding(
                                  padding: const EdgeInsets.only(right: 20),
                                  child: _pickerText(p, Alignment.centerRight),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      capStartEdge: true,
                      capEndEdge: false,
                    ),
                  ),
                  Expanded(
                    child: _clipPicker(
                      CupertinoPicker(
                        scrollController: _yearlyDayCtrl,
                        itemExtent: _pickerItemExtent,
                        backgroundColor: CupertinoColors.transparent,
                        useMagnifier: true,
                        magnification: 2.35 / 2.1,
                        squeeze: 1.25,
                        offAxisFraction: 0.45,
                        selectionOverlay:
                            const CupertinoPickerDefaultSelectionOverlay(
                              capStartEdge: false,
                              capEndEdge: true,
                            ),
                        onSelectedItemChanged: (i) =>
                            setState(() => _yearlyDayIndex = i),
                        children: _kDays
                            .map(
                              (d) => Align(
                                alignment: Alignment.centerLeft,
                                child: Padding(
                                  padding: const EdgeInsets.only(left: 20),
                                  child: _pickerText(d, Alignment.centerLeft),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      capStartEdge: false,
                      capEndEdge: true,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ]),
  );

  // ── Label & save ──────────────────────────────────────────────────────────

  String get _customLabel {
    final prefix = '${widget.subjectLabel} will occur ';
    final text = _footerText;
    final raw = text.startsWith(prefix) ? text.substring(prefix.length) : text;
    final stripped = raw.endsWith('.') ? raw.substring(0, raw.length - 1) : raw;
    return stripped[0].toUpperCase() + stripped.substring(1);
  }

  _NewEventCustomRepeatConfig get _currentConfig => _NewEventCustomRepeatConfig(
    frequency: _frequency,
    everyCount: _everyCount,
    selectedDays: Set.unmodifiable(_selectedDays),
    monthlyMode: _monthlyMode,
    selectedDates: Set.unmodifiable(_selectedDates),
    onThePositionIndex: _onThePositionIndex,
    onTheDayIndex: _onTheDayIndex,
    selectedMonths: Set.unmodifiable(_selectedMonths),
    yearlyDaysEnabled: _yearlyDaysEnabled,
    yearlyPositionIndex: _yearlyPositionIndex,
    yearlyDayIndex: _yearlyDayIndex,
  );

  void _dismiss() =>
      Navigator.of(context).pop<_NewEventCustomRepeatResult?>(null);
  void _save() => Navigator.of(context).pop<_NewEventCustomRepeatResult?>(
    _NewEventCustomRepeatResult(_customLabel, _currentConfig),
  );

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: kModalBackground,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            SizedBox(height: 12.5),
            RoundedCupertinoSheetHeader(
              child: SizedBox(
                height: 40.0,
                width: double.infinity,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Text(
                      'Custom',
                      style: TextStyle(
                        inherit: false,
                        color: resolveThemeColor(kPrimaryLabel, context),
                        fontSize: 17,
                        fontFamily: kSFProText,
                        fontWeight: FontWeight.w600,
                        fontStyle: FontStyle.normal,
                        letterSpacing: kTracking17,
                        height: kLineHeight,
                      ),
                    ),
                    Positioned(
                      left: 16.0,
                      child: _CalModalCircleButton(
                        icon: CupertinoIcons.chevron_left,
                        iconColor: kPrimaryLabel,
                        iconOffset: const Offset(-1.5, 0),
                        tapDelay: const Duration(milliseconds: 130),
                        onTap: _dismiss,
                      ),
                    ),
                    Positioned(
                      right: 16.0,
                      child: _CalModalCircleButton(
                        icon: CupertinoIcons.checkmark,
                        containerColor: widget.accentColor,
                        iconColor: CupertinoColors.white,
                        tapDelay: const Duration(milliseconds: 130),
                        onTap: _save,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── Scrollable content ─────────────────────────────────────
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  math.max(16, systemSafeAreaBottomInset(context)),
                ),
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _everyPickerCtrl,
                        builder: (ctx, _) => _card([
                          _pickerRow(
                            'Frequency',
                            _frequency,
                            items: _makeItems(
                              _kFrequencyOptions,
                              _frequency,
                              (v) => setState(() => _frequency = v),
                              checkmarkColor: widget.accentColor,
                            ),
                          ),
                          _sep(),
                          _pickerRow(
                            'Every',
                            _everyCount == 1
                                ? _everyUnit
                                : '$_everyCount $_everyUnit',
                            showChevron: false,
                            valueColor: widget.accentColor,
                            onTap: _toggleEveryPicker,
                          ),
                          _buildEverySubcard(),
                        ]),
                      ),
                      // Context footer — animate its boundary so cards below
                      // follow multiline growth instead of snapping.
                      AnimatedSize(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment.topCenter,
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              top: 8,
                              left: kModalSheetContextFooterHorizontalInset,
                              right: kModalSheetContextFooterHorizontalInset,
                            ),
                            child: Text(
                              _footerText,
                              style: modalSheetContextFooterStyle(context),
                              textAlign: TextAlign.left,
                            ),
                          ),
                        ),
                      ),
                      if (_frequency == 'Weekly') ...[
                        const SizedBox(height: 18),
                        _buildWeekDaysCard(),
                      ],
                      if (_frequency == 'Monthly') ...[
                        const SizedBox(height: 18),
                        _buildMonthlyUnifiedCard(),
                      ],
                      if (_frequency == 'Yearly') ...[
                        const SizedBox(height: 18),
                        _buildYearlyMonthCard(),
                        const SizedBox(height: 18),
                        _buildYearlyDaysCard(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tinted selection-handle controls ─────────────────────────────────────────
//
// Mirrors the same class in events_tab.dart.  Keeps selection handles
// in sync with the live _categoryColor on every build without remounting
// the text field or disturbing the active selection / keyboard focus.
class _TintedCupertinoTextSelectionControls
    extends CupertinoTextSelectionControls {
  _TintedCupertinoTextSelectionControls(this.color);
  final Color color;

  @override
  Widget buildHandle(
    BuildContext context,
    TextSelectionHandleType type,
    double textLineHeight, [
    VoidCallback? onTap,
  ]) {
    // Wrap in MediaQuery(gestureSettings: kTouchSlop) so the handle's
    // PanGestureRecognizer (which lives in the Overlay, above the sheet's own
    // MediaQuery override) uses the same 18 dp slop as the text field's
    // TapAndDragGestureRecognizer.  Without this, Android's low system slop
    // (≈4–8 dp) lets the handle recognizer win on a near-stationary tap near
    // the handle position and produce spurious selection-drag events.
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        gestureSettings: const DeviceGestureSettings(touchSlop: kTouchSlop),
      ),
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        child: super.buildHandle(context, type, textLineHeight, onTap),
      ),
    );
  }
}
