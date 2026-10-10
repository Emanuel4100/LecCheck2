import { Hono } from "hono";
import type { Env } from "./user-store";

/** Opt-in bug reports from the app (Settings → About → Report a problem).
 * Each becomes an issue in a private GitHub repository, so the developer
 * gets an email and nothing else has to be hosted. No sign-in is needed (the
 * app works without an account), so they're rate limited: a few per sender
 * a day, and a cap for everyone. */

export const MAX_REPORT_BYTES = 64 * 1024;
export const REPORTS_PER_SENDER = 5;
export const REPORTS_PER_DAY = 50;
export const DEFAULT_REPORTS_REPO = "Emanuel4100/LecCheck-reports";

export interface Report {
  appVersion: string;
  build: number | null;
  platform: string;
  os: string;
  device: string;
  locale: string;
  tz: string;
  description: string;
  diagnostics: string;
  contact: string;
}

function text(value: unknown, max: number): string {
  return typeof value === "string" ? value.trim().slice(0, max) : "";
}

/** Null unless [json] has at least a description. Every field is capped. */
export function parseReport(json: unknown): Report | null {
  if (typeof json !== "object" || json === null) return null;
  const o = json as Record<string, unknown>;
  const description = text(o.description, 5000);
  if (!description) return null;
  return {
    appVersion: text(o.appVersion, 40),
    build: typeof o.build === "number" && Number.isInteger(o.build) ? o.build : null,
    platform: text(o.platform, 20),
    os: text(o.os, 200),
    device: text(o.device, 200),
    locale: text(o.locale, 20),
    tz: text(o.tz, 60),
    description,
    diagnostics: text(o.diagnostics, 50_000),
    contact: text(o.contact, 200),
  };
}

/** The GitHub issue for [report]. */
export function issueFor(report: Report): { title: string; body: string } {
  const firstLine = report.description.split("\n")[0].slice(0, 80);
  const app = [
    `${report.appVersion || "?"}${report.build === null ? "" : ` (${report.build})`}`,
    report.platform,
    report.os,
    report.device,
    report.locale,
    report.tz,
  ]
    .filter(Boolean)
    .join(" · ");
  // Keep the code block closed whatever the log contains.
  const diagnostics = report.diagnostics.replaceAll("```", "ˋˋˋ");
  const body = [
    report.description,
    "",
    `**App:** ${app}`,
    `**Contact:** ${report.contact || "none"}`,
    ...(diagnostics
      ? ["", "<details><summary>Diagnostics</summary>", "", "```", diagnostics, "```", "</details>"]
      : []),
  ].join("\n");
  return { title: `[${report.platform || "?"} ${report.appVersion || "?"}] ${firstLine}`, body };
}

function github(token: string, path: string, init: RequestInit = {}): Promise<Response> {
  return fetch(`https://api.github.com${path}`, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      Accept: "application/vnd.github+json",
      "X-GitHub-Api-Version": "2022-11-28",
      "User-Agent": "leccheck-sync",
      ...(init.body ? { "content-type": "application/json" } : {}),
    },
  });
}

/** For the deep health check: whether reports can be filed. Not fatal. */
export async function reportsHealth(env: Env): Promise<"ok" | "not configured" | "token rejected"> {
  const token = env.REPORTS_GITHUB_TOKEN;
  if (!token) return "not configured";
  try {
    const res = await github(token, `/repos/${env.REPORTS_REPO ?? DEFAULT_REPORTS_REPO}`);
    return res.ok ? "ok" : "token rejected";
  } catch {
    return "token rejected";
  }
}

async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", new TextEncoder().encode(value));
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

/** The body as text, or null past [maxBytes] (also without a
 * `Content-Length`, e.g. chunked). */
async function readText(request: Request, maxBytes: number): Promise<string | null> {
  const reader = request.body?.getReader();
  if (!reader) return "";
  const chunks: Uint8Array[] = [];
  let size = 0;
  for (;;) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > maxBytes) {
      await reader.cancel();
      return null;
    }
    chunks.push(value);
  }
  const bytes = new Uint8Array(size);
  let at = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, at);
    at += chunk.byteLength;
  }
  return new TextDecoder().decode(bytes);
}

export const reports = new Hono<{ Bindings: Env }>();

reports.post("/", async (c) => {
  const token = c.env.REPORTS_GITHUB_TOKEN;
  if (!token) return c.json({ error: "reports_unavailable" }, 503);
  // Checked before reading, so a huge body is never held in memory.
  if (Number(c.req.header("content-length") ?? 0) > MAX_REPORT_BYTES * 3) {
    return c.json({ error: "too_large" }, 413);
  }
  const raw = await readText(c.req.raw, MAX_REPORT_BYTES * 3);
  if (raw === null || raw.length > MAX_REPORT_BYTES) return c.json({ error: "too_large" }, 413);
  let report: Report | null = null;
  try {
    report = parseReport(JSON.parse(raw));
  } catch {
    // Not JSON.
  }
  if (!report) return c.json({ error: "bad_report" }, 400);

  // Counted by a hash of the address, never the address itself.
  const sender = await sha256(`${c.req.header("CF-Connecting-IP") ?? "unknown"}`);
  const quota = c.env.USER_STORE.get(c.env.USER_STORE.idFromName("__reports__"));
  if (!(await quota.takeReportQuota(sender, REPORTS_PER_SENDER, REPORTS_PER_DAY))) {
    return c.json({ error: "rate_limited" }, 429);
  }

  const issue = issueFor(report);
  const res = await github(token, `/repos/${c.env.REPORTS_REPO ?? DEFAULT_REPORTS_REPO}/issues`, {
    method: "POST",
    body: JSON.stringify(issue),
  }).catch(() => null);
  if (!res?.ok) {
    console.error("report not filed", res?.status, await res?.text().catch(() => ""));
    // The app keeps the report and sends it again later.
    return c.json({ error: "unavailable", retryAt: Date.now() + 60 * 60 * 1000 }, 503);
  }
  return c.json({ ok: true }, 201);
});
