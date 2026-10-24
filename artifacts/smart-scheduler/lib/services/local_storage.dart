import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_database.dart';
import 'event_model.dart';

/// Local persistence for event records and user-owned category/search data.
///
/// SQLite stores event rows and serialized category/search documents.
/// Lightweight appearance and UI preferences intentionally remain in
/// SharedPreferences.
class LocalStorage {
  LocalStorage._();
  static final LocalStorage instance = LocalStorage._();

  static const _kActive = 'active';
  static const _kArchived = 'archived';
  static const _kDeleted = 'deleted';
  static const _kMigrationKey = '__migration_shared_preferences_content_v1';

  static const _kEventsKey = 'skeddo_events_v1';
  static const _kArchivedEventsKey = 'skeddo_archived_events_v1';
  static const _kDeletedEventsKey = 'skeddo_deleted_events_v1';
  static const _kEmbVersionsKey = 'skeddo_emb_versions_v1';
  static const _kCategorySortByKey = 'skeddo_category_sort_by_v1';
  static const _kCategorySortDirKey = 'skeddo_category_sort_dir_v1';
  static const _kHnswKey = 'skeddo_hnsw_v1';
  static const _kRuleParserKey = 'smart_rule_parser_cache_v1';

  static const Map<String, String> _legacyEventCollections = {
    _kEventsKey: _kActive,
    _kArchivedEventsKey: _kArchived,
    _kDeletedEventsKey: _kDeleted,
  };

  static const List<String> _legacyContentKeys = [
    _kEmbVersionsKey,
    _kCategorySortByKey,
    _kCategorySortDirKey,
    _kHnswKey,
    _kRuleParserKey,
    'events_user_categories',
    'events_pinned_categories',
    'events_recently_deleted_categories',
    'events_recently_deleted_smart_categories',
    'events_smart_category_colors',
    'events_archived_smart_categories',
    'events_smart_category_order',
    'events_grid_combined_order',
    'events_category_groups',
    'events_list_top_order',
    'events_dcv_custom_sections',
    'events_dcv_custom_section_event_ids',
    'events_utility_item_dates',
  ];

  static const List<String> _allLegacyKeys = [
    _kEventsKey,
    _kArchivedEventsKey,
    _kDeletedEventsKey,
    ..._legacyContentKeys,
  ];

  AppDatabase? _databaseOverride;
  Future<void>? _initializing;

  AppDatabase get _database => _databaseOverride ?? AppDatabase.instance;

  /// Open SQLite and transactionally migrate existing event/category/search
  /// data from SharedPreferences. Kept public so startup can complete the
  /// migration before loading the Settings panel's cached category label.
  Future<void> initialize() => _ensureInitialized();

  @visibleForTesting
  Future<void> useDatabaseForTesting(AppDatabase database) async {
    _databaseOverride = database;
    _initializing = null;
  }

  @visibleForTesting
  Future<void> resetDatabaseForTesting() async {
    _databaseOverride = null;
    _initializing = null;
  }

  Future<void> _ensureInitialized() async {
    final pending = _initializing;
    if (pending != null) return pending;
    final initialization = _initializeAndMigrate();
    _initializing = initialization;
    try {
      await initialization;
    } catch (_) {
      _initializing = null;
      rethrow;
    }
  }

  Future<void> _initializeAndMigrate() async {
    final db = _database;
    final marker = await (db.select(
      db.storedContent,
    )..where((row) => row.key.equals(_kMigrationKey))).getSingleOrNull();
    final prefs = await SharedPreferences.getInstance();

    if (marker != null) {
      final metadata = jsonDecode(marker.value);
      if (metadata is! Map || metadata['preserveLegacyKeys'] is! List) {
        throw StateError(
          'SKEDDO local-data migration marker is invalid; legacy data was '
          'left untouched.',
        );
      }
      await _removeMigratedPreferences(
        prefs,
        (metadata['preserveLegacyKeys'] as List).cast<String>().toSet(),
      );
      return;
    }

    final eventRows = <StoredEventsCompanion>[];
    final preserveLegacyKeys = <String>{};
    for (final entry in _legacyEventCollections.entries) {
      final saved = prefs.getStringList(entry.key);
      if (saved == null) continue;
      for (var position = 0; position < saved.length; position++) {
        final rawEvent = saved[position];
        try {
          final decoded = jsonDecode(rawEvent);
          if (decoded is! Map<String, dynamic>) {
            throw const FormatException('Expected an event object.');
          }
          final event = ScheduledEvent.fromJson(decoded);
          eventRows.add(
            StoredEventsCompanion.insert(
              collection: entry.value,
              id: event.id,
              position: position,
              payload: rawEvent,
            ),
          );
        } catch (error) {
          // Preserve the complete legacy list if even one row is malformed.
          // Valid rows are still imported, matching the old loader's behavior.
          preserveLegacyKeys.add(entry.key);
          debugPrint(
            'LocalStorage migration: preserving ${entry.key} because row '
            '$position could not be decoded ($error).',
          );
        }
      }
    }

    final contentRows = <StoredContentCompanion>[];
    for (final key in _legacyContentKeys) {
      final value = prefs.get(key);
      if (value == null) continue;
      contentRows.add(
        StoredContentCompanion.insert(
          key: key,
          value: _encodeContentValue(value),
        ),
      );
    }

    await db.transaction(() async {
      if (eventRows.isNotEmpty) {
        await db.batch(
          (batch) => batch.insertAll(
            db.storedEvents,
            eventRows,
            mode: InsertMode.insertOrAbort,
          ),
        );
      }
      if (contentRows.isNotEmpty) {
        await db.batch(
          (batch) => batch.insertAll(
            db.storedContent,
            contentRows,
            mode: InsertMode.insertOrReplace,
          ),
        );
      }

      final migratedRows = await db.select(db.storedEvents).get();
      if (migratedRows.length != eventRows.length) {
        throw StateError('Not all legacy events were written to SQLite.');
      }
      final metadata = jsonEncode({
        'version': 1,
        'preserveLegacyKeys': preserveLegacyKeys.toList(),
      });
      await db
          .into(db.storedContent)
          .insert(
            StoredContentCompanion.insert(key: _kMigrationKey, value: metadata),
          );
    });

    // The transaction and row-count check succeeded. Remove only migrated
    // source keys; malformed event lists are retained as a recovery copy.
    await _removeMigratedPreferences(prefs, preserveLegacyKeys);
  }

  Future<void> _removeMigratedPreferences(
    SharedPreferences prefs,
    Set<String> preserveLegacyKeys,
  ) async {
    for (final key in _allLegacyKeys) {
      if (!preserveLegacyKeys.contains(key) && prefs.containsKey(key)) {
        await prefs.remove(key);
      }
    }
  }

  static String _encodeContentValue(Object value) {
    final type = switch (value) {
      String() => 'string',
      List<String>() => 'stringList',
      bool() => 'bool',
      int() => 'int',
      double() => 'double',
      _ => 'json',
    };
    return jsonEncode({'type': type, 'value': value});
  }

  static Object? _decodeContentValue(String encoded) {
    final decoded = jsonDecode(encoded);
    if (decoded is! Map<String, dynamic>) return null;
    final value = decoded['value'];
    return switch (decoded['type']) {
      'string' => value is String ? value : null,
      'stringList' =>
        value is List ? value.map((item) => item.toString()).toList() : null,
      'bool' => value is bool ? value : null,
      'int' => value is int ? value : null,
      'double' => value is num ? value.toDouble() : null,
      'json' => value,
      _ => null,
    };
  }

  /// Read multiple serialized user-content values in one database query.
  Future<Map<String, Object?>> loadContentValues(Iterable<String> keys) async {
    final db = _database;
    await _ensureInitialized();
    final requestedKeys = keys.toSet();
    if (requestedKeys.isEmpty) return {};
    final rows = await (db.select(
      db.storedContent,
    )..where((row) => row.key.isIn(requestedKeys))).get();
    return {for (final row in rows) row.key: _decodeContentValue(row.value)};
  }

  Future<String?> loadContentString(String key) async {
    final value = (await loadContentValues([key]))[key];
    return value is String ? value : null;
  }

  Future<List<String>?> loadContentStringList(String key) async {
    final value = (await loadContentValues([key]))[key];
    return value is List ? value.map((item) => item.toString()).toList() : null;
  }

  /// Persist one or more domain-content values atomically.
  Future<bool> saveContentValues(Map<String, Object?> values) async {
    final db = _database;
    try {
      await _ensureInitialized();
      final rows = <StoredContentCompanion>[
        for (final entry in values.entries)
          if (entry.value != null)
            StoredContentCompanion.insert(
              key: entry.key,
              value: _encodeContentValue(entry.value!),
            ),
      ];
      if (rows.isEmpty) return true;
      await db.batch(
        (batch) => batch.insertAll(
          db.storedContent,
          rows,
          mode: InsertMode.insertOrReplace,
        ),
      );
      return true;
    } catch (error) {
      debugPrint('LocalStorage.saveContentValues failed: $error');
      return false;
    }
  }

  Future<bool> saveContentString(String key, String value) =>
      saveContentValues({key: value});

  Future<List<ScheduledEvent>> _loadEventCollection(String collection) async {
    final db = _database;
    try {
      await _ensureInitialized();
      final rows =
          await (db.select(db.storedEvents)
                ..where((row) => row.collection.equals(collection))
                ..orderBy([(row) => OrderingTerm.asc(row.position)]))
              .get();
      return rows
          .map(
            (row) => ScheduledEvent.fromJson(
              jsonDecode(row.payload) as Map<String, dynamic>,
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<bool> _replaceEventCollection(
    String collection,
    List<ScheduledEvent> events,
  ) async {
    final db = _database;
    try {
      await _ensureInitialized();
      await db.transaction(() async {
        await (db.delete(
          db.storedEvents,
        )..where((row) => row.collection.equals(collection))).go();
        if (events.isEmpty) return;
        await db.batch(
          (batch) => batch.insertAll(db.storedEvents, [
            for (var position = 0; position < events.length; position++)
              StoredEventsCompanion.insert(
                collection: collection,
                id: events[position].id,
                position: position,
                payload: jsonEncode(events[position].toJson()),
              ),
          ]),
        );
      });
      return true;
    } catch (error) {
      debugPrint('LocalStorage event write failed: $error');
      return false;
    }
  }

  /// Persist active events in order.
  Future<bool> saveEvents(List<ScheduledEvent> events) =>
      _replaceEventCollection(_kActive, events);

  Future<List<ScheduledEvent>> loadEvents() => _loadEventCollection(_kActive);

  Future<bool> saveArchivedEvents(List<ScheduledEvent> events) =>
      _replaceEventCollection(_kArchived, events);

  Future<List<ScheduledEvent>> loadArchivedEvents() =>
      _loadEventCollection(_kArchived);

  Future<bool> saveDeletedEvents(List<ScheduledEvent> events) =>
      _replaceEventCollection(_kDeleted, events);

  Future<List<ScheduledEvent>> loadDeletedEvents() =>
      _loadEventCollection(_kDeleted);

  /// Persist the event-to-embedding-version map used by EventPipeline.
  Future<bool> saveEmbeddingVersions(Map<String, String> versions) =>
      saveContentString(_kEmbVersionsKey, jsonEncode(versions));

  Future<Map<String, String>> loadEmbeddingVersions() async {
    try {
      final raw = await loadContentString(_kEmbVersionsKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return {};
      return decoded.map(
        (key, value) => MapEntry(key.toString(), value as String),
      );
    } catch (_) {
      return {};
    }
  }

  /// Persist category sort modes independently of UI preferences.
  Future<void> saveCategorySortMaps(
    Map<String, String> sortByMap,
    Map<String, String> sortDirMap,
  ) async {
    await saveContentValues({
      _kCategorySortByKey: jsonEncode(sortByMap),
      _kCategorySortDirKey: jsonEncode(sortDirMap),
    });
  }

  Future<(Map<String, String>, Map<String, String>)>
  loadCategorySortMaps() async {
    try {
      final values = await loadContentValues([
        _kCategorySortByKey,
        _kCategorySortDirKey,
      ]);
      Map<String, String> decode(String key) {
        final raw = values[key];
        if (raw is! String) return {};
        final decoded = jsonDecode(raw);
        if (decoded is! Map) return {};
        return Map<String, String>.from(
          decoded.map(
            (key, value) => MapEntry(key.toString(), value.toString()),
          ),
        );
      }

      return (decode(_kCategorySortByKey), decode(_kCategorySortDirKey));
    } catch (_) {
      return (<String, String>{}, <String, String>{});
    }
  }

  /// Erase active events while leaving archived and deleted items intact.
  Future<void> clearEvents() async {
    await _replaceEventCollection(_kActive, const []);
  }
}
