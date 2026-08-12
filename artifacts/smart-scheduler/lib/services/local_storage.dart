import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'event_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// LocalStorage — SharedPreferences-based persistence for events.
//
// Categories already use SharedPreferences in EventsTabState._saveCategories;
// this service adds the same pattern for ScheduledEvents so they survive app
// restarts.
//
// Phase 2 will migrate to SQLite (sqflite) when real embeddings (768-dim
// float32 blobs) require more efficient storage — the interface here
// (saveEvents / loadEvents) will remain unchanged.
// ─────────────────────────────────────────────────────────────────────────────
class LocalStorage {
  LocalStorage._();
  static final LocalStorage instance = LocalStorage._();

  static const _kEventsKey = 'skeddo_events_v1';
  static const _kEmbVersionsKey = 'skeddo_emb_versions_v1';

  /// Persist [events] to SharedPreferences as a JSON string list.
  ///
  /// Returns `true` when the write succeeds, `false` when an error occurs.
  /// Callers that need to detect failure (e.g. migration write-back) should
  /// check the return value; the exception is swallowed so the app never
  /// crashes on a save failure.
  Future<bool> saveEvents(List<ScheduledEvent> events) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonList = events.map((e) => jsonEncode(e.toJson())).toList();
      return await prefs.setStringList(_kEventsKey, jsonList);
    } catch (_) {
      // Best-effort persistence; never crash on save failure.
      return false;
    }
  }

  /// Load and return all persisted events, or an empty list on failure.
  Future<List<ScheduledEvent>> loadEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(_kEventsKey) ?? [];
      return raw
          .map((s) {
            try {
              return ScheduledEvent.fromJson(
                jsonDecode(s) as Map<String, dynamic>,
              );
            } catch (_) {
              return null;
            }
          })
          .whereType<ScheduledEvent>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Embedding version map ──────────────────────────────────────────────────

  /// Persist a map of {eventId → embeddingVersion} so EventPipeline can
  /// skip re-embedding events that are already at the current text-builder
  /// version on future startups.
  ///
  /// Returns `true` when the write succeeds, `false` when an error occurs.
  /// Callers that need to detect failure should check the return value; the
  /// exception is swallowed so the app never crashes on a save failure.
  Future<bool> saveEmbeddingVersions(Map<String, String> versions) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.setString(_kEmbVersionsKey, jsonEncode(versions));
    } catch (_) {
      // Best-effort persistence; never crash on save failure.
      return false;
    }
  }

  /// Load the persisted {eventId → embeddingVersion} map, or {} on failure.
  Future<Map<String, String>> loadEmbeddingVersions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kEmbVersionsKey);
      if (raw == null) return {};
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      return decoded.map((k, v) => MapEntry(k, v as String));
    } catch (_) {
      return {};
    }
  }

  // ── DCV sort settings (per-category) ─────────────────────────────────────
  // Each category stores its own Sort By mode and direction independently.
  // Format: two JSON-encoded Map<String,String> blobs keyed by category label.

  static const _kCategorySortByKey  = 'skeddo_category_sort_by_v1';
  static const _kCategorySortDirKey = 'skeddo_category_sort_dir_v1';

  /// Persist the full per-category sort maps in one atomic write pair.
  Future<void> saveCategorySortMaps(
    Map<String, String> sortByMap,
    Map<String, String> sortDirMap,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kCategorySortByKey,  jsonEncode(sortByMap));
      await prefs.setString(_kCategorySortDirKey, jsonEncode(sortDirMap));
    } catch (_) {}
  }

  /// Load both per-category sort maps.  Returns empty maps when nothing has
  /// been saved yet; individual missing entries default to 'Manual' / '' at
  /// the call site.
  Future<(Map<String, String>, Map<String, String>)> loadCategorySortMaps() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      Map<String, String> decode(String key) {
        final raw = prefs.getString(key);
        if (raw == null) return {};
        final decoded = jsonDecode(raw);
        if (decoded is! Map) return {};
        return Map<String, String>.from(
          decoded.map((k, v) => MapEntry(k.toString(), v.toString())),
        );
      }
      return (decode(_kCategorySortByKey), decode(_kCategorySortDirKey));
    } catch (_) {
      return (<String, String>{}, <String, String>{});
    }
  }

  // ── Erase ──────────────────────────────────────────────────────────────────

  /// Erase all persisted events.
  Future<void> clearEvents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kEventsKey);
    } catch (_) {}
  }
}
