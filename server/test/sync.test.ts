import { env, SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";
import { isAllowedRedirect } from "../src/auth";
import { pkceChallenge, randomId, signToken } from "../src/jwt";

const base = "https://sync.test";
const clock = (offset = 0, counter = 0, node = "node0001") =>
  `${String(Date.now() + offset).padStart(15, "0")}:${counter.toString(16).padStart(4, "0")}:${node}`;

async function login(name: string): Promise<string> {
  const res = await SELF.fetch(`${base}/v1/auth/dev`, {
    method: "POST",
    body: JSON.stringify({ name }),
  });
  expect(res.status).toBe(200);
  return ((await res.json()) as { token: string }).token;
}

async function sync(token: string, since: number, changes: unknown[] = []) {
  const res = await SELF.fetch(`${base}/v1/sync`, {
    method: "POST",
    headers: { Authorization: `Bearer ${token}`, "content-type": "application/json" },
    body: JSON.stringify({ since, changes }),
  });
  return { status: res.status, body: res.status === 200 ? ((await res.json()) as any) : null };
}

describe("HTTP sync", () => {
  it("pushes from one device and pulls on another", async () => {
    const token = await login("alice");
    const pushed = await sync(token, 0, [
      { tbl: "courses", id: "c1", patch: { name: "Calculus", semesterId: "s1" }, hlc: clock() },
    ]);
    expect(pushed.body.rejected).toEqual([]);
    const pulled = await sync(token, 0);
    expect(pulled.body.rows).toEqual([
      expect.objectContaining({ tbl: "courses", id: "c1", data: { id: "c1", name: "Calculus", semesterId: "s1" } }),
    ]);
    expect(pulled.body.upto).toBeGreaterThan(0);
    expect((await sync(token, pulled.body.upto)).body.rows).toEqual([]);
  });

  it("merges concurrent field edits from two devices", async () => {
    const token = await login("bob");
    await sync(token, 0, [
      { tbl: "session_overrides", id: "m1_1", patch: { status: "attended" }, hlc: clock(-3000, 0, "phone001") },
    ]);
    await sync(token, 0, [
      { tbl: "session_overrides", id: "m1_1", patch: { notes: "Ch. 2" }, hlc: clock(-2000, 0, "laptop01") },
      { tbl: "session_overrides", id: "m1_1", patch: { status: "missed" }, hlc: clock(-4000, 0, "laptop01") },
    ]);
    const { body } = await sync(token, 0);
    expect(body.rows[0].data).toMatchObject({ status: "attended", notes: "Ch. 2" });
  });

  it("rejects unknown tables and clocks far in the future", async () => {
    const token = await login("carol");
    const { body } = await sync(token, 0, [
      { tbl: "users", id: "x", patch: { a: 1 }, hlc: clock() },
      { tbl: "courses", id: "c1", patch: { name: "x" }, hlc: clock(60 * 60 * 1000) },
    ]);
    expect(body.rejected.map((r: { reason: string }) => r.reason)).toEqual(["unknown_table", "clock_skew"]);
  });

  it("keeps users isolated", async () => {
    const a = await login("dana");
    const b = await login("erin");
    await sync(a, 0, [{ tbl: "courses", id: "secret", patch: { name: "Mine" }, hlc: clock() }]);
    expect((await sync(b, 0)).body.rows).toEqual([]);
  });

  it("pages large catch-ups", async () => {
    const token = await login("frank");
    for (let batch = 0; batch < 2; batch++) {
      const changes = Array.from({ length: 300 }, (_, i) => ({
        tbl: "session_overrides",
        id: `m_${batch}_${i}`,
        patch: { status: "attended" },
        hlc: clock(0, batch * 300 + i),
      }));
      await sync(token, 0, changes);
    }
    const first = await sync(token, 0);
    expect(first.body.rows).toHaveLength(500);
    expect(first.body.more).toBe(true);
    const second = await sync(token, first.body.upto);
    expect(second.body.rows).toHaveLength(100);
    expect(second.body.more).toBe(false);
  });

  it("requires a valid session, and sign-out-everywhere revokes it", async () => {
    expect((await sync("not-a-token", 0)).status).toBe(401);
    const token = await login("gina");
    expect((await sync(token, 0)).status).toBe(200);
    const out = await SELF.fetch(`${base}/v1/auth/signout-everywhere`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}` },
    });
    expect(out.status).toBe(204);
    expect((await sync(token, 0)).status).toBe(401);
    expect((await sync(await login("gina"), 0)).status).toBe(200);
  });
});

describe("auth", () => {
  it("only redirects back to the app scheme or loopback", () => {
    expect(isAllowedRedirect("leccheck://auth")).toBe(true);
    expect(isAllowedRedirect("http://localhost:43210/auth")).toBe(true);
    expect(isAllowedRedirect("http://127.0.0.1:5000/")).toBe(true);
    expect(isAllowedRedirect("https://evil.example/auth")).toBe(false);
    expect(isAllowedRedirect("http://localhost/auth")).toBe(false);
  });

  it("exchanges a one-time code with PKCE exactly once", async () => {
    const verifier = randomId(48);
    const code = await signToken(
      { typ: "code", sub: "g:123", cc: await pkceChallenge(verifier), jti: randomId(), name: "Hila" },
      env.JWT_SECRET,
      "2m",
    );
    const exchange = (v: string) =>
      SELF.fetch(`${base}/v1/auth/token`, {
        method: "POST",
        body: JSON.stringify({ code, code_verifier: v }),
      });
    expect((await exchange("wrong-verifier")).status).toBe(400);
    const ok = await exchange(verifier);
    expect(ok.status).toBe(200);
    const body = (await ok.json()) as { token: string; user: { id: string } };
    expect(body.user.id).toBe("g:123");
    expect((await sync(body.token, 0)).status).toBe(200);
    expect((await exchange(verifier)).status).toBe(400);
  });

  it("refuses to start sign-in without PKCE or with a foreign redirect", async () => {
    const challenge = await pkceChallenge(randomId(48));
    const start = (redirect: string, cc: string) =>
      SELF.fetch(
        `${base}/v1/auth/google/start?redirect_uri=${encodeURIComponent(redirect)}&state=s&code_challenge=${cc}`,
        { redirect: "manual" },
      );
    expect((await start("https://evil.example", challenge)).status).toBe(400);
    expect((await start("leccheck://auth", "short")).status).toBe(400);
    const ok = await start("leccheck://auth", challenge);
    expect(ok.status).toBe(302);
    expect(ok.headers.get("Location")).toContain("accounts.google.com");
  });
});

describe("WebSocket sync", () => {
  async function connect(token: string) {
    const res = await SELF.fetch(`${base}/v1/sync`, {
      headers: { Upgrade: "websocket", Authorization: `Bearer ${token}` },
    });
    expect(res.status).toBe(101);
    const ws = res.webSocket!;
    const inbox: any[] = [];
    const waiters: Array<() => void> = [];
    ws.addEventListener("message", (e: MessageEvent) => {
      inbox.push(JSON.parse(e.data as string));
      waiters.splice(0).forEach((w) => w());
    });
    ws.accept();
    const next = async (pred: (m: any) => boolean) => {
      for (let i = 0; i < 50; i++) {
        const idx = inbox.findIndex(pred);
        if (idx >= 0) return inbox.splice(idx, 1)[0];
        await new Promise<void>((r) => {
          waiters.push(r);
          setTimeout(r, 20);
        });
      }
      throw new Error("timed out waiting for message");
    };
    return { ws, next };
  }

  it("catches up on hello and broadcasts pushes to the other device", async () => {
    const token = await login("hana");
    await sync(token, 0, [{ tbl: "courses", id: "c0", patch: { name: "Existing" }, hlc: clock(-1000) }]);

    const phone = await connect(token);
    const laptop = await connect(token);
    phone.ws.send(JSON.stringify({ t: "hello", since: 0 }));
    const catchUp = await phone.next((m) => m.t === "changes");
    expect(catchUp.rows.map((r: any) => r.id)).toEqual(["c0"]);
    expect(catchUp.more).toBe(false);
    expect(catchUp.catchUp).toBe(true);

    phone.ws.send(
      JSON.stringify({
        t: "push",
        batchId: "b1",
        changes: [{ tbl: "courses", id: "c1", patch: { name: "Live" }, hlc: clock() }],
      }),
    );
    const ack = await phone.next((m) => m.t === "ack");
    expect(ack).toMatchObject({ batchId: "b1", rejected: [] });
    const live = await laptop.next((m) => m.t === "changes");
    expect(live.rows[0]).toMatchObject({ id: "c1", data: { name: "Live" } });

    phone.ws.close();
    laptop.ws.close();
  });
});
