# Changelog

## 2.0.0-beta.15 — 2026-10-26

- **LecCheck for Linux is a Flatpak**, from its own repository (signed with its own key):
  `flatpak install --user https://emanuel4100.github.io/LecCheck2/leccheck.flatpakref`, or
  open that file in GNOME Software or Discover. It runs on the freedesktop runtime (about
  300 MB, shared with other Flatpak apps) and updates itself from then on. This is the last
  version for `install.sh`.
- **Move to the Flatpak**: LecCheck installed with `install.sh` offers the move on Today, in
  Settings and in a window when it starts. Signed in, everything syncs first and you sign
  in again in the Flatpak; otherwise save a backup and choose **Import backup** on the
  Flatpak's welcome screen. Then it installs the Flatpak, removes the old version (its
  data stays as one more backup) and opens the new one.
- **Updates through Flatpak**: the update window shows Flatpak's progress, then
  **Verified by Flatpak** (the repository is signed), and **Restart** starts the new
  version. The first time, your desktop asks whether LecCheck may update itself. If you
  chose Deny, or a new version needs new permissions, the window says what to run instead.
- **A clearer update window**: how big the download is before you start; a **Check the
  file** step you can watch, which reads the download back and checks it against the
  signed release, then checks itself off; What's new in its own box with a scrollbar,
  headings and bold, in English left to right in Hebrew too; and when something fails, what
  went wrong (no connection, not enough space, a file that doesn't match, Android's
  installer) instead of "Couldn't update".
- **Check now** opens the update window when there's a new version.

### Smaller things

- **Import backup** on the welcome screen, for a new device or the Flatpak.
- A sign-in kept by the keyring while the data folder was gone (a new install, or the
  Flatpak finding the old version's sign-in) looked signed in while nothing synced: an
  empty device now gets the account's data back, and one with data of its own stays
  signed out until you sign in.
- The update window that opens at startup no longer closes again by itself when LecCheck
  moves on from its splash screen.
- Linux no longer needs WebKitGTK or libsoup.
- Settings → Developer → **Copy diagnostics** says how LecCheck was installed on Linux.

## 2.0.0-beta.14 — 2026-10-26

- **Add on Week like in a calendar**: tap an empty spot for an hour there, drag out the
  time with the mouse, or on a phone long-press and drag (15-minute steps). **Quick add**
  opens beside it: pick a course or name a new one right there, weekly or one-time, the
  type and the room, then **Save** (with Undo). **More options** opens the course editor
  with everything filled in.
- **Move sessions by dragging** (desktop): drag a session to another time or day, or its
  bottom edge to change when it ends. A weekly meeting asks **This week only** or
  **Every week**, then **Undo** is offered for a few seconds. Every week moves the
  sessions' marks along to the new day.
- **Desktop sidebar like Google Calendar**: a raised **+ Create** button replaces Add,
  and a month calendar shows under the tabs: click a day to open its week; the week
  you're looking at is highlighted, class days have a dot, and no-class days are dimmed
  with their name on hover.
- The Week grid scrolls by itself when a drag nears its top or bottom.

## 2.0.0-beta.13 — 2026-10-26

- **Linux: no more surprise sign-outs.** On a keyring without a password (common with
  automatic login), GNOME Keyring emptied LecCheck's saved sign-in whenever it re-read
  its file, because the value contained backslashes, so you came back signed out. The
  sign-in is now saved in a form without any, and an older one is converted the first
  time it's read. If you were signed out, sign in once more.
- **A sign-in that can't be read isn't a sign-out**: when the system keyring doesn't
  answer, LecCheck asks it again, and if it still can't, Account and Today say so with
  **Retry** and **Sign in again** instead of showing you as signed out. Nothing is removed.
- **Canceling a session drops its reminder.** A canceled class could still announce
  itself: reminders were updated two seconds after a change, and leaving the app (home,
  Recents, swiping it away) in those seconds kept the old one. They're now updated at
  once when you leave.
- **Reminders on screen go away when they're out of date**: "class starts soon" for a
  session you canceled or skipped since, and "how was class?" for one you marked in the
  app (also last night's).
- **Skipped ahead, no reminder**: a session marked Skipped before it starts gets no
  "class starts soon".
- **Sync now shows what it did**: the icon turns while it syncs, then the cloud with its
  check pops in ("Up to date"), or it says it couldn't sync (your changes are kept). It
  also checks that the connection still works: before, pressing it while synced did
  nothing at all. With reduced motion the icons just change, and screen readers hear
  the result.
- **Click the cloud icon to sync**: in the title bar (or the sidebar on wide windows),
  clicking it syncs now, like Ctrl+R / F5; right-click or long-press opens Settings.
- **Linux remembers the window size** and whether it was maximized: it was never saved.

### Smaller things

- Settings → Developer's log notes each start's sign-in and why a sign-in was ever
  removed, and **Copy diagnostics** includes the sign-in state.
- Settings → Developer → **Sync now** says whether the server answered.
- Builds pointed at a local test server keep their own sign-in, so testing can't sign
  out the installed app.

## 2.0.0-beta.12 — 2026-10-15

- **Moving a meeting to another day** kept the session's mark and notes but dropped
  **Counts toward attendance** when the new day already had a record, so a session left
  out quietly counted again.
- A failed update no longer draws its steps as if everything had finished.
- Contact cards in the course editor line up in Hebrew.

## 2.0.0-beta.11 — 2026-10-15

- **Linux: updates no longer erase your data.** LecCheck kept its database and settings
  in the folder `install.sh` installs it to, so every update deleted them and you came
  back signed out with an empty schedule. Data now lives in
  `~/.local/share/com.leccheck.app`, and the next update moves it there first.
- **Android: opening LecCheck from the home-screen widget** no longer shows an error
  ("no routes for location").
- **Update window**: when a new version is out, a window opens at launch with what's new,
  and **Update** shows each step there: the download with its size and speed, the check
  that the file is exactly the released one, then the install and **Restart**. **Later**
  asks again next time; **Skip this version** waits for the next one. Updates are now
  signed: LecCheck only installs releases from a list signed by the release build.
- **Contacts**: a course has its lecturer and teaching assistants, each with a name, role
  and email, edited in a **Contacts** row of the course editor. The course page lists them
  with buttons to send an email or copy the address. A course's lecturer becomes its first
  contact.
- **Sessions that don't count**: turn off **Counts toward attendance** on a session (in
  its details, or right-click) when the course doesn't take attendance in it, like a first
  lecture. It keeps its status but is left out of the percentage, the streak and the
  requirement, so 80% of 10 lectures becomes 80% of 9.
- **Canceled sessions** keep their course color with diagonal stripes, instead of turning
  gray, and have their own color in status icons.
- **Desktop**: a denser layout with smaller corners, one-line title bars and a regular
  **Add** button; **Settings** keeps the sidebar, so the tabs are one click away. On Linux
  the window reopens at the size you left it, maximized if it was.

## 2.0.0-beta.10 — 2026-10-13

- **A roomier course editor**. Meetings are one line each ("Lecture · Sunday,
  10:00–12:00 · 201") and open in a sheet (a dialog on wide screens) where the type and
  how it repeats are menus, and the length shows under the end time. A new meeting can be
  on several days at once. Short name, code and lecturer wait behind **+** chips, the
  color is a dot in the name field, and the attendance requirement, notes and links fold
  into rows. Wide windows get two columns.
- **Add from Week**: tap an empty spot to add a new course, a meeting of a course, or a
  one-time session there, with the day and time filled in. The grid always shows at
  least 8:00–18:00 so there's room to tap.
- **Course page**: sessions are listed by type ("Lecture #3") instead of repeating the
  course name, and on phones **Add one-time session** moved to the app bar instead of
  covering the list. Meetings that start mid-semester or every other week from week 2
  now say so.
- **Today**: the class in progress is marked from the Now card only, not listed again
  under Needs marking. Session rows no longer break mid-detail: the type and day (and
  the time when it fits) come first, then the room after a pin. The swipe hint goes away
  once you've swiped, and classes that haven't started yet don't show the "to mark"
  circle.
- **Stats**: the weekly chart shows each week's percentage and labels its lines (0%,
  50%, 100%); the attendance card says it briefly, with the full rule behind an ⓘ
  button.
- **Welcome**: the language switch moved to the top corner.

## 2.0.0-beta.9 — 2026-10-12

- **No more empty semesters when signing in** (issue #2). Signing in on a new device
  sometimes opened the semester setup before the account's data arrived, and creating
  it added an empty semester to the account, again on every new device. Now LecCheck
  waits for your data (with **Retry** if it doesn't come), then asks **Which semester?**
  (or **Start a new semester**). A semester made before signing in no longer joins the
  account silently: when the account has data too, you choose **Use my account's** (the
  device's data is backed up first) or **Keep both**. An account whose data was deleted
  in the last 30 days offers to bring it back.
- **A quick tour of the app** (issue #1) after setting up the first semester: each step
  dims the app around one item (Today, Week, Courses, Stats, Settings) and explains it,
  and the last one opens **Add course**. Replay it from Settings → About → **Show the app
  tour**. Works on phones and wide windows, in English and Hebrew, and with the keyboard
  (arrows, Enter, Esc).
- **Long course names in Week**: when a name doesn't fit a tile and the course has no
  short name, LecCheck shortens it, dropping small words, then cutting long ones
  ("Infinitesimal Calculus 1" → "Infin. Calc. 1", "חשבון אינפיניטסימלי 1" → "חשבון
  אינפי׳ 1"), instead of cutting it off. The course editor suggests a short name for
  long names.
- **Respects "remove animations"**: with the system's reduced-motion setting on, LecCheck
  switches tabs, turns week pages and draws charts without animating.
- **What's new** on the update card now shows the release's changes (the release notes
  carry this CHANGELOG section), not just the download links.
- **Bring back deleted cloud data**: Settings → Account offers it for 30 days after
  **Delete cloud data** (until now only the server could).

## 2.0.0-beta.8 — 2026-10-12

Coming from beta.7 or older: install this version as before (Download, or
`./install.sh` on Linux). From the next release on, **Update** does it inside the app.

- **Update from inside the app** (Android, and Linux installed with `./install.sh`):
  **Update** on the update card downloads the new version with a progress bar, checks it
  against the release's SHA-256, then opens Android's installer (one tap to confirm) or,
  on Linux, installs it and offers **Restart**. Older releases still open the browser.
  Updating on Linux now swaps the app folder only after the copy succeeds.
- **Check now** (Settings → About) shows that it's checking, and a new version found there
  now says so right away, with **Update**. It used to appear only in the card at the top
  of Settings, scrolled out of sight.

## 2.0.0-beta.7 — 2026-10-11

- **Reminders follow the semester running now**: looking at last semester (its stats, say)
  stopped this semester's reminders and emptied the widget until you switched back. Both
  now cover every semester running then. A semester starting next week gets its first
  reminders in time.
- **Mute a course**: a course page has **Reminders for this course**, to turn them off for
  one course on this device (Settings → Notifications lists the muted ones).
- **Marks follow a meeting to its new day**: moving a weekly meeting to another weekday
  for **All weeks** hid every marked session (they stayed keyed to the old day). Now each
  session's marks, notes and moves go with it. **From this week on** also moves sessions
  marked ahead of time, and an every-other-week meeting keeps its weeks instead of
  restarting the cycle.
- **Removing a meeting** with marked sessions offers to **end it this week**, keeping its
  past sessions in your stats. Ended and split meetings show their dates.
- **Changing a semester's dates** warns when marked sessions would be hidden, and adds the
  holidays you chose for the new days.
- **Today** says when this device is signed out with changes waiting (with a **Sign in**
  button), when changes were refused, and when an update is needed to sync. The update
  notice and the "report the last error" card now also appear on phones (only the wide
  layout had them, the update notice twice).
- **Widget**: it holds a week of days, so it moves on to the next day at midnight without
  the app (after a week it asks to open LecCheck). Marking from the widget drops that
  session's "How was class?" reminder.
- **Linux**: reminders come on time after the computer wakes up (they came late by however
  long it slept), and stale ones are skipped. No more error at every start (the app then
  offered to report it each time). The daily backup no longer fails when two start at once.
- **Recently deleted** lists only what was deleted on or synced to this device recently:
  on a newly synced device it showed every old delete as new, and restoring a course could
  bring back things deleted separately.
- **Sturdier with odd data**: a row with a date that doesn't exist (from a file or
  another device) no longer hides its whole semester, and imports skip such rows and say
  how many. Marking a session whose record was deleted with its meeting works again.
- **Sign out on all devices** asks first, and does nothing if the server can't be
  reached (it used to sign this device out anyway). Errors from it and from **Delete cloud
  data** are shown.
- **Long notes**: notes stop at 10,000 characters; the server takes changes up to 32 KB
  (16 KB before, so a long pasted note was refused on every retry).

## 2.0.0-beta.6 — 2026-10-11

- **Sync keeps going after an error**: one change or message that failed to apply (a
  database error, a row it couldn't read) stopped sync until the app was restarted, while
  it still said "Syncing". Now it reconnects and carries on.
- **Retry no longer undoes newer edits**: retrying a change the server refused gave it a
  newer clock than edits made since, so an older value could win. Fields edited since are
  left to the newer edit.
- **Big pushes**: changes are sent in batches of at most 512 KB, so a lot of long notes at
  once (an import) no longer gets stuck resending a batch the server can't take.
- **Stays signed in**: an app left open for weeks (desktop) renews its sign-in, instead
  of being signed out when the token runs out after 60 days. Tapping "Sync now" while a
  connection is opening no longer opens a second one.
- **Safer links**: only web, mail and phone links open. Links to local files or other
  apps' screens (e.g. from an imported file) say "Can't open this link".
- **Android widget**: other apps can no longer mark sessions through the widget's
  buttons.
- **Update notice**: ignores an update whose links aren't https.
- **Sync server**:
  - per-account limits, so one account can't use up the free plan for everyone:
    10,000 rows written a day, 50,000 rows, 25 MB, 64 KB per row. Changes over a limit
    wait on the device;
  - a revoked session can no longer delete cloud data, sign out other devices or renew;
  - session tokens are only accepted in the `Authorization` header;
  - field names are validated;
  - oversized bug reports are refused before they're read;
  - a failed point-in-time restore reports the failure;
  - deleted cloud data is purged 30 days after each delete, not after the last one.

## 2.0.0-beta.5 — 2026-10-09

- **Reminders on Android**: when Android blocked LecCheck's notifications, nothing said
  so: the only warning was inside Settings, and the test button reported success. Today
  now warns while reminders are on but blocked, with an **Allow** button that opens the
  system settings when Android won't ask again. Both test buttons say why nothing appears.
- **Reminders keep coming**: they're no longer cancelled while the app starts up, and
  turning them off no longer dismisses notifications already on screen. After a force stop
  (or "swipe away" on some phones), missing alarms are found and scheduled again. Android
  plans three weeks ahead instead of two, and tops reminders up once a day in the
  background and after each notification button.
- **Holidays**: Settings → Semester → **Jewish and Israeli holidays** cancels classes on
  the holidays you tick, with the usual days off at Israeli universities suggested.
  Dates follow Israel by default, or two-day festivals as abroad. A new semester can
  start with them. Session details and the Week's day headers show the holiday's name.
- **Update notice** (Android and Linux): "LecCheck X is available" at the top of Settings
  and once on Today, with a download for your device. Checked once a day; turn it off in
  Settings → About. Obtainium installs and iPhone keep updating as before.
- **Report a problem** (Settings → About): sends a description and, if you leave it on,
  diagnostics you can read first; they go privately to the developer, and wait on the
  device while offline. After an error, Today offers to report it.
- **Week**: smoother swipes and zoom: changing weeks no longer rebuilds both visible
  weeks, tile layouts are measured once, and a tap or hover repaints only its day. On
  desktop and iPhone, taps show a plain ripple instead of Android's sparkle effect.
- **Settings → Developer → Rendering**: the display's refresh rate, frames per second while
  animating, and frame times, also included in bug reports. On Linux, Flutter draws at
  60 fps whatever the monitor's rate (an upstream limit).
- **Sync server**: health checks, and automatic deploys that are tested first, checked
  live, and rolled back by themselves if the new version fails. App releases wait until
  their server is live.
- **Settings → Notifications** points out what else can delay reminders on Android:
  exact alarms, battery optimization (one tap to turn it off), restricted background use,
  and autostart on phones that need it.
- **iPhone**: the AltStore / SideStore source now has a permanent address that always
  lists the newest build, betas included:
  `https://raw.githubusercontent.com/Emanuel4100/LecCheck2/altstore/altstore-source.json`.
  The old "latest" address didn't work while every release was a beta.

## 2.0.0-beta.4 — 2026-10-08

- **Reminders on Android**: in 2.0.0-beta.3 (and beta.2), release builds left out the
  status-bar icon, so notifications couldn't start: no reminders, and the test button
  did nothing. Fixed. The test button now asks for permission first and says why if
  nothing can be shown.
- **Week**: course names are easier to read on phones. The ✓ / ✗ moves out of the name's
  way, names wrap over more lines instead of "Calcu…", and long words shrink a little to
  fit. In short sessions the start time is left out before the room.
- **Short names**: a course can have an optional short name (e.g. "Calc 1"). The Week
  view shows it when the full name doesn't fit.
- **Developer mode** (tap Settings → About → Version 7 times): test notifications,
  including after-class buttons pressed with the app closed; sync tools, including
  pretending the server is busy; database checks and backup sizes; device details
  (Android version, battery optimization); a log of errors and background actions; and
  copying all of it for a bug report.
- **License**: LecCheck is now free software under the GNU GPL v3 or later. Settings →
  About shows the license.
- **Data safety**: database upgrades are tested from every earlier version. Courses
  synced or backed up by older versions load without the new field.

## 2.0.0-beta.3 — 2026-10-07

Each platform gets its own layout, input and options.

- **Desktop & tablets**: navigation rail with an Add button (extended sidebar on large
  windows); Today and Stats in two columns; Courses as list + details; a details panel
  beside the Week grid; Settings with categories; content no longer stretches across wide
  windows.
- **Desktop input**: right-click menus and hover ✓ / ✗ on sessions (no accidental mouse
  swipes), ‹ › week buttons, Ctrl + wheel / trackpad pinch zoom (remembered), hours that
  fill the window, keyboard shortcuts (F1 lists them), typed time entry, selectable
  session details.
- **Linux**: one window at a time (a second launch brings it forward), no GTK header bar
  outside GNOME (e.g. Hyprland), "LecCheck" title, minimum window size.
- **Android**: predictive back, edge-to-edge with transparent system bars on every
  version, "Add widget to home screen" in Settings, a warning when notifications are
  turned off for the app.
- **iPhone**: iOS switches, alerts and date/time wheels; no Wallpaper theme (iOS has no
  wallpaper colors); a reminder to refresh the app in AltStore/SideStore.

Data safety: nothing you enter should ever be overwritten, dropped or lost.

- **Signing back in** no longer overwrites newer edits from your other devices or brings
  back deleted items. Signing out with "Keep on this device" keeps unsynced edits, and
  they sync when you sign in again.
- **Editors** save only the fields you changed, so edits that synced in while a course or
  semester was open are kept, and meetings added elsewhere aren't deleted.
- **Sync** keeps changes the server refuses (shown in Account with a Retry button)
  instead of dropping them, corrects a wrong device clock from the server's time, and
  fixes this device's copy when one of its edits loses to a newer one.
- **Import** shows what a backup would change. "Add missing" (the default) never changes
  existing data; "Replace" saves an automatic backup first.
- **Automatic backups**: a daily one, plus one before imports, restores, removing data
  on sign-out, and switching accounts. Restore them from Settings → Data.
- **Recently deleted**: restore semesters and courses deleted in the last 30 days.
- **Backups off the device**: Android's backup to your Google Drive includes the database
  and the automatic backups, but not the sign-in (sign in again after a restore). On
  iPhone, iCloud backup already included them. Automatic backups are compressed.
- **Free plan**: if the sync server ever reaches Cloudflare's free daily limit, sync
  pauses until the limit resets (Account shows until when) instead of retrying, and
  your changes wait on the device. Several edits to the same item are saved on the
  server as one write.
- **Server**: "Delete cloud data" signs out every device and keeps a copy for 30 days
  in case it was a mistake (restored on request for now), and point-in-time restore is
  available. If the server's data is ever reset or restored, devices re-offer what
  they have.

## 2.0.0-beta.2 — 2026-10-05

First public beta of LecCheck 2 (Android, iPhone via AltStore/SideStore, Linux; beta.1
was never published because its Linux build failed), with
everything listed under 2.0.0 below plus:

- Live sync server with Google sign-in; homepage and privacy policy pages.
- Desktop keeps its sync connection while the window is hidden and reconnects by itself
  after sleep.
- After signing in, the app switches to the semester restored from your account.
- Clearer sign-out dialog: your data stays in your account.

Not yet verified on real devices: reminders and their buttons, the Android widget, the
iPhone build.

## 2.0.0 — 2026-10-04

Complete rebuild of LecCheck.

### New
- Local-first architecture: SQLite on every device, instant marking, works offline.
- Live sync between devices via a free Cloudflare Worker; per-field merges, so offline
  edits on two devices both survive. Optional Google sign-in (guest mode by default).
- Today screen with a Now/Next card, countdown, and a "needs marking" queue with swipe
  gestures, bulk marking and undo.
- Week grid: swipe between weeks, pinned headers, live "now" line, overlapping sessions
  side by side, pinch zoom, no-class days from the day header.
- Courses tab with attendance rings and **attendance requirements** ("can miss N more").
- Every-other-week meetings, valid date ranges, one-time sessions, and "this week only"
  changes of date/time/room.
- Stats: streaks, per-course and per-type breakdowns, weekly trend, catch-up list.
- **Reminders** before class and after class with Attended / Missed / Watched buttons
  that work without opening the app.
- **Android home-screen widget** with one-tap marking.
- Material 3 Expressive design: spring animations, 7 color themes + wallpaper colors,
  pure-black mode, custom icon set, new app icon and splash, Rubik font.
- Backups: JSON export/import; imports LecCheck v1 backups.
- Releases: signed Android APK, iPhone IPA for AltStore/SideStore, Linux installer.

### Fixed (compared with v1)
- Changing a meeting's time no longer erases its attendance history.
- Session types no longer turn into "Lecture" after switching language.
- No duplicate lectures around daylight-saving changes.
- Hiding weekdays no longer shifts dates in the week view.
- Destructive actions ask first and can be undone; signing in to another account never
  pushes the previous account's data into it.
- No network on startup; marking a session no longer rebuilds the whole app.
