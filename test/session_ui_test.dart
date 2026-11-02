import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:tone_generator/l10n/l10n.dart';
import 'package:tone_generator/providers/session_provider.dart';
import 'package:tone_generator/providers/tone_generator_provider.dart';
import 'package:tone_generator/services/session_actions.dart';

/// The provider is used without init(): the audio engine is not touched
/// (`isReady == false`) and the working state is not persisted.
void main() {
  group('ToneGeneratorProvider — remove / restore channel', () {
    test('undo puts the channel back at the same position', () {
      final tone = ToneGeneratorProvider();
      final a = tone.addChannel(freq: 100);
      final b = tone.addChannel(freq: 200);
      final c = tone.addChannel(freq: 300);

      final removed = tone.removeChannel(b)!;
      expect(tone.channels.map((ch) => ch.id), [a, c]);

      final ok = tone.restoreChannel(
          removed.channel, removed.index, removed.generation);
      expect(ok, isTrue);
      expect(tone.channels.map((ch) => ch.id), [a, b, c]);
      expect(tone.channels[1].frequency, 200);
      expect(tone.selectedChannelId, b);
    });

    test('undo twice does not duplicate', () {
      final tone = ToneGeneratorProvider();
      final a = tone.addChannel();
      final r = tone.removeChannel(a)!;
      expect(tone.restoreChannel(r.channel, r.index, r.generation), isTrue);
      expect(tone.restoreChannel(r.channel, r.index, r.generation), isFalse);
      expect(tone.channels.length, 1);
    });

    test('undo is ignored after loading another session', () {
      final tone = ToneGeneratorProvider();
      final a = tone.addChannel();
      final r = tone.removeChannel(a)!;
      tone.newSession();
      expect(tone.restoreChannel(r.channel, r.index, r.generation), isFalse);
      expect(tone.channels, isEmpty);
    });

    test('removing an unknown id returns null', () {
      expect(ToneGeneratorProvider().removeChannel('nope'), isNull);
    });

    test('dirty tracking: remove + undo returns to clean', () {
      final tone = ToneGeneratorProvider();
      tone.addChannel(freq: 440);
      final saved = tone.captureSession(id: 's1', name: 'Uno');
      tone.markSaved(saved);
      expect(tone.isDirty, isFalse);

      final r = tone.removeChannel(tone.channels.first.id)!;
      expect(tone.isDirty, isTrue);
      tone.restoreChannel(r.channel, r.index, r.generation);
      expect(tone.isDirty, isFalse);
    });
  });

  group('UI flows', () {
    late ToneGeneratorProvider tone;
    late SessionProvider library;

    // The library is created and loaded inside each testWidgets body: a
    // Completer created in setUp (real zone) never resumes under fake async.
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tone = ToneGeneratorProvider();
    });

    Future<void> loadLibrary() async {
      library = SessionProvider();
      await library.loadSessions();
    }

    Widget app(void Function(BuildContext) onPressed) => MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: tone),
            ChangeNotifierProvider.value(value: library),
          ],
          child: MaterialApp(
            locale: const Locale('es'),
            supportedLocales: kSupportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: Scaffold(
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => onPressed(context),
                    child: const Text('go'),
                  ),
                ),
              ),
            ),
          ),
        );

    testWidgets('snackbar with DESHACER hides by itself', (tester) async {
      await loadLibrary();
      await tester.pumpWidget(app((ctx) => showAppSnack(ctx, 'Guardada',
          actionLabel: 'DESHACER', onAction: () {})));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('DESHACER'), findsOneWidget);

      await tester.pump(const Duration(seconds: 6));
      await tester.pumpAndSettle();
      expect(find.text('Guardada'), findsNothing);
    });

    testWidgets('delete channel shows DESHACER and undo restores it',
        (tester) async {
      await loadLibrary();
      tone.addChannel(freq: 100);
      final id = tone.addChannel(freq: 200);
      await tester.pumpWidget(app((ctx) => removeChannelWithUndo(ctx, id)));

      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(tone.channels.length, 1);
      expect(find.text('Canal eliminado'), findsOneWidget);

      await tester.tap(find.text('DESHACER'));
      await tester.pumpAndSettle();
      expect(tone.channels.length, 2);
      expect(tone.channels[1].id, id);
    });

    testWidgets('tap-to-rename renames library entry and open session',
        (tester) async {
      await loadLibrary();
      tone.addChannel();
      final s = tone.captureSession(id: 's1', name: 'Vieja');
      await library.saveSession(s);
      tone.markSaved(s);

      await tester.pumpWidget(app((ctx) => renameCurrentSession(ctx)));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Renombrar sesión'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Nueva');
      await tester.tap(find.text('RENOMBRAR'));
      await tester.pumpAndSettle();

      expect(library.getSessionById('s1')!.name, 'Nueva');
      expect(tone.activeSessionName, 'Nueva');
      expect(tone.isDirty, isFalse);
    });

    testWidgets('tap on name of an unsaved session asks to save it',
        (tester) async {
      await loadLibrary();
      tone.addChannel();
      await tester.pumpWidget(app((ctx) => renameCurrentSession(ctx)));
      await tester.tap(find.text('go'));
      await tester.pumpAndSettle();
      expect(find.text('Guardar sesión como…'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Primera');
      await tester.tap(find.text('GUARDAR'));
      await tester.pumpAndSettle();
      expect(library.sessions.single.name, 'Primera');
      expect(tone.activeSessionId, library.sessions.single.id);
    });
  });
}
