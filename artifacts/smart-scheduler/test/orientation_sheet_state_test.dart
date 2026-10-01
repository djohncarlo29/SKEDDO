import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/live_rotation_geometry.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

void main() {
  testWidgets(
    'an open sheet keeps its draft and focus when the window rotates',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigatorKey,
          builder: (context, child) {
            final original = MediaQuery.of(context);
            final landscape = original.size.width > original.size.height;
            return MediaQuery(
              data: original.copyWith(
                viewPadding: original.viewPadding.copyWith(
                  left: landscape ? 28 : 0,
                  right: 0,
                  bottom: landscape ? 0 : 34,
                ),
                padding: original.padding.copyWith(
                  left: landscape ? 28 : 0,
                  right: 0,
                  bottom: landscape ? 0 : 34,
                ),
              ),
              child: LiveRotationGeometry(
                child: AppWindowContentBoundary(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          home: Builder(
            builder: (context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  key: const ValueKey('open-sheet'),
                  onPressed: () => showRoundedCupertinoSheet<void>(
                    context: context,
                    pageBuilder: (_) => const _DraftSheet(),
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('open-sheet')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('draft-field')));
      await tester.enterText(
        find.byKey(const ValueKey('draft-field')),
        'Keep this draft',
      );
      await tester.pump();

      final sheetStateBefore = tester.state<_DraftSheetState>(
        find.byType(_DraftSheet),
      );
      expect(sheetStateBefore.controller.text, 'Keep this draft');
      expect(sheetStateBefore.focusNode.hasFocus, isTrue);

      await tester.binding.setSurfaceSize(const Size(874, 402));
      await tester.pumpAndSettle();

      final sheetStateAfter = tester.state<_DraftSheetState>(
        find.byType(_DraftSheet),
      );
      expect(identical(sheetStateAfter, sheetStateBefore), isTrue);
      expect(sheetStateAfter.controller.text, 'Keep this draft');
      expect(sheetStateAfter.focusNode.hasFocus, isTrue);
    },
  );
}

class _DraftSheet extends StatefulWidget {
  const _DraftSheet();

  @override
  State<_DraftSheet> createState() => _DraftSheetState();
}

class _DraftSheetState extends State<_DraftSheet> {
  final controller = TextEditingController();
  final focusNode = FocusNode();

  @override
  void dispose() {
    controller.dispose();
    focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Center(
        child: SizedBox(
          width: 320,
          child: CupertinoTextField(
            key: const ValueKey('draft-field'),
            controller: controller,
            focusNode: focusNode,
          ),
        ),
      ),
    );
  }
}