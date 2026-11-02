import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/l10n.dart';
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

    final l10n = context.l10n;
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
              Text(
                l10n.disclaimerTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Warning text (in the active language)
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
                    _paragraph(l10n.disclaimerParagraph1, bold: true),
                    const SizedBox(height: 16),
                    _paragraph(l10n.disclaimerParagraph2),
                    const SizedBox(height: 16),
                    _paragraph(l10n.disclaimerParagraph3),
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
                  child: Text(
                    l10n.disclaimerAccept,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Language can be changed before accepting.
              _LanguageToggle(),
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

/// Compact "Español · English" switch shown under the accept button.
class _LanguageToggle extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    final current = Localizations.localeOf(context).languageCode;

    Widget option(String code, String label) {
      final active = current == code;
      return TextButton(
        onPressed: active ? null : () => settings.setLanguage(code),
        style: TextButton.styleFrom(
          foregroundColor: Colors.white.withValues(alpha: 0.5),
          disabledForegroundColor: const Color(0xFF6C63FF),
        ),
        child: Text(label,
            style: TextStyle(
                fontWeight: active ? FontWeight.w700 : FontWeight.w400)),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.translate_rounded,
            size: 16, color: Colors.white.withValues(alpha: 0.3)),
        const SizedBox(width: 4),
        option('es', context.l10n.languageSpanish),
        Text('·', style: TextStyle(color: Colors.white.withValues(alpha: 0.3))),
        option('en', context.l10n.languageEnglish),
      ],
    );
  }
}
