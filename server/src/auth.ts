import { Hono } from "hono";
import { createRemoteJWKSet, jwtVerify } from "jose";
import {
  pkceChallenge,
  randomId,
  signToken,
  verifyToken,
  type CodeClaims,
  type SessionClaims,
  type StateClaims,
} from "./jwt";
import type { Env } from "./user-store";

const GOOGLE_AUTHORIZE = "https://accounts.google.com/o/oauth2/v2/auth";
const GOOGLE_TOKEN = "https://oauth2.googleapis.com/token";
const GOOGLE_JWKS = createRemoteJWKSet(
  new URL("https://www.googleapis.com/oauth2/v3/certs"),
);

export const SESSION_TTL = "60d";

/**
 * Where the browser may be sent back after sign-in: the app's custom scheme
 * (Android/iOS) or a loopback port (desktop). Anything else is refused, so a
 * sign-in can't be redirected to a third-party site.
 */
export function isAllowedRedirect(uri: string): boolean {
  if (uri.startsWith("leccheck://auth")) return true;
  try {
    const url = new URL(uri);
    return (
      url.protocol === "http:" &&
      (url.hostname === "localhost" || url.hostname === "127.0.0.1") &&
      url.port !== ""
    );
  } catch {
    return false;
  }
}

export async function issueSession(
  env: Env,
  sub: string,
  profile: { name?: string; email?: string },
): Promise<string> {
  const store = env.USER_STORE.get(env.USER_STORE.idFromName(sub));
  const epoch = await store.epoch();
  return signToken(
    { sub, typ: "session", epoch, name: profile.name, email: profile.email },
    env.JWT_SECRET,
    SESSION_TTL,
  );
}

export const auth = new Hono<{ Bindings: Env }>();

/** Step 1: the app opens this in a browser with its PKCE challenge. */
auth.get("/google/start", async (c) => {
  const redirect = c.req.query("redirect_uri") ?? "";
  const appState = c.req.query("state") ?? "";
  const challenge = c.req.query("code_challenge") ?? "";
  if (!isAllowedRedirect(redirect)) return c.text("Redirect not allowed", 400);
  if (!/^[A-Za-z0-9_-]{43,128}$/.test(challenge)) {
    return c.text("Missing PKCE challenge", 400);
  }
  if (!c.env.GOOGLE_CLIENT_ID) return c.text("Google sign-in not configured", 503);

  const nonce = randomId();
  const state = await signToken(
    { typ: "state", redirect, appState, cc: challenge, nonce } satisfies StateClaims,
    c.env.JWT_SECRET,
    "10m",
  );
  const url = new URL(GOOGLE_AUTHORIZE);
  url.search = new URLSearchParams({
    client_id: c.env.GOOGLE_CLIENT_ID,
    redirect_uri: new URL("/v1/auth/google/callback", c.req.url).toString(),
    response_type: "code",
    scope: "openid email profile",
    state,
    nonce,
    prompt: "select_account",
  }).toString();
  return c.redirect(url.toString(), 302);
});

/** Step 2: Google returns here; we verify the user and hand the app a
 * short-lived one-time code (never a session token in a URL). */
auth.get("/google/callback", async (c) => {
  const state = await verifyToken<StateClaims>(
    c.req.query("state") ?? "",
    c.env.JWT_SECRET,
    "state",
  );
  if (!state) return c.text("Sign-in expired, please try again", 400);
  const back = new URL(state.redirect);
  back.searchParams.set("state", state.appState);
  const error = c.req.query("error");
  if (error) {
    back.searchParams.set("error", error);
    return c.redirect(back.toString(), 302);
  }

  const response = await fetch(GOOGLE_TOKEN, {
    method: "POST",
    headers: { "content-type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      code: c.req.query("code") ?? "",
      client_id: c.env.GOOGLE_CLIENT_ID ?? "",
      client_secret: c.env.GOOGLE_CLIENT_SECRET ?? "",
      redirect_uri: new URL("/v1/auth/google/callback", c.req.url).toString(),
      grant_type: "authorization_code",
    }),
  });
  if (!response.ok) return c.text("Google sign-in failed", 502);
  const tokens = (await response.json()) as { id_token?: string };

  let profile: { sub: string; email?: string; name?: string; picture?: string };
  try {
    const { payload } = await jwtVerify(tokens.id_token ?? "", GOOGLE_JWKS, {
      audience: c.env.GOOGLE_CLIENT_ID,
      issuer: ["https://accounts.google.com", "accounts.google.com"],
    });
    if (payload.nonce !== state.nonce || payload.email_verified === false) {
      return c.text("Google sign-in failed", 401);
    }
    profile = payload as typeof profile;
  } catch {
    return c.text("Google sign-in failed", 401);
  }

  const code = await signToken(
    {
      typ: "code",
      sub: `g:${profile.sub}`,
      cc: state.cc,
      jti: randomId(),
      name: profile.name,
      email: profile.email,
      picture: profile.picture,
    } satisfies CodeClaims,
    c.env.JWT_SECRET,
    "2m",
  );
  back.searchParams.set("code", code);
  return c.redirect(back.toString(), 302);
});

/** Step 3: the app proves it started the flow (PKCE) and gets a session. */
auth.post("/token", async (c) => {
  const body = await c.req.json<{ code?: string; code_verifier?: string }>().catch(() => ({}));
  const claims = await verifyToken<CodeClaims>(
    (body as { code?: string }).code ?? "",
    c.env.JWT_SECRET,
    "code",
  );
  const verifier = (body as { code_verifier?: string }).code_verifier ?? "";
  if (!claims || (await pkceChallenge(verifier)) !== claims.cc) {
    return c.json({ error: "invalid_code" }, 400);
  }
  const store = c.env.USER_STORE.get(c.env.USER_STORE.idFromName(claims.sub));
  if (!(await store.consumeCode(claims.jti, claims.exp ?? 0))) {
    return c.json({ error: "code_used" }, 400);
  }
  const token = await issueSession(c.env, claims.sub, claims);
  return c.json({
    token,
    user: { id: claims.sub, name: claims.name, email: claims.email, picture: claims.picture },
  });
});

/** Local development only (DEV_AUTH=1): sign in as a named test user. */
auth.post("/dev", async (c) => {
  if (c.env.DEV_AUTH !== "1") return c.notFound();
  const { name = "tester" } = await c.req.json<{ name?: string }>().catch(() => ({ name: "tester" }));
  const sub = `dev:${name}`;
  const token = await issueSession(c.env, sub, { name, email: `${name}@dev.local` });
  return c.json({ token, user: { id: sub, name, email: `${name}@dev.local` } });
});

/** The signed session in the `Authorization` header (never the URL, which
 * can end up in logs). Doesn't check revocation: see [activeSession]. */
export async function sessionFromRequest(
  request: Request,
  env: Env,
): Promise<SessionClaims | null> {
  const header = request.headers.get("Authorization") ?? "";
  if (!header.startsWith("Bearer ")) return null;
  return verifyToken<SessionClaims>(header.slice(7), env.JWT_SECRET, "session");
}

/** [sessionFromRequest], and not revoked since ("sign out everywhere",
 * "Delete cloud data"). Costs one request to the user's Durable Object. */
export async function activeSession(
  request: Request,
  env: Env,
): Promise<SessionClaims | null> {
  const session = await sessionFromRequest(request, env);
  if (!session) return null;
  const store = env.USER_STORE.get(env.USER_STORE.idFromName(session.sub));
  return session.epoch === (await store.epoch()) ? session : null;
}
