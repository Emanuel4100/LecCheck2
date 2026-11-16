import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/labels.dart';
import '../../app/recordings_controller.dart';
import '../../core/icons/lec_icons.dart';
import '../../core/recordings/panopto_api.dart';
import '../../core/recordings/panopto_connection.dart';
import '../../domain/recording_match.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import '../settings/panopto_section.dart';
import 'meeting_summary.dart';

/// The course page's Panopto part (experimental): the course's folder, the
/// group questions, and "Look now". Shown when this device is connected or
/// the course has a folder.
class PanoptoCourseSection extends ConsumerWidget {
  const PanoptoCourseSection({
    super.key,
    required this.course,
    required this.meetings,
  });

  final CourseInfo course;
  final List<MeetingRule> meetings;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final view = ref.watch(panoptoProvider);
    final folders = ref.watch(panoptoFoldersProvider).value?[course.id];
    final groups = ref.watch(panoptoGroupsProvider).value ?? const {};
    final connected = view.status == PanoptoStatus.connected;
    if (!connected && (folders == null || folders.isEmpty)) {
      return const SizedBox.shrink();
    }
    final controller = ref.read(panoptoProvider.notifier);
    final questions = view.questionsOf(course.id);
    String label(MeetingRule m) =>
        '${meetingTitle(m, l, fmt)} ${fmt.time(m.startMin)}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PanoptoHeader(),
        ListTile(
          leading: const Icon(LecIcons.recording),
          title: Text(l.panoptoFolder),
          subtitle: Text(switch (folders) {
            null => l.panoptoFolderAuto,
            [] => l.panoptoFolderNone,
            _ => folders.map((f) => f.name).join('\n'),
          }),
          trailing: connected
              ? TextButton(
                  onPressed: view.busy
                      ? null
                      : () => _chooseFolder(context, ref),
                  child: Text(l.panoptoFolderChange),
                )
              : null,
        ),
        if (view.report.chooseFolder.contains(course.id) && folders == null)
          ListTile(
            leading: const Icon(LecIcons.warning),
            subtitle: Text(l.panoptoAskFolder),
          ),
        for (final q in questions)
          if (meetings.where((m) => m.id == q.meetingId).firstOrNull
              case final meeting?)
            _GroupQuestionCard(
              key: ValueKey(q.meetingId),
              question: q,
              meetingLabel: label(meeting),
              busy: view.busy,
              onAnswer: (group) => controller.answer(
                courseId: course.id,
                meetingId: meeting.id,
                group: group,
              ),
            ),
        for (final m in meetings)
          if ((groups[m.id] ?? '').isNotEmpty)
            ListTile(
              leading: Icon(m.type.icon),
              title: Text(l.panoptoGroupChosen(label(m), groups[m.id]!)),
              trailing: connected
                  ? TextButton(
                      onPressed: view.busy
                          ? null
                          : () => controller.forgetGroup(
                              courseId: course.id,
                              meetingId: m.id,
                            ),
                      child: Text(l.panoptoGroupAskAgain),
                    )
                  : null,
            ),
        if (connected)
          ListTile(
            leading: const Icon(LecIcons.refresh),
            title: Text(view.busy ? l.panoptoLooking : l.panoptoLookCourse),
            enabled: !view.busy,
            onTap: () => controller.lookNow(courseId: course.id),
          ),
      ],
    );
  }

  Future<void> _chooseFolder(BuildContext context, WidgetRef ref) async {
    final choice = await showAppSheet<_FolderChoice>(
      context: context,
      scrollControlled: true,
      builder: (_) => _FolderPicker(course: course),
    );
    if (choice == null) return;
    await ref
        .read(panoptoProvider.notifier)
        .setFolders(course.id, choice.folders);
  }
}

/// Which group's recordings a meeting gets, with the suggestion selected.
class _GroupQuestionCard extends StatefulWidget {
  const _GroupQuestionCard({
    super.key,
    required this.question,
    required this.meetingLabel,
    required this.busy,
    required this.onAnswer,
  });

  final GroupQuestion question;
  final String meetingLabel;
  final bool busy;
  final ValueChanged<String> onAnswer;

  @override
  State<_GroupQuestionCard> createState() => _GroupQuestionCardState();
}

class _GroupQuestionCardState extends State<_GroupQuestionCard> {
  late String? _selected = widget.question.suggested;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final q = widget.question;
    final hint = switch (q.hint) {
      GroupHint.links => l.panoptoHintLinks,
      GroupHint.room => l.panoptoHintRoom,
      null => null,
    };
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.panoptoGroupQuestion(widget.meetingLabel)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in q.options)
                  ChoiceChip(
                    label: Text(
                      [
                        l.panoptoGroupOption(o.group),
                        if (o.room != null) o.room!,
                      ].join(' · '),
                    ),
                    selected: _selected == o.group,
                    onSelected: (_) => setState(() => _selected = o.group),
                  ),
              ],
            ),
            if (hint != null && _selected == q.suggested) ...[
              const SizedBox(height: 8),
              Text(hint, style: theme.textTheme.bodySmall),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: FilledButton(
                onPressed: _selected == null || widget.busy
                    ? null
                    : () => widget.onAnswer(_selected!),
                child: Text(l.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The picker's answer: null folders = find them by the course number.
class _FolderChoice {
  const _FolderChoice(this.folders);
  final List<PanoptoFolderRef>? folders;
}

class _FolderPicker extends ConsumerStatefulWidget {
  const _FolderPicker({required this.course});

  final CourseInfo course;

  @override
  ConsumerState<_FolderPicker> createState() => _FolderPickerState();
}

class _FolderPickerState extends ConsumerState<_FolderPicker> {
  late final _query = TextEditingController(text: widget.course.code);
  final _link = TextEditingController();
  List<PanoptoFolderRef>? _results;
  String? _error;
  bool _searching = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    if (_query.text.isNotEmpty) _search();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _link.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final text = _query.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final found = await ref
          .read(panoptoProvider.notifier)
          .searchFolders(text);
      if (mounted) setState(() => _results = found);
    } on PanoptoException catch (e) {
      if (mounted) {
        setState(
          () => _error = panoptoErrorText(e.code, AppLocalizations.of(context)),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _fromLink() async {
    final l = AppLocalizations.of(context);
    final controller = ref.read(panoptoProvider.notifier);
    if (PanoptoController.folderIdOf(_link.text) == null) {
      setState(() => _error = l.panoptoFolderLinkInvalid);
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
    });
    try {
      final folder = await controller.folderFromLink(_link.text);
      if (!mounted) return;
      if (folder == null) {
        setState(() => _error = l.panoptoFolderNotFound);
      } else {
        Navigator.pop(context, _FolderChoice([folder]));
      }
    } on PanoptoException catch (e) {
      if (mounted) setState(() => _error = panoptoErrorText(e.code, l));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final results = _results;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                l.panoptoFolder,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: TextField(
                controller: _query,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: l.panoptoFolderSearch,
                  prefixIcon: const Icon(LecIcons.search),
                ),
                onChanged: (_) {
                  _debounce?.cancel();
                  _debounce = Timer(const Duration(milliseconds: 500), _search);
                },
                onSubmitted: (_) => _search(),
              ),
            ),
            if (_searching) const LinearProgressIndicator(),
            if (_error != null)
              ListTile(
                leading: const Icon(LecIcons.warning),
                subtitle: Text(_error!),
              ),
            if (results != null && results.isEmpty && !_searching)
              ListTile(subtitle: Text(l.panoptoFolderNotFound)),
            for (final f in results ?? const <PanoptoFolderRef>[])
              ListTile(
                leading: const Icon(LecIcons.recording),
                title: Text(f.name),
                onTap: () => Navigator.pop(context, _FolderChoice([f])),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: TextField(
                controller: _link,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                  labelText: l.panoptoFolderLink,
                  prefixIcon: const Icon(LecIcons.link),
                ),
                onSubmitted: (_) => _fromLink(),
              ),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 8),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: _searching ? null : _fromLink,
                  child: Text(l.ok),
                ),
              ),
            ),
            const Divider(),
            if (widget.course.code.trim().isNotEmpty)
              ListTile(
                leading: const Icon(LecIcons.search),
                title: Text(l.panoptoFolderAutoOption),
                onTap: () => Navigator.pop(context, const _FolderChoice(null)),
              ),
            ListTile(
              leading: const Icon(LecIcons.close),
              title: Text(l.panoptoFolderNoneOption),
              onTap: () => Navigator.pop(context, const _FolderChoice([])),
            ),
          ],
        ),
      ),
    );
  }
}
