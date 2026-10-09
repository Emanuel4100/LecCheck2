#!/usr/bin/env python3
"""Updates update.json, the file the Android and Linux apps check for new releases.

    python3 scripts/update_manifest.py <existing-or-missing.json> <release> <build> <repo-url> > update.json

<release> is the tag without the "v" (e.g. 2.0.0-beta.5), <build> the pubspec build number.
A pre-release (a "-" in <release>) updates the "beta" channel; a stable release updates
"stable" and "beta" (people on betas get stable releases too). Published next to the
AltStore source on the altstore branch:
https://raw.githubusercontent.com/Emanuel4100/LecCheck2/altstore/update.json
"""
import datetime
import json
import os
import sys

existing, release, build, repo = sys.argv[1:5]
download = f"{repo}/releases/download/v{release}"
entry = {
    "version": release,
    "build": int(build),
    "date": datetime.date.today().isoformat(),
    "notesUrl": f"{repo}/releases/tag/v{release}",
    "androidArm64": f"{download}/LecCheck-{release}-android-arm64.apk",
    "androidUniversal": f"{download}/LecCheck-{release}-android.apk",
    "linux": f"{download}/LecCheck-{release}-linux-x64.tar.gz",
}

manifest = {}
if os.path.exists(existing):
    with open(existing, encoding="utf-8") as f:
        manifest = json.load(f)
manifest["beta"] = entry
if "-" not in release:
    manifest["stable"] = entry
json.dump(manifest, sys.stdout, indent=2)
print()
