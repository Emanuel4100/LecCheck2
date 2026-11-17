import { env, runInDurableObject, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { LOOK_EVERY_MS } from "../src/panopto-vault";
import type { UserStore } from "../src/user-store";

const base = "https://sync.test";

async function login(name: string): Promise<string> {
  const res = await SELF.fetch(`${base}/v1/auth/dev`, {
    method: "POST",
    body: JSON.stringify({ name }),
  });
  expect(res.status).toBe(200);
  return ((await res.json()) as { token: string }).token;
}

function api(token: string) {
  return async (method: string, path: string, body?: unknown) => {
    const res = await SELF.fetch(`${base}/v1/panopto${path}`, {
      method,
      headers: { Authorization: `Bearer ${token}`, "content-type": "application/json" },
      body: body === undefined ? undefined : JSON.stringify(body),
    });
    const text = await res.text();
    const json = res.headers.get("content-type")?.includes("json");
    return { status: res.status, body: text && json ? (JSON.parse(text) as any) : text || null };
  };
}

/** The user's Durable Object, to move its clock-based fields back. */
function storeOf(token: string): DurableObjectStub<UserStore> {
  const sub = JSON.parse(atob(token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/"))).sub;
  return env.USER_STORE.get(env.USER_STORE.idFromName(sub));
}

const vault = (extra: Record<string, unknown> = {}) => ({
  kid: "kid1",
  nonce: "n1",
  ct: "ciphertext",
  device: "Pixel",
  ...extra,
});

describe("the Panopto vault", () => {
  it("is empty until a device saves one, then versioned", async () => {
    const call = api(await login("vault-a"));
    expect((await call("GET", "/vault")).body).toMatchObject({ vault: null, pairs: [] });

    expect((await call("PUT", "/vault", vault({ expect: 0 }))).body).toEqual({ v: 1 });
    const got = (await call("GET", "/vault")).body.vault;
    expect(got).toMatchObject({ v: 1, kid: "kid1", ct: "ciphertext", device: "Pixel", refused: false });

    // A device that read version 1 replaces it; a stale one can't.
    expect((await call("PUT", "/vault", vault({ expect: 1, ct: "c2" }))).body).toEqual({ v: 2 });
    const stale = await call("PUT", "/vault", vault({ expect: 1, ct: "old" }));
    expect(stale.status).toBe(409);
    expect(stale.body.vault).toMatchObject({ v: 2, ct: "c2" });
    // Creating again when one exists is a conflict too.
    expect((await call("PUT", "/vault", vault({ expect: 0 }))).status).toBe(409);
  });

  it("refuses bad input and other accounts' sessions", async () => {
    const call = api(await login("vault-b"));
    expect((await call("PUT", "/vault", { expect: 0, kid: "k" })).status).toBe(400);
    expect((await call("PUT", "/vault", vault({ expect: 0, ct: "x".repeat(9000) }))).status).toBe(400);
    expect((await SELF.fetch(`${base}/v1/panopto/vault`)).status).toBe(401);

    await call("PUT", "/vault", vault({ expect: 0 }));
    const other = api(await login("vault-b2"));
    expect((await other("GET", "/vault")).body.vault).toBeNull();
  });

  it("lets one device at a time refresh", async () => {
    const token = await login("vault-c");
    const call = api(token);
    expect((await call("POST", "/vault/lease", { owner: "phone" })).status).toBe(404);
    await call("PUT", "/vault", vault({ expect: 0 }));

    const leased = await call("POST", "/vault/lease", { owner: "phone" });
    expect(leased.status).toBe(200);
    expect(leased.body.vault.v).toBe(1);
    const busy = await call("POST", "/vault/lease", { owner: "laptop" });
    expect(busy.status).toBe(409);
    expect(busy.body.error).toBe("busy");
    // Nobody else writes while it's held, even with the right version.
    expect((await call("PUT", "/vault", vault({ expect: 1, owner: "laptop" }))).status).toBe(409);
    expect((await call("PUT", "/vault", vault({ expect: 1 }))).status).toBe(409);

    // The holder's save ends the lease.
    expect((await call("PUT", "/vault", vault({ expect: 1, owner: "phone", ct: "new" }))).status).toBe(200);
    expect((await call("POST", "/vault/lease", { owner: "laptop" })).status).toBe(200);
    // Releasing someone else's lease does nothing; one's own frees it.
    await call("POST", "/vault/release", { owner: "phone" });
    expect((await call("POST", "/vault/lease", { owner: "phone" })).status).toBe(409);
    await call("POST", "/vault/release", { owner: "laptop" });
    expect((await call("POST", "/vault/lease", { owner: "phone" })).status).toBe(200);
  });

  it("forgets a lease left by a device that stopped", async () => {
    const token = await login("vault-d");
    const call = api(token);
    await call("PUT", "/vault", vault({ expect: 0 }));
    await call("POST", "/vault/lease", { owner: "gone" });
    await runInDurableObject(storeOf(token), async (_, state) => {
      state.storage.sql.exec("UPDATE panopto_vault SET lease_until = ?", Date.now() - 1);
    });
    expect((await call("POST", "/vault/lease", { owner: "phone" })).status).toBe(200);
  });

  it("marks a refused sign-in only for the copy that was used", async () => {
    const call = api(await login("vault-e"));
    await call("PUT", "/vault", vault({ expect: 0 }));
    await call("PUT", "/vault", vault({ expect: 1 }));
    // A device refused with version 1's token: version 2 may still work.
    expect((await call("POST", "/vault/refused", { expect: 1 })).status).toBe(409);
    expect((await call("GET", "/vault")).body.vault.refused).toBe(false);
    expect((await call("POST", "/vault/refused", { expect: 2 })).status).toBe(204);
    expect((await call("GET", "/vault")).body.vault.refused).toBe(true);
    // Connecting again clears it.
    await call("PUT", "/vault", vault({ expect: 2 }));
    expect((await call("GET", "/vault")).body.vault.refused).toBe(false);
  });

  it("looks at most every 3 hours for the whole account, unless forced", async () => {
    const token = await login("vault-f");
    const call = api(token);
    await call("PUT", "/vault", vault({ expect: 0 }));
    expect((await call("POST", "/vault/look", {})).body.ok).toBe(true);
    expect((await call("POST", "/vault/look", {})).body.ok).toBe(false);
    expect((await call("POST", "/vault/look", { force: true })).body.ok).toBe(true);
    await runInDurableObject(storeOf(token), async (_, state) => {
      state.storage.sql.exec("UPDATE panopto_vault SET looked_at = ?", Date.now() - LOOK_EVERY_MS - 1);
    });
    expect((await call("POST", "/vault/look", {})).body.ok).toBe(true);
    // Saving the vault keeps the look time.
    const before = (await call("GET", "/vault")).body.vault.lookedAt;
    await call("PUT", "/vault", vault({ expect: 1 }));
    expect((await call("GET", "/vault")).body.vault.lookedAt).toBe(before);
  });

  it("is gone after Disconnect everywhere and after Delete cloud data", async () => {
    const token = await login("vault-g");
    const call = api(token);
    await call("PUT", "/vault", vault({ expect: 0 }));
    await call("POST", "/pairs", { device: "Laptop", commit: "c" });
    expect((await call("DELETE", "/vault")).status).toBe(204);
    expect((await call("GET", "/vault")).body).toMatchObject({ vault: null, pairs: [] });

    await call("PUT", "/vault", vault({ expect: 0 }));
    await SELF.fetch(`${base}/v1/account`, {
      method: "DELETE",
      headers: { Authorization: `Bearer ${token}` },
    });
    const again = api(await login("vault-g"));
    expect((await again("GET", "/vault")).body.vault).toBeNull();
  });

  it("refuses a session signed out everywhere", async () => {
    const token = await login("vault-h");
    await SELF.fetch(`${base}/v1/auth/signout-everywhere`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}` },
    });
    expect((await api(token)("GET", "/vault")).status).toBe(401);
  });
});

describe("pairing", () => {
  it("needs a vault, then relays each step once and in order", async () => {
    const call = api(await login("pair-a"));
    expect((await call("POST", "/pairs", { device: "Laptop", commit: "c" })).status).toBe(404);
    await call("PUT", "/vault", vault({ expect: 0 }));

    const { id, expiresAt } = (await call("POST", "/pairs", { device: "Laptop", commit: "c" })).body;
    expect(expiresAt).toBeGreaterThan(Date.now());
    expect((await call("GET", "/vault")).body.pairs).toEqual([
      expect.objectContaining({ id, device: "Laptop", commit: "c", aPub: null }),
    ]);

    // B can't reveal before A answered; A can't wrap before B revealed.
    expect((await call("PATCH", `/pairs/${id}`, { bPub: "b", nonce: "n" })).status).toBe(409);
    expect((await call("PATCH", `/pairs/${id}`, { aPub: "a" })).status).toBe(204);
    expect((await call("PATCH", `/pairs/${id}`, { aPub: "evil" })).status).toBe(409);
    expect((await call("PATCH", `/pairs/${id}`, { wrapped: "w", kid: "kid1" })).status).toBe(409);
    expect((await call("PATCH", `/pairs/${id}`, { bPub: "b", nonce: "n" })).status).toBe(204);
    expect((await call("PATCH", `/pairs/${id}`, { wrapped: "w", kid: "kid1" })).status).toBe(204);
    expect((await call("PATCH", `/pairs/${id}`, { wrapped: "w2", kid: "kid1" })).status).toBe(409);
    expect((await call("GET", `/pairs/${id}`)).body).toMatchObject({
      aPub: "a",
      bPub: "b",
      nonce: "n",
      wrapped: "w",
      kid: "kid1",
      denied: false,
    });
    expect((await call("DELETE", `/pairs/${id}`)).status).toBe(204);
    expect((await call("GET", `/pairs/${id}`)).status).toBe(404);
  });

  it("can be denied, expires, and is capped", async () => {
    const token = await login("pair-b");
    const call = api(token);
    await call("PUT", "/vault", vault({ expect: 0 }));
    const { id } = (await call("POST", "/pairs", { device: "Laptop", commit: "c" })).body;
    await call("PATCH", `/pairs/${id}`, { denied: true });
    expect((await call("GET", `/pairs/${id}`)).body.denied).toBe(true);

    for (let i = 0; i < 4; i++) await call("POST", "/pairs", { device: `D${i}`, commit: "c" });
    expect((await call("POST", "/pairs", { device: "Too many", commit: "c" })).status).toBe(429);

    await runInDurableObject(storeOf(token), async (_, state) => {
      state.storage.sql.exec("UPDATE panopto_pairs SET expires_at = ?", Date.now() - 1);
    });
    expect((await call("GET", "/vault")).body.pairs).toEqual([]);
  });

  it("drops open requests when the vault gets a new key", async () => {
    const call = api(await login("pair-c"));
    await call("PUT", "/vault", vault({ expect: 0 }));
    await call("POST", "/pairs", { device: "Laptop", commit: "c" });
    await call("PUT", "/vault", vault({ expect: 1 }));
    expect((await call("GET", "/vault")).body.pairs).toHaveLength(1);
    await call("PUT", "/vault", vault({ expect: 2, kid: "kid2" }));
    expect((await call("GET", "/vault")).body.pairs).toEqual([]);
  });

  it("tells connected devices to read again", async () => {
    const token = await login("pair-d");
    const res = await SELF.fetch(`${base}/v1/sync`, {
      headers: { Upgrade: "websocket", Authorization: `Bearer ${token}` },
    });
    const ws = res.webSocket!;
    const inbox: any[] = [];
    ws.addEventListener("message", (e: MessageEvent) => {
      inbox.push(JSON.parse(e.data as string));
    });
    ws.accept();
    await api(token)("PUT", "/vault", vault({ expect: 0 }));
    for (let i = 0; i < 50 && inbox.length === 0; i++) await new Promise((r) => setTimeout(r, 20));
    expect(inbox).toEqual([{ t: "panopto" }]);
    ws.close();
  });
});
