import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/app_theme.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/dcv_keyboard_layout.dart';
import 'package:smart_scheduler/widgets/search_bar_widget.dart';
import 'package:smart_scheduler/widgets/smart_search_results.dart';

void main() {
  testWidgets(
    'empty offscreen results render immediately and rubberband below a fixed header',
    (tester) async {
      const surfaceSize = Size(390, 844);
      const headerKey = ValueKey('fixed-search-mode-header');
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        CupertinoApp(
          home: CupertinoPageScaffold(
            child: AppWindowContentBoundary(
              child: SizedBox.expand(
                child: AppWindowContentPadding(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SearchModeHeader(
                        searchBarRow: const SizedBox(
                          key: headerKey,
                          height: 52,
                          child: ColoredBox(color: CupertinoColors.systemBlue),
                        ),
                      ),
                      Expanded(
                        child: CustomScrollView(
                          primary: false,
                          physics: const AlwaysScrollableScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          slivers: const [SmartSearchResultsSliver(hits: [])],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No Results'), findsOneWidget);
      final headerFinder = find.byKey(headerKey);
      final headerTop = tester.getTopLeft(headerFinder).dy;

      final gesture = await tester.startGesture(
        tester.getCenter(find.text('No Results')),
      );
      await gesture.moveBy(const Offset(0, 48));
      await tester.pump();
      expect(tester.getTopLeft(headerFinder).dy, closeTo(headerTop, 0.5));

      await gesture.up();
      await tester.pumpAndSettle();
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -48));
      await tester.pump();
      expect(tester.getTopLeft(headerFinder).dy, closeTo(headerTop, 0.5));
    },
  );

  testWidgets(
    'no-results placeholder animates to the keyboard-adjusted viewport center',
    (tester) async {
      const surfaceSize = Size(320, 600);
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget buildApp(double keyboardBottom) {
        return CupertinoApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: surfaceSize,
              viewInsets: EdgeInsets.only(bottom: keyboardBottom),
            ),
            child: const Center(
              child: SizedBox(
                width: 300,
                height: 500,
                child: SearchNoResultsCentered(child: Text('No Results')),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp(0));
      await tester.pumpAndSettle();
      final noResultsFinder = find.text('No Results');
      final centerWithoutKeyboard = tester.getCenter(noResultsFinder).dy;
      expect(centerWithoutKeyboard, closeTo(300, 1));

      await tester.pumpWidget(buildApp(200));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      final centerDuringKeyboardAnimation = tester
          .getCenter(noResultsFinder)
          .dy;
      expect(centerDuringKeyboardAnimation, lessThan(centerWithoutKeyboard));
      expect(
        centerDuringKeyboardAnimation,
        greaterThan(200),
        reason: 'The placeholder should move smoothly instead of jumping.',
      );
      await tester.pumpAndSettle();
      expect(tester.getCenter(noResultsFinder).dy, closeTo(200, 1));

      await tester.pumpWidget(buildApp(0));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      final centerDuringDismissal = tester.getCenter(noResultsFinder).dy;
      expect(centerDuringDismissal, greaterThan(200));
      expect(centerDuringDismissal, lessThan(300));
      await tester.pumpAndSettle();
      expect(tester.getCenter(noResultsFinder).dy, closeTo(300, 1));
    },
  );

  testWidgets(
    'full-height offscreen results center above the tab bar and keyboard',
    (tester) async {
      const surfaceSize = Size(390, 800);
      const tabBarClearance = 80.0;
      const headerHeight = 120.0;
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget buildApp(double keyboardBottom) {
        return CupertinoApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: surfaceSize,
              viewInsets: EdgeInsets.only(bottom: keyboardBottom),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                 height: surfaceSize.height,
                child: Column(
                  children: [
                    const SizedBox(height: headerHeight),
                    Expanded(
                      child: CustomScrollView(
                        primary: false,
                        slivers: [
                          const SmartSearchResultsSliver(
                            hits: [],
                            emptyStateBottomClearance: tabBarClearance,
                            viewportBottomOffset: 0,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp(0));
      await tester.pumpAndSettle();
      final placeholder = find.byType(SearchNoResults);
      final centerWithoutKeyboard = tester.getCenter(placeholder).dy;
      expect(
        centerWithoutKeyboard,
        closeTo((headerHeight + surfaceSize.height - tabBarClearance) / 2, 1),
      );

      await tester.pumpWidget(buildApp(200));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(placeholder).dy,
        closeTo((headerHeight + surfaceSize.height - 200) / 2, 1),
      );
    },
  );

  testWidgets(
    'inline empty results center above the tab bar and keyboard',
    (tester) async {
      const surfaceSize = Size(390, 800);
      const bottomClearance = 80.0;
      const headerHeight = 120.0;
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      Widget buildApp(double keyboardBottom) {
        return CupertinoApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: surfaceSize,
              viewInsets: EdgeInsets.only(bottom: keyboardBottom),
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                height: surfaceSize.height,
                child: Column(
                  children: [
                    const SizedBox(height: headerHeight),
                    Expanded(
                      child: CustomScrollView(
                        primary: false,
                        slivers: [
                          const SmartSearchResultsSliver(
                            hits: [],
                            emptyStateBottomClearance: bottomClearance,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp(0));
      await tester.pumpAndSettle();
      final placeholder = find.byType(SearchNoResults);
      expect(
        tester.getCenter(placeholder).dy,
        closeTo((headerHeight + surfaceSize.height - bottomClearance) / 2, 1),
      );

      await tester.pumpWidget(buildApp(200));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(placeholder).dy,
        closeTo((headerHeight + surfaceSize.height - 200) / 2, 1),
      );
    },
  );

  testWidgets(
    'DCV empty results center above the keyboard without a duplicate shell inset',
    (tester) async {
      const surfaceSize = Size(390, 800);
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const keyboardBottomInset = 200.0;
      final shellInsetDuringSearch = dcvKeyboardContentBottomInset(
        hasActiveDcv: true,
        searchFocused: true,
        keyboardBottomInset: keyboardBottomInset,
      );
      expect(shellInsetDuringSearch, 0);
      expect(
        dcvKeyboardContentBottomInset(
          hasActiveDcv: true,
          searchFocused: false,
          keyboardBottomInset: keyboardBottomInset,
        ),
        keyboardBottomInset,
        reason: 'Section editing still needs the shell-level keyboard inset.',
      );

      await tester.pumpWidget(
        CupertinoApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: surfaceSize,
              viewInsets: const EdgeInsets.only(bottom: keyboardBottomInset),
            ),
            child: SizedBox.expand(
              child: Padding(
                padding: EdgeInsets.only(bottom: shellInsetDuringSearch),
                child: Column(
                  children: [
                    const SizedBox(height: 120),
                    const Expanded(
                      child: SmartDcvSearchResults(primary: [], overflow: []),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Results begin at y=120 and the keyboard begins at y=600.
      expect(
        tester.getCenter(find.byType(SearchNoResults)).dy,
        closeTo(360, 1),
      );
    },
  );

  testWidgets(
    'DCV empty results transfer keyboard clearance to the tab bar continuously',
    (tester) async {
      const surfaceSize = Size(390, 800);
      tester.view.physicalSize = surfaceSize;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      double? tabBarClearance;

      Widget buildApp(double keyboardBottomInset) {
        return CupertinoApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: surfaceSize,
              viewInsets: EdgeInsets.only(bottom: keyboardBottomInset),
            ),
            child: Builder(
              builder: (context) {
                tabBarClearance ??= floatingTabBarContentBottomClearance(
                  context,
                );
                return SizedBox.expand(
                  child: Column(
                    children: [
                      const SizedBox(height: 120),
                      const Expanded(
                        child: SmartDcvSearchResults(
                          primary: [],
                          overflow: [],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }

      await tester.pumpWidget(buildApp(0));
      await tester.pumpAndSettle();
      final placeholder = find.byType(SearchNoResults);
      final centerWithoutKeyboard = tester.getCenter(placeholder).dy;

      expect(tabBarClearance, isNotNull);
      expect(tabBarClearance!, greaterThan(50));

      await tester.pumpWidget(buildApp(200));
      await tester.pumpAndSettle();
      expect(tester.getCenter(placeholder).dy, closeTo(360, 1));

      // Once the keyboard is shorter than the tab-bar clearance, the empty
      // state should already be at its final resting center. It must not drop
      // lower and then move back up when the inset reaches zero.
      await tester.pumpWidget(buildApp(50));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(placeholder).dy,
        closeTo(centerWithoutKeyboard, 1),
      );

      await tester.pumpWidget(buildApp(0));
      await tester.pumpAndSettle();
      expect(
        tester.getCenter(placeholder).dy,
        closeTo(centerWithoutKeyboard, 1),
      );
    },
  );
}
