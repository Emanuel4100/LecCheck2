import { Hono, type Context } from "hono";
import { sessionFromRequest } from "./auth";
import type { PanoptoOp, PanoptoReply } from "./panopto-vault";
import { unavailable, unavailableResponse } from "./protocol";
import type { Env } from "./user-store";

/** The app's loopback port for desktop sign-in (as for Google sign-in). */
export const DESKTOP_PORT = 43823;

/**
 * Panopto recordings (an experimental app feature, run on the user's devices).
 *
 * Panopto's API clients take one exact redirect address, so every user puts
 * this page's address in the client they create. Panopto's sign-in comes back
 * here and the browser is sent on to the app: `state` ending in `.d` means a
 * desktop app listening on localhost, anything else the app's own scheme.
 * Only the browser passes through: the one-time code is useless without the
 * user's client secret and the app's PKCE verifier, and nothing is stored.
 */
export const panopto = new Hono<{ Bindings: Env }>();

panopto.get("/done", (c) => {
  const url = new URL(c.req.url);
  const state = url.searchParams.get("state") ?? "";
  const target = state.endsWith(".d")
    ? `http://localhost:${DESKTOP_PORT}/panopto`
    : "leccheck://panopto";
  c.header("Cache-Control", "no-store");
  c.header("Referrer-Policy", "no-referrer");
  return c.redirect(`${target}${url.search}`, 302);
});

// The vault and pairing (panopto-vault.ts). Each call is one request to the
// user's Durable Object, which checks the session's epoch itself.

type Ctx = Context<{ Bindings: Env }>;

async function run(c: Ctx, op: PanoptoOp): Promise<Response> {
  const session = await sessionFromRequest(c.req.raw, c.env);
  if (!session) return c.text("Unauthorized", 401);
  const store = c.env.USER_STORE.get(c.env.USER_STORE.idFromName(session.sub));
  let reply: PanoptoReply | null;
  try {
    // The RPC type can't carry `unknown` bodies.
    reply = (await store.panopto(session.epoch, op)) as PanoptoReply | null;
  } catch (error) {
    console.error("panopto vault failed", error);
    return unavailableResponse(unavailable(error, Date.now()));
  }
  if (!reply) return c.text("Session revoked", 401);
  c.header("Cache-Control", "no-store");
  if (reply.status === 204) return c.body(null, 204);
  return c.json(reply.body as object, reply.status as 200);
}

async function body(c: Ctx): Promise<Record<string, unknown>> {
  const json = await c.req.json<unknown>().catch(() => null);
  return json !== null && typeof json === "object" && !Array.isArray(json)
    ? (json as Record<string, unknown>)
    : {};
}

const str = (x: unknown) => (typeof x === "string" ? x : "");

panopto.get("/vault", (c) => run(c, { op: "get" }));

panopto.put("/vault", async (c) => {
  const b = await body(c);
  return run(c, {
    op: "put",
    expect: Number(b.expect),
    owner: typeof b.owner === "string" ? b.owner : undefined,
    kid: str(b.kid),
    nonce: str(b.nonce),
    ct: str(b.ct),
    device: str(b.device),
    refused: b.refused === true,
  });
});

panopto.delete("/vault", (c) => run(c, { op: "delete" }));

panopto.post("/vault/lease", async (c) => run(c, { op: "lease", owner: str((await body(c)).owner) }));

panopto.post("/vault/release", async (c) =>
  run(c, { op: "release", owner: str((await body(c)).owner) }),
);

panopto.post("/vault/refused", async (c) =>
  run(c, { op: "refused", expect: Number((await body(c)).expect) }),
);

panopto.post("/vault/look", async (c) => run(c, { op: "look", force: (await body(c)).force === true }));

panopto.post("/pairs", async (c) => {
  const b = await body(c);
  return run(c, { op: "pair", device: str(b.device), commit: str(b.commit) });
});

panopto.get("/pairs/:id", (c) => run(c, { op: "pairGet", id: c.req.param("id") }));

panopto.patch("/pairs/:id", async (c) =>
  run(c, { op: "pairSet", id: c.req.param("id"), fields: await body(c) }),
);

panopto.delete("/pairs/:id", (c) => run(c, { op: "pairDelete", id: c.req.param("id") }));
