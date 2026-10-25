import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_sficon/flutter_sficon.dart';
import 'package:smart_scheduler/widgets/emoji_picker_sheet.dart';
import 'package:smart_scheduler/widgets/fixed_size_icon.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

void main() {
  testWidgets('reopens on and marks the previously selected emoji', (
    tester,
  ) async {
    final navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: navigatorKey,
        theme: const CupertinoThemeData(brightness: Brightness.light),
        builder: (context, child) =>
            AppWindowContentBoundary(child: child ?? const SizedBox.shrink()),
        home: const SizedBox.shrink(),
      ),
    );
    navigatorKey.currentState!.push<void>(
      RoundedCupertinoSheetRoute<void>(
        builder: (_) =>
            EmojiPickerSheet(selectedEmoji: '🐶', onEmojiSelected: (_) {}),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('emoji-selected-marker')), findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Animals category' &&
            widget.properties.selected == true,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('emoji-category-dog-face')),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is FixedSFIcon && widget.icon == SFIcons.sf_hand_wave,
      ),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('emoji-category-apple-fruit')),
      findsOneWidget,
    );
    expect(find.byIcon(CupertinoIcons.airplane), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.lightbulb_fill), findsOneWidget);
    expect(find.byIcon(CupertinoIcons.suit_heart_fill), findsOneWidget);
  });

  testWidgets(
    'keeps animal and fruit emojis and fills hand-wave in Dark Mode',
    (tester) async {
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: navigatorKey,
          theme: const CupertinoThemeData(brightness: Brightness.dark),
          builder: (context, child) =>
              AppWindowContentBoundary(child: child ?? const SizedBox.shrink()),
          home: const SizedBox.shrink(),
        ),
      );
      navigatorKey.currentState!.push<void>(
        RoundedCupertinoSheetRoute<void>(
          builder: (_) => EmojiPickerSheet(onEmojiSelected: (_) {}),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('emoji-category-dog-face')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('emoji-category-apple-fruit')),
        findsOneWidget,
      );
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is FixedSFIcon && widget.icon == SFIcons.sf_hand_wave_fill,
        ),
        findsOneWidget,
      );
    },
  );
}
