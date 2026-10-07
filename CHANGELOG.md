# Changelog

## Unreleased

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
