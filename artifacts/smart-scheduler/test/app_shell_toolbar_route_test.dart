import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_shell_toolbar.dart';

void main() {
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
