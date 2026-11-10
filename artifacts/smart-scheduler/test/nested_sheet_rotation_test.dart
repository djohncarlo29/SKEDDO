import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/live_rotation_geometry.dart';
import 'package:smart_scheduler/widgets/modal_sheet_scroll_under.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

void main() {
  testWidgets(
    'nested sheet content survives portrait-landscape-portrait rotation',
    (tester) async {
      const portrait = Size(402, 874);
      const landscape = Size(874, 402);
      final previousPhysicalSize = tester.view.physicalSize;
      final previousDevicePixelRatio = tester.view.devicePixelRatio;
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = portrait;
      addTearDown(() {
        tester.view.physicalSize = previousPhysicalSize;
        tester.view.devicePixelRatio = previousDevicePixelRatio;
      });

      final navigatorKey = GlobalKey<NavigatorState>();
      const parentPageKey = ValueKey('rotation-parent-sheet');
      const nestedPageKey = ValueKey('rotation-nested-sheet');
      const nestedContentKey = ValueKey('rotation-nested-content');
      const nestedViewportKey = ValueKey('rotation-nested-viewport');
      const nestedRootKey = ValueKey('rotation-nested-root');

      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigatorKey,
          builder: (context, child) {
            final original = MediaQuery.of(context);
            final isLandscape = original.size.width > original.size.height;
            final topInset = isLandscape ? 24.0 : 30.0;
            final horizontalInset = isLandscape ? 28.0 : 0.0;
            final bottomInset = isLandscape ? 0.0 : 24.0;
            return MediaQuery(
              data: original.copyWith(
                viewPadding: original.viewPadding.copyWith(
                  left: horizontalInset,
                  right: horizontalInset,
                  top: topInset,
                  bottom: bottomInset,
                ),
                padding: original.padding.copyWith(
                  left: horizontalInset,
                  right: horizontalInset,
                  top: topInset,
                  bottom: bottomInset,
                ),
              ),
              child: LiveRotationGeometry(
                child: AppWindowContentBoundary(
                  child: child ?? const SizedBox.shrink(),
                ),
              ),
            );
          },
          home: const CupertinoPageScaffold(
            child: ColoredBox(color: CupertinoColors.systemBackground),
          ),
        ),
      );

      final parentFuture = navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(
          builder: (_) => _RotationSheet(
            key: parentPageKey,
            title: 'Parent',
            nestedPageKey: nestedPageKey,
            nestedContentKey: nestedContentKey,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('open-nested-sheet')));
      await tester.pumpAndSettle();

      final nestedStateBefore = tester.state<_RotationSheetState>(
        find.byKey(nestedPageKey),
      );
      expect(find.byKey(nestedContentKey), findsOneWidget);

      tester.view.physicalSize = landscape;
      await tester.pumpAndSettle();

      expect(
        tester.state<_RotationSheetState>(find.byKey(nestedPageKey)),
        same(nestedStateBefore),
      );
      expect(find.byKey(nestedContentKey), findsOneWidget);
      expect(tester.getSize(find.byKey(nestedContentKey)).isEmpty, isFalse);
      final landscapeViewport = tester.getRect(find.byKey(nestedViewportKey));
      final nestedRoute = ModalRoute.of(
        tester.element(find.byKey(nestedPageKey)),
      );
      expect(nestedRoute?.animation?.value, 1.0);
      expect(landscapeViewport.left, 28);
      expect(landscapeViewport.right, landscape.width - 28);
      expect(tester.getRect(find.byKey(nestedRootKey)).top, 32);

      tester.view.physicalSize = portrait;
      await tester.pumpAndSettle();

      expect(
        tester.state<_RotationSheetState>(find.byKey(nestedPageKey)),
        same(nestedStateBefore),
      );
      expect(find.byKey(nestedContentKey), findsOneWidget);
      expect(tester.getSize(find.byKey(nestedContentKey)).isEmpty, isFalse);
      final portraitViewport = tester.getRect(find.byKey(nestedViewportKey));
      expect(portraitViewport.left, 0);
      expect(portraitViewport.right, portrait.width);
      expect(tester.getRect(find.byKey(nestedRootKey)).top, 35);

      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      navigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      await parentFuture;
    },
  );
}

class _RotationSheet extends StatefulWidget {
  const _RotationSheet({
    super.key,
    required this.title,
    required this.nestedPageKey,
    required this.nestedContentKey,
  });

  final String title;
  final Key nestedPageKey;
  final Key nestedContentKey;

  @override
  State<_RotationSheet> createState() => _RotationSheetState();
}

class _RotationSheetState extends State<_RotationSheet> {
  @override
  Widget build(BuildContext context) {
    final isNested = widget.title == 'Nested';
    return ColoredBox(
      key: isNested ? const ValueKey('rotation-nested-root') : null,
      color: CupertinoColors.systemBackground.resolveFrom(context),
      child: CupertinoPageScaffold(
        backgroundColor: CupertinoColors.systemBackground,
        child: SafeArea(
          bottom: false,
          child: ModalSheetScrollUnder(
            key: isNested ? const ValueKey('rotation-nested-viewport') : null,
            headerTopInset: 8,
            headerHeight: 40,
            headerGap: 12,
            baseScrollPadding: EdgeInsets.zero,
            surfaceColor: CupertinoColors.systemBackground.resolveFrom(context),
            header: SizedBox(
              height: 40,
              child: Center(child: Text(widget.title)),
            ),
            scrollBuilder: (context, padding) => ListView(
              padding: padding,
              children: [
                if (!isNested)
                  CupertinoButton(
                    key: const ValueKey('open-nested-sheet'),
                    onPressed: () => showRoundedCupertinoSheet<void>(
                      context: context,
                      pageBuilder: (_) => _RotationSheet(
                        key: widget.nestedPageKey,
                        title: 'Nested',
                        nestedPageKey: widget.nestedPageKey,
                        nestedContentKey: widget.nestedContentKey,
                      ),
                    ),
                    child: const Text('Open nested sheet'),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Nested sheet content',
                      key: widget.nestedContentKey,
                    ),
                  ),
                const SizedBox(height: 700),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
