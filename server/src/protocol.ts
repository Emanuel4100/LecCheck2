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

/** Bumped when the sync messages change incompatibly. `GET /v1/health`
 * reports it. */
export const PROTOCOL_VERSION = 1;

export const MAX_CHANGES_PER_PUSH = 500;
/** One change: room for the app's longest note (10,000 characters, even
 * with JSON escapes). Rows are capped at [MAX_ROW_BYTES] anyway. */
export const MAX_PATCH_BYTES = 32 * 1024;
export const MAX_MESSAGE_BYTES = 1024 * 1024;
export const MAX_CLOCK_SKEW_MS = 5 * 60 * 1000;
export const PAGE_SIZE = 500;

/** Per-account limits, so one account can't use up the free plan's shared
 * daily row writes (100,000 for all users) or its 5 GB of storage. Far above
 * what a real account needs (a full semester is well under 1,000 rows). */
export const USER_ROWS_WRITTEN_PER_DAY = 10_000;
export const MAX_ACCOUNT_ROWS = 50_000;
export const MAX_ACCOUNT_BYTES = 25 * 1024 * 1024;
export const MAX_ROW_BYTES = 64 * 1024;

/** Field names: the app's columns are camelCase (`semesterId`). Anything
 * else (`__proto__`, megabyte-long keys) is refused. */
const FIELD = /^[A-Za-z][A-Za-z0-9_]{0,63}$/;

/** Hybrid logical clock: `<15-digit ms>:<4 hex counter>:<node id>`. Fixed
 * width, so plain string comparison orders clocks correctly. */
const HLC = /^(\d{15}):([0-9a-f]{4}):([0-9A-Za-z_-]{4,64})$/;

export interface Change {
  tbl: string;
  id: string;
  /** Only the fields that changed. */
  patch: Record<string, unknown>;
  hlc: string;
  /** Only fill fields the server doesn't have yet (see `applyPatch`). */
  ifAbsent?: boolean;
}

export interface WireRow {
  tbl: string;
  id: string;
  /** Full current state of the row. */
  data: Record<string, unknown>;
  v: number;
}

export interface Rejected {
  /** Position of the change in the pushed list. */
  i: number;
  tbl: string;
  id: string;
  reason: string;
}

export type ClientMessage =
  | {
      t: "hello";
      since: number;
      dataset?: string;
      /** The app's build number (from 2.0.0-beta.5): see [appTooOld]. */
      app?: number;
    }
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
      /** Identifies this copy of the account's data (catch-up only). A new id
       * means the data was reset or restored: the client starts over from 0
       * and re-offers its own rows. */
      dataset?: string;
      /** Server time in ms, so clients can correct a wrong device clock. */
      now?: number;
    }
  | {
      t: "ack";
      batchId: string;
      rejected: Rejected[];
      /** Current state of rows where some pushed field didn't win. */
      rows: WireRow[];
      clock: string | null;
      now: number;
    }
  | {
      t: "error";
      code: string;
      message: string;
      /** Set when storage can't be used right now (see `unavailable`): the
       * client keeps its changes and tries again at this server time (ms). */
      retryAt?: number;
    };

const DAY_MS = 24 * 60 * 60 * 1000;

export interface Unavailable {
  /** `user_quota`: this account wrote [USER_ROWS_WRITTEN_PER_DAY] rows today. */
  code: "quota" | "user_quota" | "unavailable";
  retryAt: number;
}

/** Thrown inside a push when the account's daily write budget is used up:
 * nothing is saved, and the device waits until 00:00 UTC. */
export class UserQuotaExceeded extends Error {
  constructor() {
    super("This account's daily sync limit is used up");
  }
}

function nextMidnight(now: number): number {
  return (Math.floor(now / DAY_MS) + 1) * DAY_MS;
}

/**
 * Classifies a failed storage operation. On the free plan, going over a daily
 * limit (requests, rows read or rows written, shared by all users) makes
 * operations fail until the limits reset at 00:00 UTC. Anything else is tried
 * again after a minute (clients back off further if it keeps failing).
 */
export function unavailable(error: unknown, now: number): Unavailable {
  if (error instanceof UserQuotaExceeded) return { code: "user_quota", retryAt: nextMidnight(now) };
  const message = error instanceof Error ? error.message : String(error);
  return /free tier|daily limit|quota|exceeded allowed|SQLITE_FULL|disk is full/i.test(message)
    ? { code: "quota", retryAt: nextMidnight(now) }
    : { code: "unavailable", retryAt: now + 60_000 };
}

/** HTTP answer for [Unavailable]: 503 with `Retry-After`. */
export function unavailableResponse(failure: Unavailable, now = Date.now()): Response {
  const seconds = Math.max(1, Math.ceil((failure.retryAt - now) / 1000));
  return Response.json(
    { error: failure.code, retryAt: failure.retryAt },
    { status: 503, headers: { "Retry-After": String(seconds) } },
  );
}

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
  if (!Object.keys(c.patch).every((field) => FIELD.test(field))) {
    return { ok: false, reason: "bad_field" };
  }
  const millis = typeof c.hlc === "string" ? hlcMillis(c.hlc) : null;
  if (millis === null) return { ok: false, reason: "bad_clock" };
  if (c.ifAbsent !== undefined && typeof c.ifAbsent !== "boolean") {
    return { ok: false, reason: "malformed" };
  }
  // A device whose clock runs far ahead would win every merge for days.
  if (millis > now + MAX_CLOCK_SKEW_MS) {
    return { ok: false, reason: "clock_skew" };
  }
  return {
    ok: true,
    change: {
      tbl: c.tbl,
      id: c.id,
      patch: c.patch,
      hlc: c.hlc!,
      ...(c.ifAbsent ? { ifAbsent: true } : {}),
    },
  };
}

/** Whether an app build is older than `MIN_APP_BUILD` (unset: none is). Apps
 * before 2.0.0-beta.5 don't send their build, so they count as too old once
 * a minimum is set. Such apps get `upgrade_required` instead of syncing. */
export function appTooOld(minAppBuild: string | undefined, build: unknown): boolean {
  const min = Number(minAppBuild);
  if (!minAppBuild || !Number.isFinite(min) || min <= 0) return false;
  return !(typeof build === "number" && build >= min);
}
