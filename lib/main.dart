import 'package:flutter/material.dart';
import 'package:fede_apps_core/fede_apps_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'l10n/l10n.dart';
import 'providers/tone_generator_provider.dart';
import 'providers/session_provider.dart';
import 'providers/settings_provider.dart';
import 'screens/tone_generator_screen.dart';
import 'services/deep_link_service.dart';
import 'services/tone_sync_adapter.dart';
import 'widgets/disclaimer_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Capture the shared link (?share=) BEFORE runApp: it is processed once the
  // main screen is shown (after the safety disclaimer).
  await DeepLinkService().captureInitialLink();
  // Local usage metrics (fede_apps_core). Never blocks startup.
  try {
    await UsageTracker.instance.init();
  } catch (e) {
    debugPrint('UsageTracker init failed: $e');
  }

  // The same provider instances the UI uses (the sync adapter writes into
  // them).
  final tone = ToneGeneratorProvider()..init();
  final sessions = SessionProvider();

  // Account + library sync (fede_apps_core). Without an account it does
  // nothing, and it never blocks startup.
  try {
    // Web restores the Firebase session asynchronously: wait for it (briefly)
    // so the tombstone purge on load knows whether there is an account.
    await FirebaseAuth.instance
        .authStateChanges()
        .first
        .timeout(const Duration(seconds: 3));
  } catch (_) {}
  try {
    await LibrarySync.instance
        .configure(ToneSyncAdapter(sessions: sessions, tone: tone));
  } catch (e) {
    debugPrint('LibrarySync configure failed: $e');
  }
  // After configure: the purge of old tombstones asks LibrarySync.
  sessions.loadSessions();

  runApp(ToneGeneratorApp(tone: tone, sessions: sessions));
}

class ToneGeneratorApp extends StatelessWidget {
  const ToneGeneratorApp({
    super.key,
    required this.tone,
    required this.sessions,
  });

  final ToneGeneratorProvider tone;
  final SessionProvider sessions;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider.value(value: tone),
        ChangeNotifierProvider.value(value: sessions),
      ],
      child: Builder(
        builder: (context) {
          final locale =
              context.select<SettingsProvider, Locale?>((s) => s.locale);
          return MaterialApp(
            onGenerateTitle: (context) => context.l10n.appTitle,
            locale: locale,
            supportedLocales: kSupportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            localeListResolutionCallback: (deviceLocales, _) =>
                resolveAppLocale(deviceLocales),
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF0D0D1A),
              colorScheme: const ColorScheme.dark(
                primary: Color(0xFF6C63FF),
                secondary: Color(0xFF00D2FF),
                surface: Color(0xFF1A1A2E),
              ),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1A1A2E),
                elevation: 0,
              ),
              useMaterial3: true,
            ),
            builder: (context, child) {
              // Keep the context-free accessor in sync with the active locale.
              L10n.current = context.l10n;
              return child!;
            },
            home: const DisclaimerGate(child: ToneGeneratorScreen()),
          );
        },
      ),
    );
  }
}
