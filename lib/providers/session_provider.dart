import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../l10n/l10n.dart';
import '../models/tone_session.dart';

/// Library of saved sessions, persisted in SharedPreferences as a JSON list.
class SessionProvider extends ChangeNotifier {
  static const _prefsKey = 'tone_sessions';
  static const _uuid = Uuid();

  final List<ToneSession> _sessions = [];
  final Completer<void> _loaded = Completer<void>();

  /// Completes once the library has been read from disk.
  Future<void> get ensureLoaded => _loaded.future;

  /// Sessions, most recently updated first.
  List<ToneSession> get sessions {
    final list = List.of(_sessions)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return List.unmodifiable(list);
  }

  Future<void> loadSessions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null) {
        final list = jsonDecode(raw) as List<dynamic>;
        _sessions
          ..clear()
          ..addAll(list.whereType<Map>().map(
              (m) => ToneSession.fromJson(Map<String, dynamic>.from(m))));
      }
    } catch (e) {
      debugPrint('SessionProvider.loadSessions error: $e');
    } finally {
      if (!_loaded.isCompleted) _loaded.complete();
      notifyListeners();
    }
  }

  ToneSession? getSessionById(String id) {
    for (final s in _sessions) {
      if (s.id == id) return s;
    }
    return null;
  }

  /// Whether another session (different [exceptId]) already uses [name].
  bool nameExists(String name, {String? exceptId}) {
    final n = name.trim().toLowerCase();
    return _sessions.any((s) => s.id != exceptId && s.name.toLowerCase() == n);
  }

  /// Adds or replaces (same ID) a session.
  Future<void> saveSession(ToneSession session) async {
    final i = _sessions.indexWhere((s) => s.id == session.id);
    if (i >= 0) {
      _sessions[i] = session;
    } else {
      _sessions.add(session);
    }
    await _persist();
  }

  Future<ToneSession?> renameSession(String id, String name) async {
    final i = _sessions.indexWhere((s) => s.id == id);
    if (i < 0) return null;
    final updated =
        _sessions[i].copyWith(name: name.trim(), updatedAt: DateTime.now());
    _sessions[i] = updated;
    await _persist();
    return updated;
  }

  Future<ToneSession?> duplicateSession(String id) async {
    final original = getSessionById(id);
    if (original == null) return null;
    final now = DateTime.now();
    final copy = original.copyWith(
      id: _uuid.v4(),
      name: _uniqueName(L10n.current.sessionCopyName(original.name)),
      createdAt: now,
      updatedAt: now,
    );
    _sessions.add(copy);
    await _persist();
    return copy;
  }

  /// Removes a session; returns it (for undo) or null if missing.
  Future<ToneSession?> deleteSession(String id) async {
    final i = _sessions.indexWhere((s) => s.id == id);
    if (i < 0) return null;
    final removed = _sessions.removeAt(i);
    await _persist();
    return removed;
  }

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
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _prefsKey, jsonEncode(_sessions.map((s) => s.toJson()).toList()));
    } catch (e) {
      debugPrint('SessionProvider._persist error: $e');
    }
  }
}
