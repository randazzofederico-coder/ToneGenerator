import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../services/deep_link_service.dart';
import '../theme/app_colors.dart';

/// Opens the unified share sheet.
///
/// The link is generated *inside* the sheet (spinner → link). The native share
/// is only triggered by a fresh tap on "Compartir en…", which keeps the user
/// activation required by the Web Share API (Safari/Chrome).
Future<void> showShareSheet(
  BuildContext context, {
  required String heading,
  required String subtitle,
  required Future<SharedLink> Function() createLink,
}) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: AppColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (_) => _ShareSheet(
      heading: heading,
      subtitle: subtitle,
      createLink: createLink,
    ),
  );
}

class _ShareSheet extends StatefulWidget {
  final String heading;
  final String subtitle;
  final Future<SharedLink> Function() createLink;

  const _ShareSheet({
    required this.heading,
    required this.subtitle,
    required this.createLink,
  });

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  late Future<SharedLink> _future;
  bool _copied = false;
  String? _info;

  @override
  void initState() {
    super.initState();
    _future = widget.createLink();
  }

  void _retry() => setState(() {
        _future = widget.createLink();
        _info = null;
      });

  Future<void> _copy(SharedLink link, {String? info}) async {
    await Clipboard.setData(ClipboardData(text: link.url));
    if (!mounted) return;
    setState(() {
      _copied = true;
      _info = info;
    });
  }

  Future<void> _nativeShare(SharedLink link) async {
    try {
      await SharePlus.instance.share(ShareParams(
        text: link.message,
        subject: link.title,
        title: link.title,
        mailToFallbackEnabled: false,
      ));
    } catch (_) {
      await _copy(link,
          info: 'No se pudo abrir el menú de compartir. Copiamos el link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    const textPrimary = AppColors.textPrimary;
    const textSecondary = AppColors.textSecondary;
    const accent = AppColors.primary;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(widget.heading,
                style: const TextStyle(
                    color: textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(widget.subtitle, style: const TextStyle(color: textSecondary)),
            const SizedBox(height: 20),
            FutureBuilder<SharedLink>(
              future: _future,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      children: [
                        SizedBox(
                          width: 28,
                          height: 28,
                          child: CircularProgressIndicator(
                              strokeWidth: 2.5, color: accent),
                        ),
                        SizedBox(height: 12),
                        Text('Generando link…',
                            style: TextStyle(color: textSecondary)),
                      ],
                    ),
                  );
                }

                if (snap.hasError) {
                  final msg = snap.error is ShareException
                      ? snap.error.toString()
                      : 'No se pudo crear el link.';
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.danger),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(msg,
                                style: const TextStyle(color: textPrimary))),
                      ]),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _retry,
                        icon: const Icon(Icons.refresh),
                        label: const Text('REINTENTAR'),
                      ),
                    ],
                  );
                }

                final link = snap.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceHigh,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(children: [
                        const Icon(Icons.link, color: textSecondary, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: SelectableText(link.url,
                              maxLines: 1,
                              style: const TextStyle(
                                  color: textPrimary, fontSize: 13)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    if (DeepLinkService().canNativeShare) ...[
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary),
                        onPressed: () => _nativeShare(link),
                        icon: const Icon(Icons.ios_share),
                        label: const Text('COMPARTIR EN…'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    OutlinedButton.icon(
                      onPressed: () => _copy(link),
                      icon: Icon(_copied ? Icons.check : Icons.copy_rounded),
                      label: Text(_copied ? '¡LINK COPIADO!' : 'COPIAR LINK'),
                    ),
                    if (_info != null) ...[
                      const SizedBox(height: 10),
                      Text(_info!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: textSecondary, fontSize: 12)),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
