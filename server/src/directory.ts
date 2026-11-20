/**
 * The user directory and the beta whitelist, kept in the reserved
 * `__directory__` Durable Object (see [UserStore.directory]).
 *
 * The directory lists who has a cloud account (Google id, email, name, when
 * they first and last signed in): sync data stays in each user's own object,
 * so without it the owner couldn't tell who the accounts are. It's written at
 * sign-in, and once for each account that signed in before it existed (on
 * that account's first sync after the deploy), so it costs almost nothing.
 *
 * The whitelist limits who can sign in while the beta is closed. It's off
 * until the owner turns it on (`PUT /v1/admin/beta`); turning it on adds everyone
 * who already has an account, so nobody using the app is locked out. Removing
 * someone signs out their devices (the admin route bumps their epoch).
 * Sign-ins it refuses are kept as requests, so the owner can let them in.
 */

export const DIRECTORY = "__directory__";

export const DIRECTORY_SCHEMA = `
  CREATE TABLE IF NOT EXISTS dir_users (
    sub TEXT PRIMARY KEY,
    email TEXT NOT NULL,
    name TEXT NOT NULL,
    first_seen INTEGER NOT NULL,
    last_signin INTEGER
  );
  CREATE TABLE IF NOT EXISTS dir_allowed (
    email TEXT PRIMARY KEY,
    added_at INTEGER NOT NULL
  );
  CREATE TABLE IF NOT EXISTS dir_requests (
    email TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    first_at INTEGER NOT NULL,
    last_at INTEGER NOT NULL,
    tries INTEGER NOT NULL
  );
  CREATE TABLE IF NOT EXISTS dir_meta (k TEXT PRIMARY KEY, v TEXT NOT NULL);
`;

/** Refused sign-ins kept for the owner to review. */
export const MAX_REQUESTS = 500;

export interface Who {
  sub: string;
  email?: string;
  name?: string;
}

export type DirectoryOp =
  /** A sign-in: recorded and allowed, or refused (and kept as a request). */
  | { op: "signIn"; who: Who }
  /** An account seen syncing that may predate the directory. */
  | { op: "seen"; who: Who }
  | { op: "list" }
  | { op: "setBeta"; on: boolean }
  | { op: "allow"; email: string }
  /** Returns the accounts to sign out. */
  | { op: "remove"; email: string };

export interface DirectoryUser {
  id: string;
  email: string;
  name: string;
  firstSeen: number;
  lastSignIn: number | null;
  allowed: boolean;
}

export interface DirectoryView {
  /** When the whitelist was turned on; null while anyone can sign in. */
  betaSince: number | null;
  users: DirectoryUser[];
  /** Whitelisted emails (some may not have signed in yet). */
  allowed: { email: string; addedAt: number; signedIn: boolean }[];
  requests: { email: string; name: string; firstAt: number; lastAt: number; tries: number }[];
}

export type DirectoryReply =
  | { ok: true; allowed?: boolean; revoke?: string[]; view?: DirectoryView }
  | { ok: false; error: string };

/** Emails compare without case or surrounding spaces. */
export function normalEmail(email: unknown): string | null {
  if (typeof email !== "string") return null;
  const e = email.trim().toLowerCase();
  return /^[^\s@]{1,64}@[^\s@]{1,255}$/.test(e) ? e : null;
}

function betaSince(sql: SqlStorage): number | null {
  const row = sql.exec<{ v: string }>("SELECT v FROM dir_meta WHERE k = 'beta'").toArray()[0];
  return row ? Number(row.v) : null;
}

function isAllowed(sql: SqlStorage, email: string | null): boolean {
  if (email === null) return false;
  return sql.exec("SELECT 1 FROM dir_allowed WHERE email = ?", email).toArray().length > 0;
}

function upsertUser(sql: SqlStorage, who: Who, email: string, now: number, signIn: boolean) {
  sql.exec(
    `INSERT INTO dir_users (sub, email, name, first_seen, last_signin) VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(sub) DO UPDATE SET email = excluded.email, name = excluded.name,
       last_signin = COALESCE(excluded.last_signin, dir_users.last_signin)`,
    who.sub,
    email,
    (who.name ?? "").slice(0, 200),
    now,
    signIn ? now : null,
  );
}

/** Runs [op] (call inside a transaction). */
export function directoryOp(sql: SqlStorage, op: DirectoryOp, now: number): DirectoryReply {
  switch (op.op) {
    case "signIn": {
      const email = normalEmail(op.who.email);
      if (betaSince(sql) !== null && !isAllowed(sql, email)) {
        if (email !== null) {
          sql.exec(
            `INSERT INTO dir_requests (email, name, first_at, last_at, tries) VALUES (?, ?, ?, ?, 1)
             ON CONFLICT(email) DO UPDATE SET name = excluded.name, last_at = excluded.last_at,
               tries = dir_requests.tries + 1`,
            email,
            (op.who.name ?? "").slice(0, 200),
            now,
            now,
          );
          sql.exec(
            `DELETE FROM dir_requests WHERE email NOT IN
               (SELECT email FROM dir_requests ORDER BY last_at DESC LIMIT ?)`,
            MAX_REQUESTS,
          );
        }
        return { ok: true, allowed: false };
      }
      upsertUser(sql, op.who, email ?? "", now, true);
      return { ok: true, allowed: true };
    }
    case "seen": {
      const known = sql.exec("SELECT 1 FROM dir_users WHERE sub = ?", op.who.sub).toArray().length;
      if (known) return { ok: true };
      // Only reached with a valid, unrevoked session: an account from before
      // the directory. It had access, so it keeps it (grandfathered).
      const email = normalEmail(op.who.email);
      upsertUser(sql, op.who, email ?? "", now, false);
      if (email !== null && betaSince(sql) !== null) {
        sql.exec("INSERT OR IGNORE INTO dir_allowed (email, added_at) VALUES (?, ?)", email, now);
      }
      return { ok: true };
    }
    case "setBeta": {
      if (!op.on) {
        sql.exec("DELETE FROM dir_meta WHERE k = 'beta'");
      } else if (betaSince(sql) === null) {
        sql.exec("INSERT INTO dir_meta (k, v) VALUES ('beta', ?)", String(now));
        // Everyone with an account keeps it.
        sql.exec(
          `INSERT OR IGNORE INTO dir_allowed (email, added_at)
           SELECT email, ? FROM dir_users WHERE email != ''`,
          now,
        );
      }
      return { ok: true, view: view(sql) };
    }
    case "allow": {
      const email = normalEmail(op.email);
      if (email === null) return { ok: false, error: "bad_email" };
      sql.exec("INSERT OR IGNORE INTO dir_allowed (email, added_at) VALUES (?, ?)", email, now);
      sql.exec("DELETE FROM dir_requests WHERE email = ?", email);
      return { ok: true };
    }
    case "remove": {
      const email = normalEmail(op.email);
      if (email === null) return { ok: false, error: "bad_email" };
      const had = sql.exec("SELECT 1 FROM dir_allowed WHERE email = ?", email).toArray().length;
      sql.exec("DELETE FROM dir_allowed WHERE email = ?", email);
      const subs = sql
        .exec<{ sub: string }>("SELECT sub FROM dir_users WHERE email = ?", email)
        .toArray()
        .map((r) => r.sub);
      if (!had && subs.length === 0) return { ok: false, error: "not_found" };
      return { ok: true, revoke: subs };
    }
    case "list":
      return { ok: true, view: view(sql) };
  }
}

function view(sql: SqlStorage): DirectoryView {
  const allowed = new Set(
    sql.exec<{ email: string }>("SELECT email FROM dir_allowed").toArray().map((r) => r.email),
  );
  const users = sql
    .exec<{ sub: string; email: string; name: string; first_seen: number; last_signin: number | null }>(
      "SELECT sub, email, name, first_seen, last_signin FROM dir_users ORDER BY first_seen",
    )
    .toArray();
  const signedIn = new Set(users.map((u) => u.email));
  return {
    betaSince: betaSince(sql),
    users: users.map((u) => ({
      id: u.sub,
      email: u.email,
      name: u.name,
      firstSeen: u.first_seen,
      lastSignIn: u.last_signin,
      allowed: allowed.has(u.email),
    })),
    allowed: sql
      .exec<{ email: string; added_at: number }>("SELECT email, added_at FROM dir_allowed ORDER BY added_at")
      .toArray()
      .map((r) => ({ email: r.email, addedAt: r.added_at, signedIn: signedIn.has(r.email) })),
    requests: sql
      .exec<{ email: string; name: string; first_at: number; last_at: number; tries: number }>(
        "SELECT email, name, first_at, last_at, tries FROM dir_requests ORDER BY last_at DESC",
      )
      .toArray()
      .map((r) => ({ email: r.email, name: r.name, firstAt: r.first_at, lastAt: r.last_at, tries: r.tries })),
  };
}
