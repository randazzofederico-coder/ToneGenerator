import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';

import 'firebase_options.dart';
import 'providers/tone_generator_provider.dart';
import 'providers/settings_provider.dart';
import 'auth/auth_repository.dart';
import 'screens/tone_generator_screen.dart';
import 'widgets/disclaimer_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await AuthRepository.instance.init();
  runApp(const ToneGeneratorApp());
}

class ToneGeneratorApp extends StatelessWidget {
  const ToneGeneratorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => ToneGeneratorProvider()..init()),
      ],
      child: MaterialApp(
        title: 'Tone Generator',
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
        home: const DisclaimerGate(child: ToneGeneratorScreen()),
      ),
    );
  }
}

