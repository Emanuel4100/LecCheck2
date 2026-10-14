#!/usr/bin/env python3
"""Updates update.json, the file the Android and Linux apps check for new releases.

    python3 scripts/update_manifest.py <existing-or-missing.json> <release> <build> <repo-url> [<assets-dir>] > update.json

<release> is the tag without the "v" (e.g. 2.0.0-beta.5), <build> the pubspec build number.
<assets-dir> holds the release files: their SHA-256 hashes go in "sha256", and the apps only
install a file themselves (Update) when it has one; otherwise Download opens the browser.
The release's section of CHANGELOG.md goes in "notes", for the app's update window.
The release workflow then signs the file (update.json.sig): the apps ignore an unsigned one.
A pre-release (a "-" in <release>) updates the "beta" channel; a stable release updates
"stable" and "beta" (people on betas get stable releases too). Published next to the
AltStore source on the altstore branch:
https://raw.githubusercontent.com/Emanuel4100/LecCheck2/altstore/update.json
"""
import datetime
import hashlib
import json
import os
import re
import sys


def changelog_notes(release):
    """The body of the "## <release> — <date>" section of CHANGELOG.md."""
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "CHANGELOG.md")
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        return ""
    match = re.search(
        rf"^## {re.escape(release)}\b[^\n]*\n(.*?)(?=^## |\Z)", text, re.M | re.S
    )
    return match.group(1).strip() if match else ""


existing, release, build, repo = sys.argv[1:5]
assets = sys.argv[5] if len(sys.argv) > 5 else None
download = f"{repo}/releases/download/v{release}"
files = {
    "androidArm64": f"LecCheck-{release}-android-arm64.apk",
    "androidUniversal": f"LecCheck-{release}-android.apk",
    "linux": f"LecCheck-{release}-linux-x64.tar.gz",
}
entry = {
    "version": release,
    "build": int(build),
    "date": datetime.date.today().isoformat(),
    "notesUrl": f"{repo}/releases/tag/v{release}",
    "notes": changelog_notes(release),
    **{key: f"{download}/{name}" for key, name in files.items()},
}
if assets:
    sha256 = {}
    for key, name in files.items():
        with open(os.path.join(assets, name), "rb") as f:
            sha256[key] = hashlib.file_digest(f, "sha256").hexdigest()
    entry["sha256"] = sha256

manifest = {}
if os.path.exists(existing):
    with open(existing, encoding="utf-8") as f:
        manifest = json.load(f)
manifest["beta"] = entry
if "-" not in release:
    manifest["stable"] = entry
json.dump(manifest, sys.stdout, indent=2)
print()
