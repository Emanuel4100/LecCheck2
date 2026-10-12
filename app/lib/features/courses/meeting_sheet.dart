import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/labels.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/local_date.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import 'meeting_summary.dart';

class LinkDraft {
  LinkDraft([NamedLink? link])
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

class MeetingDraft {
  MeetingDraft({
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
       links = [for (final l in links) LinkDraft(l)];

  factory MeetingDraft.from(MeetingRule m) => MeetingDraft(
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
  final List<LinkDraft> links;

  bool get valid =>
      endMin > startMin && (kind == MeetingKind.weekly || date != null);

  /// The same meeting on another [weekday], as a new meeting [id].
  MeetingDraft copyOn(String id, int weekday) => MeetingDraft(
    id: id,
    type: type,
    kind: kind,
    weekday: weekday,
    date: date,
    startMin: startMin,
    endMin: endMin,
    location: location.text,
    intervalWeeks: intervalWeeks,
    validFrom: validFrom,
    validUntil: validUntil,
    links: [for (final l in links) ?l.toLink()],
  );

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

/// The day and time a new meeting starts with: a tap on the Week grid.
/// One-time when [date] is set, weekly on [weekday] otherwise.
class MeetingSeed {
  const MeetingSeed({
    this.weekday,
    this.date,
    required this.startMin,
    required this.endMin,
  });

  final int? weekday;
  final LocalDate? date;
  final int startMin;
  final int endMin;

  /// From the course editor's `day`, `date`, `start` and `end` query
  /// parameters; null when they don't describe a meeting.
  static MeetingSeed? fromQuery(Map<String, String> query) {
    final start = int.tryParse(query['start'] ?? '');
    final end = int.tryParse(query['end'] ?? '');
    final date = LocalDate.tryParse(query['date']);
    final day = int.tryParse(query['day'] ?? '');
    if (start == null || end == null || start < 0 || end > 24 * 60) {
      return null;
    }
    if (end <= start || (date == null && (day == null || day < 1 || day > 7))) {
      return null;
    }
    return MeetingSeed(weekday: day, date: date, startMin: start, endMin: end);
  }

  String get query => [
    if (date case final date?) 'date=${date.toIso()}' else 'day=$weekday',
    'start=$startMin',
    'end=$endMin',
  ].join('&');
}

/// What the meeting sheet asks the editor to do.
class MeetingSheetResult {
  const MeetingSheetResult.add(this.weekdays) : remove = false;
  const MeetingSheetResult.remove() : remove = true, weekdays = const [];

  final bool remove;

  /// For a new weekly meeting: the days it's on, in week order. The editor
  /// makes one meeting per day.
  final List<int> weekdays;
}

/// Edits one meeting: a sheet on phones, a dialog on wider screens. Changes
/// to an existing meeting apply as they're made ([onChanged]); a new one is
/// added only with Add (null when dismissed).
Future<MeetingSheetResult?> showMeetingSheet(
  BuildContext context, {
  required MeetingDraft draft,
  required SemesterInfo? semester,
  required bool isNew,
  VoidCallback? onChanged,
}) => showAppSheet<MeetingSheetResult>(
  context: context,
  scrollControlled: true,
  builder: (_) => _MeetingSheet(
    draft: draft,
    semester: semester,
    isNew: isNew,
    onChanged: onChanged ?? () {},
  ),
);

enum _Repeat { weekly, everyOtherWeek, everyOtherWeekFrom2, once }

class _MeetingSheet extends StatefulWidget {
  const _MeetingSheet({
    required this.draft,
    required this.semester,
    required this.isNew,
    required this.onChanged,
  });

  final MeetingDraft draft;
  final SemesterInfo? semester;
  final bool isNew;
  final VoidCallback onChanged;

  @override
  State<_MeetingSheet> createState() => _MeetingSheetState();
}

class _MeetingSheetState extends State<_MeetingSheet> {
  MeetingDraft get _draft => widget.draft;
  late final Set<int> _days = {_draft.weekday};

  void _changed() {
    setState(() {});
    widget.onChanged();
  }

  /// The semester's days in week order, and the meeting's day if it's
  /// hidden.
  List<int> get _weekdays {
    final semester = widget.semester;
    if (semester == null) return const [7, 1, 2, 3, 4, 5, 6];
    return [for (var i = 0; i < 7; i++) (semester.weekStart - 1 + i) % 7 + 1]
        .where((d) => semester.visibleDays.contains(d) || _days.contains(d))
        .toList();
  }

  LocalDate? get _week2 =>
      widget.semester == null ? null : secondWeekStart(widget.semester!);

  /// Started or ended by an earlier change of day mid-semester: its dates
  /// are kept as they are.
  bool get _split =>
      _draft.validUntil != null ||
      (_draft.validFrom != null && _draft.validFrom != _week2);

  _Repeat get _repeat => switch (_draft) {
    MeetingDraft(kind: MeetingKind.once) => _Repeat.once,
    MeetingDraft(intervalWeeks: 1) => _Repeat.weekly,
    MeetingDraft(:final validFrom) when !_split && validFrom == _week2 =>
      _Repeat.everyOtherWeekFrom2,
    _ => _Repeat.everyOtherWeek,
  };

  String _repeatLabel(_Repeat r, AppLocalizations l) => switch (r) {
    _Repeat.weekly => l.weekly,
    _Repeat.everyOtherWeek when _split || _week2 == null => l.everyOtherWeek,
    _Repeat.everyOtherWeek => l.everyOtherWeekFrom(1),
    _Repeat.everyOtherWeekFrom2 => l.everyOtherWeekFrom(2),
    _Repeat.once => l.oneTime,
  };

  void _setRepeat(_Repeat r) {
    final d = _draft;
    switch (r) {
      case _Repeat.once:
        d.kind = MeetingKind.once;
        d.date ??= LocalDate.today();
      case _Repeat.weekly || _Repeat.everyOtherWeek:
        d.kind = MeetingKind.weekly;
        d.intervalWeeks = r == _Repeat.weekly ? 1 : 2;
        if (!_split) d.validFrom = null;
      case _Repeat.everyOtherWeekFrom2:
        d.kind = MeetingKind.weekly;
        d.intervalWeeks = 2;
        d.validFrom = _week2;
    }
    _changed();
  }

  void _toggleDay(int day, bool on) {
    if (widget.isNew) {
      if (on) {
        _days.add(day);
      } else if (_days.length > 1) {
        _days.remove(day);
      }
    } else {
      _days
        ..clear()
        ..add(day);
    }
    _draft.weekday = _weekdays.firstWhere(_days.contains);
    _changed();
  }

  Future<void> _pickTime(bool start) async {
    final d = _draft;
    final minutes = await pickTime(context, start ? d.startMin : d.endMin);
    if (minutes == null) return;
    if (start) {
      final length = d.endMin - d.startMin;
      d.startMin = minutes;
      d.endMin = (minutes + (length > 0 ? length : 60)).clamp(
        minutes + 5,
        24 * 60 - 1,
      );
    } else {
      d.endMin = minutes;
    }
    _changed();
  }

  Future<void> _pickDate() async {
    final picked = await pickDate(context, _draft.date ?? LocalDate.today());
    if (picked == null) return;
    _draft.date = picked;
    _changed();
  }

  void _close() => Navigator.pop(
    context,
    widget.isNew
        ? MeetingSheetResult.add([
            if (_draft.kind == MeetingKind.weekly)
              ..._weekdays.where(_days.contains)
            else
              _draft.weekday,
          ])
        : null,
  );

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final d = _draft;
    final weekly = d.kind == MeetingKind.weekly;
    final timeError = d.endMin <= d.startMin;
    final split = weekly && _split;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.isNew ? l.newMeeting : l.editMeeting,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MenuButton<SessionType>(
                  icon: d.type.icon,
                  label: d.type.label(l),
                  values: SessionType.values,
                  itemIcon: (t) => t.icon,
                  itemLabel: (t) => t.label(l),
                  onSelected: (t) {
                    d.type = t;
                    _changed();
                  },
                ),
                _MenuButton<_Repeat>(
                  tooltip: l.repeats,
                  icon: weekly ? LecIcons.refresh : LecIcons.date,
                  label: _repeatLabel(_repeat, l),
                  values: [
                    _Repeat.weekly,
                    _Repeat.everyOtherWeek,
                    if (!_split && _week2 != null) _Repeat.everyOtherWeekFrom2,
                    _Repeat.once,
                  ],
                  itemLabel: (r) => _repeatLabel(r, l),
                  onSelected: _setRepeat,
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (weekly) ...[
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final day in _weekdays)
                    widget.isNew
                        ? FilterChip(
                            showCheckmark: false,
                            label: Text(fmt.isoWeekdayShort(day)),
                            selected: _days.contains(day),
                            onSelected: (on) => _toggleDay(day, on),
                          )
                        : ChoiceChip(
                            showCheckmark: false,
                            label: Text(fmt.isoWeekdayShort(day)),
                            selected: d.weekday == day,
                            onSelected: (_) => _toggleDay(day, true),
                          ),
                ],
              ),
              if (widget.isNew || split)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4, top: 6),
                  child: Text(
                    widget.isNew
                        ? l.meetingDaysHint
                        : switch ((d.validFrom, d.validUntil)) {
                            (final from?, final until?) => l.meetingBetween(
                              fmt.dayMonth(from),
                              fmt.dayMonth(until),
                            ),
                            (_, final until?) => l.meetingUntil(
                              fmt.dayMonth(until),
                            ),
                            (final from?, _) => l.meetingFrom(
                              fmt.dayMonth(from),
                            ),
                            _ => '',
                          },
                    style: muted,
                  ),
                ),
            ] else
              ActionChip(
                avatar: const Icon(LecIcons.date, size: 18),
                label: Text(d.date == null ? l.date : fmt.longDate(d.date!)),
                onPressed: _pickDate,
              ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _TimeButton(
                    label: l.startTime,
                    value: fmt.time(d.startMin),
                    onTap: () => _pickTime(true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimeButton(
                    label: l.endTime,
                    value: fmt.time(d.endMin),
                    helper: timeError
                        ? null
                        : formatDuration(
                            Duration(minutes: d.endMin - d.startMin),
                            l,
                          ),
                    error: timeError ? l.endAfterStartError : null,
                    onTap: () => _pickTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: d.location,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.location,
                prefixIcon: const Icon(LecIcons.location),
              ),
              onChanged: (_) => widget.onChanged(),
            ),
            const SizedBox(height: 8),
            LinksEditor(
              links: d.links,
              onChanged: _changed,
              addLabel: l.meetingLinks,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!widget.isNew)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      foregroundColor: theme.colorScheme.error,
                    ),
                    onPressed: () => Navigator.pop(
                      context,
                      const MeetingSheetResult.remove(),
                    ),
                    icon: const Icon(LecIcons.delete),
                    label: Text(l.removeMeeting),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: _close,
                  child: Text(widget.isNew ? l.add : l.done),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A button showing the current choice ("Lecture ▾") that opens a menu of
/// the others.
class _MenuButton<T> extends StatelessWidget {
  const _MenuButton({
    required this.icon,
    required this.label,
    required this.values,
    required this.itemLabel,
    required this.onSelected,
    this.itemIcon,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final List<T> values;
  final String Function(T) itemLabel;
  final IconData Function(T)? itemIcon;
  final ValueChanged<T> onSelected;
  final String? tooltip;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      for (final v in values)
        MenuItemButton(
          leadingIcon: itemIcon == null ? null : Icon(itemIcon!(v)),
          onPressed: () => onSelected(v),
          child: Text(itemLabel(v)),
        ),
    ],
    builder: (context, controller, _) {
      final button = OutlinedButton(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 8),
            Flexible(child: Text(label, overflow: TextOverflow.ellipsis)),
            const SizedBox(width: 4),
            const Icon(LecIcons.expand, size: 18),
          ],
        ),
      );
      return tooltip == null
          ? button
          : Tooltip(message: tooltip, child: button);
    },
  );
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
    this.helper,
    this.error,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
  final String? helper;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          helperText: helper,
          errorText: error,
          errorMaxLines: 2,
        ),
        child: Text(value, style: theme.textTheme.titleMedium),
      ),
    );
  }
}

class LinksEditor extends StatelessWidget {
  const LinksEditor({
    super.key,
    required this.links,
    required this.onChanged,
    this.addLabel,
  });

  final List<LinkDraft> links;
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
            links.add(LinkDraft());
            onChanged();
          },
          icon: const Icon(LecIcons.link),
          label: Text(addLabel ?? l.addLink),
        ),
      ],
    );
  }
}
