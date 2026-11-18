#!/usr/bin/env bash
# Checks the Windows runner's C++ (app/windows/runner) on Linux, before CI
# builds it for real: clang parses each file against Flutter's Windows headers
# and MinGW's Windows SDK headers, with warnings as errors (Flutter builds the
# runner with MSVC's /W4 /WX). It doesn't link or run anything.
#
#   scripts/check_windows_runner.sh
#
# Needs clang++, curl and zstd-capable tar. The first run downloads Flutter's
# Windows artifacts (flutter precache --windows) and three MSYS2 header
# packages into ~/.cache/leccheck-winhdr.
set -euo pipefail

cd "$(dirname "$0")/../app"
cache="${XDG_CACHE_HOME:-$HOME/.cache}/leccheck-winhdr"
repo=https://repo.msys2.org/mingw/clang64
packages=(
  mingw-w64-clang-x86_64-headers-git-13.0.0.r380.gb83511db8-1-any.pkg.tar.zst
  'mingw-w64-clang-x86_64-libc%2B%2B-23.1.5-1-any.pkg.tar.zst'
  mingw-w64-clang-x86_64-winpthreads-14.0.0.r598.ge3d18511f-1-any.pkg.tar.zst
)

if [ ! -f "$cache/root/clang64/include/windows.h" ]; then
  mkdir -p "$cache/download" "$cache/root"
  for p in "${packages[@]}"; do
    curl -fsSL -o "$cache/download/$p" "$repo/$p"
    tar --zstd -xf "$cache/download/$p" -C "$cache/root" --wildcards 'clang64/include/*'
  done
fi

# Through `flutter` itself: `command -v` may find a version manager's shim.
flutter_root="$(flutter --version --machine 2>/dev/null |
  python3 -c 'import json, sys; print(json.load(sys.stdin)["flutterRoot"])')"
engine="$flutter_root/bin/cache/artifacts/engine/windows-x64"
[ -f "$engine/flutter_windows.h" ] || flutter precache --windows >/dev/null

status=0
for f in windows/runner/*.cpp; do
  if ! clang++ --target=x86_64-w64-mingw32 --sysroot="$cache/root/clang64" \
      -stdlib=libc++ -fsyntax-only -std=c++17 \
      -Iwindows -I"$engine" -I"$engine/cpp_client_wrapper/include" \
      -DUNICODE -D_UNICODE -DNOMINMAX -D_WIN32_WINNT=0x0A00 -DWINVER=0x0A00 \
      -DFLUTTER_VERSION='"0.0.0"' -DFLUTTER_VERSION_MAJOR=0 \
      -DFLUTTER_VERSION_MINOR=0 -DFLUTTER_VERSION_PATCH=0 \
      -DFLUTTER_VERSION_BUILD=0 \
      -Wall -Wextra -Wshadow -Wconversion -Wno-sign-conversion \
      -Wno-unused-parameter -Werror "$f"; then
    status=1
  fi
done
# MSVC may reject UTF-8 it can't map to the build machine's code page.
if grep -nP '[^\x00-\x7F]' windows/runner/*.cpp windows/runner/*.h; then
  echo "Non-ASCII characters in the runner (above): use plain ASCII." >&2
  status=1
fi
[ "$status" -eq 0 ] && echo "Windows runner: OK"
exit "$status"
