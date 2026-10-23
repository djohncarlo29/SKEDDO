import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';

const _bodyKey = ValueKey('header-body');
const _viewportSize = Size(360, 320);

void main() {
  testWidgets(
    'short content reaches compact state and moves below the compact header',
    (tester) async {
      tester.view.physicalSize = _viewportSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final scrollController = ScrollController();
      final titleTransition = AppHeaderTitleTransition();
      addTearDown(() {
        titleTransition.dispose();
        scrollController.dispose();
      });

      await tester.pumpWidget(
        _buildHeaderHarness(controller: scrollController, bodyHeight: 1),
      );
      await tester.pumpAndSettle();

      final position = scrollController.position;
      titleTransition.bindTo(position);
      expect(
        position.maxScrollExtent,
        closeTo(kAppHeaderTitleCollapseDistance, 1),
      );
      expect(titleTransition.collapseProgress, 0);

      double bodyTop() => tester.getTopLeft(find.byKey(_bodyKey)).dy;

      expect(
        bodyTop(),
        closeTo(kAppHeaderToolbarHeight + kAppHeaderTitleCollapseDistance, 1),
      );

      scrollController.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(titleTransition.collapseProgress, 1);
      expect(bodyTop(), closeTo(kAppHeaderToolbarHeight, 1));

      // At the bottom of a very short page, the package controller remains
      // compact because the scroll position—not maxScrollExtent—owns the state.
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        scrollController.offset,
        closeTo(kAppHeaderTitleCollapseDistance, 1),
      );
      expect(titleTransition.collapseProgress, 1);
    },
  );

  testWidgets(
    'long content stays compact until the actual title expansion region',
    (tester) async {
      tester.view.physicalSize = _viewportSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final scrollController = ScrollController();
      final titleTransition = AppHeaderTitleTransition();
      addTearDown(() {
        titleTransition.dispose();
        scrollController.dispose();
      });

      await tester.pumpWidget(
        _buildHeaderHarness(controller: scrollController, bodyHeight: 2000),
      );
      await tester.pumpAndSettle();

      final position = scrollController.position;
      titleTransition.bindTo(position);
      final naturalMaxScrollExtent =
          kAppHeaderToolbarHeight +
          kAppHeaderTitleHeight +
          2000 -
          position.viewportDimension;
      expect(position.maxScrollExtent, closeTo(naturalMaxScrollExtent, 1));

      scrollController.jumpTo(kAppHeaderTitleCollapseDistance * 3);
      await tester.pump();
      expect(titleTransition.collapseProgress, 1);

      // Moving back down within the content does not expand the title.
      scrollController.jumpTo(kAppHeaderTitleCollapseDistance * 1.5);
      await tester.pump();
      expect(titleTransition.collapseProgress, 1);

      // The large title returns only as the real position enters its measured
      // expansion range, and there is no independent release-time snap.
      scrollController.jumpTo(kAppHeaderTitleCollapseDistance / 2);
      await tester.pump();
      expect(titleTransition.collapseProgress, closeTo(0.5, 1e-9));
      await tester.pump(const Duration(milliseconds: 500));
      expect(titleTransition.collapseProgress, closeTo(0.5, 1e-9));
    },
  );

  testWidgets(
    'short-content drag release holds the compact boundary and permits smooth expansion',
    (tester) async {
      tester.view.physicalSize = _viewportSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final scrollController = ScrollController();
      final titleTransition = AppHeaderTitleTransition();
      addTearDown(() {
        titleTransition.dispose();
        scrollController.dispose();
      });

      await tester.pumpWidget(
        _buildHeaderHarness(controller: scrollController, bodyHeight: 1),
      );
      await tester.pumpAndSettle();
      titleTransition.bindTo(scrollController.position);

      var compactReached = false;
      var expandedAfterCompact = false;
      titleTransition.addListener(() {
        if (titleTransition.collapseProgress >= 1) compactReached = true;
        if (compactReached && titleTransition.collapseProgress < 1) {
          expandedAfterCompact = true;
        }
      });

      await tester.drag(find.byType(CustomScrollView), const Offset(0, -120));
      await tester.pumpAndSettle();

      expect(
        scrollController.offset,
        closeTo(kAppHeaderTitleCollapseDistance, 1),
      );
      expect(titleTransition.collapseProgress, 1);
      await tester.pump(const Duration(milliseconds: 500));
      expect(expandedAfterCompact, isFalse);
      expect(titleTransition.collapseProgress, 1);

      // A slow downward release partway through the title region remains at
      // the actual intermediate geometry instead of rubber-banding or snapping.
      final gesture = await tester.startGesture(
        tester.getCenter(find.byType(CustomScrollView)),
      );
      for (var step = 1; step <= 10; step++) {
        await gesture.moveBy(
          const Offset(0, 2),
          timeStamp: Duration(milliseconds: step * 100),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      await gesture.up(timeStamp: const Duration(milliseconds: 1100));
      await tester.pumpAndSettle();

      final expandedOffset = scrollController.offset;
      expect(expandedOffset, greaterThan(0));
      expect(expandedOffset, lessThan(kAppHeaderTitleCollapseDistance));
      expect(
        titleTransition.collapseProgress,
        closeTo(expandedOffset / kAppHeaderTitleCollapseDistance, 1e-9),
      );
      expect(
        tester.getTopLeft(find.byKey(_bodyKey)).dy,
        closeTo(
          kAppHeaderToolbarHeight +
              kAppHeaderTitleCollapseDistance -
              expandedOffset,
          1,
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(scrollController.offset, closeTo(expandedOffset, 1));
      expect(
        titleTransition.collapseProgress,
        closeTo(expandedOffset / kAppHeaderTitleCollapseDistance, 1e-9),
      );
    },
  );

  testWidgets(
    'active header state is handed off and updates the previous screen on return',
    (tester) async {
      tester.view.physicalSize = _viewportSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final firstController = ScrollController();
      final secondController = ScrollController();
      final titleTransition = AppHeaderTitleTransition();
      addTearDown(() {
        titleTransition.dispose();
        firstController.dispose();
        secondController.dispose();
      });

      await tester.pumpWidget(
        CupertinoApp(
          home: SizedBox(
            height: _viewportSize.height,
            child: Padding(
              padding: const EdgeInsets.only(top: kAppHeaderToolbarHeight),
              child: AppHeaderScrollInsetScope(
                leadingInset: kAppHeaderToolbarHeight,
                titleCollapseExtent: kAppHeaderTitleCollapseDistance,
                child: Row(
                  children: [
                    Expanded(
                      child: _buildHeaderScrollView(
                        controller: firstController,
                        bodyHeight: 600,
                      ),
                    ),
                    Expanded(
                      child: _buildHeaderScrollView(
                        controller: secondController,
                        bodyHeight: 600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final firstPosition = firstController.position;
      final secondPosition = secondController.position;
      titleTransition.bindTo(firstPosition);
      firstController.jumpTo(kAppHeaderTitleCollapseDistance);
      await tester.pump();
      expect(titleTransition.collapseProgress, 1);

      titleTransition.bindTo(secondPosition, preserveCollapseProgress: true);
      await tester.pump();
      expect(
        secondController.offset,
        closeTo(kAppHeaderTitleCollapseDistance, 1),
      );
      expect(titleTransition.collapseProgress, 1);

      secondController.jumpTo(0);
      await tester.pump();
      expect(titleTransition.collapseProgress, 0);

      titleTransition.bindTo(firstPosition, preserveCollapseProgress: true);
      await tester.pump();
      expect(firstController.offset, 0);
      expect(titleTransition.collapseProgress, 0);
    },
  );
}

Widget _buildHeaderHarness({
  required ScrollController controller,
  required double bodyHeight,
}) {
  return CupertinoApp(
    home: SizedBox(
      height: _viewportSize.height,
      child: AppHeaderScrollInsetScope(
        leadingInset: kAppHeaderToolbarHeight,
        titleCollapseExtent: kAppHeaderTitleCollapseDistance,
        child: Padding(
          padding: const EdgeInsets.only(top: kAppHeaderToolbarHeight),
          child: AppHeaderScrollView(
            controller: controller,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              const SliverToBoxAdapter(
                child: SizedBox(height: kAppHeaderTitleHeight),
              ),
              SliverToBoxAdapter(
                child: SizedBox(key: _bodyKey, height: bodyHeight),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _buildHeaderScrollView({
  required ScrollController controller,
  required double bodyHeight,
}) {
  return AppHeaderScrollView(
    controller: controller,
    physics: const AlwaysScrollableScrollPhysics(
      parent: BouncingScrollPhysics(),
    ),
    slivers: [
      const SliverToBoxAdapter(child: SizedBox(height: kAppHeaderTitleHeight)),
      SliverToBoxAdapter(child: SizedBox(height: bodyHeight)),
    ],
  );
}
