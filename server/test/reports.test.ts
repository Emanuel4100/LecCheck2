import { env, SELF } from "cloudflare:test";
import { afterEach, describe, expect, it, vi } from "vitest";
import {
  issueFor,
  MAX_REPORT_BYTES,
  parseReport,
  REPORTS_PER_SENDER,
  reports,
} from "../src/reports";

const report = {
  appVersion: "2.0.0-beta.5",
  build: 13,
  platform: "android",
  os: "Android 15 (SDK 35)",
  device: "samsung SM-S918B",
  locale: "he",
  tz: "Asia/Jerusalem",
  description: "Reminders don't come\nafter a restart",
  diagnostics: "Log:\n```nested```",
  contact: "",
};

/** The reports route with a token, as if it were configured. */
function send(body: unknown, ip = "203.0.113.1") {
  return reports.request(
    "/",
    {
      method: "POST",
      headers: { "content-type": "application/json", "CF-Connecting-IP": ip },
      body: typeof body === "string" ? body : JSON.stringify(body),
    },
    { ...env, REPORTS_GITHUB_TOKEN: "test-reports-token" },
  );
}

/** GitHub's answers, and what was sent to it. */
function github(status = 201) {
  const calls: { url: string; init: RequestInit }[] = [];
  vi.spyOn(globalThis, "fetch").mockImplementation(async (input, init) => {
    calls.push({ url: String(input), init: init ?? {} });
    return new Response(JSON.stringify({ number: 1 }), { status });
  });
  return calls;
}

afterEach(() => vi.restoreAllMocks());

describe("bug reports", () => {
  it("are off until a GitHub token is set", async () => {
    const res = await SELF.fetch("https://sync.test/v1/reports", {
      method: "POST",
      body: JSON.stringify(report),
    });
    expect(res.status).toBe(503);
    expect(await res.json()).toEqual({ error: "reports_unavailable" });
  });

  it("become an issue in the private repository", async () => {
    const calls = github();
    const res = await send(report);
    expect(res.status).toBe(201);
    expect(calls).toHaveLength(1);
    expect(calls[0].url).toBe("https://api.github.com/repos/Emanuel4100/LecCheck-reports/issues");
    expect((calls[0].init.headers as Record<string, string>).Authorization).toBe(
      "Bearer test-reports-token",
    );
    const issue = JSON.parse(String(calls[0].init.body));
    expect(issue.title).toBe("[android 2.0.0-beta.5] Reminders don't come");
    expect(issue.body).toContain("**App:** 2.0.0-beta.5 (13) · android · Android 15 (SDK 35)");
  });

  it("refuse what isn't a report", async () => {
    const calls = github();
    expect((await send("not json")).status).toBe(400);
    expect((await send({ ...report, description: "  " })).status).toBe(400);
    expect((await send({ ...report, diagnostics: "x".repeat(MAX_REPORT_BYTES) })).status).toBe(413);
    expect(calls).toHaveLength(0);
  });

  it("refuse huge bodies without reading them all", async () => {
    github();
    const res = await send("x".repeat(MAX_REPORT_BYTES * 3 + 1));
    expect(res.status).toBe(413);
  });

  it("are limited per sender and day", async () => {
    github();
    for (let i = 0; i < REPORTS_PER_SENDER; i++) {
      expect((await send(report, "198.51.100.7")).status).toBe(201);
    }
    const limited = await send(report, "198.51.100.7");
    expect(limited.status).toBe(429);
    // Someone else can still send one.
    expect((await send(report, "198.51.100.8")).status).toBe(201);
  });

  it("ask the app to try again when GitHub fails", async () => {
    github(502);
    const res = await send(report, "192.0.2.9");
    expect(res.status).toBe(503);
    const body = (await res.json()) as { error: string; retryAt: number };
    expect(body.error).toBe("unavailable");
    expect(body.retryAt).toBeGreaterThan(Date.now());
  });
});

describe("parseReport and issueFor", () => {
  it("caps every field and keeps the log's code block closed", () => {
    const parsed = parseReport({ ...report, os: "x".repeat(500), build: 1.5 })!;
    expect(parsed.os).toHaveLength(200);
    expect(parsed.build).toBeNull();
    const { body } = issueFor(parsed);
    expect(body.match(/```/g)).toHaveLength(2);
    expect(body).toContain("**Contact:** none");
  });
});
