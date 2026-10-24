import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_scheduler/services/app_database.dart';
import 'package:smart_scheduler/services/local_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase database;
  const firstEvent = {
    'id': 'legacy-1',
    'title': 'Legacy meeting',
    'time': '9:00 AM',
    'categoryId': 'sys-uncategorized',
  };
  const secondEvent = {
    'id': 'legacy-2',
    'title': 'Legacy reminder',
    'time': '10:00 AM',
    'categoryId': 'sys-uncategorized',
  };
  const category = {
    'id': 'work',
    'name': 'Work',
    'emoji': 'briefcase',
    'color': 4280391411,
    'description': '',
    'isSmartCategory': false,
    'archived': false,
  };

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'skeddo_events_v1': [
        jsonEncode(firstEvent),
        jsonEncode(secondEvent),
      ],
      'skeddo_archived_events_v1': [jsonEncode({...firstEvent, 'id': 'archived'})],
      'skeddo_deleted_events_v1': [jsonEncode({...secondEvent, 'id': 'deleted'})],
      'events_user_categories': [jsonEncode(category)],
      'events_pinned_categories': <String>[],
      'skeddo_hnsw_v1': jsonEncode({'vectors': {}, 'graph': {}}),
      'smart_rule_parser_cache_v1': jsonEncode({'meeting': {'value': 'event'}}),
      'app_theme': 'dark',
    });
    database = AppDatabase(NativeDatabase.memory());
    await LocalStorage.instance.useDatabaseForTesting(database);
  });

  tearDown(() async {
    await LocalStorage.instance.resetDatabaseForTesting();
  });

  test('migrates events, categories, and search data but leaves settings', () async {
    await LocalStorage.instance.initialize();

    expect(
      (await LocalStorage.instance.loadEvents()).map((event) => event.id),
      ['legacy-1', 'legacy-2'],
    );
    expect(
      (await LocalStorage.instance.loadArchivedEvents()).single.id,
      'archived',
    );
    expect(
      (await LocalStorage.instance.loadDeletedEvents()).single.id,
      'deleted',
    );
    expect(
      (await LocalStorage.instance.loadContentStringList(
        'events_user_categories',
      ))!.single,
      jsonEncode(category),
    );
    expect(
      await LocalStorage.instance.loadContentString('skeddo_hnsw_v1'),
      jsonEncode({'vectors': {}, 'graph': {}}),
    );
    expect(
      await LocalStorage.instance.loadContentString('smart_rule_parser_cache_v1'),
      jsonEncode({'meeting': {'value': 'event'}}),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('app_theme'), 'dark');
    expect(prefs.getStringList('skeddo_events_v1'), isNull);
    expect(prefs.getStringList('events_user_categories'), isNull);
  });

  test('re-opening after migration does not duplicate or overwrite SQLite data', () async {
    await LocalStorage.instance.initialize();
    await LocalStorage.instance.saveEvents([
      ...(await LocalStorage.instance.loadEvents()),
      (await LocalStorage.instance.loadEvents()).first.copyWith(
        id: 'sqlite-only',
        title: 'Written after migration',
      ),
    ]);

    // Re-run startup initialization against the same on-disk database.
    await LocalStorage.instance.useDatabaseForTesting(database);
    await LocalStorage.instance.initialize();

    final events = await LocalStorage.instance.loadEvents();
    expect(events.map((event) => event.id), [
      'legacy-1',
      'legacy-2',
      'sqlite-only',
    ]);
  });
}
