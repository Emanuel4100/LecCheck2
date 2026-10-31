# Roadmap

## Done — LecCheck 2.0 (M0–M3)

- **Foundation**: occurrence engine (DST-safe, every-other-week, valid ranges, one-offs,
  holiday layer, per-session moves), Drift schema, transactional repository with undo,
  English/Hebrew, Material 3 Expressive theme with 7 presets, CI.
- **App**: onboarding, Today, Week, Courses + editor, session details, Stats, Settings,
  all-sessions search, backup export/import (including v1 files), custom icon font, new
  app icon and splash.
- **Sync**: Cloudflare Worker + per-user Durable Object, per-field last-writer-wins with
  hybrid logical clocks, WebSocket live sync with HTTP fallback, Google sign-in brokered
  by the Worker (PKCE), guest → account merge, sign out everywhere, delete cloud data.
- **Extras**: before-class and after-class reminders with background actions, attendance
  requirements, Android home-screen widget, release pipeline (APK, IPA + AltStore source,
  Linux tarball).
- **Data safety** (2.0.0-beta.3): add-only re-joins and imports, editors that save only
  what changed, refused changes kept, corrections for lost writes, automatic local
  backups, Recently deleted, 30-day trash for deleted cloud data, dataset ids for
  server resets, Android backup rules, pausing sync at the free plan's daily limit.
- **Fixes and testing tools** (2.0.0-beta.4): notifications work in Android release
  builds again; readable course names in the Week view and optional short names; a
  hidden developer mode for testing on real phones (test notifications, sync, backups,
  device details, a log); database migration tests against every earlier schema;
  GPL-3.0-or-later license.
- **Reliability, holidays, updates** (2.0.0-beta.5): Today warns when Android blocks
  reminders, and reminders are re-armed after a force stop and topped up in the
  background; Jewish and Israeli holidays as no-class days; an update notice for Android
  and Linux; opt-in bug reports; a smoother Week view and rendering stats; server health
  checks and automatic deploys with smoke tests and rollback.
- **Security and sync fixes** (2.0.0-beta.6): sync recovers from a failed step instead
  of stopping until a restart; Retry no longer undoes newer edits; pushes are capped in
  size; long-running apps renew their sign-in; only web, mail and phone links open; the
  widget's buttons can't be triggered by other apps. The server has per-account limits
  (so one account can't use up the free plan for everyone) and refuses revoked sessions
  for every account action.
- **Reminders that follow the semester, history-safe edits** (2.0.0-beta.7): reminders
  and the widget cover every semester running then, whichever one is shown; mute a
  course's reminders; the widget moves on at midnight by itself; Linux reminders survive
  sleep. Moving a meeting to another day keeps its marks, removing one can end it
  instead, and changing a semester's dates warns and extends its holidays. Today shows
  when changes can't sync. Rows the app can't read are skipped instead of hiding a
  semester.
- **Update from inside the app** (2.0.0-beta.8): on Android, and on Linux installs made by
  `install.sh`, Update downloads the release, checks its SHA-256 (now in `update.json`)
  and installs it: Android's installer, or the tarball's own `install.sh` plus Restart.
  Check now shows that it's checking and what it found.
- **Sign-in without stray semesters, an app tour** (2.0.0-beta.9): signing in asks what
  to do when the device and the account both have data, waits for the account's data,
  then asks which semester to open (issue #2); a tour after the first setup (issue #1).
  Deleted cloud data can be brought back from Settings, long course names are shortened
  in Week instead of cut off, What's new shows the changes, and "remove animations" is
  respected.
- **A roomier course editor, adding from Week** (2.0.0-beta.10): meetings are one-line
  rows that open a sheet (type and repeat as menus, several days at once), optional
  fields wait behind "+" chips, and the requirement, notes and links fold into rows; two
  columns on wide windows. Tapping an empty spot in Week adds a course, a meeting or a
  one-time session there. Today, Stats, the course page and the welcome screen got a
  tidy-up from a UI review.
- **An update you can watch, course contacts, a desktop layout** (2.0.0-beta.11): the
  update window shows what's new and then each step (download with size and speed, the
  file check, install), and releases are signed so only LecCheck's own are installed.
  Courses keep their lecturer and teaching assistants with email; a session can be left
  out of attendance; canceled sessions keep their color with stripes. Desktop is denser,
  with one-line title bars and Settings inside the sidebar, and the Linux window reopens
  at its old size. Linux updates no longer erased the database, and the Android widget
  opens the app again.
- **Three bugs a code review found** (2.0.0-beta.12): moving a meeting to another day
  dropped "Counts toward attendance" when the new day already had a record, so a session
  left out of attendance counted again; a failed update drew its steps as if they had
  finished; contact cards didn't mirror in Hebrew.
- **Reminders that follow cancels, a steadier Linux sign-in** (2.0.0-beta.13): canceling
  or skipping a session drops its reminder even when the app is left right after, and
  out-of-date reminders leave the screen; Linux stays signed in on keyrings without a
  password (GNOME Keyring emptied secrets with backslashes when it re-read its file); Sync now animates and says what happened,
  and the cloud icon syncs; the Linux window size is saved.
- **Week like a calendar** (2.0.0-beta.14): tap or drag out a time on Week (long-press
  and drag on phones) and quick add the meeting beside it, to a course or a new one;
  drag sessions to move or resize them on desktop, this week only or every week, with
  Undo; a raised **+ Create** button and a month calendar in the desktop sidebar.

- **Linux as a Flatpak, a clearer update window** (2.0.0-beta.15): LecCheck for Linux is a
  Flatpak from its own signed repository on GitHub Pages (freedesktop 26.08, no
  WebKitGTK), updating itself through the Flatpak portal with Restart; `install.sh`
  installs move to it from inside the app. The update window shows the download's size, a
  check of the file you can watch, What's new in its own box, and why something failed.
  Import backup on the welcome screen.
- **Typing that works, quicker on desktop** (2.0.0-beta.16): keys that are shortcuts reach
  text fields; updates checked at every start; days in Today's countdown; type DELETE to
  delete cloud data; a Today button on Week; Ctrl+Z and the mouse wheel on Week; a tab to
  open on for each device. Linux releases are only the Flatpak.

## Not yet verified on real hardware

These are built and compile, but have only been exercised in tests so far:

- The iOS build (first run happens in the release workflow on a macOS runner).
- Reminders work on a phone (a Samsung, once notifications are allowed); their action
  buttons with the app closed and the daily background top-up are untested
  (Settings → Developer has tools for testing them).
- The Android widget on a home screen.
- Updating from inside the app (Android's installer, Linux's Restart): the first real
  update is beta.8 → the next release, or earlier with a test manifest (see
  [DEVELOPMENT.md](DEVELOPMENT.md) "Update notice").
- Google sign-in end-to-end (needs the Cloudflare + Google setup in [SETUP.md](SETUP.md));
  sync itself is verified end-to-end with the dev sign-in against a local Worker.

## Next: 2.0.0-beta.15 — Linux as a Flatpak, a better update window

Released 2026-10-26. The repository's key (fingerprint 379AB289…AA444FF9) is in the
password manager and the FLATPAK_GPG_KEY secret; GitHub Pages serves the repository.

**Flatpak, replacing the tarball**
- From LecCheck's own GPG-signed repository on **GitHub Pages**, with a `.flatpakref`
  (adds the remote, runtime from Flathub) and an install page (`scripts/flatpak_site.py`).
  One `stable` branch while in beta; each release publishes a fresh repository.
- Runtime **org.freedesktop.Platform 26.08** (smaller than GNOME's, supported to about
  Aug 2028). The bundle needs only GTK 3 and libsecret: `desktop_webview_window`
  (WebKitGTK, from `flutter_web_auth_2`, unused on Linux) is replaced by a stand-in in
  `app/third_party/`. The manifest (`app/linux/flatpak/`) repackages the CI bundle; CI
  builds it in Flathub's `freedesktop-26.08` container.
- Sign-in: the Secret portal where the desktop has one, the keyring
  (`--talk-name=org.freedesktop.secrets`) elsewhere, since Hyprland and Sway have none.
- App id stays `com.leccheck.app`; the time zone works in the sandbox (`/etc/timezone`);
  metainfo `<releases>` come from CHANGELOG (`scripts/metainfo_releases.py`), screenshots
  from the desktop goldens.
- **Move to the Flatpak** in beta.15 (the last tarball): signed in, sync then sign in
  again; otherwise a backup to import on the Flatpak's welcome screen. Then `flatpak
  install --user`, remove the tarball's files (data stays), open the Flatpak.
- Verified headless (Xvfb, private D-Bus, isolated installation): portal update with
  progress, "Verified by Flatpak", Restart into the latest version; and the move from an
  `install.sh` install.

**2.0.0-beta.16**: no tarball in the release (`update.json` lists no `linux` file, and
beta.15's tarball installs only see Move); `scripts/linux-install.sh` is gone. `TarballInstall`
goes once nobody is left on the tarball. Also the quick fixes in the changelog's Unreleased.

**The to-do list, by release**
- Done in 2.0.0-beta.11: course emails (contacts), canceled sessions not gray, a session
  that doesn't count toward attendance, Linux updates logging out, the widget's
  "no routes" error.
- Done in 2.0.0-beta.13: canceled meetings keep no notification, the Linux sign-out on
  close (root cause: GNOME Keyring and backslashes), a sync animation.
- Done in 2.0.0-beta.14: drag to create on Week, Google Calendar-style desktop (Create
  button, month in the sidebar, no Add).
- Done in 2.0.0-beta.15: the self-updater's progress and SHA-256 check animation, a
  proper Linux install (Flatpak).
- Done in 2.0.0-beta.16: the typing bug, updates at every start, days in the countdown,
  type DELETE, the "this week" button, Ctrl+Z, wheel navigation, the tab to open on.
- In 2.0.0-beta.17: the redesign (Today, Stats, mobile settings, recording link, off days).
- In 2.0.0-beta.18: reception hours, the timetable import through a chatbot, a first Hebrew
  wording pass.
- Later: a translation platform, the way open source apps do it. On hold: crash reporting, Panopto, Linux above 60 Hz.
- Still open after that: Linux at more than 60 Hz (waiting on a measurement), and a more
  desktop-like Linux layout beyond the sidebar (ask what
  feels mobile).

## Later (M4)

- **Desktop**: system tray (keep reminders running when the window is closed), Windows
  build + installer.
- **iPhone widget** (WidgetKit) — needs App Group support from AltStore/SideStore.
- **Data safety, part 3**: SQLite WAL + `quick_check` on startup (offer the latest
  automatic backup if it fails; the check exists in Settings → Developer), re-fetch rows
  the app couldn't read after an update (they're kept and skipped since 2.0.0-beta.7),
  server-side value validation, HLC stored in SQLite, and a multi-device convergence
  fuzz test.
- **Stats v2**: per-week heatmap, requirement projections.
- **Polish**: accessibility pass (semantics, large fonts), more animations, tablet
  two-pane layouts.

## Ideas (not planned)

Exams and assignments, grades / GPA, holidays of other calendars (Muslim, Christian,
Druze) and partial no-class days ("no classes after 13:00"), sharing a course
with classmates by link/QR, a calendar (ICS) feed.

## Known limitations

- The free workers.dev plan has no rate limiting in front of the Worker: anyone can spend
  its 100,000 requests a day with calls that are refused (sync then pauses until 00:00
  UTC, and nothing is lost), and the 50 bug reports a day can be used up the same way.
  Per-account limits stop a signed-in account from using up the storage and row-write
  limits. A custom domain would allow Cloudflare's rate limiting rules.

- Reminders on Linux fire only while the app is running.
- A new column added to a synced table in a future version is ignored by older app
  versions that receive it (they keep working).
- Free Apple IDs need AltStore/SideStore to refresh the app every 7 days.
