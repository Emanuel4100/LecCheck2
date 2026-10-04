import { describe, expect, it } from "vitest";
import { applyPatch } from "../src/merge";
import { validateChange } from "../src/protocol";

const clock = (ms: number, counter = 0, node = "node0001") =>
  `${String(ms).padStart(15, "0")}:${counter.toString(16).padStart(4, "0")}:${node}`;

describe("applyPatch (per-field last-writer-wins)", () => {
  const base = applyPatch(null, {
    tbl: "session_overrides",
    id: "m1_20261025",
    patch: { status: "attended", notes: "" },
    hlc: clock(1000),
  }).state;

  it("creates a row from its first patch", () => {
    expect(base.data).toEqual({ id: "m1_20261025", status: "attended", notes: "" });
  });

  it("takes newer fields and ignores older ones", () => {
    const newer = applyPatch(base, { tbl: "t", id: "m1_20261025", patch: { status: "missed" }, hlc: clock(2000) });
    expect(newer.state.data.status).toBe("missed");
    const older = applyPatch(newer.state, { tbl: "t", id: "m1_20261025", patch: { status: "watched" }, hlc: clock(1500) });
    expect(older.state.data.status).toBe("missed");
    expect(older.clockChanged).toBe(false);
  });

  it("merges concurrent edits of different fields", () => {
    const phone = applyPatch(base, { tbl: "t", id: "m1_20261025", patch: { status: "missed" }, hlc: clock(3000, 0, "phone001") });
    const laptop = applyPatch(phone.state, { tbl: "t", id: "m1_20261025", patch: { notes: "Ch. 4" }, hlc: clock(2500, 0, "laptop01") });
    expect(laptop.state.data).toMatchObject({ status: "missed", notes: "Ch. 4" });
  });

  it("a newer clock with the same value doesn't count as a data change", () => {
    const same = applyPatch(base, { tbl: "t", id: "m1_20261025", patch: { status: "attended" }, hlc: clock(4000) });
    expect(same.dataChanged).toBe(false);
    expect(same.clockChanged).toBe(true);
  });

  it("tombstones are just a field", () => {
    const deleted = applyPatch(base, { tbl: "t", id: "m1_20261025", patch: { deleted: true }, hlc: clock(5000) });
    expect(deleted.state.data.deleted).toBe(true);
  });
});

describe("validateChange", () => {
  const now = 1_759_570_000_000;
  const ok = { tbl: "courses", id: "c1", patch: { name: "Calculus" }, hlc: clock(now) };

  it("accepts a well-formed change", () => {
    expect(validateChange(ok, now).ok).toBe(true);
  });

  it.each([
    [{ ...ok, tbl: "users" }, "unknown_table"],
    [{ ...ok, id: "" }, "bad_id"],
    [{ ...ok, patch: [] }, "bad_patch"],
    [{ ...ok, hlc: "yesterday" }, "bad_clock"],
    [{ ...ok, hlc: clock(now + 10 * 60 * 1000) }, "clock_skew"],
    [{ ...ok, patch: { notes: "x".repeat(20_000) } }, "patch_too_large"],
  ])("rejects %j", (change, reason) => {
    expect(validateChange(change, now)).toEqual({ ok: false, reason });
  });
});
