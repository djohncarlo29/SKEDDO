import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassMenu, GlassMenuItem;

void main() {
  testWidgets('submenu header displays its current subtitle', (tester) async {
    await tester.pumpWidget(
      CupertinoApp(
        home: CupertinoPageScaffold(
          child: Center(
            child: GlassMenu(
              menuWidth: 260,
              items: [
                GlassMenuItem(
                  title: 'Sort By',
                  subtitle: 'Manual',
                  submenu: [GlassMenuItem(title: 'Deadline', onTap: () {})],
                  onTap: () {},
                ),
              ],
              triggerBuilder: (context, toggleMenu) => CupertinoButton(
                onPressed: toggleMenu,
                child: const Text('Actions'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Actions'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sort By'));
    await tester.pumpAndSettle();

    final header = find.byKey(const ValueKey('glass-menu-header-1'));
    expect(
      find.descendant(of: header, matching: find.text('Sort By')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: header, matching: find.text('Manual')),
      findsOneWidget,
    );
  });
}
