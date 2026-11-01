import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/tone_generator_provider.dart';
import '../providers/settings_provider.dart';
import '../models/channel_model.dart';
import '../widgets/channel_card.dart';
import '../widgets/piano_keyboard.dart';
import 'settings_screen.dart';

class ToneGeneratorScreen extends StatelessWidget {
  const ToneGeneratorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ToneGeneratorProvider, SettingsProvider>(
      builder: (context, provider, settings, _) {
        return Scaffold(
          body: Column(
            children: [
              // --- MAIN SCROLLABLE AREA ---
              Expanded(
                child: CustomScrollView(
                  slivers: [
                    // App Bar
                    SliverAppBar(
                      floating: true,
                      snap: true,
                      backgroundColor: const Color(0xFF1A1A2E),
                      elevation: 0,
                      title: const Text(
                        'Tone Generator',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                      centerTitle: true,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.share, size: 22),
                          tooltip: 'Compartir Sesión',
                          onPressed: provider.channels.isEmpty
                              ? null
                              : () => _shareSession(context, provider),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings_outlined, size: 22),
                          tooltip: 'Ajustes',
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),

                    // Master Controls Bar
                    SliverToBoxAdapter(
                      child: _MasterControlsBar(provider: provider),
                    ),

                    // Channel List
                    if (provider.channels.isEmpty)
                      SliverFillRemaining(
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.graphic_eq,
                                  size: 64,
                                  color: Colors.white.withOpacity(0.15)),
                              const SizedBox(height: 16),
                              Text(
                                'Agregá un canal para comenzar',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => provider.addChannel(),
                                icon: const Icon(Icons.add),
                                label: const Text('Agregar Canal'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF6C63FF),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final channel = provider.channels[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: ChannelCard(
                                  channel: channel,
                                  channelIndex: index,
                                ),
                              );
                            },
                            childCount: provider.channels.length,
                          ),
                        ),
                      ),

                    // Add Channel button (inline, below last card)
                    if (provider.channels.isNotEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: GestureDetector(
                            onTap: () => provider.addChannel(),
                            child: Container(
                              height: 44,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFF6C63FF).withOpacity(0.3),
                                ),
                                color: const Color(0xFF6C63FF).withOpacity(0.05),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_rounded,
                                      size: 20,
                                      color: const Color(0xFF6C63FF).withOpacity(0.7)),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Agregar Canal',
                                    style: TextStyle(
                                      color: const Color(0xFF6C63FF).withOpacity(0.7),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                    // Bottom padding
                    const SliverToBoxAdapter(
                      child: SizedBox(height: 16),
                    ),
                  ],
                ),
              ),

              // --- GLOBAL PIANO KEYBOARD (bottom) ---
              const GlobalPianoKeyboard(),
            ],
          ),
        );
      },
    );
  }

  void _shareSession(BuildContext context, ToneGeneratorProvider provider) {
    final json = provider.sessionToJson();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Compartir sesión (próximamente)')),
    );
  }
}

class _MasterControlsBar extends StatelessWidget {
  final ToneGeneratorProvider provider;

  const _MasterControlsBar({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF16213E),
            const Color(0xFF0F3460).withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        children: [
          // Play/Stop button
          _PlayButton(provider: provider),
          const SizedBox(width: 16),

          // Master Volume
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Master Volume',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 4,
                    activeTrackColor: const Color(0xFF6C63FF),
                    inactiveTrackColor: Colors.white.withOpacity(0.1),
                    thumbColor: const Color(0xFF6C63FF),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 7),
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                  ),
                  child: Slider(
                    value: provider.masterVolume,
                    onChanged: (v) => provider.setMasterVolume(v),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(
            width: 40,
            child: Text(
              '${(provider.masterVolume * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final ToneGeneratorProvider provider;

  const _PlayButton({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isPlaying = provider.isPlaying;
    return GestureDetector(
      onTap: () => provider.togglePlayback(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isPlaying
                ? [const Color(0xFFE94560), const Color(0xFFC23355)]
                : [const Color(0xFF6C63FF), const Color(0xFF5A52D5)],
          ),
          boxShadow: [
            BoxShadow(
              color: (isPlaying
                      ? const Color(0xFFE94560)
                      : const Color(0xFF6C63FF))
                  .withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
