# User guide

## First launch

1. Pick a language (English / עברית) on the welcome screen.
2. **Continue without an account** — everything stays on this device — or **Sign in with
   Google** to sync (needs a build with sync configured, see [Setup](SETUP.md)).
3. **Set up your semester**: name, start and end dates, the day your week starts, and
   which days the week view shows. Hebrew defaults to an Israeli week (Sunday–Thursday).
4. Add your courses (Today shows an **Add course** button while you have none).

## Courses and meetings

Open **Courses → +** (or the button on an empty Today screen).

- **Course info** — name, optional code and lecturer, color, notes, website and extra links.
- **Weekly schedule** — add each recurring meeting: type (Lecture / Practice / Lab /
  Other), day, start and end time, room, and links (e.g. the Zoom link). Turn on
  **Every other week** for alternating meetings and choose whether it starts in the first
  or second week.
- **One-time sessions** — a single date (a make-up class, an exam review). Add them from
  the editor, the Courses menu, or a course page.
- **Attendance requirement** — set a minimum (50–100%) for all sessions or one type
  (e.g. 80% of practices). Choose whether watching a recording counts as attending.

Editing a meeting's time keeps all its marks and notes. If you move a meeting to another
**weekday** mid-semester, LecCheck asks whether the change applies to **all weeks** or
**from this week on** (past weeks then keep their old day and marks).

Leaving the editor with unsaved changes asks first; deleting a course can be undone from
the snackbar.

## Marking attendance

Every session has a status:

| Status | Meaning | Counts in attendance % |
|---|---|---|
| Pending | Not marked yet | — |
| Attended | You were there | yes (present) |
| Watched recording | You caught up from the recording | yes (present) |
| Missed | You weren't there | yes (absent) |
| Skipped | Not relevant / skipped on purpose | not in %; counts as an absence for requirements |
| Canceled | The class didn't happen | no |

**Attendance %** = (attended + watched) ÷ (attended + watched + missed), over sessions
that have started.

Ways to mark:

- **Today → Now card**: the buttons under a session in progress.
- **Needs marking** list: tap ✓ / ✗, or **swipe right** for attended and **left** for
  missed (also in Hebrew). **Mark all attended** marks the whole queue.
- **Long-press** any session (list or week grid) for all statuses.
- **Session details** (tap a session): pick a status — tap it again to clear it.
- **Notifications** and the **home-screen widget** (below).

Every mark shows an **Undo** button for a few seconds.

## Session details

Tap any session to see its date, time, room and lecturer, and to:

- set the status,
- write **notes for this session** (saved automatically),
- paste a **recording link** (with an open button),
- open course and meeting links,
- **This week only**: change the date, time or room of just this session (e.g. a room
  change), and undo that later,
- remove a one-time session.

## Today

- Semester progress (week X of N).
- **Now / Next** card with a countdown and a link button.
- **Needs marking** — sessions that started and have no status, newest first.
- **Today's schedule** and **Coming up** (the next 6 days).
- **All sessions** — search by course, code, lecturer, room or notes; filter by course,
  type or status; switch between past (newest first) and upcoming.

## Week

- Swipe left/right to change weeks; the calendar button jumps to any date, the sun button
  back to today.
- Today's column is highlighted with a moving "now" line.
- The hour range fits your schedule; pinch with two fingers to zoom.
- Tap a day header to mark it as **no class** (holiday, strike, exam day — with an
  optional reason) or restore it. Sessions that day show as canceled; your own marks stay
  and come back if you restore the day.

## Stats

Attendance ring and semester progress, current and best **streak** (consecutive attended
or watched sessions — missed or skipped break it), sessions waiting to be marked,
requirement status per course, attendance per course and per type, a weekly trend chart,
the mix of past statuses, and **catch up on recordings** (missed sessions that have a
recording link).

## Reminders

**Settings → Notifications**:

- **Before class** — 5, 10, 15 or 30 minutes before each session, with the room and an
  **Open link** button when the course or meeting has a link.
- **After class: how was it?** — 0–30 minutes after a session ends, with **Attended /
  Missed / Watched** buttons. Tapping one records the status without opening the app
  (and syncs if you're signed in). Only sessions still pending get this reminder.
- **Send a test notification** to check it works.

Permission is requested when you switch a reminder on. Reminders are planned two weeks
ahead and kept up to date as you edit. On Linux they fire while LecCheck is running.

## Home-screen widget (Android)

Long-press your home screen → Widgets → **LecCheck**. The widget lists today's sessions
in your wallpaper colors; once a session starts, ✓ / ✗ buttons appear to mark it in one
tap. Tap the widget to open the app.

## Sync and accounts

**Settings → Account → Sign in with Google.** The sign-in opens in your browser.

- Data you created before signing in is added to your account.
- If this device holds data from a *different* account, you're asked before it's replaced.
- The cloud icon in the top bar shows sync status (synced / syncing / offline); **Sync
  now** forces a sync. Changes made offline sync when you're back online.
- **Sign out** — keep a copy on this device, or remove it.
- **Sign out on all devices** — revokes every session.
- **Delete cloud data** — removes your data from the server (this device keeps a copy).

## Appearance and settings

- **Color theme**: Wallpaper (Material You, Android 12+), Ocean, Sunset, Forest, Grape,
  Rose, Mono. **Mode**: system / light / dark, plus **Pure black** for OLED screens.
- **Language**: system, English or Hebrew. **24-hour time** and **session numbering**
  (#1, #2… per course and type).
- **Semesters**: switch between semesters (tap), edit, delete (undoable), add another.
- **Holidays and no-class days**: add date ranges with a reason.
- **Data**: export a JSON backup of all semesters, or import one — including backups from
  the old LecCheck app.

## Moving from LecCheck v1

Export in the old app (**Settings → Data → Export schedule**), uninstall it (it was
signed with a different key), install LecCheck 2, then **Settings → Data → Import
backup**.

## Where your data lives

Each device keeps a SQLite database (Linux: `~/.local/share/com.leccheck.app/`). When
signed in, the server stores your rows in your own private storage unit; nobody else's
data is ever mixed with yours.
