import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    as navigation_glass
    show GlassBarItem, GlassNavigationShell, GlassNavigationShellState;
import 'package:smart_scheduler/widgets/app_shell_toolbar.dart';
import 'package:smart_scheduler/widgets/app_window_content_boundary.dart';

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
      final toolbarNavigatorKey = GlobalKey<NavigatorState>();
      final rootNavigatorKey = GlobalKey<NavigatorState>();
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
        List<navigation_glass.GlassBarItem> actions =
            const <navigation_glass.GlassBarItem>[],
      }) => AppShellPinnedToolbar(
        glyph: glyph,
        semanticLabel: label,
        horizontalInset: 16,
        actions: actions,
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
          builder: (context, child) => AppWindowContentScope(
            horizontalInset: 0,
            physicalWidth: 402,
            child: navigation_glass.GlassNavigationShell(
              key: shellKey,
              child: child!,
            ),
          ),
          home: CupertinoPageScaffold(
            child: Stack(
              children: [
                Positioned.fill(
                  child: GestureDetector(
                    onTap: () => bodyTaps++,
                    child: const ColoredBox(color: Color(0xFFFFFFFF)),
                  ),
                ),
                Positioned.fill(
                  child: Navigator(
                    key: toolbarNavigatorKey,
                    initialRoute: 'app-shell-toolbar-home',
                    onGenerateRoute: (_) => homeToolbarRoute(),
                  ),
                ),
              ],
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

      rootNavigatorKey.currentState!.push<void>(
        appShellToolbarStateRoute(
          name: 'root-settings',
          onSystemBack: () {},
          toolbarBuilder: (_) => toolbar(
            glyph: AppShellToolbarGlyph.close,
            label: 'Close settings',
            onLeadingTap: () => settingsTaps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rootSettingsState = shellKey.currentState!.resolveState();
      if (rootSettingsState != null) {
        expect(rootSettingsState.to.actions, isEmpty);
      }
      await tester.tapAt(const Offset(36, 30));
      expect(settingsTaps, 4);
    },
  );
}
