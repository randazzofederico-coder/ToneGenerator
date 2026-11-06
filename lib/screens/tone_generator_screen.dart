import 'package:fede_apps_core/fede_apps_core.dart'
    show EcosystemPrompts, FedeApp;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../providers/tone_generator_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/session_provider.dart';
import '../services/deep_link_service.dart';
import '../services/session_actions.dart';
import '../services/share_import_service.dart';
import '../theme/app_colors.dart';
import '../widgets/channel_card.dart';
import '../widgets/piano_keyboard.dart';
import 'library_screen.dart';
import 'settings_screen.dart';

class ToneGeneratorScreen extends StatefulWidget {
  const ToneGeneratorScreen({super.key});

  @override
  State<ToneGeneratorScreen> createState() => _ToneGeneratorScreenState();
}

class _ToneGeneratorScreenState extends State<ToneGeneratorScreen> {
  @override
  void initState() {
    super.initState();
    // This screen is only built after the safety disclaimer was accepted,
    // so shared links are processed from here.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pendingId = DeepLinkService().consumePendingShareId();
      if (pendingId != null) _handleShareId(pendingId);
      // Links arriving while the app runs (App Links / PWA launchQueue).
      DeepLinkService().listenIncomingLinks(_handleShareId);
    });
  }

  bool _isHandlingShare = false;
  final List<String> _queuedShares = [];

  /// Receive flow: fetch → import to library → ask to open (protecting
  /// unsaved work) → open (stopped). Links arriving mid-flow are queued.
  Future<void> _handleShareId(String shareId) async {
    if (!mounted) return;
    if (_isHandlingShare) {
      _queuedShares.add(shareId);
      return;
    }
    _isHandlingShare = true;
    try {
      await _receiveShare(shareId);
    } finally {
      _isHandlingShare = false;
    }
    if (_queuedShares.isNotEmpty) {
      await _handleShareId(_queuedShares.removeAt(0));
    }
  }

  Future<void> _receiveShare(String shareId) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(SnackBar(
      backgroundColor: AppColors.surfaceHigh,
      duration: const Duration(seconds: 20),
      content: Row(children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.textPrimary),
        ),
        const SizedBox(width: 12),
        Text(context.l10n.shareOpening,
            style: const TextStyle(color: AppColors.textPrimary)),
      ]),
    ));

    final bundle = await DeepLinkService().fetchSharedBundle(shareId);
    if (!mounted) return;
    messenger.hideCurrentSnackBar();
    if (bundle == null) {
      showAppSnack(context, context.l10n.shareInvalidLink, error: true);
      return;
    }

    final ShareImportResult result;
    try {
      result = await ShareImportService(
        sessions: context.read<SessionProvider>(),
      ).import(bundle);
    } catch (e) {
      debugPrint('Share import error: $e');
      if (mounted) {
        showAppSnack(context, context.l10n.shareImportFailed, error: true);
      }
      return;
    }
    if (!mounted) return;

    final wantsOpen = await _askOpenImported(result);
    if (wantsOpen != true || !mounted) return;

    // Wait for the engine and the restored working state before replacing it.
    await context.read<ToneGeneratorProvider>().ready;
    if (!mounted) return;
    final opened = await openSession(context, result.session);
    if (opened && mounted) {
      showAppSnack(
          context, context.l10n.shareSessionLoaded(result.session.name));
    }
  }

  /// "Added to your library — open now?" dialog.
  Future<bool?> _askOpenImported(ShareImportResult r) {
    final l10n = context.l10n;
    final status = r.alreadyInLibrary
        ? l10n.shareAlreadyInLibrary
        : l10n.shareAddedToLibrary(r.session.summaryLabel);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        icon: const Icon(Icons.library_music_rounded,
            color: AppColors.primary),
        title: Text(l10n.shareReceivedTitle),
        content: Text(
          l10n.shareReceivedBody(r.session.name, status),
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.actionSaveOnly,
                style: const TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.actionOpen,
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    DeepLinkService().dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ToneGeneratorProvider, SettingsProvider>(
      builder: (context, provider, settings, _) {
        final l10n = context.l10n;
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
                      title: _SessionTitle(provider: provider),
                      centerTitle: true,
                      actions: [
                        IconButton(
                          icon: const Icon(Icons.save_outlined, size: 22),
                          tooltip: l10n.tooltipSaveSession,
                          onPressed: provider.isDirty
                              ? () =>
                                  saveCurrentSession(context, offerLogin: true)
                              : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.share_outlined, size: 22),
                          tooltip: l10n.shareSessionTitle,
                          onPressed: provider.channels.isEmpty
                              ? null
                              : () => shareCurrentSession(context),
                        ),
                        IconButton(
                          icon: const Icon(Icons.library_music_outlined,
                              size: 22),
                          tooltip: l10n.libraryTitle,
                          onPressed: () => _openLibrary(context),
                        ),
                        PopupMenuButton<_MenuAction>(
                          tooltip: l10n.tooltipMoreOptions,
                          color: AppColors.surfaceHigh,
                          onSelected: (a) => _onMenu(context, a),
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: _MenuAction.saveAs,
                              child: _MenuRow(
                                  Icons.save_as_outlined, l10n.menuSaveAs),
                            ),
                            PopupMenuItem(
                              value: _MenuAction.newSession,
                              child: _MenuRow(Icons.add_box_outlined,
                                  l10n.menuNewSession),
                            ),
                            PopupMenuItem(
                              value: _MenuAction.library,
                              child: _MenuRow(Icons.library_music_outlined,
                                  l10n.libraryTitle),
                            ),
                            const PopupMenuDivider(),
                            PopupMenuItem(
                              value: _MenuAction.settings,
                              child: _MenuRow(
                                  Icons.settings_outlined, l10n.settingsTitle),
                            ),
                          ],
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
                                l10n.emptyChannelsHint,
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton.icon(
                                onPressed: () => provider.addChannel(),
                                icon: const Icon(Icons.add),
                                label: Text(l10n.addChannel),
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
                                    l10n.addChannel,
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

  void _openLibrary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LibraryScreen()),
    );
  }

  void _onMenu(BuildContext context, _MenuAction action) {
    switch (action) {
      case _MenuAction.saveAs:
        saveCurrentSessionAs(context, offerLogin: true);
      case _MenuAction.newSession:
        startNewSession(context);
      case _MenuAction.library:
        _openLibrary(context);
      case _MenuAction.settings:
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsScreen()),
        );
    }
  }
}

enum _MenuAction { saveAs, newSession, library, settings }

/// Session name in the app bar: italic with `*` when there are unsaved
/// changes. Tapping it renames the session (or saves it, if unsaved).
class _SessionTitle extends StatelessWidget {
  final ToneGeneratorProvider provider;
  const _SessionTitle({required this.provider});

  @override
  Widget build(BuildContext context) {
    final dirty = provider.isDirty;
    final saved = provider.activeSessionId != null;
    return Tooltip(
      message: saved
          ? context.l10n.renameSessionTitle
          : context.l10n.tooltipSaveSession,
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => renameCurrentSession(context),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                context.l10n.appTitle.toUpperCase(),
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.45),
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      dirty
                          ? '${provider.displayName} *'
                          : provider.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        fontStyle:
                            dirty ? FontStyle.italic : FontStyle.normal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.edit_outlined,
                      size: 14, color: Colors.white.withOpacity(0.4)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuRow(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20),
        const SizedBox(width: 12),
        Text(label),
      ],
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
                  context.l10n.masterVolume,
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
      onTap: () {
        final wasPlaying = provider.isPlaying;
        provider.togglePlayback();
        // Quiet moment after a manual stop: maybe suggest the other apps.
        if (wasPlaying &&
            !provider.isPlaying &&
            context.mounted &&
            context.read<SettingsProvider>().disclaimerAccepted) {
          EcosystemPrompts.maybeShowAppsPrompt(
            context,
            currentApp: FedeApp.toneGenerator,
          );
        }
      },
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
