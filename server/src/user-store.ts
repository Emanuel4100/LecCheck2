import { DurableObject } from "cloudflare:workers";
import { applyPatch, type RowState } from "./merge";
import {
  MAX_CHANGES_PER_PUSH,
  MAX_MESSAGE_BYTES,
  PAGE_SIZE,
  validateChange,
  type Change,
  type Rejected,
  type ServerMessage,
  type WireRow,
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
  clock: string | null;
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

  async deleteAccount(): Promise<void> {
    for (const ws of this.ctx.getWebSockets()) ws.close(4002, "deleted");
    await this.ctx.storage.deleteAll();
  }

  // ------------------------------------------------------------- sync --

  /** HTTP fallback: push changes and pull everything after [since]. */
  async sync(epoch: number, since: number, changes: unknown[]): Promise<SyncResult | null> {
    if (epoch !== (await this.epoch())) return null;
    const { changedRows, rejected } = this.applyChanges(changes);
    if (changedRows.length) this.broadcast(changedRows);
    const page = this.changesSince(since);
    return { ...page, rejected, clock: this.clock() };
  }

  private applyChanges(changes: unknown[]): {
    changedRows: WireRow[];
    rejected: Rejected[];
  } {
    const rejected: Rejected[] = [];
    const changed = new Map<string, WireRow>();
    if (changes.length > MAX_CHANGES_PER_PUSH) {
      return {
        changedRows: [],
        rejected: [{ tbl: "", id: "", reason: "too_many_changes" }],
      };
    }
    const now = Date.now();
    this.ctx.storage.transactionSync(() => {
      let version = this.version();
      let clock = this.clock();
      for (const raw of changes) {
        const result = validateChange(raw, now);
        if (!result.ok) {
          const r = raw as Partial<Change> | null;
          rejected.push({
            tbl: String(r?.tbl ?? ""),
            id: String(r?.id ?? ""),
            reason: result.reason,
          });
          continue;
        }
        const change = result.change;
        if (clock === null || change.hlc > clock) clock = change.hlc;

        const existing = this.sql
          .exec<{ data: string; clocks: string }>(
            "SELECT data, clocks FROM rows WHERE tbl = ? AND id = ?",
            change.tbl,
            change.id,
          )
          .toArray()[0];
        const state: RowState | null = existing
          ? { data: JSON.parse(existing.data), clocks: JSON.parse(existing.clocks) }
          : null;
        const merged = applyPatch(state, change);
        if (!merged.clockChanged) continue;

        const data = JSON.stringify(merged.state.data);
        const clocks = JSON.stringify(merged.state.clocks);
        if (merged.dataChanged) {
          version += 1;
          this.sql.exec(
            `INSERT INTO rows (tbl, id, data, clocks, version) VALUES (?, ?, ?, ?, ?)
             ON CONFLICT(tbl, id) DO UPDATE SET data = excluded.data,
               clocks = excluded.clocks, version = excluded.version`,
            change.tbl,
            change.id,
            data,
            clocks,
            version,
          );
          changed.set(`${change.tbl}/${change.id}`, {
            tbl: change.tbl,
            id: change.id,
            data: merged.state.data,
            v: version,
          });
        } else {
          this.sql.exec(
            "UPDATE rows SET clocks = ? WHERE tbl = ? AND id = ?",
            clocks,
            change.tbl,
            change.id,
          );
        }
      }
      this.setMeta("version", String(version));
      if (clock !== null) this.setMeta("clock", clock);
    });
    return { changedRows: [...changed.values()], rejected };
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
    if (epoch !== (await this.epoch())) {
      return new Response("Session revoked", { status: 401 });
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
    let msg: { t?: string; since?: unknown; batchId?: unknown; changes?: unknown };
    try {
      msg = JSON.parse(message);
    } catch {
      this.send(ws, { t: "error", code: "bad_json", message: "Invalid JSON" });
      return;
    }
    switch (msg.t) {
      case "hello": {
        let cursor = Number(msg.since) || 0;
        let more = true;
        while (more) {
          const page = this.changesSince(cursor);
          this.send(ws, { t: "changes", ...page, clock: this.clock(), catchUp: true });
          cursor = page.upto;
          more = page.more;
        }
        break;
      }
      case "push": {
        const changes = Array.isArray(msg.changes) ? msg.changes : [];
        const { changedRows, rejected } = this.applyChanges(changes);
        if (changedRows.length) this.broadcast(changedRows);
        this.send(ws, {
          t: "ack",
          batchId: String(msg.batchId ?? ""),
          rejected,
          clock: this.clock(),
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
