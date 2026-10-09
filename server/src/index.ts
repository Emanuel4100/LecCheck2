import { Hono } from "hono";
import { auth, issueSession, sessionFromRequest } from "./auth";
import { pages } from "./pages";
import { reports, reportsHealth } from "./reports";
import { appTooOld, PROTOCOL_VERSION, unavailable, unavailableResponse } from "./protocol";
import { UserStore, type Env } from "./user-store";

export { UserStore };

const app = new Hono<{ Bindings: Env }>();

app.route("/", pages);

app.route("/v1/auth", auth);

app.route("/v1/reports", reports);

function storeFor(env: Env, userId: string) {
  return env.USER_STORE.get(env.USER_STORE.idFromName(userId));
}

/** Which code is live, for deploy smoke tests and uptime checks. Touches no
 * storage, so it costs nothing on the free plan. */
app.get("/v1/health", (c) =>
  c.json({ ok: true, rev: c.env.SERVER_REV ?? "dev", protocol: PROTOCOL_VERSION }),
);

/** Checks the secrets and Durable Object storage (one write and one read in a
 * reserved object). Needs `HEALTH_TOKEN`, since each call writes a row. */
app.get("/v1/health/deep", async (c) => {
  const token = c.env.HEALTH_TOKEN;
  if (!token || c.req.header("Authorization") !== `Bearer ${token}`) {
    return c.text("Unauthorized", 401);
  }
  const checks = {
    jwtSecret: !!c.env.JWT_SECRET,
    googleClient: !!c.env.GOOGLE_CLIENT_ID && !!c.env.GOOGLE_CLIENT_SECRET,
    // POST /v1/auth/dev signs anyone in as anyone: never in production.
    devAuthOff: c.env.DEV_AUTH !== "1",
    storage: false,
  };
  try {
    const wrote = await storeFor(c.env, "__health__").probe();
    checks.storage = Math.abs(Date.now() - wrote) < 60_000;
  } catch (error) {
    console.error("health probe failed", error);
  }
  const ok = Object.values(checks).every(Boolean);
  // Reports matter less than sync: reported, but no reason to roll back.
  const warnings = { reports: await reportsHealth(c.env) };
  return c.json({ ok, rev: c.env.SERVER_REV ?? "dev", checks, warnings }, ok ? 200 : 503);
});

/** Live sync over a WebSocket, handled by the user's Durable Object. */
app.get("/v1/sync", async (c) => {
  const session = await sessionFromRequest(c.req.raw, c.env);
  if (!session) return c.text("Unauthorized", 401);
  if (c.req.header("Upgrade") !== "websocket") {
    return c.text("Expected a WebSocket", 426);
  }
  const headers = new Headers(c.req.raw.headers);
  headers.set("X-Session-Epoch", String(session.epoch));
  try {
    return await storeFor(c.env, session.sub).fetch(new Request(c.req.raw, { headers }));
  } catch (error) {
    // E.g. the free plan's daily Durable Object requests are used up.
    console.error("sync connect failed", error);
    return unavailableResponse(unavailable(error, Date.now()));
  }
});

/** Same exchange over plain HTTP (background tasks, WebSocket fallback). */
app.post("/v1/sync", async (c) => {
  const session = await sessionFromRequest(c.req.raw, c.env);
  if (!session) return c.text("Unauthorized", 401);
  const body = await c.req
    .json<{ since?: number; changes?: unknown[]; dataset?: unknown; app?: unknown }>()
    .catch(() => null);
  if (!body) return c.json({ error: "bad_json" }, 400);
  if (appTooOld(c.env.MIN_APP_BUILD, body.app)) {
    return c.json({ error: "upgrade_required" }, 426);
  }
  let result;
  try {
    result = await storeFor(c.env, session.sub).sync(
      session.epoch,
      Number(body.since) || 0,
      Array.isArray(body.changes) ? body.changes : [],
      typeof body.dataset === "string" ? body.dataset : null,
    );
  } catch (error) {
    console.error("sync failed", error);
    return unavailableResponse(unavailable(error, Date.now()));
  }
  if (!result) return c.text("Session revoked", 401);
  if ("retryAt" in result) return unavailableResponse(result);
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

/** Deletes the account's synced data (restorable for 30 days) and signs out
 * every device. */
app.delete("/v1/account", async (c) => {
  const session = await sessionFromRequest(c.req.raw, c.env);
  if (!session) return c.text("Unauthorized", 401);
  await storeFor(c.env, session.sub).deleteAccount();
  return c.body(null, 204);
});

/** Undoes "Delete cloud data" within 30 days. */
app.post("/v1/account/restore", async (c) => {
  const session = await sessionFromRequest(c.req.raw, c.env);
  if (!session) return c.text("Unauthorized", 401);
  const store = storeFor(c.env, session.sub);
  if (session.epoch !== (await store.epoch())) return c.text("Session revoked", 401);
  return c.json({ restored: await store.restoreDeleted() });
});

/** Rolls the account's cloud data back to a point in time (up to 30 days),
 * for recovering from a bad sync or import. Devices re-offer what they have,
 * so nothing they hold is lost. */
app.post("/v1/account/restore-to", async (c) => {
  const session = await sessionFromRequest(c.req.raw, c.env);
  if (!session) return c.text("Unauthorized", 401);
  const body = await c.req.json<{ at?: unknown }>().catch(() => null);
  const at = Number(body?.at);
  const now = Date.now();
  if (!Number.isFinite(at) || at > now || at < now - 30 * 24 * 60 * 60 * 1000) {
    return c.json({ error: "at must be within the last 30 days" }, 400);
  }
  const store = storeFor(c.env, session.sub);
  const epoch = await store.epoch();
  if (session.epoch !== epoch) return c.text("Session revoked", 401);
  const bookmark = await store.bookmarkFor(at);
  try {
    await store.restoreBookmark(bookmark);
  } catch {
    // The object aborts itself to load the restored state.
  }
  await storeFor(c.env, session.sub).afterRestore(epoch);
  return c.body(null, 204);
});

export default app;
