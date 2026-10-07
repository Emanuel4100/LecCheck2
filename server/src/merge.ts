import type { Change } from "./protocol";

export interface RowState {
  data: Record<string, unknown>;
  /** Clock of the last accepted write, per field. */
  clocks: Record<string, string>;
}

export interface MergeResult {
  state: RowState;
  /** Some value changed — the row needs a new version and a broadcast. */
  dataChanged: boolean;
  /** Some field clock advanced (even if the value stayed the same). */
  clockChanged: boolean;
  /** Some field of the patch wasn't taken, so the sender's copy is stale. */
  lost: boolean;
}

/**
 * Per-field last-writer-wins. Each field in the patch is taken only if the
 * patch's clock is newer than the clock stored for that field, so two devices
 * editing different fields of the same row (status on the phone, notes on
 * the laptop) both keep their change.
 *
 * An `ifAbsent` change only fills fields the server has never seen: used when
 * a device's existing copy joins an account, so an old copy can't overwrite
 * newer edits (or bring back deleted rows) just because it's pushed later.
 */
export function applyPatch(state: RowState | null, change: Change): MergeResult {
  const data: Record<string, unknown> = { ...(state?.data ?? {}) };
  const clocks: Record<string, string> = { ...(state?.clocks ?? {}) };
  let dataChanged = state === null;
  let clockChanged = state === null;
  let lost = false;

  for (const [field, value] of Object.entries(change.patch)) {
    if (field === "id") continue;
    const current = clocks[field];
    const skip =
      current !== undefined && (change.ifAbsent === true || change.hlc <= current);
    if (skip) {
      if (!sameValue(data[field], value)) lost = true;
      continue;
    }
    clocks[field] = change.hlc;
    clockChanged = true;
    if (!sameValue(data[field], value) || !(field in data)) {
      data[field] = value;
      dataChanged = true;
    }
  }
  data.id = change.id;
  return { state: { data, clocks }, dataChanged, clockChanged, lost };
}

function sameValue(a: unknown, b: unknown): boolean {
  if (a === b) return true;
  if (typeof a === "object" && typeof b === "object" && a !== null && b !== null) {
    return JSON.stringify(a) === JSON.stringify(b);
  }
  return false;
}
