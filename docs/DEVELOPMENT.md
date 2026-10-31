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
  linux/flatpak/          the Flatpak manifest and the repository's public key
  third_party/            a stand-in for desktop_webview_window (no WebKitGTK)
server/                   Cloudflare Worker sync server (TypeScript) — see server/README.md
design/                   icon and logo sources — see design/README.md
scripts/                  release helpers: update_manifest.py, flatpak_site.py,
                          metainfo_releases.py, altstore_source.py
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
| `release.yml` | tag `v*` | signed Android APKs, unsigned iOS IPA, AltStore source → GitHub Release, after the server for that commit is live; the Linux Flatpak into its GPG-signed repository on GitHub Pages; then `altstore-source.json` and `update.json` (the apps' update check) on the `altstore` branch |

To release: bump `version:` in `app/pubspec.yaml`, then `git tag vX.Y.Z && git push --tags`.
Required secrets and variables are listed in [SETUP.md](SETUP.md).

### Release routine

1. Work lands in focused commits ("App: …", "Linux: …", "Server: …"), with the
   changes listed under `## Unreleased` in `CHANGELOG.md` as they happen. That section
   becomes the GitHub release notes and the update window's What's new: it can render
   `- ` items, `**bold**` and `### ` headings (not nested lists).
2. A last commit, "Prepare the vX pre-release": `version: 2.0.0+N` in
   `app/pubspec.yaml` (the build number **must** go up: Android, AltStore and the update
   check compare it), the CHANGELOG heading `## 2.0.0-beta.N — YYYY-MM-DD`, a "Done"
   entry in `docs/ROADMAP.md`, and `python3 scripts/metainfo_releases.py` (the Linux
   metainfo's release notes; the release workflow runs it again anyway).
3. Before tagging: `flutter analyze`, `TZ=Asia/Jerusalem flutter test`,
   `flutter test test_screenshots` (only intended goldens change; don't commit
   `en_light_semester_form.png`, it depends on today's date), and the E2E sync tests when
   sync changed. Deploy the server first only if `server/` changed (pushing main does it).
4. Push main, then an annotated tag: `git tag -a v2.0.0-beta.N -m "LecCheck 2.0.0-beta.N"`.
   To try every build first (the Flatpak too) without publishing anything, run the
   Release workflow by hand on main: `gh workflow run release.yml --ref main`.
5. After the Release workflow: the arm64 APK's versionCode is 2000 + N and it carries the
   release certificate (`aapt2 dump badging`, `apksigner verify --print-certs`);
   `update.json` on the `altstore` branch has the new version and build with sha256s and
   sizes matching the release's assets, and `flatpakref`; `altstore-source.json` has the
   new build; `flatpak remote-info leccheck com.leccheck.app` shows the new version.

**Trying the Flatpak on your own Linux PC**: the manifest is
`app/linux/flatpak/com.leccheck.app.yml`. It packages the release bundle, so build that
first, then build and install the Flatpak with
[flatpak-builder](https://docs.flatpak.org/en/latest/flatpak-builder.html) (as a Flatpak
itself, with the SDK, about 1 GB):

```bash
flatpak install --user flathub org.flatpak.Builder org.freedesktop.Sdk//26.08
cd app
flutter build linux --release --dart-define=API_BASE_URL=<your Worker URL> \
  --build-name=2.0.0-beta.N --build-number=<previous build>
flatpak run org.flatpak.Builder --user --install --force-clean \
  --default-branch=test build-flatpak linux/flatpak/com.leccheck.app.yml
flatpak run com.leccheck.app//test
```

A build with the *previous* build number still sees the real release in the update window.
Its data is in `~/.var/app/com.leccheck.app` like the real Flatpak's.

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
it at every start, and at most once a day when the app comes back
(`app/update_controller.dart`). To try the notice, serve a manifest
with a higher build and point a build at it:
`flutter run --dart-define=UPDATE_URL=http://<your-ip>:8000/update.json`. Android's
per-ABI APKs report 1000 × ABI + build as their version code; `installedBuild()` undoes
that.

Each entry also has the files' SHA-256 (`sha256`, from 2.0.0-beta.8 on), their sizes
(`size`, from 2.0.0-beta.15) and, for releases in the Flatpak repository, `flatpakref`.
With a hash, the card's **Update** installs the release from inside the app:

- **Android**: it downloads the APK into `cache/updates`, checks the hash, and opens
  Android's installer through a FileProvider (`installApk` on the device channel,
  `REQUEST_INSTALL_PACKAGES`). Android asks once to allow "Install unknown apps", and
  refuses an APK not signed with the release key. An arm64 phone always gets the arm64
  APK, whose version codes are higher than the universal one's.
- **Flatpak**: the release must have `flatpakref`. The Flatpak portal
  (`org.freedesktop.portal.Flatpak`) installs it: `CreateUpdateMonitor`, then `Update`,
  whose `Progress` signals the window shows; Flatpak checks the repository's GPG
  signature. The first time, the desktop asks whether LecCheck may update itself (the
  answer is kept in the permission store: `flatpak permission-show com.leccheck.app`).
  **Restart** asks the portal to `Spawn` the latest version with `--after-update`, and the
  runner waits until the old instance has given up the D-Bus name.
- **`install.sh` installs** (the tarball, until 2.0.0-beta.15): no updates, **Move to the
  Flatpak** instead (`MoveController`, `TarballInstall`).

Without a hash (older manifests, other Linux builds), **Download** opens the browser as
before. To try **Update** for real, point a build with a lower build number at a test
manifest signed with your own key, and let that build trust the key
(`UPDATE_PUBLIC_KEY`; release builds never set it):

```bash
(umask 077 && openssl genpkey -algorithm ed25519 -out test-key.pem)
PUB=$(openssl pkey -in test-key.pem -pubout -outform DER | tail -c 32 | base64 -w0)
openssl pkeyutl -sign -rawin -inkey test-key.pem -in update.json | base64 -w0 > update.json.sig
python3 -m http.server 8765   # next to update.json and update.json.sig
flutter build apk --split-per-abi --build-number=14 \
  --dart-define=UPDATE_URL=http://<your-ip>:8765/update.json --dart-define=UPDATE_PUBLIC_KEY=$PUB
```

List a published release's files with their `sha256sum` in it. Sign the Android build
with the release key, or Android refuses the update. For the Flatpak, give the entry a
`flatpakref` and install two builds from a local repository (`flatpak build-export`);
`FLATPAK_REF` points a test build's **Move to the Flatpak** at another `.flatpakref`.

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
