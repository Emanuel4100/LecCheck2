import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/adaptive.dart';
import '../../app/labels.dart';
import '../../app/providers.dart';
import '../../app/shortcuts.dart';
import '../../app/widgets/common.dart';
import '../../core/icons/lec_icons.dart';
import '../../domain/occurrence.dart';
import '../../domain/schedule_types.dart';
import '../../l10n/gen/app_localizations.dart';
import '../session/session_tile.dart';

/// Every session of the semester with search, filters and a sort. By
/// default "Past" shows the newest first and "Upcoming" the soonest first.
class AllSessionsPage extends ConsumerStatefulWidget {
  const AllSessionsPage({super.key});

  @override
  ConsumerState<AllSessionsPage> createState() => _AllSessionsPageState();
}

enum _Sort { newest, oldest, course, recordingsFirst }

bool _hasRecording(Occurrence o) => o.recordingUrl?.trim().isNotEmpty ?? false;

class _AllSessionsPageState extends ConsumerState<AllSessionsPage> {
  bool _upcoming = false;
  String _query = '';
  String? _courseId;
  SessionType? _type;
  AttendanceStatus? _status;
  bool _withRecording = false;
  bool _withNote = false;

  /// Null: the tab's own order.
  _Sort? _sort;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final index = ref.watch(occurrenceIndexProvider);
    final courses = ref.watch(coursesProvider).items;
    final now = ref.watch(minuteClockProvider).value ?? DateTime.now();
    final courseById = {for (final c in courses) c.id: c};
    final query = _query.trim().toLowerCase();

    bool matches(Occurrence o) {
      if (_courseId != null && o.courseId != _courseId) return false;
      if (_type != null && o.type != _type) return false;
      if (_status != null && o.status != _status) return false;
      if (_withRecording && !_hasRecording(o)) return false;
      if (_withNote && o.notes.trim().isEmpty) return false;
      if (query.isEmpty) return true;
      final c = courseById[o.courseId];
      return [
        c?.name,
        c?.code,
        c?.lecturer,
        o.location,
        o.notes,
        o.recordingUrl,
      ].any((s) => s != null && s.toLowerCase().contains(query));
    }

    final sessions = [
      for (final o in index.all)
        if (o.hasStarted(now) != _upcoming && matches(o)) o,
    ];
    final sort = _sort ?? (_upcoming ? _Sort.oldest : _Sort.newest);
    // Sessions come oldest first; the other orders keep the tab's own
    // order within a course or among the sessions with a recording.
    final byDate = _upcoming ? sessions : sessions.reversed.toList();
    final ordered = switch (sort) {
      _Sort.oldest => sessions,
      _Sort.newest => sessions.reversed.toList(),
      _Sort.course => [
        for (final c in courses) ...byDate.where((o) => o.courseId == c.id),
        ...byDate.where((o) => !courseById.containsKey(o.courseId)),
      ],
      _Sort.recordingsFirst => [
        ...byDate.where(_hasRecording),
        ...byDate.where((o) => !_hasRecording(o)),
      ],
    };
    String sortLabel(_Sort s) => switch (s) {
      _Sort.newest => l.sortNewest,
      _Sort.oldest => l.sortOldest,
      _Sort.course => l.sortCourse,
      _Sort.recordingsFirst => l.sortRecordingsFirst,
    };

    return PageShortcuts(
      autofocus: !AppIdiom.isDesktop,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.allSessions),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(64),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Centered(
                maxWidth: 868,
                child: SearchBar(
                  // Opened to search (Ctrl+F on desktop): ready to type.
                  autoFocus: AppIdiom.isDesktop,
                  leading: const Icon(LecIcons.search),
                  hintText: l.search,
                  elevation: const WidgetStatePropertyAll(0),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ),
          ),
        ),
        body: CustomScrollView(
          slivers: [
            SliverCentered(
              maxWidth: 900,
              sliver: SliverMainAxisGroup(
                slivers: [
                  SliverToBoxAdapter(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                      child: Row(
                        children: [
                          SegmentedButton<bool>(
                            showSelectedIcon: false,
                            segments: [
                              ButtonSegment(
                                value: false,
                                label: Text(l.statusMix),
                              ),
                              ButtonSegment(
                                value: true,
                                label: Text(l.comingUp),
                              ),
                            ],
                            selected: {_upcoming},
                            onSelectionChanged: (s) =>
                                setState(() => _upcoming = s.first),
                          ),
                          const SizedBox(width: 8),
                          _FilterMenu<String?>(
                            label: _courseId == null
                                ? l.navCourses
                                : courseById[_courseId]?.name ?? l.navCourses,
                            active: _courseId != null,
                            options: {
                              null: l.allTypes,
                              for (final c in courses) c.id: c.name,
                            },
                            onSelected: (v) => setState(() => _courseId = v),
                          ),
                          const SizedBox(width: 8),
                          _FilterMenu<SessionType?>(
                            label: _type?.label(l) ?? l.appliesTo,
                            active: _type != null,
                            options: {
                              null: l.allTypes,
                              for (final t in SessionType.attendable)
                                t: t.label(l),
                            },
                            onSelected: (v) => setState(() => _type = v),
                          ),
                          const SizedBox(width: 8),
                          _FilterMenu<AttendanceStatus?>(
                            label: _status?.label(l) ?? l.status,
                            active: _status != null,
                            options: {
                              null: l.allTypes,
                              for (final s in AttendanceStatus.values)
                                s: s.label(l),
                            },
                            onSelected: (v) => setState(() => _status = v),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(l.filterHasRecording),
                            avatar: _withRecording
                                ? null
                                : const Icon(LecIcons.recording),
                            selected: _withRecording,
                            onSelected: (v) =>
                                setState(() => _withRecording = v),
                          ),
                          const SizedBox(width: 8),
                          FilterChip(
                            label: Text(l.filterHasNote),
                            avatar: _withNote
                                ? null
                                : const Icon(LecIcons.notes),
                            selected: _withNote,
                            onSelected: (v) => setState(() => _withNote = v),
                          ),
                          const SizedBox(width: 8),
                          _FilterMenu<_Sort>(
                            label: sortLabel(sort),
                            avatar: const Icon(LecIcons.sort),
                            active: _sort != null,
                            options: {
                              for (final s in _Sort.values) s: sortLabel(s),
                            },
                            onSelected: (v) => setState(
                              // The tab's own order goes back to following
                              // the tab.
                              () => _sort =
                                  v == (_upcoming ? _Sort.oldest : _Sort.newest)
                                  ? null
                                  : v,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (ordered.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: LecIcons.search,
                        title: l.noUpcoming,
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                      sliver: SliverList.separated(
                        itemCount: ordered.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) => SessionTile(
                          sessionId: ordered[i].id,
                          showDate: true,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterMenu<T> extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.active,
    required this.options,
    required this.onSelected,
    this.avatar,
  });

  final String label;
  final Widget? avatar;
  final bool active;
  final Map<T, String> options;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => MenuAnchor(
    menuChildren: [
      for (final e in options.entries)
        MenuItemButton(
          onPressed: () => onSelected(e.key),
          child: Text(e.value),
        ),
    ],
    builder: (context, controller, _) => FilterChip(
      label: Text(label),
      avatar: avatar,
      selected: active,
      onSelected: (_) =>
          controller.isOpen ? controller.close() : controller.open(),
    ),
  );
}
