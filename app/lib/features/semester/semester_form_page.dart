import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/format.dart';
import '../../app/providers.dart';
import '../../core/db/schedule_repository.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/local_date.dart';
import '../../domain/schedule_types.dart';
import '../../domain/semester_calendar.dart';
import '../../l10n/gen/app_localizations.dart';

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

  SemesterInfo? get _existing => ref
      .read(semestersProvider)
      .value
      ?.firstWhereOrNull((s) => s.id == widget.semesterId);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final existing = _existing;
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
    final current = start ? _start : _end;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(2020),
      lastDate: DateTime(2040),
    );
    if (picked == null) return;
    setState(() {
      final date = LocalDate.fromDateTime(picked);
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
    setState(() => _saving = true);
    final repo = ref.read(repositoryProvider);
    final id = widget.semesterId ?? ScheduleRepository.newId();
    await repo.saveSemester(
      SemesterInfo(
        id: id,
        name: _name.text.trim(),
        start: _start,
        end: _end,
        weekStart: _weekStart,
        visibleDays: _days,
      ),
    );
    ref.read(activeSemesterChoiceProvider.notifier).select(id);
    if (!mounted) return;
    if (widget.semesterId == null) {
      context.go('/today');
    } else {
      context.pop();
    }
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

    return Scaffold(
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
                    ButtonSegment(value: d, label: Text(fmt.isoWeekdayName(d))),
                ],
                selected: {_weekStart},
                onSelectionChanged: (s) => setState(() => _weekStart = s.first),
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
