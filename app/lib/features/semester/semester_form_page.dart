import 'package:collection/collection.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/shortcuts.dart';
import '../../core/db/schedule_repository.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/holidays/jewish_holidays.dart';
import '../../domain/local_date.dart';
import '../../domain/occurrence_engine.dart';
import '../../domain/schedule_types.dart';
import '../../domain/semester_calendar.dart';
import '../../l10n/gen/app_localizations.dart';
import '../settings/holidays_sheet.dart';

/// Creates (onboarding, "add semester") or edits a semester.
class SemesterFormPage extends ConsumerStatefulWidget {
  const SemesterFormPage({super.key, this.semesterId});

  final String? semesterId;

  @override
  ConsumerState<SemesterFormPage> createState() => _SemesterFormPageState();
}

class _SemesterFormPageState extends ConsumerState<SemesterFormPage> {
  final _name = TextEditingController();
  late LocalDate _start;
  late LocalDate _end;
  late int _weekStart;
  late Set<int> _days;
  bool _initialized = false;
  bool _saving = false;

  /// New semesters: add the usual Jewish and Israeli days off. On by
  /// default in Hebrew or in Israel's time zone, until the user chooses.
  bool? _holidays;
  bool _inIsrael = false;

  /// The semester as the form loaded it; saving writes only what changed.
  SemesterInfo? _loaded;

  SemesterInfo? get _existing => ref
      .read(semestersProvider)
      .value
      ?.firstWhereOrNull((s) => s.id == widget.semesterId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final existing = _loaded = _existing;
    if (existing != null) {
      _name.text = existing.name;
      _start = existing.start;
      _end = existing.end;
      _weekStart = existing.weekStart;
      _days = {...existing.visibleDays};
      return;
    }
    // Locale-aware defaults: Israeli week (Sun–Thu) for Hebrew.
    final hebrew = Localizations.localeOf(context).languageCode == 'he';
    _inIsrael = hebrew;
    FlutterTimezone.getLocalTimezone().then((zone) {
      final israel = const {
        'Asia/Jerusalem',
        'Asia/Tel_Aviv',
      }.contains(zone.identifier);
      if (israel && mounted) setState(() => _inIsrael = true);
    }, onError: (Object _) {});
    _name.text = AppLocalizations.of(context).semesterDefaultName;
    _weekStart = hebrew ? DateTime.sunday : DateTime.monday;
    _days = hebrew ? {7, 1, 2, 3, 4} : {1, 2, 3, 4, 5};
    // The upcoming week start (today if the week starts today).
    final today = LocalDate.today();
    final thisWeek = startOfWeek(today, _weekStart);
    _start = thisWeek == today ? today : thisWeek.addDays(7);
    _end = _start.addDays(13 * 7 - 2);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _valid => _end.isAfter(_start) && _name.text.trim().isNotEmpty;

  Future<void> _pickDate(bool start) async {
    final date = await pickDate(context, start ? _start : _end);
    if (date == null) return;
    setState(() {
      if (start) {
        final length = _start.daysUntil(_end);
        _start = date;
        if (!_end.isAfter(_start)) _end = _start.addDays(length);
      } else {
        _end = date;
      }
    });
  }

  Future<void> _save() async {
    final repo = ref.read(repositoryProvider);
    final loaded = _loaded;
    final datesChanged =
        loaded != null && (loaded.start != _start || loaded.end != _end);
    if (datesChanged && !await _confirmHiddenSessions(repo, loaded)) return;
    setState(() => _saving = true);
    final id = widget.semesterId ?? ScheduleRepository.newId();
    final applied = datesChanged
        ? await repo.generatedHolidays(id)
        : const <LocalDate, bool>{};
    await repo.saveSemester(
      SemesterInfo(
        id: id,
        name: _name.text.trim(),
        start: _start,
        end: _end,
        weekStart: _weekStart,
        visibleDays: _days,
      ),
      base: _loaded,
    );
    if (widget.semesterId == null && (_holidays ?? _inIsrael) && mounted) {
      await applyHolidayPreset(
        repo,
        ref.read(sharedPrefsProvider),
        SemesterInfo(id: id, name: '', start: _start, end: _end),
        AppLocalizations.of(context),
      );
    }
    // New dates: the holidays chosen for this semester cover them too.
    if (datesChanged && applied.isNotEmpty && mounted) {
      final l = AppLocalizations.of(context);
      await repo.applyHolidays(
        id,
        add: {
          for (final day in holidaysForNewRange(
            oldStart: loaded.start,
            oldEnd: loaded.end,
            newStart: _start,
            newEnd: _end,
            applied: applied,
            inIsrael: holidaysInIsrael(ref.read(sharedPrefsProvider)),
          ))
            day.date: l.holidayName(day.name),
        },
      );
    }
    ref.read(activeSemesterChoiceProvider.notifier).select(id);
    if (!mounted) return;
    if (widget.semesterId == null) {
      context.go('/today');
    } else {
      context.pop();
    }
  }

  /// Weekly sessions only exist between the semester's dates: when marked
  /// ones would fall outside the new dates, asks first (they're kept, and
  /// show again if the dates change back).
  Future<bool> _confirmHiddenSessions(
    ScheduleRepository repo,
    SemesterInfo loaded,
  ) async {
    final data = await repo.loadSemesterData(loaded.id);
    if (data == null || !mounted) return mounted;
    final hidden =
        OccurrenceEngine.expand(
              semester: data.semester,
              meetings: data.meetings,
              overrides: data.overrides,
              noClassRanges: data.noClassRanges,
            ).all
            .where(
              (o) =>
                  !o.isOneOff &&
                  (o.explicitStatus?.isDecided ?? false) &&
                  !o.originalDate.isWithin(_start, _end),
            )
            .length;
    if (hidden == 0) return true;
    final l = AppLocalizations.of(context);
    return confirmDialog(
      context,
      title: l.semesterDatesTitle,
      body: l.semesterDatesBody(hidden),
      confirmLabel: l.save,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final weeks = (_start.daysUntil(_end) + 1) / 7;
    final orderedDays = [
      for (var i = 0; i < 7; i++) (_weekStart - 1 + i) % 7 + 1,
    ];

    return PageShortcuts(
      bindings: {
        primaryKey(LogicalKeyboardKey.keyS): () {
          if (_valid && !_saving) _save();
        },
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.semesterId == null ? l.semesterSetupTitle : l.editSemester,
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
              children: [
                if (widget.semesterId == null)
                  Text(
                    l.semesterSetupSubtitle,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                const SizedBox(height: 20),
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: l.semesterName,
                    prefixIcon: const Icon(LecIcons.semester),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _DateField(
                        label: l.startDate,
                        value: fmt.yearMonthDay(_start),
                        onTap: () => _pickDate(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _DateField(
                        label: l.endDate,
                        value: fmt.yearMonthDay(_end),
                        onTap: () => _pickDate(false),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
                  child: Text(
                    _end.isAfter(_start)
                        ? l.semesterLength(weeks.ceil())
                        : l.dateRangeError,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: _end.isAfter(_start)
                          ? theme.colorScheme.onSurfaceVariant
                          : theme.colorScheme.error,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Text(l.weekStartsOn, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: [
                    for (final d in const [
                      DateTime.saturday,
                      DateTime.sunday,
                      DateTime.monday,
                    ])
                      ButtonSegment(
                        value: d,
                        label: Text(fmt.isoWeekdayName(d)),
                      ),
                  ],
                  selected: {_weekStart},
                  onSelectionChanged: (s) =>
                      setState(() => _weekStart = s.first),
                ),
                const SizedBox(height: 24),
                Text(l.visibleDays, style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final d in orderedDays)
                      FilterChip(
                        label: Text(fmt.isoWeekdayShort(d)),
                        selected: _days.contains(d),
                        onSelected: (on) => setState(() {
                          if (on) {
                            _days.add(d);
                          } else if (_days.length > 1) {
                            _days.remove(d);
                          }
                        }),
                      ),
                  ],
                ),
                if (widget.semesterId == null) ...[
                  const SizedBox(height: 16),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.semesterHolidays),
                    subtitle: Text(l.semesterHolidaysSubtitle),
                    value: _holidays ?? _inIsrael,
                    onChanged: (on) => setState(() => _holidays = on),
                  ),
                ],
              ],
            ),
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _valid && !_saving ? _save : null,
          icon: const Icon(LecIcons.check),
          label: Text(widget.semesterId == null ? l.createSemester : l.save),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(16),
    onTap: onTap,
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: const Icon(LecIcons.date),
      ),
      child: Text(value),
    ),
  );
}
