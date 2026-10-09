# Setup guide

Everything here is free. You only do it once.

## 1. Deploy the sync server (Cloudflare Workers)

1. Create a free account at <https://dash.cloudflare.com/sign-up>.
2. Log in from the terminal and set the server's secrets:

   ```bash
   cd server
   npm install
   npx wrangler login
   openssl rand -base64 48 | npx wrangler secret put JWT_SECRET
   npx wrangler deploy
   ```

   `deploy` prints your server URL, e.g. `https://leccheck-sync.<you>.workers.dev`.
   Keep it for the next steps; it's the app's `API_BASE_URL`.

## 2. Google sign-in (Google Cloud Console)

1. Open <https://console.cloud.google.com/>, create a project (or reuse the v1
   Firebase project).
2. **APIs & Services → OAuth consent screen**: user type *External*, fill in the
   app name and your email. The scopes needed are `openid`, `email` and
   `profile`, which don't require Google's verification. Publishing requires,
   under **Branding**, a homepage and a privacy policy on an authorized domain.
   The Worker serves both:
   - Homepage: `https://leccheck-sync.<you>.workers.dev/`
   - Privacy policy: `https://leccheck-sync.<you>.workers.dev/privacy`
   - Authorized domain: `<you>.workers.dev` (`workers.dev` is a public suffix, so
     this is the top private domain Google asks for)

   Then **Audience → Publish app**. In "Testing" mode only listed test users can
   sign in.
3. **APIs & Services → Credentials → Create credentials → OAuth client ID**:
   - Application type: **Web application**
   - Authorized redirect URI: `https://leccheck-sync.<you>.workers.dev/v1/auth/google/callback`
4. Give the client to the server:

   ```bash
   npx wrangler secret put GOOGLE_CLIENT_ID      # ends with .apps.googleusercontent.com
   npx wrangler secret put GOOGLE_CLIENT_SECRET
   ```

The client secret lives only in the Worker. The app never contains it, so
the same sign-in works on Android, iPhone, Linux and Windows.

## 3. Build the app with sync turned on

```bash
cd app
flutter run -d linux --dart-define=API_BASE_URL=https://leccheck-sync.<you>.workers.dev
```

Without `API_BASE_URL` the app still works fully offline; sign-in is hidden.

### Local testing without Google

```bash
cd server
cp .dev.vars.example .dev.vars        # DEV_AUTH=1 enables a test sign-in
npx wrangler dev --port 8787
# second terminal
cd app
flutter run -d linux --dart-define=API_BASE_URL=http://localhost:8787 --dart-define=DEV_AUTH=true
```

To check sync between two simulated devices:
`flutter test test_sync --dart-define=API_BASE_URL=http://localhost:8787`.

## 4. GitHub (releases and automatic server deploys)

Repository **Settings → Secrets and variables → Actions**:

| Kind | Name | Value |
|---|---|---|
| Variable | `API_BASE_URL` | your Worker URL |
| Secret | `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release.jks` (see below) |
| Secret | `ANDROID_KEYSTORE_PASSWORD` | keystore password |
| Secret | `ANDROID_KEY_ALIAS` | e.g. `leccheck` |
| Secret | `ANDROID_KEY_PASSWORD` | key password |
| Secret | `CLOUDFLARE_API_TOKEN` | Cloudflare → My Profile → API Tokens → "Edit Cloudflare Workers" template, limited to your account |
| Secret | `CLOUDFLARE_ACCOUNT_ID` | Cloudflare dashboard → Workers → Account ID |
| Secret | `HEALTH_TOKEN` | a random value, also set on the Worker (below) |

The deploy workflow checks the live server with `HEALTH_TOKEN`. Create it once, set it
on both sides without printing it, then delete the file:

```bash
openssl rand -hex 32 > health-token
(cd server && npx wrangler secret put HEALTH_TOKEN < ../health-token)
gh secret set HEALTH_TOKEN < health-token
rm health-token
```

Then **Settings → Environments → New environment** `production-approval`, with yourself
as a **required reviewer**. Deploys that change `server/wrangler.jsonc` (bindings,
Durable Object migrations) run there and wait for your approval, because Cloudflare
can't roll them back.

Create the Android signing key once:

```bash
keytool -genkey -v -keystore release.jks -alias leccheck -keyalg RSA -keysize 4096 -validity 10000
```

**Back up `release.jks` and its passwords.** Updates for installed apps must
be signed with the same key.

## 5. Releasing

1. Bump `version:` in `app/pubspec.yaml` (e.g. `2.0.1+11`).
2. `git tag v2.0.1 && git push --tags`.

The **Release** workflow builds a signed Android APK, an unsigned iPhone IPA
and a Linux tarball, and publishes them with an AltStore/SideStore source.

## 6. Installing

- **Android**: download the APK from Releases, or add the repo to
  [Obtainium](https://obtainium.imranr.dev) for automatic updates.
- **iPhone** (no $99 developer account): install
  [AltStore](https://altstore.io) or [SideStore](https://sidestore.io), then
  add this source once:
  `https://raw.githubusercontent.com/Emanuel4100/LecCheck2/altstore/altstore-source.json`.
  Free Apple IDs need the app refreshed every 7 days; AltStore/SideStore do
  that in the background.
- **Linux**: extract `LecCheck-*-linux-x64.tar.gz` and run `./install.sh`
  (`./install.sh uninstall` removes it).

## 7. Moving over from LecCheck v1

1. In the old app: **Settings → Data → Export schedule** (saves a JSON file).
2. The new app is signed with a different key, so uninstall the old one first.
3. In the new app: **Settings → Data → Import backup**, and pick the file.

Courses, weekly meetings, attendance marks, notes and recording links all carry
over. Holidays become no-class ranges.

## Notes

- **Exact reminders on Android** use the `USE_EXACT_ALARM` permission, which is
  fine for apps installed outside the Play Store. If you ever publish to Google
  Play, review that policy first.
- **Free-tier headroom**: Cloudflare's free plan allows, per day, 100,000 Durable
  Object requests and 100,000 rows written (shared by everyone), and one person
  uses a few hundred, so you're covered even if classmates join. The free plan
  never bills: if a limit is ever reached, sync pauses until 00:00 UTC and every
  change waits on its device until then.
