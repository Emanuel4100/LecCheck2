import { Hono } from "hono";

// Public pages Google's OAuth consent screen links to (homepage + privacy policy).
// They live on the Worker so they share its domain with the OAuth redirect URI.

const REPO = "https://github.com/Emanuel4100/LecCheck2";
const CONTACT = "https://github.com/Emanuel4100/LecCheck2/issues";

function page(title: string, body: string): string {
  return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${title}</title>
<style>
  :root { color-scheme: light dark; --accent: #4f62d9; }
  body { font: 16px/1.6 system-ui, sans-serif; max-width: 42rem; margin: 0 auto;
         padding: 2rem 1rem; background: Canvas; color: CanvasText; }
  h1 { font-size: 1.8rem; margin-bottom: .25rem; }
  h2 { font-size: 1.15rem; margin-top: 2rem; }
  a { color: var(--accent); }
  .muted { opacity: .7; }
  nav { margin-top: 2.5rem; display: flex; gap: 1rem; }
</style>
</head>
<body>
${body}
<nav><a href="/">Home</a><a href="/privacy">Privacy policy</a><a href="${REPO}">Source code</a></nav>
</body>
</html>`;
}

const home = page(
  "LecCheck",
  `<h1>LecCheck</h1>
<p class="muted">Lecture and class attendance tracker for students</p>
<p>LecCheck shows your weekly class schedule, lets you mark each lecture, practice or lab as
attended, missed or watched as a recording, and tracks attendance requirements per course.
It works fully offline; signing in with Google is optional and only used to sync your
schedule between your own devices.</p>
<p>This address hosts the LecCheck sync server. The apps for Android, iPhone and Linux are
available from the <a href="${REPO}/releases">releases page</a>.</p>`,
);

const privacy = page(
  "LecCheck privacy policy",
  `<h1>Privacy policy</h1>
<p class="muted">Last updated: October 5, 2026</p>

<h2>Summary</h2>
<p>LecCheck works without an account, and then everything stays on your device. If you sign
in with Google, your schedule is stored on our sync server so your devices can share it.
We don't sell, share or analyze your data, and there are no ads or trackers.</p>

<h2>Data on your device</h2>
<p>Your semesters, courses, meeting times, attendance marks, notes and settings are stored in
a database on your device. Backups you export are files you control.</p>

<h2>Google sign-in</h2>
<p>When you sign in, Google tells us your Google account ID, name, email address and profile
picture (scopes <code>openid</code>, <code>email</code>, <code>profile</code>). We use the
account ID to keep your data separate from everyone else's. Your name, email and picture are
only shown in the app's account settings; the server does not store them in its database.
We don't receive your Google password or access to any other Google data.</p>

<h2>Synced data</h2>
<p>While signed in, the same schedule and attendance data that is on your device is stored on
our server (Cloudflare Workers and Durable Objects), in storage reserved for your account.
It is used only to sync your devices. It is sent over encrypted connections (HTTPS).
To protect against mistakes, Cloudflare keeps point-in-time copies of your storage for
30 days.</p>

<h2>Deleting your data</h2>
<p>In the app, <b>Settings → Account → Delete cloud data</b> removes your data from sync
immediately and signs out your devices. In case it was a mistake, the deleted data can be
restored for 30 days; after that it is erased permanently. Signing out lets you also remove
the copy on the device.
Uninstalling the app removes local data.</p>

<h2>Third parties</h2>
<p>Google (sign-in) and Cloudflare (hosting) process data as needed to provide those
services, under their own privacy policies. No other parties receive your data.</p>

<h2>Children</h2>
<p>LecCheck is meant for students and isn't directed at children under 13.</p>

<h2>Changes and contact</h2>
<p>Changes to this policy are published on this page. Questions or requests:
<a href="${CONTACT}">open an issue on GitHub</a>.</p>`,
);

export const pages = new Hono();

pages.get("/", (c) => c.html(home));
pages.get("/privacy", (c) => c.html(privacy));
