# Changelog

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
