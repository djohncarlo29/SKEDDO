import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';

void main() {
  testWidgets('short body has only the outer header collapse travel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bodyController = ScrollController();
    addTearDown(bodyController.dispose);
    await tester.pumpWidget(
      CupertinoApp(
        home: AppHeaderScrollInsetScope(
          leadingInset: kAppHeaderToolbarHeight,
          titleCollapseExtent: kAppHeaderTitleCollapseDistance,
          child: Padding(
            padding: const EdgeInsets.only(top: kAppHeaderToolbarHeight),
            child: AppHeaderScrollView(
              controller: bodyController,
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              slivers: const [
                SliverToBoxAdapter(child: AppHeaderScrollInset()),
                SliverToBoxAdapter(
                  child: SizedBox(key: ValueKey('body'), height: 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final outer = AppHeaderScrollView.headerPositionFor(bodyController)!;
    expect(bodyController.hasClients, isTrue);
    expect(bodyController.position.maxScrollExtent, 0);
    expect(outer.maxScrollExtent, kAppHeaderTitleCollapseDistance);
    final expandedViewportHeight = bodyController.position.viewportDimension;
    final expandedTop = tester.getTopLeft(find.byKey(const ValueKey('body'))).dy;
    await tester.drag(find.byType(NestedScrollView), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(outer.pixels, kAppHeaderTitleCollapseDistance);
    expect(
      bodyController.position.viewportDimension,
      expandedViewportHeight + kAppHeaderTitleCollapseDistance,
    );
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
      closeTo(expandedTop - kAppHeaderTitleCollapseDistance, 0.5),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(outer.pixels, kAppHeaderTitleCollapseDistance);
    for (var cycle = 0; cycle < 10; cycle++) {
      outer.jumpTo(0);
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
        expandedTop,
      );
      outer.jumpTo(kAppHeaderTitleCollapseDistance);
      await tester.pump();
      expect(bodyController.position.maxScrollExtent, 0);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
        expandedTop - kAppHeaderTitleCollapseDistance,
      );
    }
    outer.jumpTo(kAppHeaderTitleCollapseDistance / 2);
    AppHeaderScrollView.jumpBodyTo(bodyController, 0);
    await tester.pump();
    expect(outer.pixels, kAppHeaderTitleCollapseDistance / 2);
  });
}
