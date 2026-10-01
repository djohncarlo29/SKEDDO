import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/search_bar_widget.dart';

void main() {
  testWidgets('preserves search text and focus when orientation changes', (
    tester,
  ) async {
    Widget buildApp(Size size, EdgeInsets viewPadding) {
      return CupertinoApp(
        home: const CupertinoPageScaffold(child: _SearchHarness()),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: size,
            padding: viewPadding,
            viewPadding: viewPadding,
          ),
          child: AppWindowContentBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      buildApp(const Size(390, 844), const EdgeInsets.only(bottom: 34)),
    );
    final searchField = find.byType(CupertinoTextField);
    await tester.enterText(searchField, 'find this note');
    await tester.pump();
    final focusBeforeRotation = FocusManager.instance.primaryFocus;
    expect(focusBeforeRotation, isNotNull);
    expect(focusBeforeRotation!.hasFocus, isTrue);

    await tester.pumpWidget(
      buildApp(const Size(844, 390), const EdgeInsets.only(left: 28)),
    );
    await tester.pump();
    var searchBar = tester.widget<AppSearchBar>(find.byType(AppSearchBar));
    expect(searchBar.controller.text, 'find this note');
    expect(FocusManager.instance.primaryFocus, same(focusBeforeRotation));

    await tester.pumpWidget(
      buildApp(const Size(390, 844), const EdgeInsets.only(bottom: 34)),
    );
    await tester.pump();
    searchBar = tester.widget<AppSearchBar>(find.byType(AppSearchBar));
    expect(searchBar.controller.text, 'find this note');
    expect(FocusManager.instance.primaryFocus, same(focusBeforeRotation));
  });
}

class _SearchHarness extends StatefulWidget {
  const _SearchHarness();

  @override
  State<_SearchHarness> createState() => _SearchHarnessState();
}

class _SearchHarnessState extends State<_SearchHarness> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppWindowContentPadding(
      child: Center(
        child: SizedBox(
          width: 320,
          height: 60,
          child: AppSearchBar(controller: _controller),
        ),
      ),
    );
  }
}
