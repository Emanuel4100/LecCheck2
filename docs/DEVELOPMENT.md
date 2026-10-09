# Development

## Toolchain

Versions are pinned in [`mise.toml`](../mise.toml): Flutter 3.47.6, Temurin JDK 21,
Node 22, ninja. With [mise](https://mise.jdx.dev) installed:

```bash
mise install
```

Other requirements:

- **Linux builds**: clang, cmake, pkg-config, GTK 3 and libsecret development files
  (Arch: `base-devel gtk3 libsecret`; Ubuntu: `libgtk-3-dev libsecret-1-dev`).
- **Android builds**: the Android SDK in `~/Android/Sdk` (`mise.toml` sets
  `ANDROID_HOME`). Gradle downloads the NDK and other pieces on the first build.
- **iOS builds**: macOS with Xcode — or let the release workflow build the IPA.

## Repository layout

```
app/                      Flutter app
  lib/domain/             pure Dart domain logic (engine, stats, requirements, reminders)
  lib/core/               database, sync, auth, notifications, widget, backup, icons
  lib/app/                providers, router, shell, theme, formatting, controllers
  lib/features/           screens
  lib/l10n/               app_en.arb, app_he.arb (+ generated gen/)
  test/                   unit + widget tests (run in CI)
  test_screenshots/       offscreen screenshot renders (goldens/)
  test_sync/              two-device sync test against a local Worker
  android/…/widget/       Jetpack Glance home-screen widget (Kotlin)
server/                   Cloudflare Worker sync server (TypeScript) — see server/README.md
design/                   icon and logo sources — see design/README.md
scripts/                  linux-install.sh, altstore_source.py
.github/workflows/        ci.yml, release.yml, deploy-server.yml
```

## Everyday commands (from `app/`)

```bash
flutter run -d linux                                  # or -d <android device>
flutter analyze
TZ=Asia/Jerusalem flutter test                        # unit + widget tests
flutter test test_screenshots --update-goldens        # re-render screen previews
```

With sync against a local server (see [server/README.md](../server/README.md)):

```bash
flutter run -d linux --dart-define=API_BASE_URL=http://localhost:8787 --dart-define=DEV_AUTH=true
flutter test test_sync --dart-define=API_BASE_URL=http://localhost:8787
```

Server (from `server/`): `npm test`, `npm run typecheck`, `npx wrangler dev`.

## Common changes

### Add or change a string

1. Add the key to `lib/l10n/app_en.arb` **and** `lib/l10n/app_he.arb` (use ICU plurals
   with `=1`, `=2` and `other` for Hebrew).
2. Run `flutter gen-l10n` (also runs automatically on `flutter run`).
3. Use it as `AppLocalizations.of(context).yourKey`.

### Change the database schema

1. Edit `lib/core/db/tables.dart`. Add new columns at the end of the table (upgraded
   databases append them there) and give them a default.
2. Bump `schemaVersion` in `app_database.dart`.
3. Regenerate: `dart run build_runner build --delete-conflicting-outputs`, then
   `dart run drift_dev make-migrations`. It saves the new schema in `drift_schemas/` and
   regenerates `app_database.steps.dart` and the test helpers in `test/drift/`.
4. Add the `fromNToN+1` step to `stepByStep` in `app_database.dart`, and extend
   `test/drift/leccheck/migration_test.dart`: it checks every upgrade path against the
   saved schemas and that existing rows survive.
5. A new column in a synced table: add its default to the adapter's `added` map in
   `schedule_repository.dart`. Rows synced by older app versions, and older backups and
   automatic backups, don't have it and must still load. Older app versions ignore fields
   they don't know.
6. A new synced table: add it to `SYNCED_TABLES` in `server/src/protocol.ts` and to the
   repository's adapters. The server stores rows as JSON, so new columns need no server
   change.

### Add or change an icon

Edit or add an SVG in `design/icons/` (24px grid, 2px round strokes), then:

```bash
uv run --with picosvg --with fonttools python design/build_icons.py
```

Reference it through `LecIcons` (`lib/core/icons/lec_icons.dart`).

### Change the app icon or splash

Edit `design/app-icon/*.svg`, export PNGs into `app/assets/branding/` (see
[design/README.md](../design/README.md)), then:

```bash
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Testing on a real phone

Turn on developer mode (**Settings → About → Version** 7 times) and open **Settings →
Developer → Developer tools**:

- **Notifications**: whether they're set up (and the error if not), permission, channels
  turned off, exact alarms, time zone, what's scheduled, and how much of it still has an
  alarm in the system. Show one now, schedule one in a minute, or an after-class reminder
  in a minute. Go to the home screen before it arrives (don't swipe LecCheck away: some
  phones, e.g. Xiaomi, force-stop it, and a force stop drops every alarm until the app
  is opened again), press a button, then check the session and the log. Its buttons mark
  the latest session that needs marking; if none does, they only log. Check permission
  first: when Android blocks LecCheck's notifications, nothing appears at all (Today
  shows a warning while reminders are on).
- **Sync**: state, cursor, dataset, clock correction; **Sync now**; **Pretend the server
  is busy** for 2 minutes. Account then shows "Sync paused until…", and sync resumes by
  itself.
- **Data**: database and automatic backup sizes (Android backs up 25 MB per app),
  `PRAGMA quick_check`.
- **This device**: Android version, battery optimization, screen, time zone. A button
  opens LecCheck's system settings (notifications, alarms, battery).
- **Log**: errors (`debugPrint`, uncaught errors) and what notification and widget
  buttons did in the background (`core/dev/dev_log.dart`, kept in `dev_log.txt`,
  64 KB at most, left out of Android's backup). **Copy diagnostics** copies all of it.

Android's backup (needs `adb`, from `~/Android/Sdk/platform-tools`):

```bash
adb shell bmgr backupnow com.leccheck.app   # back up now (the phone must be signed in to Google)
adb uninstall com.leccheck.app              # export a backup first: this deletes the app's data
adb install LecCheck-…-android-arm64.apk    # the same signing key; the data comes back
```

After the restore, sign in again (the sign-in token isn't backed up).

## Code style

- `flutter analyze` must be clean; format with `dart format`.
- Domain code (`lib/domain`) stays pure Dart and fully unit-tested.
- Writes go through `ScheduleRepository`; widgets watch the narrowest provider they can.
- No network or heavy work before the first frame.
- Directional layout only (`EdgeInsetsDirectional`, `AlignmentDirectional`) for RTL.

## CI and releases

| Workflow | Trigger | Does |
|---|---|---|
| `ci.yml` | push to main, PRs | analyze + test the app, typecheck + test the server, check generated Drift code |
| `deploy-server.yml` | push to main touching `server/`, manual, and every release | test, deploy, smoke-test, roll back on failure (see below) |
| `server-health.yml` | every 6 hours, manual | deep health check of the live server; a failure emails you |
| `release.yml` | tag `v*` | signed Android APKs, unsigned iOS IPA, Linux tarball, AltStore source → GitHub Release, after the server for that commit is live; `altstore-source.json` and `update.json` (the apps' update check) on the `altstore` branch |

To release: bump `version:` in `app/pubspec.yaml`, then `git tag vX.Y.Z && git push --tags`.
Required secrets and variables are listed in [SETUP.md](SETUP.md).

## Server deploys

Deploy through GitHub, not with `npx wrangler deploy` from a laptop:
`deploy-server.yml` stamps the version (`SERVER_REV`, the last commit that changed
`server/`), which is how it knows what's live.

1. **verify**: typecheck, tests, and a dry-run bundle. Nothing is uploaded if they fail.
2. **plan**: `GET /v1/health` reports the live `rev`. The same rev means nothing to do (so
   releases can call the workflow for free). If `server/wrangler.jsonc` changed since the
   live rev, or the live rev is unknown, the deploy runs in the `production-approval`
   environment and waits for you: Cloudflare can't roll back across binding or Durable
   Object class changes.
3. **deploy**: `wrangler deploy --var SERVER_REV:<rev>`, then
   `scripts/server-smoke-test.sh`. It waits until `/v1/health` reports the new rev, then
   checks `/v1/health/deep` (secrets present, `DEV_AUTH` off, a Durable Object write and
   read), the public pages, and that sync without a token gets 401. If that fails, it
   runs `wrangler rollback` to the version that was live before and fails the run, so
   GitHub emails you.

Worker versions can't be tried before they take traffic: Cloudflare gives no preview
URLs to Workers with Durable Objects. That's why the tests run against the real
`workerd` runtime (`@cloudflare/vitest-pool-workers`) first.

**Runbook**

- *Roll back by hand*: `cd server && npx wrangler deployments list` shows the versions;
  `npx wrangler rollback <version-id> -m "why"`. Then fix the code on main: the next
  deploy replaces the rolled-back version.
- *Check the live server*: `HEALTH_TOKEN=… scripts/server-smoke-test.sh <url>`.
- *Rotate a secret*: `npx wrangler secret put NAME` takes effect at once (it creates a new
  version). Rotating `JWT_SECRET` signs every device out. For `HEALTH_TOKEN`, set the
  Worker secret and the GitHub secret to the same new value.
- *Require a newer app*: set `MIN_APP_BUILD` (a var in `wrangler.jsonc`, or a secret)
  to a build number. Older apps then get `upgrade_required` instead of syncing; apps
  before 2.0.0-beta.5 don't send their build, so they count as older.

## Update notice

`update.json` on the `altstore` branch has a `beta` and a `stable` channel
(`scripts/update_manifest.py`): betas update `beta`, stable releases both. The apps read
it at most once a day (`app/update_controller.dart`). To try the notice, serve a manifest
with a higher build and point a build at it:
`flutter run --dart-define=UPDATE_URL=http://<your-ip>:8000/update.json`. Android's
per-ABI APKs report 1000 × ABI + build as their version code; `installedBuild()` undoes
that.

## Smoothness (Linux)

Flutter 3.47's Linux engine has no vsync: it draws at a fixed 60 fps whatever the
display's rate (`VsyncWaiterFallback`; upstream issue flutter/flutter#183703). On a
100 Hz monitor, 60 frames spread over 100 refreshes as 20/20/10 ms, which looks like
judder; at 60 Hz, or with VRR/FreeSync on, it's smooth. The app can't change that, but it
can avoid slow frames on top:

- **Settings → Developer → Rendering** shows the display's rate, the frame rate while
  animating, build and raster times (p50/p90/max) and the share of frames over budget
  (`core/dev/frame_stats.dart`, also in diagnostics and bug reports).
- `LECCHECK_UI_THREAD=separate leccheck` runs Dart on its own thread instead of GTK's
  main thread; compare the numbers with and without it.
- Profile builds: `flutter run --profile -d linux`, with DevTools' frame chart.

At a fractional scale (e.g. 1.25 on Hyprland), GTK3 renders at 2× and the compositor
scales down: slightly softer text, not slower frames.
