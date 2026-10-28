import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/main.dart';
import 'package:smart_scheduler/tabs/calendar_tab.dart';
import 'package:smart_scheduler/tabs/events_tab.dart';
import 'package:smart_scheduler/tabs/notes_tab.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';
import 'package:smart_scheduler/widgets/floating_tab_pill.dart';
import 'package:smart_scheduler/widgets/modal_toolbar_glass_button.dart';
import 'package:smart_scheduler/widgets/search_bar_widget.dart';
import 'package:smart_scheduler/widgets/app_shell_toolbar.dart';

void main() {
  testWidgets(
    'real tabs inherit the package title and search collapse stages',
    (tester) async {
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
      expect(
        tester.getTopLeft(firstNoteCard).dy,
        closeTo(expandedCardTop, 0.5),
      );
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

      // Opening and cancelling search must not reopen its collapsed parent bar.
      await tester.tapAt(const Offset(323, 30));
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
        closeTo(settingsInset + kAppHeaderTitleHeight, 0.5),
      );
      await tester.timedDragFrom(
        const Offset(200, 450),
        const Offset(0, -200),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(transition.position!.pixels, kAppHeaderTitleCollapseDistance);
      expect(
        tester.getTopLeft(firstOption).dy,
        closeTo(settingsInset + kAppHeaderContentTopSpacing, 0.5),
      );
      transition.position!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(firstOption).dy,
        closeTo(settingsInset + kAppHeaderTitleHeight, 0.5),
      );

      await tester.tapAt(const Offset(36, 30));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Date Format'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Date Format').hitTestable());
      await tester.pumpAndSettle();
      transition.position!.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(firstOption).dy,
        closeTo(settingsInset + kAppHeaderTitleHeight, 0.5),
      );
      await tester.timedDragFrom(
        const Offset(200, 450),
        const Offset(0, -200),
        const Duration(milliseconds: 300),
      );
      await tester.pumpAndSettle();
      expect(transition.position!.pixels, kAppHeaderTitleCollapseDistance);
      expect(
        tester.getTopLeft(firstOption).dy,
        closeTo(settingsInset + kAppHeaderContentTopSpacing, 0.5),
      );
      expect(tester.takeException(), isNull);
    },
  );

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

      final searchBar = find.byType(AppSearchBar).first;
      tester.widget<AppSearchBar>(searchBar).onFocusChanged!(true);
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Notes search entry');

      await tapTabIcon('Events');
      expect(tester.widget<FloatingTabPill>(tabBar).selectedIndex, 2);
      expect(find.byType(SearchModeHeader), findsNothing);

      await tester.tapAt(const Offset(323, 30));
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsOneWidget);
      expect(find.byType(AppShellPinnedToolbar), findsNothing);
      await tester.tap(find.bySemanticsLabel('Cancel search'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsNothing);
      expect(tester.takeException(), isNull, reason: 'Events search cancel');

      await tapTabIcon('Home');
      expect(tester.widget<FloatingTabPill>(tabBar).selectedIndex, 0);
      expect(find.byType(SearchModeHeader), findsNothing);

      final notes = tester.state<NotesTabState>(find.byType(NotesTab));
      final headerPosition = AppHeaderScrollView.headerPositionFor(
        notes.scrollController,
      )!;
      headerPosition.jumpTo(headerPosition.maxScrollExtent);
      await tester.pumpAndSettle();
      final notesContext = tester.element(find.byType(NotesTab));
      final headerInsetBeforeOffscreenSearch =
          AppHeaderScrollInsetScope.maybeOf(notesContext);
      final parentOffsetBeforeOffscreenSearch = notes.scrollController.offset;
      await tester.tapAt(const Offset(323, 30));
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsOneWidget);
      expect(find.byType(AppShellPinnedToolbar), findsNothing);
      final shellSearchTransform = tester.widget<Transform>(
        find.byKey(const ValueKey('app-shell-search-toolbar-offset')),
      );
      expect(
        shellSearchTransform.transform.getTranslation().y,
        closeTo(0, 0.01),
        reason: 'Off-screen search must not slide the shared toolbar.',
      );
      expect(
        AppHeaderScrollInsetScope.maybeOf(
          tester.element(find.byType(NotesTab)),
        ),
        closeTo(headerInsetBeforeOffscreenSearch, 0.01),
        reason: 'Off-screen search must not change the parent layout.',
      );
      expect(find.byType(AppHeaderScrollEdge), findsNothing);
      expect(
        tester.getTopLeft(find.byType(SearchModeHeader)).dy,
        closeTo(MediaQuery.paddingOf(notesContext).top, 0.01),
      );

      final cancelFinder = find.bySemanticsLabel('Cancel search');
      await tester.tap(cancelFinder);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsNothing);
      expect(
        tester
            .widget<Transform>(
              find.byKey(const ValueKey('app-shell-search-toolbar-offset')),
            )
            .transform
            .getTranslation()
            .y,
        closeTo(0, 0.01),
        reason: 'Exiting off-screen search must not move the shared toolbar.',
      );
      expect(
        notes.scrollController.offset,
        closeTo(parentOffsetBeforeOffscreenSearch, 0.01),
        reason: 'Off-screen search must restore the original parent position.',
      );
      expect(
        AppHeaderScrollInsetScope.maybeOf(
          tester.element(find.byType(NotesTab)),
        ),
        closeTo(headerInsetBeforeOffscreenSearch, 0.01),
      );
      expect(tester.takeException(), isNull, reason: 'Notes search exit');

      await tester.tapAt(const Offset(323, 30));
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Calendar search entry');

      await tapTabIcon('Events');
      expect(tester.widget<FloatingTabPill>(tabBar).selectedIndex, 2);
      expect(find.byType(SearchModeHeader), findsNothing);

      await tapTabIcon('Home');
      expect(tester.widget<FloatingTabPill>(tabBar).selectedIndex, 0);
      expect(find.byType(SearchModeHeader), findsNothing);

      await tapTabIcon('Calendar');
      final calendarInsetBeforeSearch = AppHeaderScrollInsetScope.maybeOf(
        tester.element(find.byType(CalendarTab)),
      );
      await tester.tapAt(const Offset(323, 30));
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsOneWidget);
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
        AppHeaderScrollInsetScope.maybeOf(
          tester.element(find.byType(CalendarTab)),
        ),
        closeTo(calendarInsetBeforeSearch, 0.01),
      );
      expect(find.byType(AppHeaderScrollEdge), findsNothing);
      expect(
        tester.getTopLeft(find.byType(SearchModeHeader)).dy,
        closeTo(
          MediaQuery.paddingOf(tester.element(find.byType(CalendarTab))).top,
          0.01,
        ),
      );
      await tester.tap(find.bySemanticsLabel('Cancel search'));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsNothing);
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
        AppHeaderScrollInsetScope.maybeOf(
          tester.element(find.byType(CalendarTab)),
        ),
        closeTo(calendarInsetBeforeSearch, 0.01),
      );
      expect(tester.takeException(), isNull, reason: 'Calendar search exit');

      await tapTabIcon('Events');
      final events = tester.state<EventsTabState>(find.byType(EventsTab));
      final eventsHeaderPosition = AppHeaderScrollView.headerPositionFor(
        events.scrollController,
      )!;
      eventsHeaderPosition.jumpTo(eventsHeaderPosition.maxScrollExtent);
      await tester.pumpAndSettle();
      final eventsInsetBeforeSearch = AppHeaderScrollInsetScope.maybeOf(
        tester.element(find.byType(EventsTab)),
      );
      final eventsOffsetBeforeSearch = events.scrollController.offset;
      await tester.tapAt(const Offset(323, 30));
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'Events search entry');
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
        AppHeaderScrollInsetScope.maybeOf(
          tester.element(find.byType(EventsTab)),
        ),
        closeTo(eventsInsetBeforeSearch, 0.01),
      );
      expect(find.byType(AppHeaderScrollEdge), findsNothing);
      expect(
        tester.getTopLeft(find.byType(SearchModeHeader)).dy,
        closeTo(
          MediaQuery.paddingOf(tester.element(find.byType(EventsTab))).top,
          0.01,
        ),
      );
      tester
          .widgetList<SearchCancelButton>(find.byType(SearchCancelButton))
          .firstWhere((widget) => widget.searchFocused)
          .onTap();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsNothing);
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
      expect(events.scrollController.offset, closeTo(eventsOffsetBeforeSearch, 0.01));
      expect(
        AppHeaderScrollInsetScope.maybeOf(
          tester.element(find.byType(EventsTab)),
        ),
        closeTo(eventsInsetBeforeSearch, 0.01),
      );
      expect(tester.takeException(), isNull, reason: 'Events search exit');
    },
  );
}
