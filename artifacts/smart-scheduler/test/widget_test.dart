import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/interactive_tap_focus_dismissal.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

void main() {
  testWidgets('rounded sheet dismisses from a downward drag', (tester) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigatorKey,
        builder: (context, child) =>
            AppWindowContentBoundary(child: child ?? const SizedBox.shrink()),
        home: CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              onPressed: () {
                showRoundedCupertinoSheet<void>(
                  context: navigatorKey.currentContext!,
                  pageBuilder: (_) => const CupertinoPageScaffold(
                    child: SizedBox.expand(
                      child: Center(child: Text('Sheet content')),
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Sheet content'), findsOneWidget);

    await tester.dragFrom(const Offset(200, 260), const Offset(200, 660));
    await tester.pumpAndSettle();

    expect(find.text('Sheet content'), findsNothing);
  });

  testWidgets('editable taps keep focus and other taps dismiss it', (
    tester,
  ) async {
    final focusNode = FocusNode();

    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => InteractiveTapFocusDismissal(
          child: child ?? const SizedBox.shrink(),
        ),
        home: CupertinoPageScaffold(
          child: Column(
            children: [
              CupertinoTextField(focusNode: focusNode),
              CupertinoButton(
                onPressed: focusNode.requestFocus,
                child: const Text('Action'),
              ),
            ],
          ),
        ),
      ),
    );

    focusNode.requestFocus();
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.text('Action'));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);

    focusNode.requestFocus();
    await tester.pump();
    await tester.tap(find.byType(CupertinoTextField));
    await tester.pump();
    expect(focusNode.hasFocus, isTrue);

    await tester.pumpWidget(const SizedBox.shrink());
    focusNode.dispose();
  });

  testWidgets('autofocus fields still focus in root modal sheets', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    final focusNode = FocusNode();

    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigatorKey,
        builder: (context, child) => InteractiveTapFocusDismissal(
          child: AppWindowContentBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
        home: CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              onPressed: () {
                showRoundedCupertinoSheet<void>(
                  context: navigatorKey.currentContext!,
                  requestFocus: true,
                  pageBuilder: (_) => CupertinoPageScaffold(
                    child: Column(
                      children: [
                        Center(
                          child: CupertinoTextField(
                            focusNode: focusNode,
                            autofocus: true,
                          ),
                        ),
                        CupertinoButton(
                          onPressed: focusNode.requestFocus,
                          child: const Text('Sheet action'),
                        ),
                      ],
                    ),
                  ),
                );
              },
              child: const Text('Open focused sheet'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open focused sheet'));
    await tester.pumpAndSettle();
    expect(focusNode.hasFocus, isTrue);

    await tester.tap(find.text('Sheet action'));
    await tester.pump();
    expect(focusNode.hasFocus, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
    focusNode.dispose();
  });

  testWidgets('keeps an unsaved modal draft through orientation changes', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();

    Widget buildApp(Size size, EdgeInsets viewPadding) {
      return CupertinoApp(
        navigatorKey: navigatorKey,
        home: CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              onPressed: () {
                showRoundedCupertinoSheet<void>(
                  context: navigatorKey.currentContext!,
                  pageBuilder: (_) => const _DraftSheet(),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            size: size,
            padding: viewPadding,
            viewPadding: viewPadding,
          ),
          child: AppWindowContentBoundary(
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      );
    }

    await tester.pumpWidget(
      buildApp(const Size(390, 844), const EdgeInsets.only(bottom: 34)),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(CupertinoTextField), 'keep this draft');
    await tester.pump();
    final focusedNodeBeforeRotation = FocusManager.instance.primaryFocus;
    expect(focusedNodeBeforeRotation, isNotNull);
    expect(focusedNodeBeforeRotation!.hasFocus, isTrue);

    await tester.pumpWidget(
      buildApp(const Size(844, 390), const EdgeInsets.only(left: 28)),
    );
    await tester.pump();
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller!
          .text,
      'keep this draft',
    );
    expect(FocusManager.instance.primaryFocus, same(focusedNodeBeforeRotation));

    await tester.pumpWidget(
      buildApp(const Size(390, 844), const EdgeInsets.only(bottom: 34)),
    );
    await tester.pump();
    expect(
      tester
          .widget<CupertinoTextField>(find.byType(CupertinoTextField))
          .controller!
          .text,
      'keep this draft',
    );
    expect(FocusManager.instance.primaryFocus, same(focusedNodeBeforeRotation));
  });
}

class _DraftSheet extends StatefulWidget {
  const _DraftSheet();

  @override
  State<_DraftSheet> createState() => _DraftSheetState();
}

class _DraftSheetState extends State<_DraftSheet> {
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
          child: CupertinoTextField(controller: _controller, autofocus: true),
        ),
      ),
    );
  }
}
