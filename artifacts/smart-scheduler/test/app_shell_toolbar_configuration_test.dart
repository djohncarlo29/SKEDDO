import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_shell_toolbar.dart';

void main() {
  String configuration({
    required int tab,
    bool searchFocused = false,
    bool dcvToolbarVisible = false,
  }) => appShellToolbarConfigurationKey(
    searchFocused: searchFocused,
    selectedTabIndex: tab,
    dcvToolbarVisible: dcvToolbarVisible,
  );

  test('tabs with identical toolbar contents keep one route', () {
    final notes = configuration(tab: 0);
    expect(configuration(tab: 1), notes);
    expect(configuration(tab: 2), notes);

    expect(configuration(tab: 3), isNot(notes));
    expect(configuration(tab: 2, dcvToolbarVisible: true), isNot(notes));
    expect(configuration(tab: 2, searchFocused: true), 'search');
  });
}
