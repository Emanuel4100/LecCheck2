/**
 * Panopto on every device (the vault and pairing, see docs/PANOPTO.md).
 *
 * The vault is the user's Panopto setup and sign-in (site, client id and
 * secret, tokens), encrypted on the devices with a key the server never
 * sees. The server keeps the ciphertext, a version so a device can only
 * replace the copy it read, and a short lease so one device at a time
 * refreshes Panopto's single-use refresh token.
 *
 * Pairing hands the key to a new device: the new device (B) commits to its
 * public key, a device holding the key (A) answers with its own, B reveals
 * its key, both show a code made from the two keys, and on "Allow" A sends
 * the vault key wrapped for B. The server only relays public keys, the
 * commit and ciphertext.
 */

/** How long a refresh may hold the vault. Longer than a token request. */
export const LEASE_MS = 60_000;
/** Pairing requests left unanswered for this long are dropped. */
export const PAIR_MS = 10 * 60_000;
/** Account-wide wait between looks (a forced look doesn't wait). */
export const LOOK_EVERY_MS = 3 * 60 * 60_000;
export const MAX_OPEN_PAIRS = 5;
const MAX_CIPHERTEXT = 8_192;
const MAX_FIELD = 512;

export interface VaultView {
  v: number;
  kid: string;
  nonce: string;
  ct: string;
  /** The device that last wrote it (shown as "set up on …"). */
  device: string;
  updatedAt: number;
  lookedAt: number;
  /** Panopto refused the sign-in: any device can connect again. */
  refused: boolean;
}

export interface PairView {
  id: string;
  device: string;
  commit: string;
  aPub: string | null;
  bPub: string | null;
  nonce: string | null;
  wrapped: string | null;
  kid: string | null;
  denied: boolean;
  expiresAt: number;
}

export type PanoptoOp =
  | { op: "get" }
  | { op: "lease"; owner: string }
  | { op: "release"; owner: string }
  | {
      op: "put";
      expect: number;
      owner?: string;
      kid: string;
      nonce: string;
      ct: string;
      device: string;
      refused?: boolean;
    }
  | { op: "refused"; expect: number }
  | { op: "look"; force: boolean }
  | { op: "unlook"; at: number }
  | { op: "delete" }
  | { op: "pair"; device: string; commit: string }
  | { op: "pairGet"; id: string }
  | { op: "pairSet"; id: string; fields: Record<string, unknown> }
  | { op: "pairDelete"; id: string };

export interface PanoptoReply {
  status: number;
  body: unknown;
  /** Devices should read the vault or their pairing requests again. */
  changed?: boolean;
}

interface VaultRow {
  v: number;
  kid: string;
  nonce: string;
  ct: string;
  device: string;
  updated_at: number;
  looked_at: number;
  refused: number;
  lease_owner: string | null;
  lease_until: number;
  [key: string]: SqlStorageValue;
}

interface PairRow {
  id: string;
  device: string;
  commit_hash: string;
  a_pub: string | null;
  b_pub: string | null;
  nonce: string | null;
  wrapped: string | null;
  kid: string | null;
  denied: number;
  expires_at: number;
  [key: string]: SqlStorageValue;
}

export const VAULT_SCHEMA = `
  CREATE TABLE IF NOT EXISTS panopto_vault (
    k INTEGER PRIMARY KEY CHECK (k = 1),
    v INTEGER NOT NULL,
    kid TEXT NOT NULL,
    nonce TEXT NOT NULL,
    ct TEXT NOT NULL,
    device TEXT NOT NULL,
    updated_at INTEGER NOT NULL,
    looked_at INTEGER NOT NULL DEFAULT 0,
    refused INTEGER NOT NULL DEFAULT 0,
    lease_owner TEXT,
    lease_until INTEGER NOT NULL DEFAULT 0
  );
  CREATE TABLE IF NOT EXISTS panopto_pairs (
    id TEXT PRIMARY KEY,
    device TEXT NOT NULL,
    commit_hash TEXT NOT NULL,
    a_pub TEXT,
    b_pub TEXT,
    nonce TEXT,
    wrapped TEXT,
    kid TEXT,
    denied INTEGER NOT NULL DEFAULT 0,
    expires_at INTEGER NOT NULL
  );
`;

const isText = (x: unknown, max = MAX_FIELD): x is string =>
  typeof x === "string" && x.length > 0 && x.length <= max;

function view(row: VaultRow): VaultView {
  return {
    v: row.v,
    kid: row.kid,
    nonce: row.nonce,
    ct: row.ct,
    device: row.device,
    updatedAt: row.updated_at,
    lookedAt: row.looked_at,
    refused: row.refused !== 0,
  };
}

function pairView(row: PairRow): PairView {
  return {
    id: row.id,
    device: row.device,
    commit: row.commit_hash,
    aPub: row.a_pub,
    bPub: row.b_pub,
    nonce: row.nonce,
    wrapped: row.wrapped,
    kid: row.kid,
    denied: row.denied !== 0,
    expiresAt: row.expires_at,
  };
}

const bad = (error: string): PanoptoReply => ({ status: 400, body: { error } });

/** Runs one vault or pairing operation on the user's storage. */
export function panoptoOp(sql: SqlStorage, op: PanoptoOp, now: number): PanoptoReply {
  sql.exec("DELETE FROM panopto_pairs WHERE expires_at < ?", now);
  const row = sql.exec<VaultRow>("SELECT * FROM panopto_vault WHERE k = 1").toArray()[0];
  const leaseHeld = (owner?: string) =>
    row !== undefined && row.lease_until > now && row.lease_owner !== (owner ?? null);

  switch (op.op) {
    case "get": {
      const pairs = sql
        .exec<PairRow>("SELECT * FROM panopto_pairs ORDER BY expires_at")
        .toArray()
        .map(pairView);
      return { status: 200, body: { vault: row ? view(row) : null, pairs, now } };
    }

    case "lease": {
      if (!isText(op.owner, 64)) return bad("bad_owner");
      if (!row) return { status: 404, body: { error: "no_vault" } };
      if (leaseHeld(op.owner)) {
        return { status: 409, body: { error: "busy", until: row.lease_until } };
      }
      const until = now + LEASE_MS;
      sql.exec("UPDATE panopto_vault SET lease_owner = ?, lease_until = ? WHERE k = 1", op.owner, until);
      return { status: 200, body: { vault: view(row), until } };
    }

    case "release": {
      sql.exec(
        "UPDATE panopto_vault SET lease_owner = NULL, lease_until = 0 WHERE k = 1 AND lease_owner = ?",
        op.owner,
      );
      return { status: 204, body: null };
    }

    case "put": {
      if (!Number.isInteger(op.expect) || op.expect < 0) return bad("bad_expect");
      if (!isText(op.kid, 64) || !isText(op.nonce, 64) || !isText(op.ct, MAX_CIPHERTEXT)) {
        return bad("bad_vault");
      }
      if (!isText(op.device, 128)) return bad("bad_device");
      const current = row?.v ?? 0;
      if (op.expect !== current || leaseHeld(op.owner)) {
        return { status: 409, body: { error: "conflict", vault: row ? view(row) : null } };
      }
      const v = current + 1;
      sql.exec(
        `INSERT INTO panopto_vault (k, v, kid, nonce, ct, device, updated_at, looked_at, refused)
         VALUES (1, ?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(k) DO UPDATE SET v = excluded.v, kid = excluded.kid,
           nonce = excluded.nonce, ct = excluded.ct, device = excluded.device,
           updated_at = excluded.updated_at, refused = excluded.refused,
           lease_owner = NULL, lease_until = 0`,
        v,
        op.kid,
        op.nonce,
        op.ct,
        op.device,
        now,
        row?.looked_at ?? 0,
        op.refused ? 1 : 0,
      );
      // A new key (set up again elsewhere) makes open pairings useless.
      if (row && row.kid !== op.kid) sql.exec("DELETE FROM panopto_pairs");
      return { status: 200, body: { v }, changed: true };
    }

    case "refused": {
      // Only for the copy the device used: a newer sign-in may work.
      if (!row || row.v !== op.expect) {
        return { status: 409, body: { error: "conflict", vault: row ? view(row) : null } };
      }
      sql.exec("UPDATE panopto_vault SET refused = 1 WHERE k = 1");
      return { status: 204, body: null, changed: true };
    }

    case "look": {
      if (!row) return { status: 404, body: { error: "no_vault" } };
      if (!op.force && now - row.looked_at < LOOK_EVERY_MS) {
        return { status: 200, body: { ok: false, lookedAt: row.looked_at } };
      }
      sql.exec("UPDATE panopto_vault SET looked_at = ? WHERE k = 1", now);
      return { status: 200, body: { ok: true, lookedAt: now } };
    }

    case "unlook": {
      // A look that failed for a passing reason gives its claim back.
      sql.exec("UPDATE panopto_vault SET looked_at = 0 WHERE k = 1 AND looked_at = ?", op.at);
      return { status: 204, body: null };
    }

    case "delete": {
      sql.exec("DELETE FROM panopto_vault");
      sql.exec("DELETE FROM panopto_pairs");
      return { status: 204, body: null, changed: true };
    }

    case "pair": {
      if (!isText(op.device, 128)) return bad("bad_device");
      if (!isText(op.commit, 128)) return bad("bad_commit");
      if (!row) return { status: 404, body: { error: "no_vault" } };
      const open = sql.exec<{ n: number }>("SELECT COUNT(*) AS n FROM panopto_pairs").one().n;
      if (open >= MAX_OPEN_PAIRS) return { status: 429, body: { error: "too_many" } };
      const id = crypto.randomUUID();
      const expiresAt = now + PAIR_MS;
      sql.exec(
        "INSERT INTO panopto_pairs (id, device, commit_hash, expires_at) VALUES (?, ?, ?, ?)",
        id,
        op.device,
        op.commit,
        expiresAt,
      );
      return { status: 200, body: { id, expiresAt }, changed: true };
    }

    case "pairGet": {
      const pair = sql.exec<PairRow>("SELECT * FROM panopto_pairs WHERE id = ?", op.id).toArray()[0];
      return pair
        ? { status: 200, body: pairView(pair) }
        : { status: 404, body: { error: "no_pair" } };
    }

    case "pairSet": {
      const pair = sql.exec<PairRow>("SELECT * FROM panopto_pairs WHERE id = ?", op.id).toArray()[0];
      if (!pair) return { status: 404, body: { error: "no_pair" } };
      const f = op.fields;
      // Each step once, in order: A's key, B's key and nonce, the wrapped key.
      if ("denied" in f) {
        sql.exec("UPDATE panopto_pairs SET denied = 1 WHERE id = ?", op.id);
      } else if ("aPub" in f) {
        if (!isText(f.aPub, 128)) return bad("bad_key");
        if (pair.a_pub !== null) return { status: 409, body: { error: "answered" } };
        sql.exec("UPDATE panopto_pairs SET a_pub = ? WHERE id = ?", f.aPub, op.id);
      } else if ("bPub" in f) {
        if (!isText(f.bPub, 128) || !isText(f.nonce, 128)) return bad("bad_key");
        if (pair.a_pub === null || pair.b_pub !== null) {
          return { status: 409, body: { error: "out_of_order" } };
        }
        sql.exec("UPDATE panopto_pairs SET b_pub = ?, nonce = ? WHERE id = ?", f.bPub, f.nonce, op.id);
      } else if ("wrapped" in f) {
        if (!isText(f.wrapped, 512) || !isText(f.kid, 64)) return bad("bad_key");
        if (pair.b_pub === null || pair.wrapped !== null) {
          return { status: 409, body: { error: "out_of_order" } };
        }
        sql.exec("UPDATE panopto_pairs SET wrapped = ?, kid = ? WHERE id = ?", f.wrapped, f.kid, op.id);
      } else {
        return bad("bad_fields");
      }
      return { status: 204, body: null, changed: true };
    }

    case "pairDelete": {
      sql.exec("DELETE FROM panopto_pairs WHERE id = ?", op.id);
      return { status: 204, body: null, changed: true };
    }
  }
}
