# Architecture

```
 Flutter app (each device)                         Cloudflare (free plan)
 ┌──────────────────────────────┐   WebSocket   ┌─────────────────────────────┐
 │ UI (Riverpod, granular)      │◄────────────► │ Worker (Hono): auth, routing│
 │   ▲ reactive Drift queries   │  HTTP fallback│   │ idFromName(userId)      │
 │ Drift SQLite = local truth   │               │   ▼                         │
 │   outbox + HLC + SyncEngine ─┼──────────────►│ Durable Object per user     │
 └──────────────────────────────┘               │ SQLite: rows + field clocks │
        ▲ Google sign-in (browser), brokered by the Worker └────────────────┘
```

## Principles

1. **Local first.** Every read and write goes to the device's SQLite database. The UI
   never waits for the network; sync happens in the background.
2. **One write path.** All changes go through `ScheduleRepository`, one transaction each.
3. **Sessions are derived, not stored.** Meeting rules + per-session overrides +
   no-class ranges are expanded into sessions on the fly. Editing a rule can't lose marks.
4. **Granular rebuilds.** Providers expose small, value-equal slices; marking one session
   rebuilds only the widgets showing it.
5. **Nothing slow on the startup path.** `main()` reads preferences and calls `runApp`;
   the database opens on its own isolate; notifications and the widget start after the
   first frame.

These directly fix v1, which serialized the whole app to one JSON blob per change, ran
`setState` on a 1,600-line root widget for every tap, and awaited the network at launch.

## Code map (`app/lib`)

| Path | Contents |
|---|---|
| `domain/` | Pure Dart, no Flutter: `LocalDate`, schedule types, occurrence engine, stats, requirements, reminder planning |
| `core/db/` | Drift tables, `AppDatabase`, row ↔ domain mappers, `ScheduleRepository` |
| `core/sync/` | HLC, `SyncRecorder` (outbox), `SyncEngine` (WebSocket/HTTP), config |
| `core/auth/` | Session model, `AuthService` (Google via browser + PKCE, secure storage) |
| `core/notifications/` | `NotificationService` (diff-based scheduling), background action handler |
| `core/home_widget/` | Android widget snapshot + background callback |
| `core/backup/` | JSON v3 export/import, v1/v2 importer |
| `core/icons/` | `LecIcons` (meaning → glyph) and the generated custom icon font class |
| `app/` | Providers, router, shell, theme, formatting, notification/widget controllers, adaptive helpers (`adaptive.dart`) and keyboard shortcuts (`shortcuts.dart`) |
| `features/` | Screens: onboarding, today, week, courses, session, stats, settings, sessions |

## Data model

Synced tables (Drift, `core/db/tables.dart`). Every row has `id` (TEXT, UUIDv7),
`deleted` (tombstone, so deletions sync) and `updatedAt` (local diagnostics only).

| Table | Purpose / key columns |
|---|---|
| `semesters` | name, startDate, endDate, weekStart (ISO weekday), visibleDays (bitmask) |
| `courses` | semesterId, name, code, lecturer, colorKey, website, notes, links (JSON), sortOrder |
| `meetings` | courseId, type, kind (`weekly`/`once`), weekday or date, startMin, endMin, location, intervalWeeks (1/2), validFrom, validUntil, links |
| `session_overrides` | **id = `{meetingId}_{yyyymmdd}`** of the original date; status, notes, recordingUrl, moved date/start/end/location |
| `no_class_ranges` | semesterId, start, end, label |
| `requirements` | courseId, type (null = all), minPercent, recordingsCount |
| `user_settings` | single row `me`: use24h (null = follow device), meetingNumbers |

Local-only: `outbox(seq, tbl, rowId, patch JSON, hlc, ifAbsent, rejected)` and
`sync_meta` (server cursor, dataset id).

Conventions: enums are stored as stable keys (`lecture`, `attended`, …) — never
translated labels (v1's bug); times are minutes after midnight; dates are `yyyy-MM-dd`;
all date arithmetic runs on UTC midnights (`LocalDate`), so daylight-saving transitions
can't duplicate or skip days.

The override id is deterministic so that two devices editing the same session write the
same row and the sync merge combines their fields.

## Occurrence engine (`domain/occurrence_engine.dart`)

`OccurrenceEngine.expand(semester, meetings, overrides, noClassRanges)` returns an
`OccurrenceIndex`: a chronological list with lookups by id, day and course.

- **Weekly** meetings run from the later of semester start / `validFrom` to the earlier
  of semester end / `validUntil`. **Every other week** anchors on the week of `validFrom`
  (or the semester start). **One-off** meetings appear on their date even outside the
  semester.
- **Overrides** are looked up by `(meetingId, originalDate)` and supply status, notes,
  recording link and "this week only" moves. Overrides for dates a rule no longer
  produces are ignored (kept, so reverting the rule brings them back).
- **No-class days** are a separate layer: a session on such a day shows as canceled
  unless the user set an explicit status; removing the range restores everything.
- **Holidays** (`domain/holidays/jewish_holidays.dart`) are generated, not stored as a
  calendar: `jewishHolidays()` walks the semester's days with `kosher_dart` (checked
  against Hebcal for 2025–2030 in the tests) and the holidays sheet writes ordinary
  no-class days, one row per day with the id `<semesterId>_hol_<date>`. Every device
  derives the same ids, so applying the same holidays on two devices merges cleanly, and
  no schema or server change was needed. `holidayChanges()` touches only the holidays
  whose tick changed, so a day restored on its own stays restored.
- **Numbering** (#N) runs per (course, type), skipping canceled sessions.

Expansion is O(n) and takes well under a millisecond for a semester; the result is
memoized by Riverpod and recomputed only when the data changes.

Other domain logic: `attendance_stats.dart` (progress, streak, needs-marking, groupings),
`requirements.dart` (required = ⌈total × min%⌉; absences = missed + skipped, + watched
unless recordings count; slack = total − required − absences), `reminder_plan.dart`
(soonest-first plan of before/after reminders, stable FNV-1a ids, capped at 60 for iOS).

## State management (`app/providers.dart`)

```
databaseProvider → repositoryProvider → semestersProvider
                                     ↘ semesterDataProvider (stream) → occurrenceIndexProvider
                                                                      ↘ sessionProvider(id), courseProvider(id),
                                                                        dayIdsProvider(day), needsMarkingProvider,
                                                                        nowNextProvider, courseSummaryProvider(id)
minuteClockProvider (ticks on minute boundaries) → todayProvider
```

- Riverpod only notifies when the new value `!=` the old one, so domain classes implement
  value equality and list providers return `EqList` (deep equality).
- A session tile watches `sessionProvider(id)`; marking it changes that one occurrence,
  so only that tile (and the summaries that depend on it) rebuild.
- Device preferences (theme, language, active semester, reminders) live in
  `SharedPreferencesWithCache`, loaded before `runApp` so they're available synchronously.

## Persistence (`core/db`)

- Drift runs on a background isolate (`drift_flutter`, `shareAcrossIsolates: true`), so
  notification and widget callbacks in other isolates write to the same database with
  working stream updates.
- `ScheduleRepository._write` stores the full row and hands the **changed fields** to the
  `ChangeRecorder` (the sync outbox) in the same transaction.
- Rows are written with `toColumns(false)`: a Drift data class used directly treats null
  as *absent*, and the upsert would never clear a column (found by a test — undo to
  "pending" silently failed).
- Deletes tombstone the whole tree (course → meetings → overrides → requirements) and
  return a `DeletionReceipt`, which `undoDeletion` replays. Tombstones from the last 30
  days are listed in **Recently deleted**, which restores a course or semester with
  everything deleted along with it.
- Editors pass the state they loaded (`CourseBase`, the loaded `SemesterInfo`): only
  fields the user changed are written, and only meetings/requirements the user removed
  are deleted, so edits that synced in while the editor was open survive.
- **Automatic backups** (`core/backup/snapshot_service.dart`): gzipped v3 JSON (deleted
  rows included) in app-support `/snapshots`, written to a `.part` file and renamed.
  One a day, plus one before imports, restores, removing data on sign-out and switching
  accounts; kept: 7 daily, 4 weekly, 10 others. Restoring saves the current state first.
- Off-device copies: Android's own backup (Google Drive) includes the database and
  snapshots; SharedPreferences, where the sign-in token is encrypted with a key that
  can't leave the phone, are excluded (`res/xml/data_extraction_rules.xml`,
  `backup_rules.xml`). iCloud backup includes Application Support on iPhone.
- `watchSemesterData` is a Drift `customSelect(..., readsFrom: {...}).watch()` mapped to
  a loader: one emission per transaction, and it cancels cleanly.
- Schema upgrades are drift `stepByStep` migrations, each written against the schema of
  its own version (`app_database.steps.dart`) and tested from every earlier version
  (`test/drift`). Columns added after a release have defaults in the repository's
  adapters (`added`), so rows from older app versions still load: synced rows, backups
  and automatic backups.

## Sync

### Client (`core/sync`)

- **`SyncRecorder`** stamps each change with a **hybrid logical clock** (`Hlc`:
  `millis:counter:node`, fixed width so string order = time order) and inserts it into the
  outbox. It's installed whenever an account is attached to the device (a preference read
  at startup), even before the network connects, so no edit is missed.
- **`SyncEngine`** keeps one WebSocket per device:
  1. connect → `hello{since: cursor}` → catch-up pages (`catchUp: true`); the cursor is
     saved in the same transaction as the rows;
  2. every server row is written as the new base state, then the row's **pending outbox
     patches are re-applied on top** (rebase), so local edits never flicker away;
  3. the outbox is pushed in batches of ≤ 500. On `ack`, accepted entries are deleted;
     refused ones stay, parked with the reason (Settings → Account shows them with
     Retry); `clock_skew` ones are re-stamped after the clock is corrected from the
     server's `now`; rows where a pushed field lost come back as corrections;
  4. if the server can't save (an `error` with `retryAt`: its free plan's daily limit,
     until 00:00 UTC, or an outage), or refuses the connection with 503/429, the socket
     closes and the engine comes back at that time, backing off up to an hour if it
     keeps happening. The outbox keeps everything meanwhile;
  5. broadcasts received before catch-up finished are applied but don't move the cursor,
     so a reconnect can't skip versions; a catch-up with a new `dataset` id (the server's
     data was deleted or rolled back) restarts from 0 and re-offers this device's rows;
  6. pings every 30 s (answered by the server without waking it); no answer for 75 s
     (e.g. after the laptop slept) drops the socket and reconnects. Exponential backoff
     with jitter on failures, skipped when the app comes back to the foreground. On
     phones the socket closes 30 s after the app goes to the background; desktops keep
     it open while the window is hidden.
- **HTTP fallback** (`SyncEngine.syncOverHttp`) is used by background isolates
  (notification actions, widget buttons).
- **Accounts**: guest data joins an account on first sign-in (every row offered
  add-only, `ifAbsent`, so it never overwrites the account's newer edits or deleted rows);
  data of a different account is wiped only after confirmation and an automatic backup;
  sign-out either keeps local data (and the unsynced outbox, which syncs on the next
  sign-in to the same account) or removes it (after an automatic backup).

### Server (`server/`)

One Durable Object per user (`idFromName(userId)`) with its own SQLite:
`rows(tbl, id, data JSON, clocks JSON, version)`. Each field in a patch wins only if its
clock is newer than the stored clock for that field (**per-field last-writer-wins**), so
the phone setting a status and the laptop editing notes on the same session both keep
their change. Accepted changes bump a monotonically increasing `version` (the clients'
cursor) and are broadcast to all of the user's sockets. A push is one transaction that
writes each touched row once. "Delete cloud data" moves rows to a trash for 30 days.
Details, including the free plan's daily limits: [server/README.md](../server/README.md).

### Sign-in

```
App                         Worker                         Google
 │ open /v1/auth/google/start?redirect&state&code_challenge (PKCE)
 │──────────────────────────►│ signed state JWT ───────────►│ consent
 │                           │◄──────── code ───────────────│
 │                           │ exchange code (client secret), verify ID token
 │◄── redirect leccheck://auth?code=<one-time JWT>&state ───│
 │ POST /v1/auth/token {code, code_verifier}
 │──────────────────────────►│ check PKCE, one-time use → session JWT (60 days)
```

Desktop uses a loopback redirect (`http://localhost:43823/auth`) instead of the custom
scheme. The Google client secret exists only in the Worker. Sessions renew after 7 days;
"sign out everywhere" bumps a per-user epoch that invalidates older tokens.

## Notifications and widget

- `NotificationController` re-plans reminders (debounced 2 s) when data, settings or
  language change, hourly, and when the app comes back. While the semester is still
  loading it leaves scheduled reminders alone; turning reminders off cancels them without
  dismissing notifications already on screen.
- `NotificationService.apply` compares the plan with the plugin's list of scheduled
  notifications (each carries a signature in its payload) and only cancels or schedules
  the differences. That list survives a force stop while Android drops the alarms, so
  once per process it also asks the system which alarms still exist
  (`MainActivity.armedReminders`, a `PendingIntent` lookup) and re-arms the missing ones.
  Android plans up to 100 reminders over 21 days (the plugin rewrites its whole list for
  each one); iOS 60 over 14 days (its cap is 64). Linux has no OS scheduler, so reminders
  due within a day are shown from in-app timers.
- Reminders are also topped up without the UI (`app/background_reminders.dart`): after a
  notification button, and once a day from WorkManager (`scheduleDailyTopUp`).
- `ReminderHealth` (permission, blocked channels, exact alarms, battery optimization,
  restricted background use) comes from the plugin and `MainActivity`'s
  `com.leccheck.app/device` channel. Today warns when reminders are on but blocked, and
  Settings → Notifications offers a fix for each problem.
- Bug reports (`core/report/report_sender.dart`) go to `POST /v1/reports` without
  sign-in; the Worker rate-limits them (per hashed sender and per day, counted in a
  reserved Durable Object) and files a GitHub issue in a private repository
  (`server/src/reports.ts`). Unsent reports wait in `pending_reports.json`. DevLog marks
  uncaught errors (`last_error.txt`), and the next start offers to report them.
- Action buttons call `onNotificationActionInBackground` in a background isolate: it opens
  the shared database, sets the status, tries an HTTP sync, then tops up reminders.
- The status-bar icon (`ic_stat_leccheck`) is named only from Dart, so
  `res/raw/keep.xml` stops release builds from stripping it. Without it, the plugin can't
  start, and nothing is shown or scheduled (as in v2.0.0-beta.3 on Android). A failed
  setup is logged and shown in Settings → Developer, and the test button reports it.
- The Android widget (`android/.../widget/TodayWidget.kt`, Jetpack Glance) renders a JSON
  snapshot written by `WidgetController`; it decides at render time which sessions have
  started, and its buttons call `todayWidgetCallback` in the background.

## UI

- **Router**: go_router with a `StatefulShellRoute` (Today, Week, Courses, Stats). The
  shell keeps every tab alive and fades/scales the newly selected one in ("fade
  through").
- **Adaptive layer** — two independent axes:
  - *Window size* (`WindowSize`: compact < 600, medium < 840, expanded < 1200, large)
    decides the **layout**: bottom bar → rail with an Add button → extended sidebar;
    single column → centered column (`SliverCentered`) → two columns
    (`SliverCrossAxisGroup`) or list + details (Courses, the Week panel, Settings).
  - *Idiom* (`AppIdiom`, from `defaultTargetPlatform` so tests can override it) decides
    **input and controls**: touch gets swipes, long-press and bottom sheets; desktop
    gets hover, right-click menus (`showSessionMenu`), dialogs and keyboard shortcuts;
    Apple platforms get Cupertino alerts and date/time wheels (`showChoiceDialog`,
    `pickDate`, `pickTime`) and adaptive switches.
  - Shortcuts: the shell's `CallbackShortcuts` handles app-wide keys and drives the Week
    page through `weekCommandsProvider`; pushed pages wrap themselves in `PageShortcuts`
    (Esc, Ctrl+S). Single-key shortcuts are ignored while a text field has focus.
- **Platform runners**: Linux is single-instance (a second launch presents the existing
  window), uses a GTK header bar only on GNOME-family desktops, and has a minimum window
  size. Android enables predictive back and draws edge-to-edge on every version.
- **Theme** (`app/theme`): `material_ui` (the standalone Material package). Presets build
  a `ColorScheme.fromSeed` with a per-preset scheme variant; `StatusColors` and
  `CourseColors` theme extensions compute light/dark tones in HCT and harmonize them with
  the primary color; `AppMotion` holds Material 3 Expressive spring curves. Rubik is
  bundled as static weights (Flutter doesn't map `FontWeight` onto variable fonts).
- **Icons**: `LecIcons` maps meanings to glyphs; identity icons come from a custom font
  built from `design/icons/*.svg` ([design/README.md](../design/README.md)).
- **RTL & formatting**: directional paddings everywhere; time ranges wrapped in Unicode
  isolates with word joiners so they never break or reorder inside Hebrew text; `Fmt`
  caches `DateFormat`s per locale and 24-hour setting.
- `fl_chart` still uses the SDK Material library, so the app is wrapped in
  `MaterialUiCompatibilityBridge`.

## Testing

| Suite | What it covers |
|---|---|
| `app/test/domain` | Engine (DST weeks, biweekly, ranges, holidays, moves, numbering), stats, requirements, reminder planning |
| `app/test/core` | Repository (history kept, null clearing, cascade + undo), HLC, backup import/export; data safety: editor saves, import merge/replace, trash, snapshots, refused and corrected changes, sync pausing when the server is over its limit, rows from older app versions, test notification buttons |
| `app/test/drift` | Database upgrades from every earlier schema (`drift_schemas/`): the result matches a fresh database and existing rows survive |
| `app/test/widget` | Mark + undo, editor validation, unsaved-changes guard, empty state, developer mode; week tile layout; adaptive behavior per platform (desktop sidebar, shortcuts, right-click, list + details; iPhone dialogs and pickers; phone swipe) |
| `app/test_screenshots` | Renders every main screen offscreen to PNG (English/Hebrew, light/dark; phone, desktop 1440×900, iPhone) |
| `app/test_sync` | Two simulated devices against a local Worker: live sync, field merges, delete/undo |
| `server/test` | Merge rules (incl. `ifAbsent`), validation, auth/PKCE, isolation, paging, revocation, WebSocket broadcast, corrections, one write per row per push, delete + restore, dataset resets, storage failures |

App tests run with `TZ=Asia/Jerusalem` so they cross real daylight-saving transitions.
