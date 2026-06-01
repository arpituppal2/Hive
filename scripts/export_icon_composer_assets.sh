#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON_ROOT="$ROOT/Sources/HiveApp/Resources/AppIcon"
ICON_DOCUMENT="$ICON_ROOT/Hive.icon"
ICONSET="$ICON_ROOT/Hive.iconset"
PREVIEWS="$ICON_ROOT/IconComposerPreviews"
ICTOOL="/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool"

if [[ ! -x "$ICTOOL" ]]; then
  echo "Icon Composer ictool not found at $ICTOOL" >&2
  exit 1
fi

if [[ ! -f "$ICON_DOCUMENT/icon.json" ]]; then
  echo "Icon Composer document missing at $ICON_DOCUMENT" >&2
  exit 1
fi

rm -rf "$ICONSET" "$PREVIEWS"
mkdir -p "$ICONSET" "$PREVIEWS"

export_preview() {
  local rendition="$1"
  local filename="$2"
  shift 2
  "$ICTOOL" "$ICON_DOCUMENT" \
    --export-image \
    --output-file "$PREVIEWS/$filename" \
    --platform iOS \
    --rendition "$rendition" \
    --width 1024 \
    --height 1024 \
    --scale 1 \
    "$@" >/dev/null
}

export_default_size() {
  local filename="$1"
  local pixels="$2"
  "$ICTOOL" "$ICON_DOCUMENT" \
    --export-image \
    --output-file "$ICONSET/$filename" \
    --platform iOS \
    --rendition Default \
    --width "$pixels" \
    --height "$pixels" \
    --scale 1 >/dev/null
}

export_preview Default Preview-normal.png
export_preview Dark Preview-dark.png
export_preview TintedLight Preview-light-tinted.png --tint-color 0.115 --tint-strength 0.70
export_preview TintedDark Preview-dark-tinted.png --tint-color 0.115 --tint-strength 0.82
export_preview ClearLight Preview-light-clear.png
export_preview ClearDark Preview-dark-clear.png
cp "$PREVIEWS/Preview-normal.png" "$PREVIEWS/Preview.png"

export_default_size icon_16x16.png 16
export_default_size icon_16x16@2x.png 32
export_default_size icon_32x32.png 32
export_default_size icon_32x32@2x.png 64
export_default_size icon_128x128.png 128
export_default_size icon_128x128@2x.png 256
export_default_size icon_256x256.png 256
export_default_size icon_256x256@2x.png 512
export_default_size icon_512x512.png 512
export_default_size icon_512x512@2x.png 1024

/usr/bin/iconutil -c icns "$ICONSET" -o "$ICON_ROOT/Hive.icns"
