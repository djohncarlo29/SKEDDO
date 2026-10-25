import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassScrollEdge;
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';

void main() {
  test('shell large title follows the scroll position once', () {
    expect(AppHeaderScrollBehavior.shellLargeTitleTravelOffset(0), 0);
    expect(
      AppHeaderScrollBehavior.shellLargeTitleTravelOffset(
        kAppHeaderTitleHeight / 2,
      ),
      closeTo(kAppHeaderTitleHeight / 2, 1e-9),
    );
    expect(
      AppHeaderScrollBehavior.shellLargeTitleTravelOffset(
        kAppHeaderTitleHeight,
      ),
      closeTo(kAppHeaderTitleHeight, 1e-9),
    );
    expect(AppHeaderScrollBehavior.shellLargeTitleTravelOffset(double.nan), 0);
    expect(AppHeaderScrollBehavior.shellLargeTitleTravelOffset(-12), 0);
  });

  test('shell and in-scroll titles share one collapse distance and curve', () {
    expect(AppHeaderScrollBehavior.titleCollapseProgress(0), 0);
    expect(
      AppHeaderScrollBehavior.titleCollapseProgress(
        kAppHeaderTitleCollapseDistance / 2,
      ),
      0.5,
    );
    expect(
      AppHeaderScrollBehavior.titleCollapseProgress(
        kAppHeaderTitleCollapseDistance,
      ),
      1,
    );
    expect(
      AppHeaderScrollBehavior.titleCollapseProgress(
        kAppHeaderTitleCollapseDistance * 2,
      ),
      1,
    );
    expect(AppHeaderScrollBehavior.titleCollapseProgress(double.nan), 0);
    expect(AppHeaderScrollBehavior.titleCollapseProgress(-12), 0);

    for (var offset = 0.0; offset <= kAppHeaderTitleCollapseDistance; offset += 0.25) {
      final collapseProgress =
          AppHeaderScrollBehavior.titleCollapseProgress(offset);
      expect(
        AppHeaderScrollBehavior.packageLargeTitleFadeProgress(collapseProgress),
        AppHeaderScrollBehavior.packageLargeTitleFadeProgress(
          offset / kAppHeaderTitleCollapseDistance,
        ),
      );
      expect(
        AppHeaderScrollBehavior.packageCompactTitleFadeProgress(
          collapseProgress,
        ),
        AppHeaderScrollBehavior.packageCompactTitleFadeProgress(
          offset / kAppHeaderTitleCollapseDistance,
        ),
      );
    }
  });

  testWidgets('scroll-owned calendar title follows shared collapse progress', (
    tester,
  ) async {
    const titleKey = ValueKey('scroll-owned-large-title');
    final controller = ScrollController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: AppHeaderScrollInsetScope(
          leadingInset: 0,
          child: SizedBox(
            height: 600,
            child: CustomScrollView(
              controller: controller,
              slivers: [
                const SliverToBoxAdapter(
                  child: SizedBox(height: kAppHeaderTitleHeight),
                ),
                SliverToBoxAdapter(
                  child: AppHeaderScrollTitle(
                    controller: controller,
                    child: const SizedBox(
                      height: kAppHeaderTitleHeight,
                      child: Text('Calendar', key: titleKey),
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 1000)),
              ],
            ),
          ),
        ),
      ),
    );

    double titleOpacity() => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(titleKey),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    controller.jumpTo(kAppHeaderTitleCollapseDistance / 2);
    await tester.pump();
    final collapseProgress = AppHeaderScrollBehavior.titleCollapseProgress(
      kAppHeaderTitleCollapseDistance / 2,
    );
    expect(
      titleOpacity(),
      closeTo(
        1 -
            AppHeaderScrollBehavior.packageLargeTitleFadeProgress(
              collapseProgress,
            ),
        1e-9,
      ),
    );

    controller.jumpTo(kAppHeaderTitleCollapseDistance);
    await tester.pump();
    expect(titleOpacity(), 0);

    controller.jumpTo(0);
    await tester.pump();
    expect(titleOpacity(), 1);
  });

  testWidgets('the fixed title slot remains in the scroll extent', (
    tester,
  ) async {
    const contentKey = ValueKey('latched-title-slot-content');

    await tester.pumpWidget(
      CupertinoApp(
        home: AppHeaderScrollInsetScope(
          leadingInset: 0,
          child: SizedBox(
            height: 600,
            child: Column(
              children: [
                const AppHeaderScrollInset(),
                const SizedBox(key: contentKey, height: 1),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double contentTop() => tester.getTopLeft(find.byKey(contentKey)).dy;
    expect(contentTop(), kAppHeaderTitleHeight);
    await tester.pumpAndSettle();
    expect(contentTop(), kAppHeaderTitleHeight);
  });

  test('scroll edge progresses through the large-title and toolbar travel', () {
    final totalTravel = kAppHeaderTitleHeight + kAppHeaderToolbarHeight;

    expect(AppHeaderScrollBehavior.scrollEdgeProgress(0), 0);
    expect(
      AppHeaderScrollBehavior.scrollEdgeProgress(kAppHeaderTitleHeight),
      closeTo(kAppHeaderTitleHeight / totalTravel, 1e-9),
    );
    expect(AppHeaderScrollBehavior.scrollEdgeProgress(totalTravel), 1);
    expect(AppHeaderScrollBehavior.scrollEdgeProgress(totalTravel + 20), 1);
    expect(AppHeaderScrollBehavior.scrollEdgeProgress(double.nan), 0);
  });

  test('package title cross-fade follows its collapse progress', () {
    expect(AppHeaderScrollBehavior.packageLargeTitleFadeProgress(0), 0);
    expect(
      AppHeaderScrollBehavior.packageLargeTitleFadeProgress(0.5),
      closeTo(1 - Curves.easeIn.transform(0.5), 1e-9),
    );
    expect(AppHeaderScrollBehavior.packageLargeTitleFadeProgress(1), 1);

    expect(AppHeaderScrollBehavior.packageCompactTitleFadeProgress(0), 0);
    expect(AppHeaderScrollBehavior.packageCompactTitleFadeProgress(0.5), 0);
    expect(
      AppHeaderScrollBehavior.packageCompactTitleFadeProgress(0.75),
      closeTo(Curves.easeOut.transform(0.5), 1e-9),
    );
    expect(AppHeaderScrollBehavior.packageCompactTitleFadeProgress(1), 1);
  });

  testWidgets(
    'package collapse controller tracks the actual position through release-like changes',
    (tester) async {
      final scrollController = ScrollController();
      final titleTransition = AppHeaderTitleTransition();
      addTearDown(() {
        titleTransition.dispose();
        scrollController.dispose();
      });
      const contentKey = ValueKey('content-below-compact-header');

      await tester.pumpWidget(
        CupertinoApp(
          home: AppHeaderScrollInsetScope(
            leadingInset: kAppHeaderToolbarHeight,
            child: SizedBox(
              height: 320,
              child: Padding(
                padding: const EdgeInsets.only(top: kAppHeaderToolbarHeight),
                child: AppHeaderScrollView(
                  controller: scrollController,
                  physics: const NeverScrollableScrollPhysics(),
                  slivers: const [
                    SliverToBoxAdapter(
                      child: SizedBox(height: kAppHeaderTitleHeight),
                    ),
                    SliverToBoxAdapter(
                      child: SizedBox(key: contentKey, height: 40),
                    ),
                    SliverToBoxAdapter(child: SizedBox(height: 2400)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final position = scrollController.position;
      titleTransition.bindTo(position);
      expect(titleTransition.collapseProgress, 0);

      // Passing the title slot produces the compact state; a small downward
      // move that remains beyond it cannot restore the large title.
      scrollController.jumpTo(kAppHeaderTitleHeight + 20);
      await tester.pump();
      expect(titleTransition.collapseProgress, 1);
      expect(titleTransition.contentOffset, kAppHeaderTitleHeight + 20);

      // The package controller saturates collapseProgress at 1.0 and stops
      // notifying for further positive movement. The shared shell must still
      // follow this same ScrollPosition for title travel and glass-edge extent.
      scrollController.jumpTo(400);
      await tester.pump();
      expect(titleTransition.collapseProgress, 1);
      expect(titleTransition.contentOffset, 400);

      // Moving back toward the top while still in the compact region must not
      // restore the large title, but the shell's positional effects must keep
      // tracking the actual scroll coordinate.
      scrollController.jumpTo(120);
      await tester.pump();
      expect(titleTransition.collapseProgress, 1);
      expect(titleTransition.contentOffset, 120);

      scrollController.jumpTo(kAppHeaderTitleHeight);
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(contentKey)).dy,
        closeTo(kAppHeaderToolbarHeight, 1),
      );

      scrollController.jumpTo(kAppHeaderTitleHeight + 8);
      await tester.pump();
      expect(titleTransition.collapseProgress, 1);

      // Expansion is continuous with the real position and remains there when
      // motion stops; there is no independent settle animation to snap through.
      scrollController.jumpTo(kAppHeaderTitleHeight / 2);
      await tester.pump();
      expect(titleTransition.collapseProgress, closeTo(0.5, 1e-9));
      await tester.pump(const Duration(milliseconds: 300));
      expect(titleTransition.collapseProgress, closeTo(0.5, 1e-9));

      for (var cycle = 0; cycle < 3; cycle++) {
        scrollController.jumpTo(kAppHeaderTitleHeight + 12);
        await tester.pump();
        expect(titleTransition.collapseProgress, 1);
        scrollController.jumpTo(0);
        await tester.pump();
        expect(titleTransition.collapseProgress, 0);
        expect(titleTransition.contentOffset, 0);
      }
    },
  );

  testWidgets(
    'Calendar preview inherits shared header collapse before and after appearing',
    (tester) async {
      final activeController = ScrollController();
      final previewController = ScrollController();
      final titleTransition = AppHeaderTitleTransition();
      final showPreview = ValueNotifier(false);
      addTearDown(() {
        activeController.dispose();
        previewController.dispose();
        titleTransition.dispose();
        showPreview.dispose();
      });

      Widget buildScrollView(
        ScrollController controller, {
        bool mirrorSharedHeaderCollapse = false,
      }) {
        return AppHeaderScrollView(
          controller: controller,
          mirrorSharedHeaderCollapse: mirrorSharedHeaderCollapse,
          physics: const NeverScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: AppHeaderScrollInset(
                child: SizedBox(height: kAppHeaderTitleHeight),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 1600)),
          ],
        );
      }

      await tester.pumpWidget(
        CupertinoApp(
          home: AppHeaderScrollInsetScope(
            leadingInset: kAppHeaderToolbarHeight,
            titleCollapseExtent: kAppHeaderTitleHeight,
            titleTransition: titleTransition,
            child: SizedBox(
              height: 400,
              child: ValueListenableBuilder<bool>(
                valueListenable: showPreview,
                builder: (context, includePreview, _) => Stack(
                  children: [
                    Positioned.fill(child: buildScrollView(activeController)),
                    if (includePreview)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: buildScrollView(
                            previewController,
                            mirrorSharedHeaderCollapse: true,
                          ),
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

      final activeHeader =
          AppHeaderScrollView.headerPositionFor(activeController);
      expect(activeHeader, isNotNull);
      titleTransition.bindTo(activeHeader!);
      final collapsedOffset = kAppHeaderTitleHeight * 0.6;
      activeHeader.jumpTo(collapsedOffset);
      await tester.pump();
      expect(titleTransition.collapseProgress, closeTo(0.6, 0.02));

      // A preview first created after the active panel has collapsed must
      // start from that shared state, rather than flashing expanded.
      showPreview.value = true;
      await tester.pump();
      await tester.pumpAndSettle();
      final previewHeader =
          AppHeaderScrollView.headerPositionFor(previewController);
      expect(previewHeader, isNotNull);
      expect(previewHeader!.pixels, closeTo(collapsedOffset, 0.75));

      // Existing adjacent panels must keep following the active panel too.
      activeHeader.jumpTo(0);
      await tester.pump();
      expect(previewHeader.pixels, closeTo(0, 0.75));
    },
  );

  testWidgets(
    'large Calendar title fades from shared state when a preview body is still at top',
    (tester) async {
      final activeController = ScrollController();
      final previewController = ScrollController();
      final titleTransition = AppHeaderTitleTransition();
      const previewTitleKey = ValueKey('preview-large-calendar-title');
      addTearDown(() {
        activeController.dispose();
        previewController.dispose();
        titleTransition.dispose();
      });

      await tester.pumpWidget(
        CupertinoApp(
          home: AppHeaderScrollInsetScope(
            leadingInset: kAppHeaderToolbarHeight,
            titleCollapseExtent: kAppHeaderTitleHeight,
            titleTransition: titleTransition,
            child: SizedBox(
              height: 400,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AppHeaderScrollView(
                      controller: activeController,
                      physics: const NeverScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: AppHeaderScrollInset(
                            child: SizedBox(height: kAppHeaderTitleHeight),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 1600)),
                      ],
                    ),
                  ),
                  Positioned.fill(
                    child: CustomScrollView(
                      controller: previewController,
                      primary: false,
                      physics: const NeverScrollableScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: AppHeaderScrollTitle(
                            controller: previewController,
                            child: const SizedBox(
                              key: previewTitleKey,
                              height: kAppHeaderTitleHeight,
                            ),
                          ),
                        ),
                        const SliverToBoxAdapter(child: SizedBox(height: 1600)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final activeHeader =
          AppHeaderScrollView.headerPositionFor(activeController);
      expect(activeHeader, isNotNull);
      titleTransition.bindTo(activeHeader!);
      final titleOpacityFinder = find.ancestor(
        of: find.byKey(previewTitleKey),
        matching: find.byType(Opacity),
      );
      expect(titleOpacityFinder, findsOneWidget);
      expect(tester.widget<Opacity>(titleOpacityFinder).opacity, 1.0);

      activeHeader.jumpTo(kAppHeaderTitleHeight);
      await tester.pump();
      expect(titleTransition.collapseProgress, 1.0);
      expect(previewController.offset, 0.0);
      expect(tester.widget<Opacity>(titleOpacityFinder).opacity, 0.0);

      activeHeader.jumpTo(0);
      await tester.pump();
      expect(tester.widget<Opacity>(titleOpacityFinder).opacity, 1.0);
    },
  );

  testWidgets(
    'drag release keeps the title and compact-header content on one scroll position',
    (tester) async {
      const viewportKey = ValueKey('large-title-scroll-viewport');
      const contentKey = ValueKey('large-title-first-content');
      final scrollController = ScrollController();
      final titleTransition = AppHeaderTitleTransition();
      addTearDown(() {
        titleTransition.dispose();
        scrollController.dispose();
      });

      await tester.pumpWidget(
        CupertinoApp(
          home: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              final notificationContext = notification.context;
              if (notificationContext != null) {
                final position = Scrollable.maybeOf(
                  notificationContext,
                  axis: Axis.vertical,
                )?.position;
                if (position != null) titleTransition.bindTo(position);
              }
              return false;
            },
            child: Stack(
              children: [
                Positioned.fill(
                  child: AppHeaderScrollInsetScope(
                    leadingInset: kAppHeaderToolbarHeight,
                    child: Padding(
                      padding: const EdgeInsets.only(
                        top: kAppHeaderToolbarHeight,
                      ),
                      child: AppHeaderScrollView(
                        key: viewportKey,
                        controller: scrollController,
                        physics: const BouncingScrollPhysics(),
                        slivers: const [
                          SliverToBoxAdapter(
                            child: SizedBox(height: kAppHeaderTitleHeight),
                          ),
                          SliverToBoxAdapter(
                            child: SizedBox(key: contentKey, height: 40),
                          ),
                          SliverToBoxAdapter(child: SizedBox(height: 2400)),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: kAppHeaderToolbarHeight,
                  child: AnimatedBuilder(
                    animation: titleTransition,
                    builder: (context, _) => AppHeaderCompactTitle(
                      progress:
                          AppHeaderScrollBehavior.packageCompactTitleFadeProgress(
                            titleTransition.collapseProgress,
                          ),
                      isLandscape: false,
                      child: const Center(
                        child: Text('Compact title', key: ValueKey('compact')),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: kAppHeaderToolbarHeight,
                  left: 0,
                  right: 0,
                  height: kAppHeaderTitleHeight,
                  child: AnimatedBuilder(
                    animation: titleTransition,
                    builder: (context, _) => Transform.translate(
                      offset: Offset(
                        0,
                        -titleTransition.contentOffset,
                      ),
                      child: AppHeaderLargeTitleHandoff(
                        progress:
                            AppHeaderScrollBehavior.packageLargeTitleFadeProgress(
                              titleTransition.collapseProgress,
                            ),
                        child: const Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            'Large title',
                            key: ValueKey('large'),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.getTopLeft(find.byKey(contentKey)).dy,
        closeTo(kAppHeaderToolbarHeight + kAppHeaderTitleHeight, 1),
      );

      // A real drag followed by its ballistic release must not send the
      // package-driven title back to expanded while the same position remains
      // beyond the title slot.
      await tester.drag(find.byKey(viewportKey), const Offset(0, -140));
      await tester.pumpAndSettle();
      expect(
        scrollController.position.pixels,
        greaterThan(kAppHeaderTitleHeight),
      );
      expect(titleTransition.collapseProgress, 1);
      expect(
        tester.widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('compact')),
                matching: find.byType(Opacity),
              )
              .first,
        ).opacity,
        1,
      );

      // Moving down in the middle of the content does not restore the large
      // title; the controller remains compact until the actual position enters
      // the title's expansion region.
      await tester.drag(find.byKey(viewportKey), const Offset(0, 24));
      await tester.pumpAndSettle();
      expect(
        scrollController.position.pixels,
        greaterThan(kAppHeaderTitleHeight),
      );
      expect(titleTransition.collapseProgress, 1);

      // At the exact collapse handoff, the first content row reaches the
      // toolbar boundary rather than being hidden beneath the compact title.
      scrollController.jumpTo(kAppHeaderTitleHeight);
      await tester.pump();
      expect(
        tester.getTopLeft(find.byKey(contentKey)).dy,
        closeTo(kAppHeaderToolbarHeight, 1),
      );
      expect(titleTransition.collapseProgress, 1);

      // Only reaching the true leading edge restores the large title.
      scrollController.jumpTo(0);
      await tester.pump();
      expect(titleTransition.collapseProgress, 0);
      expect(
        tester.widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('compact')),
                matching: find.byType(Opacity),
              )
              .first,
        ).opacity,
        0,
      );
      expect(
        tester.getTopLeft(find.byKey(contentKey)).dy,
        closeTo(kAppHeaderToolbarHeight + kAppHeaderTitleHeight, 1),
      );
    },
  );

  testWidgets(
    'centered content follows the expanding area without list recentering',
    (tester) async {
      const surfaceSize = Size(320, 600);
      const contentKey = ValueKey('centered-content-under-collapsing-title');
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: SizedBox(
            width: surfaceSize.width,
            height: surfaceSize.height,
            child: AppHeaderScrollView(
              controller: controller,
              slivers: const [
                SliverToBoxAdapter(
                  child: SizedBox(height: kAppHeaderTitleHeight),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 180,
                    child: Center(
                      child: AppHeaderScrollCentered(
                        child: SizedBox(key: contentKey, width: 20, height: 20),
                      ),
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 500)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final centerCorrection = () {
        final transform = tester.widget<Transform>(
          find
              .ancestor(
                of: find.byKey(contentKey),
                matching: find.byType(Transform),
              )
              .first,
        );
        return transform.transform.getTranslation().y;
      };

      controller.jumpTo(30);
      await tester.pump();
      expect(centerCorrection(), closeTo(15, 1e-6));

      controller.jumpTo(kAppHeaderTitleHeight + 40);
      await tester.pump();
      expect(centerCorrection(), closeTo(kAppHeaderTitleHeight / 2, 1e-6));
    },
  );

  testWidgets(
    'glass filter starts at screen top and extends 16pt below header',
    (tester) async {
      const headerAreaHeight = 92.0;
      const surfaceSize = Size(320, 240);

      await tester.pumpWidget(
        const CupertinoApp(
          home: SizedBox(
            width: 320,
            height: 240,
            child: Stack(
              children: [
                AppHeaderScrollEdge(
                  progress: 1,
                  surfaceColor: Color(0xFFFFFFFF),
                  headerHeight: headerAreaHeight,
                  backgroundGradientHeight: headerAreaHeight,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final blurRect = tester.getRect(find.byType(LiquidGlassScrollEdge));
      expect(blurRect.top, 0);
      expect(
        blurRect.height,
        headerAreaHeight + kAppHeaderScrollEdgeHeaderBottomExtension,
      );
      expect(blurRect.bottom, lessThan(surfaceSize.height));
    },
  );

  testWidgets('header content slot stays fixed during title collapse', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: AppHeaderScrollInsetScope(
          leadingInset: 0,
          child: SizedBox(
            height: 600,
            child: Column(
              children: const [
                AppHeaderScrollInset(),
                SizedBox(key: ValueKey('animated-header-content'), height: 1),
              ],
            ),
          ),
        ),
      ),
    );

    double contentTop() => tester
        .getTopLeft(find.byKey(const ValueKey('animated-header-content')))
        .dy;

    expect(contentTop(), kAppHeaderTitleHeight);
    await tester.pumpAndSettle();
    expect(contentTop(), kAppHeaderTitleHeight);
  });

  testWidgets(
    'portrait compact title fades in with scroll progress and accepts taps once visible',
    (tester) async {
      var tapCount = 0;
      const titleKey = ValueKey('compact-header-title');

      Widget buildApp({required double progress, bool isLandscape = false}) {
        return CupertinoApp(
          home: Center(
            child: AppHeaderCompactTitle(
              progress: progress,
              isLandscape: isLandscape,
              child: GestureDetector(
                key: titleKey,
                onTap: () => tapCount++,
                child: const Text('Calendar title'),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp(progress: 0.25));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.25);
      await tester.tap(find.byKey(titleKey));
      expect(tapCount, 0);

      await tester.pumpWidget(buildApp(progress: 0.75));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 0.75);
      await tester.tap(find.byKey(titleKey));
      expect(tapCount, 1);

      await tester.pumpWidget(buildApp(progress: 0.0, isLandscape: true));
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1.0);
      await tester.tap(find.byKey(titleKey));
      expect(tapCount, 2);
    },
  );

  testWidgets(
    'scroll content remains visible through the app edge above its viewport',
    (tester) async {
      const surfaceSize = Size(320, 300);
      const captureKey = ValueKey('app-scroll-edge-capture');
      const contentKey = ValueKey('content-under-app-scroll-edge');
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController(initialScrollOffset: 145);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: SizedBox(
            width: surfaceSize.width,
            height: surfaceSize.height,
            child: RepaintBoundary(
              key: captureKey,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Positioned.fill(
                    top: 40,
                    child: AppHeaderScrollInsetScope(
                      leadingInset: 40,
                      child: RepaintBoundary(
                        child: AppHeaderScrollClip(
                          child: AppHeaderScrollStack(
                            children: [
                              AppHeaderScrollView(
                                controller: controller,
                                physics: const NeverScrollableScrollPhysics(),
                                slivers: const [
                                  SliverToBoxAdapter(
                                    child: SizedBox(height: 120),
                                  ),
                                  SliverToBoxAdapter(
                                    child: SizedBox(
                                      key: contentKey,
                                      height: 20,
                                      child: ColoredBox(
                                        color: Color(0xFFD84A45),
                                      ),
                                    ),
                                  ),
                                  SliverToBoxAdapter(
                                    child: SizedBox(height: 600),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  const AppHeaderScrollEdge(
                    progress: 1,
                    surfaceColor: Color(0xFFFFFFFF),
                    headerHeight: 100,
                    backgroundGradientHeight: 0,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final scrollViewFinder = find.byType(AppHeaderScrollView);
      final stack = tester.widget<AppHeaderScrollStack>(
        find.byType(AppHeaderScrollStack),
      );
      final scrollViewWidget = tester.widget<AppHeaderScrollView>(
        scrollViewFinder,
      );
      final edge = tester.widget<LiquidGlassScrollEdge>(
        find.byType(LiquidGlassScrollEdge),
      );
      final contentRect = tester.getRect(find.byKey(contentKey));

      expect(controller.offset, closeTo(145, 1));
      expect(
        contentRect.top,
        greaterThanOrEqualTo(0),
        reason: 'The row should still be within the physical device viewport.',
      );
      expect(
        contentRect.bottom,
        lessThan(40),
        reason:
            'The whole row is above the app page viewport, but not above the device viewport.',
      );
      expect(scrollViewWidget.clipBehavior, Clip.none);
      expect(stack.clipBehavior, Clip.none);
      expect(
        find.ancestor(
          of: scrollViewFinder,
          matching: find.byType(AppHeaderScrollEdge),
        ),
        findsNothing,
        reason: 'The edge must overlay the viewport, not wrap or clip it.',
      );
      expect(
        edge.color.a,
        lessThanOrEqualTo(0.25),
        reason: 'The glass tint must not make passing content look removed.',
      );
      expect(
        edge.blur,
        lessThanOrEqualTo(8),
        reason: 'The glass blur must retain perceptible content detail.',
      );

      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(captureKey),
      );
      final pixels = (await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 1);
        try {
          return (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      }))!;
      final pixelOffset = (25 * surfaceSize.width.toInt() + 160) * 4;
      final pixel = pixels.sublist(pixelOffset, pixelOffset + 4);
      expect(
        pixel[0] - pixel[1],
        greaterThan(50),
        reason:
            'A red row crossing the edge must still be rendered there, not clipped away.',
      );
    },
  );

  testWidgets(
    'single-child page scrollables use the same physical viewport extension',
    (tester) async {
      const surfaceSize = Size(320, 300);
      const contentKey = ValueKey('single-child-under-app-scroll-edge');
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = ScrollController(initialScrollOffset: 145);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        CupertinoApp(
          home: SizedBox(
            width: surfaceSize.width,
            height: surfaceSize.height,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned.fill(
                  top: 40,
                  child: AppHeaderScrollInsetScope(
                    leadingInset: 40,
                    child: AppHeaderScrollClip(
                      child: AppHeaderScrollStack(
                        children: [
                          AppHeaderSingleChildScrollView(
                            leadingInset: 40,
                            controller: controller,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.only(top: 160),
                            child: Column(
                              children: const [
                                SizedBox(
                                  key: contentKey,
                                  height: 20,
                                  child: ColoredBox(color: Color(0xFFD84A45)),
                                ),
                                SizedBox(height: 600),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const AppHeaderScrollEdge(
                  progress: 1,
                  surfaceColor: Color(0xFFFFFFFF),
                  headerHeight: 100,
                  backgroundGradientHeight: 0,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final contentRect = tester.getRect(find.byKey(contentKey));
      expect(controller.offset, closeTo(145, 1));
      expect(contentRect.top, closeTo(15, 1));
      expect(contentRect.bottom, lessThan(40));
    },
  );

  testWidgets(
    'page top extension raises content without shrinking its viewport',
    (tester) async {
      const surfaceSize = Size(320, 300);
      const contentKey = ValueKey('content-after-raised-page-edge');
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CupertinoApp(
          home: SizedBox(
            width: surfaceSize.width,
            height: surfaceSize.height,
            child: AppHeaderScrollView(
              topExtension: 16,
              physics: const NeverScrollableScrollPhysics(),
              slivers: const [
                SliverToBoxAdapter(child: SizedBox(height: 40)),
                SliverToBoxAdapter(
                  child: SizedBox(key: contentKey, height: 20),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 500)),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.getRect(find.byKey(contentKey)).top, closeTo(24, 1));
      expect(
        tester.getSize(find.byType(CustomScrollView)).height,
        closeTo(surfaceSize.height + 16, 1),
      );
    },
  );
}
