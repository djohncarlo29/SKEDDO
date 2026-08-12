import 'dart:io';

import 'package:flutter/foundation.dart';

import 'ai_services.dart';
import '../services/event_store.dart';
import '../services/local_storage.dart';

// ── Embedding text-builder version ────────────────────────────────────────────
// Bump this constant whenever the text built in [_buildText] changes so that
// stale event embeddings are automatically re-generated on the next startup.
//
// History:
//   v1 — title + date + location only (original schema)
//   v2 — adds subtitle, destination, notes, day name, time-of-day label
const kEmbeddingTextVersion = 'v2';

// ── Time-of-day bucketer ──────────────────────────────────────────────────────
// Converts a stored time string ("9:30 AM", "3:00 PM") into a natural-language
// label so Smart Category rules like "Sunday morning" can match on time-of-day.
//
// Buckets:
//   morning   → 05:00–11:59
//   afternoon → 12:00–16:59
//   evening   → 17:00–20:59
//   night     → 21:00–04:59
String? _timeOfDayLabel(String? timeStr) {
  if (timeStr == null || timeStr.isEmpty) return null;
  final m = RegExp(
    r'^(\d{1,2}):(\d{2})\s*(AM|PM)$',
    caseSensitive: false,
  ).firstMatch(timeStr.trim());
  if (m == null) return null;
  var hour = int.parse(m.group(1)!);
  final isPm = m.group(3)!.toUpperCase() == 'PM';
  if (isPm && hour != 12) hour += 12;
  if (!isPm && hour == 12) hour = 0;
  if (hour >= 5 && hour < 12) return 'morning';
  if (hour >= 12 && hour < 17) return 'afternoon';
  if (hour >= 17 && hour < 21) return 'evening';
  return 'night';
}

// ── Rich text builder ─────────────────────────────────────────────────────────
// Builds the embedding input text for an event.  All callers — _onAdded,
// _onUpdated, and _reembedStale — go through this single function so the
// embedding is always generated from identical text regardless of code path.
//
// Field priority:
//   title + subtitle  — what the event is
//   destination       — WHERE it happens (strongest location signal)
//   location          — starting point (weaker, keep as fallback context)
//   notes             — richest free-text the user writes
//   date + day name   — enables "Aug 26", "Saturday" style Smart rules
//   time              — enables "morning", "3:00 PM" style rules
String _buildText(ScheduledEvent event) {
  final pd = event.parsedDate;
  final dayName = pd?.absoluteDate != null
      ? const [
          'Monday', 'Tuesday', 'Wednesday', 'Thursday',
          'Friday', 'Saturday', 'Sunday',
        ][pd!.absoluteDate!.weekday - 1]
      : null;

  return [
    event.title,
    if (event.subtitle != null && event.subtitle!.isNotEmpty)
      event.subtitle!,
    if (event.destination != null && event.destination!.isNotEmpty)
      event.destination!,
    if (event.location != null && event.location!.isNotEmpty)
      event.location!,
    if (event.notes != null && event.notes!.isNotEmpty) event.notes!,
    // Date/time context — lets Smart Categories match on specific dates,
    // day-of-week, and time-of-day patterns ("Aug 26", "Saturday",
    // "morning", "Sunday morning", etc.).
    if (event.date != null && event.date!.isNotEmpty) event.date!,
    if (dayName != null) dayName,
    if (event.time != null && event.time!.isNotEmpty) event.time!,
    if (_timeOfDayLabel(event.time) case final tod?) tod,
  ].join(' ');
}

// ─────────────────────────────────────────────────────────────────────────────
// EventPipeline — processes every event through the full AI pipeline.
//
// Registers hooks on EventStore so all event creation/deletion paths
// automatically trigger pipeline processing without callers needing to
// know about it.
//
// Pipeline steps on create / update:
//   1. LocalStorage  — persist all events to SharedPreferences.
//   2. AIServices    — embed text → upsert HNSW vector index → register in
//                      HybridMatcher for Smart Category matching.
//   3. LocalStorage  — persist the current [kEmbeddingTextVersion] for this
//                      event so future startups can skip re-embedding it.
//
// On startup, call [scheduleBackgroundReembed] after EventStore.loadFromStorage
// completes.  It runs in the background (never blocks the UI) and:
//   • Loads the persisted {eventId → version} map.
//   • For events already at [kEmbeddingTextVersion]: loads their stored vector
//     from the HNSW index directly into the HybridMatcher (no model call).
//   • For stale events: re-embeds with the current text builder, updates the
//     HNSW index and HybridMatcher, and saves the new version.
//
// Date parsing happens synchronously inside EventStore.create() so the
// ParsedDate is available immediately on the returned event (no pipeline
// step needed).
// ─────────────────────────────────────────────────────────────────────────────
class EventPipeline {
  EventPipeline._();
  static final EventPipeline instance = EventPipeline._();

  /// Call once at app startup to wire this pipeline into EventStore.
  void init() {
    EventStore.setPipelineHooks(
      onAdded: _onAdded,
      onRemoved: _onRemoved,
      onUpdated: _onUpdated,
      onCleared: _onCleared,
    );
  }

  /// Schedule a background pass that populates the HybridMatcher for all
  /// [allEvents] loaded from storage.
  ///
  /// Events already embedded at [kEmbeddingTextVersion] are registered into
  /// the HybridMatcher from their stored HNSW vector — no model call is made.
  /// Events at an older version (or with no stored version) are re-embedded
  /// with the current text builder and their new version is persisted.
  ///
  /// Must be called after [EventStore.loadFromStorage] and runs entirely in
  /// the background — it never blocks or delays app startup.
  void scheduleBackgroundReembed(List<ScheduledEvent> allEvents) {
    if (allEvents.isEmpty) return;
    // Schedule as a low-priority future so the first frame renders first.
    Future(() => _reembedStale(allEvents));
  }

  Future<void> _reembedStale(List<ScheduledEvent> allEvents) async {
    try {
      final versions = await LocalStorage.instance.loadEmbeddingVersions();
      final updated = Map<String, String>.from(versions);
      var dirty = false;

      for (final event in allEvents) {
        final storedVec = AIServices.getEventVector(event.id);

        if (versions[event.id] == kEmbeddingTextVersion && storedVec != null) {
          // Already at the current version AND the vector is in the HNSW
          // index — just warm up the HybridMatcher (no model call needed).
          AIServices.hybridMatcher.setEventEmbedding(event.id, storedVec);
        } else {
          // Stale version, no version record, OR version is current but the
          // HNSW vector is missing (e.g. index wasn't persisted last run) —
          // always re-embed so the matcher has a reliable vector.
          final text = _buildText(event);
          if (text.trim().isNotEmpty) {
            final ok = await AIServices.embedEvent(event.id, text);
            // Only advance the stored version when embedding actually succeeded.
            // On failure (model not ready, I/O error) we leave the version
            // unchanged so the next startup retries rather than permanently
            // skipping this event.
            if (ok) {
              updated[event.id] = kEmbeddingTextVersion;
              dirty = true;
            }
          }
        }
      }

      if (dirty) {
        final saved = await LocalStorage.instance.saveEmbeddingVersions(updated);
        if (!saved) {
          debugPrint(
            '[EventPipeline] WARNING: saveEmbeddingVersions returned false during '
            'background re-embed — version map not persisted; will retry on next launch.',
          );
        }
      }
    } catch (_) {
      // Background errors must never surface to the user.
    }
  }

  Future<void> _onAdded(
    ScheduledEvent event,
    List<ScheduledEvent> allEvents,
  ) async {
    try {
      // 1. Persist the full event list.
      final savedEvents = await LocalStorage.instance.saveEvents(allEvents);
      if (!savedEvents) {
        debugPrint(
          '[EventPipeline] WARNING: saveEvents returned false after adding event '
          '${event.id} — event list not persisted to disk; in-memory state and '
          'disk are now diverged.',
        );
      }

      // 2. Embed + index + register for Smart Category matching.
      final text = _buildText(event);
      final ok = await AIServices.embedEvent(event.id, text);

      // 3. AI priority classification — runs after embedding so the event
      //    vector is available in the HNSW index.  Uses setPriority() which
      //    updates in-place without firing a re-embed hook, avoiding a loop.
      if (ok) {
        final priority = AIServices.classifyPriority(event.id);
        if (priority != event.priority) {
          EventStore.instance.setPriority(event.id, priority);
        }
      }

      // 4. Persist the current embedding version — only if embedding succeeded.
      //    On failure the version entry is left absent so the background pass
      //    on the next startup retries rather than treating the event as current.
      if (ok) {
        final versions = await LocalStorage.instance.loadEmbeddingVersions();
        versions[event.id] = kEmbeddingTextVersion;
        final saved = await LocalStorage.instance.saveEmbeddingVersions(versions);
        if (!saved) {
          debugPrint(
            '[EventPipeline] WARNING: saveEmbeddingVersions returned false after '
            'adding event ${event.id} — version not persisted; will re-embed on next launch.',
          );
        }
      }
    } catch (_) {
      // Pipeline errors must never crash the app; events are already in memory.
    }
  }

  /// Re-embed an event after it has been edited so Smart Category matching
  /// reflects the new title, subtitle, date, time, location, etc.
  ///
  /// Event persistence is the caller's responsibility — [EventStore.update]
  /// and [EventStore.updateCategoryPresets] already save before firing this
  /// hook.  This method only handles the AI/embedding side.
  Future<void> _onUpdated(ScheduledEvent event) async {
    try {
      final text = _buildText(event);
      final ok = await AIServices.embedEvent(event.id, text);
      if (ok) {
        // Re-classify priority after re-embedding so edits to title/notes
        // are reflected in the priority score.
        final priority = AIServices.classifyPriority(event.id);
        if (priority != event.priority) {
          EventStore.instance.setPriority(event.id, priority);
        }
      }
      // Advance the stored version so the next startup doesn't re-embed
      // unnecessarily. Only written on success — a failed embedding leaves
      // the version absent so the background pass on the next startup retries.
      if (ok) {
        final versions = await LocalStorage.instance.loadEmbeddingVersions();
        versions[event.id] = kEmbeddingTextVersion;
        final saved = await LocalStorage.instance.saveEmbeddingVersions(versions);
        if (!saved) {
          debugPrint(
            '[EventPipeline] WARNING: saveEmbeddingVersions returned false after '
            'updating event ${event.id} — version not persisted; will re-embed on next launch.',
          );
        }
      }
    } catch (_) {
      // Background errors must never crash the app.
    }
  }

  /// Deletes attachment files for all events that were wiped by
  /// [EventStore.clear].  Mirrors the per-event cleanup in [_onRemoved] but
  /// operates on the full flat list of paths in a single pass.
  Future<void> _onCleared(List<String> allAttachmentPaths) async {
    for (final p in allAttachmentPaths) {
      try {
        final f = File(p);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {
        // Best-effort — a missing or locked file must never block the wipe.
      }
    }
  }

  Future<void> _onRemoved(
    String eventId,
    List<String> attachmentPaths,
    List<ScheduledEvent> allEvents,
  ) async {
    try {
      await AIServices.removeEvent(eventId);
      final savedEvents = await LocalStorage.instance.saveEvents(allEvents);
      if (!savedEvents) {
        debugPrint(
          '[EventPipeline] WARNING: saveEvents returned false after removing event '
          '$eventId — event list not persisted to disk; in-memory state and '
          'disk are now diverged.',
        );
      }

      // Clean up the version entry so deleted events don't linger in storage.
      final versions = await LocalStorage.instance.loadEmbeddingVersions();
      if (versions.remove(eventId) != null) {
        final saved = await LocalStorage.instance.saveEmbeddingVersions(versions);
        if (!saved) {
          debugPrint(
            '[EventPipeline] WARNING: saveEmbeddingVersions returned false after '
            'removing event $eventId — stale version entry may linger until next launch.',
          );
        }
      }

      // Delete attachment files from disk so they don't pile up over time.
      for (final p in attachmentPaths) {
        try {
          final f = File(p);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {
          // Best-effort — a missing or locked file must never block deletion.
        }
      }
    } catch (_) {}
  }
}
