import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';

void main() {
  testWidgets(
    'keeps modal draft state when landscape safe-area insets appear or disappear',
    (tester) async {
      Widget buildApp(Size size, EdgeInsets viewPadding) {
        final data = MediaQueryData(
          size: size,
          padding: viewPadding,
          viewPadding: viewPadding,
        );
        return CupertinoApp(
          home: const _DraftForm(),
          builder: (context, child) => MediaQuery(
            data: data,
            child: AppWindowContentBoundary(
              child: AppWindowContentPadding(
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(
        buildApp(const Size(390, 844), const EdgeInsets.only(bottom: 34)),
      );
      await tester.enterText(find.byType(CupertinoTextField), 'unsaved draft');
      await tester.pump();

      await tester.pumpWidget(
        buildApp(const Size(844, 390), const EdgeInsets.only(left: 28)),
      );
      await tester.pump();
      expect(
        tester
            .widget<CupertinoTextField>(find.byType(CupertinoTextField))
            .controller!
            .text,
        'unsaved draft',
      );

      await tester.pumpWidget(
        buildApp(const Size(390, 844), const EdgeInsets.only(bottom: 34)),
      );
      await tester.pump();
      expect(
        tester
            .widget<CupertinoTextField>(find.byType(CupertinoTextField))
            .controller!
            .text,
        'unsaved draft',
      );
    },
  );

  test('reserves the same landscape inset regardless of physical side', () {
    final landscape = MediaQueryData(size: const Size(844, 390));
    final leftCutout = landscape.copyWith(
      viewPadding: const EdgeInsets.only(left: 52),
    );
    final rightCutout = landscape.copyWith(
      viewPadding: const EdgeInsets.only(right: 52),
    );

    expect(AppWindowContentBoundary.landscapeSystemInsetFor(leftCutout), 52);
    expect(AppWindowContentBoundary.landscapeSystemInsetFor(rightCutout), 52);
  });

  test('does not reserve horizontal landscape space in portrait', () {
    final portrait = MediaQueryData(size: const Size(390, 844));
    final withInset = portrait.copyWith(
      viewPadding: const EdgeInsets.only(left: 52),
    );

    expect(AppWindowContentBoundary.landscapeSystemInsetFor(withInset), 0);
  });

  test('centers a floating overlay on portrait-width master content', () {
    const geometry = AppWindowMasterDetailGeometry(
      isLandscape: true,
      physicalWidth: 1024,
      horizontalInset: 32,
      portraitShortEdgeWidth: 468,
      masterPaneWidth: 500,
      masterContentWidth: 468,
      detailPaneWidth: 523.25,
      detailContentWidth: 491.25,
    );

    final tabBarCenter =
        geometry.physicalWidth / 2 + geometry.masterContentCenterOffset;

    expect(
      tabBarCenter,
      geometry.horizontalInset + geometry.masterContentWidth / 2,
    );
    expect(tabBarCenter, 266);
  });

  test('interpolates the shared master/detail pane geometry', () {
    const geometry = AppWindowMasterDetailGeometry(
      isLandscape: true,
      physicalWidth: 1024,
      horizontalInset: 32,
      portraitShortEdgeWidth: 468,
      masterPaneWidth: 500,
      masterContentWidth: 468,
      detailPaneWidth: 523.25,
      detailContentWidth: 491.25,
    );

    expect(geometry.masterPaneWidthAt(0), 1024);
    expect(geometry.masterPaneWidthAt(1), 500);
    expect(geometry.masterContentWidthAt(0), 960);
    expect(geometry.masterContentWidthAt(1), 468);
    expect(geometry.dividerWidthAt(0), 0);
    expect(geometry.dividerWidthAt(1), 0.75);
    expect(geometry.detailPaneWidthAt(0), 0);
    expect(geometry.detailPaneWidthAt(1), 523.25);
    expect(geometry.detailContentWidthAt(1), 491.25);
  });

  testWidgets(
    'keeps visible anchors in place and reveals them in both pane directions',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final progress = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 100),
      );
      final scrollController = ScrollController();
      final anchorKey = GlobalKey();

      await tester.pumpWidget(
        _focusTransitionApp(
          progress: progress,
          scrollController: scrollController,
          anchorKey: anchorKey,
          anchorIndex: 10,
        ),
      );
      await tester.pump();
      scrollController.jumpTo(650);
      await tester.pump();

      progress.forward();
      await tester.pumpAndSettle();
      expect(scrollController.offset, 650);
      _expectAnchorVisible(tester, anchorKey, avoidTabBar: true);

      // Closing the pane must also restore a selected row that has moved above
      // the usable viewport while the split is open.
      scrollController.jumpTo(900);
      await tester.pump();
      progress.reverse();
      await tester.pumpAndSettle();
      _expectAnchorVisible(tester, anchorKey, avoidTabBar: true);
      expect(scrollController.offset, closeTo(720, 1));

      // Opening from full width must reveal the same row if it starts below
      // the usable area, without centering it under the floating tab bar.
      scrollController.jumpTo(0);
      await tester.pump();
      progress.forward();
      await tester.pumpAndSettle();
      _expectAnchorVisible(tester, anchorKey, avoidTabBar: true);
      expect(scrollController.offset, closeTo(270, 1));

      await tester.pumpWidget(const SizedBox.shrink());
      progress.dispose();
      scrollController.dispose();
    },
  );

  testWidgets(
    'keeps the selected item at its visual position when row heights reflow',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final progress = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 100),
      );
      final scrollController = ScrollController();
      final anchorKey = GlobalKey();

      await tester.pumpWidget(
        _focusTransitionApp(
          progress: progress,
          scrollController: scrollController,
          anchorKey: anchorKey,
          anchorIndex: 10,
          variableHeights: true,
        ),
      );
      await tester.pump();
      scrollController.jumpTo(650);
      await tester.pump();
      final initialTop = tester.getTopLeft(find.byKey(anchorKey)).dy;

      progress.forward();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(anchorKey)).dy, closeTo(initialTop, 1));
      _expectAnchorVisible(tester, anchorKey, avoidTabBar: true);

      progress.reverse();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.byKey(anchorKey)).dy, closeTo(initialTop, 1));
      _expectAnchorVisible(tester, anchorKey, avoidTabBar: true);

      await tester.pumpWidget(const SizedBox.shrink());
      progress.dispose();
      scrollController.dispose();
    },
  );

  testWidgets(
    'respects a full-screen Settings bottom safe-area clearance',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1024, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      final progress = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(milliseconds: 100),
      );
      final scrollController = ScrollController();
      final anchorKey = GlobalKey();

      await tester.pumpWidget(
        _focusTransitionApp(
          progress: progress,
          scrollController: scrollController,
          anchorKey: anchorKey,
          anchorIndex: 7,
          avoidTabBar: false,
          focusBottomClearance: 80,
        ),
      );
      await tester.pump();

      progress.forward();
      await tester.pumpAndSettle();

      expect(scrollController.offset, closeTo(56, 1));
      _expectAnchorVisible(
        tester,
        anchorKey,
        avoidTabBar: false,
        bottomClearance: 80,
      );
      final settledOffset = scrollController.offset;
      await tester.pump(const Duration(milliseconds: 250));
      expect(scrollController.offset, settledOffset);

      await tester.pumpWidget(const SizedBox.shrink());
      progress.dispose();
      scrollController.dispose();
    },
  );

  testWidgets('rapid reversal settles anchor and pane together', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final progress = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 100),
    );
    final scrollController = ScrollController();
    final anchorKey = GlobalKey();

    await tester.pumpWidget(
      _focusTransitionApp(
        progress: progress,
        scrollController: scrollController,
        anchorKey: anchorKey,
        anchorIndex: 10,
      ),
    );
    await tester.pump();
    scrollController.jumpTo(0);
    await tester.pump();

    progress.forward();
    await tester.pump(const Duration(milliseconds: 40));
    progress.reverse();
    await tester.pumpAndSettle();
    _expectAnchorVisible(tester, anchorKey, avoidTabBar: true);
    expect(progress.status, AnimationStatus.dismissed);
    final settledOffset = scrollController.offset;
    await tester.pump(const Duration(milliseconds: 250));
    expect(scrollController.offset, settledOffset);

    await tester.pumpWidget(const SizedBox.shrink());
    progress.dispose();
    scrollController.dispose();
  });

  testWidgets('waits for pane motion to settle before revealing a hidden row', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final progress = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 100),
    );
    final scrollController = ScrollController(initialScrollOffset: 650);
    final anchorKey = GlobalKey();

    await tester.pumpWidget(
      _focusTransitionApp(
        progress: progress,
        scrollController: scrollController,
        anchorKey: anchorKey,
        anchorIndex: 10,
      ),
    );
    await tester.pump();
    expect(scrollController.offset, 650);
    _expectAnchorVisible(tester, anchorKey, avoidTabBar: true);

    scrollController.jumpTo(0);
    await tester.pump();
    progress.forward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 51));
    expect(progress.status, AnimationStatus.forward);
    expect(scrollController.offset, greaterThan(0));
    expect(scrollController.offset, lessThan(270));

    await tester.pump(const Duration(milliseconds: 50));
    expect(progress.status, AnimationStatus.completed);
    // The row correction reaches its final offset on the same frame as the
    // pane transition, with no trailing independent animation.
    expect(scrollController.offset, closeTo(270, 1));

    await tester.pumpAndSettle();
    expect(scrollController.offset, closeTo(270, 1));
    _expectAnchorVisible(tester, anchorKey, avoidTabBar: true);

    await tester.pumpWidget(const SizedBox.shrink());
    progress.dispose();
    scrollController.dispose();
  });

  testWidgets('uses the full viewport bottom when tab-bar avoidance is off', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final progress = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 100),
    );
    final scrollController = ScrollController();
    final anchorKey = GlobalKey();

    await tester.pumpWidget(
      _focusTransitionApp(
        progress: progress,
        scrollController: scrollController,
        anchorKey: anchorKey,
        anchorIndex: 26,
        avoidTabBar: false,
      ),
    );
    await tester.pump();
    scrollController.jumpTo(1350);
    await tester.pump();

    progress.forward();
    await tester.pumpAndSettle();

    expect(scrollController.offset, 1350);
    _expectAnchorVisible(tester, anchorKey, avoidTabBar: false);

    await tester.pumpWidget(const SizedBox.shrink());
    progress.dispose();
    scrollController.dispose();
  });

  test('uses only persistent view padding, not padding or gesture insets', () {
    final landscape = MediaQueryData(size: const Size(844, 390));
    final withPlatformInsets = landscape.copyWith(
      padding: const EdgeInsets.only(right: 96),
      viewPadding: const EdgeInsets.only(right: 48),
      viewInsets: const EdgeInsets.only(left: 120),
      systemGestureInsets: const EdgeInsets.only(left: 144),
    );

    expect(
      AppWindowContentBoundary.landscapeSystemInsetFor(withPlatformInsets),
      48,
    );
  });

  test('keyboard viewInsets do not change the landscape reservation', () {
    final base = MediaQueryData(
      size: const Size(844, 390),
      viewPadding: const EdgeInsets.only(left: 52),
    );
    final keyboardVisible = base.copyWith(
      viewInsets: const EdgeInsets.only(bottom: 280),
      padding: const EdgeInsets.only(bottom: 280),
    );

    expect(
      AppWindowContentBoundary.landscapeSystemInsetFor(keyboardVisible),
      AppWindowContentBoundary.landscapeSystemInsetFor(base),
    );
  });

  testWidgets('content padding clears one-sided insets for nested safe areas', (
    tester,
  ) async {
    EdgeInsets? nestedPadding;
    EdgeInsets? nestedViewPadding;
    EdgeInsets? nestedGestureInsets;
    double? reservedInset;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(844, 390),
          padding: EdgeInsets.only(left: 52),
          viewPadding: EdgeInsets.only(left: 52),
          systemGestureInsets: EdgeInsets.only(left: 52),
        ),
        child: AppWindowContentBoundary(
          child: AppWindowContentPadding(
            child: Builder(
              builder: (context) {
                  reservedInset =
                      AppWindowContentScope.of(context).horizontalInset;
                nestedPadding = MediaQuery.paddingOf(context);
                nestedViewPadding = MediaQuery.viewPaddingOf(context);
                nestedGestureInsets = MediaQuery.systemGestureInsetsOf(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );

    expect(reservedInset, 52);
    expect(nestedPadding!.left, 0);
    expect(nestedPadding!.right, 0);
    expect(nestedViewPadding!.left, 0);
    expect(nestedViewPadding!.right, 0);
    expect(nestedGestureInsets!.left, 0);
    expect(nestedGestureInsets!.right, 0);
  });

  testWidgets('content padding preserves portrait safe areas', (tester) async {
    EdgeInsets? nestedPadding;
    EdgeInsets? nestedViewPadding;
    double? reservedInset;

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          padding: EdgeInsets.only(left: 18),
          viewPadding: EdgeInsets.only(left: 18),
        ),
        child: AppWindowContentBoundary(
          child: AppWindowContentPadding(
            child: Builder(
              builder: (context) {
                  reservedInset =
                      AppWindowContentScope.of(context).horizontalInset;
                nestedPadding = MediaQuery.paddingOf(context);
                nestedViewPadding = MediaQuery.viewPaddingOf(context);
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );

    expect(reservedInset, 0);
    expect(nestedPadding!.left, 18);
    expect(nestedViewPadding!.left, 18);
  });
}

const _focusTestGeometry = AppWindowMasterDetailGeometry(
  isLandscape: true,
  physicalWidth: 1024,
  horizontalInset: 32,
  portraitShortEdgeWidth: 468,
  masterPaneWidth: 500,
  masterContentWidth: 468,
  detailPaneWidth: 523.25,
  detailContentWidth: 491.25,
);

Widget _focusTransitionApp({
  required Animation<double> progress,
  required ScrollController scrollController,
  required GlobalKey anchorKey,
  required int anchorIndex,
  bool avoidTabBar = true,
  double focusBottomClearance = 0.0,
  bool variableHeights = false,
}) {
  return CupertinoApp(
    home: AppWindowContentScope(
      horizontalInset: _focusTestGeometry.horizontalInset,
      physicalWidth: _focusTestGeometry.physicalWidth,
      child: AppWindowMasterDetailTransition(
        geometry: _focusTestGeometry,
        progress: progress,
        applyDetailPaneInsets: false,
        focusAnchorKey: anchorKey,
        focusRevealDuration: const Duration(milliseconds: 100),
        focusAvoidTabBar: avoidTabBar,
        focusBottomClearance: focusBottomClearance,
        dividerColor: CupertinoColors.separator,
        master: ListView(
          controller: scrollController,
          children: [
            for (var index = 0; index < 30; index++)
              LayoutBuilder(
                builder: (context, constraints) {
                  final height = variableHeights && constraints.maxWidth < 650
                      ? 96.0
                      : 72.0;
                  return SizedBox(
                    key: index == anchorIndex ? anchorKey : null,
                    height: height,
                    child: Center(child: Text('Row $index')),
                  );
                },
              ),
          ],
        ),
        detail: const ColoredBox(color: CupertinoColors.systemBackground),
      ),
    ),
  );
}

void _expectAnchorVisible(
  WidgetTester tester,
  GlobalKey anchorKey, {
  required bool avoidTabBar,
  double bottomClearance = 0.0,
}) {
  final anchorRect = tester.getRect(find.byKey(anchorKey));
  final viewportRect = tester.getRect(find.byType(ListView));
  final context = tester.element(find.byType(AppWindowMasterDetailTransition));
  final bottom = avoidTabBar
      ? math.min(
          viewportRect.bottom,
          MediaQuery.sizeOf(context).height -
              floatingTabBarContentBottomClearance(context),
        )
      : viewportRect.bottom - bottomClearance;
  expect(anchorRect.top, greaterThanOrEqualTo(viewportRect.top - 1));
  expect(anchorRect.bottom, lessThanOrEqualTo(bottom + 1));
}

class _DraftForm extends StatefulWidget {
  const _DraftForm();

  @override
  State<_DraftForm> createState() => _DraftFormState();
}

class _DraftFormState extends State<_DraftForm> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
        child: SizedBox(
          width: 260,
          child: CupertinoTextField(controller: _controller),
        ),
      ),
    );
  }
}
