import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContextMenuAction, showGlassContextMenu;

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

    expect(find.text('Top preview'), findsOneWidget);
    final actionRect = tester.getRect(find.text('Top action'));
    expect(actionRect.top, greaterThan(targetRect.bottom));
    expect(actionRect.left, greaterThan(0));
    expect(actionRect.right, lessThan(400));
  });

  testWidgets('context platter opens above a source near the bottom', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    late BuildContext context;
    const targetRect = Rect.fromLTWH(100, 690, 180, 60);

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
      actions: [
        GlassContextMenuAction(
          child: const Text('Bottom action'),
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
    final actionRect = tester.getRect(find.text('Bottom action'));
    expect(actionRect.bottom, lessThan(targetRect.top));
    expect(actionRect.top, greaterThanOrEqualTo(0));
  });
}
