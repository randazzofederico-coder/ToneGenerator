import 'dart:async';

import 'package:fede_apps_core/fede_apps_core.dart'
    show EcosystemPrompts, FedeApp;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../l10n/l10n.dart';
import '../models/tone_session.dart';
import '../providers/session_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tone_generator_provider.dart';
import '../theme/app_colors.dart';
import '../widgets/share_sheet.dart';
import 'deep_link_service.dart';

/// Session flows shared by the main screen and the library:
/// save / save as / open / new, protecting unsaved changes.

/// Shows a short message, replacing the current one. With an action (e.g.
/// DESHACER) it still auto-hides: since Flutter 3.32 snackbars with an action
/// persist by default, so `persist: false` is set explicitly.
void showAppSnack(BuildContext context, String message,
    {String? actionLabel, VoidCallback? onAction, bool error = false}) {
  final messenger = ScaffoldMessenger.of(context);
  final hasAction = actionLabel != null && onAction != null;
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(SnackBar(
    content: Text(message,
        style: const TextStyle(color: AppColors.textPrimary)),
    backgroundColor: error ? AppColors.danger : AppColors.surfaceHigh,
    behavior: SnackBarBehavior.floating,
    persist: false,
    duration: Duration(seconds: hasAction ? 5 : 3),
    action: hasAction
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
  String? confirmLabel,
  String? exceptId,
}) {
  final library = context.read<SessionProvider>();
  final l10n = context.l10n;
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
            setState(() => error = l10n.sessionNameRequired);
            return;
          }
          if (library.nameExists(name, exceptId: exceptId)) {
            setState(() => error = l10n.sessionNameExists);
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
              hintText: l10n.sessionNameHint,
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
              child: Text(l10n.actionCancel,
                  style: const TextStyle(color: AppColors.textSecondary)),
            ),
            TextButton(
              onPressed: submit,
              child: Text(confirmLabel ?? l10n.actionSave,
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
///
/// [offerLogin]: only for the explicit "Guardar" / "Guardar como" buttons —
/// after saving a NEW session, maybe suggest signing in (see
/// [_maybeOfferLogin]). Flows that continue with another sheet or a
/// navigation (share, unsaved-changes dialog, rename) leave it off.
Future<bool> saveCurrentSession(BuildContext context,
    {bool offerUndo = true, bool offerLogin = false}) async {
  final tone = context.read<ToneGeneratorProvider>();
  final library = context.read<SessionProvider>();
  await library.ensureLoaded;

  final id = tone.activeSessionId;
  final previous = id == null ? null : library.getSessionById(id);
  if (previous == null) {
    if (!context.mounted) return false;
    return saveCurrentSessionAs(context, offerLogin: offerLogin);
  }

  final updated = tone.captureSession(
      id: previous.id, name: previous.name, createdAt: previous.createdAt);
  await library.saveSession(updated);
  tone.markSaved(updated);

  if (context.mounted) {
    final l10n = context.l10n;
    showAppSnack(
      context,
      l10n.sessionSaved(updated.name),
      actionLabel: offerUndo ? l10n.actionUndo : null,
      onAction: offerUndo
          ? () async {
              await library.restoreSnapshot(previous);
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
Future<bool> saveCurrentSessionAs(BuildContext context,
    {bool offerLogin = false}) async {
  final tone = context.read<ToneGeneratorProvider>();
  final library = context.read<SessionProvider>();
  await library.ensureLoaded;
  if (!context.mounted) return false;

  final name = await askSessionName(
    context,
    title: context.l10n.saveSessionAsTitle,
    initial: tone.activeSessionName ?? '',
  );
  if (name == null) return false;

  final session = tone.captureSession(id: _newId(), name: name);
  await library.saveSession(session);
  tone.markSaved(session);
  if (context.mounted) {
    showAppSnack(context, context.l10n.sessionSaved(name));
    if (offerLogin) _maybeOfferLogin(context, library.sessions.length);
  }
  return true;
}

/// Layered login suggestion (fede_apps_core: shown only with ≥ 3 sessions,
/// without an account, rate-limited by `PromptGate`). Fire-and-forget and
/// never on top of the safety disclaimer.
void _maybeOfferLogin(BuildContext context, int libraryCount) {
  final settings = context.read<SettingsProvider?>();
  if (settings == null || !settings.disclaimerAccepted) return;
  unawaited(EcosystemPrompts.maybeShowLoginPrompt(
    context,
    currentApp: FedeApp.toneGenerator,
    libraryCount: libraryCount,
  ).catchError((Object e) {
    debugPrint('Login prompt failed: $e');
    return false;
  }));
}

String _newId() => const Uuid().v4();

/// If the working state has unsaved changes, offers Save / Discard / Cancel.
/// Returns true when it's OK to replace the current state.
Future<bool> protectUnsavedChanges(BuildContext context) async {
  final tone = context.read<ToneGeneratorProvider>();
  if (!tone.isDirty) return true;

  final l10n = context.l10n;
  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(l10n.unsavedChangesTitle),
      content: Text(tone.activeSessionId == null
          ? l10n.unsavedChangesNew
          : l10n.unsavedChangesNamed(tone.displayName)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'cancel'),
          child: Text(l10n.actionCancel,
              style: const TextStyle(color: AppColors.textSecondary)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'discard'),
          child: Text(l10n.actionDiscard,
              style: const TextStyle(color: AppColors.danger)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, 'save'),
          child: Text(l10n.actionSave,
              style: const TextStyle(
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

/// Renames the open session (tap on its name). An unsaved session is saved
/// with the chosen name instead.
Future<void> renameCurrentSession(BuildContext context) async {
  final tone = context.read<ToneGeneratorProvider>();
  final library = context.read<SessionProvider>();
  await library.ensureLoaded;
  if (!context.mounted) return;

  final id = tone.activeSessionId;
  final stored = id == null ? null : library.getSessionById(id);
  if (stored == null) {
    await saveCurrentSessionAs(context);
    return;
  }

  final name = await askSessionName(
    context,
    title: context.l10n.renameSessionTitle,
    initial: stored.name,
    confirmLabel: context.l10n.actionRename,
    exceptId: stored.id,
  );
  if (name == null || name == stored.name) return;
  await library.renameSession(stored.id, name);
  if (tone.activeSessionId == stored.id) tone.renameActive(name);
}

/// Removes a channel offering DESHACER.
void removeChannelWithUndo(BuildContext context, String channelId) {
  final tone = context.read<ToneGeneratorProvider>();
  final removed = tone.removeChannel(channelId);
  if (removed == null) return;
  showAppSnack(
    context,
    context.l10n.channelDeleted,
    actionLabel: context.l10n.actionUndo,
    onAction: () => tone.restoreChannel(
        removed.channel, removed.index, removed.generation),
  );
}

// ── Sharing ────────────────────────────────────────────────────────────────

/// Opens the share sheet for a library [session].
void shareSession(BuildContext context, ToneSession session,
    {String? note}) {
  showShareSheet(
    context,
    heading: context.l10n.shareSessionTitle,
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
    showAppSnack(context, context.l10n.shareAddChannelFirst);
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
    note: dirty ? context.l10n.shareIncludesUnsaved : null,
  );
}
