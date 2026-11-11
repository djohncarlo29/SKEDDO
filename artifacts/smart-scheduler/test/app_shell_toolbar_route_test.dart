import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_shell_toolbar.dart';

void main() {
  test('landscape toolbar inset keeps its circle 16pt from the edge', () {
    expect(
      kAppShellLandscapeToolbarMinimumTopInset +
          (kAppShellPinnedToolbarDefaultHeight -
                  kAppShellPinnedToolbarButtonSize) /
              2,
      kAppShellLandscapeToolbarTopEdgeGap,
    );
    final immersiveLandscape = MediaQueryData(
      size: const Size(874, 402),
      padding: EdgeInsets.zero,
    );
    expect(
      appShellMediaQueryWithLandscapeToolbarInset(immersiveLandscape)
          .padding
          .top,
      kAppShellLandscapeToolbarMinimumTopInset,
    );

    final portrait = MediaQueryData(
      size: const Size(402, 874),
      padding: EdgeInsets.zero,
    );
    expect(
      appShellMediaQueryWithLandscapeToolbarInset(portrait).padding.top,
      0,
    );

    final existingLandscapeInset = MediaQueryData(
      size: const Size(874, 402),
      padding: const EdgeInsets.only(top: 24),
    );
    expect(
      appShellMediaQueryWithLandscapeToolbarInset(existingLandscapeInset)
          .padding
          .top,
      24,
    );
  });

  testWidgets('toolbar state route passes taps through to the active screen', (
    tester,
  ) async {
    var tapCount = 0;
    final buttonKey = GlobalKey();

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              key: buttonKey,
              onPressed: () => tapCount++,
              child: const Text('Screen action'),
            ),
          ),
        ),
      ),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      appShellToolbarStateRoute(
        name: 'test-toolbar-state',
        toolbarBuilder: (_) => const SizedBox(height: 56),
        onSystemBack: () {},
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(buttonKey));

    expect(tapCount, 1);
  });

}
