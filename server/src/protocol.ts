/** Wire protocol shared by the WebSocket and HTTP sync endpoints. */

/** Tables a client may write. The server stores rows as JSON and never needs
 * to know their columns, so client schema changes need no server migration. */
export const SYNCED_TABLES = new Set([
  "semesters",
  "courses",
  "meetings",
  "session_overrides",
  "no_class_ranges",
  "requirements",
  "user_settings",
]);

export const MAX_CHANGES_PER_PUSH = 500;
export const MAX_PATCH_BYTES = 16 * 1024;
export const MAX_MESSAGE_BYTES = 1024 * 1024;
export const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;
export const PAGE_SIZE = 500;

/** Hybrid logical clock: `<15-digit ms>:<4 hex counter>:<node id>`. Fixed
 * width, so plain string comparison orders clocks correctly. */
const HLC = /^(\d{15}):([0-9a-f]{4}):([0-9A-Za-z_-]{4,64})$/;

export interface Change {
  tbl: string;
  id: string;
  /** Only the fields that changed. */
  patch: Record<string, unknown>;
  hlc: string;
}

export interface WireRow {
  tbl: string;
  id: string;
  /** Full current state of the row. */
  data: Record<string, unknown>;
  v: number;
}

export interface Rejected {
  tbl: string;
  id: string;
  reason: string;
}

export type ClientMessage =
  | { t: "hello"; since: number }
  | { t: "push"; batchId: string; changes: Change[] };

export type ServerMessage =
  | {
      t: "changes";
      rows: WireRow[];
      upto: number;
      more: boolean;
      clock: string | null;
      /** Set on replies to `hello`; clients only move their saved cursor
       * from broadcasts once catch-up has finished. */
      catchUp?: boolean;
    }
  | { t: "ack"; batchId: string; rejected: Rejected[]; clock: string | null }
  | { t: "error"; code: string; message: string };

export function hlcMillis(hlc: string): number | null {
  const m = HLC.exec(hlc);
  return m ? Number(m[1]) : null;
}

export type Validation =
  | { ok: true; change: Change }
  | { ok: false; reason: string };

export function validateChange(raw: unknown, now: number): Validation {
  if (typeof raw !== "object" || raw === null) {
    return { ok: false, reason: "malformed" };
  }
  const c = raw as Partial<Change>;
  if (typeof c.tbl !== "string" || !SYNCED_TABLES.has(c.tbl)) {
    return { ok: false, reason: "unknown_table" };
  }
  if (typeof c.id !== "string" || c.id.length === 0 || c.id.length > 128) {
    return { ok: false, reason: "bad_id" };
  }
  if (typeof c.patch !== "object" || c.patch === null || Array.isArray(c.patch)) {
    return { ok: false, reason: "bad_patch" };
  }
  if (JSON.stringify(c.patch).length > MAX_PATCH_BYTES) {
    return { ok: false, reason: "patch_too_large" };
  }
  const millis = typeof c.hlc === "string" ? hlcMillis(c.hlc) : null;
  if (millis === null) return { ok: false, reason: "bad_clock" };
  // A device whose clock runs far ahead would win every merge for days.
  if (millis > now + MAX_CLOCK_SKEW_MS) {
    return { ok: false, reason: "clock_skew" };
  }
  return {
    ok: true,
    change: { tbl: c.tbl, id: c.id, patch: c.patch, hlc: c.hlc! },
  };
}
