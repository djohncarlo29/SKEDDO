import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as liquid_glass
    show AdaptiveLiquidGlassLayer, GlassButton, GlassContainer;
import 'package:smart_scheduler/widgets/edge_fade_metrics.dart';
import 'package:smart_scheduler/widgets/horizontal_edge_fade.dart';
import 'package:smart_scheduler/widgets/native_text_input.dart';
import 'package:smart_scheduler/widgets/search_bar_widget.dart';

void main() {
  testWidgets('AppSearchBar keeps its surface solid and opaque', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(width: 360, child: AppSearchBar(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(liquid_glass.GlassContainer), findsNothing);
    final surface = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('search-bar-solid-surface')),
    );
    final decoration = surface.decoration as ShapeDecoration;
    expect(decoration.color!.a, 1.0);
    expect(
      (decoration.shape as ContinuousRectangleBorder).side,
      BorderSide.none,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('search-bar-solid-surface')),
        matching: find.byType(NativeTextInput),
      ),
      findsOneWidget,
    );
    expect(find.byType(SearchWeightedIcon), findsOneWidget);
    expect(find.byKey(const ValueKey('search-mic')), findsOneWidget);
    expect(find.text('Search'), findsOneWidget);

    controller.dispose();
  });

  testWidgets('search field and cancel circle share a blend layer', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 360,
          child: SearchBarGlassGroup(
            child: Row(
              children: [
                Expanded(
                  child: AppSearchBar(
                    controller: controller,
                    groupedGlass: true,
                  ),
                ),
                SearchCancelButton(
                  searchFocused: true,
                  groupedGlass: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(liquid_glass.AdaptiveLiquidGlassLayer), findsOneWidget);
    final searchSurface = tester.widget<liquid_glass.GlassContainer>(
      find.byType(liquid_glass.GlassContainer),
    );
    expect(searchSurface.useOwnLayer, isFalse);
    expect(searchSurface.settings, isNull);
    final proxyClipFinder = find.ancestor(
      of: find.byType(liquid_glass.GlassContainer),
      matching: find.byType(ClipPath),
    );
    expect(proxyClipFinder, findsOneWidget);
    final proxyClip = tester.widget<ClipPath>(proxyClipFinder);
    expect(proxyClip.clipBehavior, Clip.antiAlias);
    expect(
      (proxyClip.clipper as ShapeBorderClipper).shape,
      isA<ContinuousRectangleBorder>(),
    );
    expect(
      find.descendant(
        of: find.byType(liquid_glass.GlassContainer),
        matching: find.byType(NativeTextInput),
      ),
      findsNothing,
      reason: 'The live text field should not sit inside the glass renderer.',
    );
    final cancelSurface = tester.widget<liquid_glass.GlassButton>(
      find.byType(liquid_glass.GlassButton),
    );
    expect(cancelSurface.useOwnLayer, isFalse);
    expect(cancelSurface.settings, isNull);
    expect(find.byKey(const ValueKey('search-bar-rim-cover')), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('overflowing search text uses an alpha mask', (tester) async {
    final textController = TextEditingController(text: 'search text');
    final metrics = ValueNotifier<EdgeFadeMetrics?>(
      const EdgeFadeMetrics(
        pixels: 0,
        minScrollExtent: 0,
        maxScrollExtent: 100,
        extentBefore: 0,
        extentAfter: 100,
      ),
    );
    const fadeKey = ValueKey('alpha-search-fade');

    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 160,
          height: 44,
          child: HorizontalEdgeFade(
            key: fadeKey,
            controller: textController,
            metricsListenable: metrics,
            fadeColor: CupertinoColors.systemRed,
            alphaMask: true,
            fadeWidth: 20,
            leadingInset: 4,
            trailingInset: 4,
            child: const SizedBox.expand(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('search text overflowing its viewport'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mask = tester.widget<ShaderMask>(
      find.descendant(
        of: find.byKey(fadeKey),
        matching: find.byType(ShaderMask),
      ),
    );
    expect(mask.blendMode, BlendMode.dstIn);

    textController.dispose();
    metrics.dispose();
  });

  testWidgets('short typed search text keeps its fitting-content rubberband', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'short');
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 360,
          child: SearchBarGlassGroup(
            child: Row(
              children: [
                Expanded(
                  child: AppSearchBar(
                    controller: controller,
                    groupedGlass: true,
                  ),
                ),
                SearchCancelButton(
                  searchFocused: true,
                  groupedGlass: true,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final inputFinder = find.byType(NativeTextInput);
    final input = tester.widget<NativeTextInput>(inputFinder);
    final scrollController = input.scrollController!;
    expect(scrollController.hasClients, isTrue);
    expect(scrollController.position.maxScrollExtent, 0);

    final inputRectBefore = tester.getRect(inputFinder);
    final gesture = await tester.startGesture(inputRectBefore.center);
    await gesture.moveBy(const Offset(-12, 0));
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(-12, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.getRect(inputFinder).left,
      lessThan(inputRectBefore.left - 5),
    );
    expect(find.byType(ShaderMask), findsOneWidget);
    expect(scrollController.position.pixels, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.getRect(inputFinder).left, closeTo(inputRectBefore.left, 0.1));
    expect(scrollController.position.pixels, closeTo(0, 0.1));

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
    'placeholder drag is tracked when the editable child ignores hit tests',
    (tester) async {
      final controller = TextEditingController();
      await tester.pumpWidget(
        CupertinoApp(
          home: Center(
            child: SizedBox(
              width: 240,
              height: 48,
              child: HorizontalEdgeFade(
                fadeColor: const Color(0xFFFFFFFF),
                controller: controller,
                placeholderText: 'Search',
                placeholderTextStyle: const TextStyle(fontSize: 18),
                rubberbandWhenContentFits: true,
                fadeOnRubberbandWhenContentFits: true,
                child: const IgnorePointer(child: SizedBox.expand()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final placeholder = find.text('Search');
      final before = tester.getRect(placeholder);
      final gesture = await tester.startGesture(before.center);
      await gesture.moveBy(const Offset(-24, 0));
      await tester.pump(const Duration(milliseconds: 16));
      expect(
        tester.getRect(placeholder).left,
        lessThan(before.left - 5),
        reason: 'The wrapper must observe drags on its painted placeholder.',
      );

      await gesture.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(placeholder).left, closeTo(before.left, 0.1));

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    },
  );

  testWidgets('short placeholder follows the drag and bounce-back together', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(width: 360, child: AppSearchBar(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();
    NativeTextInput.focus(controller);
    await tester.pumpAndSettle();

    final inputFinder = find.byType(NativeTextInput);
    final input = tester.widget<NativeTextInput>(inputFinder);
    expect(input.placeholder, isEmpty);
    expect(input.rubberbandWhenContentFits, isTrue);
    final edgeFade = tester.widget<HorizontalEdgeFade>(
      find.byType(HorizontalEdgeFade),
    );
    expect(edgeFade.placeholderInChild, isFalse);
    expect(edgeFade.placeholderFocusListenable, isNotNull);
    expect(edgeFade.rubberbandWhenContentFits, isTrue);
    final placeholderFinder = find.text('Search');
    expect(
      find.descendant(of: inputFinder, matching: placeholderFinder),
      findsNothing,
      reason: 'The hint must be owned by the moving edge-fade layer.',
    );
    final inputBefore = tester.getRect(inputFinder);
    final placeholderBefore = tester.getRect(placeholderFinder);
    final gesture = await tester.startGesture(placeholderBefore.center);
    await gesture.moveBy(const Offset(-24, 0));
    await tester.pump(const Duration(milliseconds: 16));

    final inputDuringDrag = tester.getRect(inputFinder);
    final placeholderDuringDrag = tester.getRect(placeholderFinder);
    expect(inputDuringDrag.left, lessThan(inputBefore.left - 5));
    expect(
      placeholderDuringDrag.left,
      lessThan(placeholderBefore.left - 5),
    );
    expect(find.byType(ShaderMask), findsOneWidget);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 100));
    final inputDuringReturn = tester.getRect(inputFinder);
    final placeholderDuringReturn = tester.getRect(placeholderFinder);
    expect(
      inputDuringReturn.left - inputBefore.left,
      closeTo(
        placeholderDuringReturn.left - placeholderBefore.left,
        0.5,
      ),
    );
    expect(inputDuringReturn.left, lessThan(inputBefore.left));

    await tester.pumpAndSettle();
    expect(tester.getRect(inputFinder).left, closeTo(inputBefore.left, 0.1));
    expect(
      tester.getRect(placeholderFinder).left,
      closeTo(placeholderBefore.left, 0.1),
    );

    final gestureRight = await tester.startGesture(placeholderBefore.center);
    await gestureRight.moveBy(const Offset(24, 0));
    await tester.pump(const Duration(milliseconds: 16));
    expect(
      tester.getRect(placeholderFinder).left,
      greaterThan(placeholderBefore.left + 5),
    );
    await gestureRight.up();
    await tester.pumpAndSettle();
    expect(
      tester.getRect(placeholderFinder).left,
      closeTo(placeholderBefore.left, 0.1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('search placeholder tracks editable-field overscroll metrics', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(width: 360, child: AppSearchBar(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    final input = tester.widget<NativeTextInput>(find.byType(NativeTextInput));
    final scrollController = input.scrollController!;
    expect(scrollController.hasClients, isTrue);
    expect(scrollController.position.maxScrollExtent, 0);

    final placeholder = find.text('Search');
    final before = tester.getRect(placeholder);
    scrollController.jumpTo(-18);
    await tester.pump(const Duration(milliseconds: 1));
    final nativeOverscroll = scrollController.position.pixels;
    expect(nativeOverscroll, lessThan(-1));

    expect(
      tester.getRect(placeholder).left,
      closeTo(before.left - nativeOverscroll, 0.5),
      reason:
          'The visible hint must track the editable text viewport’s own '
          'rubberband offset, not only the wrapper’s synthetic drag offset.',
    );

    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('fitting placeholder follows the web rubberband fallback', (
    tester,
  ) async {
    final controller = TextEditingController();
    final metrics = ValueNotifier<EdgeFadeMetrics?>(
      const EdgeFadeMetrics(
        pixels: 0,
        minScrollExtent: 0,
        maxScrollExtent: 0,
        extentBefore: 0,
        extentAfter: 0,
      ),
    );
    const fadeKey = ValueKey('fitting-placeholder-fade');
    const contentKey = ValueKey('fitting-placeholder-content');

    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 240,
          height: 44,
          child: HorizontalEdgeFade(
            key: fadeKey,
            controller: controller,
            metricsListenable: metrics,
            fadeColor: CupertinoColors.systemBackground,
            fadeOnRubberbandWhenContentFits: true,
            rubberbandWhenContentFits: true,
            alphaMask: true,
            placeholderText: 'Search',
            placeholderTextStyle: const TextStyle(fontSize: 17),
            child: const SizedBox.expand(key: contentKey),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final contentBefore = tester.getRect(find.byKey(contentKey));
    final placeholderBefore = tester.getRect(find.text('Search'));
    metrics.value = const EdgeFadeMetrics(
      pixels: -18,
      minScrollExtent: 0,
      maxScrollExtent: 0,
      extentBefore: 0,
      extentAfter: 0,
    );
    await tester.pump();

    expect(
      tester.getRect(find.byKey(contentKey)).left,
      closeTo(contentBefore.left + 18, 0.5),
    );
    expect(
      tester.getRect(find.text('Search')).left,
      closeTo(placeholderBefore.left + 18, 0.5),
    );
    expect(
      find.descendant(
        of: find.byKey(fadeKey),
        matching: find.byType(ShaderMask),
      ),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    metrics.dispose();
  });
}
