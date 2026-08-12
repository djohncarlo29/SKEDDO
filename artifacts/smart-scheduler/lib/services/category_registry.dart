import 'package:flutter/painting.dart' show Color;

// ─────────────────────────────────────────────────────────────────────────────
// CategoryRegistry — lightweight app-wide map from category ID → display meta.
//
// Populated by EventsTabState whenever categories are loaded or changed.
// Read by SmartSearchResults (and any other widget) to show category name /
// colour alongside event tiles without needing a BuildContext dependency.
//
// The stored [rawColor] is unresolved; callers must pass it through
// renderCategoryColor(rawColor, context) at render time to honour dark-mode
// and the kCatBlue accent-tracking sentinel.
// ─────────────────────────────────────────────────────────────────────────────
class CategoryRegistry {
  CategoryRegistry._();

  static final _data = <String, CategoryMeta>{};

  /// Replace the entire registry contents with [entries].
  /// Cheap — just clears and refills the internal map.
  static void update(Map<String, CategoryMeta> entries) {
    _data
      ..clear()
      ..addAll(entries);
  }

  /// Return the [CategoryMeta] for [categoryId], or null if unknown.
  static CategoryMeta? get(String categoryId) => _data[categoryId];

  /// All registered entries (read-only view).
  static Iterable<MapEntry<String, CategoryMeta>> get entries => _data.entries;
}

/// Minimum display metadata for one category.
class CategoryMeta {
  /// Human-readable category name (shown in search results).
  final String name;

  /// Raw [Color] as stored on the [_UserCategory] object —
  /// NOT resolved for dark-mode yet.  Pass through
  /// `renderCategoryColor(rawColor, context)` before painting.
  final Color rawColor;

  const CategoryMeta({required this.name, required this.rawColor});
}
