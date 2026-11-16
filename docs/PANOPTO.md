# Panopto recordings, linked automatically

Status: **experimental, on one device** (built 2026-11-16, not released yet). The device
connected to Panopto finds the links; the user's other devices get them through sync.
Pairing other devices (Step 4) waits. Decisions are the owner's, from 2026-11-16.

This document is the place to come back to: what is built and how it behaves (first),
its **limits** and the **ideas** for making it better, how to debug a missing link, and
then the reference (what Panopto's API does, the decisions, the design of the parts not
built yet).

## What is built

- **Settings → Panopto recordings**: setup steps (open Panopto, create a "Mobile or
  Desktop Application" API client with LecCheck's redirect address, paste its Client ID
  and secret, Connect), then the connection's status, "Look for recordings now" and
  Disconnect (optionally removing every link it found). An "Experimental" badge and a
  one-time warning before connecting.
- **The tour** offers it as a step before the last one ("Recordings from Panopto"), when
  this build has a server and the device isn't connected. While experimental, "Next"
  leads and "Set it up" is the other choice; flip `PanoptoFeature.experimental` and "Set
  it up" leads, with "Later".
- **Finding links**: each course's folder by its number, then every finished recording
  goes to the class it fits best. Found links show everywhere a pasted link does
  (Catch up on recordings, Today's button, the icons), marked "Found in Panopto" in the
  session.
- **The course page** has a Panopto part: the folder (Change: search, a pasted folder
  link, by the course number, or none), the group question when several groups are
  recorded at a meeting's time, the groups remembered (Ask again), and "Look now".
- **Groups**: asked once per meeting with a suggestion, or learned from the links the
  user pasted (two or more pointing to one group).
- **Removing a link asks** what Panopto may do next.
- **Developer mode → Matching details**: why each session got a link or not, why each
  recording wasn't used, copyable as text.
- **Where it runs**: at start and when the app comes back (at most every 3 hours), in
  Android's daily background task (then a sync), and on "Look now".
- **Server**: only `GET /v1/panopto/done`, a page that sends the browser back to the app,
  and a privacy policy section. No Panopto work on the server.

Code:

| Path | What |
|---|---|
| `app/lib/domain/recording_match.dart` | The matcher (pure Dart), its details, recording names and descriptions |
| `app/lib/core/recordings/panopto_api.dart` | Read-only REST calls, parsing, name cleanup, the two readings of `StartTime` |
| `app/lib/core/recordings/panopto_connection.dart` | Sign-in, rotating tokens in secure storage, the refresh lease (`DbRefreshLock`) |
| `app/lib/core/recordings/recording_linker.dart` | The runner: folders, matching, writing, the report |
| `app/lib/core/recordings/match_report.dart` | Matching details per course, and the text report |
| `app/lib/app/recordings_controller.dart` | Providers, `PanoptoController`, `PanoptoFeature.experimental` |
| `app/lib/features/settings/panopto_section.dart` | Settings section, setup page, connect/disconnect dialogs |
| `app/lib/features/courses/panopto_course_section.dart` | The course page's part and the folder picker |
| `app/lib/features/developer/panopto_debug_page.dart` | Matching details (English only) |
| `app/lib/features/session/session_sheet.dart` | "Found in Panopto", the question after removing a link |
| `app/lib/features/tour/` | The tour's Panopto step |
| `app/lib/app/background_reminders.dart` | Android's daily look |
| `server/src/panopto.ts` | The redirect page |
| `app/test/fixtures/panopto/` | The real 80430 folder of 2026-11-16 (ids and links replaced) |
| `app/test/core/fake_panopto.dart` | A fake Panopto that behaves like HUJI's site |

## How it behaves

### Your link and Panopto's link

| | Your link (pasted) | Panopto's link (found) |
|---|---|---|
| Stored in | `session_overrides.recordingUrl` | `session_overrides.recordingFound` |
| Shown | Always, when there is one | Only while the session has no link of yours |
| Marked | — | "Found in Panopto" in the session |
| A later look can change it | Never | Yes, when a better match turns up |
| Sync | Its own field: never overwritten by a found link, even one found before your paste arrives | Its own field |
| Disconnect → remove the links it found | Untouched | Cleared |

- Editing a found link makes it yours.
- Removing a link stores `''` (no link), then asks, when Panopto is in use (connected
  here, or found links exist):
  - your link: "Let Panopto find it?" Yes → null, and a look at the course if this device
    is connected. "Leave empty" → stays `''`; never filled.
  - a found link: "Was it the wrong recording?" "Put it back" → null, the found link shows
    again. "Yes, remove it" → stays `''`.
  - Closing the sheet mid-edit keeps `''`.
- Typing into an empty field and erasing it again leaves null (nothing was removed).
- Your links guide matching: the recording a pasted link points to isn't given to
  another session; two or more pasted links into a meeting, all of one group, teach the
  meeting that group; one suggests it when the group question comes.

### When two recordings fit one class

A recording fits a session when it starts from 30 minutes before the session to its end,
on the session's date (its moved date and time, if moved). Then, in this order:

1. **Type**: lectures don't take recordings named as practices (`תרגיל`, `תרגול`) and
   practices don't take lectures (`שעור`, `שיעור`, `הרצאה`); labs `מעבדה`. "Other"
   meetings take any. Hand-named recordings have no type and fit any.
2. **Different groups** (practice ד and ו both at 10:00):
   - The meeting has a group (chosen, or learned from pasted links): only that group's
     recordings and ones without a group count.
   - It has none: no guess. The session stays empty and the course page asks which
     group's recordings are the user's, suggesting one from pasted links, else the one
     in the meeting's room. The answer is remembered per meeting and syncs.
3. **The same group, or no group** (Wednesday 13:00: the automatic `תרגיל ג` and the
   hand-named `13-14 on 11/11`): no question. One wins, by: closest start, then the
   meeting's room, then an automatic recording (with the timetable slot in its
   description) over a hand-named one, then the longest. The other is "not used:
   another recording took its session".
4. **Across sessions**: every fitting session–recording pair is ranked that way, closest
   first, so a recording goes to the session it fits best and each is used once. (A long
   meeting overlapping the next class no longer takes that class's recording.)

Never filled: canceled sessions, sessions not over yet, sessions with the user's link or
a removed one, recordings still recording or processing (`Status` other than 4 Complete
or 6 Archived), recordings whose name starts with another course number.

### When it looks, and what it reads

- Semesters running now or ended in the last 30 days.
- Courses with folders; a course without folders gets them by its number (the one
  folder whose name has it, or the one of the semester's academic year, `2026-27`).
  Several → "Choose its Panopto folder".
- Each folder's recordings by `CreatedDate`, newest first, 50 a page, until a page is all
  older than a week before the semester: 1–3 requests per course.
- `StartTime` is read as wall-clock digits (how HUJI sends it), unless reading it as real
  UTC fits more recordings to sessions.

### What syncs and what stays on the device

| Synced | On this device only |
|---|---|
| Found links (`recordingFound`), removed links (`''`) | Client ID, secret, access and refresh tokens (secure storage) |
| Folders per course (`courses.panoptoFolders`) | The last look's report: time, links written, error |
| Groups per meeting (`meetings.panoptoGroup`) | Open group questions, courses to choose a folder for |
| | Whether the warning was shown; matching details (memory only) |

## Limits and known issues

Each with what it means for a user, and the likely fix.

1. **One link per session.** A class recorded in two parts within one meeting (a 9–12
   meeting recorded 9:00–9:50 and 10:00–11:50) gets only the part starting closest to it;
   the other shows as unused in Matching details. *Fix: a list of links per session
   (synced JSON), or a second link.*
2. **The chosen group's recording is missing that day** → the session stays empty, even
   when another group's exists (unless a hand-named one fits). *Fix: offer the other
   group's recording, marked, or ask.*
3. **Hand-named recordings have no group or type** (`80430 9.11 12-14`), so at the user's
   class time one can be taken even if another group made it; they never cause a group
   question. *Fix: parse more name patterns; prefer automatic recordings of the chosen
   group; read the folder's recorder or room if the API gives it.*
4. **Names and descriptions are parsed the HUJI way** (course number first, `שעור`/`תרגיל`
   and a group letter, `יום ב 12:00 - 13:45`, the room on the next line). Another
   university's names give no type or group: no questions, closest start only. Group
   letters are compared exactly (`ו` ≠ `ו'`, `06` ≠ `6`). *Fix: normalize letters; a
   per-site parser.*
5. **Canceled sessions never get a link**, even when Panopto shows the class happened (13
   of the owner's canceled sessions have recordings). *Fix: "Canceled but recorded" hint.*
6. **Make-up classes** (a recording of the user's group at a time with no session) are
   only listed in Matching details. *Fix: offer "Add as a one-time session" with its link.*
7. **The fitting window** is 30 minutes before to the session's end. A recording started
   after the session's end, or a class moved without updating LecCheck, doesn't match
   ("no session at its time", with the closest session). *Fix: also use the description's
   timetable slot; suggest moving the session.*
8. **Only the last 30 days after a semester.** Older semesters aren't looked at.
9. **`StartTime`'s zone**: HUJI sends local wall-clock time marked UTC. The matcher picks
   the reading that fits more recordings per folder; a folder with few recordings and
   ambiguous times could pick wrong. Unknown whether a user's Panopto time zone setting
   changes it.
10. **Removed is final unless answered.** A link removed with "Leave empty" (or on a device
    where Panopto isn't in use) never fills again; Matching details has "Allow finding
    again" (Developer mode only). *Fix: a "Find in Panopto" button in the session sheet.*
11. **Older app versions** don't show found links (they read only `recordingUrl`), and
    clear a link to null instead of `''`.
12. **Only one device looks.** Other devices get links when that device has looked and
    synced; on iPhone there's no background look (only when the app runs). Two connected
    devices are allowed; if they disagree, the last `recordingFound` written wins.
13. **Group questions and the folder-choice list are per device** (prefs), shown on the
    connected device only; the answers (groups, folders) sync.
14. **Sign-in**: refresh tokens work once. If the app dies after Panopto rotated the token
    but before it was saved, the sign-in is lost ("Connect again"). The refresh token's
    lifetime is unknown (the owner's test token from 2026-11-16 20:53 measures it).
    Background looks never open a browser; an expired sign-in shows only in Settings.
15. **One redirect address per Panopto client**, so every user's client points at
    `https://leccheck-sync.leccheck.workers.dev/v1/panopto/done`. Moving the server to
    another address breaks every client until its Redirect URL is edited.
16. **Setup effort**: each user creates an API client and copies a 44-character secret.
    The setup guide has no pictures yet. HUJI could turn user-created clients off; then
    links are pasted by hand again.
17. **Matching details live in memory** for this run of the app (not after a restart, not
    from Android's background look).
18. **Desktop sign-in** uses loopback port 43823, like Google sign-in.
19. **Rate limits are unknown** (no headers seen). The 3-hour throttle keeps requests few.

## Ideas to make it better

Roughly by value:

1. **Canceled but recorded**: show sessions marked canceled that have a recording, to fix
   the status or link it anyway.
2. **"Watched" from Panopto**: suggest "Watched the recording" when `PercentCompleted` is
   high (the owner's watched sessions were 81–89%; skipped ones 5%).
3. **Make-up classes**: offer recordings of the user's group at times with no session as
   one-time sessions.
4. **More than one link per session** (split recordings).
5. **A "Find in Panopto" button** in the session sheet (also undoes a removal).
6. **Pasted links on another date** (Matching details flags them): offer to fix.
7. **Tell the user on Today** when the Panopto sign-in expired.
8. **"N new recordings"** on Catch up on recordings.
9. **Use the description's slot** (`יום ב 12:00 - 13:45`) to confirm a match or to match
   recordings that started late.
10. **Normalize group letters** and parse other universities' names.
11. **Pairing other devices** (Step 4 below), so any device can look.
12. **Search inside recordings** (`folders/{id}/sessions/search` finds words in the
    lecture, without timestamps) and **thumbnails** (public images).

## Debugging a missing link

1. Turn on Developer mode, then Settings → Panopto recordings → **Matching details**.
   Look again (top) to fill it in for this run.
2. Find the session under "Sessions without a found link" or "Links you removed", and
   the recording under "Recordings not used". Each says why: nothing recorded at its
   time, another group, its session canceled or with your link, waiting for the group
   question…
3. "Copy as text" gives the whole report for an issue.
4. To read Panopto directly, a throwaway script with your own API client (like Step 0)
   can list a folder's recordings: `GET /Panopto/api/v1/folders/{id}/sessions`.
5. To try a build without touching your data: see DEVELOPMENT.md, "A separate test copy
   on Linux".

## Out of experimental, when

- The owner has used it for a few weeks on the Linux build and the phone without wrong
  links or lost sign-ins; the refresh token's lifetime is known.
- The Hebrew strings are approved and the setup guide has its pictures.
- Then set `PanoptoFeature.experimental = false`: the badges and the warning go, and the
  tour leads with "Set it up".

---

# Reference

## Goal

LecCheck finds each session's Panopto recording and fills in its recording link, so nobody
pastes links by hand. Missed sessions with a recording then show under Stats → Catch up
by themselves.

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
  `invalid_client`. So other devices need the vault and pairing to look themselves.
- **Send the id and secret in Basic auth as they are.** Panopto doesn't URL-decode them
  (RFC 6749 says to encode them, and most OAuth libraries do): the encoded secret gets
  `invalid_client`. Putting them in the body (`client_secret_post`) also works.
- PKCE works. The browser comes back with `code`, `state` and `session_state`.
- **One redirect address per client** (a single field), matched exactly: `127.0.0.1`
  instead of `localhost`, another port or another path are refused. So the Worker
  redirect page is needed. (Not tried: several addresses in that field, or a
  `leccheck://` one.)
- Access token: a JWT, **1 hour**. Refresh token: opaque, 32 characters, **a new one with
  every refresh, and a used one is refused** (`invalid_grant`). How long an unused one
  lasts is still unknown.

Reading recordings:
- `GET /api/v1/folders/search?searchQuery=80430` finds exactly the course folder,
  `2026-27 -&gt; 80430_1-מבוא להסתברות ולסטטיסטיקה`. Names come **HTML-escaped**
  (`&gt;`), and some contain Moodle language tags
  (`{mlang he}…{mlang}{mlang en}…{mlang}`). `sessions/search` is a loose text search
  across all courses (not useful). Each of the owner's four courses had one folder.
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
  then).
- `Status` comes as a number, the enum's index: 0 Created, 1 Scheduled, 2 Recording,
  3 Processing, **4 Complete**, 5 Live, 6 Archived. All 58 were 4.
- Automatic recordings run 110 minutes from the full hour (`Duration` ≈ 6599). Their
  description lines: course number, English name, Hebrew name, the slot
  (`יום ב 12:00 - 13:45`), the room, the type with the group (`תרגיל ה`).
- What the matcher had to handle: parallel groups (practice ד and ו both Thursday 10:00);
  separate slots for one lecture group (Tuesday 9:00–9:45 and 10:00–11:45, in two rooms:
  two meetings in the owner's timetable); hand-named recordings without a description;
  rooms that changed early in the semester; a cut-short recording (13 minutes); one with
  `IsWebcast: true`.
- `PercentCompleted` is the signed-in user's progress (e.g. 89%), and
  `GET /api/v1/users/me/sessions/viewed` lists what they watched across courses.
- Other endpoints a student can use: `sessions/{id}` (same fields), `folders/{id}`,
  `folders/{id}/sessions/search` (finds words in recordings, no timestamps),
  `sessions/inProgress/recording`; thumbnails are public. Captions need a browser sign-in;
  viewers and analytics are refused.

From Panopto's documentation and community (before Step 0):
- "Mobile or Desktop Application" uses the authorization-code flow; the client id and
  secret go as Basic auth to `https://<site>/Panopto/oauth2/connect/token`.
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

### First real test (owner, 2026-11-16)

A separate test copy of the Linux app with the owner's data: all four courses got their
folders, 16 links were found. Few, because most sessions already had a pasted link, were
marked canceled, or had their links removed during the test; every unused recording was
another group's class at a time the owner has none. This led to Matching details,
learning groups from pasted links, asking when a link is removed, and ranking pairs
across sessions.

## Decisions

| Question | Decision | Why |
|---|---|---|
| How to read Panopto | REST API with the user's own API client | RSS is off at HUJI; the API gives real start times |
| Client type | Mobile or Desktop Application | Made for apps; works with SSO |
| Who creates it | Each user, once | Works at any Panopto university, depends on nobody's account. A shared HUJI client is unconfirmed and its secret would be public in the open-source app |
| Where it runs | Devices | See the comparison below |
| Refresh tokens | Per device, never synced | They are what opens Panopto; each device signs in itself |
| Other devices (later) | The setup syncs, encrypted end to end; a new device is unlocked by pairing (a 6-digit code) | Every device can look; the server can't read it; no passphrase |

For the experimental release (owner, after Step 0):

| Question | Decision |
|---|---|
| Other devices | One connected device; the others get the links through sync. Vault and pairing later |
| Parallel groups | Suggest a group (from links pasted before, then the room), ask once on the course page, remember the letter per meeting (synced) |
| Found links | Marked "Found in Panopto", in their own column, with "remove every link it found" on Disconnect |
| Removing a link | Ask each time (when Panopto is in use): a pasted link may be filled from Panopto, a found one may be put back |
| Groups from pasted links | At least two links pasted into a meeting's sessions, all of one group, set the meeting's group without asking |
| Setup guide | In the app, numbered steps with Copy for the redirect address; pictures from the owner later |
| The tour | Offers Panopto as a step; "Set it up" becomes the default action when it's out of experimental |

Devices or server, compared:

| | Devices (chosen) | Server (Worker cron) |
|---|---|---|
| Free plan | No Worker requests or CPU; only the new links sync, one row each | Free cron: 10 ms CPU and 50 outside fetches a run; reading every account costs Durable Object requests daily |
| Secrets | Stay on devices (encrypted when synced) | The server would hold every user's Panopto secret and refresh token |
| When links appear | When a connected device runs: opening the app, Android's daily task, "Look now" | On a schedule, even if no device runs |
| New code | App, plus a tiny redirect page on the server | Account registry, the server writing user data with its own clock, cron, limits |

## Signing in (as built)

- One redirect address for every device and platform:
  `https://<LecCheck server>/v1/panopto/done` (`server/src/panopto.ts`). It sends the
  browser on to the app with Panopto's query as it is: `leccheck://panopto?…` on phones,
  or `http://localhost:43823/panopto?…` on desktop, chosen by the state's ending (`.m` or
  `.d`). It sees the one-time code, useless without the client secret and the app's PKCE
  verifier, and stores nothing.
- The app opens the browser with `flutter_web_auth_2` (as Google sign-in does), scopes
  `openid api offline_access`, and exchanges the code at the token endpoint with the id
  and secret in Basic auth, unencoded.
- The setup and tokens go to secure storage as base64url JSON (`leccheck.panopto`), never
  synced. Each refresh's new token is saved before anything else, under a 30-second
  lease in `sync_meta` (`DbRefreshLock`): Android's background task is another isolate in
  the same process, where file locks don't keep them apart. A refused refresh token
  means "Connect again" (one browser tap; HUJI's sign-in is usually remembered).
  Background work never opens a browser.
- Disconnect asks Panopto to revoke the refresh token and forgets it.

## Not built yet: the vault and pairing (Step 4)

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

## Data model (schema v6, as built)

| Where | What | Default |
|---|---|---|
| `courses.panoptoFolders` | TEXT: `''` not chosen, or JSON list of `{id, name}` (`[]` = none) | `''` |
| `meetings.panoptoGroup` | TEXT, the group letter whose recordings are the meeting's | `''` |
| `session_overrides.recordingFound` | TEXT, nullable, a link found in Panopto | null |

- No server change for these (the server doesn't know columns).
- Editing a course or meeting leaves `panoptoFolders` and `panoptoGroup` alone
  (`_Adapter.own`): the domain types don't carry them. Backups and snapshots restore them.
- The viewer link needs a Panopto sign-in to play, so it isn't a secret in the synced
  session row.
- Later, for pairing: `user_settings.panoptoVault` and a synced table `device_requests`
  (id, deviceName, commit, aPub, bPub, nonce, wrapped, kid, expiresAt), added to
  `SYNCED_TABLES`.

## Steps

0. **Check the API with the owner's client.** Done 2026-11-16 (see Step 0 results).
   Still open: several redirect addresses or a `leccheck://` one; the refresh token's
   lifetime.
1. **Matcher** with unit tests. Done: tests on the real 80430 folder and the owner's
   meetings (`test/domain/recording_match_test.dart`).
2. **Panopto client**: connect, refresh, folder sessions, folder search. Done, tested
   against `test/core/fake_panopto.dart`.
3. **One device, no pairing**: Settings, the course page, the runner, schema v6, the
   server page. Done 2026-11-16 as an experimental feature, then (same day) Matching
   details, learning groups, asking on removal, ranking pairs across sessions, the
   tour step.
4. **Vault and pairing** (`core/recordings/panopto_vault.dart`): not started.
5. **Polish**: USER_GUIDE, CHANGELOG and tour done. Waiting: the owner's approval of the
   Hebrew strings; pictures for the setup guide; then out of experimental.

## Tests

- `test/domain/recording_match_test.dart`: the real folder against the owner's meetings
  (each meeting's recordings, the parallel groups' question, suggestions from links and
  room, a chosen or learned group), canceled, removed and pasted links, not over yet and
  processing, lectures vs practices, wall-clock and true UTC times, a moved session,
  other course numbers, overlapping meetings, and the matching details.
- `test/core/panopto_test.dart`: connecting, the unencoded secret, a refused secret,
  token rotation, a refused refresh token, concurrent refreshes, a 401 then a retry,
  revoking, the database lease, paging, name cleanup, time parsing.
- `test/core/recording_linker_test.dart`: folders found by the course number, links
  written and recorded for sync, answering the group question, learning a group, the
  3-hour throttle, pasted and removed links staying, a paste that syncs in later
  winning, course edits keeping folders and groups, an expired sign-in.
- `test/widget/flows_test.dart`: the question after removing a found or pasted link.
- `test/widget/tour_test.dart`: the tour's Panopto step.
- `test/drift`: upgrades to v6. `server/test/panopto.test.ts`: the redirect page.
- Screenshots: the setup page, the Settings section, the course page's part, the tour
  step.
- Later, for pairing: vault round trip, wrong account, wrong `kid`, two simulated devices,
  a swapped key giving a different code, no plaintext in synced rows; `test_sync` with
  two devices pairing through a local Worker.

## Risks and open questions

- HUJI could turn off user-created API clients. The fallback is pasting links by hand.
- The refresh token's lifetime: if short, "Connect again" will show often.
- Panopto's rate limits are unknown.
- Settled since Step 0: parallel groups (ask once, or learn from pasted links); wall-clock
  `StartTime` (both readings, per folder); rotating refresh tokens (saved first, one
  refresh at a time per device); a class in two parts (one link, limit 1 above).
- Open: "Watched the recording" from `PercentCompleted` (idea 2).
