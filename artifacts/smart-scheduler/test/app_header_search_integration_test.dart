import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/main.dart';
import 'package:smart_scheduler/tabs/notes_tab.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';
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
    final outer = AppHeaderScrollView.headerPositionFor(notes.scrollController)!;
    final firstNoteCard = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_NoteInputCard',
    );
    final expandedCardTop = AppHeaderScrollInsetScope.maybeOf(context) +
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

    for (final tab in ['Events', 'Calendar', 'Notes']) {
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
    final headerSearch = tester
        .widgetList<AnimatedTapIcon>(find.byType(AnimatedTapIcon))
        .firstWhere((widget) =>
            widget.padding == const EdgeInsets.fromLTRB(18, 10, 4, 0));
    headerSearch.onTap!();
    await tester.pumpAndSettle();
    final cancel = tester
        .widgetList<SearchCancelButton>(find.byType(SearchCancelButton))
        .firstWhere((widget) => widget.searchFocused);
    cancel.onTap();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(transition.collapseProgress, 1);
    expect(transition.searchBarCollapseProgress, 1);
    final restoredOuter =
        AppHeaderScrollView.headerPositionFor(notes.scrollController)!;
    expect(restoredOuter.pixels, kAppHeaderTitleHeight + searchExtent);
    for (var cycle = 0; cycle < 3; cycle++) {
      restoredOuter.jumpTo(0);
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(firstNoteCard).dy, closeTo(expandedCardTop, 0.5));
      restoredOuter.jumpTo(restoredOuter.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(firstNoteCard).dy,
        closeTo(AppHeaderScrollInsetScope.maybeOf(context) + 16, 0.5),
      );
    }

    // Settings and its pushed subscreen keep their existing expanded inset,
    // and must not add a second copy when inheriting compact state.
    await tester.tapAt(const Offset(36, 30));
    await tester.pumpAndSettle();
    final account = find.text('Account').hitTestable();
    expect(account, findsOneWidget);
    final settingsInset = AppHeaderScrollInsetScope.maybeOf(tester.element(account));
    expect(tester.getTopLeft(account).dy, closeTo(settingsInset, 0.5));
    transition.position!.jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(account).dy,
      closeTo(settingsInset + kAppHeaderTitleHeight, 0.5),
    );
    await tester.tap(find.text('Theme').hitTestable().first);
    await tester.pumpAndSettle();
    final firstOption = find.byWidgetPredicate(
      (widget) => widget.runtimeType.toString() == '_OptionRow',
    ).hitTestable().first;
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
    expect(tester.getTopLeft(firstOption).dy, closeTo(settingsInset, 0.5));
    expect(tester.takeException(), isNull);
  });
}
