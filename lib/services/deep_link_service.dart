import 'dart:async';
import 'dart:convert';

import 'package:app_links/app_links.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../l10n/l10n.dart';
import '../models/tone_session.dart';

// Conditional import: web reads/cleans the browser URL, stub is a no-op.
import 'deep_link_stub.dart'
    if (dart.library.js_interop) 'deep_link_web.dart';

/// A ready-to-share link produced by [DeepLinkService].
class SharedLink {
  final String id;
  final String url;

  /// Human title, e.g. "Sesión: Afinación 432".
  final String title;

  /// Full message to send (includes the URL).
  final String message;

  const SharedLink({
    required this.id,
    required this.url,
    required this.title,
    required this.message,
  });
}

/// Decoded content of a shared link.
class SharedBundle {
  final String shareId;
  final String name;

  /// Session JSON as shared (validated later by [ToneSession.fromJson]).
  final Map<String, dynamic> data;

  const SharedBundle({
    required this.shareId,
    required this.name,
    required this.data,
  });
}

/// User-facing error raised while creating a share link.
class ShareException implements Exception {
  final String message;
  const ShareException(this.message);
  @override
  String toString() => message;
}

/// Shares sessions via deep links (same design as the Metrónomo app).
///
/// Workflow:
///  **Export** — signs in (anonymously if needed), serialises the session and
///               stores it in Firestore under a *content-addressed* short ID
///               (same content + same author ⇒ same link, no duplicate docs).
///               URL: `…/tone-generator/?share=<id>&name=<slug>`.
///  **Import (Web)** — on app start, checks the URL for `?share=` via JS interop.
///  **Import (Native)** — listens for App Links via the `app_links` package.
///
/// Document schema (v1) in `tone_shared_links/{id}`:
/// ```
/// v: 1, type: "session", name, ownerUid, summary{channels, waveforms},
/// payload: "<JSON string {data}>",
/// createdAt, expiresAt
/// ```
/// The payload is stored as a JSON string so it is format-stable across
/// platforms (no int/double drift on web) and readable by the website/forum.
///
/// Firebase project is on the Spark plan (no TTL policies), so expired docs
/// are removed lazily by the client: up to 10 on each link creation, and any
/// expired link that gets opened. Rules only allow deleting expired docs.
class DeepLinkService {
  // Singleton -----------------------------------------------------------------
  static final DeepLinkService _instance = DeepLinkService._();
  factory DeepLinkService() => _instance;
  DeepLinkService._();

  // Configuration -------------------------------------------------------------
  static const String baseUrl =
      'https://federicorandazzo.com.ar/tone-generator/';
  static const String collection = 'tone_shared_links';
  static const int _ttlDays = 30;
  static const int _schemaVersion = 1;
  static const String _type = 'session';

  // Native link listener ------------------------------------------------------
  StreamSubscription<Uri>? _linkSub;

  /// Share ID captured at app startup (before any screen mounts).
  String? _pendingShareId;

  /// Share IDs already dispatched during this app run. `app_links` may deliver
  /// the same initial link through several paths (getInitialLink + stream).
  final Set<String> _dispatched = {};

  /// Call from main.dart BEFORE runApp() to capture the initial deep link.
  Future<void> captureInitialLink() async {
    if (kIsWeb) {
      _pendingShareId = _sanitizeId(getShareParamFromUrl());
      if (_pendingShareId != null) cleanShareParamFromUrl();
      return;
    }
    try {
      final initialUri = await AppLinks().getInitialLink();
      if (initialUri != null) {
        _pendingShareId = _extractShareId(initialUri);
      }
    } catch (e) {
      debugPrint('DeepLinkService.captureInitialLink error: $e');
    }
  }

  /// Returns and clears the pending share ID (if any) — only once.
  String? consumePendingShareId() {
    final id = _pendingShareId;
    _pendingShareId = null;
    if (id == null || !_dispatched.add(id)) return null;
    return id;
  }

  /// Listens for links arriving while the app runs:
  ///  * Native: App Links via `app_links`.
  ///  * Web (installed PWA): `launchQueue` when the window is reused.
  /// Already-dispatched IDs are ignored so a link is imported once.
  void listenIncomingLinks(void Function(String shareId) onShareReceived) {
    if (kIsWeb) {
      listenWebLaunchQueue((raw) {
        final id = _sanitizeId(raw);
        if (id != null && _dispatched.add(id)) onShareReceived(id);
      });
      return;
    }
    _linkSub?.cancel();
    _linkSub = AppLinks().uriLinkStream.listen((uri) {
      final id = _extractShareId(uri);
      if (id != null && _dispatched.add(id)) onShareReceived(id);
    });
  }

  String? _extractShareId(Uri uri) => _sanitizeId(uri.queryParameters['share']);

  /// IDs are 10 chars base36; anything else is ignored.
  String? _sanitizeId(String? id) {
    if (id == null) return null;
    final trimmed = id.trim();
    return RegExp(r'^[a-z0-9]{6,32}$').hasMatch(trimmed) ? trimmed : null;
  }

  /// Whether a native share sheet is available (Web Share API on web).
  bool get canNativeShare => kIsWeb ? webCanShare() : true;

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Ensures there is a Firebase user (anonymous if none). The anonymous
  /// account can later be upgraded with `linkWithCredential`, keeping the
  /// same uid so links remain attributed to the user.
  Future<User> _ensureUser() async {
    final auth = FirebaseAuth.instance;
    final current = auth.currentUser;
    if (current != null) return current;
    try {
      final cred = await auth.signInAnonymously();
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      debugPrint('DeepLinkService anonymous sign-in failed: ${e.code}');
      throw ShareException(L10n.current.shareErrorServer);
    }
  }

  /// Converts a human-readable name into a URL-safe slug.
  static String slugify(String name) {
    return name
        .toLowerCase()
        .replaceAll(RegExp(r'[áàäâ]'), 'a')
        .replaceAll(RegExp(r'[éèëê]'), 'e')
        .replaceAll(RegExp(r'[íìïî]'), 'i')
        .replaceAll(RegExp(r'[óòöô]'), 'o')
        .replaceAll(RegExp(r'[úùüû]'), 'u')
        .replaceAll(RegExp(r'[ñ]'), 'n')
        .replaceAll(RegExp(r'[^a-z0-9\s-]'), '')
        .trim()
        .replaceAll(RegExp(r'\s+'), '-')
        .replaceAll(RegExp(r'-+'), '-');
  }

  /// Canonicalises JSON for hashing: sorted keys, volatile fields removed.
  static Object? _canonical(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((k) => k.toString()).toList()..sort();
      return {
        for (final k in keys)
          if (k != 'createdAt' && k != 'updatedAt') k: _canonical(value[k]),
      };
    }
    if (value is List) return value.map(_canonical).toList();
    return value;
  }

  /// Short content-addressed ID (10 chars, base36) from SHA-256.
  @visibleForTesting
  static String contentId(String ownerUid, Map<String, dynamic> payload) {
    final canonical = jsonEncode(_canonical({'o': ownerUid, 'p': payload}));
    final bytes = sha256.convert(utf8.encode(canonical)).bytes;
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(10, (i) => chars[bytes[i] % chars.length]).join();
  }

  Timestamp _newExpiry() =>
      Timestamp.fromDate(DateTime.now().add(const Duration(days: _ttlDays)));

  // ── Export (share) ─────────────────────────────────────────────────────────

  /// Creates (or reuses) the link for [session].
  Future<SharedLink> createSessionLink(ToneSession session) async {
    final user = await _ensureUser();
    final payload = {'data': session.toJson()};
    final shareId = contentId(user.uid, payload);
    final ref = FirebaseFirestore.instance.collection(collection).doc(shareId);

    try {
      final existing = await ref.get();
      if (existing.exists) {
        // Same content already shared by this user: just extend its life.
        unawaited(ref.update({'expiresAt': _newExpiry()}).catchError((_) {}));
      } else {
        await ref.set({
          'v': _schemaVersion,
          'type': _type,
          'name': session.name,
          'ownerUid': user.uid,
          'summary': {
            'channels': session.channels.length,
            'waveforms': session.waveformNames,
          },
          'payload': jsonEncode(payload),
          'createdAt': FieldValue.serverTimestamp(),
          'expiresAt': _newExpiry(),
        });
      }
    } on FirebaseException catch (e) {
      debugPrint('DeepLinkService.createSessionLink ${e.code}: ${e.message}');
      throw ShareException(e.code == 'permission-denied'
          ? L10n.current.shareErrorPermission
          : L10n.current.shareErrorConnection);
    }

    final slug = slugify(session.name);
    final url = slug.isEmpty
        ? '$baseUrl?share=$shareId'
        : '$baseUrl?share=$shareId&name=$slug';

    // Lazy cleanup of expired links (Spark plan has no TTL policies).
    unawaited(_cleanupExpiredLinks());

    return SharedLink(
      id: shareId,
      url: url,
      title: L10n.current.shareLinkTitle(session.name),
      message: L10n.current
          .shareLinkMessage(session.name, session.summaryLabel, url),
    );
  }

  // ── Import (receive) ──────────────────────────────────────────────────────

  /// Fetches and decodes a shared link. Returns `null` if missing/expired.
  Future<SharedBundle?> fetchSharedBundle(String shareId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection(collection)
          .doc(shareId)
          .get();
      if (!doc.exists) return null;
      final raw = doc.data()!;

      final expiresAt = raw['expiresAt'];
      if (expiresAt is Timestamp &&
          expiresAt.toDate().isBefore(DateTime.now())) {
        // Expired: delete it (rules allow deleting only expired docs).
        unawaited(doc.reference.delete().catchError((_) {}));
        return null;
      }

      // Renew TTL (best-effort; rules allow touching only `expiresAt`).
      unawaited(doc.reference
          .update({'expiresAt': _newExpiry()})
          .catchError((e) => debugPrint('TTL renew skipped: $e')));

      if (raw['type'] != _type || raw['payload'] is! String) return null;
      final body = jsonDecode(raw['payload'] as String);
      if (body is! Map || body['data'] is! Map) return null;

      return SharedBundle(
        shareId: shareId,
        name: raw['name'] as String? ?? '',
        data: Map<String, dynamic>.from(body['data'] as Map),
      );
    } catch (e) {
      debugPrint('DeepLinkService.fetchSharedBundle error: $e');
      return null;
    }
  }

  /// Deletes up to 10 expired links (best-effort, fire-and-forget).
  ///
  /// Security rules only allow listing/deleting docs whose `expiresAt` is in
  /// the past, so the query uses a 1-hour safety margin against clock skew
  /// (rules compare against server time).
  Future<void> _cleanupExpiredLinks() async {
    try {
      final cutoff = Timestamp.fromDate(
          DateTime.now().subtract(const Duration(hours: 1)));
      final expired = await FirebaseFirestore.instance
          .collection(collection)
          .where('expiresAt', isLessThan: cutoff)
          .limit(10)
          .get();
      for (final doc in expired.docs) {
        unawaited(doc.reference.delete().catchError((_) {}));
      }
      if (expired.docs.isNotEmpty) {
        debugPrint(
            'DeepLinkService: cleaned ${expired.docs.length} expired links');
      }
    } catch (e) {
      debugPrint('DeepLinkService._cleanupExpiredLinks skipped: $e');
    }
  }

  /// Cancels native link listener.
  void dispose() {
    _linkSub?.cancel();
    _linkSub = null;
  }
}
