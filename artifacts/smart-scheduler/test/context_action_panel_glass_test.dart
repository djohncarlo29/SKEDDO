import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart'
    show GlassContainer, GlassMenuItem, GlassQuality;
import 'package:smart_scheduler/widgets/action_panel.dart'
    show ActionItem, ActionPanel;

void main() {
  testWidgets(
    'context action panel uses GlassMenu formatting on a premium surface',
    (tester) async {
      final closing = ValueNotifier(false);
      addTearDown(closing.dispose);
      var editCount = 0;
      var deleteCount = 0;

      await tester.pumpWidget(
        CupertinoApp(
          theme: const CupertinoThemeData(brightness: Brightness.light),
          home: Center(
            child: SizedBox(
              width: 250,
              child: ActionPanel(
                isClosing: closing,
                useGlassMenuStyle: true,
                items: [
                  ActionItem(
                    label: 'Edit Event Info',
                    icon: CupertinoIcons.pencil,
                    onTap: () => editCount++,
                  ),
                  ActionItem(
                    label: 'Delete Event',
                    icon: CupertinoIcons.trash,
                    isDestructive: true,
                    onTap: () => deleteCount++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final surface = tester.widget<GlassContainer>(
        find.byType(GlassContainer),
      );
      expect(surface.quality, GlassQuality.premium);
      expect(surface.settings!.thickness, 30);
      expect(surface.settings!.refractiveIndex, 1.59);
      expect(surface.settings!.chromaticAberration, 0.3);

      final rows = tester.widgetList<GlassMenuItem>(find.byType(GlassMenuItem));
      expect(rows, hasLength(2));
      expect(rows.first.title, 'Edit Event Info');
      expect(rows.first.iconLabelGap, 12);
      expect(rows.first.titleStyle, isNull);
      expect(rows.first.allowTextWrapping, isTrue);
      expect(rows.last.isDestructive, isTrue);
      final title = tester.widget<Text>(find.text('Edit Event Info'));
      expect(title.style!.fontSize, 17);

      await tester.tap(find.text('Edit Event Info'));
      expect(editCount, 1);
      expect(deleteCount, 0);
    },
  );
}
