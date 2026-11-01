import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../models/tone_session.dart';
import '../providers/session_provider.dart';
import '../providers/tone_generator_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/share_sheet.dart';
import 'deep_link_service.dart';

/// Session flows shared by the main screen and the library:
/// save / save as / open / new, protecting unsaved changes.

void showAppSnack(BuildContext context, String message,
    {String? actionLabel, VoidCallback? onAction, bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message),
    backgroundColor: error ? AppColors.danger : AppColors.surfaceHigh,
    behavior: SnackBarBehavior.floating,
    action: (actionLabel != null && onAction != null)
        ? SnackBarAction(
            label: actionLabel,
            textColor: AppColors.secondary,
            onPressed: onAction,
          )
        : null,
  ));
}

/// Asks for a session name. Returns the trimmed name or null if cancelled.
Future<String?> askSessionName(
  BuildContext context, {
  required String title,
  String initial = '',
  String confirmLabel = 'GUARDAR',
  String? exceptId,
}) {
  final library = context.read<SessionProvider>();
  final controller = TextEditingController(text: initial)
    ..selection = TextSelection(baseOffset: 0, extentOffset: initial.length);
  String? error;

  return showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        void submit() {
          final name = controller.text.trim();
          if (name.isEmpty) {
            setState(() => error = 'Escribí un nombre');
            return;
          }
          if (library.nameExists(name, exceptId: exceptId)) {
            setState(() => error = 'Ya existe una sesión con ese nombre');
            return;
          }
          Navigator.pop(ctx, name);
        }

        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: ToneSession.maxNameLength,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Nombre de la sesión',
              errorText: error,
            ),
            onChanged: (_) {
              if (error != null) setState(() => error = null);
            },
            onSubmitted: (_) => submit(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('CANCELAR',
                  style: TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: submit,
              child: Text(confirmLabel,
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    ),
  );
}

/// 💾 Saves the current state over the active session (with UNDO). If there
/// is no active session in the library, asks for a name ("Guardar como…").
Future<bool> saveCurrentSession(BuildContext context,
    {bool offerUndo = true}) async {
  final tone = context.read<ToneGeneratorProvider>();
  final library = context.read<SessionProvider>();
  await library.ensureLoaded;

  final id = tone.activeSessionId;
  final previous = id == null ? null : library.getSessionById(id);
  if (previous == null) {
    if (!context.mounted) return false;
    return saveCurrentSessionAs(context);
  }

  final updated = tone.captureSession(
      id: previous.id, name: previous.name, createdAt: previous.createdAt);
  await library.saveSession(updated);
  tone.markSaved(updated);

  if (context.mounted) {
    showAppSnack(
      context,
      'Sesión «${updated.name}» guardada',
      actionLabel: offerUndo ? 'DESHACER' : null,
      onAction: offerUndo
          ? () async {
              await library.saveSession(previous);
              if (tone.activeSessionId == previous.id) {
                tone.setSavedReference(previous);
              }
            }
          : null,
    );
  }
  return true;
}

/// Saves the current state as a new library session (asks for a name).
Future<bool> saveCurrentSessionAs(BuildContext context) async {
  final tone = context.read<ToneGeneratorProvider>();
  final library = context.read<SessionProvider>();
  await library.ensureLoaded;
  if (!context.mounted) return false;

  final name = await askSessionName(
    context,
    title: 'Guardar sesión como…',
    initial: tone.activeSessionName ?? '',
  );
  if (name == null) return false;

  final session = tone.captureSession(id: _newId(), name: name);
  await library.saveSession(session);
  tone.markSaved(session);
  if (context.mounted) showAppSnack(context, 'Sesión «$name» guardada');
  return true;
}

String _newId() => const Uuid().v4();

/// If the working state has unsaved changes, offers Save / Discard / Cancel.
/// Returns true when it's OK to replace the current state.
Future<bool> protectUnsavedChanges(BuildContext context) async {
  final tone = context.read<ToneGeneratorProvider>();
  if (!tone.isDirty) return true;

  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: const Text('Cambios sin guardar'),
      content: Text(tone.activeSessionId == null
          ? 'La sesión actual no está guardada. ¿Qué querés hacer antes de continuar?'
          : 'La sesión «${tone.displayName}» tiene cambios sin guardar. ¿Qué querés hacer antes de continuar?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'cancel'),
          child: const Text('CANCELAR',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'discard'),
          child: const Text('DESCARTAR',
              style: TextStyle(color: AppColors.danger)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'save'),
          child: const Text('GUARDAR',
              style: TextStyle(
                  color: AppColors.success, fontWeight: FontWeight.bold)),
        ),
      ],
    ),
  );

  if (!context.mounted) return false;
  switch (choice) {
    case 'discard':
      return true;
    case 'save':
      return saveCurrentSession(context, offerUndo: false);
    default:
      return false;
  }
}

/// Opens [session] (protecting unsaved work). Never starts playback.
Future<bool> openSession(BuildContext context, ToneSession session) async {
  final tone = context.read<ToneGeneratorProvider>();
  if (tone.activeSessionId == session.id && !tone.isDirty) return true;
  if (!await protectUnsavedChanges(context)) return false;
  tone.loadSession(session);
  return true;
}

/// Starts an empty session (protecting unsaved work).
Future<void> startNewSession(BuildContext context) async {
  if (!await protectUnsavedChanges(context)) return;
  if (!context.mounted) return;
  context.read<ToneGeneratorProvider>().newSession();
}

// ── Sharing ────────────────────────────────────────────────────────────────

/// Opens the share sheet for a library [session].
void shareSession(BuildContext context, ToneSession session,
    {String? note}) {
  showShareSheet(
    context,
    heading: 'Compartir sesión',
    subtitle: '«${session.name}» · ${session.summaryLabel}'
        '${note != null ? '\n$note' : ''}',
    createLink: () => DeepLinkService().createSessionLink(session),
  );
}

/// Shares what is loaded right now. An unsaved session is saved first (a
/// name is needed); unsaved changes of a saved session are included as-is.
Future<void> shareCurrentSession(BuildContext context) async {
  final tone = context.read<ToneGeneratorProvider>();
  if (tone.channels.isEmpty) {
    showAppSnack(context, 'Agregá al menos un canal para compartir.');
    return;
  }
  if (tone.activeSessionId == null) {
    final saved = await saveCurrentSessionAs(context);
    if (!saved || !context.mounted) return;
  }
  final library = context.read<SessionProvider>();
  final stored = library.getSessionById(tone.activeSessionId!);
  final dirty = tone.isDirty;
  shareSession(
    context,
    tone.captureSession(createdAt: stored?.createdAt),
    note: dirty ? 'Incluye los cambios sin guardar.' : null,
  );
}
