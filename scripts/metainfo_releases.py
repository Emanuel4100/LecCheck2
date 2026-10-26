#!/usr/bin/env python3
"""Writes the newest releases from CHANGELOG.md into the <releases> of the Linux metainfo,
so software centers (GNOME Software, Discover) show what's new in each version.

    python3 scripts/metainfo_releases.py [<metainfo.xml>] [<how many>]

The metainfo defaults to app/linux/packaging/com.leccheck.app.metainfo.xml, and the
releases to the newest 8. The release workflow runs it before building the Flatpak;
"Prepare the vX pre-release" runs it too, to keep the file in the repository current.
"""
import html
import os
import re
import sys

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")


def releases(changelog):
    """(version, date, body) for each "## <version> — <date>" section, newest first."""
    pattern = re.compile(r"^## (\S+) — (\d{4}-\d{2}-\d{2})\s*\n(.*?)(?=^## |\Z)", re.M | re.S)
    return [(m[1], m[2], m[3].strip()) for m in pattern.finditer(changelog)]


def inline(text):
    """Markdown marks as AppStream's: **bold** → <em>, `code` → <code>, links → their text.
    Plain URLs lose their scheme: AppStream doesn't allow them in descriptions."""
    text = re.sub(r"https?://", "", html.escape(text, quote=False))
    text = re.sub(r"\*\*(.+?)\*\*", r"<em>\1</em>", text)
    text = re.sub(r"`([^`]+)`", r"<code>\1</code>", text)
    return re.sub(r"\[([^\]]+)\]\([^)]*\)", r"\1", text)


def description(body, indent):
    """`### ` headings and paragraphs as <p>, `- ` items (continued on indented lines)
    as <ul><li>."""
    blocks = []  # ("p" | "li", text)
    for line in body.split("\n"):
        stripped = line.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            blocks.append(("p", re.sub(r"^#+\s*", "", stripped)))
        elif stripped.startswith(("- ", "* ")):
            blocks.append(("li", stripped[2:]))
        elif blocks and line.startswith(" "):
            kind, text = blocks[-1]
            blocks[-1] = (kind, f"{text} {stripped}")
        else:
            blocks.append(("p", stripped))
    out, in_list = [], False
    for kind, text in blocks:
        if kind == "li" and not in_list:
            out.append(f"{indent}<ul>")
            in_list = True
        elif kind == "p" and in_list:
            out.append(f"{indent}</ul>")
            in_list = False
        tag = "li" if kind == "li" else "p"
        pad = indent + ("  " if kind == "li" else "")
        out.append(f"{pad}<{tag}>{inline(text)}</{tag}>")
    if in_list:
        out.append(f"{indent}</ul>")
    return "\n".join(out)


def releases_xml(changelog, count):
    lines = ["  <releases>"]
    for version, date, body in releases(changelog)[:count]:
        kind = "development" if "-" in version else "stable"
        lines.append(f'    <release version="{version}" date="{date}" type="{kind}">')
        if body:
            lines.append("      <description>")
            lines.append(description(body, "        "))
            lines.append("      </description>")
        lines.append("    </release>")
    lines.append("  </releases>")
    return "\n".join(lines)


def main():
    metainfo = sys.argv[1] if len(sys.argv) > 1 else os.path.join(
        ROOT, "app/linux/packaging/com.leccheck.app.metainfo.xml"
    )
    count = int(sys.argv[2]) if len(sys.argv) > 2 else 8
    with open(os.path.join(ROOT, "CHANGELOG.md"), encoding="utf-8") as f:
        changelog = f.read()
    with open(metainfo, encoding="utf-8") as f:
        text = f.read()
    new, n = re.subn(
        r"^  <releases>.*?^  </releases>",
        lambda _: releases_xml(changelog, count),
        text,
        flags=re.M | re.S,
    )
    if n != 1:
        sys.exit(f"{metainfo}: no <releases> block to fill")
    with open(metainfo, "w", encoding="utf-8") as f:
        f.write(new)


if __name__ == "__main__":
    main()
