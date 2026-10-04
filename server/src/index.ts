import { Hono } from "hono";
import { auth, issueSession, sessionFromRequest } from "./auth";
import { UserStore, type Env } from "./user-store";

export { UserStore };

const app = new Hono<{ Bindings: Env }>();

app.get("/", (c) => c.text("LecCheck sync server"));

app.route("/v1/auth", auth);

function storeFor(env: Env, userId: string) {
  return env.USER_STORE.get(env.USER_STORE.idFromName(userId));
}

/** Live sync over a WebSocket, handled by the user's Durable Object. */
app.get("/v1/sync", async (c) => {
  const session = await sessionFromRequest(c.req.raw, c.env);
  if (!session) return c.text("Unauthorized", 401);
  if (c.req.header("Upgrade") !== "websocket") {
    return c.text("Expected a WebSocket", 426);
  }
  const headers = new Headers(c.req.raw.headers);
  headers.set("X-Session-Epoch", String(session.epoch));
  return storeFor(c.env, session.sub).fetch(new Request(c.req.raw, { headers }));
});

/** Same exchange over plain HTTP (background tasks, WebSocket fallback). */
app.post("/v1/sync", async (c) => {
  const session = await sessionFromRequest(c.req.raw, c.env);
  if (!session) return c.text("Unauthorized", 401);
  const body = await c.req
    .json<{ since?: number; changes?: unknown[] }>()
    .catch(() => null);
  if (!body) return c.json({ error: "bad_json" }, 400);
  const result = await storeFor(c.env, session.sub).sync(
    session.epoch,
    Number(body.since) || 0,
    Array.isArray(body.changes) ? body.changes : [],
  );
  if (!result) return c.text("Session revoked", 401);
  return c.json(result);
});

/** Fresh token for an active session (the app renews before expiry). */
app.post("/v1/auth/renew", async (c) => {
  const session = await sessionFromRequest(c.req.raw, c.env);
  if (!session) return c.text("Unauthorized", 401);
  if (session.epoch !== (await storeFor(c.env, session.sub).epoch())) {
    return c.text("Session revoked", 401);
  }
  return c.json({ token: await issueSession(c.env, session.sub, session) });
});

app.post("/v1/auth/signout-everywhere", async (c) => {
  const session = await sessionFromRequest(c.req.raw, c.env);
  if (!session) return c.text("Unauthorized", 401);
  await storeFor(c.env, session.sub).bumpEpoch();
  return c.body(null, 204);
});

/** Deletes everything stored for the account. */
app.delete("/v1/account", async (c) => {
  const session = await sessionFromRequest(c.req.raw, c.env);
  if (!session) return c.text("Unauthorized", 401);
  await storeFor(c.env, session.sub).deleteAccount();
  return c.body(null, 204);
});

export default app;
