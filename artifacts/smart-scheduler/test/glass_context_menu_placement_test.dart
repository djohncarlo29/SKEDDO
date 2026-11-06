import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContextMenu, GlassContextMenuAction, showGlassContextMenu;

void main() {
  testWidgets('context platter opens below a source near the top', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext context;
    const previewKey = ValueKey('context-preview-top');
    const targetRect = Rect.fromLTWH(100, 24, 180, 60);
    const sourceTile = SizedBox(
      width: 180,
      height: 60,
      child: Center(child: Text('Top preview')),
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return CupertinoPageScaffold(
              child: Stack(
                children: [
                  Positioned.fromRect(rect: targetRect, child: sourceTile),
                ],
              ),
            );
          },
        ),
      ),
    );

    showGlassContextMenu<void>(
      context: context,
      targetRect: targetRect,
      overlaySize: const Size(400, 800),
      actions: [
        GlassContextMenuAction(
          child: const Text('Top action'),
          onPressed: () {},
        ),
      ],
      previewChild: const SizedBox(
        key: previewKey,
        width: 180,
        height: 60,
        child: Center(child: Text('Top preview')),
      ),
      menuWidth: 250,
      platterGap: 12,
      centerPlatterHorizontally: true,
      preferSideWithMoreSpace: true,
    );
    await tester.pumpAndSettle();

    // The source remains in the page under the scrim while the route paints
    // the lifted preview above it.
    expect(find.text('Top preview'), findsNWidgets(2));
    final actionRect = tester.getRect(find.text('Top action'));
    expect(actionRect.top, greaterThan(targetRect.bottom));
    expect(actionRect.left, greaterThan(0));
    expect(actionRect.right, lessThan(400));
  });

  testWidgets('context platter opens above a source near the bottom', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    // Simulate a root route whose inherited MediaQuery is larger than the
    // actual Navigator overlay used for targetRect coordinates.
    tester.view.physicalSize = const Size(400, 1200);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext context;
    const targetRect = Rect.fromLTWH(100, 560, 180, 60);

    await tester.pumpWidget(
      CupertinoApp(
        home: Builder(
          builder: (builderContext) {
            context = builderContext;
            return const CupertinoPageScaffold(
              child: Center(child: Text('Underlying screen')),
            );
          },
        ),
      ),
    );

    showGlassContextMenu<void>(
      context: context,
      targetRect: targetRect,
      overlaySize: const Size(400, 800),
      actions: [
        for (var i = 0; i < 4; i++)
          GlassContextMenuAction(
            child: Text('Bottom action $i'),
            onPressed: () {},
          ),
      ],
      previewChild: const SizedBox(
        width: 180,
        height: 60,
        child: Center(child: Text('Bottom preview')),
      ),
      menuWidth: 250,
      platterGap: 12,
      centerPlatterHorizontally: true,
      preferSideWithMoreSpace: true,
    );
    await tester.pumpAndSettle();

    expect(find.text('Bottom preview'), findsOneWidget);
    final actionRect = tester.getRect(find.text('Bottom action 0'));
    final lastActionRect = tester.getRect(find.text('Bottom action 3'));
    expect(actionRect.bottom, lessThan(targetRect.top));
    expect(actionRect.top, greaterThanOrEqualTo(0));
    expect(lastActionRect.bottom, lessThanOrEqualTo(800));
  });

  testWidgets('widget API anchors to the actual source tile render box', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const tileKey = ValueKey('actual-source-tile');
    const tile = SizedBox(
      width: 180,
      height: 60,
      child: Center(child: Text('Anchored tile')),
    );

    await tester.pumpWidget(
      CupertinoApp(
        home: const CupertinoPageScaffold(
          child: Stack(
            children: [
              Positioned(
                left: 100,
                top: 690,
                child: GlassContextMenu(
                  actions: [
                    GlassContextMenuAction(
                      child: Text('Anchored action'),
                      onPressed: _noop,
                    ),
                  ],
                  menuWidth: 250,
                  child: SizedBox(key: tileKey, child: tile),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final tileRect = tester.getRect(find.byKey(tileKey));
    await tester.longPress(find.text('Anchored tile'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();

    final actionRect = tester.getRect(find.text('Anchored action'));
    expect(actionRect.bottom, lessThan(tileRect.top));
    expect(find.text('Anchored tile'), findsNWidgets(2));
  });
}

void _noop() {}
