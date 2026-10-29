import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassButton;
import 'package:smart_scheduler/widgets/search_bar_widget.dart';

void main() {
  testWidgets(
    'search cancel claims drags without scrolling its parent and matches toolbar motion',
    (tester) async {
      final scrollController = ScrollController();
      var cancelTaps = 0;
      const cancelKey = ValueKey('search-cancel');

      await tester.pumpWidget(
        CupertinoApp(
          home: SingleChildScrollView(
            controller: scrollController,
            child: Column(
              children: [
                const SizedBox(height: 40),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SearchCancelButton(
                      key: cancelKey,
                      searchFocused: true,
                      animation: const AlwaysStoppedAnimation<double>(1),
                      onTap: () => cancelTaps++,
                    ),
                  ],
                ),
                const SizedBox(height: 1200),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final glassButton = tester.widget<GlassButton>(
        find.descendant(
          of: find.byKey(cancelKey),
          matching: find.byType(GlassButton),
        ),
      );
      expect(glassButton.interactionScale, isNull);
      expect(glassButton.stretch, 0.5);

      final drag = await tester.startGesture(
        tester.getCenter(find.byKey(cancelKey)),
      );
      await drag.moveBy(const Offset(0, -35));
      await tester.pump(const Duration(milliseconds: 40));
      await drag.moveBy(const Offset(0, -35));
      await tester.pump(const Duration(milliseconds: 40));
      expect(scrollController.offset, 0);
      await drag.up();
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(cancelKey));
      await tester.pump(const Duration(milliseconds: 150));
      await tester.pumpAndSettle();
      expect(cancelTaps, 1);
      expect(tester.takeException(), isNull);

      scrollController.dispose();
    },
  );
}
