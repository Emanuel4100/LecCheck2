# LecCheck — notes for Claude Code

A lecture-attendance app: Flutter (`app/`, Android + iPhone via AltStore/SideStore +
Linux as a Flatpak, English and Hebrew/RTL) and a Cloudflare Worker sync server (`server/`, Durable
Objects, free plan only). Tools are pinned in `mise.toml`.

**Start here:** [docs/ROADMAP.md](docs/ROADMAP.md) "Next" has the next release's decided
plan and the to-do list by release; [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) has the
commands, the release routine and how to test on a phone; [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
the design; [CHANGELOG.md](CHANGELOG.md) what each beta shipped.

## Working with the owner

- Ask about features and design choices before building (offer options, recommend one);
  plan bigger work first.
- No data loss and free plans are top priorities.
- Ask before pushing tags or publishing releases. Never print secrets (keystore,
  tokens); pipe them from files into commands.
- Don't open windows on the owner's desktop; render screenshots offscreen (goldens) or
  run the Linux build headless (Xvfb with its own `XDG_*` dirs and `dbus-run-session`).

## Checks

- `cd app && flutter analyze && TZ=Asia/Jerusalem flutter test`
- `flutter test test_screenshots`: phone goldens stay identical unless a screen changed
  on purpose; regenerate with `--update-goldens` and look at the PNGs. Don't commit
  `en_light_semester_form.png` (it changes with today's date).
- `cd server && npm test && npm run typecheck`
- E2E sync: `npx wrangler dev --port 8787` in `server/` (with `DEV_AUTH=1` in `.dev.vars`),
  then `flutter test test_sync --dart-define=API_BASE_URL=http://localhost:8787`.
- Strings: edit `app/lib/l10n/app_en.arb` and `app_he.arb`, then `flutter gen-l10n`.
- Schema changes: `dart run drift_dev make-migrations`, a `stepByStep` step, a test in
  `test/drift`, and defaults in `_Adapter.added` for new synced columns.

## Things learned the hard way

- Riverpod 3 retries a failing provider for ~40 s and reports it as loading: give
  providers whose errors the UI must show `retry: (_, _) => null`.
- On Linux the sign-in is in the keyring through flutter_secure_storage_linux 3.0.3,
  which stores every value in one JSON document under the schema name "%". GNOME Keyring
  without a password drops secrets containing backslashes when it re-reads its file, so
  the session is saved base64-encoded. Upgrading that plugin needs a migration.
- Flutter's Linux engine quits without destroying the window: save state on change or in
  `GApplication::shutdown`, not on "destroy".
- Mouse-only gestures on Week use `supportedDevices: {PointerDeviceKind.mouse}` (so touch
  scrolling isn't stolen) and `DragStartBehavior.down` (so a drag starts where the button
  went down).
- Riverpod 3 pauses a provider nobody listens to: `ref.read(p.future)` of an unwatched
  StreamProvider never completes. Listen while reading.
- The router starts on `/` (a splash) and redirects once semesters load: a dialog opened
  before that goes away with the page. Startup windows wait for `_pastSplash`.
- Flatpak: sandboxes never see `/tmp` or Flatpak's own installation folders, and
  `flatpak run` doesn't pass `FLATPAK_USER_DIR` (use `--env=`). flatpak-builder inside
  the `org.flatpak.Builder` app runs `flatpak` on the host. Hyprland has no Secret
  portal. The portal's first `Update` shows a desktop dialog (answer kept per app:
  `flatpak permission-set flatpak updates com.leccheck.app yes` for tests).
- Waiting for a process by pid: `kill -0` succeeds on a zombie; check `/proc/PID/stat`.
