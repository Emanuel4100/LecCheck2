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
| `app/` | Providers, router, shell, theme, formatting, notification/widget controllers |
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

Local-only: `outbox(seq, tbl, rowId, patch JSON, hlc)` and `sync_meta` (server cursor).

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
  return a `DeletionReceipt`, which `undoDeletion` replays.
- `watchSemesterData` is a Drift `customSelect(..., readsFrom: {...}).watch()` mapped to
  a loader: one emission per transaction, and it cancels cleanly.

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
  3. the outbox is pushed in batches of ≤ 500; entries are deleted on `ack`;
  4. broadcasts received before catch-up finished are applied but don't move the cursor,
     so a reconnect can't skip versions;
  5. pings every 30 s (answered by the server without waking it); no answer for 75 s
     (e.g. after the laptop slept) drops the socket and reconnects. Exponential backoff
     with jitter on failures, skipped when the app comes back to the foreground. On
     phones the socket closes 30 s after the app goes to the background; desktops keep
     it open while the window is hidden.
- **HTTP fallback** (`SyncEngine.syncOverHttp`) is used by background isolates
  (notification actions, widget buttons).
- **Accounts**: guest data joins an account on first sign-in (every row queued); data of a
  different account is wiped only after confirmation; sign-out keeps or removes local data.

### Server (`server/`)

One Durable Object per user (`idFromName(userId)`) with its own SQLite:
`rows(tbl, id, data JSON, clocks JSON, version)`. Each field in a patch wins only if its
clock is newer than the stored clock for that field (**per-field last-writer-wins**), so
the phone setting a status and the laptop editing notes on the same session both keep
their change. Accepted changes bump a monotonically increasing `version` (the clients'
cursor) and are broadcast to all of the user's sockets. Details: [server/README.md](../server/README.md).

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
  language change, and hourly. `NotificationService.apply` compares the plan with the
  OS's pending notifications (each carries a signature in its payload) and only cancels or
  schedules the differences. Linux has no OS scheduler, so reminders due within a day are
  shown from in-app timers.
- Action buttons call `onNotificationActionInBackground` in a background isolate: it opens
  the shared database, sets the status, and tries an HTTP sync.
- The Android widget (`android/.../widget/TodayWidget.kt`, Jetpack Glance) renders a JSON
  snapshot written by `WidgetController`; it decides at render time which sessions have
  started, and its buttons call `todayWidgetCallback` in the background.

## UI

- **Router**: go_router with a `StatefulShellRoute` (Today, Week, Courses, Stats). The
  shell keeps every tab alive and fades/scales the newly selected one in ("fade
  through"). Phones get a bottom navigation bar; wider windows a navigation rail.
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
| `app/test/core` | Repository (history kept, null clearing, cascade + undo), HLC, backup import/export |
| `app/test/widget` | Mark + undo, editor validation, unsaved-changes guard, empty state |
| `app/test_screenshots` | Renders every main screen offscreen to PNG (English/Hebrew, light/dark) |
| `app/test_sync` | Two simulated devices against a local Worker: live sync, field merges, delete/undo |
| `server/test` | Merge rules, validation, auth/PKCE, isolation, paging, revocation, WebSocket broadcast |

App tests run with `TZ=Asia/Jerusalem` so they cross real daylight-saving transitions.
