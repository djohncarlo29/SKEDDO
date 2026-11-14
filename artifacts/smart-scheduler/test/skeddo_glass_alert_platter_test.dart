import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show
        GlassDialogAction,
        GlassInteractiveContainer,
        AdaptiveLiquidGlassLayer,
        GlassQuality,
        LiquidGlassSettings,
        LiquidRoundedSuperellipse;
import 'package:smart_scheduler/widgets/skeddo_glass_alert_platter.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';

void main() {
  testWidgets('category alert platter uses the 1.17 layout and actions', (
    tester,
  ) async {
    String? selectedAction;
    const actions = [
      GlassDialogAction(
        label: 'Delete Category Only',
        isPrimary: true,
        onPressed: _noop,
      ),
      GlassDialogAction(
        label: 'Delete Category & Contents',
        isDestructive: true,
        onPressed: _noop,
      ),
      GlassDialogAction(label: 'Cancel', onPressed: _noop),
    ];

    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SkeddoGlassAlertPlatter(
              title: 'Delete the category "Draggable"?',
              message: 'Choose how to handle its events.',
              actions: [
                for (final action in actions)
                  GlassDialogAction(
                    label: action.label,
                    isDestructive: action.isDestructive,
                    onPressed: () => selectedAction = action.label,
                  ),
              ],
              settings: const LiquidGlassSettings(),
              quality: GlassQuality.standard,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Delete the category "Draggable"?'), findsOneWidget);
    expect(find.text('Choose how to handle its events.'), findsOneWidget);
    expect(find.text('Delete Category Only'), findsOneWidget);
    expect(find.text('Delete Category & Contents'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final titleRect = tester.getRect(
      find.text('Delete the category "Draggable"?'),
    );
    final messageRect = tester.getRect(
      find.text('Choose how to handle its events.'),
    );
    final firstButtonRect = tester.getRect(
      find.ancestor(
        of: find.text('Delete Category Only'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(messageRect.top - titleRect.bottom, closeTo(14.5, 0.1));
    expect(firstButtonRect.top - messageRect.bottom, closeTo(20.33, 0.1));
    final destructiveButtonRect = tester.getRect(
      find.ancestor(
        of: find.text('Delete Category & Contents'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    final cancelButtonRect = tester.getRect(
      find.ancestor(
        of: find.text('Cancel'),
        matching: find.byType(AnimatedContainer),
      ),
    );
    expect(destructiveButtonRect.bottom, lessThan(cancelButtonRect.top));

    final platter = tester.widget<GlassInteractiveContainer>(
      find.byType(GlassInteractiveContainer),
    );
    expect(platter.shape, const LiquidRoundedSuperellipse(borderRadius: 34));
    expect(platter.quality, GlassQuality.standard);
    expect(platter.useOwnLayer, isFalse);
    expect(find.byType(AdaptiveLiquidGlassLayer), findsOneWidget);
    expect(platter.enableInteractionGlow, isTrue);
    expect(platter.stretch, 0.5);
    expect(platter.interactionScale, 1.02);
    expect(
      tester.widget<Text>(find.text('Delete Category Only')).style?.fontWeight,
      FontWeight.w400,
    );

    await tester.tap(find.text('Delete Category & Contents'));
    await tester.pump();
    expect(selectedAction, 'Delete Category & Contents');
  });

  testWidgets(
    'dialog capture is active during entry and its barrier covers safe areas',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        CupertinoApp(
          builder: (context, child) => AppWindowContentBoundary(child: child!),
          home: Builder(
            builder: (context) => CupertinoPageScaffold(
              child: Center(
                child: CupertinoButton(
                  onPressed: () {
                    showSkeddoGlassAlertDialog<void>(
                      context: context,
                      title: 'Confirm action',
                      actionsBuilder: (dialogContext) => [
                        GlassDialogAction(
                          label: 'Done',
                          onPressed: () => Navigator.of(dialogContext).pop(),
                        ),
                      ],
                    );
                  },
                  child: const Text('Open dialog'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open dialog'));
      await tester.pump();

      expect(
        find.byKey(const ValueKey('skeddo-glass-alert-fullscreen-layer')),
        findsOneWidget,
      );
      expect(find.byType(AdaptiveLiquidGlassLayer), findsOneWidget);
      expect(find.byType(GlassInteractiveContainer), findsOneWidget);
      expect(
        tester
            .widget<GlassInteractiveContainer>(
              find.byType(GlassInteractiveContainer),
            )
            .useOwnLayer,
        isFalse,
      );
      expect(
        find.byKey(const ValueKey('safe-popup-bottom-cover')),
        findsNothing,
      );

      final barrier = find.byType(AnimatedModalBarrier);
      expect(tester.getRect(barrier.last), const Rect.fromLTWH(0, 0, 390, 844));

      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(AdaptiveLiquidGlassLayer), findsOneWidget);
      expect(find.byType(GlassInteractiveContainer), findsOneWidget);

      await tester.tap(find.text('Done'));
      await tester.pump();
      expect(find.byType(AdaptiveLiquidGlassLayer), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 40));
      expect(find.byType(AdaptiveLiquidGlassLayer), findsOneWidget);
    },
  );

  testWidgets('alert platter stays legible at accessibility text scaling', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!,
        ),
        home: CupertinoPageScaffold(
          child: Center(
            child: SkeddoGlassAlertPlatter(
              title: 'Delete the category "Draggable"?',
              message:
                  'Choose whether to move the category and its event together.',
              actions: const [
                GlassDialogAction(
                  label: 'Delete Category Only',
                  onPressed: _noop,
                ),
                GlassDialogAction(
                  label: 'Delete Category & Contents',
                  isDestructive: true,
                  onPressed: _noop,
                ),
                GlassDialogAction(label: 'Cancel', onPressed: _noop),
              ],
              settings: const LiquidGlassSettings(),
              quality: GlassQuality.standard,
            ),
          ),
        ),
      ),
    );

    await tester.pump();
    expect(find.text('Delete Category & Contents'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('long action labels wrap and grow their button', (tester) async {
    const longLabel =
        'Permanently delete this event and remove it from Recently Deleted';
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SkeddoGlassAlertPlatter(
              title: 'Confirm deletion?',
              message: 'This action cannot be undone.',
              actions: const [
                GlassDialogAction(label: longLabel, onPressed: _noop),
                GlassDialogAction(label: 'Keep Event', onPressed: _noop),
                GlassDialogAction(label: 'Cancel', onPressed: _noop),
              ],
              settings: const LiquidGlassSettings(),
              quality: GlassQuality.standard,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final text = tester.widget<Text>(find.text(longLabel));
    final button = find.ancestor(
      of: find.text(longLabel),
      matching: find.byType(AnimatedContainer),
    );
    expect(text.maxLines, isNull);
    expect(text.overflow, isNull);
    expect(tester.getSize(button).height, greaterThan(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('overflowing platter fades edges and shows its scroll pill', (
    tester,
  ) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SkeddoGlassAlertPlatter(
              title: 'Choose an action',
              message: 'This dialog has enough options to require scrolling.',
              actions: [
                for (var index = 0; index < 10; index++)
                  GlassDialogAction(
                    label: 'Action ${index + 1}',
                    onPressed: _noop,
                  ),
              ],
              settings: const LiquidGlassSettings(),
              quality: GlassQuality.standard,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final scrollable = tester.widget<SingleChildScrollView>(
      find.byKey(const ValueKey('skeddo-glass-alert-scroll-viewport')),
    );
    expect(scrollable.controller!.position.maxScrollExtent, greaterThan(0));
    final platterRect = tester.getRect(find.byType(GlassInteractiveContainer));
    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(platterRect.top, closeTo(16, 0.1));
    expect(screenHeight - platterRect.bottom, closeTo(16, 0.1));
    expect(
      find.byKey(const ValueKey('skeddo-glass-alert-scroll-fade')),
      findsOneWidget,
    );

    await tester.drag(
      find.byKey(const ValueKey('skeddo-glass-alert-scroll-viewport')),
      const Offset(0, -120),
    );
    await tester.pump();
    final indicator = tester.widget<AnimatedOpacity>(
      find.byKey(const ValueKey('skeddo-glass-alert-scroll-indicator')),
    );
    expect(indicator.opacity, 0.8);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dragging across options selects the release target', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SkeddoGlassAlertPlatter(
              title: 'Choose an action',
              message: 'Release on an option to select it.',
              actions: [
                for (var index = 0; index < 10; index++)
                  GlassDialogAction(
                    label: 'Action ${index + 1}',
                    onPressed: () => selected.add('Action ${index + 1}'),
                  ),
              ],
              settings: const LiquidGlassSettings(),
              quality: GlassQuality.standard,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final scrollFinder = find.byKey(
      const ValueKey('skeddo-glass-alert-scroll-viewport'),
    );
    await tester.drag(scrollFinder, const Offset(0, -120));
    await tester.pump();

    expect(selected, hasLength(1));
    expect(selected.single, matches(RegExp(r'^Action \d+$')));
    expect(scrollFinder, findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('scrolling an overflowing dialog highlights its touched option', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SkeddoGlassAlertPlatter(
              title: 'Choose an action',
              actions: [
                for (var index = 0; index < 10; index++)
                  GlassDialogAction(
                    label: 'Action ${index + 1}',
                    onPressed: () => selected.add('Action ${index + 1}'),
                  ),
              ],
              settings: const LiquidGlassSettings(),
              quality: GlassQuality.standard,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Action 5')),
    );
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    await gesture.moveBy(const Offset(0, -20));
    await tester.pump();
    expect(
      tester
          .widget<SingleChildScrollView>(
            find.byKey(const ValueKey('skeddo-glass-alert-scroll-viewport')),
          )
          .controller!
          .position
          .pixels,
      greaterThan(0),
    );
    final highlightedIndexes = <int>[];
    for (var index = 0; index < 10; index++) {
      final text = find.text('Action ${index + 1}');
      final button = find.ancestor(
        of: text,
        matching: find.byType(AnimatedContainer),
      );
      final decoration =
          tester.widget<AnimatedContainer>(button).decoration
              as ShapeDecoration;
      if (decoration.color!.a > 0.20) highlightedIndexes.add(index);
    }
    expect(highlightedIndexes, hasLength(1));

    await gesture.up();
    await tester.pump();
    expect(selected, ['Action ${highlightedIndexes.single + 1}']);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a non-scrolling drag does not trigger overflow selection', (
    tester,
  ) async {
    final selected = <String>[];
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SkeddoGlassAlertPlatter(
              title: 'Choose an action',
              actions: [
                for (var index = 0; index < 10; index++)
                  GlassDialogAction(
                    label: 'Action ${index + 1}',
                    onPressed: () => selected.add('Action ${index + 1}'),
                  ),
              ],
              settings: const LiquidGlassSettings(),
              quality: GlassQuality.standard,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Action 1')),
    );
    await gesture.moveBy(const Offset(32, 0));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(selected, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('two long actions remain side by side and wrap', (tester) async {
    const longLabel = 'Keep every category and event together in this group';
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SkeddoGlassAlertPlatter(
              title: 'Delete category?',
              actions: const [
                GlassDialogAction(label: longLabel, onPressed: _noop),
                GlassDialogAction(label: 'Cancel', onPressed: _noop),
              ],
              settings: const LiquidGlassSettings(),
              quality: GlassQuality.standard,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final destructiveText = find.text(longLabel);
    final cancelText = find.text('Cancel');
    final destructiveButton = find.ancestor(
      of: destructiveText,
      matching: find.byType(AnimatedContainer),
    );
    final cancelButton = find.ancestor(
      of: cancelText,
      matching: find.byType(AnimatedContainer),
    );
    expect(
      tester.getCenter(cancelButton).dx,
      lessThan(tester.getCenter(destructiveButton).dx),
    );
    expect(tester.getSize(destructiveButton).height, greaterThan(48));
    expect(tester.takeException(), isNull);
  });

  testWidgets('two-action dialogs retain descriptive action labels', (
    tester,
  ) async {
    Future<void> pumpTwoActions(
      String actionLabel, {
      bool cancelFirst = false,
    }) async {
      final action = GlassDialogAction(
        label: actionLabel,
        isDestructive: true,
        onPressed: _noop,
      );
      const cancel = GlassDialogAction(label: 'Cancel', onPressed: _noop);
      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(
              child: SkeddoGlassAlertPlatter(
                title: 'Confirm action?',
                actions: cancelFirst ? [cancel, action] : [action, cancel],
                settings: const LiquidGlassSettings(),
                quality: GlassQuality.standard,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpTwoActions('Delete Category');
    expect(find.text('Delete Category'), findsOneWidget);
    expect(find.text('Delete'), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    expect(
      tester.getCenter(find.text('Cancel')).dx,
      lessThan(tester.getCenter(find.text('Delete Category')).dx),
    );

    await pumpTwoActions('Archive Event');
    expect(find.text('Archive Event'), findsOneWidget);
    expect(find.text('Archive'), findsNothing);

    await pumpTwoActions('Remove Group', cancelFirst: true);
    expect(find.text('Remove Group'), findsOneWidget);
    expect(find.text('Remove'), findsNothing);
    expect(
      tester.getCenter(find.text('Cancel')).dx,
      lessThan(tester.getCenter(find.text('Remove Group')).dx),
    );

    await pumpTwoActions('Permanently Delete');
    expect(find.text('Permanently Delete'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('edge fades clear at the endpoint being reached', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: SkeddoGlassAlertPlatter(
              title: 'Choose an action',
              actions: [
                for (var index = 0; index < 10; index++)
                  GlassDialogAction(
                    label: 'Action ${index + 1}',
                    onPressed: _noop,
                  ),
              ],
              settings: const LiquidGlassSettings(),
              quality: GlassQuality.standard,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    final scrollFinder = find.byKey(
      const ValueKey('skeddo-glass-alert-scroll-viewport'),
    );

    Future<int> edgeAlpha({required bool top}) async {
      final mask = tester.widget<ShaderMask>(
        find.byKey(const ValueKey('skeddo-glass-alert-scroll-fade')),
      );
      final bounds = Rect.fromLTWH(0, 0, 100, 400);
      final shader = mask.shaderCallback(bounds);
      final result = await tester.runAsync<int>(
        () => _readShaderAlpha(shader, bounds, top ? 0 : 399),
      );
      return result ?? 0;
    }

    expect(await edgeAlpha(top: true), 255);
    await tester.drag(scrollFinder, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(await edgeAlpha(top: false), 255);
    expect(tester.takeException(), isNull);
  });

  testWidgets('shared dialog helper returns the chosen action', (tester) async {
    _latestResult = null;
    await tester.pumpWidget(
      const AppWindowContentBoundary(
        child: CupertinoApp(
          home: CupertinoPageScaffold(
            child: Center(child: _AlertDialogTestTrigger()),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm action?'), findsOneWidget);

    await tester.tap(find.text('Confirm'));
    await tester.pumpAndSettle();
    expect(_latestResult, 'confirmed');
  });
}

class _AlertDialogTestTrigger extends StatelessWidget {
  const _AlertDialogTestTrigger();

  @override
  Widget build(BuildContext context) {
    return Builder(
      builder: (context) => CupertinoButton(
        onPressed: () {
          showSkeddoGlassAlertDialog<String>(
            context: context,
            title: 'Confirm action?',
            message: 'This is a test.',
            actionsBuilder: (dialogContext) => [
              GlassDialogAction(
                label: 'Confirm',
                isPrimary: true,
                onPressed: () => Navigator.of(dialogContext).pop('confirmed'),
              ),
              GlassDialogAction(
                label: 'Cancel',
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ],
          ).then((value) => _latestResult = value);
        },
        child: const Text('Open dialog'),
      ),
    );
  }
}

String? _latestResult;

void _noop() {}

Future<int> _readShaderAlpha(ui.Shader shader, Rect bounds, int y) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(bounds, ui.Paint()..shader = shader);
  final picture = recorder.endRecording();
  final image = await picture.toImage(
    bounds.width.toInt(),
    bounds.height.toInt(),
  );
  final pixels = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  final alpha = pixels!.getUint8((y * bounds.width.toInt()) * 4 + 3);
  image.dispose();
  picture.dispose();
  return alpha;
}
