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

Future<void> openUrl(String url) async {
  final uri = Uri.tryParse(url.contains('://') ? url : 'https://$url');
  if (uri == null) return;
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}
