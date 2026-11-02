import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/tone_session.dart';
import '../providers/session_provider.dart';
import '../providers/tone_generator_provider.dart';
import '../services/session_actions.dart';
import '../theme/app_colors.dart';

/// Library of saved sessions: search, open, rename, duplicate, delete.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<SessionProvider>();
    final tone = context.watch<ToneGeneratorProvider>();
    final q = _query.trim().toLowerCase();
    final sessions = library.sessions
        .where((s) => q.isEmpty || s.name.toLowerCase().contains(q))
        .toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Biblioteca'),
        backgroundColor: AppColors.surface,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar sesión',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                    filled: true,
                    fillColor: AppColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: sessions.isEmpty
                    ? _EmptyState(searching: q.isNotEmpty)
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                        itemCount: sessions.length,
                        itemBuilder: (context, i) => _SessionTile(
                          session: sessions[i],
                          isActive: tone.activeSessionId == sessions[i].id,
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool searching;
  const _EmptyState({required this.searching});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.library_music_outlined,
                size: 56, color: Colors.white.withValues(alpha: 0.15)),
            const SizedBox(height: 16),
            Text(
              searching
                  ? 'No hay sesiones con ese nombre'
                  : 'Todavía no guardaste sesiones.\nUsá 💾 en la pantalla principal para guardar la actual.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withValues(alpha: 0.45)),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Action { open, share, duplicate, rename, delete }

class _SessionTile extends StatelessWidget {
  final ToneSession session;
  final bool isActive;

  const _SessionTile({required this.session, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _open(context),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isActive
                    ? AppColors.primary.withValues(alpha: 0.6)
                    : AppColors.border,
              ),
            ),
            child: Row(
              children: [
                _ChannelDots(session: session),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (isActive)
                  Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('Abierta',
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600)),
                  ),
                PopupMenuButton<_Action>(
                  tooltip: 'Opciones',
                  color: AppColors.surfaceHigh,
                  onSelected: (a) => _onAction(context, a),
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                        value: _Action.open,
                        child: _MenuRow(Icons.open_in_new, 'Abrir')),
                    PopupMenuItem(
                        value: _Action.share,
                        child: _MenuRow(Icons.share_outlined, 'Compartir')),
                    PopupMenuItem(
                        value: _Action.duplicate,
                        child: _MenuRow(Icons.copy_rounded, 'Duplicar')),
                    PopupMenuItem(
                        value: _Action.rename,
                        child: _MenuRow(Icons.edit_outlined, 'Renombrar')),
                    PopupMenuItem(
                        value: _Action.delete,
                        child: _MenuRow(Icons.delete_outline, 'Eliminar',
                            color: AppColors.danger)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    final freqs = session
        .buildChannels()
        .map((c) => c.frequency >= 1000
            ? '${(c.frequency / 1000).toStringAsFixed(2)} kHz'
            : '${c.frequency.toStringAsFixed(c.frequency % 1 == 0 ? 0 : 1)} Hz')
        .take(4)
        .join(' · ');
    final more = session.channels.length > 4 ? ' …' : '';
    return freqs.isEmpty
        ? 'Sin canales'
        : '${session.summaryLabel} — $freqs$more';
  }

  Future<void> _open(BuildContext context) async {
    final opened = await openSession(context, session);
    if (opened && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _onAction(BuildContext context, _Action action) async {
    final library = context.read<SessionProvider>();
    final tone = context.read<ToneGeneratorProvider>();
    switch (action) {
      case _Action.open:
        await _open(context);
      case _Action.share:
        if (session.channels.isEmpty) {
          showAppSnack(context, 'La sesión no tiene canales para compartir.');
          return;
        }
        shareSession(context, session);
      case _Action.duplicate:
        final copy = await library.duplicateSession(session.id);
        if (copy != null && context.mounted) {
          showAppSnack(context, 'Se creó «${copy.name}»');
        }
      case _Action.rename:
        final name = await askSessionName(
          context,
          title: 'Renombrar sesión',
          initial: session.name,
          confirmLabel: 'RENOMBRAR',
          exceptId: session.id,
        );
        if (name == null || name == session.name) return;
        await library.renameSession(session.id, name);
        if (tone.activeSessionId == session.id) tone.renameActive(name);
      case _Action.delete:
        await _delete(context, library, tone);
    }
  }

  Future<void> _delete(BuildContext context, SessionProvider library,
      ToneGeneratorProvider tone) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Eliminar sesión'),
        content: Text('¿Eliminar «${session.name}» de la biblioteca?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('CANCELAR',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ELIMINAR',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final removed = await library.deleteSession(session.id);
    if (removed == null) return;
    if (tone.activeSessionId == removed.id) tone.detachActive();
    if (!context.mounted) return;
    showAppSnack(
      context,
      'Sesión «${removed.name}» eliminada',
      actionLabel: 'DESHACER',
      onAction: () async {
        await library.saveSession(removed);
        tone.reattach(removed);
      },
    );
  }
}

class _ChannelDots extends StatelessWidget {
  final ToneSession session;
  const _ChannelDots({required this.session});

  @override
  Widget build(BuildContext context) {
    final n = session.channels.length.clamp(0, 8);
    return SizedBox(
      width: 28,
      height: 28,
      child: n == 0
          ? Icon(Icons.graphic_eq,
              size: 22, color: Colors.white.withValues(alpha: 0.3))
          : Wrap(
              spacing: 3,
              runSpacing: 3,
              alignment: WrapAlignment.center,
              runAlignment: WrapAlignment.center,
              children: List.generate(
                n,
                (i) => Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: channelColor(i),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;
  const _MenuRow(this.icon, this.label, {this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Text(label, style: TextStyle(color: color)),
      ],
    );
  }
}
