# LecCheck sync server

A Cloudflare Worker (Hono) plus one **Durable Object per user** (`UserStore`, SQLite
storage). Runs on the Workers **free plan**; a user generates a few hundred requests a
day against a limit of 100,000.

```
src/index.ts       routes (sync, renew, sign-out-everywhere, delete account)
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
npm test                          # 22 tests
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
| `POST /v1/sync` `{since, changes}` | Bearer | Same exchange over HTTP |
| `DELETE /v1/account` | Bearer | Deletes everything stored for the user |

User ids are `g:<google sub>` (or `dev:<name>`). Session tokens carry the user's
`epoch`; a token with an old epoch is rejected.

## Wire protocol

All messages are JSON text.

Client → server:

```jsonc
{"t": "hello", "since": 41}                 // catch up from version 41
{"t": "push", "batchId": "b1", "changes": [
  {"tbl": "session_overrides", "id": "m1_20261025",
   "patch": {"status": "attended"},          // only the fields that changed
   "hlc": "001759570000123:0000:3f9a0c1b2d4e5f60"}
]}
{"t": "ping"}                               // answered with {"t":"pong"} without waking the object
```

Server → client:

```jsonc
{"t": "changes", "rows": [{"tbl": "...", "id": "...", "data": {/* full row */}, "v": 42}],
 "upto": 42, "more": false, "clock": "<max HLC seen>", "catchUp": true}
{"t": "ack", "batchId": "b1", "rejected": [], "clock": "..."}
{"t": "error", "code": "bad_json", "message": "..."}
```

- `hello` is answered with pages of at most 500 rows (`catchUp: true`, `more` while
  pages remain).
- After a `push`, accepted rows are broadcast as `changes` to **all** of the user's
  sockets (the sender too), then the sender gets an `ack`.
- `upto` is the server version after the message; clients save it as their cursor
  (from broadcasts only once their catch-up has finished).
- `clock` lets clients move their HLC past the newest clock the server has seen.

HTTP `POST /v1/sync` returns `{rows, upto, more, rejected, clock}` for the same push +
pull in one request.

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
- A row only gets a new `version` (and a broadcast) when a value actually changes.

HLC format: `<15-digit ms>:<4 hex counter>:<node id>`, fixed width, so comparing strings
compares clocks.

## Limits and validation

| Limit | Value |
|---|---|
| Changes per push | 500 |
| Patch size | 16 KB |
| Message size | 1 MB |
| Clock skew | changes stamped > 5 minutes in the future are rejected (`clock_skew`) |
| Tables | `semesters`, `courses`, `meetings`, `session_overrides`, `no_class_ranges`, `requirements`, `user_settings` |

The server never interprets row contents beyond `id`, so client schema changes need no
server migration.
