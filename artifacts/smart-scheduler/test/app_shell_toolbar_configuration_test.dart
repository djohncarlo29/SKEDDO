import 'package:flutter_test/flutter_test.dart';
import 'package:smart_scheduler/widgets/app_shell_toolbar.dart';

void main() {
  String configuration({
    required int tab,
    bool searchFocused = false,
    bool dcvToolbarVisible = false,
    String calendarToolbarVariant = 'month-compact',
  }) => appShellToolbarConfigurationKey(
    searchFocused: searchFocused,
    selectedTabIndex: tab,
    dcvToolbarVisible: dcvToolbarVisible,
    calendarToolbarVariant: calendarToolbarVariant,
  );

  test('toolbar routes follow visible actions', () {
    final home = configuration(tab: 0);
    expect(configuration(tab: 3), home);

    expect(configuration(tab: 1), 'calendar-month-compact');
    expect(
      configuration(tab: 1, calendarToolbarVariant: 'year'),
      'calendar-year',
    );
    expect(
      configuration(tab: 1, calendarToolbarVariant: 'day-list'),
      'calendar-day-list',
    );
    expect(configuration(tab: 2), 'events');
    expect(configuration(tab: 2, dcvToolbarVisible: true), 'events-dcv');
    expect(configuration(tab: 2, searchFocused: true), 'search');
  });
}
