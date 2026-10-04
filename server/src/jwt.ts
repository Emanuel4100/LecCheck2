import { jwtVerify, SignJWT, type JWTPayload } from "jose";

const encoder = new TextEncoder();

export type TokenType = "session" | "code" | "state";

export interface SessionClaims extends JWTPayload {
  sub: string;
  typ: "session";
  epoch: number;
  name?: string;
  email?: string;
}

export interface CodeClaims extends JWTPayload {
  sub: string;
  typ: "code";
  /** PKCE challenge from the app: base64url(sha256(verifier)). */
  cc: string;
  jti: string;
  name?: string;
  email?: string;
  picture?: string;
}

export interface StateClaims extends JWTPayload {
  typ: "state";
  redirect: string;
  appState: string;
  cc: string;
  nonce: string;
}

export async function signToken(
  claims: JWTPayload & { typ: TokenType },
  secret: string,
  expiresIn: string,
): Promise<string> {
  return new SignJWT(claims)
    .setProtectedHeader({ alg: "HS256" })
    .setIssuedAt()
    .setExpirationTime(expiresIn)
    .sign(encoder.encode(secret));
}

export async function verifyToken<T extends JWTPayload>(
  token: string,
  secret: string,
  typ: TokenType,
): Promise<T | null> {
  try {
    const { payload } = await jwtVerify(token, encoder.encode(secret), {
      algorithms: ["HS256"],
    });
    return payload.typ === typ ? (payload as T) : null;
  } catch {
    return null;
  }
}

export async function pkceChallenge(verifier: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(verifier));
  return base64url(new Uint8Array(digest));
}

export function base64url(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) binary += String.fromCharCode(b);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function randomId(bytes = 16): string {
  return base64url(crypto.getRandomValues(new Uint8Array(bytes)));
}
