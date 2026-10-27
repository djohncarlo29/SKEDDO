import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass
    show GlassBarItem, GlassNavigationShell, GlassNavigationShellState;
import 'package:smart_scheduler/widgets/app_shell_toolbar.dart';
import 'package:smart_scheduler/widgets/app_shell_navigation_scope.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';
import 'package:smart_scheduler/widgets/rounded_cupertino_sheet.dart';

void main() {
  testWidgets(
    'nested pinned toolbar routes retain morph state and interactions',
    (tester) async {
      navigation_glass.GlassNavigationShellState.debugPinningSupported = true;
      addTearDown(() {
        navigation_glass.GlassNavigationShellState.debugPinningSupported =
            null;
      });

      final shellKey = GlobalKey<navigation_glass.GlassNavigationShellState>();
      final rootNavigatorKey = GlobalKey<NavigatorState>();
      final toolbarNavigatorKey = GlobalKey<NavigatorState>();
      final routeRevision = ValueNotifier<int>(0);
      addTearDown(routeRevision.dispose);
      final routeObserver = _RouteNameObserver();
      final rootRouteObserver = _RouteNameObserver();
      var settingsTaps = 0;
      var createTaps = 0;
      var bodyTaps = 0;

      navigation_glass.GlassBarItem action(
        String id,
        String label,
        VoidCallback onTap,
      ) => navigation_glass.GlassBarItem.icon(
        id: id,
        label: label,
        icon: const Icon(CupertinoIcons.add),
        onTap: onTap,
      );

      Widget toolbar({
        required AppShellToolbarGlyph glyph,
        required String label,
        required VoidCallback onLeadingTap,
        bool showPrimary = true,
        List<navigation_glass.GlassBarItem> actions =
            const <navigation_glass.GlassBarItem>[],
      }) => AppShellPinnedToolbar(
        glyph: glyph,
        semanticLabel: label,
        horizontalInset: 16,
        actions: actions,
        showPrimary: showPrimary,
        onTap: onLeadingTap,
      );

      Route<void> homeToolbarRoute() => appShellToolbarStateRoute(
        name: 'toolbar-home',
        opaque: true,
        onSystemBack: () {},
        toolbarBuilder: (_) => toolbar(
          glyph: AppShellToolbarGlyph.menu,
          label: 'Open settings',
          onLeadingTap: () => settingsTaps++,
          actions: [
            action('search', 'Search', () {}),
            action('create', 'Create event', () => createTaps++),
          ],
        ),
      );

      await tester.pumpWidget(
        CupertinoApp(
          navigatorKey: rootNavigatorKey,
          navigatorObservers: [rootRouteObserver],
          builder: (context, child) => AppWindowContentScope(
            horizontalInset: 0,
            physicalWidth: 402,
            child: child!,
          ),
          home: CupertinoPageScaffold(
            child: AppShellNavigationScope(
              navigatorKey: toolbarNavigatorKey,
              routeRevision: routeRevision,
              child: navigation_glass.GlassNavigationShell(
                key: shellKey,
                child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => bodyTaps++,
                      child: const ColoredBox(color: Color(0xFFFFFFFF)),
                    ),
                  ),
                  Positioned(
                    top: 90,
                    left: 20,
                    child: Builder(
                      builder: (bodyContext) => CupertinoButton(
                        key: const ValueKey('open-nested-sheet'),
                        onPressed: () {
                          showRoundedCupertinoSheet<void>(
                            context: bodyContext,
                            pageBuilder: (sheetContext) => CupertinoPageScaffold(
                              child: Center(
                                child: CupertinoButton(
                                  key: const ValueKey('dismiss-nested-sheet'),
                                  onPressed: () =>
                                      Navigator.of(sheetContext).pop(),
                                  child: const Text('Dismiss sheet'),
                                ),
                              ),
                            ),
                          );
                        },
                        child: const Text('Open sheet'),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: Navigator(
                      key: toolbarNavigatorKey,
                      observers: [
                        routeObserver,
                        AppShellNavigationObserver(routeRevision),
                      ],
                      initialRoute: 'app-shell-toolbar-home',
                      onGenerateRoute: (_) => homeToolbarRoute(),
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(shellKey.currentState!.resolveState()!.settled, isTrue);
      await tester.tap(find.bySemanticsLabel('Open settings'));
      expect(settingsTaps, 1);
      expect(find.bySemanticsLabel('Create event'), findsOneWidget);

      toolbarNavigatorKey.currentState!.push<void>(
        appShellToolbarStateRoute(
          name: 'toolbar-you',
          opaque: true,
          onSystemBack: () {},
          toolbarBuilder: (_) => toolbar(
            glyph: AppShellToolbarGlyph.menu,
            label: 'Open settings',
            onLeadingTap: () => settingsTaps++,
            actions: [action('create', 'Create event', () => createTaps++)],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final youState = shellKey.currentState!.resolveState()!;
      expect(youState.settled, isTrue);
      expect(youState.flowProgress, 1);
      expect(youState.to.actions, hasLength(1));
      await tester.tap(find.bySemanticsLabel('Create event'));
      await tester.tap(find.bySemanticsLabel('Open settings'));
      expect(createTaps, 1);
      expect(settingsTaps, 2);

      toolbarNavigatorKey.currentState!.push<void>(
        appShellToolbarStateRoute(
          name: 'toolbar-settings',
          opaque: true,
          onSystemBack: () {},
          toolbarBuilder: (_) => toolbar(
            glyph: AppShellToolbarGlyph.close,
            label: 'Close settings',
            onLeadingTap: () => settingsTaps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final settingsState = shellKey.currentState!.resolveState()!;
      expect(settingsState.settled, isTrue);
      expect(settingsState.to.actions, isEmpty);
      expect(settingsState.flowProgress, 1);
      await tester.tapAt(const Offset(36, 30));
      expect(settingsTaps, 3);

      toolbarNavigatorKey.currentState!.push<void>(
        appShellToolbarStateRoute(
          name: 'toolbar-settings-subscreen',
          opaque: true,
          onSystemBack: () {},
          toolbarBuilder: (_) => toolbar(
            glyph: AppShellToolbarGlyph.back,
            label: 'Back from Theme',
            onLeadingTap: () {
              settingsTaps++;
              toolbarNavigatorKey.currentState!.pop();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final subScreenState = shellKey.currentState!.resolveState()!;
      expect(subScreenState.to.actions, isEmpty);
      expect(subScreenState.flowProgress, 1);
      await tester.tapAt(const Offset(36, 30));
      await tester.pumpAndSettle();
      expect(settingsTaps, 4);
      expect(find.bySemanticsLabel('Close settings'), findsOneWidget);

      await tester.tapAt(const Offset(200, 300));
      expect(bodyTaps, 1);

      toolbarNavigatorKey.currentState!.pushReplacement<void, void>(
        appShellToolbarStateRoute(
          name: 'toolbar-home-return',
          opaque: true,
          onSystemBack: () {},
          toolbarBuilder: (_) => toolbar(
            glyph: AppShellToolbarGlyph.menu,
            label: 'Open settings',
            onLeadingTap: () => settingsTaps++,
            actions: [
              action('search', 'Search', () {}),
              action('create', 'Create event', () => createTaps++),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        shellKey.currentState!.resolveState()!.to.actions,
        hasLength(2),
      );

      toolbarNavigatorKey.currentState!.pushReplacement<void, void>(
        appShellToolbarStateRoute(
          name: 'toolbar-search',
          opaque: true,
          onSystemBack: () {},
          toolbarBuilder: (_) => toolbar(
            glyph: AppShellToolbarGlyph.menu,
            label: 'Search',
            onLeadingTap: () {},
            showPrimary: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final searchState = shellKey.currentState!.resolveState()!;
      expect(searchState.to.leading, isEmpty);
      expect(searchState.to.actions, isEmpty);
      await tester.tapAt(const Offset(200, 300));
      expect(bodyTaps, 2);

      toolbarNavigatorKey.currentState!.pushReplacement<void, void>(
        appShellToolbarStateRoute(
          name: 'toolbar-home-return-after-search',
          opaque: true,
          onSystemBack: () {},
          toolbarBuilder: (_) => toolbar(
            glyph: AppShellToolbarGlyph.menu,
            label: 'Open settings',
            onLeadingTap: () => settingsTaps++,
            actions: [
              action('search', 'Search', () {}),
              action('create', 'Create event', () => createTaps++),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      final routeRevisionBeforeSheet = routeRevision.value;
      final toolbarRectBeforeSheet = tester.getRect(
        find.bySemanticsLabel('Open settings'),
      );
      final trailingRectBeforeSheet = tester.getRect(
        find.bySemanticsLabel('Create event'),
      );
      await tester.tap(find.byKey(const ValueKey('open-nested-sheet')));
      await tester.pumpAndSettle();
      expect(rootNavigatorKey.currentState!.canPop(), isTrue);
      expect(routeObserver.currentName, 'toolbar-home-return-after-search');
      expect(
        rootRouteObserver.currentRoute,
        isA<RoundedCupertinoSheetRoute<void>>(),
      );
      expect(routeRevision.value, routeRevisionBeforeSheet);
      // The shell sits inside the AppShell route, so the root modal covers and
      // dims the pinned chrome together with the page without handing it back.
      expect(shellKey.currentState!.resolveState(), isNotNull);
      expect(
        find.ancestor(
          of: find.byKey(const ValueKey('open-nested-sheet')),
          matching: find.byKey(
            const ValueKey('rounded-sheet-app-shell-dim-overlay'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.bySemanticsLabel('Open settings'),
          matching: find.byKey(
            const ValueKey('rounded-sheet-app-shell-dim-overlay'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.ancestor(
          of: find.bySemanticsLabel('Create event'),
          matching: find.byKey(
            const ValueKey('rounded-sheet-app-shell-dim-overlay'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        tester.getRect(find.bySemanticsLabel('Open settings')).size,
        toolbarRectBeforeSheet.size,
      );
      expect(
        tester.getRect(find.bySemanticsLabel('Create event')).size,
        trailingRectBeforeSheet.size,
      );
      await tester.tapAt(toolbarRectBeforeSheet.center);
      expect(settingsTaps, 4);
      await tester.tapAt(trailingRectBeforeSheet.center);
      expect(createTaps, 1);
      await tester.tap(find.byKey(const ValueKey('dismiss-nested-sheet')));
      await tester.pumpAndSettle();
      expect(find.text('Dismiss sheet'), findsNothing);
      expect(routeObserver.currentName, 'toolbar-home-return-after-search');
      expect(routeObserver.currentRoute!.isCurrent, isTrue);
      expect(routeRevision.value, routeRevisionBeforeSheet);
      expect(find.bySemanticsLabel('Open settings'), findsOneWidget);
      expect(find.bySemanticsLabel('Create event'), findsOneWidget);
      expect(
        shellKey.currentState!.isHoisting(
          routeObserver.currentRoute! as ModalRoute<dynamic>,
        ),
        isTrue,
      );
      final returnedState = shellKey.currentState!.resolveState()!;
      expect(returnedState.settled, isTrue);
      expect(returnedState.to.actions, hasLength(2));
    },
  );
}

class _RouteNameObserver extends NavigatorObserver {
  String? currentName;
  Route<dynamic>? currentRoute;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentName = route.settings.name;
    currentRoute = route;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    currentName = previousRoute?.settings.name;
    currentRoute = previousRoute;
  }

  @override
  void didReplace({
    Route<dynamic>? newRoute,
    Route<dynamic>? oldRoute,
  }) {
    currentName = newRoute?.settings.name;
    currentRoute = newRoute;
  }
}
