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

# Runtime libraries the app links against (GTK, keyring, sign-in web view).
libs="$(ldconfig -p 2>/dev/null || /sbin/ldconfig -p 2>/dev/null || true)"
missing=()
if [[ -n "$libs" ]]; then
  for lib in libgtk-3.so.0 libsecret-1.so.0 libwebkit2gtk-4.1.so.0 libsoup-3.0.so.0; do
    [[ "$libs" == *"$lib "* ]] || missing+=("$lib")
  done
fi
if (( ${#missing[@]} )); then
  echo "Missing system libraries: ${missing[*]}"
  echo "  Debian/Ubuntu: sudo apt install libgtk-3-0 libsecret-1-0 libwebkit2gtk-4.1-0"
  echo "  Fedora:        sudo dnf install gtk3 libsecret webkit2gtk4.1"
  echo "  Arch:          sudo pacman -S gtk3 libsecret webkit2gtk-4.1"
  echo "Install them, then run this script again."
  exit 1
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
