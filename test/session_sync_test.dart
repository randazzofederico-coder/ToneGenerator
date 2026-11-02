import 'dart:convert';

import 'package:fede_apps_core/fede_apps_core.dart'
    show DeviceIdentity, SyncFields;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tone_generator/models/tone_session.dart';
import 'package:tone_generator/providers/session_provider.dart';
import 'package:tone_generator/services/deep_link_service.dart';
import 'package:tone_generator/services/share_import_service.dart';

const _key = 'tone_sessions';

Map<String, dynamic> _oldJson(String id, String name,
        {String updatedAt = '2025-01-01T10:00:00.000'}) =>
    {
      'id': id,
      'name': name,
      'channels': [
        {'f': 440.0, 'w': 0, 'v': 0.5}
      ],
      'masterVol': 0.7,
      'createdAt': '2025-01-01T10:00:00.000',
      'updatedAt': updatedAt,
    };

ToneSession _sample({String id = 's1', String name = 'Uno'}) => ToneSession(
      id: id,
      name: name,
      channels: const [
        {'f': 440.0, 'w': 0, 'v': 0.5}
      ],
      masterVolume: 0.8,
      createdAt: DateTime(2025),
      updatedAt: DateTime(2025),
    );

Future<List<dynamic>> _stored() async {
  final prefs = await SharedPreferences.getInstance();
  return jsonDecode(prefs.getString(_key)!) as List<dynamic>;
}

void main() {
  late String deviceId;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DeviceIdentity.debugReset();
    deviceId = await DeviceIdentity.ensure();
  });

  group('ToneSession sync fields', () {
    test('old JSON (no sync keys) reads as rev 1, not deleted', () {
      final s = ToneSession.fromJson(_oldJson('a', 'Vieja'));
      expect(s.rev, 1);
      expect(s.deleted, isFalse);
      expect(s.deletedAt, isNull);
      expect(s.device, isNull);
      expect(s.name, 'Vieja');
      expect(s.masterVolume, 0.7);
    });

    test('round trip keeps sync fields and existing keys', () {
      final t = _sample().tombstoned(now: DateTime(2026, 3, 1), device: 'd1');
      final json = t.toJson();
      for (final k in [
        'id', 'name', 'channels', 'masterVol', 'createdAt', 'updatedAt'
      ]) {
        expect(json.containsKey(k), isTrue, reason: k);
      }
      final back = ToneSession.fromJson(json);
      expect(back.rev, 2);
      expect(back.deleted, isTrue);
      expect(back.deletedAt, DateTime(2026, 3, 1));
      expect(back.device, 'd1');
    });

    test('share JSON carries no sync fields', () {
      final json = _sample()
          .tombstoned(now: DateTime(2026), device: 'd1')
          .toJson(includeSync: false);
      for (final k in [
        SyncFields.rev,
        SyncFields.deleted,
        SyncFields.deletedAt,
        SyncFields.device
      ]) {
        expect(json.containsKey(k), isFalse, reason: k);
      }
    });
  });

  group('SessionProvider sync', () {
    test('migrates old library JSON', () async {
      SharedPreferences.setMockInitialValues({
        _key: jsonEncode([_oldJson('a', 'A'), _oldJson('b', 'B')]),
      });
      final lib = SessionProvider();
      await lib.loadSessions();
      expect(lib.sessions.length, 2);
      expect(lib.sessions.every((s) => s.rev == 1 && !s.deleted), isTrue);
    });

    test('create = rev 1; overwrite and rename bump rev', () async {
      final lib = SessionProvider();
      await lib.loadSessions();
      var t = DateTime(2026, 1, 1);
      lib.clock = () => t;

      final created = await lib.saveSession(_sample());
      expect(created.rev, 1);
      expect(created.device, deviceId);
      expect(created.updatedAt, DateTime(2026, 1, 1));

      t = DateTime(2026, 1, 2);
      final saved = await lib.saveSession(
          _sample().copyWith(channels: const [], masterVolume: 0.3));
      expect(saved.rev, 2);
      expect(saved.updatedAt, DateTime(2026, 1, 2));

      t = DateTime(2026, 1, 3);
      final renamed = await lib.renameSession('s1', 'Nuevo');
      expect(renamed!.rev, 3);
      expect(renamed.name, 'Nuevo');
      expect(renamed.updatedAt, DateTime(2026, 1, 3));
      expect(renamed.device, deviceId);

      final stored = await _stored();
      expect(stored.single[SyncFields.rev], 3);
      expect(stored.single[SyncFields.device], deviceId);
    });

    test('delete leaves a hidden tombstone', () async {
      final lib = SessionProvider();
      await lib.loadSessions();
      lib.clock = () => DateTime(2026, 2, 1);
      await lib.saveSession(_sample());
      await lib.saveSession(_sample(id: 's2', name: 'Dos'));

      final removed = await lib.deleteSession('s1');
      expect(removed!.deleted, isFalse);
      expect(lib.sessions.map((s) => s.id), ['s2']);
      expect(lib.getSessionById('s1'), isNull);
      expect(lib.nameExists('Uno'), isFalse);
      expect(await lib.deleteSession('s1'), isNull);
      expect(await lib.renameSession('s1', 'X'), isNull);
      expect(await lib.duplicateSession('s1'), isNull);

      final tomb = lib.allItems.firstWhere((s) => s.id == 's1');
      expect(tomb.deleted, isTrue);
      expect(tomb.rev, 2);
      expect(tomb.deletedAt, DateTime(2026, 2, 1));
      expect(tomb.device, deviceId);
      expect((await _stored()).length, 2);

      // Reload: still hidden.
      final again = SessionProvider()..clock = () => DateTime(2026, 2, 2);
      await again.loadSessions();
      expect(again.sessions.map((s) => s.id), ['s2']);
      expect(again.allItems.length, 2);
    });

    test('undo of delete revives with a newer rev', () async {
      final lib = SessionProvider();
      await lib.loadSessions();
      await lib.saveSession(_sample());
      final removed = await lib.deleteSession('s1');
      final revived = await lib.saveSession(removed!);
      expect(revived.rev, 3);
      expect(revived.deleted, isFalse);
      expect(revived.deletedAt, isNull);
      expect(lib.sessions.single.id, 's1');
    });

    test('tombstones are purged on load after 30 days', () async {
      final old = _sample(id: 'old')
          .tombstoned(now: DateTime(2026, 1, 1), device: 'x')
          .toJson();
      final recent = _sample(id: 'recent')
          .tombstoned(now: DateTime(2026, 1, 20), device: 'x')
          .toJson();
      final live = _sample(id: 'live').toJson();
      SharedPreferences.setMockInitialValues({
        _key: jsonEncode([old, recent, live]),
      });

      final lib = SessionProvider()..clock = () => DateTime(2026, 1, 31);
      await lib.loadSessions();
      expect(lib.allItems.map((s) => s.id), ['recent', 'live']);
      expect(lib.sessions.map((s) => s.id), ['live']);
      expect((await _stored()).map((m) => m['id']), ['recent', 'live']);
    });

    test('duplicate gets a new id and rev 1', () async {
      final lib = SessionProvider();
      await lib.loadSessions();
      await lib.saveSession(_sample());
      await lib.renameSession('s1', 'Uno');
      final copy = await lib.duplicateSession('s1');
      expect(copy!.id, isNot('s1'));
      expect(copy.rev, 1);
      expect(copy.deleted, isFalse);
      expect(copy.device, deviceId);
      expect(lib.getSessionById('s1')!.rev, 2);
    });

    test('name of a deleted session can be reused', () async {
      final lib = SessionProvider();
      await lib.loadSessions();
      await lib.saveSession(_sample());
      await lib.deleteSession('s1');
      expect(lib.nameExists('Uno'), isFalse);
    });
  });

  group('Import with tombstones', () {
    SharedBundle bundleOf(ToneSession s) =>
        SharedBundle(shareId: 'abc123defg', name: s.name, data: s.toJson());

    test('import is rev 1 and ignores shared sync fields', () async {
      final lib = SessionProvider();
      await lib.loadSessions();
      final shared = ToneSession.fromJson({
        ..._sample(id: 'orig').toJson(),
        SyncFields.rev: 9,
        SyncFields.deleted: true,
        SyncFields.device: 'other',
      });
      final r = await ShareImportService(sessions: lib).import(bundleOf(shared));
      expect(r.session.rev, 1);
      expect(r.session.deleted, isFalse);
      expect(r.session.device, deviceId);
      expect(lib.sessions.single.id, r.session.id);
    });

    test('re-importing a deleted import revives the tombstone', () async {
      final lib = SessionProvider();
      await lib.loadSessions();
      final service = ShareImportService(sessions: lib);
      final first = await service.import(bundleOf(_sample(id: 'orig')));
      await lib.deleteSession(first.session.id);
      final again = await service.import(bundleOf(_sample(id: 'orig')));
      expect(again.alreadyInLibrary, isFalse);
      expect(again.session.id, first.session.id);
      expect(again.session.rev, 3);
      expect(lib.allItems.length, 1);
    });
  });
}
