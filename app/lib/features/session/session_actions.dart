import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../domain/occurrence.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';

/// Marks one session with haptic feedback and an undo snackbar.
Future<void> markSession(
  BuildContext context,
  WidgetRef ref,
  Occurrence session,
  AttendanceStatus status, {
  VoidCallback? onUndo,
}) async {
  final repo = ref.read(repositoryProvider);
  final previous = session.explicitStatus;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = AppLocalizations.of(context);
  HapticFeedback.mediumImpact();
  await repo.setStatus(session, status);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l.markedAs(status.label(l))),
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () {
            onUndo?.call();
            repo.setStatus(session, previous);
          },
        ),
      ),
    );
}

/// Marks several sessions at once (e.g. "mark all attended").
Future<void> markSessions(
  BuildContext context,
  WidgetRef ref,
  List<Occurrence> sessions,
  AttendanceStatus status,
) async {
  if (sessions.isEmpty) return;
  final repo = ref.read(repositoryProvider);
  final previous = {for (final s in sessions) s: s.explicitStatus};
  final messenger = ScaffoldMessenger.maybeOf(context);
  final l = AppLocalizations.of(context);
  HapticFeedback.heavyImpact();
  await repo.setStatuses(sessions, status);
  messenger
    ?..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(l.markedManyAs(sessions.length, status.label(l))),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () async {
            for (final e in previous.entries) {
              await repo.setStatus(e.key, e.value);
            }
          },
        ),
      ),
    );
}

/// Schemes links may open. Links can come from imported backups, so
/// anything that could open local files or other apps' screens (`file:`,
/// `content:`, `intent:`) is refused.
const _openableSchemes = {'http', 'https', 'mailto', 'tel'};

/// The link [url] as it would be opened, or null if LecCheck doesn't open
/// it. Text without a scheme is a web address (`example.com`; note that
/// `example.com:8080/x` parses with the scheme `example.com`).
Uri? openableLink(String url) {
  final text = url.trim();
  final parsed = Uri.tryParse(text);
  if (parsed != null &&
      _openableSchemes.contains(parsed.scheme.toLowerCase())) {
    return parsed;
  }
  if (text.isEmpty || text.contains('://')) return null;
  final web = Uri.tryParse('https://$text');
  return web == null || web.host.isEmpty ? null : web;
}

/// Opens [url] in its app (the browser for web links). A link LecCheck
/// doesn't open shows a snackbar when [context] is given.
Future<void> openUrl(String url, {BuildContext? context}) async {
  final uri = openableLink(url);
  if (uri == null) {
    if (context != null && context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context).linkNotOpened)),
      );
    }
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
