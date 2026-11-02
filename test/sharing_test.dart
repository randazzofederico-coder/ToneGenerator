import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tone_generator/l10n/l10n.dart';
import 'package:tone_generator/models/channel_model.dart';
import 'package:tone_generator/models/tone_session.dart';
import 'package:tone_generator/providers/session_provider.dart';
import 'package:tone_generator/services/deep_link_service.dart';
import 'package:tone_generator/services/share_import_service.dart';

ToneSession _sample({String id = 'orig-1', String name = 'Afinación'}) {
  return ToneSession.capture(
    id: id,
    name: name,
    channels: [
      ToneChannel(id: 'a', frequency: 440, volume: 0.3, noteName: 'A4'),
      ToneChannel(
          id: 'b',
          frequency: 432,
          waveform: Waveform.square,
          pan: -0.5,
          muted: true,
          noteName: 'A4'),
    ],
    masterVolume: 0.7,
  );
}

void main() {
  // Context-free strings (default names, summaries) in Spanish, as asserted below.
  setUpAll(() => L10n.current = lookupAppLocalizations(const Locale('es')));

  group('ToneChannel.fromJson', () {
    test('clamps out-of-range and wrong-typed values', () {
      final ch = ToneChannel.fromJson('x', {
        'f': 999999,
        'w': 42,
        'v': 5,
        'p': -9,
        'm': 'yes',
        'n': 'way too long note name',
      });
      expect(ch.frequency, ToneChannel.maxFrequency);
      expect(ch.waveform, Waveform.sine);
      expect(ch.volume, 1.0);
      expect(ch.pan, -1.0);
      expect(ch.muted, isFalse);
      expect(ch.noteName, isNot('way too long note name'));
    });

    test('accepts doubles where ints are expected (web JSON)', () {
      final ch = ToneChannel.fromJson('x', {'f': 100, 'w': 2.0});
      expect(ch.frequency, 100.0);
      expect(ch.waveform, Waveform.triangle);
    });
  });

  group('ToneSession', () {
    test('JSON round trip keeps channels and master volume', () {
      final s = _sample();
      final back = ToneSession.fromJson(s.toJson());
      expect(back.id, s.id);
      expect(back.name, s.name);
      expect(back.masterVolume, 0.7);
      expect(back.channels, s.channels);
      final chans = back.buildChannels();
      expect(chans[1].waveform, Waveform.square);
      expect(chans[1].muted, isTrue);
    });

    test('defensive parse of hostile data', () {
      final s = ToneSession.fromJson({
        'name': 'x' * 500,
        'masterVol': 12,
        'channels': List.generate(100, (_) => {'f': 440}),
      });
      expect(s.name.length, ToneSession.maxNameLength);
      expect(s.masterVolume, 1.0);
      expect(s.channels.length, ToneSession.maxChannels);
      expect(s.id, isNotEmpty);
    });

    test('empty / garbage input still yields a valid session', () {
      final s = ToneSession.fromJson({'channels': 'nope', 'name': 3});
      expect(s.name, 'Sesión');
      expect(s.channels, isEmpty);
    });
  });

  group('DeepLinkService.contentId', () {
    test('stable, 10 chars base36, ignores timestamps', () {
      final s = _sample();
      final a = DeepLinkService.contentId('uid', {'data': s.toJson()});
      final later = s.copyWith(updatedAt: DateTime(2030));
      final b = DeepLinkService.contentId('uid', {'data': later.toJson()});
      expect(a, b);
      expect(a, matches(RegExp(r'^[a-z0-9]{10}$')));
    });

    test('changes with content or author', () {
      final s = _sample();
      final base = DeepLinkService.contentId('uid', {'data': s.toJson()});
      final other = DeepLinkService.contentId(
          'uid', {'data': s.copyWith(masterVolume: 0.1).toJson()});
      final otherUser =
          DeepLinkService.contentId('uid2', {'data': s.toJson()});
      expect(other, isNot(base));
      expect(otherUser, isNot(base));
    });

    test('slugify', () {
      expect(DeepLinkService.slugify('Afinación 432 Hz ñ!'),
          'afinacion-432-hz-n');
    });
  });

  group('ShareImportService', () {
    late SessionProvider library;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      library = SessionProvider();
      await library.loadSessions();
    });

    SharedBundle bundleOf(ToneSession s, {String shareId = 'abc123defg'}) =>
        SharedBundle(shareId: shareId, name: s.name, data: s.toJson());

    test('importing the same link twice does not duplicate', () async {
      final service = ShareImportService(sessions: library);
      final first = await service.import(bundleOf(_sample()));
      final second = await service.import(bundleOf(_sample()));

      expect(first.alreadyInLibrary, isFalse);
      expect(second.alreadyInLibrary, isTrue);
      expect(second.session.id, first.session.id);
      expect(library.sessions.length, 1);
      expect(first.session.id,
          ShareImportService.derivedId('abc123defg', 'orig-1'));
    });

    test('own session (same original id) is reused', () async {
      final own = _sample();
      await library.saveSession(own);
      final r = await ShareImportService(sessions: library)
          .import(bundleOf(own));
      expect(r.alreadyInLibrary, isTrue);
      expect(r.session.id, own.id);
      expect(library.sessions.length, 1);
    });

    test('name clash gets a suffix', () async {
      await library.saveSession(_sample(id: 'mine'));
      final r = await ShareImportService(sessions: library)
          .import(bundleOf(_sample(id: 'theirs')));
      expect(r.session.name, 'Afinación (2)');
      expect(library.sessions.length, 2);
    });

    test('deleted import is re-created on reopen', () async {
      final service = ShareImportService(sessions: library);
      final first = await service.import(bundleOf(_sample()));
      await library.deleteSession(first.session.id);
      final again = await service.import(bundleOf(_sample()));
      expect(again.alreadyInLibrary, isFalse);
      expect(again.session.id, first.session.id);
    });
  });
}
