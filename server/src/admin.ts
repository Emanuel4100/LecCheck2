import { Hono } from "hono";
import { DIRECTORY, type DirectoryOp, type DirectoryReply } from "./directory";
import type { Env } from "./user-store";

/**
 * The owner's routes: who has an account, and the beta whitelist.
 * Every call needs `Authorization: Bearer <ADMIN_TOKEN>`; without that secret
 * they don't exist (404). Each call is one Worker request and one Durable
 * Object request (plus one per account a removal signs out).
 *
 *   GET    /v1/admin/users               the directory (see DirectoryView)
 *   PUT    /v1/admin/beta {on}           turn the whitelist on or off
 *   POST   /v1/admin/beta/allow {email}  let someone in
 *   DELETE /v1/admin/beta/allow/:email   take them out and sign out their devices
 */
export const admin = new Hono<{ Bindings: Env }>();

const encoder = new TextEncoder();

/** Compares in constant time, so the token can't be guessed byte by byte. */
function sameToken(given: string, expected: string): boolean {
  const a = encoder.encode(given);
  const b = encoder.encode(expected);
  if (a.byteLength !== b.byteLength) return false;
  return crypto.subtle.timingSafeEqual(a, b);
}

admin.use("*", async (c, next) => {
  const token = c.env.ADMIN_TOKEN;
  if (!token) return c.notFound();
  const header = c.req.header("Authorization") ?? "";
  if (!header.startsWith("Bearer ") || !sameToken(header.slice(7), token)) {
    return c.text("Unauthorized", 401);
  }
  await next();
});

function directory(env: Env) {
  return env.USER_STORE.get(env.USER_STORE.idFromName(DIRECTORY));
}

async function run(env: Env, op: DirectoryOp): Promise<DirectoryReply> {
  return directory(env).directory(op);
}

function failed(reply: DirectoryReply): Response | null {
  if (reply.ok) return null;
  return Response.json({ error: reply.error }, { status: reply.error === "not_found" ? 404 : 400 });
}

admin.get("/users", async (c) => {
  const reply = await run(c.env, { op: "list" });
  return failed(reply) ?? c.json(reply.ok ? reply.view : null);
});

admin.put("/beta", async (c) => {
  const body = await c.req.json<{ on?: unknown }>().catch(() => null);
  if (typeof body?.on !== "boolean") return c.json({ error: "on must be true or false" }, 400);
  const reply = await run(c.env, { op: "setBeta", on: body.on });
  return failed(reply) ?? c.json(reply.ok ? reply.view : null);
});

admin.post("/beta/allow", async (c) => {
  const body = await c.req.json<{ email?: unknown }>().catch(() => null);
  const reply = await run(c.env, { op: "allow", email: String(body?.email ?? "") });
  return failed(reply) ?? c.body(null, 204);
});

admin.delete("/beta/allow/:email", async (c) => {
  const reply = await run(c.env, { op: "remove", email: c.req.param("email") });
  if (!reply.ok) return failed(reply)!;
  // Signs out every device of the accounts with that email.
  for (const sub of reply.revoke ?? []) {
    await c.env.USER_STORE.get(c.env.USER_STORE.idFromName(sub)).bumpEpoch();
  }
  return c.json({ signedOut: reply.revoke?.length ?? 0 });
});
