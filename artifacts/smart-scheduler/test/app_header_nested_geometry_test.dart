import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';

void main() {
  testWidgets('Settings and regular pages share compact clearance while preserving expanded spacing', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final declaresExistingSpacing in [false, true]) {
      final controller = ScrollController();
      await tester.pumpWidget(CupertinoApp(
        home: AppHeaderScrollInsetScope(
          leadingInset: kAppHeaderToolbarHeight,
          titleCollapseExtent: kAppHeaderTitleHeight,
          child: Padding(
            padding: const EdgeInsets.only(top: kAppHeaderToolbarHeight),
            child: AppHeaderScrollView(
              controller: controller,
              topExtension: kAppHeaderContentTopSpacing,
              slivers: [
                const SliverToBoxAdapter(child: AppHeaderScrollInset()),
                if (declaresExistingSpacing)
                  const SliverToBoxAdapter(child: AppHeaderContentSpacing()),
                SliverPadding(
                  padding: EdgeInsets.only(
                    top: declaresExistingSpacing ? 0 : 16,
                  ),
                  sliver: const SliverToBoxAdapter(
                    child: SizedBox(key: ValueKey('first-card'), height: 2000),
                  ),
                ),
              ],
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      final outer = AppHeaderScrollView.headerPositionFor(controller)!;
      final expandedTop =
          kAppHeaderToolbarHeight +
          kAppHeaderTitleHeight +
          kAppHeaderExpandedTitleDownshift;
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('first-card'))).dy,
        expandedTop,
      );
      outer.jumpTo(kAppHeaderTitleHeight / 2);
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('first-card'))).dy,
        closeTo(
          expandedTop -
              kAppHeaderTitleHeight / 2 +
              8.0 -
              kAppHeaderExpandedTitleDownshift / 2,
          1e-6,
        ),
      );
      outer.jumpTo(outer.maxScrollExtent);
      await tester.pump();
      expect(outer.maxScrollExtent, kAppHeaderTitleHeight);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('first-card'))).dy,
        kAppHeaderToolbarHeight + 16,
      );
      controller.jumpTo(16);
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('first-card'))).dy,
        kAppHeaderToolbarHeight,
      );
      expect(outer.pixels, kAppHeaderTitleHeight);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('package phases collapse title before search and release both extents', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final bodyController = ScrollController();
    final transition = AppHeaderTitleTransition();
    addTearDown(() {
      transition.dispose();
      bodyController.dispose();
    });
    const searchExtent = 44.0;
    const titleExtent = kAppHeaderTitleCollapseDistance;
    await tester.pumpWidget(CupertinoApp(
      home: AppHeaderScrollInsetScope(
        leadingInset: kAppHeaderToolbarHeight,
        titleCollapseExtent: titleExtent,
        titleTransition: transition,
        child: Padding(
          padding: const EdgeInsets.only(top: kAppHeaderToolbarHeight),
          child: AppHeaderScrollView(
            controller: bodyController,
            topExtension: kAppHeaderContentTopSpacing,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: const [
              SliverToBoxAdapter(child: AppHeaderScrollInset(
                searchBarExtent: searchExtent,
                searchBar: SizedBox(
                  key: ValueKey('search'),
                  height: searchExtent,
                  child: Text('Search'),
                ),
              )),
              SliverToBoxAdapter(
                child: SizedBox(key: ValueKey('body'), height: 1),
              ),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    final outer = AppHeaderScrollView.headerPositionFor(bodyController)!;
    transition.bindTo(outer);
    final expandedViewport = bodyController.position.viewportDimension;
    final expandedTop = tester.getTopLeft(find.byKey(const ValueKey('body'))).dy;
    final expandedSearchTop =
        tester.getTopLeft(find.byKey(const ValueKey('search'))).dy;
    expect(outer.maxScrollExtent, titleExtent + searchExtent);
    expect(bodyController.position.maxScrollExtent, 0);

    final overscrollGesture = await tester.startGesture(
      tester.getCenter(find.byType(NestedScrollView)),
    );
    await overscrollGesture.moveBy(const Offset(0, 24));
    await tester.pump();
    expect(bodyController.position.pixels, -24);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('search'))).dy,
      expandedSearchTop + 24,
    );
    expect(transition.collapseProgress, 0);
    expect(transition.searchBarCollapseProgress, 0);
    await overscrollGesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('search'))).dy,
      expandedSearchTop,
    );

    for (final offset in [titleExtent / 2, titleExtent]) {
      outer.jumpTo(offset);
      await tester.pump();
      expect(transition.collapseProgress, offset / titleExtent);
      expect(transition.searchBarCollapseProgress, 0);
      expect(
        bodyController.position.viewportDimension,
        closeTo(expandedViewport + offset, 0.01),
      );
      final opacity = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(const ValueKey('search')),
          matching: find.byType(Opacity),
        ).first,
      );
      expect(opacity.opacity, 1);
    }
    outer.jumpTo(titleExtent + searchExtent / 2);
    await tester.pump();
    expect(transition.collapseProgress, 1);
    expect(transition.searchBarCollapseProgress, 0.5);
    expect(
      bodyController.position.viewportDimension,
      expandedViewport + titleExtent + searchExtent / 2,
    );
    final halfwaySearchOpacity = tester.widget<Opacity>(
      find.ancestor(
        of: find.byKey(const ValueKey('search')),
        matching: find.byType(Opacity),
      ).first,
    );
    expect(halfwaySearchOpacity.opacity, Curves.easeIn.transform(0.5));

    await tester.drag(find.byType(NestedScrollView), const Offset(0, -160));
    await tester.pumpAndSettle();
    expect(outer.pixels, titleExtent + searchExtent);
    expect(transition.searchBarCollapseProgress, 1);
    expect(bodyController.position.maxScrollExtent, 0);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('body'))).dy,
      expandedTop -
          kAppHeaderExpandedTitleDownshift -
          titleExtent -
          searchExtent +
          kAppHeaderContentTopSpacing,
    );
    for (var cycle = 0; cycle < 5; cycle++) {
      outer.jumpTo(0);
      await tester.pump();
      expect(tester.getTopLeft(find.byKey(const ValueKey('body'))).dy, expandedTop);
      outer.jumpTo(outer.maxScrollExtent);
      await tester.pump();
      expect(bodyController.position.maxScrollExtent, 0);
      expect(
        bodyController.position.viewportDimension,
        expandedViewport + titleExtent + searchExtent,
      );
    }
    await tester.pump(const Duration(milliseconds: 500));
    expect(outer.pixels, titleExtent + searchExtent);
  });

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
