import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/providers.dart';
import '../../core/db/schedule_repository.dart';
import '../../domain/holidays/jewish_holidays.dart';
import '../../domain/local_date.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';

/// Whether holidays follow Israel's dates (one-day festivals). Per device.
const _inIsraelKey = 'holidays.inIsrael';

bool holidaysInIsrael(SharedPreferencesWithCache prefs) =>
    prefs.getBool(_inIsraelKey) ?? true;

/// Adds the preset's holidays to a new semester (semester form).
Future<void> applyHolidayPreset(
  ScheduleRepository repo,
  SharedPreferencesWithCache prefs,
  SemesterInfo semester,
  AppLocalizations l,
) => repo.applyHolidays(
  semester.id,
  add: {
    for (final day in jewishHolidays(
      semester.start,
      semester.end,
      inIsrael: holidaysInIsrael(prefs),
    ))
      if (day.holiday.preset) day.date: l.holidayName(day.name),
  },
);

/// Settings → Semester → holidays: tick the Jewish and Israeli holidays
/// without classes. Applying changes only the holidays whose tick changed, so
/// a day restored on its own (Week → day → Restore classes) stays restored.
Future<void> showHolidaysSheet(
  BuildContext context,
  WidgetRef ref,
  SemesterInfo semester,
) async {
  final repo = ref.read(repositoryProvider);
  final applied = await repo.generatedHolidays(semester.id);
  if (!context.mounted) return;
  await showAppSheet<void>(
    context: context,
    scrollControlled: true,
    builder: (_) => _HolidaysSheet(
      semester: semester,
      applied: applied,
      repo: repo,
      prefs: ref.read(sharedPrefsProvider),
    ),
  );
}

class _HolidaysSheet extends StatefulWidget {
  const _HolidaysSheet({
    required this.semester,
    required this.applied,
    required this.repo,
    required this.prefs,
  });

  final SemesterInfo semester;

  /// Generated days so far: true while applied, false once removed.
  final Map<LocalDate, bool> applied;
  final ScheduleRepository repo;
  final SharedPreferencesWithCache prefs;

  @override
  State<_HolidaysSheet> createState() => _HolidaysSheetState();
}

class _HolidaysSheetState extends State<_HolidaysSheet> {
  late final bool _savedInIsrael = holidaysInIsrael(widget.prefs);
  late bool _inIsrael = _savedInIsrael;
  late Map<JewishHoliday, bool> _ticked = initialHolidayTicks(
    _groups,
    widget.applied,
  );

  Map<JewishHoliday, List<HolidayDay>> get _groups => groupHolidays(
    jewishHolidays(
      widget.semester.start,
      widget.semester.end,
      inIsrael: _inIsrael,
    ),
  );

  Future<void> _apply() async {
    final l = AppLocalizations.of(context);
    final changes = holidayChanges(
      groups: _groups,
      ticked: _ticked,
      applied: widget.applied,
      calendarChanged: _inIsrael != _savedInIsrael,
      name: (day) => l.holidayName(day.name),
    );
    await widget.prefs.setBool(_inIsraelKey, _inIsrael);
    await widget.repo.applyHolidays(
      widget.semester.id,
      add: changes.add,
      remove: changes.remove,
    );
    if (mounted) Navigator.pop(context);
  }

  String _dates(Fmt fmt, List<HolidayDay> days) {
    final runs = <(LocalDate, LocalDate)>[];
    for (final day in days) {
      if (runs.isNotEmpty && runs.last.$2.addDays(1) == day.date) {
        runs.last = (runs.last.$1, day.date);
      } else {
        runs.add((day.date, day.date));
      }
    }
    return runs
        .map(
          (r) => r.$1 == r.$2
              ? fmt.weekdayDayMonth(r.$1)
              : '${fmt.dayMonth(r.$1)} – ${fmt.dayMonth(r.$2)}',
        )
        .join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final groups = _groups;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(l.holidaysTitle, style: theme.textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Text(
                l.holidaysIntro,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            SwitchListTile.adaptive(
              title: Text(l.holidaysInIsrael),
              subtitle: Text(l.holidaysInIsraelSubtitle),
              value: _inIsrael,
              onChanged: (on) => setState(() {
                _inIsrael = on;
                // Keep each holiday's tick; new ones get the preset.
                _ticked = {
                  for (final holiday in _groups.keys)
                    holiday: _ticked[holiday] ?? holiday.preset,
                };
              }),
            ),
            const Divider(),
            if (groups.isEmpty)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(l.holidaysNone),
              ),
            for (final MapEntry(key: holiday, value: days) in groups.entries)
              CheckboxListTile.adaptive(
                title: Text(l.holidayName(holiday.name)),
                subtitle: Text(_dates(fmt, days)),
                value: _ticked[holiday] ?? false,
                onChanged: (on) =>
                    setState(() => _ticked[holiday] = on ?? false),
              ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(l.cancel),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _apply, child: Text(l.save)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
