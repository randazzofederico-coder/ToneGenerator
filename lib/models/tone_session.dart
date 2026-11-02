import 'package:fede_apps_core/fede_apps_core.dart' show SyncFields;
import 'package:uuid/uuid.dart';

import '../l10n/l10n.dart';
import 'channel_model.dart';

/// A saved Tone Generator setup: its channels and the master volume.
///
/// Channels are stored as the compact [ToneChannel] JSON (`f, w, v, p, m, s,
/// i, n`) without runtime IDs: every time a session is loaded the channels get
/// fresh IDs for the audio engine.
class ToneSession {
  /// Maximum channels accepted from stored/shared data.
  static const int maxChannels = 16;
  static const int maxNameLength = 80;

  final String id;
  final String name;
  final List<Map<String, dynamic>> channels;
  final double masterVolume;
  final DateTime createdAt;
  final DateTime updatedAt;

  // ── Sync fields (contract: fede_apps_core `SyncFields`) ──
  /// Revision: 1 on creation, +1 on every change (save, rename, delete...).
  final int rev;

  /// Tombstone: deleted from the library but kept (until purged) so a future
  /// sync can propagate the deletion. Never shown in the UI.
  final bool deleted;
  final DateTime? deletedAt;

  /// `DeviceIdentity.id` of the installation that made the last change.
  final String? device;

  const ToneSession({
    required this.id,
    required this.name,
    required this.channels,
    required this.masterVolume,
    required this.createdAt,
    required this.updatedAt,
    this.rev = 1,
    this.deleted = false,
    this.deletedAt,
    this.device,
  });

  static const _uuid = Uuid();

  /// New session with a random ID, captured from live channels.
  factory ToneSession.capture({
    String? id,
    required String name,
    required List<ToneChannel> channels,
    required double masterVolume,
    DateTime? createdAt,
  }) {
    final now = DateTime.now();
    return ToneSession(
      id: id ?? _uuid.v4(),
      name: name,
      channels: channels.map((c) => c.toJson()).toList(),
      masterVolume: masterVolume,
      createdAt: createdAt ?? now,
      updatedAt: now,
    );
  }

  /// Builds runtime channels (with fresh IDs) from the stored JSON.
  List<ToneChannel> buildChannels() =>
      channels.map((json) => ToneChannel.fromJson(_uuid.v4(), json)).toList();

  /// Waveform names used by the channels (for summaries), in order, unique.
  List<String> get waveformNames {
    final seen = <String>{};
    for (final ch in buildChannels()) {
      seen.add(ch.waveform.name);
    }
    return seen.toList();
  }

  /// Short human description, e.g. "3 canales" / "3 channels".
  String get summaryLabel => L10n.current.channelCount(channels.length);

  /// JSON for storage. With [includeSync] false (shared links) the sync
  /// fields (`rev`, `deleted`, `deletedAt`, `dev`) are left out.
  Map<String, dynamic> toJson({bool includeSync = true}) {
    final json = <String, dynamic>{
      'id': id,
      'name': name,
      'channels': channels,
      'masterVol': masterVolume,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
    if (includeSync) {
      SyncFields.write(json,
          rev: rev, deleted: deleted, deletedAt: deletedAt, device: device);
    }
    return json;
  }

  /// Defensive parser: the JSON may come from a shared link.
  factory ToneSession.fromJson(Map<String, dynamic> json) {
    final rawChannels = json['channels'];
    final channels = <Map<String, dynamic>>[];
    if (rawChannels is List) {
      for (final c in rawChannels.take(maxChannels)) {
        if (c is Map) {
          // Normalise through ToneChannel to drop unknown keys / clamp values.
          channels.add(
              ToneChannel.fromJson('', Map<String, dynamic>.from(c)).toJson());
        }
      }
    }

    final rawName = json['name'];
    var name = (rawName is String) ? rawName.trim() : '';
    if (name.isEmpty) name = L10n.current.sessionDefaultName;
    if (name.length > maxNameLength) name = name.substring(0, maxNameLength);

    final vol = json['masterVol'];
    var master = (vol is num) ? vol.toDouble() : 0.8;
    if (master.isNaN || master.isInfinite) master = 0.8;

    DateTime date(Object? v) =>
        (v is String ? DateTime.tryParse(v) : null) ?? DateTime.now();

    final id = json['id'];
    return ToneSession(
      id: (id is String && id.isNotEmpty) ? id : _uuid.v4(),
      name: name,
      channels: channels,
      masterVolume: master.clamp(0.0, 1.0).toDouble(),
      createdAt: date(json['createdAt']),
      updatedAt: date(json['updatedAt']),
      // Old JSON (without these keys) → rev 1, not deleted.
      rev: SyncFields.readRev(json),
      deleted: SyncFields.readDeleted(json),
      deletedAt: SyncFields.readDeletedAt(json),
      device: SyncFields.readDevice(json),
    );
  }

  /// Copies data fields; sync fields are kept as they are (use [revised] /
  /// [tombstoned] to change them).
  ToneSession copyWith({
    String? id,
    String? name,
    List<Map<String, dynamic>>? channels,
    double? masterVolume,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ToneSession(
      id: id ?? this.id,
      name: name ?? this.name,
      channels: channels ?? this.channels,
      masterVolume: masterVolume ?? this.masterVolume,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rev: rev,
      deleted: deleted,
      deletedAt: deletedAt,
      device: device,
    );
  }

  /// Same data stamped as a live revision: [rev], `updatedAt = now`,
  /// [device], not deleted.
  ToneSession revised({
    required int rev,
    required DateTime now,
    String? device,
  }) {
    return ToneSession(
      id: id,
      name: name,
      channels: channels,
      masterVolume: masterVolume,
      createdAt: createdAt,
      updatedAt: now,
      rev: rev,
      device: device,
    );
  }

  /// Tombstone of this session: `rev + 1`, `deleted`, `deletedAt = now`.
  ToneSession tombstoned({required DateTime now, String? device}) {
    return ToneSession(
      id: id,
      name: name,
      channels: channels,
      masterVolume: masterVolume,
      createdAt: createdAt,
      updatedAt: now,
      rev: rev + 1,
      deleted: true,
      deletedAt: now,
      device: device,
    );
  }
}
