import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/recordings_controller.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/recordings/panopto_api.dart';
import '../../core/recordings/recording_linker.dart';
import '../../domain/occurrence.dart';
import '../../domain/recording_match.dart';
import '../../l10n/gen/app_localizations.dart';
import '../courses/panopto_group_choice.dart';
import '../settings/panopto_section.dart';

/// "Find in Panopto" in a session's sheet: finds this session's recording
/// now and fills its link. Several groups at its time: asks which one is
/// the user's and saves it for the meeting. A link the user pasted is only
/// replaced when they say so. Nothing fits: says why, and offers the day's
/// recordings to pick from.
Future<void> findInPanopto(
  BuildContext context,
  WidgetRef ref,
  Occurrence session,
) => _find(context, ref, session, asked: false);

Future<void> _find(
  BuildContext context,
  WidgetRef ref,
  Occurrence session, {
  required bool asked,
}) async {
  final l = AppLocalizations.of(context);
  final messenger = ScaffoldMessenger.of(context);
  final controller = ref.read(panoptoProvider.notifier);
  final repo = ref.read(repositoryProvider);
  void say(String text) =>
      messenger.showSnackBar(SnackBar(content: Text(text)));

  final SessionCheck check;
  try {
    check = await controller.checkSession(session);
  } on PanoptoException catch (e) {
    say(panoptoErrorText(e.code, l));
    return;
  }
  if (!context.mounted) return;

  final own = session.recordingUrl?.trim() ?? '';
  final pasted = own.isNotEmpty && !session.recordingAuto;
  if (check.found case final found?) {
    if (pasted) {
      // recordingIdOf gives the id in lower case.
      if (RecordingMatcher.recordingIdOf(own) == found.id.toLowerCase()) {
        say(l.panoptoLinkMatches);
        return;
      }
      final replace = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(l.panoptoReplaceTitle),
          content: Text(l.panoptoReplaceBody(found.name)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(l.panoptoKeepMine),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(l.panoptoReplace),
            ),
          ],
        ),
      );
      if (replace != true) return;
    }
    await repo.useFoundRecording(session, found.viewerUrl);
    say(l.panoptoFoundHere);
    return;
  }

  if (check.question case final question? when !asked) {
    final group = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.panoptoWhichGroupTitle),
        content: SizedBox(
          width: 360,
          child: GroupChoice(
            options: question.options,
            selected: question.suggested,
            hint: question.hint,
            onSave: (group) => Navigator.pop(context, group),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l.cancel),
          ),
        ],
      ),
    );
    if (group == null || !context.mounted) return;
    // Saved for the meeting; its other sessions are found again too.
    await controller.answer(
      courseId: session.courseId,
      meetingId: session.meetingId,
      group: group,
    );
    if (!context.mounted) return;
    final fresh = ref.read(sessionProvider(session.id)) ?? session;
    return _find(context, ref, fresh, asked: true);
  }

  final why = check.noFolder
      ? l.panoptoWhyNoFolder
      : switch (check.outcome) {
          SessionOutcome.notOver => l.panoptoWhyNotOver,
          SessionOutcome.processing => l.panoptoWhyProcessing,
          SessionOutcome.otherGroup => l.panoptoWhyOtherGroup,
          SessionOutcome.otherType => l.panoptoWhyOtherType,
          SessionOutcome.usedElsewhere => l.panoptoWhyUsedElsewhere,
          SessionOutcome.canceled => l.panoptoWhyCanceled,
          _ => l.panoptoWhyNoRecording,
        };
  final pick = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.panoptoNothingTitle),
      content: Text(why),
      actions: [
        if (check.sameDay.isNotEmpty)
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.panoptoPickRecording),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(l.ok),
        ),
      ],
    ),
  );
  if (pick != true || !context.mounted) return;
  final chosen = await showAppSheet<PanoptoRecording>(
    context: context,
    scrollControlled: true,
    builder: (_) =>
        _RecordingPicker(session: session, recordings: check.sameDay),
  );
  // Picked by hand: the user's own link, which looks never move.
  if (chosen != null) await repo.setRecordingUrl(session, chosen.viewerUrl);
}

/// The course's recordings on the session's day.
class _RecordingPicker extends ConsumerWidget {
  const _RecordingPicker({required this.session, required this.recordings});

  final Occurrence session;
  final List<RecordingDetail> recordings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final today = ref.watch(todayProvider);
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              l.panoptoPickTitle(fmt.relativeDay(session.date, today, l)),
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final r in recordings)
            ListTile(
              leading: const Icon(LecIcons.recording),
              title: Text(r.recording.name),
              subtitle: Text(
                [
                  fmt.time(r.start.minute),
                  if (r.recording.group case final group?)
                    l.panoptoGroupOption(group),
                  ?r.recording.room,
                ].join(' · '),
              ),
              onTap: () => Navigator.pop(context, r.recording),
            ),
        ],
      ),
    );
  }
}
