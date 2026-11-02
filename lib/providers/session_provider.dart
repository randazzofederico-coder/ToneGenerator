import 'dart:async';
import 'dart:convert';

import 'package:fede_apps_core/fede_apps_core.dart'
    show DeviceIdentity, SyncFields;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../l10n/l10n.dart';
import '../models/tone_session.dart';

/// Library of saved sessions, persisted in SharedPreferences as a JSON list.
///
/// Ready for a future cloud sync (contract: fede_apps_core `SyncFields`):
///  * every change of a stored session bumps `rev`, sets `updatedAt = now`
///    and `dev = DeviceIdentity.id`; a new session starts at `rev 1`;
///  * deleting leaves a tombstone (`deleted`, `deletedAt`) in the stored
///    list instead of removing it. Tombstones are invisible to the rest of
///    the app ([sessions], [getSessionById], [nameExists]) and are purged on
///    load after `SyncFields.tombstoneRetention` (30 days).
class SessionProvider extends ChangeNotifier {
  static const _prefsKey = 'tone_sessions';
  static const _uuid = Uuid();

  /// Every stored item, tombstones included.
  final List<ToneSession> _items = [];
  final Completer<void> _loaded = Completer<void>();

  /// Clock (overridable in tests).
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// Completes once the library has been read from disk.
  Future<void> get ensureLoaded => _loaded.future;

  /// Live (non-deleted) sessions, most recently updated first.
  List<ToneSession> get sessions {
    final list = _items.where((s) => !s.deleted).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(list);
  }

  /// Every stored item including tombstones (for sync / tests only).
  List<ToneSession> get allItems => List.unmodifiable(_items);

  Future<void> loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        final all = list
            .whereType<Map>()
            .map((m) => ToneSession.fromJson(Map<String, dynamic>.from(m)))
            .toList();
        final now = clock();
        final kept = all
            .where((s) => !SyncFields.shouldPurge(
                deleted: s.deleted, deletedAt: s.deletedAt, now: now))
            .toList();
        _items
          ..clear()
          ..addAll(kept);
        if (kept.length != all.length) await _write();
      }
    } catch (e) {
      debugPrint('SessionProvider.loadSessions error: $e');
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
      notifyListeners();
    }
  }

  /// Live session with [id] (tombstones are ignored).
  ToneSession? getSessionById(String id) {
    for (final s in _items) {
      if (s.id == id && !s.deleted) return s;
    }
    return null;
  }

  /// Whether another live session (different [exceptId]) already uses [name].
  bool nameExists(String name, {String? exceptId}) {
    final n = name.trim().toLowerCase();
    return _items.any((s) =>
        !s.deleted && s.id != exceptId && s.name.toLowerCase() == n);
  }

  /// Adds or replaces (same ID) a session and returns it as stored.
  ///
  /// Sync fields of [session] are ignored: if an item with the same ID is
  /// stored (live or tombstone) the result is `rev + 1` of it — so saving
  /// over a tombstone (undo of a delete, re-importing a deleted link)
  /// revives it with a newer revision than the deletion. Otherwise it's a
  /// new item at `rev 1`. Always `updatedAt = now`, `dev = this device`.
  Future<ToneSession> saveSession(ToneSession session) async {
    final i = _indexOf(session.id);
    final stamped = session.revised(
      rev: i >= 0 ? _items[i].rev + 1 : 1,
      now: clock(),
      device: DeviceIdentity.id,
    );
    if (i >= 0) {
      _items[i] = stamped;
    } else {
      _items.add(stamped);
    }
    await _persist();
    return stamped;
  }

  Future<ToneSession?> renameSession(String id, String name) async {
    final i = _indexOf(id);
    if (i < 0 || _items[i].deleted) return null;
    final current = _items[i];
    final updated = current.copyWith(name: name.trim()).revised(
          rev: current.rev + 1,
          now: clock(),
          device: DeviceIdentity.id,
        );
    _items[i] = updated;
    await _persist();
    return updated;
  }

  /// Copy with a new ID and `rev 1`.
  Future<ToneSession?> duplicateSession(String id) async {
    final original = getSessionById(id);
    if (original == null) return null;
    final now = clock();
    final copy = original
        .copyWith(
          id: _uuid.v4(),
          name: _uniqueName(L10n.current.sessionCopyName(original.name)),
          createdAt: now,
        )
        .revised(rev: 1, now: now, device: DeviceIdentity.id);
    _items.add(copy);
    await _persist();
    return copy;
  }

  /// Deletes a session (leaves a tombstone); returns the live session as it
  /// was (for undo → [saveSession] revives it) or null if missing.
  Future<ToneSession?> deleteSession(String id) async {
    final i = _indexOf(id);
    if (i < 0 || _items[i].deleted) return null;
    final removed = _items[i];
    _items[i] = removed.tombstoned(now: clock(), device: DeviceIdentity.id);
    await _persist();
    return removed;
  }

  int _indexOf(String id) => _items.indexWhere((s) => s.id == id);

  String _uniqueName(String base) {
    if (!nameExists(base)) return base;
    var n = 2;
    while (nameExists('$base $n')) {
      n++;
    }
    return '$base $n';
  }

  Future<void> _persist() async {
    notifyListeners();
    await _write();
  }

  Future<void> _write() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, jsonEncode(_items.map((s) => s.toJson()).toList()));
    } catch (e) {
      debugPrint('SessionProvider._persist error: $e');
    }
  }
}
