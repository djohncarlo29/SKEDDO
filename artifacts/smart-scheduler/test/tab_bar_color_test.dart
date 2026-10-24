import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart';

void main() {
  testWidgets('inactive tab tint uses the specified light and dark colors', (
    tester,
  ) async {
    for (final entry in [
      (Brightness.light, const Color(0xFF737373)),
      (Brightness.dark, const Color(0xFF8E8E93)),
    ]) {
      Color? resolvedColor;
      await tester.pumpWidget(
        CupertinoApp(
          theme: CupertinoThemeData(brightness: entry.$1),
          home: Builder(
            builder: (context) {
              resolvedColor = CupertinoDynamicColor.resolve(
                kTabBarInactiveColor,
                context,
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(resolvedColor!.value, entry.$2.value);
    }
  });
}
