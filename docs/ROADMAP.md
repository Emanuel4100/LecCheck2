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

## Not yet verified on real hardware

These are built and compile, but have only been exercised in tests so far:

- The iOS build (first run happens in the release workflow on a macOS runner).
- Reminders and their action buttons on a phone; the Android widget on a home screen.
- Google sign-in end-to-end (needs the Cloudflare + Google setup in [SETUP.md](SETUP.md));
  sync itself is verified end-to-end with the dev sign-in against a local Worker.

## Next (M4)

- **Desktop**: system tray (keep reminders running when the window is closed), keyboard
  shortcuts, Windows build + installer, AUR package, Flatpak.
- **iPhone widget** (WidgetKit) — needs App Group support from AltStore/SideStore.
- **Data safety, part 3**: SQLite WAL + `quick_check` on startup (offer the latest
  automatic backup if it fails), drift migration tests, keep server rows the app can't
  read yet (and re-fetch after an update), server-side value validation, HLC stored in
  SQLite, a multi-device convergence fuzz test, and an in-app "restore deleted cloud
  data" button (the server side exists).
- **Reminders**: mute per course; daily background top-up (workmanager) so reminders stay
  scheduled even if the app isn't opened for two weeks.
- **Stats v2**: per-week heatmap, requirement projections.
- **Polish**: accessibility pass (semantics, large fonts), more animations, tablet
  two-pane layouts.

## Ideas (not planned)

Exams and assignments, grades / GPA, automatic holiday import (Hebcal), sharing a course
with classmates by link/QR, a calendar (ICS) feed.

## Known limitations

- Reminders on Linux fire only while the app is running.
- A new column added to a synced table in a future version is ignored by older app
  versions that receive it (they keep working).
- Free Apple IDs need AltStore/SideStore to refresh the app every 7 days.
