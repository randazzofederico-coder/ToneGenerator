import 'dart:async';

import 'package:fede_apps_core/fede_apps_core.dart' show SyncAdapter;
import 'package:uuid/uuid.dart';

import '../l10n/l10n.dart';
import '../models/tone_session.dart';
import '../providers/session_provider.dart';
import '../providers/tone_generator_provider.dart';

/// Connects the session library ([SessionProvider]) with the cloud sync of
/// fede_apps_core (`LibrarySync`): `users/{uid}/appData/tonegenerator`, a
/// single collection `sessions`.
///
/// What arrives from the cloud is written as is by
/// [SessionProvider.applyRemote] (no rev bump, no `notifyLocalChange`).
///
/// The open (working) session, when it was changed remotely — decided once
/// the working state has been restored ([toneReady]):
///  * **deleted** (tombstone or purged): detached, exactly like a local
///    delete — the channels stay as an unsaved session with the same name;
///  * **updated** and the working state is clean and not playing: the new
///    version is loaded (nothing is lost, nothing starts sounding);
///  * **updated** while there are unsaved changes or it's playing: the
///    channels are not touched; only the "saved" reference (and the name)
///    move to the new version, so the session shows as modified and the user
///    decides whether to save over it.
class ToneSyncAdapter implements SyncAdapter {
  ToneSyncAdapter({
    required this.sessions,
    this.tone,
    Future<void>? toneReady,
  }) : toneReady = toneReady ?? tone?.ready ?? Future<void>.value();

  final SessionProvider sessions;

  /// Working state (null: library only, e.g. in tests).
  final ToneGeneratorProvider? tone;

  /// Completes once [tone] restored the last working state.
  final Future<void> toneReady;

  static const _uuid = Uuid();

  @override
  String get appId => 'tonegenerator';

  @override
  List<String> get collections => const [SessionProvider.syncCollection];

  @override
  Future<List<Map<String, dynamic>>> readAll(String collection) async {
    if (collection != SessionProvider.syncCollection) return const [];
    await sessions.ensureLoaded;
    return sessions.allItems.map((s) => s.toJson()).toList();
  }

  @override
  Future<void> applyRemote(
    String collection, {
    required List<Map<String, dynamic>> upserts,
    required List<String> removals,
  }) async {
    if (collection != SessionProvider.syncCollection) return;
    await sessions.applyRemote(upserts: upserts, removals: removals);
    final touched = <String>{
      for (final u in upserts)
        if (u['id'] is String) u['id'] as String,
      ...removals,
    };
    if (tone != null && touched.isNotEmpty) {
      unawaited(toneReady.then((_) => _reconcileActive(touched)));
    }
  }

  void _reconcileActive(Set<String> touched) {
    final t = tone;
    if (t == null) return;
    final id = t.activeSessionId;
    if (id == null || !touched.contains(id)) return;
    final stored = sessions.getSessionById(id);
    if (stored == null) {
      t.detachActive();
    } else if (!t.isDirty && !t.isPlaying) {
      t.loadSession(stored);
    } else {
      t.setSavedReference(stored);
    }
  }

  @override
  Map<String, dynamic> conflictCopy(
      String collection, Map<String, dynamic> item) {
    final name = item['name'] is String ? item['name'] as String : '';
    var copyName = L10n.current.sessionConflictCopyName(name);
    final extra = copyName.length - ToneSession.maxNameLength;
    if (extra > 0 && name.length > extra) {
      copyName = L10n.current
          .sessionConflictCopyName(name.substring(0, name.length - extra).trim());
    }
    return {
      ...item,
      'id': _uuid.v4(),
      'name': copyName,
    };
  }
}
