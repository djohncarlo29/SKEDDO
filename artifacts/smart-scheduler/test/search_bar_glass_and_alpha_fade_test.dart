import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as liquid_glass
    show GlassContainer;
import 'package:smart_scheduler/widgets/edge_fade_metrics.dart';
import 'package:smart_scheduler/widgets/horizontal_edge_fade.dart';
import 'package:smart_scheduler/widgets/search_bar_widget.dart';

void main() {
  testWidgets('AppSearchBar uses the package glass surface only', (
    tester,
  ) async {
    final controller = TextEditingController();
    await tester.pumpWidget(
      CupertinoApp(
        home: SizedBox(
          width: 360,
          child: AppSearchBar(controller: controller),
        ),
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
}
