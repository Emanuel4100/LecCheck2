# User guide

## First launch

1. Pick a language (English / עברית) on the welcome screen.
2. **Continue without an account** — everything stays on this device — or **Sign in with
   Google** to sync (needs a build with sync configured, see [Setup](SETUP.md)).
3. **Set up your semester**: name, start and end dates, the day your week starts, and
   which days the week view shows. Hebrew defaults to an Israeli week (Sunday–Thursday).
   If you signed in to an account that already has data, you skip this: LecCheck brings
   your semesters and asks which one to open.
4. **A quick tour** follows the first setup: it points at Today, Week, Courses, Stats
   and Settings in turn, and ends at **Add course**. **Skip** (✕) ends it; see it again
   from **Settings → About → Show the app tour**.
5. Add your courses (Today shows an **Add course** button while you have none).

## Courses and meetings

Open **Courses → +** (or the button on an empty Today screen), or tap an empty spot in
**Week** (see below).

- **Course info** — the name, with its color as a dot at the end of the name field (tap
  it for the palette). **Short name** and **Course code** wait behind
  **+** chips until you need them. The short name (e.g. "Calc 1") is shown in the Week
  view when the full name doesn't fit; for a long name, the chip suggests one
  (**Use "…"**).
- **Weekly schedule** — each meeting is one line ("Lecture · Sunday, 10:00–12:00 ·
  201"). Tap it, or **Add meeting**, to edit it in a sheet (a dialog on wide screens):
  the type (Lecture / Practice / Lab / Other), how it **repeats** (weekly, every other
  week from week 1 or from week 2, or once), the day, start and end time (the length
  shows under the end), room, and links (e.g. the Zoom link). A new meeting can be on
  several days at once (same time and room): LecCheck adds one meeting per day. A
  meeting is added only with **Add**; changes to an existing one apply as you make them.
- **One-time sessions** — a single date (a make-up class, an exam review). Add them from
  the editor, the Courses menu, a course page (the clock button), or Week.
- **Attendance requirement** — set a minimum (50–100%) for all sessions or one type
  (e.g. 80% of practices). Choose whether watching a recording counts as attending.
- **Contacts** — the lecturer and teaching assistants, each with a name, a role and an
  email. The course page lists them with buttons to send an email or copy the address.
  A course's existing lecturer becomes its first contact.
- **Notes & links** — notes, the course website and extra links.

The requirement, contacts, and notes and links are rows with a summary that open when
tapped.
On wide windows, the editor shows two columns: the course on the left, its schedule on
the right.

Editing a meeting's time keeps all its marks and notes. If you move a meeting to another
**weekday** mid-semester, LecCheck asks whether the change applies to **all weeks** (each
session's marks and notes move to the new day of its week) or **from this week on** (past
weeks keep their old day and marks; every-other-week meetings keep their weeks).
Removing a meeting with marked sessions offers to **end it this week** instead, so its
past sessions stay in your stats. Changing a semester's dates warns when marked sessions
would fall outside them, and adds the holidays you chose for the new days.

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

**Sessions that don't count**: when a course doesn't take attendance in a session (say,
the first lecture), open it and turn off **Counts toward attendance** (or right-click it).
It keeps its status, but is left out of the percentage, the streak and the requirement:
a requirement of 80% of 10 lectures becomes 80% of 9. Lists show it with a small ✓̸ icon.

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
  shrunk a little to fit. When the full name doesn't fit, the course's short name is
  shown; without one, LecCheck shortens the name itself: small words go first ("to",
  "of"; "של", "על"), then long words are cut ("Infin. Calc. 1", "חשבון אינפי׳ 1"). Then come the room and the start time; the time is left out first in
  short sessions. A ✓ / ✗ shows how you marked it.
- **Add from the grid**: tap an empty spot for an hour there (from the half hour
  before the tap), or drag out the time: with the mouse on desktop, or long-press and
  drag on a phone (15-minute steps). **Quick add** opens beside it (a sheet on phones):
  pick a course, or **New course** and type its name right there; **Weekly** or
  **One-time**; the type; an optional room. **Save** adds it (with **Undo**), and **More
  options** opens the course editor with all of it filled in.
- **Move a session** (desktop): drag it to another time or day of the week, or drag its
  bottom edge to change when it ends; a ghost shows where it lands. A weekly meeting
  then asks **This week only** (like "Change date, time or room") or **Every week** (the
  meeting itself changes, and the sessions' marks move along with them). A snackbar
  offers **Undo** for a few seconds.
- The hours shown are at least 8:00–18:00, more when your schedule needs it; pinch with two fingers to zoom (desktop: Ctrl +
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
  (and syncs if you're signed in). Only sessions still pending get this reminder, and
  marking a session in the app takes its reminder off the screen.
- **Send a test notification** to check it works. If nothing can be shown, it says why.
- **Per course**: a course page has **Reminders for this course**, to turn them off for
  one course (e.g. one you only watch as recordings) on this device.

Permission is requested when you switch a reminder on. If the phone blocks LecCheck's
notifications later, **Today** shows a warning with an **Allow** button (it opens the
system settings when Android won't ask again). On Android, **Settings → Notifications**
also points out what can delay or stop reminders: exact alarms, battery optimization,
restricted background use, and, on some phones, autostart.

Canceled sessions get no reminders, and a session marked **Skipped** ahead gets no
"class starts soon". Reminders are planned up to three weeks ahead (two on iPhone) and
kept up to date as you edit (also when you leave the app right after), when you open the
app, and once a day in the background. They follow every
semester running then, whichever semester you're looking at. On Linux they fire while
LecCheck is running (also right after the computer wakes up; ones that are no longer
useful, like "class starts soon" for a class already under way, are skipped).

## Updates

On Android and Linux, LecCheck checks for a new version every time it starts. When there is one,
the **update window** opens when you start LecCheck, with what's new in it, and
**LecCheck X is available** appears at the top of Settings (and on Today, until **Later**).
**Later** asks again the next time you start LecCheck.

- The window says how big the download is. **Update** shows each step there: the
  download (size and speed; **Cancel** stops it), the check that the file is exactly the
  one released (it's read back and its SHA-256 must match the signed list of releases),
  then the install. On Android, the system then asks you to confirm the update; the first
  time, allow LecCheck to install apps. Your data stays.
- **Linux (Flatpak)**: Flatpak downloads and installs the update. The first time, your
  desktop asks whether LecCheck may update itself: choose **Update**. Flatpak checks the
  repository's signature ("Verified by Flatpak"), and **Restart** starts the new version.
  If you chose **Deny**, or a new version needs new permissions, the window says so and
  gives the command to run instead; `flatpak update` and software centers update it too.
- When something goes wrong, the window says what (no connection, not enough space, a
  file that doesn't match) and **Retry** tries again.
- LecCheck only offers releases from a list signed by the release build, so a changed
  list or file is never installed.
- **Download** appears instead for releases before 2.0.0-beta.8, and for Linux builds that
  aren't the Flatpak: it opens the release page.
- **What's new** opens the release notes, and **Skip this version** hides it until the
  next one.

### Linux: moving to the Flatpak

Since 2.0.0-beta.15, LecCheck for Linux is a Flatpak (2.0.0-beta.15 was the last
`install.sh` version). An `install.sh` install shows **LecCheck is moving to Flatpak** on
Today and in Settings, and a window when it starts:

1. **Your data**: signed in, everything is synced first, and you sign in again in the
   Flatpak. Otherwise **Save a backup…**, then **Import backup** on the Flatpak's welcome
   screen.
2. **Install the Flatpak** for your user (Flatpak itself must be installed:
   [flatpak.org/setup](https://flatpak.org/setup/)). The first time, its runtime downloads
   too (about 300 MB, shared with other Flatpak apps).
3. **Remove this version**: the old app goes; its data stays in
   `~/.local/share/com.leccheck.app` as one more backup (delete it once you're happy).
4. **Open LecCheck** starts the Flatpak.

Betas get betas and stable releases; stable versions get stable releases. Turn it off,
or check right away, in **Settings → About**. If you installed LecCheck with Obtainium,
Obtainium updates it instead. On iPhone, AltStore and SideStore handle updates.

## Reporting a problem

**Settings → About → Report a problem**: describe what happened, optionally add an email
for a reply, and choose whether to include diagnostics (app version, device, reminder and
sync state, and the recent log, which can mention course names). **See what's sent**
shows everything before you send. Reports go privately to the developer. Without a
connection they wait on the device and are sent later.

If the app hit an error last time, Today offers to report it (**Not now** dismisses it).

## Home-screen widget (Android)

Long-press your home screen → Widgets → **LecCheck**. The widget lists today's sessions
in your wallpaper colors; once a session starts, ✓ / ✗ buttons appear to mark it in one
tap (that session's "how was it?" reminder is then dropped). It holds a week, so it moves
on to the next day by itself; after a week without opening LecCheck it asks you to open
it. Tap the widget to open the app.

## Sync and accounts

**Settings → Account → Sign in with Google.** The sign-in opens in your browser.

- **Signing in on a new device** brings your account's data, then asks **Which
  semester?**: open one of your semesters, or **Start a new semester**. A brand-new
  account goes straight to setting up its first semester.
- **Data you created before signing in**: when your account is empty, it's added to the
  account. When the account has data too, you're asked: **Use my account's** (this
  device's data goes to an automatic backup first, see Settings → Data) or **Keep both**.
- If this device holds data from a *different* account, you're asked before it's replaced.
- If your account's cloud data was deleted in the last 30 days, signing in offers to
  **Bring back** it.
- The cloud icon in the top bar shows sync status (synced / syncing / offline). Click
  it, or **Sync now** under Account, to sync now: the icon turns, then says **Up to
  date** or that it couldn't sync. Right-click or long-press the icon for Settings.
  Changes made offline sync when you're back online.
- If LecCheck can't read your saved sign-in (on Linux, when the system keyring doesn't
  answer), Account and Today say so with **Retry**: you're still signed in.
- Changes the server refuses are kept on the device and listed under Account with a
  **Retry** button. If the sync server is busy (for example, it reached its free daily
  limit), Account shows **Sync paused until** a time; your changes wait on the device.
- **Sign out** — keep a copy on this device (unsynced changes sync when you sign back
  in), or remove it (an automatic backup is saved first).
- **Sign out on all devices** — revokes every session (it asks first, and does nothing
  if the server can't be reached).
- **Signed out on a device that keeps the account's data**: changes you make there wait,
  and **Today** says how many, with a **Sign in** button. Refused changes and "update
  LecCheck to keep syncing" also show on Today.
- **Delete cloud data** — asks you to type **DELETE** first, then removes your data from the server (this device keeps a copy;
  the server keeps a copy for 30 days in case it was a mistake). Other devices are signed
  out but keep their copy; if one of them signs in to the account again, its copy syncs
  back up.
- **Bring back deleted cloud data** — within those 30 days, Settings → Account shows when
  the data was deleted and brings it back to every device (signing in to the emptied
  account offers the same).

## Phones, tablets and desktop

The layout follows the window size, and the controls follow the device:

- **Phones**: bottom navigation; details and pickers open as bottom sheets.
- **Tablets and wide windows**: a navigation rail with an **Add** button (new course or
  one-time session; **Create** on desktop); Today and Stats in two columns; **Courses** shows the list and the
  selected course side by side; **Settings** has categories on the left.
- **Large desktop windows**: a sidebar with the logo, sync status, a **+ Create** button
  (new course or one-time session) and a month calendar: click a day to see its week in
  Week. The week you're looking at is highlighted, days with classes have a dot, and
  no-class days are dimmed (hover for the reason). Week gets a details panel.
- **iPhone**: iOS switches, alerts and date/time wheels.
- **Desktop**: a denser layout with smaller corners and one-line title bars, right-click
  menus, hover actions, keyboard shortcuts, time fields you can type into, and only one
  LecCheck window at a time (launching it again brings the window forward). Settings
  keeps the sidebar, so the tabs are one click away. On Linux the window opens at the size
  you left it (and maximized if it was).

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
| Shift+wheel, or the wheel over the day names | Previous / next week (Week tab) |
| T or Home | This week |
| Ctrl+Z | Undo the last change (Week tab) |
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
`~/.var/app/com.leccheck.app/data/com.leccheck.app/`, or
`~/.local/share/com.leccheck.app/` for `install.sh` installs; backups in `snapshots/`). Android's backup to your
Google Drive and iPhone's iCloud backup include them, so a new phone gets them back
(sign in again after a restore). When signed in, the server stores your rows in your own
private storage unit; nobody else's data is ever mixed with yours.
