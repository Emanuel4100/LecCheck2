import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/providers.dart';
import '../../app/recordings_controller.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/recordings/match_report.dart';
import '../../domain/recording_match.dart';

/// Developer mode: how each course's recordings matched in the latest looks.
/// English only, like the other developer tools.
class PanoptoDebugPage extends ConsumerWidget {
  const PanoptoDebugPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(panoptoProvider);
    final controller = ref.read(panoptoProvider.notifier);
    final looks = [...view.looks]..sort((a, b) => a.code.compareTo(b.code));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panopto matching'),
        actions: [
          IconButton(
            tooltip: 'Look again',
            icon: const Icon(LecIcons.refresh),
            onPressed: view.busy ? null : controller.lookNow,
          ),
          IconButton(
            tooltip: 'Copy as text',
            icon: const Icon(LecIcons.copy),
            onPressed: looks.isEmpty
                ? null
                : () async {
                    final messenger = ScaffoldMessenger.of(context);
                    await Clipboard.setData(
                      ClipboardData(
                        text: lookReportText(looks, at: view.report.at),
                      ),
                    );
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Copied')),
                    );
                  },
          ),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 40),
            children: [
              if (view.busy) const LinearProgressIndicator(),
              if (looks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No details yet: they come from looks in this run of the '
                    'app. Tap Look again (top) to see how each course '
                    'matched.',
                  ),
                ),
              if (view.report.error != null)
                ListTile(
                  leading: const Icon(LecIcons.warning),
                  title: Text('Last look stopped: ${view.report.error}'),
                ),
              for (final look in looks) _CourseCard(look: look),
            ],
          ),
        ),
      ),
    );
  }
}

class _CourseCard extends ConsumerWidget {
  const _CourseCard({required this.look});

  final CourseLook look;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final d = look.details;
    final s = look.sessionCounts;
    final r = look.recordingCounts;
    int count(Iterable<SessionOutcome> outcomes) =>
        outcomes.fold(0, (n, o) => n + (s[o] ?? 0));
    final missing = [
      for (final x in d.sessions)
        if (missingOutcomes.contains(x.outcome)) x,
    ];
    final removed = [
      for (final x in d.sessions)
        if (x.outcome == SessionOutcome.removed) x,
    ];
    final found = [
      for (final x in d.sessions)
        if (x.outcome == SessionOutcome.found) x,
    ];
    final own = [
      for (final x in d.sessions)
        if (x.outcome == SessionOutcome.ownLink) x,
    ];
    final byId = {for (final x in d.recordings) x.recording.id: x};
    final unused = <RecordingOutcome, List<RecordingDetail>>{};
    for (final x in d.recordings) {
      if (unusedOutcomes.contains(x.outcome)) {
        unused.putIfAbsent(x.outcome, () => []).add(x);
      }
    }
    final summary = look.skipped != null
        ? 'Not looked at: ${look.skipped}'
        : [
            'found ${s[SessionOutcome.found] ?? 0}',
            'your links ${s[SessionOutcome.ownLink] ?? 0}',
            'removed ${s[SessionOutcome.removed] ?? 0}',
            'canceled ${s[SessionOutcome.canceled] ?? 0}',
            'missing ${count(missingOutcomes)}',
            'recordings ${d.recordings.length} '
                '(not used ${unused.values.fold(0, (n, l) => n + l.length)})',
          ].join(' · ');

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text, style: theme.textTheme.titleSmall),
    );
    Widget line(String title, String? subtitle, {Widget? trailing}) => ListTile(
      dense: true,
      visualDensity: VisualDensity.compact,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: trailing,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        title: Text('${look.code} ${look.courseName}'),
        subtitle: Text(summary, style: muted),
        childrenPadding: const EdgeInsets.only(bottom: 12),
        expandedCrossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              [
                for (final f in look.folders) 'Folder: ${f.name}',
                if (look.error != null) 'Error: ${look.error}',
                if (look.skipped == null)
                  'Start times read as '
                      '${d.readUtc ? 'real UTC' : 'wall clock'} '
                      '(fit sessions: wall clock ${d.fitWall}, UTC '
                      '${d.fitUtc}) · ${look.recordingsRead} recordings '
                      'read · ${look.written} links written',
                if (r.isNotEmpty)
                  'Recordings: ${[for (final e in r.entries) '${recordingOutcomeText(e.key)} ${e.value}'].join(', ')}',
              ].join('\n'),
              style: muted,
            ),
          ),
          if (missing.isNotEmpty) ...[
            heading('Sessions without a found link (${missing.length})'),
            for (final x in missing)
              line(sessionLabel(x.session), sessionOutcomeText(x.outcome)),
          ],
          if (removed.isNotEmpty) ...[
            heading('Links you removed (${removed.length})'),
            for (final x in removed)
              line(
                sessionLabel(x.session),
                'Removed by hand, so nothing found shows here',
                trailing: TextButton(
                  onPressed: () => ref
                      .read(repositoryProvider)
                      .allowFoundRecording(x.session),
                  child: const Text('Allow finding again'),
                ),
              ),
          ],
          if (found.isNotEmpty) ...[
            heading('Found (${found.length})'),
            for (final x in found)
              line(sessionLabel(x.session), switch (byId[x.recordingId]) {
                final rec? => recordingLabel(rec),
                null => x.recordingId,
              }),
          ],
          if (own.isNotEmpty) ...[
            heading('Your links (${own.length})'),
            for (final x in own)
              line(sessionLabel(x.session), _ownLink(x, byId)),
          ],
          for (final MapEntry(key: outcome, value: list) in unused.entries) ...[
            heading(
              'Recordings not used: ${recordingOutcomeText(outcome)} '
              '(${list.length})',
            ),
            for (final x in list) line(recordingLabel(x), recordingReason(x)),
          ],
        ],
      ),
    );
  }

  /// Where a pasted link points: a recording of this folder (and whether
  /// it's from the session's date), or somewhere else.
  static String _ownLink(SessionDetail x, Map<String, RecordingDetail> byId) {
    final id = RecordingMatcher.recordingIdOf(x.session.recordingUrl ?? '');
    if (id == null) return 'Not a Panopto viewer link';
    final rec = byId[id];
    if (rec == null) return 'A recording outside this course\'s folder';
    final sameDay = rec.start.date == x.session.date;
    return '${sameDay ? '' : 'Another date! '}${recordingLabel(rec)}';
  }
}
