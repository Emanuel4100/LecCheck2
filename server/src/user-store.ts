import { DurableObject } from "cloudflare:workers";
import { applyPatch, type RowState } from "./merge";
import {
  MAX_CHANGES_PER_PUSH,
  MAX_MESSAGE_BYTES,
  PAGE_SIZE,
  unavailable,
  validateChange,
  type Change,
  type Rejected,
  type ServerMessage,
  type Unavailable,
  type WireRow,
  unavailableResponse,
} from "./protocol";

export interface Env {
  USER_STORE: DurableObjectNamespace<UserStore>;
  JWT_SECRET: string;
  GOOGLE_CLIENT_ID?: string;
  GOOGLE_CLIENT_SECRET?: string;
  DEV_AUTH?: string;
}

export interface SyncResult {
  rows: WireRow[];
  upto: number;
  more: boolean;
  rejected: Rejected[];
  /** Current state of rows where some pushed field didn't win. */
  corrections: WireRow[];
  clock: string | null;
  dataset: string;
  now: number;
}

const DAY_MS = 24 * 60 * 60 * 1000;
/** Deleted cloud data can be restored for this long. */
export const TRASH_DAYS = 30;

/** A row touched by a pushed batch, merged in memory before it's written. */
interface TouchedRow {
  tbl: string;
  id: string;
  state: RowState | null;
  version: number;
  dataChanged: boolean;
  clockChanged: boolean;
  lost: boolean;
}

/** A message from a device (validated field by field where it's used). */
interface Incoming {
  t?: string;
  since?: unknown;
  dataset?: unknown;
  batchId?: unknown;
  changes?: unknown;
}

/**
 * One instance per user (named by user id). Holds the user's rows in its own
 * SQLite database and fans changes out to the user's connected devices.
 * Uses the WebSocket Hibernation API: idle connections cost nothing, and
 * pings are answered without waking the object.
 */
export class UserStore extends DurableObject<Env> {
  private readonly sql: SqlStorage;

  constructor(ctx: DurableObjectState, env: Env) {
    super(ctx, env);
    this.sql = ctx.storage.sql;
    this.sql.exec(`
      CREATE TABLE IF NOT EXISTS rows (
        tbl TEXT NOT NULL,
        id TEXT NOT NULL,
        data TEXT NOT NULL,
        clocks TEXT NOT NULL,
        version INTEGER NOT NULL,
        PRIMARY KEY (tbl, id)
      );
      CREATE INDEX IF NOT EXISTS rows_version ON rows(version);
      CREATE TABLE IF NOT EXISTS meta (k TEXT PRIMARY KEY, v TEXT NOT NULL);
      CREATE TABLE IF NOT EXISTS used_codes (jti TEXT PRIMARY KEY, exp INTEGER NOT NULL);
      CREATE TABLE IF NOT EXISTS trash (
        tbl TEXT NOT NULL,
        id TEXT NOT NULL,
        data TEXT NOT NULL,
        clocks TEXT NOT NULL,
        deleted_at INTEGER NOT NULL,
        PRIMARY KEY (tbl, id)
      );
    `);
    ctx.setWebSocketAutoResponse(
      new WebSocketRequestResponsePair('{"t":"ping"}', '{"t":"pong"}'),
    );
  }

  // ------------------------------------------------------------- meta --

  private meta(key: string): string | null {
    const row = this.sql
      .exec<{ v: string }>("SELECT v FROM meta WHERE k = ?", key)
      .toArray()[0];
    return row?.v ?? null;
  }

  private setMeta(key: string, value: string): void {
    this.sql.exec(
      "INSERT INTO meta (k, v) VALUES (?, ?) ON CONFLICT(k) DO UPDATE SET v = excluded.v",
      key,
      value,
    );
  }

  private version(): number {
    return Number(this.meta("version") ?? 0);
  }

  private clock(): string | null {
    return this.meta("clock");
  }

  /** Id of this copy of the data; changes when it's reset or restored. */
  private dataset(): string {
    let id = this.meta("dataset");
    if (id === null) {
      id = crypto.randomUUID();
      this.setMeta("dataset", id);
    }
    return id;
  }

  // ------------------------------------------------------- auth (RPC) --

  async epoch(): Promise<number> {
    return Number(this.meta("epoch") ?? 0);
  }

  /** "Sign out everywhere": invalidates every session token issued so far. */
  async bumpEpoch(): Promise<number> {
    const next = (await this.epoch()) + 1;
    this.setMeta("epoch", String(next));
    for (const ws of this.ctx.getWebSockets()) ws.close(4001, "revoked");
    return next;
  }

  /** One-time sign-in codes can be exchanged only once. */
  async consumeCode(jti: string, exp: number): Promise<boolean> {
    const now = Math.floor(Date.now() / 1000);
    this.sql.exec("DELETE FROM used_codes WHERE exp < ?", now);
    const seen = this.sql
      .exec("SELECT 1 FROM used_codes WHERE jti = ?", jti)
      .toArray().length;
    if (seen) return false;
    this.sql.exec("INSERT INTO used_codes (jti, exp) VALUES (?, ?)", jti, exp);
    return true;
  }

  /**
   * "Delete cloud data": signs out every device and moves the rows to a trash
   * that's purged after [TRASH_DAYS] days, so a mistake can still be undone.
   */
  async deleteAccount(): Promise<void> {
    const now = Date.now();
    this.ctx.storage.transactionSync(() => {
      this.sql.exec(
        `INSERT INTO trash (tbl, id, data, clocks, deleted_at)
         SELECT tbl, id, data, clocks, ? FROM rows WHERE true
         ON CONFLICT(tbl, id) DO UPDATE SET data = excluded.data,
           clocks = excluded.clocks, deleted_at = excluded.deleted_at`,
        now,
      );
      this.sql.exec("DELETE FROM rows");
      this.setMeta("dataset", crypto.randomUUID());
    });
    await this.bumpEpoch();
    await this.ctx.storage.setAlarm(now + TRASH_DAYS * DAY_MS);
  }

  /** Brings back data removed by [deleteAccount] (rows not re-created since).
   * Returns how many rows came back. */
  async restoreDeleted(): Promise<number> {
    let restored: WireRow[] = [];
    this.ctx.storage.transactionSync(() => {
      let version = this.version();
      const rows = this.sql
        .exec<{ tbl: string; id: string; data: string; clocks: string }>(
          `SELECT tbl, id, data, clocks FROM trash t WHERE NOT EXISTS
             (SELECT 1 FROM rows r WHERE r.tbl = t.tbl AND r.id = t.id)`,
        )
        .toArray();
      for (const r of rows) {
        version += 1;
        this.sql.exec(
          "INSERT INTO rows (tbl, id, data, clocks, version) VALUES (?, ?, ?, ?, ?)",
          r.tbl,
          r.id,
          r.data,
          r.clocks,
          version,
        );
        restored.push({ tbl: r.tbl, id: r.id, data: JSON.parse(r.data), v: version });
      }
      this.sql.exec("DELETE FROM trash");
      this.setMeta("version", String(version));
    });
    if (restored.length) this.broadcast(restored);
    return restored.length;
  }

  async alarm(): Promise<void> {
    const now = Date.now();
    this.sql.exec("DELETE FROM trash WHERE deleted_at < ?", now - TRASH_DAYS * DAY_MS + 60_000);
    const next = this.sql
      .exec<{ at: number | null }>("SELECT MIN(deleted_at) AS at FROM trash")
      .toArray()[0]?.at;
    if (next != null) await this.ctx.storage.setAlarm(next + TRASH_DAYS * DAY_MS);
  }

  // --------------------------------------------------------- recovery --

  /** Point-in-time recovery bookmark for [at] (up to 30 days back). */
  async bookmarkFor(at: number): Promise<string> {
    return this.ctx.storage.getBookmarkForTime(at);
  }

  /**
   * Rolls the whole store back to [bookmark]. The object restarts (so this
   * call fails by design); the caller must then call [afterRestore].
   */
  async restoreBookmark(bookmark: string): Promise<void> {
    await this.ctx.storage.onNextSessionRestoreBookmark(bookmark);
    this.ctx.abort("restoring");
  }

  /** After a point-in-time restore: keeps sessions revoked since then
   * revoked, and gives the data a new dataset id so devices re-offer edits
   * made after [at] instead of trusting cursors from the future. */
  async afterRestore(minEpoch: number): Promise<void> {
    if ((await this.epoch()) < minEpoch) this.setMeta("epoch", String(minEpoch));
    this.setMeta("dataset", crypto.randomUUID());
    for (const ws of this.ctx.getWebSockets()) ws.close(1012, "restored");
  }

  // ------------------------------------------------------------- sync --

  /** HTTP fallback: push changes and pull everything after [since]. */
  async sync(
    epoch: number,
    since: number,
    changes: unknown[],
    knownDataset: string | null = null,
  ): Promise<SyncResult | Unavailable | null> {
    try {
      if (epoch !== (await this.epoch())) return null;
      if (knownDataset !== null && knownDataset !== this.dataset()) since = 0;
      const { changedRows, rejected, corrections } = this.applyChanges(changes);
      if (changedRows.length) this.broadcast(changedRows);
      const page = this.changesSince(since);
      return {
        ...page,
        rejected,
        corrections,
        clock: this.clock(),
        dataset: this.dataset(),
        now: Date.now(),
      };
    } catch (error) {
      console.error("sync failed", error);
      return unavailable(error, Date.now());
    }
  }

  /**
   * Applies a pushed batch in one transaction (all or nothing). Every row the
   * batch touches is read once, merged in memory and written once, so several
   * queued edits to the same item cost one write: the free plan allows
   * 100,000 rows written a day, shared by all users.
   */
  private applyChanges(changes: unknown[]): {
    changedRows: WireRow[];
    rejected: Rejected[];
    corrections: WireRow[];
  } {
    if (changes.length > MAX_CHANGES_PER_PUSH) {
      return {
        changedRows: [],
        rejected: changes.map((_, i) => ({ i, tbl: "", id: "", reason: "too_many_changes" })),
        corrections: [],
      };
    }
    const now = Date.now();
    const rejected: Rejected[] = [];
    const changedRows: WireRow[] = [];
    const corrections: WireRow[] = [];
    this.ctx.storage.transactionSync(() => {
      const touched = new Map<string, TouchedRow>();
      const startVersion = this.version();
      const startClock = this.clock();
      let version = startVersion;
      let clock = startClock;
      for (const [i, raw] of changes.entries()) {
        const result = validateChange(raw, now);
        if (!result.ok) {
          const r = raw as Partial<Change> | null;
          rejected.push({
            i,
            tbl: String(r?.tbl ?? ""),
            id: String(r?.id ?? ""),
            reason: result.reason,
          });
          continue;
        }
        const change = result.change;
        if (clock === null || change.hlc > clock) clock = change.hlc;

        const key = `${change.tbl}/${change.id}`;
        let row = touched.get(key);
        if (!row) {
          const existing = this.sql
            .exec<{ data: string; clocks: string; version: number }>(
              "SELECT data, clocks, version FROM rows WHERE tbl = ? AND id = ?",
              change.tbl,
              change.id,
            )
            .toArray()[0];
          row = {
            tbl: change.tbl,
            id: change.id,
            state: existing
              ? { data: JSON.parse(existing.data), clocks: JSON.parse(existing.clocks) }
              : null,
            version: existing?.version ?? 0,
            dataChanged: false,
            clockChanged: false,
            lost: false,
          };
          touched.set(key, row);
        }
        const merged = applyPatch(row.state, change);
        if (merged.lost) row.lost = true;
        if (!merged.clockChanged) continue;
        row.state = merged.state;
        row.clockChanged = true;
        if (merged.dataChanged) row.dataChanged = true;
      }

      for (const row of touched.values()) {
        if (row.state === null) continue;
        const clocks = JSON.stringify(row.state.clocks);
        if (row.dataChanged) {
          version += 1;
          row.version = version;
          this.sql.exec(
            `INSERT INTO rows (tbl, id, data, clocks, version) VALUES (?, ?, ?, ?, ?)
             ON CONFLICT(tbl, id) DO UPDATE SET data = excluded.data,
               clocks = excluded.clocks, version = excluded.version`,
            row.tbl,
            row.id,
            JSON.stringify(row.state.data),
            clocks,
            version,
          );
          changedRows.push({ tbl: row.tbl, id: row.id, data: row.state.data, v: version });
        } else if (row.clockChanged) {
          this.sql.exec(
            "UPDATE rows SET clocks = ? WHERE tbl = ? AND id = ?",
            clocks,
            row.tbl,
            row.id,
          );
        }
        // Some pushed field lost to a newer write: send the sender the row
        // as it is now, so its copy doesn't keep the losing value.
        if (row.lost) {
          corrections.push({ tbl: row.tbl, id: row.id, data: row.state.data, v: row.version });
        }
      }
      if (version !== startVersion) this.setMeta("version", String(version));
      if (clock !== null && clock !== startClock) this.setMeta("clock", clock);
    });
    return { changedRows, rejected, corrections };
  }

  private changesSince(since: number): { rows: WireRow[]; upto: number; more: boolean } {
    const rows = this.sql
      .exec<{ tbl: string; id: string; data: string; version: number }>(
        "SELECT tbl, id, data, version FROM rows WHERE version > ? ORDER BY version LIMIT ?",
        since,
        PAGE_SIZE + 1,
      )
      .toArray();
    const more = rows.length > PAGE_SIZE;
    const page = rows.slice(0, PAGE_SIZE).map((r) => ({
      tbl: r.tbl,
      id: r.id,
      data: JSON.parse(r.data) as Record<string, unknown>,
      v: r.version,
    }));
    const upto = more ? page[page.length - 1].v : Math.max(since, this.version());
    return { rows: page, upto, more };
  }

  /** Sends changed rows to every connected device (the sender included, so
   * every client sees every version in order). */
  private broadcast(rows: WireRow[]): void {
    const message: ServerMessage = {
      t: "changes",
      rows,
      upto: this.version(),
      more: false,
      clock: this.clock(),
    };
    const json = JSON.stringify(message);
    for (const ws of this.ctx.getWebSockets()) {
      try {
        ws.send(json);
      } catch {
        // Closed sockets are cleaned up by the runtime.
      }
    }
  }

  // -------------------------------------------------------- websocket --

  async fetch(request: Request): Promise<Response> {
    if (request.headers.get("Upgrade") !== "websocket") {
      return new Response("Expected a WebSocket", { status: 426 });
    }
    const epoch = Number(request.headers.get("X-Session-Epoch"));
    try {
      if (epoch !== (await this.epoch())) {
        return new Response("Session revoked", { status: 401 });
      }
    } catch (error) {
      console.error("connect failed", error);
      return unavailableResponse(unavailable(error, Date.now()));
    }
    const pair = new WebSocketPair();
    this.ctx.acceptWebSocket(pair[1]);
    return new Response(null, { status: 101, webSocket: pair[0] });
  }

  async webSocketMessage(ws: WebSocket, message: string | ArrayBuffer): Promise<void> {
    if (typeof message !== "string" || message.length > MAX_MESSAGE_BYTES) {
      this.send(ws, { t: "error", code: "bad_message", message: "Expected JSON text" });
      return;
    }
    let msg: Incoming;
    try {
      msg = JSON.parse(message);
    } catch {
      this.send(ws, { t: "error", code: "bad_json", message: "Invalid JSON" });
      return;
    }
    try {
      this.handle(ws, msg);
    } catch (error) {
      // Nothing was saved (pushes are one transaction). The client keeps its
      // changes and reconnects at `retryAt`.
      console.error("sync failed", error);
      const failure = unavailable(error, Date.now());
      try {
        this.send(ws, { t: "error", message: "Storage unavailable", ...failure });
      } catch {
        // The socket closed; the client reconnects anyway.
      }
    }
  }

  private handle(ws: WebSocket, msg: Incoming): void {
    switch (msg.t) {
      case "hello": {
        const dataset = this.dataset();
        // A device that synced with another copy of the data (before a reset
        // or restore) starts over, so it can't skip versions.
        const known = typeof msg.dataset === "string" ? msg.dataset : null;
        let cursor = known !== null && known !== dataset ? 0 : Number(msg.since) || 0;
        let more = true;
        while (more) {
          const page = this.changesSince(cursor);
          this.send(ws, {
            t: "changes",
            ...page,
            clock: this.clock(),
            catchUp: true,
            dataset,
            now: Date.now(),
          });
          cursor = page.upto;
          more = page.more;
        }
        break;
      }
      case "push": {
        const changes = Array.isArray(msg.changes) ? msg.changes : [];
        const { changedRows, rejected, corrections } = this.applyChanges(changes);
        if (changedRows.length) this.broadcast(changedRows);
        this.send(ws, {
          t: "ack",
          batchId: String(msg.batchId ?? ""),
          rejected,
          rows: corrections,
          clock: this.clock(),
          now: Date.now(),
        });
        break;
      }
      default:
        this.send(ws, { t: "error", code: "unknown_type", message: String(msg.t) });
    }
  }

  async webSocketClose(ws: WebSocket, code: number, reason: string): Promise<void> {
    try {
      ws.close(code, reason);
    } catch {
      // Already closed.
    }
  }

  private send(ws: WebSocket, message: ServerMessage): void {
    ws.send(JSON.stringify(message));
  }
}
