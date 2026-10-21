import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart'
    show LiquidGlassScrollEdge;
import 'package:smart_scheduler/widgets/app_header_scroll_edge.dart';

void main() {
  test('large and compact title fades are sequential and end at content edge', () {
    const titleBottomInset = 10.0;
    final titleBottom = kAppHeaderTitleHeight - titleBottomInset;
    final handoffSplit = (titleBottom + kAppHeaderTitleHeight) / 2;

    expect(
      AppHeaderScrollBehavior.largeTitleFadeProgress(
        titleBottom - 1,
        titleBottomInset: titleBottomInset,
      ),
      0,
    );
    expect(
      AppHeaderScrollBehavior.largeTitleFadeProgress(
        titleBottom,
        titleBottomInset: titleBottomInset,
      ),
      0,
    );
    expect(
      AppHeaderScrollBehavior.largeTitleFadeProgress(
        handoffSplit,
        titleBottomInset: titleBottomInset,
      ),
      1,
    );
    expect(
      AppHeaderScrollBehavior.compactTitleFadeProgress(
        handoffSplit,
        titleBottomInset: titleBottomInset,
      ),
      0,
    );
    expect(
      AppHeaderScrollBehavior.compactTitleFadeProgress(
        (handoffSplit + kAppHeaderTitleHeight) / 2,
        titleBottomInset: titleBottomInset,
      ),
      closeTo(0.5, 1e-9),
    );
    expect(
      AppHeaderScrollBehavior.compactTitleFadeProgress(
        kAppHeaderTitleHeight,
        titleBottomInset: titleBottomInset,
      ),
      1,
    );
    for (var offset = 0.0; offset <= kAppHeaderTitleHeight; offset += 0.25) {
      final largeOpacity =
          1 -
          AppHeaderScrollBehavior.largeTitleFadeProgress(
            offset,
            titleBottomInset: titleBottomInset,
          );
      final compactOpacity =
          AppHeaderScrollBehavior.compactTitleFadeProgress(
            offset,
            titleBottomInset: titleBottomInset,
          );
      expect(
        largeOpacity == 0.0 || compactOpacity == 0.0,
        isTrue,
        reason: 'titles must not overlap at scroll offset $offset',
      );
    }
  });

  testWidgets('large title disappears before compact title appears', (
    tester,
  ) async {
    const largeTitleKey = ValueKey('large-title-handoff');
    const compactTitleKey = ValueKey('compact-title-handoff');
    const titleBottomInset = 10.0;

    Widget buildApp(double contentOffset) {
      return CupertinoApp(
        home: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppHeaderLargeTitleHandoff(
                progress: AppHeaderScrollBehavior.largeTitleFadeProgress(
                  contentOffset,
                  titleBottomInset: titleBottomInset,
                ),
                child: const Text('Large title', key: largeTitleKey),
              ),
              AppHeaderCompactTitle(
                progress: AppHeaderScrollBehavior.compactTitleFadeProgress(
                  contentOffset,
                  titleBottomInset: titleBottomInset,
                ),
                isLandscape: false,
                child: const Text('Compact title', key: compactTitleKey),
              ),
            ],
          ),
        ),
      );
    }

    bool ignoresPointer(Key key) {
      final pointerGate = tester.widget<IgnorePointer>(
        find
            .ancestor(
              of: find.byKey(key),
              matching: find.byType(IgnorePointer),
            )
            .first,
      );
      return pointerGate.ignoring;
    }

    double opacityFor(Key key) => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(key),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;

    await tester.pumpWidget(buildApp(49));
    expect(opacityFor(largeTitleKey), closeTo(0.6, 1e-9));
    expect(opacityFor(compactTitleKey), 0);
    expect(ignoresPointer(largeTitleKey), isFalse);
    expect(ignoresPointer(compactTitleKey), isTrue);

    await tester.pumpWidget(buildApp(52));
    expect(opacityFor(largeTitleKey), 0);
    expect(opacityFor(compactTitleKey), 0);
    expect(ignoresPointer(largeTitleKey), isTrue);

    await tester.pumpWidget(buildApp(kAppHeaderTitleHeight));
    expect(opacityFor(largeTitleKey), 0);
    expect(opacityFor(compactTitleKey), 1);
    expect(ignoresPointer(compactTitleKey), isFalse);
  });

  testWidgets('scroll-owned calendar title obeys the sequential handoff', (
    tester,
  ) async {
    const titleBottomInset = 10.0;
    const titleKey = ValueKey('scroll-owned-large-title');
    final controller = ScrollController();
    final isScrolled = ValueNotifier<bool>(false);
    final isScrollActive = ValueNotifier<bool>(false);
    addTearDown(controller.dispose);
    addTearDown(isScrolled.dispose);
    addTearDown(isScrollActive.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: AppHeaderScrollInsetScope(
          leadingInset: 0,
          headerIsScrolled: isScrolled,
          headerScrollIsActive: isScrollActive,
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
                    titleBottomInset: titleBottomInset,
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

    isScrollActive.value = true;
    controller.jumpTo(52);
    await tester.pump();
    expect(titleOpacity(), 0);

    controller.jumpTo(kAppHeaderTitleHeight);
    await tester.pump();
    expect(titleOpacity(), 0);

    controller.jumpTo(0);
    await tester.pump();
    isScrolled.value = true;
    isScrollActive.value = false;
    await tester.pump();
    expect(titleOpacity(), 0);

    isScrolled.value = false;
    await tester.pump();
    expect(titleOpacity(), 1);
  });

  testWidgets('settled header state collapses and restores the content slot', (
    tester,
  ) async {
    const contentKey = ValueKey('latched-title-slot-content');
    final isScrolled = ValueNotifier<bool>(false);
    addTearDown(isScrolled.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: AppHeaderScrollInsetScope(
          leadingInset: 0,
          headerIsScrolled: isScrolled,
          child: SizedBox(
            height: 600,
            child: Column(
              children: [
                const AppHeaderScrollInset(),
                const SizedBox(
                  key: contentKey,
                  height: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    double contentTop() => tester.getTopLeft(find.byKey(contentKey)).dy;
    expect(contentTop(), kAppHeaderTitleHeight);

    isScrolled.value = true;
    await tester.pump();
    expect(contentTop(), 0);

    isScrolled.value = false;
    await tester.pump();
    expect(contentTop(), kAppHeaderTitleHeight);
  });

  test('scroll edge progresses through the large-title and toolbar travel', () {
    final totalTravel = kAppHeaderTitleHeight + kAppHeaderToolbarHeight;

    expect(AppHeaderScrollBehavior.scrollEdgeProgress(0), 0);
    expect(
      AppHeaderScrollBehavior.scrollEdgeProgress(kAppHeaderTitleHeight),
      closeTo(kAppHeaderTitleHeight / totalTravel, 1e-9),
    );
    expect(
      AppHeaderScrollBehavior.scrollEdgeProgress(totalTravel),
      1,
    );
    expect(AppHeaderScrollBehavior.scrollEdgeProgress(totalTravel + 20), 1);
    expect(AppHeaderScrollBehavior.scrollEdgeProgress(double.nan), 0);
  });

  test('header settle preserves two direction-driven states', () {
    expect(
      AppHeaderScrollBehavior.settledHeaderOffset(ScrollDirection.reverse),
      kAppHeaderScrollCollapsedOffset,
    );
    expect(
      AppHeaderScrollBehavior.settledHeaderOffset(ScrollDirection.forward),
      0,
    );
  });

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
                        child: SizedBox(
                          key: contentKey,
                          width: 20,
                          height: 20,
                        ),
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
          find.ancestor(
            of: find.byKey(contentKey),
            matching: find.byType(Transform),
          ).first,
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

  testWidgets('glass filter starts at screen top and extends 16pt below header', (
    tester,
  ) async {
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
  });

  testWidgets('header content slot follows the animated scroll offset', (
    tester,
  ) async {
    final scrollOffset = ValueNotifier<double>(0.0);
    addTearDown(scrollOffset.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: AppHeaderScrollInsetScope(
          leadingInset: 0,
          headerTitleScrollOffset: scrollOffset,
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
    scrollOffset.value = kAppHeaderTitleHeight / 2;
    await tester.pump();
    expect(contentTop(), kAppHeaderTitleHeight / 2);
    scrollOffset.value = kAppHeaderTitleHeight;
    await tester.pump();
    expect(contentTop(), 0);
  });

  testWidgets('settle animation uses the same path in both directions', (
    tester,
  ) async {
    final offset = ValueNotifier<double>(0.0);
    addTearDown(offset.dispose);
    late AppHeaderScrollSettler settler;

    await tester.pumpWidget(
      CupertinoApp(
        home: _HeaderSettleHarness(
          offset: offset,
          onSettlerCreated: (value) => settler = value,
        ),
      ),
    );

    settler.animateTo(kAppHeaderScrollCollapsedOffset);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    final halfwayCollapsed = offset.value;
    expect(
      halfwayCollapsed,
      inExclusiveRange(0, kAppHeaderScrollCollapsedOffset),
    );

    await tester.pump(const Duration(milliseconds: 130));
    expect(offset.value, kAppHeaderScrollCollapsedOffset);

    settler.animateTo(0);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 130));
    expect(
      offset.value,
      closeTo(kAppHeaderScrollCollapsedOffset - halfwayCollapsed, 2.5),
    );
    await tester.pump(const Duration(milliseconds: 130));
    expect(offset.value, 0);
  });

  testWidgets(
    'portrait compact title fades in with scroll progress and accepts taps once visible',
    (tester) async {
      var tapCount = 0;
      const titleKey = ValueKey('compact-header-title');

      Widget buildApp({
        required double progress,
        bool isLandscape = false,
      }) {
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

      await tester.pumpWidget(
        buildApp(progress: 0.0, isLandscape: true),
      );
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

class _HeaderSettleHarness extends StatefulWidget {
  const _HeaderSettleHarness({
    required this.offset,
    required this.onSettlerCreated,
  });

  final ValueNotifier<double> offset;
  final ValueChanged<AppHeaderScrollSettler> onSettlerCreated;

  @override
  State<_HeaderSettleHarness> createState() => _HeaderSettleHarnessState();
}

class _HeaderSettleHarnessState extends State<_HeaderSettleHarness>
    with SingleTickerProviderStateMixin {
  late final AppHeaderScrollSettler _settler;

  @override
  void initState() {
    super.initState();
    _settler = AppHeaderScrollSettler(
      vsync: this,
      offset: widget.offset,
      onSettled: () {},
    );
    widget.onSettlerCreated(_settler);
  }

  @override
  void dispose() {
    _settler.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
