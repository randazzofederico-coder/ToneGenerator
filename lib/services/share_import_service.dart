import 'package:uuid/uuid.dart';

import '../models/tone_session.dart';
import '../providers/session_provider.dart';
import 'deep_link_service.dart';

/// Result of importing a [SharedBundle] into the local library.
class ShareImportResult {
  final ToneSession session;

  /// True if nothing new was added (link opened before, or own content).
  final bool alreadyInLibrary;

  const ShareImportResult({
    required this.session,
    required this.alreadyInLibrary,
  });
}

/// Imports shared sessions into the local library.
///
/// ID strategy (idempotent, no extra storage needed):
///  * If the original ID already exists locally, the session is the user's
///    own (they opened their own link) → reuse it.
///  * Otherwise the local ID is a UUID v5 derived from `shareId + originalId`,
///    so opening the same link again maps to the same local session and
///    nothing is duplicated. If the user deleted it, it's re-created.
class ShareImportService {
  final SessionProvider sessions;

  ShareImportService({required this.sessions});

  static const _uuid = Uuid();

  static String derivedId(String shareId, String originalId) =>
      _uuid.v5(Namespace.url.value, 'tonegen-share:$shareId:$originalId');

  Future<ShareImportResult> import(SharedBundle bundle) async {
    await sessions.ensureLoaded;

    // Defensive parse: clamps values, limits channels, sanitises the name.
    final shared = ToneSession.fromJson(bundle.data);

    final own = sessions.getSessionById(shared.id);
    if (own != null) {
      return ShareImportResult(session: own, alreadyInLibrary: true);
    }

    final localId = derivedId(bundle.shareId, shared.id);
    final existing = sessions.getSessionById(localId);
    if (existing != null) {
      return ShareImportResult(session: existing, alreadyInLibrary: true);
    }

    final now = DateTime.now();
    final imported = shared.copyWith(
      id: localId,
      name: _uniqueName(shared.name),
      createdAt: now,
      updatedAt: now,
    );
    await sessions.saveSession(imported);
    return ShareImportResult(session: imported, alreadyInLibrary: false);
  }

  /// Avoids clashing with an existing local session of the same name.
  String _uniqueName(String base) {
    if (!sessions.nameExists(base)) return base;
    var n = 2;
    while (sessions.nameExists('$base ($n)')) {
      n++;
    }
    return '$base ($n)';
  }
}
