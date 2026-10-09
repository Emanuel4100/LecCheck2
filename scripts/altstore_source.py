#!/usr/bin/env python3
"""Writes the AltStore / SideStore source for the latest iPhone build.

    python3 scripts/altstore_source.py <version> <build> <ipa_path> <download_url> [<release>] > altstore-source.json

<version> must match the IPA's CFBundleShortVersionString (numbers only, e.g. 2.0.0);
<release> is the name shown in the notes (e.g. 2.0.0-beta.1), defaulting to <version>.

Attached to each release, and copied to the `altstore` branch so the source URL
never changes (GitHub's "latest" release links skip pre-releases):
https://raw.githubusercontent.com/Emanuel4100/LecCheck2/altstore/altstore-source.json
"""
import datetime
import json
import os
import sys

version, build, ipa, url = sys.argv[1:5]
release = sys.argv[5] if len(sys.argv) > 5 else version
repo = "https://github.com/Emanuel4100/LecCheck2"
icon = "https://raw.githubusercontent.com/Emanuel4100/LecCheck2/main/design/app-icon/icon_full.png"

source = {
    "name": "LecCheck",
    "identifier": "com.leccheck.app.source",
    "subtitle": "Lecture attendance tracker",
    "iconURL": icon,
    "website": repo,
    "tintColor": "#4F66D2",
    "apps": [
        {
            "name": "LecCheck",
            "bundleIdentifier": "com.leccheck.app",
            "developerName": "Emanuel",
            "subtitle": "Mark every class you attend",
            "localizedDescription": "Track the lectures, practices and labs you attend. "
            "Works offline and syncs live between your devices.",
            "iconURL": icon,
            "tintColor": "#4F66D2",
            "category": "education",
            "versions": [
                {
                    "version": version,
                    "buildVersion": build,
                    "date": datetime.date.today().isoformat(),
                    "localizedDescription": f"LecCheck {release}",
                    "downloadURL": url,
                    "size": os.path.getsize(ipa),
                    "minOSVersion": "15.0",
                }
            ],
            "appPermissions": {"entitlements": [], "privacy": {}},
        }
    ],
    "news": [],
}
json.dump(source, sys.stdout, indent=2)
print()
