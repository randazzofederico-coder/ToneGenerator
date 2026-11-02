import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

/// Shows a safety disclaimer on first launch.
/// User must accept before using the app.
class DisclaimerGate extends StatelessWidget {
  final Widget child;

  const DisclaimerGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final accepted = context.select<SettingsProvider, bool>(
      (p) => p.disclaimerAccepted,
    );

    if (accepted) return child;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE94560).withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE94560),
                  size: 36,
                ),
              ),
              const SizedBox(height: 20),

              // Title
              const Text(
                'Advertencia de Seguridad',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Safety Warning',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 24),

              // Warning text
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.04),
                  border: Border.all(
                    color: const Color(0xFFE94560).withValues(alpha: 0.15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _paragraph(
                      '⚠️  Podés dañar tu audición o tus parlantes si reproducís tonos a volúmenes extremos.',
                      bold: true,
                    ),
                    const SizedBox(height: 16),
                    _paragraph(
                      'Las personas no escuchan bien los sonidos por debajo de 20 Hz ni por encima de '
                      '10.000 Hz. Si subís el volumen del dispositivo para compensar, podrías exponerte '
                      'a niveles de sonido dañinos y someter a tus parlantes a corrientes perjudiciales.',
                    ),
                    const SizedBox(height: 16),
                    _paragraph(
                      'Para ser prudente, encontrá el nivel de volumen que te permita escuchar un tono '
                      'de 1.000 Hz sin molestias y no te alejes mucho de ese nivel, aunque no escuches '
                      'mucho — especialmente en el rango agudo, donde tu audición es más frágil.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // English version (smaller)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white.withValues(alpha: 0.02),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _paragraph(
                      'You can damage your hearing or your speakers if you play tones at extreme volumes.',
                      bold: true,
                      small: true,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 12),
                    _paragraph(
                      "People can't hear sounds < 20 Hz and > 10,000 Hz very well. If you turn up "
                      'the volume on your device to compensate, you could expose yourself to harmful '
                      'sound levels and your speakers to harmful currents.',
                      small: true,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
                    _paragraph(
                      'To be safe, note the volume level that allows you to listen to a 1,000 Hz '
                      'tone without discomfort and do not stray too far above this level, even if '
                      'you can\'t hear much — especially in the high range, where your hearing is '
                      'the most fragile.',
                      small: true,
                      color: Colors.white.withValues(alpha: 0.4),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // Accept button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    context.read<SettingsProvider>().acceptDisclaimer();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6C63FF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Entiendo y acepto',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _paragraph(
    String text, {
    bool bold = false,
    bool small = false,
    Color? color,
  }) {
    return Text(
      text,
      style: TextStyle(
        color: color ?? Colors.white.withValues(alpha: 0.7),
        fontSize: small ? 12 : 14,
        fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
        height: 1.5,
      ),
    );
  }
}
