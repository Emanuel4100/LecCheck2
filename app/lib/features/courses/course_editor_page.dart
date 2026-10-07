import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/shortcuts.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/motion.dart';
import '../../app/widgets/common.dart';
import '../../core/db/schedule_repository.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/local_date.dart';
import '../../domain/schedule_types.dart';
import '../../domain/semester_calendar.dart';
import '../../domain/semester_data.dart';
import '../../l10n/gen/app_localizations.dart';

class _LinkDraft {
  _LinkDraft([NamedLink? link])
    : title = TextEditingController(text: link?.title ?? ''),
      url = TextEditingController(text: link?.url ?? '');

  final TextEditingController title;
  final TextEditingController url;

  NamedLink? toLink() => url.text.trim().isEmpty
      ? null
      : NamedLink(title: title.text.trim(), url: url.text.trim());

  void dispose() {
    title.dispose();
    url.dispose();
  }
}

class _MeetingDraft {
  _MeetingDraft({
    required this.id,
    required this.type,
    required this.kind,
    required this.weekday,
    required this.date,
    required this.startMin,
    required this.endMin,
    required String location,
    required this.intervalWeeks,
    required this.validFrom,
    required this.validUntil,
    List<NamedLink> links = const [],
  }) : location = TextEditingController(text: location),
       links = [for (final l in links) _LinkDraft(l)];

  factory _MeetingDraft.from(MeetingRule m) => _MeetingDraft(
    id: m.id,
    type: m.type,
    kind: m.kind,
    weekday: m.weekday ?? DateTime.sunday,
    date: m.date,
    startMin: m.startMin,
    endMin: m.endMin,
    location: m.location,
    intervalWeeks: m.intervalWeeks,
    validFrom: m.validFrom,
    validUntil: m.validUntil,
    links: m.links,
  );

  final String id;
  SessionType type;
  MeetingKind kind;
  int weekday;
  LocalDate? date;
  int startMin;
  int endMin;
  final TextEditingController location;
  int intervalWeeks;
  LocalDate? validFrom;
  LocalDate? validUntil;
  final List<_LinkDraft> links;
  bool expanded = false;

  bool get valid =>
      endMin > startMin && (kind == MeetingKind.weekly || date != null);

  MeetingRule toRule(String courseId) => MeetingRule(
    id: id,
    courseId: courseId,
    type: type,
    kind: kind,
    weekday: kind == MeetingKind.weekly ? weekday : null,
    date: kind == MeetingKind.once ? date : null,
    startMin: startMin,
    endMin: endMin,
    location: location.text.trim(),
    intervalWeeks: kind == MeetingKind.weekly ? intervalWeeks : 1,
    validFrom: validFrom,
    validUntil: validUntil,
    links: [for (final l in links) ?l.toLink()],
  );

  void dispose() {
    location.dispose();
    for (final l in links) {
      l.dispose();
    }
  }
}

class _RequirementDraft {
  _RequirementDraft({
    required this.id,
    this.type,
    this.minPercent = 80,
    this.recordingsCount = false,
  });

  final String id;
  SessionType? type;
  int minPercent;
  bool recordingsCount;

  AttendanceRequirement toRequirement(String courseId) => AttendanceRequirement(
    id: id,
    courseId: courseId,
    type: type,
    minPercent: minPercent,
    recordingsCount: recordingsCount,
  );
}

class CourseEditorPage extends ConsumerStatefulWidget {
  const CourseEditorPage({
    super.key,
    this.courseId,
    this.startWithOneTime = false,
  });

  final String? courseId;
  final bool startWithOneTime;

  @override
  ConsumerState<CourseEditorPage> createState() => _CourseEditorPageState();
}

class _CourseEditorPageState extends ConsumerState<CourseEditorPage> {
  final _name = TextEditingController();
  final _shortName = TextEditingController();
  final _code = TextEditingController();
  final _lecturer = TextEditingController();
  final _website = TextEditingController();
  final _notes = TextEditingController();
  final _links = <_LinkDraft>[];
  final _meetings = <_MeetingDraft>[];
  final _requirements = <_RequirementDraft>[];
  String _colorKey = 'ocean';
  int _sortOrder = 0;
  bool _initialized = false;
  bool _showErrors = false;
  String? _initialSnapshot;

  late SemesterData? _data = ref.read(semesterDataProvider).value;

  CourseInfo? get _existing =>
      widget.courseId == null ? null : _data?.course(widget.courseId!);

  /// The course as the editor loaded it; saving writes only what changed
  /// since, so edits synced in from another device meanwhile survive.
  CourseBase? _base;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final existing = _existing;
    final data = _data;
    if (existing != null && data != null) {
      _base = CourseBase(
        course: existing,
        meetings: data.meetingsOf(existing.id),
        requirements: data.requirementsOf(existing.id),
      );
      _name.text = existing.name;
      _shortName.text = existing.shortName;
      _code.text = existing.code;
      _lecturer.text = existing.lecturer;
      _website.text = existing.website;
      _notes.text = existing.notes;
      _colorKey = existing.colorKey;
      _sortOrder = existing.sortOrder;
      _links.addAll(existing.links.map(_LinkDraft.new));
      _meetings.addAll(data.meetingsOf(existing.id).map(_MeetingDraft.from));
      _requirements.addAll(
        data
            .requirementsOf(existing.id)
            .map(
              (r) => _RequirementDraft(
                id: r.id,
                type: r.type,
                minPercent: r.minPercent,
                recordingsCount: r.recordingsCount,
              ),
            ),
      );
    } else {
      final used = {...?data?.courses.map((c) => c.colorKey)};
      _colorKey = coursePaletteSeeds.keys.firstWhere(
        (k) => !used.contains(k),
        orElse: () => coursePaletteSeeds.keys.first,
      );
      _sortOrder = data?.courses.length ?? 0;
      _meetings.add(
        _newMeeting(
          widget.startWithOneTime ? MeetingKind.once : MeetingKind.weekly,
        ),
      );
    }
    _initialSnapshot = _snapshot();
    if (existing != null && widget.startWithOneTime) {
      _meetings.add(_newMeeting(MeetingKind.once));
    }
  }

  _MeetingDraft _newMeeting(MeetingKind kind) {
    final semester = _data?.semester;
    final firstDay = semester == null
        ? DateTime.sunday
        : SemesterCalendar(semester)
              .visibleDatesOfWeek(semester.start)
              .firstOrNull
              ?.weekday;
    final last = _meetings.lastOrNull;
    return _MeetingDraft(
      id: ScheduleRepository.newId(),
      type: last == null ? SessionType.lecture : SessionType.practice,
      kind: kind,
      weekday: firstDay ?? DateTime.sunday,
      date: kind == MeetingKind.once ? LocalDate.today() : null,
      startMin: 10 * 60,
      endMin: 12 * 60,
      location: '',
      intervalWeeks: 1,
      validFrom: null,
      validUntil: null,
    );
  }

  /// Serialized form state, used to detect unsaved changes.
  String _snapshot() => [
    _name.text,
    _shortName.text,
    _code.text,
    _lecturer.text,
    _website.text,
    _notes.text,
    _colorKey,
    for (final l in _links) '${l.title.text}|${l.url.text}',
    for (final m in _meetings)
      '${m.id}|${m.type}|${m.kind}|${m.weekday}|${m.date}|${m.startMin}|'
          '${m.endMin}|${m.location.text}|${m.intervalWeeks}|${m.validFrom}|'
          '${m.links.map((l) => '${l.title.text}>${l.url.text}').join(',')}',
    for (final r in _requirements)
      '${r.id}|${r.type}|${r.minPercent}|${r.recordingsCount}',
  ].join('\n');

  bool get _dirty => _snapshot() != _initialSnapshot;

  @override
  void dispose() {
    for (final c in [_name, _shortName, _code, _lecturer, _website, _notes]) {
      c.dispose();
    }
    for (final l in _links) {
      l.dispose();
    }
    for (final m in _meetings) {
      m.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final semester = _data?.semester;
    if (semester == null) return;
    if (_name.text.trim().isEmpty || _meetings.any((m) => !m.valid)) {
      setState(() => _showErrors = true);
      return;
    }
    final id = widget.courseId ?? ScheduleRepository.newId();
    final meetings = [for (final m in _meetings) m.toRule(id)];

    final split = await _confirmWeekdayChanges(meetings);
    if (split == null) return;

    await ref
        .read(repositoryProvider)
        .saveCourse(
          CourseInfo(
            id: id,
            semesterId: semester.id,
            name: _name.text.trim(),
            shortName: _shortName.text.trim(),
            code: _code.text.trim(),
            lecturer: _lecturer.text.trim(),
            colorKey: _colorKey,
            website: _website.text.trim(),
            notes: _notes.text.trim(),
            links: [for (final l in _links) ?l.toLink()],
            sortOrder: _sortOrder,
          ),
          meetings: split,
          requirements: [for (final r in _requirements) r.toRequirement(id)],
          base: _base,
        );
    _initialSnapshot = _snapshot();
    if (mounted) context.pop();
  }

  /// When a weekly meeting moves to another weekday mid-semester, asks whether
  /// the change applies to all weeks or only from this week on. "From this
  /// week on" keeps past sessions (and their marks) on the old day.
  Future<List<MeetingRule>?> _confirmWeekdayChanges(
    List<MeetingRule> meetings,
  ) async {
    final data = _data;
    if (data == null || widget.courseId == null) return meetings;
    final today = ref.read(todayProvider);
    final semester = data.semester;
    final thisWeek = startOfWeek(today, semester.weekStart);
    if (!thisWeek.isAfter(semester.start)) return meetings;

    final changed = [
      for (final m in meetings)
        if (data.meeting(m.id) case final old?
            when old.kind == MeetingKind.weekly &&
                m.kind == MeetingKind.weekly &&
                old.weekday != m.weekday)
          m,
    ];
    if (changed.isEmpty) return meetings;

    final l = AppLocalizations.of(context);
    final fromThisWeek = await showChoiceDialog<bool?>(
      context,
      title: l.applyChangeTitle,
      choices: [
        DialogChoice(l.cancel, null),
        DialogChoice(l.applyAllWeeks, false),
        DialogChoice(l.applyFromThisWeek, true, primary: true),
      ],
    );
    if (fromThisWeek == null) return null;
    if (!fromThisWeek) return meetings;

    final result = <MeetingRule>[];
    for (final m in meetings) {
      if (!changed.contains(m)) {
        result.add(m);
        continue;
      }
      final old = data.meeting(m.id)!;
      result
        ..add(
          MeetingRule(
            id: old.id,
            courseId: old.courseId,
            type: old.type,
            kind: old.kind,
            weekday: old.weekday,
            startMin: old.startMin,
            endMin: old.endMin,
            location: old.location,
            intervalWeeks: old.intervalWeeks,
            validFrom: old.validFrom,
            validUntil: thisWeek.addDays(-1),
            links: old.links,
          ),
        )
        ..add(
          MeetingRule(
            id: ScheduleRepository.newId(),
            courseId: m.courseId,
            type: m.type,
            kind: m.kind,
            weekday: m.weekday,
            startMin: m.startMin,
            endMin: m.endMin,
            location: m.location,
            intervalWeeks: m.intervalWeeks,
            validFrom: thisWeek,
            validUntil: m.validUntil,
            links: m.links,
          ),
        );
    }
    return result;
  }

  Future<void> _delete() async {
    final l = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l.deleteCourseTitle,
      body: l.deleteCourseBody,
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final repo = ref.read(repositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final receipt = await repo.deleteCourse(widget.courseId!);
    _initialSnapshot = _snapshot();
    router.go('/courses');
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.courseDeleted),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => repo.undoDeletion(receipt),
        ),
      ),
    );
  }

  Future<bool> _confirmDiscard() async {
    final l = AppLocalizations.of(context);
    return await showChoiceDialog<bool>(
          context,
          title: l.discardChangesTitle,
          body: l.discardChangesBody,
          choices: [
            DialogChoice(l.discard, true, destructive: true),
            DialogChoice(l.keepEditing, false, primary: true),
          ],
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    _data = ref.watch(semesterDataProvider).value ?? _data;
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final nameError = _showErrors && _name.text.trim().isEmpty;

    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmDiscard() && context.mounted) {
          _initialSnapshot = _snapshot();
          context.pop();
        }
      },
      child: PageShortcuts(
        // A new course starts in the name field instead.
        autofocus: widget.courseId != null,
        bindings: {primaryKey(LogicalKeyboardKey.keyS): _save},
        child: Scaffold(
          appBar: AppBar(
            title: Text(widget.courseId == null ? l.newCourse : l.editCourse),
            actions: [
              if (widget.courseId != null)
                IconButton(
                  tooltip: l.delete,
                  icon: const Icon(LecIcons.delete),
                  onPressed: _delete,
                ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 8),
                child: FilledButton(onPressed: _save, child: Text(l.save)),
              ),
            ],
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                children: [
                  TextField(
                    controller: _name,
                    autofocus: widget.courseId == null,
                    textCapitalization: TextCapitalization.sentences,
                    style: theme.textTheme.titleLarge,
                    decoration: InputDecoration(
                      labelText: l.courseName,
                      errorText: nameError ? l.courseNameRequired : null,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _shortName,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      labelText: '${l.shortName} (${l.optional})',
                      helperText: l.shortNameHelper,
                    ),
                  ),
                  // Clear of the helper text, for the floating labels below.
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _code,
                          decoration: InputDecoration(
                            labelText: '${l.courseCode} (${l.optional})',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _lecturer,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: '${l.lecturer} (${l.optional})',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(l.courseColor, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 10),
                  _ColorPicker(
                    selected: _colorKey,
                    onSelected: (k) => setState(() => _colorKey = k),
                  ),
                  SectionHeader(
                    title: l.meetingsSection,
                    padding: const EdgeInsetsDirectional.fromSTEB(4, 28, 0, 8),
                  ),
                  if (_meetings.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(
                        l.noMeetingsYet,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  for (final m in _meetings)
                    Padding(
                      key: ValueKey(m.id),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _MeetingCard(
                        draft: m,
                        semester: _data?.semester,
                        showErrors: _showErrors,
                        onChanged: () => setState(() {}),
                        onRemove: () => setState(() {
                          _meetings.remove(m);
                          m.dispose();
                        }),
                      ),
                    ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => setState(
                          () => _meetings.add(_newMeeting(MeetingKind.weekly)),
                        ),
                        icon: const Icon(LecIcons.add),
                        label: Text(l.addMeeting),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => setState(
                          () => _meetings.add(_newMeeting(MeetingKind.once)),
                        ),
                        icon: const Icon(LecIcons.date),
                        label: Text(l.addOneTimeSession),
                      ),
                    ],
                  ),
                  SectionHeader(
                    title: l.requirementsSection,
                    subtitle: l.requirementsHint,
                    padding: const EdgeInsetsDirectional.fromSTEB(4, 28, 0, 8),
                  ),
                  for (final r in _requirements)
                    _RequirementRow(
                      key: ValueKey(r.id),
                      draft: r,
                      onChanged: () => setState(() {}),
                      onRemove: () => setState(() => _requirements.remove(r)),
                    ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      onPressed: () => setState(
                        () => _requirements.add(
                          _RequirementDraft(id: ScheduleRepository.newId()),
                        ),
                      ),
                      icon: const Icon(LecIcons.target),
                      label: Text(l.addRequirement),
                    ),
                  ),
                  SectionHeader(
                    title: l.courseNotes,
                    padding: const EdgeInsetsDirectional.fromSTEB(4, 28, 0, 8),
                  ),
                  TextField(
                    controller: _notes,
                    minLines: 3,
                    maxLines: 8,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(hintText: l.courseNotesHint),
                  ),
                  SectionHeader(
                    title: l.extraLinks,
                    padding: const EdgeInsetsDirectional.fromSTEB(4, 28, 0, 8),
                  ),
                  TextField(
                    controller: _website,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(
                      labelText: l.courseWebsite,
                      prefixIcon: const Icon(LecIcons.link),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _LinksEditor(links: _links, onChanged: () => setState(() {})),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  const _ColorPicker({required this.selected, required this.onSelected});

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = CourseColors.of(context);
    final motion = AppMotion.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final key in colors.keys)
          GestureDetector(
            onTap: () => onSelected(key),
            child: AnimatedContainer(
              duration: motion.medium,
              curve: motion.spatialFast,
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colors.tone(key).accent,
                borderRadius: BorderRadius.circular(key == selected ? 14 : 20),
                border: Border.all(
                  color: key == selected
                      ? scheme.onSurface
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: key == selected
                  ? Icon(LecIcons.check, color: scheme.surface, size: 22)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _MeetingCard extends StatelessWidget {
  const _MeetingCard({
    required this.draft,
    required this.semester,
    required this.showErrors,
    required this.onChanged,
    required this.onRemove,
  });

  final _MeetingDraft draft;
  final SemesterInfo? semester;
  final bool showErrors;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  Future<void> _pickTime(BuildContext context, bool start) async {
    final minutes = await pickTime(
      context,
      start ? draft.startMin : draft.endMin,
    );
    if (minutes == null) return;
    if (start) {
      final length = draft.endMin - draft.startMin;
      draft.startMin = minutes;
      draft.endMin = (minutes + (length > 0 ? length : 60)).clamp(
        minutes + 5,
        24 * 60 - 1,
      );
    } else {
      draft.endMin = minutes;
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final days = semester == null
        ? const [7, 1, 2, 3, 4, 5, 6]
        : [for (var i = 0; i < 7; i++) (semester!.weekStart - 1 + i) % 7 + 1]
              .where(
                (d) => semester!.visibleDays.contains(d) || d == draft.weekday,
              )
              .toList();
    final timeError = showErrors && draft.endMin <= draft.startMin;
    final dateError =
        showErrors && draft.kind == MeetingKind.once && draft.date == null;

    return Card(
      color: theme.colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final t in SessionType.values)
                        ChoiceChip(
                          avatar: Icon(t.icon, size: 18),
                          showCheckmark: false,
                          label: Text(t.label(l)),
                          selected: draft.type == t,
                          onSelected: (_) {
                            draft.type = t;
                            onChanged();
                          },
                        ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.removeMeeting,
                  icon: const Icon(LecIcons.delete),
                  onPressed: onRemove,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(l.weekly),
                  selected: draft.kind == MeetingKind.weekly,
                  onSelected: (_) {
                    draft.kind = MeetingKind.weekly;
                    onChanged();
                  },
                ),
                ChoiceChip(
                  label: Text(l.oneTime),
                  selected: draft.kind == MeetingKind.once,
                  onSelected: (_) {
                    draft.kind = MeetingKind.once;
                    draft.date ??= LocalDate.today();
                    onChanged();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (draft.kind == MeetingKind.weekly)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final d in days)
                    ChoiceChip(
                      label: Text(fmt.isoWeekdayShort(d)),
                      selected: draft.weekday == d,
                      onSelected: (_) {
                        draft.weekday = d;
                        onChanged();
                      },
                    ),
                ],
              )
            else
              ActionChip(
                avatar: const Icon(LecIcons.date, size: 18),
                label: Text(
                  draft.date == null ? l.date : fmt.longDate(draft.date!),
                  style: dateError
                      ? TextStyle(color: theme.colorScheme.error)
                      : null,
                ),
                onPressed: () async {
                  final picked = await pickDate(
                    context,
                    draft.date ?? LocalDate.today(),
                  );
                  if (picked != null) {
                    draft.date = picked;
                    onChanged();
                  }
                },
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _TimeButton(
                    label: l.startTime,
                    value: fmt.time(draft.startMin),
                    onTap: () => _pickTime(context, true),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _TimeButton(
                    label: l.endTime,
                    value: fmt.time(draft.endMin),
                    error: timeError,
                    onTap: () => _pickTime(context, false),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            if (timeError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  l.endAfterStartError,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: TextField(
                controller: draft.location,
                decoration: InputDecoration(
                  labelText: l.location,
                  prefixIcon: const Icon(LecIcons.location),
                ),
                onChanged: (_) => onChanged(),
              ),
            ),
            if (draft.kind == MeetingKind.weekly) ...[
              const SizedBox(height: 4),
              SwitchListTile.adaptive(
                contentPadding: const EdgeInsetsDirectional.only(end: 8),
                title: Text(l.everyOtherWeek),
                value: draft.intervalWeeks == 2,
                onChanged: (on) {
                  draft.intervalWeeks = on ? 2 : 1;
                  if (!on) draft.validFrom = null;
                  onChanged();
                },
              ),
              if (draft.intervalWeeks == 2 && semester != null)
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: Text(l.firstWeek),
                      selected:
                          draft.validFrom == null ||
                          !draft.validFrom!.isAfter(
                            startOfWeek(
                              semester!.start,
                              semester!.weekStart,
                            ).addDays(6),
                          ),
                      onSelected: (_) {
                        draft.validFrom = null;
                        onChanged();
                      },
                    ),
                    ChoiceChip(
                      label: Text(l.secondWeek),
                      selected:
                          draft.validFrom != null &&
                          draft.validFrom!.isAfter(
                            startOfWeek(
                              semester!.start,
                              semester!.weekStart,
                            ).addDays(6),
                          ),
                      onSelected: (_) {
                        draft.validFrom = startOfWeek(
                          semester!.start,
                          semester!.weekStart,
                        ).addDays(7);
                        onChanged();
                      },
                    ),
                  ],
                ),
            ],
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8, top: 8),
              child: _LinksEditor(
                links: draft.links,
                onChanged: onChanged,
                addLabel: l.meetingLinks,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
    this.error = false,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(LecIcons.time),
          errorText: error ? '' : null,
          errorStyle: const TextStyle(height: 0, fontSize: 0),
        ),
        child: Text(value, style: theme.textTheme.titleMedium),
      ),
    );
  }
}

class _LinksEditor extends StatelessWidget {
  const _LinksEditor({
    required this.links,
    required this.onChanged,
    this.addLabel,
  });

  final List<_LinkDraft> links;
  final VoidCallback onChanged;
  final String? addLabel;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final link in links)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: link.title,
                    decoration: InputDecoration(labelText: l.linkTitle),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: link.url,
                    keyboardType: TextInputType.url,
                    decoration: InputDecoration(labelText: l.linkUrl),
                    onChanged: (_) => onChanged(),
                  ),
                ),
                IconButton(
                  tooltip: l.remove,
                  icon: const Icon(LecIcons.close),
                  onPressed: () {
                    links.remove(link);
                    link.dispose();
                    onChanged();
                  },
                ),
              ],
            ),
          ),
        TextButton.icon(
          onPressed: () {
            links.add(_LinkDraft());
            onChanged();
          },
          icon: const Icon(LecIcons.link),
          label: Text(addLabel ?? l.addLink),
        ),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  const _RequirementRow({
    super.key,
    required this.draft,
    required this.onChanged,
    required this.onRemove,
  });

  final _RequirementDraft draft;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surfaceContainer,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(l.appliesTo, style: theme.textTheme.titleSmall),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<SessionType?>(
                    isExpanded: true,
                    value: draft.type,
                    underline: const SizedBox.shrink(),
                    items: [
                      DropdownMenuItem(value: null, child: Text(l.allTypes)),
                      for (final t in SessionType.values)
                        DropdownMenuItem(value: t, child: Text(t.label(l))),
                    ],
                    onChanged: (t) {
                      draft.type = t;
                      onChanged();
                    },
                  ),
                ),
                IconButton(
                  tooltip: l.remove,
                  icon: const Icon(LecIcons.close),
                  onPressed: onRemove,
                ),
              ],
            ),
            Row(
              children: [
                Text(l.minAttendance),
                Expanded(
                  child: Slider(
                    value: draft.minPercent.toDouble(),
                    min: 50,
                    max: 100,
                    divisions: 10,
                    label: '${draft.minPercent}%',
                    onChanged: (v) {
                      draft.minPercent = v.round();
                      onChanged();
                    },
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${draft.minPercent}%',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text(l.recordingsCount),
              value: draft.recordingsCount,
              onChanged: (v) {
                draft.recordingsCount = v;
                onChanged();
              },
            ),
          ],
        ),
      ),
    );
  }
}
