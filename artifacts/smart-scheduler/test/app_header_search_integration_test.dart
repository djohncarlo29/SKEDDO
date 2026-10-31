import 'package:flutter/cupertino.dart';
import 'package:flutter/painting.dart' show TextPainter;
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass
    show
        GlassMenu,
        GlassMenuItem,
        GlassNavigationShell,
        GlassNavigationShellState;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/app_settings.dart';
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/main.dart';
import 'package:smart_scheduler/tabs/calendar_tab.dart';
import 'package:smart_scheduler/tabs/events_tab.dart';
import 'package:smart_scheduler/tabs/notes_tab.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';
import 'package:smart_scheduler/widgets/floating_tab_pill.dart';
import 'package:smart_scheduler/widgets/header_title_scroller.dart';
import 'package:smart_scheduler/widgets/modal_toolbar_glass_button.dart';
import 'package:smart_scheduler/widgets/search_bar_widget.dart';

Finder _largestTextMatch(WidgetTester tester, String value) {
  final matches = find.text(value).evaluate().toList();
  if (matches.isEmpty) return find.text(value);
  final largest = matches.reduce((left, right) {
    final leftHeight = tester.getSize(find.byWidget(left.widget)).height;
    final rightHeight = tester.getSize(find.byWidget(right.widget)).height;
    return leftHeight >= rightHeight ? left : right;
  });
  return find.byWidget(largest.widget);
}

double _textBaselineY(WidgetTester tester, Finder finder) {
  final widget = tester.widget<Text>(finder);
  final context = tester.element(finder);
  final painter = TextPainter(
    text:
        widget.textSpan ??
        TextSpan(text: widget.data ?? '', style: widget.style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
  )..layout();
  final metrics = painter.computeLineMetrics();
  final baseline = tester.getRect(finder).top +
      (metrics.isEmpty ? 0.0 : metrics.first.baseline);
  painter.dispose();
  return baseline;
}

List<Rect> _visibleMonthDowRects(
  WidgetTester tester,
  Finder calendarFinder,
) {
  const weekdayLabels = {'S', 'M', 'T', 'W', 'F'};
  final baselines = find.descendant(
    of: calendarFinder,
    matching: find.byType(Baseline),
  );
  final rects = <Rect>[];
  for (var index = 0; index < baselines.evaluate().length; index++) {
    final label = find.descendant(
      of: baselines.at(index),
      matching: find.byType(Text),
    );
    if (label.evaluate().isEmpty) continue;
    if (!weekdayLabels.contains(tester.widget<Text>(label.first).data)) {
      continue;
    }
    final rect = tester.getRect(label.first);
    if (rect.left >= 0 && rect.right <= 402 && rect.top < 260) {
      rects.add(rect);
    }
  }
  rects.sort((left, right) => left.left.compareTo(right.left));
  return rects;
}

void main() {
  Future<void> tapToolbarSearch(WidgetTester tester) async {
    // The inline field can also expose "Search" as text; the toolbar action
    // is the final semantics node with this label in the shell tree.
    await tester.tap(find.bySemanticsLabel('Search').last);
  }

  testWidgets(
    'Month DOW aligns to the large-title baseline and settled toolbar',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24, bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final previousDefaultView = appDefaultViewNotifier.value;
      appDefaultViewNotifier.value = 'Month';
      addTearDown(() => appDefaultViewNotifier.value = previousDefaultView);

      await tester.pumpWidget(const SKEDDOApp());
      await tester.pumpAndSettle();
      await tester.tapAt(tester.getCenter(find.text('Calendar').last));
      await tester.pumpAndSettle();

      final calendarFinder = find.byType(CalendarTab);
      final calendar = tester.state<CalendarTabState>(calendarFinder);
      final monthTitle = _largestTextMatch(tester, calendar.headerTitle);
      final monthLabels = _visibleMonthDowRects(tester, calendarFinder);
      expect(monthLabels, hasLength(7));
      for (final label in monthLabels) {
        expect(
          label.top,
          closeTo(_textBaselineY(tester, monthTitle) + 16.0, 0.5),
        );
      }

      final headerPosition = calendar.headerScrollPosition!;
      headerPosition.jumpTo(kAppHeaderTitleCollapseDistance);
      await tester.pumpAndSettle();
      final compactLabels = _visibleMonthDowRects(tester, calendarFinder);
      expect(compactLabels, hasLength(7));
      for (final label in compactLabels) {
        expect(
          label.top,
          closeTo(
            MediaQuery.paddingOf(tester.element(calendarFinder)).top +
                kAppHeaderSettledToolbarCircleBottom +
                16.0,
            0.5,
          ),
        );
      }
    },
  );

  testWidgets('Default View selects the matching Calendar hierarchy', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    appDefaultViewNotifier.value = 'Year';
    await tester.pumpWidget(const SKEDDOApp());
    await tester.pumpAndSettle();

    final calendarLabel = find.text('Calendar').last;
    await tester.tapAt(tester.getCenter(calendarLabel) - const Offset(0, 24));
    await tester.pumpAndSettle();
    final calendarFinder = find.byType(CalendarTab);
    CalendarTabState calendarState() =>
        tester.state<CalendarTabState>(calendarFinder);
    expect(calendarState().view, CalendarView.year);

    const choices = <(String, CalendarView, String?)>[
      ('Month', CalendarView.month, null),
      ('Day', CalendarView.day, 'singleDay'),
      ('Week', CalendarView.day, 'multiDay'),
      ('Year', CalendarView.year, null),
    ];
    for (final (setting, expectedView, expectedSubMode) in choices) {
      appDefaultViewNotifier.value = setting;
      await tester.pumpAndSettle();
      expect(calendarState().view, expectedView, reason: setting);
      if (expectedSubMode != null) {
        expect(
          tester.widget<CalendarTab>(calendarFinder).daySubMode.name,
          expectedSubMode,
          reason: setting,
        );
      }
    }

    await tester.pumpWidget(const SizedBox.shrink());
    appDefaultViewNotifier.value = 'Month';
  });

  testWidgets('real tabs inherit the package title and search collapse stages', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SKEDDOApp());
    await tester.pumpAndSettle();
    final notesFinder = find.byType(NotesTab);
    final notes = tester.state<NotesTabState>(notesFinder);
    final context = tester.element(notesFinder);
    final transition = AppHeaderScrollInsetScope.titleTransitionOf(context)!;
    final searchExtent = searchBarHostRowHeight(context);
    final outer = AppHeaderScrollView.headerPositionFor(
      notes.scrollController,
    )!;
    final firstNoteCard = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_NoteInputCard',
    );
    final expandedCardTop = tester.getTopLeft(firstNoteCard).dy;
    expect(outer.maxScrollExtent, kAppHeaderTitleHeight + searchExtent);
    expect(transition.position, same(outer));
    outer.jumpTo(kAppHeaderTitleHeight);
    await tester.pumpAndSettle();
    expect(transition.collapseProgress, 1);
    expect(transition.searchBarCollapseProgress, 0);
    expect(
      tester.getTopLeft(firstNoteCard).dy,
      lessThan(expandedCardTop - kAppHeaderTitleHeight / 2),
    );
    outer.jumpTo(outer.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(transition.searchBarCollapseProgress, 1);

    for (final tab in ['Events', 'Calendar', 'Home']) {
      await tester.tapAt(tester.getCenter(find.text(tab).last));
      await tester.pumpAndSettle();
      expect(transition.collapseProgress, 1, reason: tab);
      expect(transition.searchBarCollapseProgress, 1, reason: tab);
    }
    expect(outer.pixels, kAppHeaderTitleHeight + searchExtent);
    expect(
      tester.getTopLeft(firstNoteCard).dy,
      closeTo(
        AppHeaderScrollInsetScope.maybeOf(tester.element(notesFinder)) +
            appHeaderCompactContentSpacingForOrientation(
              Orientation.portrait,
            ),
        0.5,
      ),
    );

    // Search may present its own header, but it must not rewrite the
    // collapsed parent state or translate the shell chrome.
    await tapToolbarSearch(tester);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('app-shell-search-toolbar-offset')),
          )
          .transform
          .getTranslation()
          .y,
      closeTo(0, 0.01),
    );
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('app-shell-search-header-offset')),
          )
          .transform
          .getTranslation()
          .y,
      closeTo(0, 0.01),
    );
    expect(transition.collapseProgress, 1);
    expect(transition.searchBarCollapseProgress, 1);
    expect(outer.pixels, kAppHeaderTitleHeight + searchExtent);
    final cancel = tester
        .widgetList<SearchCancelButton>(find.byType(SearchCancelButton))
        .firstWhere((widget) => widget.searchFocused);
    expect(find.byType(ModalToolbarGlassButton), findsWidgets);
    cancel.onTap();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('app-shell-search-toolbar-offset')),
          )
          .transform
          .getTranslation()
          .y,
      closeTo(0, 0.01),
    );
    expect(
      tester
          .widget<Transform>(
            find.byKey(const ValueKey('app-shell-search-header-offset')),
          )
          .transform
          .getTranslation()
          .y,
      closeTo(0, 0.01),
    );
    expect(transition.collapseProgress, 1);
    expect(transition.searchBarCollapseProgress, 1);
    final restoredOuter = AppHeaderScrollView.headerPositionFor(
      notes.scrollController,
    )!;
    expect(restoredOuter.pixels, kAppHeaderTitleHeight + searchExtent);
    for (var cycle = 0; cycle < 3; cycle++) {
      restoredOuter.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(firstNoteCard).dy,
        closeTo(expandedCardTop, 0.5),
      );
      restoredOuter.jumpTo(restoredOuter.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(firstNoteCard).dy,
        closeTo(
          AppHeaderScrollInsetScope.maybeOf(context) +
              appHeaderCompactContentSpacingForOrientation(
                Orientation.portrait,
              ),
          0.5,
        ),
      );
    }

    // Settings keeps its authored expanded inset AND gains the same compact
    // clearance as Notes; its baseline must not replace that clearance.
    await tester.tapAt(const Offset(36, 30));
    await tester.pumpAndSettle();
    final account = find.text('Account').hitTestable();
    expect(account, findsOneWidget);
    final settingsInset = AppHeaderScrollInsetScope.maybeOf(
      tester.element(account),
    );
    expect(
      tester.getTopLeft(account).dy,
      closeTo(
        settingsInset +
            appHeaderCompactContentSpacingForOrientation(
              Orientation.portrait,
            ),
        0.5,
      ),
    );
    expect(
      tester.getTopLeft(account).dy,
      closeTo(tester.getTopLeft(firstNoteCard).dy, 0.5),
    );
    transition.position!.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(account).dy,
      greaterThan(settingsInset + kAppHeaderContentTopSpacing),
    );
    await tester.tap(find.text('Theme').hitTestable().first);
    await tester.pumpAndSettle();
    final firstOption = find
        .byWidgetPredicate(
          (widget) => widget.runtimeType.toString() == '_OptionRow',
        )
        .hitTestable()
        .first;
    expect(
      tester.getTopLeft(firstOption).dy,
      greaterThan(settingsInset + kAppHeaderTitleHeight),
    );
    await tester.timedDragFrom(
      const Offset(200, 450),
      const Offset(0, -200),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(transition.position!.pixels, kAppHeaderTitleCollapseDistance);
    expect(firstOption, findsOneWidget);
    transition.position!.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(firstOption).dy,
      greaterThan(settingsInset + kAppHeaderTitleHeight),
    );

    await tester.tapAt(const Offset(36, 30));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Date Format'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Date Format').hitTestable());
    await tester.pumpAndSettle();
    transition.position!.jumpTo(0);
    await tester.pumpAndSettle();
    expect(find.text('Mirror System Setting'), findsOneWidget);
    expect(find.text('Skeddo App Only'), findsOneWidget);
    final dateFormatSections = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_DateFormatSettingsSection',
    );
    final dateFormatSection = dateFormatSections.last;
    final systemFormatRow = find
        .descendant(
          of: dateFormatSection,
          matching: find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_OptionRow',
          ),
        )
        .first;
    expect(
      tester.getTopLeft(systemFormatRow).dy,
      lessThan(settingsInset + kAppHeaderTitleHeight),
      reason:
          'Date Format should not add an extra top inset beyond the shared '
          'header spacing.',
    );
    expect(
      find.textContaining('Format Example:'),
      findsNothing,
      reason: 'System Date Format does not show the app-only format example.',
    );
    await tester.timedDragFrom(
      const Offset(200, 450),
      const Offset(0, -200),
      const Duration(milliseconds: 300),
    );
    await tester.pumpAndSettle();
    expect(transition.position!.pixels, kAppHeaderTitleCollapseDistance);
    expect(systemFormatRow, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'tab switching from inline and offscreen search clears search before return',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SKEDDOApp());
      await tester.pumpAndSettle();

      final tabBar = find.byType(FloatingTabPill);
      expect(tabBar, findsOneWidget);
      Future<void> tapTabIcon(String label) async {
        final labelCenter = tester.getCenter(find.text(label).last);
        await tester.tapAt(labelCenter - const Offset(0, 24));
        await tester.pumpAndSettle();
      }

      void expectShellChromeAtRest() {
        for (final key in const [
          'app-shell-search-toolbar-offset',
          'app-shell-search-header-offset',
        ]) {
          final transform = tester.widget<Transform>(
            find.byKey(ValueKey<String>(key)),
          );
          expect(
            transform.transform.getTranslation().y,
            closeTo(0, 0.01),
            reason: '$key should not move during off-screen search',
          );
        }
      }

      final searchBar = find.byType(AppSearchBar).first;
      tester.widget<AppSearchBar>(searchBar).onFocusChanged!(true);
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsOneWidget);

      await tapTabIcon('Events');
      expect(tester.widget<FloatingTabPill>(tabBar).selectedIndex, 2);
      expect(find.byType(SearchModeHeader), findsNothing);

      await tapTabIcon('Home');
      expect(tester.widget<FloatingTabPill>(tabBar).selectedIndex, 0);
      expect(find.byType(SearchModeHeader), findsNothing);

      final notes = tester.state<NotesTabState>(find.byType(NotesTab));
      final headerPosition = AppHeaderScrollView.headerPositionFor(
        notes.scrollController,
      )!;
      headerPosition.jumpTo(headerPosition.maxScrollExtent);
      await tester.pumpAndSettle();
      await tapToolbarSearch(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsOneWidget);
      expectShellChromeAtRest();

      await tapTabIcon('Events');
      expect(tester.widget<FloatingTabPill>(tabBar).selectedIndex, 2);
      expect(find.byType(SearchModeHeader), findsNothing);

      await tapTabIcon('Home');
      expect(tester.widget<FloatingTabPill>(tabBar).selectedIndex, 0);
      expect(find.byType(SearchModeHeader), findsNothing);

      final restoredNotes = tester.state<NotesTabState>(find.byType(NotesTab));
      final restoredHeaderPosition = AppHeaderScrollView.headerPositionFor(
        restoredNotes.scrollController,
      )!;
      restoredHeaderPosition.jumpTo(restoredHeaderPosition.maxScrollExtent);
      await tester.pumpAndSettle();
      await tapToolbarSearch(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsOneWidget);
      expectShellChromeAtRest();
      restoredNotes.cancelSearch();
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsNothing);
      expectShellChromeAtRest();

      await tapTabIcon('Calendar');
      await tapToolbarSearch(tester);
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsOneWidget);
      expectShellChromeAtRest();
      await tester.tap(find.byType(SearchCancelButton));
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsNothing);
      expectShellChromeAtRest();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'offscreen Calendar search preserves its expanded parent header',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SKEDDOApp());
      await tester.pumpAndSettle();

      final notes = find.byType(NotesTab);
      final transition = AppHeaderScrollInsetScope.titleTransitionOf(
        tester.element(notes),
      )!;
      final toolbarShell = tester
          .state<navigation_glass.GlassNavigationShellState>(
            find.byType(navigation_glass.GlassNavigationShell),
          );
      final toolbarBeforeSearch = toolbarShell.resolveState();
      expect(toolbarBeforeSearch, isNotNull);
      final initialToolbar = toolbarBeforeSearch!;
      expect(initialToolbar.settled, isTrue);
      expect(transition.collapseProgress, closeTo(0, 0.001));
      expect(transition.searchBarCollapseProgress, closeTo(0, 0.001));

      final calendarLabel = find.text('Calendar').last;
      await tester.tapAt(tester.getCenter(calendarLabel) - const Offset(0, 24));
      await tester.pumpAndSettle();
      final calendarToolbar = toolbarShell.resolveState()!;
      expect(calendarToolbar.settled, isTrue);
      expect(calendarToolbar.to.actions, hasLength(2));
      final calendarOptions = find
          .bySemanticsLabel('Calendar view options')
          .last;
      await tester.tap(calendarOptions);
      await tester.pumpAndSettle();
      final activeMenu = tester.widget<navigation_glass.GlassMenu>(
        find.byType(navigation_glass.GlassMenu).last,
      );
      expect(activeMenu.showItemInteractionHighlight, isFalse);
      expect(
        find.byKey(const ValueKey('glass-menu-selection-pill')),
        findsNothing,
      );
      expect(find.text('Compact'), findsOneWidget);
      final firstLabelLeft = tester.getTopLeft(find.text('Compact')).dx;
      for (final label in const ['Stacked', 'Details', 'List']) {
        expect(
          tester.getTopLeft(find.text(label)).dx,
          closeTo(firstLabelLeft, 0.1),
        );
      }
      final compactText = find.text('Compact');
      final compactRow = find.ancestor(
        of: compactText,
        matching: find.byType(navigation_glass.GlassMenuItem),
      );
      final compactPress = await tester.startGesture(
        tester.getCenter(compactText),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('glass-menu-selection-pill')),
        findsNothing,
      );
      final compactMenuItem = tester.widget<navigation_glass.GlassMenuItem>(
        compactRow.first,
      );
      expect(compactMenuItem.enablePressScale, isFalse);
      expect(compactMenuItem.showInteractionHighlight, isFalse);
      expect(compactMenuItem.isPressed, isFalse);
      final compactRowSurface = find.descendant(
        of: compactRow.first,
        matching: find.byType(AnimatedContainer),
      );
      final rowDecoration =
          tester.widget<AnimatedContainer>(compactRowSurface.first).decoration
              as BoxDecoration;
      expect(rowDecoration.color, const Color(0x00000000));
      await compactPress.cancel();
      await tester.pumpAndSettle();
      final compactLongPress = await tester.startGesture(
        tester.getCenter(compactText),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        find.byKey(const ValueKey('glass-menu-selection-pill')),
        findsNothing,
      );
      await compactLongPress.cancel();
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('glass-menu-selection-pill')),
        findsNothing,
      );
      await tester.tapAt(const Offset(201, 600));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(transition.collapseProgress, closeTo(0, 0.001));
      expect(transition.searchBarCollapseProgress, closeTo(0, 0.001));

      final parentHeaderPosition = transition.position!;
      final parentHeaderPixels = parentHeaderPosition.pixels;
      await tapToolbarSearch(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.byType(SearchModeHeader), findsOneWidget);
      final searchHeader = find.byType(SearchModeHeader);
      final safeAreaSearchBackground = find.byKey(
        const ValueKey('offscreen-search-safe-area-background'),
      );
      expect(safeAreaSearchBackground, findsOneWidget);
      expect(tester.getTopLeft(safeAreaSearchBackground).dy, 0);
      expect(
        tester.widget<ColoredBox>(safeAreaSearchBackground).color,
        resolveThemeColor(kBackgroundColor, tester.element(searchHeader)),
      );
      expect(
        find.byKey(const ValueKey('offscreen-search-tabbar-background')),
        findsNothing,
      );
      expect(
        tester.getBottomRight(safeAreaSearchBackground).dy,
        closeTo(tester.view.physicalSize.height, 0.5),
      );
      expect(find.byType(FloatingTabPill), findsOneWidget);
      expect(
        tester
            .widget<FloatingTabPill>(find.byType(FloatingTabPill))
            .selectedIndex,
        1,
      );
      expect(
        tester.getTopLeft(searchHeader).dy,
        closeTo(MediaQuery.paddingOf(tester.element(searchHeader)).top, 0.5),
      );
      final toolbarDuringSearch = toolbarShell.resolveState();
      expect(
        toolbarDuringSearch == null || toolbarDuringSearch.settled,
        isTrue,
        reason: 'Offscreen search must not start a toolbar morph.',
      );
      await tester.pumpAndSettle();
      expect(transition.collapseProgress, closeTo(0, 0.001));
      expect(transition.searchBarCollapseProgress, closeTo(0, 0.001));
      expect(parentHeaderPosition.pixels, closeTo(parentHeaderPixels, 0.5));

      final cancel = tester
          .widgetList<SearchCancelButton>(find.byType(SearchCancelButton))
          .firstWhere((button) => button.searchFocused);
      cancel.onTap();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));
      final toolbarDuringExit = toolbarShell.resolveState();
      expect(
        toolbarDuringExit == null || toolbarDuringExit.settled,
        isTrue,
        reason: 'Closing offscreen search must not start a toolbar morph.',
      );
      await tester.pumpAndSettle();

      expect(find.byType(SearchModeHeader), findsNothing);
      final toolbarAfterSearch = toolbarShell.resolveState();
      expect(toolbarAfterSearch, isNotNull);
      expect(
        toolbarAfterSearch!.settled,
        isTrue,
        reason: 'Closing offscreen search must not rematerialize the toolbar.',
      );
      expect(
        toolbarAfterSearch.to.leading,
        hasLength(calendarToolbar.to.leading.length),
      );
      expect(
        toolbarAfterSearch.to.actions,
        hasLength(calendarToolbar.to.actions.length),
      );
      expect(transition.collapseProgress, closeTo(0, 0.001));
      expect(transition.searchBarCollapseProgress, closeTo(0, 0.001));
      expect(parentHeaderPosition.pixels, closeTo(parentHeaderPixels, 0.5));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'repeated offscreen Events searches preserve the parent body offset',
    (tester) async {
      void drainKnownGridRoundingOverflow() {
        FlutterError? overflow;
        while (true) {
          final error = tester.takeException();
          if (error == null) break;
          expect(error, isA<FlutterError>());
          overflow = error as FlutterError;
        }
        if (overflow != null) {
          expect(
            overflow.toString(),
            'A RenderFlex overflowed by 0.500 pixels on the bottom.',
          );
        }
      }

      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(402, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SKEDDOApp());
      await tester.pumpAndSettle();

      final eventsLabel = find.text('Events').last;
      await tester.tapAt(tester.getCenter(eventsLabel) - const Offset(0, 24));
      await tester.pumpAndSettle();
      drainKnownGridRoundingOverflow();

      final events = tester.state<EventsTabState>(find.byType(EventsTab));
      final scrollController = events.scrollController;
      expect(scrollController.hasClients, isTrue);
      expect(scrollController.position.maxScrollExtent, greaterThan(0));
      final eventsTab = find.byType(EventsTab);
      await tester.drag(eventsTab, const Offset(0, -900));
      await tester.pumpAndSettle();
      drainKnownGridRoundingOverflow();
      await tester.drag(eventsTab, const Offset(0, -900));
      await tester.pumpAndSettle();
      drainKnownGridRoundingOverflow();
      final originalOffset = scrollController.offset;
      expect(
        originalOffset,
        greaterThan(scrollController.position.maxScrollExtent * 0.75),
        reason: 'The test must begin from a deeply scrolled Events page.',
      );
      final headerPosition = AppHeaderScrollView.headerPositionFor(
        scrollController,
      )!;
      final originalHeaderOffset = headerPosition.pixels;

      for (var cycle = 0; cycle < 3; cycle++) {
        await tapToolbarSearch(tester);
        await tester.pumpAndSettle();
        drainKnownGridRoundingOverflow();
        expect(
          scrollController.offset,
          closeTo(originalOffset, 0.5),
          reason: 'Entering offscreen search changed the Events page.',
        );
        expect(
          headerPosition.pixels,
          closeTo(originalHeaderOffset, 0.5),
          reason: 'Entering offscreen search changed the shared header.',
        );
        final searchHeader = find.byType(SearchModeHeader);
        expect(searchHeader, findsOneWidget);
        expect(
          tester.getTopLeft(searchHeader).dy,
          closeTo(MediaQuery.paddingOf(tester.element(searchHeader)).top, 0.5),
        );
        // The native keyboard resizes the viewport while offscreen search is
        // active. Reproduce its animated dismissal after cancelling.
        tester.view.viewInsets = const FakeViewPadding(bottom: 320);
        await tester.pumpAndSettle();
        expect(
          scrollController.offset,
          closeTo(originalOffset, 0.5),
          reason: 'The search keyboard changed the covered Events page.',
        );
        expect(
          headerPosition.pixels,
          closeTo(originalHeaderOffset, 0.5),
          reason: 'The search keyboard changed the shared header.',
        );
        final cancel = tester
            .widgetList<SearchCancelButton>(find.byType(SearchCancelButton))
            .firstWhere((button) => button.searchFocused);
        cancel.onTap();
        for (final keyboardInset in [240.0, 160.0, 80.0, 0.0]) {
          tester.view.viewInsets = FakeViewPadding(bottom: keyboardInset);
          await tester.pump(const Duration(milliseconds: 40));
        }
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpAndSettle();
        drainKnownGridRoundingOverflow();
        expect(
          scrollController.offset,
          closeTo(originalOffset, 0.5),
          reason: 'Offscreen search cycle ${cycle + 1} moved the Events page.',
        );
        expect(
          headerPosition.pixels,
          closeTo(originalHeaderOffset, 0.5),
          reason: 'Offscreen search cycle ${cycle + 1} moved the header.',
        );
      }
      drainKnownGridRoundingOverflow();
    },
  );

  testWidgets('today Day View title stays accented in day-first format', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'app_date_format': AppDateFormat.dayMonthYearDot.name,
      'app_date_format_uses_system': false,
    });
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SKEDDOApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Calendar').last, warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.byType(CalendarTab).hitTestable(), findsOneWidget);
    final calendar = tester.state<CalendarTabState>(find.byType(CalendarTab));
    await calendar.enterTodayDay();
    await tester.pumpAndSettle();

    final expectedTitle = formatAppDateMedium(
      DateTime.now(),
      includeYear: false,
    );
    final titleScroller = find
        .byWidgetPredicate(
          (widget) =>
              widget is HeaderTitleScroller && widget.title == expectedTitle,
        )
        .first;
    final titleTextFinder = find.descendant(
      of: titleScroller,
      matching: find.text(expectedTitle),
    );
    expect(titleTextFinder, findsOneWidget);
    final titleText = tester.widget<Text>(titleTextFinder);
    expect(
      titleText.style?.color,
      resolveAccentColor(tester.element(titleTextFinder)),
    );
  });

  testWidgets('You toolbar opens offscreen search without leaving You', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SKEDDOApp());
    await tester.pumpAndSettle();

    final tabBar = find.byType(FloatingTabPill);
    await tester.tapAt(
      tester.getCenter(find.text('You').last) - const Offset(0, 24),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<FloatingTabPill>(tabBar).selectedIndex, 3);

    final toolbarShell = tester
        .state<navigation_glass.GlassNavigationShellState>(
          find.byType(navigation_glass.GlassNavigationShell),
        );
    expect(toolbarShell.resolveState()!.to.actions, hasLength(1));

    await tapToolbarSearch(tester);
    await tester.pumpAndSettle();
    expect(find.byType(SearchModeHeader), findsOneWidget);
    expect(
      find.byKey(const ValueKey('offscreen-search-safe-area-background')),
      findsOneWidget,
    );
    expect(tester.widget<FloatingTabPill>(tabBar).selectedIndex, 3);

    final cancel = tester
        .widgetList<SearchCancelButton>(find.byType(SearchCancelButton))
        .lastWhere((button) => button.searchFocused);
    cancel.onTap();
    await tester.pumpAndSettle();

    expect(find.byType(SearchModeHeader), findsNothing);
    expect(tester.widget<FloatingTabPill>(tabBar).selectedIndex, 3);
    expect(tester.takeException(), isNull);
  });
}
