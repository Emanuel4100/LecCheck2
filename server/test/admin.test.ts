import { env, runInDurableObject, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { DIRECTORY, normalEmail, type DirectoryView } from "../src/directory";

const base = "https://sync.test";
const adminHeaders = { Authorization: "Bearer test-admin-token", "content-type": "application/json" };

async function login(name: string) {
  const res = await SELF.fetch(`${base}/v1/auth/dev`, { method: "POST", body: JSON.stringify({ name }) });
  const body = (await res.json()) as { token?: string; error?: string };
  return { status: res.status, token: body.token ?? "", error: body.error };
}

async function sync(token: string, extra: Record<string, unknown> = {}) {
  const res = await SELF.fetch(`${base}/v1/sync`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify({ since: 0, changes: [], ...extra }),
  });
  return res.status;
}

async function users(): Promise<DirectoryView> {
  const res = await SELF.fetch(`${base}/v1/admin/users`, { headers: adminHeaders });
  expect(res.status).toBe(200);
  return res.json();
}

const setBeta = (on: boolean) =>
  SELF.fetch(`${base}/v1/admin/beta`, { method: "PUT", headers: adminHeaders, body: JSON.stringify({ on }) });
const allow = (email: string) =>
  SELF.fetch(`${base}/v1/admin/beta/allow`, { method: "POST", headers: adminHeaders, body: JSON.stringify({ email }) });
const remove = (email: string) =>
  SELF.fetch(`${base}/v1/admin/beta/allow/${encodeURIComponent(email)}`, { method: "DELETE", headers: adminHeaders });

const directory = () => env.USER_STORE.get(env.USER_STORE.idFromName(DIRECTORY));

describe("admin routes", () => {
  it("need the admin token", async () => {
    expect((await SELF.fetch(`${base}/v1/admin/users`)).status).toBe(401);
    const wrong = await SELF.fetch(`${base}/v1/admin/users`, { headers: { Authorization: "Bearer nope" } });
    expect(wrong.status).toBe(401);
  });
});

describe("beta whitelist", () => {
  it("is off at first: anyone signs in and is listed", async () => {
    expect((await login("early")).status).toBe(200);
    const view = await users();
    expect(view.betaSince).toBeNull();
    expect(view.users).toContainEqual(
      expect.objectContaining({ id: "dev:early", email: "early@dev.local", name: "early", allowed: false }),
    );
  });

  it("keeps existing accounts, refuses others and lets the owner add them", async () => {
    const early = await login("early2");
    expect((await setBeta(true)).status).toBe(200);
    const view = await users();
    expect(view.betaSince).toBeGreaterThan(0);
    expect(view.allowed.map((a) => a.email)).toContain("early2@dev.local");

    // Grandfathered: signs in again, keeps syncing.
    expect((await login("early2")).status).toBe(200);
    expect(await sync(early.token)).toBe(200);

    const refused = await login("stranger");
    expect(refused).toMatchObject({ status: 403, error: "not_invited" });
    expect((await users()).requests).toContainEqual(
      expect.objectContaining({ email: "stranger@dev.local", tries: 1 }),
    );

    expect((await allow("Stranger@Dev.Local ")).status).toBe(204);
    expect((await login("stranger")).status).toBe(200);
    expect((await users()).requests.map((r) => r.email)).not.toContain("stranger@dev.local");
    expect((await setBeta(false)).status).toBe(200);
  });

  it("removing someone signs out their devices", async () => {
    const { token } = await login("leaver");
    await setBeta(true);
    expect(await sync(token)).toBe(200);
    const res = await remove("leaver@dev.local");
    expect(await res.json()).toEqual({ signedOut: 1 });
    expect(await sync(token)).toBe(401);
    expect((await login("leaver")).status).toBe(403);
    expect((await remove("nobody@dev.local")).status).toBe(404);
    await setBeta(false);
  });

  it("adds accounts from before the directory on their first sync", async () => {
    const { token } = await login("veteran");
    // As if it had signed in before the directory existed.
    await runInDurableObject(directory(), async (_, state) => {
      state.storage.sql.exec("DELETE FROM dir_users WHERE sub = 'dev:veteran'");
    });
    await setBeta(true);
    expect(await sync(token, { platform: "linux", app: 42 })).toBe(200);
    await expect
      .poll(async () => (await users()).users.some((u) => u.id === "dev:veteran" && u.allowed))
      .toBe(true);
    await setBeta(false);
  });
});

describe("normalEmail", () => {
  it("ignores case and spaces, refuses non-emails", () => {
    expect(normalEmail("  A@B.c ")).toBe("a@b.c");
    expect(normalEmail("nope")).toBeNull();
    expect(normalEmail(42)).toBeNull();
  });
});
