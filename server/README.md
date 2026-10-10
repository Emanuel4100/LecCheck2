# LecCheck sync server

A Cloudflare Worker (Hono) plus one **Durable Object per user** (`UserStore`, SQLite
storage). Runs on the Workers **free plan**; a user generates a few hundred requests a
day against a limit of 100,000 (see [Free plan limits](#free-plan-limits)).

```
src/index.ts       routes (sync, renew, sign-out-everywhere, delete/restore account)
src/auth.ts        Google OAuth broker + PKCE code exchange + dev sign-in
src/user-store.ts  Durable Object: rows, merge, versions, WebSockets (hibernation)
src/merge.ts       per-field last-writer-wins (pure)
src/protocol.ts    message types, limits, validation
src/jwt.ts         HS256 tokens (jose), PKCE helpers
test/              vitest + @cloudflare/vitest-pool-workers
```

## Running

```bash
npm install
cp .dev.vars.example .dev.vars   # DEV_AUTH=1 enables POST /v1/auth/dev
npx wrangler dev --port 8787
npm test                          # 34 tests
npm run typecheck
```

Deploying and configuring Google sign-in: [docs/SETUP.md](../docs/SETUP.md).

Secrets: `JWT_SECRET`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`. Variable: `DEV_AUTH`
(`"0"` in production).

## Endpoints

| Method & path | Auth | Purpose |
|---|---|---|
| `GET /v1/auth/google/start?redirect_uri&state&code_challenge` | — | Starts Google sign-in. `redirect_uri` must be `leccheck://auth…` or `http://localhost:<port>/…` |
| `GET /v1/auth/google/callback` | — | Google redirects here; verifies the ID token, redirects back with a one-time code (2 min) |
| `POST /v1/auth/token` `{code, code_verifier}` | — | PKCE check, one use only → `{token, user}` (session, 60 days) |
| `POST /v1/auth/dev` `{name}` | — | Test sign-in, only when `DEV_AUTH=1` |
| `POST /v1/auth/renew` | Bearer | Fresh session token |
| `POST /v1/auth/signout-everywhere` | Bearer | Invalidates all of the user's tokens (epoch bump) |
| `GET /v1/sync` (WebSocket upgrade) | Bearer | Live sync |
| `POST /v1/sync` `{since, changes, dataset}` | Bearer | Same exchange over HTTP |
| `DELETE /v1/account` | Bearer | Moves the user's rows to a trash (erased after 30 days) and signs out every device |
| `POST /v1/account/restore` | Bearer | Brings back rows from the trash that weren't re-created since |
| `POST /v1/account/restore-to` `{at}` | Bearer | Rolls the user's storage back to a time in the last 30 days (Durable Object point-in-time recovery; not available in `wrangler dev`) |

User ids are `g:<google sub>` (or `dev:<name>`). Session tokens carry the user's
`epoch`; a token with an old epoch is rejected.

## Wire protocol

All messages are JSON text.

Client → server:

```jsonc
{"t": "hello", "since": 41, "dataset": "…"} // catch up from version 41 of that dataset
{"t": "push", "batchId": "b1", "changes": [
  {"tbl": "session_overrides", "id": "m1_20261025",
   "patch": {"status": "attended"},          // only the fields that changed
   "hlc": "001759570000123:0000:3f9a0c1b2d4e5f60",
   "ifAbsent": false}                        // true: only fill fields the server doesn't have
]}
{"t": "ping"}                               // answered with {"t":"pong"} without waking the object
```

Server → client:

```jsonc
{"t": "changes", "rows": [{"tbl": "...", "id": "...", "data": {/* full row */}, "v": 42}],
 "upto": 42, "more": false, "clock": "<max HLC seen>", "catchUp": true,
 "dataset": "…", "now": 1759570000123}      // dataset and now: catch-up only
{"t": "ack", "batchId": "b1", "rejected": [{"i": 0, "tbl": "…", "id": "…", "reason": "clock_skew"}],
 "rows": [/* corrections */], "clock": "...", "now": 1759570000123}
{"t": "error", "code": "bad_json", "message": "..."}
{"t": "error", "code": "quota", "message": "...", "retryAt": 1759622400000}
```

- `hello` is answered with pages of at most 500 rows (`catchUp: true`, `more` while
  pages remain).
- After a `push`, accepted rows are broadcast as `changes` to **all** of the user's
  sockets (the sender too), then the sender gets an `ack`.
- `upto` is the server version after the message; clients save it as their cursor
  (from broadcasts only once their catch-up has finished).
- `clock` lets clients move their HLC past the newest clock the server has seen; `now`
  (server time) lets them correct a wrong device clock.
- `rejected[].i` is the change's position in the push. Clients keep refused changes
  (they're never dropped) and re-stamp `clock_skew` ones after correcting their clock.
- The ack's `rows` are **corrections**: the current state of rows where some pushed field
  lost to a newer write, so the sender's copy doesn't keep the losing value.
- `dataset` identifies this copy of the user's data. It changes when the data is deleted
  or rolled back; a client that sends an older one is caught up from version 0 and
  re-offers its own rows (`ifAbsent`), so it can't skip versions or lose edits.
- An `error` with `retryAt` means storage can't be used right now (`quota`: the free
  plan's daily limit, until 00:00 UTC; `user_quota`: this account's own daily write
  limit, until 00:00 UTC; `unavailable`: anything else, in a minute). Nothing from the
  push was saved; the client keeps its changes and comes back then.

HTTP `POST /v1/sync` returns `{rows, upto, more, rejected, corrections, clock, dataset,
now}` for the same push + pull in one request, or `503 {error, retryAt}` with a
`Retry-After` header.

## Merge rules

Each stored row keeps `data` (field → value) and `clocks` (field → HLC of the last
accepted write). For every field in a patch, the value is taken only if the patch's HLC is
newer than that field's clock. Consequences:

- Concurrent edits to **different fields** of a row (status on one device, notes on
  another) both survive.
- For the **same field**, the later edit wins. HLCs are monotonic per device and move
  past every clock seen from the server, so "later" follows causality even if device
  clocks drift.
- Deletion is the field `deleted: true`; undo is `deleted: false` with a newer clock.
- An `ifAbsent` change only fills fields the server has never seen. Devices use it when
  their existing copy joins an account (first sign-in, imports, a reset server), so an
  old copy can't overwrite newer edits or bring back deleted rows.
- A row only gets a new `version` (and a broadcast) when a value actually changes.
- A push is one transaction. Every row it touches is read once, merged in memory and
  written once, so several queued edits to the same item cost one write.

HLC format: `<15-digit ms>:<4 hex counter>:<node id>`, fixed width, so comparing strings
compares clocks.

## Limits and validation

| Limit | Value |
|---|---|
| Changes per push | 500 |
| Patch size | 32 KB (the app caps notes at 10,000 characters) |
| Field names | letters, digits and `_`, starting with a letter, up to 64 (`bad_field`) |
| Message size | 1 MB (the app sends at most 512 KB) |
| Clock skew | changes stamped > 5 minutes in the future are rejected (`clock_skew`) |
| Rows written per account per day | 10,000, counting `meta`; then `user_quota` until 00:00 UTC |
| Rows per account | 50,000 (new rows past it: `account_full`) |
| Data per account | 25 MB (growing rows past it: `account_full`) |
| Row size | 64 KB (`row_too_large`) |
| Tables | `semesters`, `courses`, `meetings`, `session_overrides`, `no_class_ranges`, `requirements`, `user_settings` |

The server never interprets row contents beyond `id`, so client schema changes need no
server migration.

The per-account limits keep one account (a bug, or someone abusing sign-in) from using
up the free plan for everyone. Each Durable Object keeps its counts (`usage` in `meta`)
in memory and saves them only every 200 written rows, so they cost almost no writes;
storage is recounted once a day. Refused rows stay in the app's outbox (Account →
Retry), so nothing is lost.

Session tokens are only read from the `Authorization` header (never from the URL,
which can end up in logs). Renewing, signing out everywhere, deleting cloud data and
restoring all check that the session wasn't revoked.

## Free plan limits

The Workers Free plan allows, per day and shared by all users: 100,000 Durable Object
requests (incoming WebSocket messages count 1/20), 5 million rows read and **100,000
rows written**, plus 5 GB of storage. It never bills: going over a limit makes those
operations fail until the limits reset at 00:00 UTC.

The server keeps writes low (one write per changed row per push; `meta` only when it
changes) and, when storage fails, answers with `retryAt` instead of an error the client
would retry right away. Clients keep every change in their outbox and reconnect at
`retryAt` (or later, backing off up to an hour, if it keeps failing), so nothing is lost
and the limit isn't spent on retries.
