import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../app/adaptive.dart';
import '../../app/format.dart';
import '../../app/providers.dart';
import '../../app/shortcuts.dart';
import '../../app/theme/app_theme.dart';
import '../../app/theme/colors.dart';
import '../../app/theme/motion.dart';
import '../../app/widgets/common.dart';
import '../../core/backup/backup_service.dart';
import '../../core/backup/snapshot_service.dart';
import '../../core/home_widget/today_widget.dart';
import '../../core/db/schedule_repository.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/holidays/jewish_holidays.dart';
import '../../domain/local_date.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import '../developer/developer_page.dart';
import '../session/session_actions.dart';
import 'account_section.dart';
import 'holidays_sheet.dart';
import 'notifications_section.dart';

final _versionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return '${info.version} (${info.buildNumber})';
});

final _pinSupportedProvider = FutureProvider<bool>(
  (ref) => TodayWidget.canPin(),
);

/// One settings category: a header and its tiles on phones, an entry of the
/// category list on wide windows.
class _Section {
  const _Section(this.icon, this.title, this.children);

  final IconData icon;
  final String title;
  final List<Widget> children;
}

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  int _selected = 0;

  List<_Section> _sections(AppLocalizations l) {
    final device =
        AppIdiom.isDesktop ||
        AppIdiom.isIOS ||
        (ref.watch(_pinSupportedProvider).value ?? false);
    return [
      _Section(LecIcons.account, l.account, const [AccountSection()]),
      _Section(LecIcons.palette, l.appearance, const [
        _ThemePresetPicker(),
        _ModeAndLanguage(),
      ]),
      _Section(LecIcons.notifications, l.notifications, const [
        NotificationsSection(),
      ]),
      _Section(LecIcons.semester, l.semesterSection, const [
        _SemesterSection(),
        _NoClassSection(),
      ]),
      _Section(LecIcons.courses, l.navCourses, const [_CourseOptions()]),
      _Section(LecIcons.exportData, l.data, const [_DataSection()]),
      if (device)
        _Section(LecIcons.device, l.thisDevice, const [_DeviceSection()]),
      _Section(LecIcons.info, l.about, const [_AboutSection()]),
      if (ref.watch(devModeProvider))
        _Section(LecIcons.developer, l.developer, const [_DeveloperSection()]),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final sections = _sections(l);

    if (!WindowSize.of(context).isWide) {
      return PageShortcuts(
        child: Scaffold(
          body: CustomScrollView(
            slivers: [
              SliverAppBar.large(title: Text(l.settings)),
              SliverCentered(
                maxWidth: 720,
                sliver: SliverList.list(
                  children: [
                    for (final section in sections) ...[
                      SectionHeader(title: section.title),
                      ...section.children,
                    ],
                    const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Wide: categories on the left, the chosen one on the right.
    final theme = Theme.of(context);
    final selected = _selected.clamp(0, sections.length - 1);
    return PageShortcuts(
      child: Scaffold(
        appBar: AppBar(title: Text(l.settings)),
        body: Row(
          children: [
            SizedBox(
              width: 280,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                children: [
                  for (final (i, section) in sections.indexed)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: ListTile(
                        leading: Icon(section.icon),
                        title: Text(section.title),
                        selected: i == selected,
                        selectedColor: theme.colorScheme.onSecondaryContainer,
                        selectedTileColor: theme.colorScheme.secondaryContainer,
                        shape: const StadiumBorder(),
                        onTap: () => setState(() => _selected = i),
                      ),
                    ),
                ],
              ),
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Align(
                alignment: AlignmentDirectional.topStart,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 760),
                  child: ListView(
                    key: ValueKey(selected),
                    padding: const EdgeInsets.only(bottom: 48),
                    children: [
                      SectionHeader(title: sections[selected].title),
                      ...sections[selected].children,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutSection extends ConsumerStatefulWidget {
  const _AboutSection();

  @override
  ConsumerState<_AboutSection> createState() => _AboutSectionState();
}

class _AboutSectionState extends ConsumerState<_AboutSection> {
  /// Taps on the version: like Android's build number, 7 turn on developer
  /// mode.
  int _taps = 0;

  void _tapVersion() {
    final l = AppLocalizations.of(context);
    void say(String text) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(text), duration: const Duration(seconds: 2)),
      );
    if (ref.read(devModeProvider)) {
      say(l.devModeAlreadyOn);
      return;
    }
    final left = 7 - ++_taps;
    if (left > 0) {
      if (left <= 4) say(l.devModeSteps(left));
      return;
    }
    _taps = 0;
    ref.read(devModeProvider.notifier).set(true);
    say(l.devModeOn);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          leading: const Icon(LecIcons.info),
          title: Text(l.version),
          subtitle: Text(ref.watch(_versionProvider).value ?? ''),
          onTap: _tapVersion,
        ),
        ListTile(
          leading: const Icon(LecIcons.license),
          title: Text(l.license),
          subtitle: Text(l.licenseSummary),
          onTap: () => showLicensePage(
            context: context,
            applicationName: 'LecCheck',
            applicationVersion: ref.read(_versionProvider).value,
            applicationLegalese: '${l.licenseSummary}\n© 2026 Emanuel',
          ),
        ),
        ListTile(
          leading: const Icon(LecIcons.code),
          title: Text(l.sourceCode),
          subtitle: const Text('github.com/Emanuel4100/LecCheck2'),
          onTap: () => openUrl('https://github.com/Emanuel4100/LecCheck2'),
        ),
      ],
    );
  }
}

/// Shown once developer mode is on.
class _DeveloperSection extends StatelessWidget {
  const _DeveloperSection();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListTile(
      leading: const Icon(LecIcons.developer),
      title: Text(l.developerTools),
      subtitle: Text(l.developerToolsSubtitle),
      onTap: () => context.push('/developer'),
    );
  }
}

/// Options that only exist on this kind of device.
class _DeviceSection extends ConsumerWidget {
  const _DeviceSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (AppIdiom.isDesktop)
          ListTile(
            leading: const Icon(LecIcons.keyboard),
            title: Text(l.keyboardShortcuts),
            subtitle: Text(l.keyboardShortcutsSubtitle),
            onTap: () => showShortcutsHelp(context),
          ),
        if (ref.watch(_pinSupportedProvider).value ?? false)
          ListTile(
            leading: const Icon(LecIcons.widget),
            title: Text(l.addWidget),
            subtitle: Text(l.addWidgetSubtitle),
            onTap: TodayWidget.requestPin,
          ),
        // Sideloaded with a free Apple ID: the app expires after 7 days.
        if (AppIdiom.isIOS)
          ListTile(
            leading: const Icon(LecIcons.refresh),
            title: Text(l.altStoreRefresh),
            subtitle: Text(l.altStoreRefreshSubtitle),
          ),
      ],
    );
  }
}

class _ThemePresetPicker extends ConsumerWidget {
  const _ThemePresetPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final selected = ref.watch(appearanceProvider.select((a) => a.preset));
    final brightness = Theme.of(context).brightness;
    final motion = AppMotion.of(context);
    // iPhone has no wallpaper colors; desktops offer their accent color.
    final presets = [
      for (final p in ThemePreset.values)
        if (p != ThemePreset.wallpaper || !AppIdiom.isIOS) p,
    ];
    String name(ThemePreset p) => switch (p) {
      ThemePreset.wallpaper =>
        AppIdiom.isDesktop ? l.presetAccent : l.presetWallpaper,
      ThemePreset.ocean => l.presetOcean,
      ThemePreset.sunset => l.presetSunset,
      ThemePreset.forest => l.presetForest,
      ThemePreset.grape => l.presetGrape,
      ThemePreset.rose => l.presetRose,
      ThemePreset.mono => l.presetMono,
    };

    return SizedBox(
      height: 116,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: presets.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) {
          final preset = presets[i];
          final scheme = preset == ThemePreset.wallpaper
              ? Theme.of(context).colorScheme
              : AppTheme.build(
                  preset: preset,
                  brightness: brightness,
                ).colorScheme;
          final isSelected = preset == selected;
          return GestureDetector(
            onTap: () =>
                ref.read(appearanceProvider.notifier).setPreset(preset),
            child: Column(
              children: [
                AnimatedContainer(
                  duration: motion.medium,
                  curve: motion.spatialFast,
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(isSelected ? 20 : 36),
                    border: Border.all(
                      color: isSelected
                          ? scheme.primary
                          : scheme.outlineVariant,
                      width: isSelected ? 3 : 1,
                    ),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      for (final c in [
                        scheme.primary,
                        scheme.tertiary,
                        scheme.secondaryContainer,
                      ])
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(1.5),
                            decoration: BoxDecoration(
                              color: c,
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  name(preset),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: isSelected ? FontWeight.w700 : null,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ModeAndLanguage extends ConsumerWidget {
  const _ModeAndLanguage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final appearance = ref.watch(appearanceProvider);
    final controller = ref.read(appearanceProvider.notifier);
    final prefs = ref.watch(userPrefsProvider).value ?? const UserPrefs();
    final use24h = prefs.use24h ?? MediaQuery.alwaysUse24HourFormatOf(context);

    return Column(
      children: [
        ListTile(
          leading: const Icon(LecIcons.darkMode),
          title: Text(l.themeMode),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<ThemeMode>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                  value: ThemeMode.system,
                  label: Text(l.themeSystem),
                ),
                ButtonSegment(
                  value: ThemeMode.light,
                  label: Text(l.themeLight),
                ),
                ButtonSegment(value: ThemeMode.dark, label: Text(l.themeDark)),
              ],
              selected: {appearance.mode},
              onSelectionChanged: (s) => controller.setMode(s.first),
            ),
          ),
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(LecIcons.darkMode),
          title: Text(l.pureBlack),
          subtitle: Text(l.pureBlackSubtitle),
          value: appearance.pureBlack,
          onChanged: controller.setPureBlack,
        ),
        ListTile(
          leading: const Icon(LecIcons.language),
          title: Text(l.language),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'system', label: Text(l.themeSystem)),
                const ButtonSegment(value: 'en', label: Text('English')),
                const ButtonSegment(value: 'he', label: Text('עברית')),
              ],
              selected: {appearance.localeCode ?? 'system'},
              onSelectionChanged: (s) =>
                  controller.setLocale(s.first == 'system' ? null : s.first),
            ),
          ),
        ),
        SwitchListTile.adaptive(
          secondary: const Icon(LecIcons.clock24),
          title: Text(l.time24h),
          subtitle: Text(l.time24hSubtitle),
          value: use24h,
          onChanged: (v) => ref.read(repositoryProvider).setUse24h(v),
        ),
      ],
    );
  }
}

class _SemesterSection extends ConsumerWidget {
  const _SemesterSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final theme = Theme.of(context);
    final semesters = ref.watch(semestersProvider).value ?? const [];
    final current = ref.watch(currentSemesterIdProvider);

    return Column(
      children: [
        for (final s in semesters)
          ListTile(
            leading: Icon(
              s.id == current ? LecIcons.check : LecIcons.semester,
              color: s.id == current ? theme.colorScheme.primary : null,
            ),
            title: Text(s.name),
            subtitle: Text(
              '${fmt.yearMonthDay(s.start)} – ${fmt.yearMonthDay(s.end)}',
            ),
            onTap: () =>
                ref.read(activeSemesterChoiceProvider.notifier).select(s.id),
            trailing: PopupMenuButton<String>(
              onSelected: (action) async {
                if (action == 'edit') {
                  context.push('/semester?id=${s.id}');
                } else if (action == 'delete') {
                  await _deleteSemester(context, ref, s);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'edit', child: Text(l.edit)),
                PopupMenuItem(value: 'delete', child: Text(l.delete)),
              ],
            ),
          ),
        ListTile(
          leading: const Icon(LecIcons.add),
          title: Text(l.addSemester),
          onTap: () => context.push('/semester?new=1'),
        ),
      ],
    );
  }

  Future<void> _deleteSemester(
    BuildContext context,
    WidgetRef ref,
    SemesterInfo semester,
  ) async {
    final l = AppLocalizations.of(context);
    final ok = await confirmDialog(
      context,
      title: l.deleteSemesterTitle,
      body: l.deleteSemesterBody,
      confirmLabel: l.delete,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final repo = ref.read(repositoryProvider);
    final messenger = ScaffoldMessenger.of(context);
    final receipt = await repo.deleteSemester(semester.id);
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.semesterDeleted),
        action: SnackBarAction(
          label: l.undo,
          onPressed: () => repo.undoDeletion(receipt),
        ),
      ),
    );
  }
}

class _NoClassSection extends ConsumerWidget {
  const _NoClassSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final data = ref.watch(semesterDataProvider).value;
    if (data == null) return const SizedBox.shrink();
    final repo = ref.read(repositoryProvider);
    final holidays = data.noClassRanges.where(isGeneratedHoliday).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          leading: const Icon(LecIcons.holiday),
          title: Text(l.noClassDays),
          subtitle: Text(l.noClassDaysSubtitle),
        ),
        // Generated holidays are a row per day: one entry for all of them.
        ListTile(
          contentPadding: const EdgeInsetsDirectional.only(start: 72, end: 8),
          title: Text(l.holidaysTitle),
          subtitle: Text(
            holidays == 0 ? l.holidaysAdd : l.holidaysApplied(holidays),
          ),
          trailing: const Icon(LecIcons.chevronEnd),
          onTap: () => showHolidaysSheet(context, ref, data.semester),
        ),
        for (final r in data.noClassRanges)
          if (!isGeneratedHoliday(r))
            ListTile(
              contentPadding: const EdgeInsetsDirectional.only(
                start: 72,
                end: 8,
              ),
              title: Text(r.label.isEmpty ? l.markNoClassDay : r.label),
              subtitle: Text(
                r.start == r.end
                    ? fmt.weekdayDayMonth(r.start)
                    : '${fmt.dayMonth(r.start)} – ${fmt.dayMonth(r.end)}',
              ),
              trailing: IconButton(
                tooltip: l.delete,
                icon: const Icon(LecIcons.delete),
                onPressed: () => repo.deleteNoClassRange(r.id),
              ),
            ),
        Padding(
          padding: const EdgeInsetsDirectional.only(start: 64),
          child: TextButton.icon(
            onPressed: () async {
              final s = data.semester;
              final range = await showDateRangePicker(
                context: context,
                firstDate: DateTime(
                  s.start.year,
                  s.start.month,
                  s.start.day,
                ).subtract(const Duration(days: 60)),
                lastDate: DateTime(
                  s.end.year,
                  s.end.month,
                  s.end.day,
                ).add(const Duration(days: 60)),
              );
              if (range == null || !context.mounted) return;
              final label = await _askLabel(context);
              await repo.saveNoClassRange(
                NoClassRange(
                  id: ScheduleRepository.newId(),
                  semesterId: s.id,
                  start: LocalDate.fromDateTime(range.start),
                  end: LocalDate.fromDateTime(range.end),
                  label: label ?? '',
                ),
              );
            },
            icon: const Icon(LecIcons.add),
            label: Text(l.addNoClassRange),
          ),
        ),
      ],
    );
  }

  Future<String?> _askLabel(BuildContext context) {
    final l = AppLocalizations.of(context);
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.noClassReason),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l.noClassReasonHint),
          onSubmitted: (v) => Navigator.pop(context, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, ''),
            child: Text(l.skip),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: Text(l.save),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

class _CourseOptions extends ConsumerWidget {
  const _CourseOptions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final numbers = ref.watch(
      userPrefsProvider.select((p) => p.value?.meetingNumbers ?? true),
    );
    return SwitchListTile.adaptive(
      secondary: const Icon(LecIcons.numbers),
      title: Text(l.meetingNumbers),
      subtitle: Text(l.meetingNumbersSubtitle),
      value: numbers,
      onChanged: (v) => ref.read(repositoryProvider).setMeetingNumbers(v),
    );
  }
}

class _DataSection extends ConsumerWidget {
  const _DataSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final deleted = ref.watch(recentlyDeletedProvider).value ?? const [];

    return Column(
      children: [
        ListTile(
          leading: const Icon(LecIcons.exportData),
          title: Text(l.exportData),
          subtitle: Text(l.exportDataSubtitle),
          onTap: () async {
            final messenger = ScaffoldMessenger.of(context);
            final json = await BackupService(ref.read(repositoryProvider))
                .exportJson();
            final stamp = LocalDate.today().toIso();
            final saved = await FilePicker.saveFile(
              fileName: 'leccheck-backup-$stamp.json',
              bytes: utf8.encode(json),
              allowedExtensions: const ['json'],
            );
            if (saved != null) {
              messenger.showSnackBar(SnackBar(content: Text(l.exportDone)));
            }
          },
        ),
        ListTile(
          leading: const Icon(LecIcons.importData),
          title: Text(l.importData),
          subtitle: Text(l.importDataSubtitle),
          onTap: () => _import(context, ref),
        ),
        ListTile(
          leading: const Icon(LecIcons.history),
          title: Text(l.snapshots),
          subtitle: Text(l.snapshotsSubtitle),
          onTap: () => showAppSheet<void>(
            context: context,
            scrollControlled: true,
            builder: (_) => const _SnapshotList(),
          ),
        ),
        ListTile(
          leading: const Icon(LecIcons.restore),
          title: Text(l.recentlyDeleted),
          subtitle: Text(l.recentlyDeletedSubtitle),
          trailing: deleted.isEmpty ? null : Text('${deleted.length}'),
          onTap: () => showAppSheet<void>(
            context: context,
            scrollControlled: true,
            builder: (_) => const _RecentlyDeletedList(),
          ),
        ),
      ],
    );
  }

  /// Reads the file, shows what it would change, and imports it after an
  /// automatic backup. "Add missing" never changes existing data.
  Future<void> _import(BuildContext context, WidgetRef ref) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final repo = ref.read(repositoryProvider);
    final file = await FilePicker.pickFile(allowedExtensions: const ['json']);
    if (file == null || !context.mounted) return;
    final ParsedBackup backup;
    try {
      backup = BackupService.parse(utf8.decode(await file.readAsBytes()));
    } on FormatException {
      messenger.showSnackBar(SnackBar(content: Text(l.importFailed)));
      return;
    }
    final preview = await repo.previewImport(backup.tables);
    if (preview.added == 0 && preview.changed == 0) {
      messenger.showSnackBar(SnackBar(content: Text(l.importNothing)));
      return;
    }
    if (!context.mounted) return;
    final mode = await showChoiceDialog<ImportMode?>(
      context,
      title: l.importTitle,
      body: l.importPreview(backup.semesters, preview.added, preview.changed),
      choices: [
        DialogChoice(l.cancel, null),
        if (preview.changed > 0)
          DialogChoice(l.replace, ImportMode.replace, destructive: true),
        DialogChoice(l.importMerge, ImportMode.merge, primary: true),
      ],
    );
    if (mode == null) return;
    await ref.read(snapshotServiceProvider).take(SnapshotReason.beforeImport);
    final count = await BackupService(repo).importParsed(backup, mode: mode);
    messenger.showSnackBar(SnackBar(content: Text(l.importDone(count))));
  }
}

/// Automatic backups, newest first; tapping one restores it.
class _SnapshotList extends ConsumerStatefulWidget {
  const _SnapshotList();

  @override
  ConsumerState<_SnapshotList> createState() => _SnapshotListState();
}

class _SnapshotListState extends ConsumerState<_SnapshotList> {
  late final _snapshots = ref.read(snapshotServiceProvider).list();

  String _reason(SnapshotReason reason, AppLocalizations l) => switch (reason) {
    SnapshotReason.daily => l.snapshotDaily,
    SnapshotReason.beforeImport => l.snapshotImport,
    SnapshotReason.beforeRestore => l.snapshotRestore,
    SnapshotReason.beforeSignOut => l.snapshotSignOut,
    SnapshotReason.beforeAccountSwitch => l.snapshotSwitch,
  };

  Future<void> _restore(Snapshot snapshot) async {
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final ok = await confirmDialog(
      context,
      title: l.restoreSnapshotTitle,
      body: l.restoreSnapshotBody,
      confirmLabel: l.restore,
      destructive: true,
    );
    if (!ok) return;
    await ref.read(snapshotServiceProvider).restore(snapshot);
    navigator.pop();
    messenger.showSnackBar(SnackBar(content: Text(l.restoreDone)));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    return FutureBuilder(
      future: _snapshots,
      builder: (context, snap) {
        final snapshots = snap.data;
        return _SheetList(
          title: l.snapshots,
          empty: snapshots == null ? null : l.snapshotsEmpty,
          children: [
            for (final s in snapshots ?? const <Snapshot>[])
              ListTile(
                leading: const Icon(LecIcons.history),
                title: Text(
                  '${fmt.longDate(LocalDate.fromDateTime(s.takenAt))} · '
                  '${fmt.time(s.takenAt.hour * 60 + s.takenAt.minute)}',
                ),
                subtitle: Text(_reason(s.reason, l)),
                trailing: TextButton(
                  onPressed: () => _restore(s),
                  child: Text(l.restore),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Deleted semesters and courses, with a restore button each.
class _RecentlyDeletedList extends ConsumerWidget {
  const _RecentlyDeletedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    final fmt = Fmt.of(context);
    final items = ref.watch(recentlyDeletedProvider).value;
    return _SheetList(
      title: l.recentlyDeleted,
      empty: items == null ? null : l.recentlyDeletedEmpty,
      children: [
        for (final item in items ?? const <DeletedItem>[])
          ListTile(
            leading: Icon(
              item.isSemester ? LecIcons.semester : LecIcons.courses,
            ),
            title: Text(item.name),
            subtitle: Text(
              (item.isSemester ? l.deletedSemester : l.deletedCourse)(
                fmt.dayMonth(LocalDate.fromDateTime(item.deletedAt)),
              ),
            ),
            trailing: TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                await ref.read(repositoryProvider).restoreDeleted(item);
                messenger.showSnackBar(SnackBar(content: Text(l.restoreDone)));
              },
              child: Text(l.restore),
            ),
          ),
      ],
    );
  }
}

/// Title and a scrollable list for [showAppSheet]; shows [empty] when there
/// are no children (null while loading).
class _SheetList extends StatelessWidget {
  const _SheetList({
    required this.title,
    required this.empty,
    required this.children,
  });

  final String title;
  final String? empty;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
            child: Text(title, style: theme.textTheme.titleLarge),
          ),
          if (children.isEmpty && empty != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
              child: Text(
                empty!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.only(bottom: 24),
                children: children,
              ),
            ),
        ],
      ),
    );
  }
}
