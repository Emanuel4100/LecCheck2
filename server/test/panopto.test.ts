import { SELF } from "cloudflare:test";
import { describe, expect, it } from "vitest";

async function done(query: string) {
  return SELF.fetch(`https://sync.test/v1/panopto/done?${query}`, {
    redirect: "manual",
  });
}

describe("Panopto's sign-in page", () => {
  it("sends phones on to the app's scheme with everything Panopto sent", async () => {
    const res = await done("code=abc&scope=openid%20api&state=xyz.m&session_state=s1");
    expect(res.status).toBe(302);
    expect(res.headers.get("Location")).toBe(
      "leccheck://panopto?code=abc&scope=openid%20api&state=xyz.m&session_state=s1",
    );
    expect(res.headers.get("Cache-Control")).toBe("no-store");
  });

  it("sends desktops to their loopback port", async () => {
    const res = await done("code=abc&state=xyz.d");
    expect(res.headers.get("Location")).toBe(
      "http://localhost:43823/panopto?code=abc&state=xyz.d",
    );
  });

  it("passes refusals on, and never anywhere else", async () => {
    const res = await done("error=access_denied&state=https://evil.example");
    expect(res.headers.get("Location")).toBe(
      "leccheck://panopto?error=access_denied&state=https://evil.example",
    );
  });
});
