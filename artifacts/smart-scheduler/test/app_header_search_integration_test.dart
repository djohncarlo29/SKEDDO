import 'package:flutter/cupertino.dart';
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

void main() {
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
    final expandedCardTop =
        AppHeaderScrollInsetScope.maybeOf(context) +
        kAppHeaderTitleHeight +
        searchExtent;
    expect(tester.getTopLeft(firstNoteCard).dy, closeTo(expandedCardTop, 0.5));
    expect(outer.maxScrollExtent, kAppHeaderTitleHeight + searchExtent);
    expect(transition.position, same(outer));
    outer.jumpTo(kAppHeaderTitleHeight);
    await tester.pumpAndSettle();
    expect(transition.collapseProgress, 1);
    expect(transition.searchBarCollapseProgress, 0);
    expect(
      tester.getTopLeft(firstNoteCard).dy,
      closeTo(expandedCardTop - kAppHeaderTitleHeight, 0.5),
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
        AppHeaderScrollInsetScope.maybeOf(tester.element(notesFinder)) + 16,
        0.5,
      ),
    );

    // Search may present its own header, but it must not rewrite the
    // collapsed parent state or translate the shell chrome.
    await tester.tapAt(const Offset(366, 30));
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
        closeTo(AppHeaderScrollInsetScope.maybeOf(context) + 16, 0.5),
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
      closeTo(settingsInset + kAppHeaderContentTopSpacing, 0.5),
    );
    expect(
      tester.getTopLeft(account).dy,
      closeTo(tester.getTopLeft(firstNoteCard).dy, 0.5),
    );
    transition.position!.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(account).dy,
      closeTo(settingsInset + kAppHeaderTitleHeight, 0.5),
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
    final formatFooter = tester.widget<Text>(
      find.textContaining('Format Example:'),
    );
    expect(
      formatFooter.data,
      contains(
        'This setting will apply in Skeddo only. Other apps will use the system setting.\n\nFormat Example:',
      ),
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
      await tester.tapAt(const Offset(366, 30));
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
      await tester.tapAt(const Offset(366, 30));
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsOneWidget);
      expectShellChromeAtRest();
      restoredNotes.cancelSearch();
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsNothing);
      expectShellChromeAtRest();

      await tapTabIcon('Calendar');
      await tester.tapAt(const Offset(366, 30));
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
      expect(activeMenu.showSelectionPill, isFalse);
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
      final compactMenuItem = tester.widget<navigation_glass.GlassMenuItem>(
        compactRow.first,
      );
      expect(compactMenuItem.isPressed, isTrue);
      await compactPress.cancel();
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(201, 600));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(transition.collapseProgress, closeTo(0, 0.001));
      expect(transition.searchBarCollapseProgress, closeTo(0, 0.001));

      final parentHeaderPosition = transition.position!;
      final parentHeaderPixels = parentHeaderPosition.pixels;
      await tester.tapAt(const Offset(366, 30));
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
        await tester.tapAt(const Offset(366, 30));
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

    await tester.tapAt(const Offset(366, 30));
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
