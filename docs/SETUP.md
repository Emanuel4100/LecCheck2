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
| Secret | `UPDATE_SIGNING_KEY` | the update signing key (below): the apps ignore an unsigned `update.json` |

The deploy workflow checks the live server with `HEALTH_TOKEN`. Create it once, set it
on both sides without printing it, then delete the file:

```bash
openssl rand -hex 32 > health-token
(cd server && npx wrangler secret put HEALTH_TOKEN < ../health-token)
gh secret set HEALTH_TOKEN < health-token
rm health-token
```

**Bug reports** (optional): create a **private** repository `LecCheck-reports`, then a
fine-grained token (GitHub → Settings → Developer settings → Fine-grained tokens) with
access to that repository only and **Issues: Read and write**. Set it on the Worker:
`npx wrangler secret put REPORTS_GITHUB_TOKEN`. Without it, the app's **Report a problem**
says reports aren't available; with it, each report is an issue there. The issues are
filed with your own token, so GitHub counts them as your own activity and doesn't email
you unless you turn on **Settings → Notifications → Include your own updates**. A
different repository: set `REPORTS_REPO` (e.g. `you/reports`) the same way.
Fine-grained tokens expire: the server health check warns when it's rejected.

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

The update signing key signs `update.json`, the list of releases the Android and Linux
apps update from. Create it once, put its public half in
`app/lib/core/update/update_service.dart` (`updatePublicKey`), and the key itself in the
secret:

```bash
(umask 077 && openssl genpkey -algorithm ed25519 -out update-signing-key.pem)
openssl pkey -in update-signing-key.pem -pubout -outform DER | tail -c 32 | base64
gh secret set UPDATE_SIGNING_KEY < update-signing-key.pem
```

**Back it up too.** Without it, installed apps can't be told about new releases; a new
key needs a release that apps install by hand.

The Linux app is a Flatpak served from LecCheck's own repository on GitHub Pages, signed
with a GPG key. Create the key once (no passphrase: the secret protects it), commit its
public half as `app/linux/flatpak/leccheck-repo.asc`, and put the key itself in the
secret:

```bash
export GNUPGHOME=$(mktemp -d)
gpg --batch --pinentry-mode loopback --passphrase '' \
  --quick-gen-key 'LecCheck Flatpak repository' rsa4096 sign never
FPR=$(gpg --list-keys --with-colons | awk -F: '/^fpr/ {print $10; exit}')
{ echo "# fingerprint: $FPR"; gpg --armor --export "$FPR"; } > app/linux/flatpak/leccheck-repo.asc
(umask 077 && gpg --armor --export-secret-keys "$FPR" > leccheck-flatpak-key.asc)
gh secret set FLATPAK_GPG_KEY < leccheck-flatpak-key.asc
rm -rf "$GNUPGHOME"
```

**Back it up.** Flatpak checks every update against this key: a new one means everyone
installs LecCheck again.

Then turn on GitHub Pages for the repository with **GitHub Actions** as the source, and
let release tags publish to it (the `github-pages` environment allows only the default
branch at first):

```bash
gh api -X POST repos/OWNER/REPO/pages -f build_type=workflow
gh api -X PUT repos/OWNER/REPO/environments/github-pages \
  -F deployment_branch_policy[protected_branches]=false \
  -F deployment_branch_policy[custom_branch_policies]=true
gh api -X POST repos/OWNER/REPO/environments/github-pages/deployment-branch-policies \
  -f name='v*' -f type=tag
gh api -X POST repos/OWNER/REPO/environments/github-pages/deployment-branch-policies \
  -f name=main -f type=branch
```

## 5. Releasing

1. Bump `version:` in `app/pubspec.yaml` (e.g. `2.0.1+11`).
2. `git tag v2.0.1 && git push --tags`.

The **Release** workflow builds a signed Android APK, an unsigned iPhone IPA
and the Linux Flatpak, publishes them with an AltStore/SideStore source, and puts the
Flatpak in its repository on GitHub Pages.

## 6. Installing

- **Android**: download the APK from Releases, or add the repo to
  [Obtainium](https://obtainium.imranr.dev) for automatic updates.
- **iPhone** (no $99 developer account): install
  [AltStore](https://altstore.io) or [SideStore](https://sidestore.io), then
  add this source once:
  `https://raw.githubusercontent.com/Emanuel4100/LecCheck2/altstore/altstore-source.json`.
  Free Apple IDs need the app refreshed every 7 days; AltStore/SideStore do
  that in the background.
- **Linux**: install the Flatpak (with [Flatpak](https://flatpak.org/setup/) set up):
  `flatpak install --user https://emanuel4100.github.io/LecCheck2/leccheck.flatpakref`,
  or open that file in GNOME Software or Discover. It updates itself from then on;
  `flatpak uninstall com.leccheck.app` removes it. 2.0.0-beta.15 is the last tarball
  (`./install.sh`): those installs move to the Flatpak from inside the app.

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
