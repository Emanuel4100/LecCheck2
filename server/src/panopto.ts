import { Hono } from "hono";

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
export const panopto = new Hono();

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
