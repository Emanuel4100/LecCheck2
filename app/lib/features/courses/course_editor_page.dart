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
import '../../domain/occurrence_engine.dart';
import '../../domain/schedule_types.dart';
import '../../domain/semester_calendar.dart';
import '../../domain/semester_data.dart';
import '../../domain/short_name.dart';
import '../../l10n/gen/app_localizations.dart';
import 'contacts_editor.dart';
import 'meeting_sheet.dart';
import 'meeting_summary.dart';

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

/// A course's name and details, with its meetings as one-line rows that
/// open a sheet, and the rarer parts (requirement, notes, links) folded into
/// rows too. Two columns on wide windows.
class CourseEditorPage extends ConsumerStatefulWidget {
  const CourseEditorPage({
    super.key,
    this.courseId,
    this.startWithOneTime = false,
    this.seed,
    this.name = '',
  });

  final String? courseId;

  /// A new course's name, typed in Week's quick add.
  final String name;

  /// Opens the sheet on a new one-time meeting.
  final bool startWithOneTime;

  /// A new meeting at this day and time (a tap on the Week grid): in the
  /// sheet for an existing course, in the list for a new one.
  final MeetingSeed? seed;

  @override
  ConsumerState<CourseEditorPage> createState() => _CourseEditorPageState();
}

class _CourseEditorPageState extends ConsumerState<CourseEditorPage> {
  final _name = TextEditingController();
  final _shortName = TextEditingController();
  final _code = TextEditingController();
  final _website = TextEditingController();
  final _notes = TextEditingController();
  final _shortNameFocus = FocusNode();
  final _codeFocus = FocusNode();
  final _links = <LinkDraft>[];
  final _contacts = <ContactDraft>[];
  final _meetings = <MeetingDraft>[];
  final _requirements = <_RequirementDraft>[];

  /// Meetings taken out while their sheet may still be closing; disposed
  /// with the page.
  final _retired = <MeetingDraft>[];
  String _colorKey = 'ocean';
  int _sortOrder = 0;
  bool _initialized = false;
  bool _showErrors = false;

  /// Optional fields shown after tapping their "+" chip (or because they
  /// have a value).
  bool _showShortName = false;
  bool _showCode = false;
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
      _website.text = existing.website;
      _notes.text = existing.notes;
      _colorKey = existing.colorKey;
      _sortOrder = existing.sortOrder;
      _links.addAll(existing.links.map(LinkDraft.new));
      // Courses from before contacts: the lecturer becomes the first one.
      _contacts.addAll(
        existing.contacts.isNotEmpty || existing.lecturer.isEmpty
            ? existing.contacts.map(ContactDraft.new)
            : [ContactDraft(CourseContact(name: existing.lecturer))],
      );
      _meetings.addAll(data.meetingsOf(existing.id).map(MeetingDraft.from));
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
      _name.text = widget.name;
      // From the Week grid: the meeting is there, the name comes first.
      if (widget.seed case final seed?) {
        _meetings.add(_newMeeting(MeetingKind.weekly, seed: seed));
      }
    }
    _initialSnapshot = _snapshot();
    if (existing != null && (widget.startWithOneTime || widget.seed != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _addMeeting(
          widget.startWithOneTime ? MeetingKind.once : MeetingKind.weekly,
          seed: widget.seed,
        );
      });
    }
  }

  MeetingDraft _newMeeting(MeetingKind kind, {MeetingSeed? seed}) {
    final semester = _data?.semester;
    final firstDay = semester == null
        ? DateTime.sunday
        : SemesterCalendar(semester)
              .visibleDatesOfWeek(semester.start)
              .firstOrNull
              ?.weekday;
    final once = kind == MeetingKind.once || seed?.date != null;
    final last = _meetings.lastOrNull;
    return MeetingDraft(
      id: ScheduleRepository.newId(),
      type:
          seed?.type ??
          (last == null ? SessionType.lecture : SessionType.practice),
      kind: once ? MeetingKind.once : MeetingKind.weekly,
      weekday: seed?.weekday ?? seed?.date?.weekday ?? firstDay ?? 7,
      date: once ? seed?.date ?? LocalDate.today() : null,
      startMin: seed?.startMin ?? 10 * 60,
      endMin: seed?.endMin ?? 12 * 60,
      location: seed?.location ?? '',
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
    _website.text,
    _notes.text,
    _colorKey,
    for (final l in _links) '${l.title.text}|${l.url.text}',
    for (final c in _contacts) '${c.name.text}|${c.role}|${c.email.text}',
    for (final m in _meetings)
      '${m.id}|${m.type}|${m.kind}|${m.weekday}|${m.date}|${m.startMin}|'
          '${m.endMin}|${m.location.text}|${m.intervalWeeks}|${m.validFrom}|'
          '${m.validUntil}|'
          '${m.links.map((l) => '${l.title.text}>${l.url.text}').join(',')}',
    for (final r in _requirements)
      '${r.id}|${r.type}|${r.minPercent}|${r.recordingsCount}',
  ].join('\n');

  bool get _dirty => _snapshot() != _initialSnapshot;

  @override
  void dispose() {
    for (final c in [_name, _shortName, _code, _website, _notes]) {
      c.dispose();
    }
    for (final f in [_shortNameFocus, _codeFocus]) {
      f.dispose();
    }
    for (final l in _links) {
      l.dispose();
    }
    for (final c in _contacts) {
      c.dispose();
    }
    for (final m in [..._meetings, ..._retired]) {
      m.dispose();
    }
    super.dispose();
  }

  /// A new meeting in the sheet; added (one per chosen day) with Add.
  Future<void> _addMeeting(MeetingKind kind, {MeetingSeed? seed}) async {
    final draft = _newMeeting(kind, seed: seed);
    final result = await showMeetingSheet(
      context,
      draft: draft,
      semester: _data?.semester,
      isNew: true,
    );
    if (!mounted) return;
    if (result == null || result.remove) {
      _retired.add(draft);
      return;
    }
    setState(() {
      final [first, ...others] = draft.kind == MeetingKind.weekly
          ? result.weekdays
          : [draft.weekday];
      _meetings.add(draft..weekday = first);
      for (final day in others) {
        _meetings.add(draft.copyOn(ScheduleRepository.newId(), day));
      }
    });
  }

  Future<void> _editMeeting(MeetingDraft m) async {
    final result = await showMeetingSheet(
      context,
      draft: m,
      semester: _data?.semester,
      isNew: false,
      onChanged: () => setState(() {}),
    );
    if (result != null && result.remove && mounted) await _removeMeeting(m);
  }

  Future<void> _pickColor() async {
    final l = AppLocalizations.of(context);
    final picked = await showAppSheet<String>(
      context: context,
      builder: (sheet) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.courseColor, style: Theme.of(sheet).textTheme.titleLarge),
            const SizedBox(height: 16),
            _ColorPicker(
              selected: _colorKey,
              onSelected: (k) => Navigator.pop(sheet, k),
            ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) setState(() => _colorKey = picked);
  }

  Future<void> _editRequirements() => showAppSheet<void>(
    context: context,
    scrollControlled: true,
    builder: (_) => _RequirementsSheet(
      requirements: _requirements,
      onChanged: () => setState(() {}),
    ),
  );

  Future<void> _editContacts() => showAppSheet<void>(
    context: context,
    scrollControlled: true,
    builder: (_) =>
        _ContactsSheet(contacts: _contacts, onChanged: () => setState(() {})),
  );

  Future<void> _editNotes() => showAppSheet<void>(
    context: context,
    scrollControlled: true,
    builder: (_) => _NotesSheet(
      notes: _notes,
      website: _website,
      links: _links,
      onChanged: () => setState(() {}),
    ),
  );

  /// Shows an optional field and puts the cursor in it.
  void _reveal(FocusNode focus, void Function() show) {
    setState(show);
    WidgetsBinding.instance.addPostFrameCallback((_) => focus.requestFocus());
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
    final contacts = [for (final c in _contacts) ?c.toContact()];

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
            lecturer: lecturerNames(contacts),
            colorKey: _colorKey,
            website: _website.text.trim(),
            notes: _notes.text.trim(),
            links: [for (final l in _links) ?l.toLink()],
            contacts: contacts,
            sortOrder: _sortOrder,
          ),
          meetings: split.meetings,
          requirements: [for (final r in _requirements) r.toRequirement(id)],
          base: _base,
          historyMoves: split.moves,
        );
    _initialSnapshot = _snapshot();
    if (mounted) context.pop();
  }

  /// When a weekly meeting moves to another weekday, asks (mid-semester)
  /// whether the change applies to all weeks or only from this week on, and
  /// says which session records move with it:
  /// - all weeks: every session moves to the new day of its week, marks
  ///   and notes included;
  /// - from this week on: past sessions (and their marks) stay on the old
  ///   day, which ends last week; this week's and later ones move to the
  ///   new meeting.
  Future<({List<MeetingRule> meetings, List<HistoryMove> moves})?>
  _confirmWeekdayChanges(List<MeetingRule> meetings) async {
    final data = _data;
    if (data == null || widget.courseId == null) {
      return (meetings: meetings, moves: const <HistoryMove>[]);
    }
    final semester = data.semester;
    final changed = [
      for (final m in meetings)
        if (data.meeting(m.id) case final old?
            when old.kind == MeetingKind.weekly &&
                m.kind == MeetingKind.weekly &&
                old.weekday != m.weekday)
          m,
    ];
    if (changed.isEmpty) {
      return (meetings: meetings, moves: const <HistoryMove>[]);
    }
    HistoryMove allWeeks(MeetingRule m) => HistoryMove(
      fromMeetingId: m.id,
      toMeetingId: m.id,
      toWeekday: m.weekday!,
      weekStart: semester.weekStart,
    );

    final today = ref.read(todayProvider);
    final thisWeek = startOfWeek(today, semester.weekStart);
    // Before the semester starts, the new day simply applies to every week.
    if (!thisWeek.isAfter(semester.start)) {
      return (
        meetings: meetings,
        moves: [for (final m in changed) allWeeks(m)],
      );
    }

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
    if (!fromThisWeek) {
      return (
        meetings: meetings,
        moves: [for (final m in changed) allWeeks(m)],
      );
    }

    final result = <MeetingRule>[];
    final moves = <HistoryMove>[];
    for (final m in meetings) {
      if (!changed.contains(m)) {
        result.add(m);
        continue;
      }
      final old = data.meeting(m.id)!;
      final next = ScheduleRepository.newId();
      // Every other week: keep the same weeks, not a cycle restarting now.
      final from = m.intervalWeeks == old.intervalWeeks
          ? OccurrenceEngine.nextWeekOnCycle(old, semester, thisWeek)
          : thisWeek;
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
            id: next,
            courseId: m.courseId,
            type: m.type,
            kind: m.kind,
            weekday: m.weekday,
            startMin: m.startMin,
            endMin: m.endMin,
            location: m.location,
            intervalWeeks: m.intervalWeeks,
            validFrom: from,
            validUntil: m.validUntil,
            links: m.links,
          ),
        );
      moves.add(
        HistoryMove(
          fromMeetingId: old.id,
          toMeetingId: next,
          toWeekday: m.weekday!,
          weekStart: semester.weekStart,
          from: thisWeek,
        ),
      );
    }
    return (meetings: result, moves: moves);
  }

  /// Removing a weekly meeting with marked past sessions would take them out
  /// of the stats: offers to end it this week instead (it keeps its past
  /// sessions and stops from this week on).
  Future<void> _removeMeeting(MeetingDraft m) async {
    final data = _data;
    final saved = data?.meeting(m.id);
    if (data != null &&
        saved != null &&
        saved.kind == MeetingKind.weekly &&
        m.kind == MeetingKind.weekly) {
      final thisWeek = startOfWeek(
        ref.read(todayProvider),
        data.semester.weekStart,
      );
      final marked = data.overrides
          .where(
            (o) =>
                o.meetingId == m.id &&
                o.originalDate.isBefore(thisWeek) &&
                (o.status?.isDecided ?? false),
          )
          .length;
      if (marked > 0) {
        final l = AppLocalizations.of(context);
        final end = await showChoiceDialog<bool?>(
          context,
          title: l.removeMeetingTitle,
          body: l.removeMeetingBody(marked),
          choices: [
            DialogChoice(l.cancel, null),
            DialogChoice(l.deleteWithHistory, false, destructive: true),
            DialogChoice(l.endThisWeek, true, primary: true),
          ],
        );
        if (end == null || !mounted) return;
        if (end) {
          setState(() => m.validUntil = thisWeek.addDays(-1));
          return;
        }
      }
    }
    setState(() => _meetings.remove(m));
    _retired.add(m);
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
    final wide = WindowSize.of(context).isWide;

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
          body: wide
              ? Centered(
                  maxWidth: 1040,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ..._details(l, theme),
                              const SizedBox(height: 16),
                              _contactsRow(l),
                              _notesRow(l),
                            ],
                          ),
                        ),
                        const SizedBox(width: 32),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ..._schedule(l, theme, top: 0),
                              const SizedBox(height: 16),
                              _requirementsRow(l),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Centered(
                  maxWidth: 680,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
                    children: [
                      ..._details(l, theme),
                      ..._schedule(l, theme, top: 28),
                      const SizedBox(height: 20),
                      _requirementsRow(l),
                      _contactsRow(l),
                      _notesRow(l),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  /// Name with its color, then the optional fields: as "+" chips until
  /// they're used.
  List<Widget> _details(AppLocalizations l, ThemeData theme) {
    final nameError = _showErrors && _name.text.trim().isEmpty;
    final accent = CourseColors.of(context).tone(_colorKey).accent;
    final showShortName = _showShortName || _shortName.text.isNotEmpty;
    final showCode = _showCode || _code.text.isNotEmpty;
    // A long name: offer the short form the week view would make up, so it
    // can be checked or changed.
    final suggestion = _shortName.text.trim().isEmpty
        ? suggestedShortName(_name.text)
        : null;
    void useSuggestion() => setState(() {
      _shortName.text = suggestion!;
      _showShortName = true;
    });

    final code = TextField(
      controller: _code,
      focusNode: _codeFocus,
      decoration: InputDecoration(labelText: l.courseCode),
      onChanged: (_) => setState(() {}),
    );

    return [
      TextField(
        controller: _name,
        autofocus: widget.courseId == null,
        textCapitalization: TextCapitalization.sentences,
        style: theme.textTheme.titleLarge,
        decoration: InputDecoration(
          labelText: l.courseName,
          errorText: nameError ? l.courseNameRequired : null,
          suffixIcon: IconButton(
            tooltip: l.courseColor,
            onPressed: _pickColor,
            icon: AnimatedContainer(
              duration: AppMotion.of(context).medium,
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: accent,
                shape: BoxShape.circle,
                border: Border.all(color: theme.colorScheme.surface, width: 2),
                boxShadow: [
                  BoxShadow(color: theme.colorScheme.outline, spreadRadius: 1),
                ],
              ),
            ),
          ),
        ),
        onChanged: (_) => setState(() {}),
      ),
      if (!showShortName || !showCode) ...[
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (!showShortName)
              suggestion == null
                  ? _AddFieldChip(
                      label: l.shortName,
                      onPressed: () =>
                          _reveal(_shortNameFocus, () => _showShortName = true),
                    )
                  : ActionChip(
                      avatar: const Icon(LecIcons.check, size: 18),
                      label: Text(l.useShortName(suggestion)),
                      onPressed: useSuggestion,
                    ),
            if (!showCode)
              _AddFieldChip(
                label: l.courseCode,
                onPressed: () => _reveal(_codeFocus, () => _showCode = true),
              ),
          ],
        ),
      ],
      if (showShortName) ...[
        const SizedBox(height: 16),
        TextField(
          controller: _shortName,
          focusNode: _shortNameFocus,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.shortName,
            helperText: l.shortNameHelper,
          ),
          onChanged: (_) => setState(() {}),
        ),
        if (suggestion != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: useSuggestion,
              child: Text(l.useShortName(suggestion)),
            ),
          ),
      ],
      if (showCode) ...[
        // Clear of the helper text above, for the floating labels.
        SizedBox(height: showShortName && suggestion == null ? 20 : 16),
        code,
      ],
    ];
  }

  /// The meetings as one-line rows, and the buttons to add more.
  List<Widget> _schedule(
    AppLocalizations l,
    ThemeData theme, {
    required double top,
  }) {
    final fmt = Fmt.of(context);
    final tone = CourseColors.of(context).tone(_colorKey);
    final semester = _data?.semester;
    return [
      SectionHeader(
        title: l.meetingsSection,
        padding: EdgeInsetsDirectional.fromSTEB(4, top, 0, 4),
      ),
      if (_meetings.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Text(
            l.noMeetingsYet,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      for (final m in _meetings)
        Builder(
          key: ValueKey(m.id),
          builder: (context) {
            final rule = m.toRule('');
            final error = _showErrors && !m.valid;
            return ListTile(
              contentPadding: const EdgeInsetsDirectional.only(
                start: 4,
                end: 4,
              ),
              leading: Icon(
                m.type.icon,
                color: error ? theme.colorScheme.error : tone.accent,
              ),
              title: Text(meetingTitle(rule, l, fmt)),
              subtitle: Text(
                error
                    ? l.endAfterStartError
                    : meetingDetails(rule, semester, l, fmt),
                style: error ? TextStyle(color: theme.colorScheme.error) : null,
              ),
              trailing: const Icon(LecIcons.chevronEnd),
              onTap: () => _editMeeting(m),
            );
          },
        ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.tonalIcon(
            onPressed: () => _addMeeting(MeetingKind.weekly),
            icon: const Icon(LecIcons.add),
            label: Text(l.addMeeting),
          ),
          OutlinedButton.icon(
            onPressed: () => _addMeeting(MeetingKind.once),
            icon: const Icon(LecIcons.date),
            label: Text(l.addOneTimeSession),
          ),
        ],
      ),
    ];
  }

  Widget _requirementsRow(AppLocalizations l) => _FoldedRow(
    icon: LecIcons.target,
    title: l.requirementsSection,
    summary: _requirements.isEmpty
        ? l.requirementsHint
        : _requirements
              .map(
                (r) => '${r.minPercent}% · ${r.type?.label(l) ?? l.allTypes}',
              )
              .join(', '),
    onTap: _editRequirements,
  );

  Widget _contactsRow(AppLocalizations l) {
    final names = [
      for (final c in _contacts)
        if (c.name.text.trim().isNotEmpty)
          c.name.text.trim()
        else if (c.email.text.trim().isNotEmpty)
          c.email.text.trim(),
    ];
    return _FoldedRow(
      icon: LecIcons.contacts,
      title: l.contactsSection,
      summary: names.isEmpty ? l.contactsHint : names.join(', '),
      onTap: _editContacts,
    );
  }

  Widget _notesRow(AppLocalizations l) {
    final links =
        (_website.text.trim().isEmpty ? 0 : 1) +
        _links.where((k) => k.url.text.trim().isNotEmpty).length;
    final notes = _notes.text.trim().split('\n').first;
    return _FoldedRow(
      icon: LecIcons.notes,
      title: l.notesAndLinks,
      summary: notes.isEmpty && links == 0
          ? l.courseNotesHint
          : [
              if (notes.isNotEmpty) notes,
              if (links > 0) l.linksCount(links),
            ].join(' · '),
      onTap: _editNotes,
    );
  }
}

/// "+ Course code": shows an optional field.
class _AddFieldChip extends StatelessWidget {
  const _AddFieldChip({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => ActionChip(
    avatar: const Icon(LecIcons.add, size: 18),
    label: Text(label),
    onPressed: onPressed,
  );
}

/// A part of the course that's set rarely, as one row with a summary.
class _FoldedRow extends StatelessWidget {
  const _FoldedRow({
    required this.icon,
    required this.title,
    required this.summary,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsetsDirectional.only(start: 4, end: 4),
    leading: Icon(icon),
    title: Text(title),
    subtitle: Text(summary, maxLines: 2, overflow: TextOverflow.ellipsis),
    trailing: const Icon(LecIcons.chevronEnd),
    onTap: onTap,
  );
}

class _RequirementsSheet extends StatefulWidget {
  const _RequirementsSheet({
    required this.requirements,
    required this.onChanged,
  });

  final List<_RequirementDraft> requirements;
  final VoidCallback onChanged;

  @override
  State<_RequirementsSheet> createState() => _RequirementsSheetState();
}

class _RequirementsSheetState extends State<_RequirementsSheet> {
  void _changed(void Function() change) {
    setState(change);
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _SheetBody(
      title: l.requirementsSection,
      children: [
        Text(
          l.requirementsHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        for (final r in widget.requirements)
          _RequirementRow(
            key: ValueKey(r.id),
            draft: r,
            onChanged: () => _changed(() {}),
            onRemove: () => _changed(() => widget.requirements.remove(r)),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            onPressed: () => _changed(
              () => widget.requirements.add(
                _RequirementDraft(id: ScheduleRepository.newId()),
              ),
            ),
            icon: const Icon(LecIcons.target),
            label: Text(l.addRequirement),
          ),
        ),
      ],
    );
  }
}

class _ContactsSheet extends StatefulWidget {
  const _ContactsSheet({required this.contacts, required this.onChanged});

  final List<ContactDraft> contacts;
  final VoidCallback onChanged;

  @override
  State<_ContactsSheet> createState() => _ContactsSheetState();
}

class _ContactsSheetState extends State<_ContactsSheet> {
  void _changed() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return _SheetBody(
      title: l.contactsSection,
      children: [
        Text(
          l.contactsHint,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        ContactsEditor(contacts: widget.contacts, onChanged: _changed),
      ],
    );
  }
}

class _NotesSheet extends StatefulWidget {
  const _NotesSheet({
    required this.notes,
    required this.website,
    required this.links,
    required this.onChanged,
  });

  final TextEditingController notes;
  final TextEditingController website;
  final List<LinkDraft> links;
  final VoidCallback onChanged;

  @override
  State<_NotesSheet> createState() => _NotesSheetState();
}

class _NotesSheetState extends State<_NotesSheet> {
  void _changed() {
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return _SheetBody(
      title: l.notesAndLinks,
      children: [
        TextField(
          controller: widget.notes,
          minLines: 3,
          maxLines: 8,
          maxLength: notesMaxLength,
          buildCounter: notesCounter,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: l.courseNotes,
            hintText: l.courseNotesHint,
            alignLabelWithHint: true,
          ),
          onChanged: (_) => widget.onChanged(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: widget.website,
          keyboardType: TextInputType.url,
          decoration: InputDecoration(
            labelText: l.courseWebsite,
            prefixIcon: const Icon(LecIcons.link),
          ),
          onChanged: (_) => widget.onChanged(),
        ),
        const SizedBox(height: 12),
        LinksEditor(links: widget.links, onChanged: _changed),
      ],
    );
  }
}

/// A titled, scrolling sheet with Done at the end, clear of the keyboard.
class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          ...children,
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context).done),
            ),
          ),
        ],
      ),
    ),
  );
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
            key: ValueKey('color-$key'),
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
                      for (final t in SessionType.attendable)
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
