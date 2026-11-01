import 'package:uuid/uuid.dart';

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

  const ToneSession({
    required this.id,
    required this.name,
    required this.channels,
    required this.masterVolume,
    required this.createdAt,
    required this.updatedAt,
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

  /// Short human description, e.g. "3 canales".
  String get summaryLabel =>
      channels.length == 1 ? '1 canal' : '${channels.length} canales';

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'channels': channels,
        'masterVol': masterVolume,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

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
    if (name.isEmpty) name = 'Sesión';
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
    );
  }

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
    );
  }
}
