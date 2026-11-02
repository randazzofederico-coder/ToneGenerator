import 'package:fede_apps_core/fede_apps_core.dart'
    show AccountSection, EcosystemPrompts, EcosystemSection, FedeApp;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/l10n.dart';
import '../providers/settings_provider.dart';

const _forumUrl = 'https://federicorandazzo.com.ar/foro/';
const _appsUrl = 'https://federicorandazzo.com.ar/apps/';

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
    // Quiet moment (entering Settings): maybe suggest the other apps.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Never on top of the safety disclaimer.
      if (!context.read<SettingsProvider>().disclaimerAccepted) return;
      EcosystemPrompts.maybeShowAppsPrompt(
        context,
        currentApp: FedeApp.toneGenerator,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Consumer<SettingsProvider>(
      builder: (context, settings, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              l10n.settingsTitle,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 20),
            ),
            centerTitle: true,
            backgroundColor: const Color(0xFF1A1A2E),
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            children: [
              // --- ACCOUNT (fede_apps_core: login + library sync) ---
              _SectionHeader(title: l10n.settingsAccountTitle),
              const SizedBox(height: 12),
              Material(
                color: const Color(0xFF1A1A2E),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: AccountSection(
                    hasLibrary: true,
                    showHeader: false,
                    iconColor: Color(0xFF6C63FF),
                    buttonColor: Color(0xFF6C63FF),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --- LANGUAGE ---
              _SectionHeader(title: l10n.settingsLanguageTitle),
              const SizedBox(height: 12),
              _Card(child: _LanguageSelector(settings: settings)),

              const SizedBox(height: 32),

              // --- INTERFACE SIZE ---
              _SectionHeader(title: l10n.settingsInterfaceSection),
              const SizedBox(height: 12),

              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.text_fields,
                            size: 18, color: Colors.white.withValues(alpha: 0.4)),
                        const SizedBox(width: 8),
                        Text(
                          l10n.settingsUiScaleTitle,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(6),
                            color:
                                const Color(0xFF6C63FF).withValues(alpha: 0.15),
                          ),
                          child: Text(
                            '${(settings.scaleFactor * 100).round()}%',
                            style: const TextStyle(
                              color: Color(0xFF6C63FF),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SliderTheme(
                      data: SliderThemeData(
                        trackHeight: 4,
                        activeTrackColor: const Color(0xFF6C63FF),
                        inactiveTrackColor: Colors.white.withValues(alpha: 0.06),
                        thumbColor: Colors.white,
                        thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 7),
                        overlayShape: const RoundSliderOverlayShape(
                            overlayRadius: 14),
                      ),
                      child: Slider(
                        value: settings.scaleFactor,
                        min: 0.7,
                        max: 1.3,
                        divisions: 12,
                        onChanged: (v) => settings.setScaleFactor(v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _ScaleHint(l10n.scaleCompact),
                          _ScaleHint(l10n.scaleNormal),
                          _ScaleHint(l10n.scaleLarge),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // --- COMMUNITY / FORUM ---
              _SectionHeader(title: l10n.settingsForumTitle),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.forum_rounded,
                            size: 18, color: Colors.white.withValues(alpha: 0.4)),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.settingsForumSubtitle,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.6),
                              fontSize: 13,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () => _openUrl(_forumUrl),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: Text(
                          l10n.settingsForumButton,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6C63FF),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // --- MORE APPS (fede_apps_core) ---
              _SectionHeader(title: l10n.settingsMoreAppsTitle),
              const SizedBox(height: 12),
              Material(
                color: const Color(0xFF1A1A2E),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                ),
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  // The site link is already in "About" (showSite: false).
                  child: EcosystemSection(
                    currentApp: FedeApp.toneGenerator,
                    showHeader: false,
                    showSite: false,
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // --- ABOUT ---
              _SectionHeader(title: l10n.settingsAboutTitle),
              const SizedBox(height: 12),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.appTitle,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.settingsAboutDescription,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'v1.0.0',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.25),
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Divider(color: Colors.white.withValues(alpha: 0.06)),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () => _openUrl(_appsUrl),
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(Icons.launch, size: 16, color: Color(0xFF6C63FF)),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                l10n.settingsAboutVisitWebsite,
                                style: const TextStyle(
                                  color: Color(0xFF6C63FF),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Show disclaimer again
              Center(
                child: TextButton.icon(
                  onPressed: () => _showDisclaimer(context),
                  icon: const Icon(Icons.warning_amber_rounded, size: 18),
                  label: Text(l10n.settingsShowSafetyWarning),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white.withValues(alpha: 0.4),
                  ),
                ),
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showDisclaimer(BuildContext context) {
    final l10n = context.l10n;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A2E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Color(0xFFE94560), size: 24),
            const SizedBox(width: 8),
            Text(l10n.warningTitle,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        content: Text(
          l10n.warningShortBody,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.warningGotIt,
                style: const TextStyle(
                    color: Color(0xFF6C63FF), fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

/// Language picker: system language (default), Español or English.
class _LanguageSelector extends StatelessWidget {
  final SettingsProvider settings;
  const _LanguageSelector({required this.settings});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.translate_rounded,
                size: 18, color: Colors.white.withValues(alpha: 0.4)),
            const SizedBox(width: 8),
            Text(
              l10n.settingsLanguageSubtitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String?>(
          initialValue: settings.languageCode,
          dropdownColor: const Color(0xFF1A1A2E),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  BorderSide(color: Colors.white.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF6C63FF)),
            ),
          ),
          items: [
            DropdownMenuItem<String?>(
              value: null,
              child: Text(l10n.languageSystem),
            ),
            DropdownMenuItem<String?>(
              value: 'es',
              child: Text(l10n.languageSpanish),
            ),
            DropdownMenuItem<String?>(
              value: 'en',
              child: Text(l10n.languageEnglish),
            ),
          ],
          onChanged: (code) => settings.setLanguage(code),
        ),
      ],
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: const Color(0xFF1A1A2E),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: child,
    );
  }
}

class _ScaleHint extends StatelessWidget {
  final String text;
  const _ScaleHint(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: TextStyle(
            fontSize: 10, color: Colors.white.withValues(alpha: 0.25)));
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.4),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
  }
}
