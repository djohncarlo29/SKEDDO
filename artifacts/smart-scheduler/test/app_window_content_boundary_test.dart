import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
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

  testWidgets('centers the source item when the master pane settles', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1024, 600);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

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
    final progress = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(milliseconds: 100),
    );
    final scrollController = ScrollController();
    final anchorKey = GlobalKey();
    double? detailViewportWidth;

    await tester.pumpWidget(
      CupertinoApp(
        home: AppWindowContentScope(
          horizontalInset: geometry.horizontalInset,
          physicalWidth: geometry.physicalWidth,
          child: AppWindowMasterDetailTransition(
            geometry: geometry,
            progress: progress,
            applyDetailPaneInsets: false,
            focusAnchorKey: anchorKey,
            dividerColor: CupertinoColors.separator,
            master: ListView(
              controller: scrollController,
              children: [
                for (var index = 0; index < 30; index++)
                  SizedBox(
                    key: index == 10 ? anchorKey : null,
                    height: 72,
                    child: Center(child: Text('Row $index')),
                  ),
              ],
            ),
            detail: LayoutBuilder(
              builder: (context, constraints) {
                detailViewportWidth = constraints.maxWidth;
                return const ColoredBox(
                  color: CupertinoColors.systemBackground,
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    scrollController.jumpTo(650);
    await tester.pump();

    progress.forward();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final midTransitionTargetRect = tester.getRect(find.byKey(anchorKey));
    final midTransitionViewportRect = tester.getRect(find.byType(ListView));
    expect(
      (midTransitionTargetRect.center.dy -
              midTransitionViewportRect.center.dy)
          .abs(),
      lessThan(2),
    );

    await tester.pumpAndSettle();

    final targetRect = tester.getRect(find.byKey(anchorKey));
    final viewportRect = tester.getRect(find.byType(ListView));
    expect((targetRect.center.dy - viewportRect.center.dy).abs(), lessThan(2));
    expect(viewportRect.width, geometry.masterContentWidth);
    expect(detailViewportWidth, geometry.detailPaneWidth);

    final settledOffset = scrollController.offset;
    await tester.pump(const Duration(milliseconds: 400));
    expect(scrollController.offset, settledOffset);

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
