# Design assets

## Icon font (`icons/`)

24 hand-drawn icons for the app's identity: navigation (outline + filled), session types,
attendance statuses, and a few objects (streak, requirement flag, holiday, moved).
Generic actions (add, close, search…) use Material icons.

Rules: 24px grid, 2px strokes with round caps and joins, `stroke="#000"`, filled parts
with `fill="#000"`.

Build:

```bash
uv run --with picosvg --with fonttools python design/build_icons.py
```

The script converts strokes to filled outlines (picosvg), unions each icon's shapes with
pairwise boolean ops (skia-pathops, so fills and strokes can't cancel each other out),
writes `app/assets/fonts/LecIcons.ttf` (Private Use Area codepoints, unitsPerEm 960) and
generates `app/lib/core/icons/lec_icon_font.dart` with `const IconData` entries so Flutter
can tree-shake the font. Use the icons through `LecIcons` in
`app/lib/core/icons/lec_icons.dart`.

## App icon and logo (`app-icon/`)

The mark is a calendar page with binder rings and a bold check on a blue→violet gradient
(`#2A7BCC` → `#7B4FD6`). The in-app logo (`LecLogo` widget) draws the same geometry with
the active theme's colors.

| File | Use |
|---|---|
| `foreground.svg` | Android adaptive icon foreground (mark inside the safe zone) |
| `background.svg` | Android adaptive icon background (gradient) |
| `monochrome.svg` | Android 13+ themed icon |
| `icon_full.svg` | iOS / legacy square icon |
| `icon_rounded.svg` | Linux, Windows, macOS, AltStore, splash |

Export and apply:

```bash
cd design/app-icon
for f in foreground background monochrome icon_full icon_rounded; do
  rsvg-convert -w 1024 -h 1024 $f.svg -o ../../app/assets/branding/$f.png
done
rsvg-convert -w 768 -h 768 icon_rounded.svg -o ../../app/assets/branding/splash.png
for s in 64 128 256 512; do
  rsvg-convert -w $s -h $s icon_rounded.svg -o ../../app/linux/assets/com.leccheck.app-$s.png
done
cd ../../app
dart run flutter_launcher_icons
dart run flutter_native_splash:create
```

## Font

The app uses [Rubik](https://github.com/googlefonts/rubik) (SIL Open Font License,
Hebrew + Latin), bundled as static Regular/Medium/SemiBold/Bold instances generated from
the variable font with `fonttools varLib.instancer`.
