import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/main.dart';
import 'package:smart_scheduler/tabs/notes_tab.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';
import 'package:smart_scheduler/widgets/floating_tab_pill.dart';
import 'package:smart_scheduler/widgets/modal_toolbar_glass_button.dart';
import 'package:smart_scheduler/widgets/search_bar_widget.dart';

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

      // Search may present its own header, but it must not rewrite the
      // collapsed parent state or translate the shell chrome.
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
      await tester.tapAt(const Offset(323, 30));
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsOneWidget);
      expectShellChromeAtRest();

      await tapTabIcon('Events');
      expect(tester.widget<FloatingTabPill>(tabBar).selectedIndex, 2);
      expect(find.byType(SearchModeHeader), findsNothing);

      await tapTabIcon('Home');
      expect(tester.widget<FloatingTabPill>(tabBar).selectedIndex, 0);
      expect(find.byType(SearchModeHeader), findsNothing);

      final restoredNotes = tester.state<NotesTabState>(
        find.byType(NotesTab),
      );
      final restoredHeaderPosition = AppHeaderScrollView.headerPositionFor(
        restoredNotes.scrollController,
      )!;
      restoredHeaderPosition.jumpTo(restoredHeaderPosition.maxScrollExtent);
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(323, 30));
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsOneWidget);
      expectShellChromeAtRest();
      restoredNotes.cancelSearch();
      await tester.pumpAndSettle();
      expect(find.byType(SearchModeHeader), findsNothing);
      expectShellChromeAtRest();

      await tapTabIcon('Calendar');
      await tester.tapAt(const Offset(323, 30));
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
      expect(transition.collapseProgress, closeTo(0, 0.001));
      expect(transition.searchBarCollapseProgress, closeTo(0, 0.001));

      final calendarLabel = find.text('Calendar').last;
      await tester.tapAt(tester.getCenter(calendarLabel) - const Offset(0, 24));
      await tester.pumpAndSettle();
      expect(transition.collapseProgress, closeTo(0, 0.001));
      expect(transition.searchBarCollapseProgress, closeTo(0, 0.001));

      final parentHeaderPosition = transition.position!;
      final parentHeaderPixels = parentHeaderPosition.pixels;
      await tester.tapAt(const Offset(323, 30));
      await tester.pumpAndSettle();

      expect(find.byType(SearchModeHeader), findsOneWidget);
      expect(transition.collapseProgress, closeTo(0, 0.001));
      expect(transition.searchBarCollapseProgress, closeTo(0, 0.001));
      expect(parentHeaderPosition.pixels, closeTo(parentHeaderPixels, 0.5));

      final cancel = tester
          .widgetList<SearchCancelButton>(find.byType(SearchCancelButton))
          .firstWhere((button) => button.searchFocused);
      cancel.onTap();
      await tester.pumpAndSettle();

      expect(find.byType(SearchModeHeader), findsNothing);
      expect(transition.collapseProgress, closeTo(0, 0.001));
      expect(transition.searchBarCollapseProgress, closeTo(0, 0.001));
      expect(parentHeaderPosition.pixels, closeTo(parentHeaderPixels, 0.5));
      expect(tester.takeException(), isNull);
    },
  );
}
