# Panopto recordings, linked automatically

Status: **designed, not built.** Step 0 done on 2026-11-16: it works (results below).
Decided with the owner on 2026-11-16.

## Goal

LecCheck finds each session's Panopto recording and fills in its recording link
(`session_overrides.recordingUrl`), so nobody pastes links by hand. Missed sessions with a
recording then show under Stats → Catch up by themselves.

Requirements from the owner:
- Runs on the devices. The server does no Panopto work (free plans first).
- Each user creates a Panopto API client **once**, and every device of theirs can use it.
- The server must not be able to read that setup.
- Nothing to remember: no passphrase.

## What we found (huji.cloud.panopto.eu, 2026-11-16)

- **RSS/podcast feeds are off.** `…/Panopto/Podcast/Podcast.ashx?courseid=<folder>&type=mp4`
  answers HTTP 403 in a private window. The folder's "+ Subscribe" button is Panopto's
  follow/notify feature, not RSS.
- **Users can create API clients**: avatar → User Settings → API Clients → Create a new
  API Client. Types offered: Server-side Web Application, JavaScript Web Application,
  Hybrid Web Application, Server Application, User Based Server Application, **Mobile or
  Desktop Application**. Fields: name, optional URL, CORS origin, redirect URL, post-logout
  redirect URL.
- **Recording names are structured**: `80430 2026-11-16 תרגיל א`: course number, date,
  type (`שעור` lecture, `תרגיל` practice), group letter. Descriptions carry the weekday and
  time: `יום ב 12:00 - 13:45`. HUJI records automatically, and a recording in progress
  shows "Recording right now".
- A course folder's address carries its id:
  `…/Sessions/List.aspx#folderID="ab040e1e-9c68-410e-b8b6-b4650147c6f8"`.

### Step 0 results (owner's client, course 80430, 2026-11-16)

Public, no sign-in: the OAuth settings at `/Panopto/oauth2/.well-known/openid-configuration`
(IdentityServer: PKCE `S256`, scopes `openid profile email api offline_access`, secret as
Basic auth or in the body) and the API description at `/Panopto/api/v1/panoptoApi.json`.

Signing in:
- The "Mobile or Desktop Application" client **has a secret** (44 characters, base64 with
  `/` and `=`), and the token endpoint requires it: the client id alone gets
  `invalid_client`. So the vault and pairing are needed.
- **Send the id and secret in Basic auth as they are.** Panopto doesn't URL-decode them
  (RFC 6749 says to encode them, and most OAuth libraries do): the encoded secret gets
  `invalid_client`. Putting them in the body (`client_secret_post`) also works.
- PKCE works. The browser comes back with `code`, `state` and `session_state`.
- **One redirect address per client** (a single field), matched exactly: `127.0.0.1`
  instead of `localhost`, another port or another path are refused. So the Worker
  redirect page stays. (Not yet tried: whether the form accepts several addresses
  separated somehow, or a `leccheck://` one.)
- Access token: a JWT, **1 hour**. Refresh token: opaque, 32 characters, **a new one with
  every refresh, and a used one is refused** (`invalid_grant`). How long an unused one
  lasts is still unknown.

Reading recordings:
- `GET /api/v1/folders/search?searchQuery=80430` finds exactly the course folder,
  `2026-27 -&gt; 80430_1-מבוא להסתברות ולסטטיסטיקה`. Names come **HTML-escaped**
  (`&gt;`), and some contain Moodle language tags
  (`{mlang he}…{mlang}{mlang en}…{mlang}`). `sessions/search` is a loose text search
  across all courses (not useful).
- `GET /api/v1/folders/{id}/sessions?sortField=CreatedDate&sortOrder=Desc&pageNumber=N`:
  **50 per page**, an empty page at the end. 58 recordings by week 6: two pages. No future
  (scheduled) recordings were listed for a student, and the list came out in start order.
  0.3–1.1 s per request. No rate-limit headers.
- Fields as in the spec: `Id, Name, Description, StartTime, Duration (seconds), Status,
  IsWebcast, PercentCompleted, MostRecentViewPosition, CreatedBy, Folder, FolderDetails,
  Urls{ViewerUrl, EmbedUrl, DownloadUrl, ThumbnailUrl, …}`.
  `ViewerUrl` = `https://<site>/Panopto/Pages/Viewer.aspx?id=<Id>`.
- **`StartTime` is the local wall-clock time marked as UTC**: the class "יום ב 12:00 - 13:45"
  comes back as `2026-11-16T12:00:01.13Z`, and as `12:00:01Z` in October too (UTC+3
  then). Read its clock digits as local time. (Unknown: whether it follows the site's
  time zone or the user's Panopto time zone setting.)
- `Status` comes as a number, the enum's index: 0 Created, 1 Scheduled, 2 Recording,
  3 Processing, **4 Complete**, 5 Live, 6 Archived. All 58 were 4.
- Automatic recordings run 110 minutes from the full hour (`Duration` ≈ 6599). Their
  description ends with the slot (`יום ב 12:00 - 13:45`).
- What the matcher has to handle:
  - **Parallel groups:** practice groups ד and ו are both recorded Thursday 12:00–13:50.
    Time alone can't pick one, and meetings don't store a group letter.
  - **One class, two recordings:** lecture group א on Tuesday is recorded as 9:00–9:50
    and 10:00–11:50.
  - **Hand-named recordings** with no description: `80430 9.11 12-14`,
    `80430 13-14 on 11/11/2026 (יום ד)`, `80430 02/11 12-14`. Start times are still right.
  - A cut-short recording (13 minutes), and one with `IsWebcast: true`.
- `PercentCompleted` is the signed-in user's progress (e.g. 89%), and
  `GET /api/v1/users/me/sessions/viewed` lists what they watched across courses. This could
  mark "Watched the recording" by itself (not decided).

From Panopto's documentation and community (before Step 0):
- "Mobile or Desktop Application" uses the authorization-code flow like a server-side
  client: the client id and secret go as Basic auth to
  `https://<site>/Panopto/oauth2/connect/token`; the redirect address must match one of the
  client's exactly; several redirect addresses per client are possible.
- Scope `offline_access` gives a refresh token. Each refresh token works once and expires
  after a while.
- REST endpoints (prefix `/Panopto`): `GET /api/v1/folders/{id}/sessions` (paged:
  `sortField`, `sortOrder`, `pageNumber`), `GET /api/v1/sessions/search`, folder search.
  Each site documents its API at `/Panopto/api/docs/index.html`.
- "User Based Server Application" signs in with a Panopto password. HUJI uses SSO, so
  there's none: not usable. "Server Application" tokens have no user and can't list
  folders.

Sources: [OAuth2 for users](https://support.panopto.com/s/article/How-to-Get-OAuth2-Access-Tokens-for-Users),
[Panopto's Python examples](https://github.com/Panopto/panopto-api-python-examples),
[Postman with the REST API](https://support.panopto.com/s/article/How-to-use-Postman-with-the-Panopto-REST-API),
[community: user-based clients and SSO](https://community.panopto.com/discussion/2937/api-user-based-app-with-sso),
[community: redirect addresses](https://community.panopto.com/discussion/2483/how-to-obtain-an-authentication-code-using-oauth2),
[community: empty results with server clients](https://community.panopto.com/discussion/2664/empty-responses-when-trying-to-search-for-folders-and-sessions),
[Limerick: RSS feeds need no sign-in](https://ul.ie/media/36258/download),
[Cloudflare Workers limits](https://developers.cloudflare.com/workers/platform/limits/).

## Decisions

| Question | Decision | Why |
|---|---|---|
| How to read Panopto | REST API with the user's own API client | RSS is off at HUJI; the API gives real start times |
| Client type | Mobile or Desktop Application | Made for apps; works with SSO |
| Who creates it | Each user, once | Works at any Panopto university, depends on nobody's account. A shared HUJI client is unconfirmed (can other users sign in with a client a regular user made?) and its secret would be public in the open-source app |
| Where it runs | Devices | See the comparison below |
| Other devices | The setup syncs, encrypted end to end | The owner wants every device to work; the server must not read it |
| Unlocking on a new device | Pairing with an existing device, comparing a 6-digit code | No passphrase to remember |
| Refresh tokens | Per device, never synced | They are what opens Panopto; each device signs in itself |

Devices or server, compared:

| | Devices (chosen) | Server (Worker cron) |
|---|---|---|
| Free plan | No Worker requests or CPU; only the new links sync, one row each | Free cron: 10 ms CPU and 50 outside fetches a run; reading every account costs Durable Object requests daily |
| Secrets | Stay on devices (encrypted when synced) | The server would hold every user's Panopto secret and refresh token |
| When links appear | When a connected device runs: opening the app, Android's daily task, "Look now" | On a schedule, even if no device runs |
| New code | App, plus a tiny redirect page and one table name on the server | Account registry, the server writing user data with its own clock, cron, limits |

## How it works

### Signing in to Panopto

- One redirect address for every device and platform:
  `https://<LecCheck server>/v1/panopto/done`. It's a static Worker page. It reads `state`
  and sends the browser on to the app: `leccheck://panopto?code=…&state=…` on phones, or
  `http://localhost:43823/panopto?…` on desktop. It forwards the browser only: it sees the
  one-time code, which is useless without the client secret. One request per sign-in.
  Step 0 showed a client has a single redirect field, matched exactly, so this page is
  needed.
- The app opens the browser with `flutter_web_auth_2` (as Google sign-in does), scopes
  `openid api offline_access`, and exchanges the code at the token endpoint.
- The refresh token goes to secure storage (`flutter_secure_storage`, as `AuthService`
  does), never synced. The new refresh token is saved before the old one is used again.
  When it has expired, the device shows "Connect again" (one browser tap; HUJI's sign-in
  is usually remembered). Background work never opens a browser: it skips and the app
  asks next time.

### The setup on every device: the vault

- The **setup** is `{site, clientId, clientSecret}`.
- The first device makes a random 256-bit key **K**, keeps it in secure storage, and syncs
  the setup encrypted with it in `user_settings.panoptoVault`:
  `{"v":1, "kid": first 8 bytes of SHA-256(K) as hex, "nonce", "ct"}`. AES-256-GCM
  (`cryptography` package, already used for update signatures), with the account's user
  id as associated data so a vault can't be moved to another account.
- A device whose key has another `kid` (the setup was redone elsewhere) offers "Use it
  here" again.
- Disconnecting everywhere clears the vault (synced); each device deletes its key and
  token.
- A lost phone loses nothing: redo the setup on any device (Panopto's Generate button
  makes a new secret).
- Step 0 showed this client type has a secret, so the vault and pairing are needed.

### Pairing a new device

What the user does:
1. On the new device, tap **Use it here**.
2. Check that the phone shows the same 6-digit code, and tap **Allow**.
3. Tap **Connect** on the new device: one browser tap.

Underneath, a commit-then-reveal exchange in sync rows. Committing first stops the
server from grinding a key pair that happens to show the same code:
1. New device B: makes an X25519 key pair and a random nonce. Writes a request: its name
   and `commit = SHA-256(B.pub ‖ nonce)`.
2. Device A (has K): makes an X25519 key pair and writes `A.pub`.
3. B: writes `B.pub` and `nonce`. A checks them against the commit.
4. Both show `code = 6 digits of SHA-256("leccheck-pair-v1" ‖ request id ‖ A.pub ‖ B.pub ‖ nonce)`.
5. A, on **Allow**: `wrapKey = HKDF-SHA256(X25519(a, B.pub), salt = request id,
   info = "leccheck-pair-v1")`. Writes `wrapped = AES-GCM(wrapKey, K)` with `kid`.
6. B unwraps K, stores it, decrypts the vault, and tombstones the request.

Steps 2–3 run by themselves over live sync, in about a second. Requests expire after
10 minutes, and done or expired ones are tombstoned. Only devices holding K answer.

What the server sees: public keys, the commit, ciphertext. Encryption stops a server that
only reads. The code comparison stops a server that tries to swap in its own key.

### Finding recordings

- **Folders per course**: `courses.panoptoFolders`, a JSON list of folder ids (a lecture
  folder and a practice folder are both fine). Not secret, synced. The course editor
  suggests folders found by the course code (`CourseInfo.code`, e.g. 80430) and also takes
  a pasted folder link.
- **Runner** `core/recordings/recording_linker.dart`, on every connected device:
  - Which semesters: those running now or ended in the last 30 days
    (`ScheduleRepository.loadWindow`).
  - What it does: for each course with folders, it lists the folder's sessions, newest
    first, until older than the semester's start. Then it matches them and writes the
    links with `setRecordingUrl` in one transaction.
  - When it runs: at start and when the app comes back, at most every 3 hours (time kept
    in prefs). Also in Android's daily task (`backgroundTaskDispatcher`,
    `app/background_reminders.dart`), followed by `SyncEngine.syncOverHttp` as the widget
    does, and on "Look for recordings now" on the course page.
  - Two devices finding the same link write the same value; that's harmless.
- **Matcher** `domain/recording_match.dart` (pure Dart):
  - A recording goes to the course's session whose effective start (moved sessions
    included) is closest to the recording's start, from 30 minutes before the start to
    the end.
  - Fallback without a usable start time: the date in the name, plus the type word
    (`שעור`/`שיעור`/`הרצאה` lecture, `תרגיל`/`תרגול` practice, `מעבדה` lab).
  - Never canceled sessions, and never one that already has a link. Each recording is
    used once. A recording in progress waits until it's done.
- **Removed stays removed**: clearing a link stores `''` instead of null
  (`setRecordingUrl`), and the matcher fills only null. The app already treats `''` as no
  link (`AttendanceStats.catchUp`, Today's card).
- The viewer link needs a Panopto sign-in to play, so it isn't a secret in the synced
  session row.

## Data model (schema v6)

Follow CLAUDE.md's schema steps: `dart run drift_dev make-migrations`, a `stepByStep` step,
a test in `test/drift`, defaults in `_Adapter.added`.

| Where | Change | Default |
|---|---|---|
| `courses.panoptoFolders` | TEXT, JSON list of folder ids | `'[]'` |
| `user_settings.panoptoVault` | TEXT, nullable, encrypted setup | null |
| new synced table `device_requests` | id, deviceName, commit, aPub, bPub, nonce, wrapped, kid, expiresAt | — |

- Server: add `device_requests` to `SYNCED_TABLES` (`server/src/protocol.ts`). Older apps
  ignore the table.
- Per device, not synced: K, the refresh token, the last run time.

## Steps

0. **Check the API with your client (no app code).** Done 2026-11-16: see "Step 0
   results". The redirect address with several entries or `leccheck://`, and the refresh
   token's lifetime, are still open.
   - You create a "Mobile or Desktop Application" client with the redirect
     `http://localhost:8765/panopto` and save its id and secret to a file yourself.
   - A throwaway script outside the repo signs in through that address. It prints only
     recording names, start times, and whether viewer links exist (never the secret or
     tokens).
   - It answers:
     - the field names (StartTime? Duration? Urls.ViewerUrl?);
     - whether the start time is the class time;
     - access and refresh token lifetimes;
     - whether this type has a secret;
     - whether Panopto accepts `leccheck://panopto` and several redirect addresses on one
       client;
     - page size;
     - whether folder search by "80430" finds the course.
   - Update this document with the answers.
1. **Matcher**, with unit tests. No Panopto needed.
2. **Panopto client** (`core/recordings/panopto_client.dart`): connect, refresh, folder
   sessions, folder search. Tested against a fake HTTP server with fixtures from Step 0
   (ids and links replaced).
3. **One device, no pairing yet**:
   - Settings → Panopto: setup steps with a Copy button for the redirect address, the
     Client ID and secret, Connect / Disconnect.
   - Course editor: a folders row. Course page: "Look now".
   - The runner.
   - `''` on clearing.
   - Schema v6 for `courses.panoptoFolders`.
   - Server: the redirect page.

   This alone is a useful release: other devices get the links through sync.
4. **Vault and pairing** (`core/recordings/panopto_vault.dart`):
   - `user_settings.panoptoVault` and `device_requests`.
   - "Use it here", and the "Allow this device?" prompt on Today and in Settings.
   - A list of paired devices.
5. **Polish**: Hebrew strings sent to the owner for approval; a USER_GUIDE section;
   CHANGELOG.

## Tests

- **Matcher**: closest session, moved sessions, two folders, a DST week, canceled,
  already linked, cleared `''`, in progress, the name fallback.
- **Vault**: round trip; wrong account; wrong `kid`; pairing between two simulated
  devices; a swapped key gives a different code; the synced rows hold no plaintext.
- **Client**: token rotation, an expired refresh token, paging, a 401 from Panopto.
- **Repository and runner**: `''` isn't refilled; writes reach the outbox.
- **Schema and server**: `test/drift` upgrades to v6; `server/test` covers the redirect
  page and the new table name.
- **End to end**: `test_sync` with two devices pairing through a local Worker, and a link
  found on one appearing on the other.
- **By hand**: the Linux build headless (Xvfb, own `XDG_*` dirs) connected to HUJI, paired
  with the owner's phone.

## Risks and open questions

From Step 0, to decide before building:
- **Parallel groups**: how a course's meeting knows its group letter (ask once when two
  recordings tie and remember it per meeting, or a field in the meeting editor).
- **Two recordings for one class**: link the first, the longest, or keep both
  (`recordingUrl` holds one).
- **Wall-clock `StartTime`**: read it as local time, or have the matcher try both readings
  and keep the one that lines up with the meetings (safe if Panopto fixes it, or at
  other universities).
- **Rotating refresh tokens**: save the new one before anything else, and refresh in only
  one place per device: the app and Android's background task refreshing at the same
  time would leave one of them with a used token and "Connect again".
- Refresh token lifetime: measure by refreshing after some days.
- Watched percentage: offer "Watched the recording" from `PercentCompleted`?

- HUJI could turn off user-created API clients. The fallback is pasting links by hand, as
  today.
- Refresh token lifetime is unknown; if it's short, "Connect again" will show often.
- Panopto API rate limits are unknown (no rate-limit headers seen). The 3-hour throttle
  and newest-first paging keep requests few: about 2–3 per course folder a run.
- A folder that also holds other courses' recordings: the course number in the name
  filters them.
- Other universities: the site address is a setting, and nothing above is HUJI-specific
  except the name fallback's words.
