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
  testWidgets('AppSearchBar uses the package glass surface only', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(width: 360, child: AppSearchBar(controller: controller)),
      ),
    );
    await tester.pumpAndSettle();

    final glass = tester.widget<liquid_glass.GlassContainer>(
      find.byType(liquid_glass.GlassContainer),
    );
    expect(glass.useOwnLayer, isTrue);
    expect(glass.settings, isNotNull);
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
    final cancelSurface = tester.widget<liquid_glass.GlassButton>(
      find.byType(liquid_glass.GlassButton),
    );
    expect(cancelSurface.useOwnLayer, isFalse);
    expect(cancelSurface.settings, isNull);

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

  testWidgets('short typed search text keeps its horizontal rubberband', (
    tester,
  ) async {
    final controller = TextEditingController(text: 'short');
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(width: 360, child: AppSearchBar(controller: controller)),
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
    await gesture.moveBy(const Offset(-24, 0));
    await tester.pump();
    expect(
      tester.getRect(inputFinder).left,
      lessThan(inputRectBefore.left - 5),
    );
    expect(scrollController.position.pixels, 0);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(
      tester.getRect(inputFinder).left,
      closeTo(inputRectBefore.left, 0.1),
    );
    expect(scrollController.position.pixels, closeTo(0, 0.1));

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
