import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart'
    show kModalSheetButtonDiameter, kModalSheetButtonEdgeGap;
import 'package:smart_scheduler/widgets/header_title_scroller.dart';
import 'package:smart_scheduler/widgets/horizontal_edge_fade.dart'
    show kHorizontalFadeEdgeGap;
import 'package:smart_scheduler/widgets/modal_sheet_title_scroller.dart';

const _fadeColor = Color(0xFFF2F2F7);
const _titleStyle = TextStyle(
  inherit: false,
  color: Color(0xFF1D1D1F),
  fontSize: 17,
  fontWeight: FontWeight.w600,
);

Widget _harness(String title, {double width = 320}) {
  return CupertinoApp(
    home: CupertinoPageScaffold(
      backgroundColor: _fadeColor,
      child: Center(
        child: SizedBox(
          width: width,
          height: 64,
          child: Stack(
            children: [
              Positioned.fill(
                child: ModalSheetTitleScroller(
                  title: title,
                  style: _titleStyle,
                  fadeColor: _fadeColor,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Finder _fadeMasks() => find.descendant(
  of: find.byType(HeaderTitleScroller),
  matching: find.byType(ShaderMask),
);

Finder _titleScrollable() => find.descendant(
  of: find.byType(HeaderTitleScroller),
  matching: find.byType(Scrollable),
);

void main() {
  testWidgets(
    'centers a fitting sheet title and reveals a fade while rubberbanding',
    (tester) async {
      await tester.pumpWidget(_harness('New Event'));
      await tester.pumpAndSettle();

      final scrollerRect = tester.getRect(find.byType(HeaderTitleScroller));
      final sheetTitleRect = tester.getRect(
        find.byType(ModalSheetTitleScroller),
      );
      final controlAndFadeGap =
          kModalSheetButtonEdgeGap +
          kModalSheetButtonDiameter +
          kHorizontalFadeEdgeGap;
      expect(
        scrollerRect.left - sheetTitleRect.left,
        closeTo(controlAndFadeGap, 0.5),
      );
      expect(
        tester.getCenter(find.text('New Event')).dx,
        closeTo(sheetTitleRect.center.dx, 1),
      );
      expect(
        tester
            .state<ScrollableState>(_titleScrollable())
            .position
            .maxScrollExtent,
        0,
      );
      expect(_fadeMasks(), findsOneWidget);
      expect(
        find.byKey(const ValueKey<String>('modal-sheet-title-fade-boundary')),
        findsOneWidget,
      );

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('New Event')),
      );
      await gesture.moveBy(const Offset(40, 0));
      await tester.pump();

      expect(
        tester.state<ScrollableState>(_titleScrollable()).position.pixels,
        lessThan(0),
      );
      expect(_fadeMasks(), findsOneWidget);
      await gesture.up();
      await tester.pumpAndSettle();
    },
  );

  testWidgets('shows the trailing fade for an overflowing title at rest', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        'A very long modal title that exceeds the space between the controls',
        width: 260,
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester
          .state<ScrollableState>(_titleScrollable())
          .position
          .maxScrollExtent,
      greaterThan(1),
    );
    expect(_fadeMasks(), findsOneWidget);
  });

  testWidgets('modal title fades use alpha compositing, not a tint overlay', (
    tester,
  ) async {
    await tester.pumpWidget(
      const CupertinoApp(
        home: Center(
          child: SizedBox(
            width: 260,
            height: 64,
            child: ModalSheetTitleScroller(
              title: 'A very long modal title that overflows its viewport',
              style: _titleStyle,
              fadeColor: _fadeColor,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final mask = tester.widget<ShaderMask>(_fadeMasks());
    expect(mask.blendMode, BlendMode.dstIn);
    expect(
      find.descendant(
        of: find.byType(HeaderTitleScroller),
        matching: find.byWidgetPredicate((widget) {
          if (widget is! DecoratedBox) return false;
          final decoration = widget.decoration;
          return decoration is BoxDecoration &&
              decoration.gradient is LinearGradient;
        }),
      ),
      findsNothing,
    );
  });
}
