import 'dart:convert';

import 'package:fede_apps_core/fede_apps_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tone_generator/l10n/l10n.dart';
import 'package:tone_generator/models/tone_session.dart';
import 'package:tone_generator/providers/session_provider.dart';
import 'package:tone_generator/providers/tone_generator_provider.dart';
import 'package:tone_generator/services/tone_sync_adapter.dart';

/// LibrarySync that counts the local-change notifications.
class CountingSync extends LibrarySync {
  CountingSync({
    required super.store,
    required super.user,
    required String name,
  }) : super(
          deviceId: name,
          listenLifecycle: false,
          prefsPrefix: 'fac_sync_${name}_',
        );

  int notified = 0;

  @override
  void notifyLocalChange() {
    notified++;
    super.notifyLocalChange();
  }
}

const _user = FedeUser(uid: 'u1', email: 'fede@example.com');

ToneSession _session(String id, String name, {double freq = 440}) =>
    ToneSession(
      id: id,
      name: name,
      channels: [
        {'f': freq, 'w': 0, 'v': 0.5}
      ],
      masterVolume: 0.8,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );

Future<void> _settle() async {
  for (var i = 0; i < 30; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// One installation: library + working state + sync engine.
class _Device {
  _Device(this.name, InMemoryRemoteStore store, ValueListenable<FedeUser?> user)
      : sync = CountingSync(store: store, user: user, name: name) {
    library = SessionProvider(sync: sync);
    adapter = ToneSyncAdapter(
      sessions: library,
      tone: tone,
      toneReady: Future<void>.value(),
    );
  }

  final String name;
  final CountingSync sync;
  late final SessionProvider library;
  final tone = ToneGeneratorProvider(); // no init(): audio engine untouched
  late final ToneSyncAdapter adapter;

  Future<void> start() async {
    await library.loadSessions();
    await sync.configure(adapter);
    await _settle();
  }

  Future<void> syncNow() async {
    await sync.syncNow(force: true);
    await _settle();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late InMemoryRemoteStore store;
  late ValueNotifier<FedeUser?> user;
  late _Device a;
  late _Device b;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    DeviceIdentity.debugReset();
    await DeviceIdentity.ensure();
    L10n.current = lookupAppLocalizations(const Locale('es'));
    store = InMemoryRemoteStore();
    user = ValueNotifier(_user);
    a = _Device('A', store, user);
    b = _Device('B', store, user);
    await a.start();
    await b.start();
  });

  tearDown(() {
    a.sync.dispose();
    b.sync.dispose();
  });

  Map<String, dynamic> remoteSessions() =>
      Map<String, dynamic>.from(
          store.collections('u1', 'tonegenerator')!['sessions'] as Map);

  test('adapter contract: appId and collection', () {
    expect(a.adapter.appId, 'tonegenerator');
    expect(a.adapter.collections, ['sessions']);
  });

  test('local save notifies the engine and the sync uploads it', () async {
    final before = a.sync.notified;
    await a.library.saveSession(_session('s1', 'Uno'));
    expect(a.sync.notified, before + 1);

    await a.syncNow();
    final remote = remoteSessions();
    expect(remote.keys, ['s1']);
    expect((remote['s1'] as Map)['rev'], 1);

    // Rename, duplicate, delete and undo also notify.
    await a.library.renameSession('s1', 'Uno bis');
    final copy = await a.library.duplicateSession('s1');
    final removed = await a.library.deleteSession(copy!.id);
    await a.library.restoreSnapshot(removed!);
    expect(a.sync.notified, before + 5);
  });

  test('remote change → applyRemote updates the library without rev bump',
      () async {
    await a.library.saveSession(_session('s1', 'Uno'));
    await a.syncNow();
    await b.syncNow();
    expect(b.library.getSessionById('s1')!.name, 'Uno');

    await b.library.renameSession('s1', 'Renombrada en B');
    final edited = b.library.getSessionById('s1')!;
    expect(edited.rev, 2);
    await b.syncNow();

    final notifiedBefore = a.sync.notified;
    var uiNotified = 0;
    a.library.addListener(() => uiNotified++);
    await a.syncNow();

    final got = a.library.getSessionById('s1')!;
    expect(got.name, 'Renombrada en B');
    expect(got.rev, 2, reason: 'applyRemote must not bump rev');
    expect(got.updatedAt, edited.updatedAt);
    expect(uiNotified, greaterThan(0));
    expect(a.sync.notified, notifiedBefore,
        reason: 'applyRemote is not a local change');

    // Converged: another round writes nothing.
    final writes = store.writes;
    await a.syncNow();
    await b.syncNow();
    expect(store.writes, writes);
  });

  test('remote delete hides the session (and detaches it if open)', () async {
    await a.library.saveSession(_session('s1', 'Uno'));
    await a.syncNow();
    await b.syncNow();
    a.tone.loadSession(a.library.getSessionById('s1')!);
    expect(a.tone.activeSessionId, 's1');

    await b.library.deleteSession('s1');
    await b.syncNow();
    await a.syncNow();

    expect(a.library.getSessionById('s1'), isNull);
    expect(a.library.sessions, isEmpty);
    final tomb = a.library.allItems.single;
    expect(tomb.deleted, isTrue);
    expect(tomb.rev, 2);
    // Like a local delete: same channels, now an unsaved session.
    expect(a.tone.activeSessionId, isNull);
    expect(a.tone.channels, hasLength(1));
    expect(a.tone.activeSessionName, 'Uno');
  });

  test('open session updated remotely: clean → reloaded, dirty → kept',
      () async {
    await a.library.saveSession(_session('s1', 'Uno', freq: 440));
    await a.library.saveSession(_session('s2', 'Dos', freq: 220));
    await a.syncNow();
    await b.syncNow();

    // Clean working state: the new version is loaded.
    a.tone.loadSession(a.library.getSessionById('s1')!);
    await b.library.saveSession(_session('s1', 'Uno', freq: 880));
    await b.syncNow();
    await a.syncNow();
    expect(a.tone.channels.single.frequency, 880);
    expect(a.tone.isDirty, isFalse);

    // Unsaved changes: channels untouched, reference + name move on.
    a.tone.loadSession(a.library.getSessionById('s2')!);
    a.tone.addChannel(freq: 100);
    await b.library.renameSession('s2', 'Dos (B)');
    await b.syncNow();
    await a.syncNow();
    expect(a.tone.channels.map((c) => c.frequency), [220, 100]);
    expect(a.tone.activeSessionId, 's2');
    expect(a.tone.displayName, 'Dos (B)');
    expect(a.tone.isDirty, isTrue);
  });

  test('conflict creates an "(otro dispositivo)" copy on both devices',
      () async {
    await a.library.saveSession(_session('s1', 'Base'));
    await a.syncNow();
    await b.syncNow();

    await a.library.saveSession(_session('s1', 'Base', freq: 300)); // rev 2
    await b.library.saveSession(_session('s1', 'Base', freq: 500)); // rev 2
    await b.library.saveSession(_session('s1', 'Base', freq: 600)); // rev 3

    await b.syncNow();
    await a.syncNow(); // conflict: B (rev 3) wins, A's version → copy
    await b.syncNow();

    List<String> names(SessionProvider p) =>
        p.sessions.map((s) => s.name).toList()..sort();
    expect(names(a.library), ['Base', 'Base (otro dispositivo)']);
    expect(names(b.library), names(a.library));

    final winner = a.library.getSessionById('s1')!;
    expect(winner.channels.single['f'], 600);
    final copy =
        a.library.sessions.firstWhere((s) => s.name.endsWith('dispositivo)'));
    expect(copy.id, isNot('s1'));
    expect(copy.channels.single['f'], 300);
    expect(copy.rev, 1);
    expect(b.library.getSessionById(copy.id)!.channels.single['f'], 300);
  });

  test('conflict copy name follows the app language', () {
    L10n.current = lookupAppLocalizations(const Locale('en'));
    final copy = a.adapter
        .conflictCopy('sessions', _session('s1', 'Base').toJson());
    expect(copy['name'], 'Base (other device)');
    expect(copy['id'], isNot('s1'));
    expect(copy['channels'], isNotEmpty);
  });

  test('purge on load waits until the tombstone is synced', () async {
    final old = DateTime.now().subtract(const Duration(days: 40));
    final tomb = _session('t1', 'Vieja').tombstoned(now: old, device: 'x');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('tone_sessions', jsonEncode([tomb.toJson()]));

    // Signed in, never synced → kept.
    final c = _Device('C', store, user);
    await c.library.loadSessions();
    expect(c.library.allItems.map((s) => s.id), ['t1']);
    c.sync.dispose();

    // Without account → purged.
    final d = _Device('D', store, ValueNotifier<FedeUser?>(null));
    await d.sync.configure(d.adapter);
    await d.library.loadSessions();
    expect(d.library.allItems, isEmpty);
    d.sync.dispose();
  });
}
