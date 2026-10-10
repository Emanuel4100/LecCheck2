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

## Not yet verified on real hardware

These are built and compile, but have only been exercised in tests so far:

- The iOS build (first run happens in the release workflow on a macOS runner).
- Reminders work on a phone (a Samsung, once notifications are allowed); their action
  buttons with the app closed and the daily background top-up are untested
  (Settings → Developer has tools for testing them).
- The Android widget on a home screen.
- Google sign-in end-to-end (needs the Cloudflare + Google setup in [SETUP.md](SETUP.md));
  sync itself is verified end-to-end with the dev sign-in against a local Worker.

## Next (M4)

- **Desktop**: system tray (keep reminders running when the window is closed), keyboard
  shortcuts, Windows build + installer, AUR package, Flatpak.
- **iPhone widget** (WidgetKit) — needs App Group support from AltStore/SideStore.
- **Data safety, part 3**: SQLite WAL + `quick_check` on startup (offer the latest
  automatic backup if it fails; the check exists in Settings → Developer), re-fetch rows
  the app couldn't read after an update (they're kept and skipped since 2.0.0-beta.7),
  server-side value validation, HLC stored in SQLite, a multi-device convergence fuzz
  test, and an in-app "restore deleted cloud data" button (the server side exists).
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
