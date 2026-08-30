/// Shared helpers for the ordered alert sequence stored on events and
/// category presets.
class AlertSequence {
  /// Removes the optional "None" terminator and everything after it while
  /// preserving the authored order. Older records are allowed to contain
  /// null/empty values because they were written by earlier sheet versions.
  static List<String> compact(Iterable<String?> values) {
    final result = <String>[];
    for (final raw in values) {
      final value = raw?.trim();
      if (value == null || value.isEmpty || value == 'None') break;
      result.add(value);
    }
    return List.unmodifiable(result);
  }

  /// Returns true when every alert after the first is strictly closer to the
  /// event than the alert immediately before it. -1 is reserved for None.
  static bool isValid(
    Iterable<String> values,
    Map<String, int> minutesBeforeEvent,
  ) {
    String? previous;
    final seen = <String>{};
    for (final value in values) {
      if (value == 'None') break;
      final currentMinutes = minutesBeforeEvent[value];
      if (currentMinutes == null || !seen.add(value)) return false;
      if (previous != null) {
        final previousMinutes = minutesBeforeEvent[previous];
        if (previousMinutes == null || currentMinutes >= previousMinutes) {
          return false;
        }
      }
      previous = value;
    }
    return true;
  }
}
