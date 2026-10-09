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

- **Course info** — name, optional short name, code and lecturer, color, notes, website
  and extra links. The **short name** (e.g. "Calc 1") is shown in the Week view when the
  full name doesn't fit.
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
- **With a mouse** (desktop): hover a session that has started to get ✓ / ✗, or
  **right-click** any session for every status plus Details, Open link and Go to course.
- **Keyboard**: with session details open, press **1–5** for attended, missed, watched,
  skipped, canceled.
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

- Swipe left/right to change weeks (on tablets and desktop also the ‹ › buttons); the
  calendar button jumps to any date, the sun button back to today.
- Today's column is highlighted with a moving "now" line.
- Each session shows its course name first, over as many lines as fit, with long words
  shrunk a little to fit (or the course's short name, if it has one and the full name
  doesn't fit). Then come the room and the start time; the time is left out first in
  short sessions. A ✓ / ✗ shows how you marked it.
- The hour range fits your schedule; pinch with two fingers to zoom (desktop: Ctrl +
  mouse wheel or a trackpad pinch). The zoom is remembered on each device; on desktop the
  default fills the window.
- On large windows, a click shows the session's details in a panel beside the grid.
- Tap a day header to mark it as **no class** (holiday, strike, exam day — with an
  optional reason) or restore it. Sessions that day show as canceled; your own marks stay
  and come back if you restore the day. On desktop, hovering a holiday's header shows
  its name.

## Holidays

**Settings → Semester → Jewish and Israeli holidays** lists the holidays that fall in the
semester's dates, each with its days. Tick the ones without classes; the suggestion is
the usual days off at Israeli universities (Rosh Hashana, Yom Kippur, Sukkot, Purim,
Pesach, Yom HaAtzmaut and Shavuot, each with its eve). Hanukkah, Yom HaShoah,
Yom HaZikaron, Lag BaOmer, Yom Yerushalayim, Tisha B'Av and the minor fasts are there to
tick if your institution gives them off. **Dates as in Israel** can be turned off for
two-day festivals, as abroad.

A new semester can start with the suggested holidays (a switch in the semester form). A
single holiday day can be restored from the Week (tap its day header); saving the
holidays again keeps it restored unless you untick and tick that holiday. Holidays sync
to your other devices like any no-class day.

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
- **Send a test notification** to check it works. If nothing can be shown, it says why.

Permission is requested when you switch a reminder on. If the phone blocks LecCheck's
notifications later, **Today** shows a warning with an **Allow** button (it opens the
system settings when Android won't ask again). On Android, **Settings → Notifications**
also points out what can delay or stop reminders: exact alarms, battery optimization,
restricted background use, and, on some phones, autostart.

Reminders are planned up to three weeks ahead (two on iPhone) and kept up to date as you
edit, when you open the app, and once a day in the background. On Linux they fire while
LecCheck is running.

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
- Changes the server refuses are kept on the device and listed under Account with a
  **Retry** button. If the sync server is busy (for example, it reached its free daily
  limit), Account shows **Sync paused until** a time; your changes wait on the device.
- **Sign out** — keep a copy on this device (unsynced changes sync when you sign back
  in), or remove it (an automatic backup is saved first).
- **Sign out on all devices** — revokes every session.
- **Delete cloud data** — removes your data from the server (this device keeps a copy;
  the server keeps a copy for 30 days in case it was a mistake).

## Phones, tablets and desktop

The layout follows the window size, and the controls follow the device:

- **Phones**: bottom navigation; details and pickers open as bottom sheets.
- **Tablets and wide windows**: a navigation rail with an **Add** button (new course or
  one-time session); Today and Stats in two columns; **Courses** shows the list and the
  selected course side by side; **Settings** has categories on the left.
- **Large desktop windows**: a sidebar with the logo, sync status and Add; Week gets a
  details panel.
- **iPhone**: iOS switches, alerts and date/time wheels.
- **Desktop**: right-click menus, hover actions, keyboard shortcuts, time fields you can
  type into, and only one LecCheck window at a time (launching it again brings the window
  forward).

### Keyboard shortcuts

Ctrl on Linux and Windows (⌘ on a Mac). **F1** shows this list in the app.

| Keys | Action |
|---|---|
| Ctrl+1 … 4 | Today, Week, Courses, Stats |
| Ctrl+N / Ctrl+Shift+N | New course / one-time session |
| Ctrl+F | Search all sessions |
| Ctrl+R or F5 | Sync now |
| Ctrl+, | Settings |
| ← → or PgUp PgDn | Previous / next week (Week tab) |
| T or Home | This week |
| Ctrl+= / Ctrl+− / Ctrl+0 | Zoom the week in / out / reset |
| 1 … 5 | Mark the open session |
| Ctrl+S | Save (course and semester editors) |
| Esc | Close / back |

## Appearance and settings

- **Color theme**: Wallpaper (Material You, Android 12+; on desktop "System accent"; not
  on iPhone), Ocean, Sunset, Forest, Grape, Rose, Mono. **Mode**: system / light / dark, plus **Pure black** for OLED screens.
- **Language**: system, English or Hebrew. **24-hour time** and **session numbering**
  (#1, #2… per course and type).
- **Semesters**: switch between semesters (tap), edit, delete (undoable), add another.
- **Holidays and no-class days**: add date ranges with a reason.
- **Data**: export a JSON backup of all semesters, or import one — including backups from
  the old LecCheck app. Importing shows what would change: **Add missing** (the default)
  never changes your data; **Replace** overwrites it, after an automatic backup.
  **Automatic backups** (daily, and before imports, restores, sign-out and account
  switches) can be restored; **Recently deleted** brings back semesters and courses
  deleted in the last 30 days.
- **This device**: Android — add the home-screen widget; desktop — keyboard shortcuts;
  iPhone — a reminder to refresh the app in AltStore/SideStore every week.
- **About**: version, license (GNU GPL v3 or later) and the source code.

### Developer mode

For testing on a real phone: tap **Settings → About → Version** 7 times, then open
**Settings → Developer → Developer tools**. It can show and schedule test notifications
(including an after-class reminder whose buttons you press with the app closed),
reschedule reminders, pretend the sync server is busy, check the database, update the
widget, and show device details: Android version, battery optimization and time zone.
It also keeps a **log** of errors and of what notification and widget buttons did in the
background. **Copy diagnostics** puts all of it on the clipboard to paste into a bug
report. Switch it off at the top of the same page.

## Moving from LecCheck v1

Export in the old app (**Settings → Data → Export schedule**), uninstall it (it was
signed with a different key), install LecCheck 2, then **Settings → Data → Import
backup**.

## Where your data lives

Each device keeps a SQLite database and its automatic backups (Linux:
`~/.local/share/com.leccheck.app/`, backups in `snapshots/`). Android's backup to your
Google Drive and iPhone's iCloud backup include them, so a new phone gets them back
(sign in again after a restore). When signed in, the server stores your rows in your own
private storage unit; nobody else's data is ever mixed with yours.
