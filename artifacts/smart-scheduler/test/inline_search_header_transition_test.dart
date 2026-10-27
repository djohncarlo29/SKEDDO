import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/main.dart';
import 'package:smart_scheduler/widgets/search_bar_widget.dart';

Future<void> verifyInlineSearchMotion(WidgetTester tester) async {
  final searchBar = find.byType(AppSearchBar);
  expect(searchBar, findsOneWidget);
  final searchBarState = tester.state<AppSearchBarState>(searchBar);
  final initialTop = tester.getTopLeft(searchBar).dy;

  tester.widget<AppSearchBar>(searchBar).onFocusChanged!(true);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  expect(find.byType(SearchModeHeader), findsNothing);
  expect(searchBar, findsOneWidget);
  expect(tester.state<AppSearchBarState>(searchBar), same(searchBarState));
  final enteringTop = tester.getTopLeft(searchBar).dy;
  expect(enteringTop, lessThan(initialTop));
  expect(tester.getSize(searchBar).height, greaterThan(0));

  await tester.pumpAndSettle();
  final searchTop = tester.getTopLeft(searchBar).dy;
  expect(searchTop, lessThan(enteringTop));

  final cancel = tester
      .widgetList<SearchCancelButton>(find.byType(SearchCancelButton))
      .firstWhere((button) => button.searchFocused);
  cancel.onTap();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));

  expect(searchBar, findsOneWidget);
  expect(tester.state<AppSearchBarState>(searchBar), same(searchBarState));
  final exitingTop = tester.getTopLeft(searchBar).dy;
  expect(exitingTop, greaterThan(searchTop));

  await tester.pumpAndSettle();
  expect(tester.getTopLeft(searchBar).dy, closeTo(initialTop, 0.5));
}

void main() {
  testWidgets(
    'inline search bar stays mounted while the shared header moves it on Notes and Events',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(402, 874);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(const SKEDDOApp());
      await tester.pumpAndSettle();

      await verifyInlineSearchMotion(tester);
      await tester.tap(find.text('Events').last);
      await tester.pumpAndSettle();
      await verifyInlineSearchMotion(tester);
      expect(tester.takeException(), isNull);
    },
  );
}
