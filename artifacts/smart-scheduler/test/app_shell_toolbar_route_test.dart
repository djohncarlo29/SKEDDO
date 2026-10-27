import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_shell_toolbar.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

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

  testWidgets('pinned toolbar keeps its settled scale behind a modal sheet', (
    tester,
  ) async {
    const toolbarKey = ValueKey('toolbar-child');
    const sizePreserverKey = ValueKey('rounded-sheet-toolbar-size-preserver');

    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => AppWindowContentScope(
          horizontalInset: 0,
          physicalWidth: 402,
          child: child!,
        ),
        home: Builder(
          builder: (context) => CupertinoPageScaffold(
            child: preserveRoundedCupertinoSheetToolbarSize(
              context,
              const SizedBox(key: toolbarKey, width: 96, height: 56),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(sizePreserverKey), findsNothing);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.push(
      RoundedCupertinoSheetRoute<void>(builder: (_) => const SizedBox.expand()),
    );
    await tester.pumpAndSettle();

    final transform = tester.widget<Transform>(find.byKey(sizePreserverKey));
    expect(transform.transform.getMaxScaleOnAxis(), greaterThan(1.08));

    navigator.pop();
    await tester.pumpAndSettle();
    expect(find.byKey(sizePreserverKey), findsNothing);
  });
}
