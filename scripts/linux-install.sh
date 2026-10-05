#!/usr/bin/env bash
# Installs LecCheck for the current user (no root needed):
#   ./install.sh            install or update
#   ./install.sh uninstall  remove (your data in ~/.local/share/com.leccheck.app is kept)
set -euo pipefail

APP_ID="com.leccheck.app"
HERE="$(cd "$(dirname "$0")" && pwd)"
PREFIX="${XDG_DATA_HOME:-$HOME/.local/share}"
DEST="$PREFIX/leccheck"
BIN="$HOME/.local/bin"

if [[ "${1:-}" == "uninstall" ]]; then
  rm -rf "$DEST" "$BIN/leccheck" "$PREFIX/applications/$APP_ID.desktop" "$PREFIX/metainfo/$APP_ID.metainfo.xml"
  for size in 64 128 256 512; do rm -f "$PREFIX/icons/hicolor/${size}x${size}/apps/$APP_ID.png"; done
  echo "LecCheck removed."
  exit 0
fi

mkdir -p "$DEST" "$BIN" "$PREFIX/applications" "$PREFIX/metainfo"
rm -rf "${DEST:?}"/*
cp -r "$HERE/bundle/." "$DEST/"
ln -sf "$DEST/leccheck" "$BIN/leccheck"
for size in 64 128 256 512; do
  install -Dm644 "$HERE/icons/$APP_ID-$size.png" "$PREFIX/icons/hicolor/${size}x${size}/apps/$APP_ID.png"
done
install -Dm644 "$HERE/$APP_ID.desktop" "$PREFIX/applications/$APP_ID.desktop"
install -Dm644 "$HERE/$APP_ID.metainfo.xml" "$PREFIX/metainfo/$APP_ID.metainfo.xml"
command -v update-desktop-database >/dev/null && update-desktop-database "$PREFIX/applications" || true
[[ -f "$PREFIX/icons/hicolor/index.theme" ]] && command -v gtk-update-icon-cache >/dev/null && gtk-update-icon-cache -q "$PREFIX/icons/hicolor" || true
echo "LecCheck installed. Start it from your app launcher or run: leccheck"
