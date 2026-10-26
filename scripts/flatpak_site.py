#!/usr/bin/env python3
"""Builds the GitHub Pages site that serves LecCheck's Flatpak repository:

    python3 scripts/flatpak_site.py <repo-dir> <out-dir> <public-key.asc> <base-url>

<repo-dir> is the GPG-signed OSTree repository the release workflow built. <out-dir> gets:
- repo/: that repository,
- leccheck.flatpakref: installs LecCheck and adds the repository as the remote "leccheck"
  (its runtime comes from Flathub, which is added if needed),
- leccheck.flatpakrepo: adds the repository only,
- index.html: how to install, update and remove it,
- the screenshots the metainfo links to, and the icon.
<public-key.asc> is the repository's public key, ASCII-armored
(app/linux/flatpak/leccheck-repo.asc); <base-url> where the site is served, e.g.
https://emanuel4100.github.io/LecCheck2.
"""
import html
import os
import shutil
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
HOMEPAGE = "https://github.com/Emanuel4100/LecCheck2"
SCREENSHOTS = {"today": "desktop_today", "week": "desktop_week", "stats": "desktop_stats"}


def key_base64(armored):
    """The armored key's base64 body (the binary key, as Flatpak's GPGKey= wants it)."""
    lines = armored.strip().splitlines()
    body, started = [], False
    for line in lines[1:]:
        if not started:
            # Armor headers end at the first empty line.
            started = line.strip() == ""
            continue
        if line.startswith("=") or line.startswith("-----END"):
            break
        body.append(line.strip())
    if not body:
        sys.exit("No key in the armored file")
    return "".join(body)


def fingerprint(armored):
    """The fingerprint, from the "# fingerprint: …" comment the key file starts with."""
    for line in armored.splitlines():
        if line.startswith("# fingerprint:"):
            return line.split(":", 1)[1].strip()
    return ""


def page(base, fpr):
    ref = f"{base}/leccheck.flatpakref"
    command = html.escape(f"flatpak install --user {ref}")
    return f"""<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>LecCheck for Linux</title>
<link rel="icon" href="icon.png">
<style>
:root {{ color-scheme: light dark; --bg: #f7f8fc; --fg: #1a1c22; --muted: #5a5f6e;
  --box: #e4e7f2; --accent: #3a5a8c; }}
@media (prefers-color-scheme: dark) {{ :root {{ --bg: #111318; --fg: #e3e4ec;
  --muted: #a6aabb; --box: #23262f; --accent: #a8c4ff; }} }}
body {{ margin: 0; background: var(--bg); color: var(--fg);
  font: 16px/1.55 system-ui, sans-serif; }}
main {{ max-width: 720px; margin: 0 auto; padding: 32px 16px 64px; }}
header {{ display: flex; gap: 16px; align-items: center; }}
h1 {{ margin: 0; font-size: 28px; }}
h2 {{ margin-top: 32px; font-size: 19px; }}
p, li {{ color: var(--muted); }}
code, pre {{ font-family: ui-monospace, monospace; font-size: 14px; }}
pre {{ background: var(--box); border-radius: 10px; padding: 12px 14px;
  overflow-x: auto; color: var(--fg); }}
a {{ color: var(--accent); }}
.button {{ display: inline-block; margin: 8px 0; padding: 10px 20px; border-radius: 999px;
  background: var(--accent); color: var(--bg); text-decoration: none; font-weight: 600; }}
img.shot {{ width: 100%; border-radius: 12px; margin-top: 16px; }}
</style>
</head>
<body>
<main>
<header>
  <img src="icon.png" width="64" height="64" alt="">
  <div>
    <h1>LecCheck for Linux</h1>
    <p style="margin:0">Track the lectures, practices and labs you attend.</p>
  </div>
</header>

<h2>Install</h2>
<p>LecCheck comes as a Flatpak from its own repository, signed with its own key.
In a terminal:</p>
<pre>{command}</pre>
<p>Or open <a class="button" href="leccheck.flatpakref">leccheck.flatpakref</a> with your
software center (GNOME Software, KDE Discover). No Flatpak yet?
<a href="https://flatpak.org/setup/">Set it up first</a>.</p>
<p>Then start LecCheck from your app launcher, or with
<code>flatpak run com.leccheck.app</code>.</p>

<h2>Updates</h2>
<p>LecCheck tells you when there's a new version and installs it itself: the first time,
your desktop asks whether it may. <code>flatpak update</code> and software centers update
it too.</p>

<h2>Installed with install.sh before?</h2>
<p>Update it from inside the app once more, then choose <strong>Move to the Flatpak</strong>.
Signed in, you sign in again in the Flatpak and your data comes back; otherwise save a
backup there and import it in the Flatpak.</p>

<h2>Remove</h2>
<pre>flatpak uninstall com.leccheck.app</pre>
<p>Your data stays in <code>~/.var/app/com.leccheck.app</code>;
<code>flatpak uninstall --delete-data com.leccheck.app</code> removes it too.</p>

<h2>About this repository</h2>
<p>Its key's fingerprint: <code>{html.escape(fpr)}</code>. The source and every release
are on <a href="{HOMEPAGE}">GitHub</a>.</p>

<img class="shot" src="screenshots/week.png" alt="LecCheck's Week view">
</main>
</body>
</html>
"""


def main():
    if len(sys.argv) != 5:
        sys.exit(__doc__)
    repo, out, key_file, base = sys.argv[1:5]
    base = base.rstrip("/")
    with open(key_file, encoding="utf-8") as f:
        armored = f.read()
    key = key_base64(armored)
    if os.path.exists(out):
        shutil.rmtree(out)
    shutil.copytree(repo, os.path.join(out, "repo"), symlinks=True)
    common = (
        "Title=LecCheck\n"
        f"Url={base}/repo/\n"
        f"Homepage={HOMEPAGE}\n"
        f"Icon={base}/icon.png\n"
    )
    with open(os.path.join(out, "leccheck.flatpakref"), "w", encoding="utf-8") as f:
        f.write(
            "[Flatpak Ref]\n"
            "Name=com.leccheck.app\n"
            "Branch=stable\n"
            f"{common}"
            "SuggestRemoteName=leccheck\n"
            "RuntimeRepo=https://dl.flathub.org/repo/flathub.flatpakrepo\n"
            "IsRuntime=false\n"
            f"GPGKey={key}\n"
        )
    with open(os.path.join(out, "leccheck.flatpakrepo"), "w", encoding="utf-8") as f:
        f.write(
            "[Flatpak Repo]\n"
            f"{common}"
            "Comment=Track the lectures, practices and labs you attend\n"
            "Description=LecCheck's own Flatpak repository\n"
            f"GPGKey={key}\n"
        )
    with open(os.path.join(out, "index.html"), "w", encoding="utf-8") as f:
        f.write(page(base, fingerprint(armored)))
    shots = os.path.join(out, "screenshots")
    os.makedirs(shots)
    goldens = os.path.join(ROOT, "app/test_screenshots/goldens")
    for name, golden in SCREENSHOTS.items():
        shutil.copy(os.path.join(goldens, f"{golden}.png"), os.path.join(shots, f"{name}.png"))
    shutil.copy(
        os.path.join(ROOT, "app/linux/assets/com.leccheck.app-128.png"),
        os.path.join(out, "icon.png"),
    )
    # Served as they are: no Jekyll.
    open(os.path.join(out, ".nojekyll"), "w").close()


if __name__ == "__main__":
    main()
