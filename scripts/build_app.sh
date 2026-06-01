#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIGURATION="${1:-release}"
APP_DIR="${HIVE_APP_DIR:-"$HOME/Applications/Hive.app"}"
ALLOW_UNSIGNED_LOCKED_BUILD="${HIVE_ALLOW_UNSIGNED_LOCKED_BUILD:-0}"
BUNDLE_IDENTIFIER="${HIVE_BUNDLE_IDENTIFIER:-}"
DEVELOPMENT_TEAM="${HIVE_DEVELOPMENT_TEAM:-}"
SIGN_IDENTITY="${HIVE_CODESIGN_IDENTITY:-}"
GOOGLE_CLIENT_ID="${HIVE_GOOGLE_CLIENT_ID:-}"
GOOGLE_REVERSED_CLIENT_ID="${HIVE_GOOGLE_REVERSED_CLIENT_ID:-}"
if [[ "$ALLOW_UNSIGNED_LOCKED_BUILD" == "1" ]]; then
  BUNDLE_IDENTIFIER="${BUNDLE_IDENTIFIER:-local.hive.desktop}"
  SIGN_IDENTITY="${SIGN_IDENTITY:-"-"}"
else
  missing=()
  [[ -n "$BUNDLE_IDENTIFIER" ]] || missing+=("HIVE_BUNDLE_IDENTIFIER")
  [[ -n "$DEVELOPMENT_TEAM" ]] || missing+=("HIVE_DEVELOPMENT_TEAM")
  [[ -n "$SIGN_IDENTITY" ]] || missing+=("HIVE_CODESIGN_IDENTITY")
  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "Hive requires Sign in with Apple before app access." >&2
    echo "Usable builds must be signed with the Apple Developer App ID that owns the Sign in with Apple entitlement." >&2
    echo "Missing: ${missing[*]}" >&2
    echo "Set HIVE_ALLOW_UNSIGNED_LOCKED_BUILD=1 only for local UI testing; provider login will be unavailable and temporary guest access may be shown." >&2
    exit 1
  fi
fi
ICLOUD_CONTAINER_IDENTIFIER="${HIVE_ICLOUD_CONTAINER_IDENTIFIER:-iCloud.$BUNDLE_IDENTIFIER}"
UBIQUITY_KVSTORE_IDENTIFIER="${HIVE_UBIQUITY_KVSTORE_IDENTIFIER:-$BUNDLE_IDENTIFIER}"
GOOGLE_INFO_PLIST_KEYS=""
if [[ -n "$GOOGLE_CLIENT_ID" || -n "$GOOGLE_REVERSED_CLIENT_ID" ]]; then
  if [[ -z "$GOOGLE_CLIENT_ID" || -z "$GOOGLE_REVERSED_CLIENT_ID" ]]; then
    echo "Google sign-in requires both HIVE_GOOGLE_CLIENT_ID and HIVE_GOOGLE_REVERSED_CLIENT_ID when either is set." >&2
    exit 1
  fi
  GOOGLE_INFO_PLIST_KEYS=$(cat <<PLIST
  <key>GIDClientID</key>
  <string>${GOOGLE_CLIENT_ID}</string>
  <key>HiveGoogleReversedClientID</key>
  <string>${GOOGLE_REVERSED_CLIENT_ID}</string>
  <key>CFBundleURLTypes</key>
  <array>
    <dict>
      <key>CFBundleURLName</key>
      <string>Google Sign-In</string>
      <key>CFBundleURLSchemes</key>
      <array>
        <string>${GOOGLE_REVERSED_CLIENT_ID}</string>
      </array>
    </dict>
  </array>
PLIST
)
fi
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"
HELPERS="$CONTENTS/Library/Helpers"

cd "$ROOT"
swift build -c "$CONFIGURATION" --product HiveApp
swift build -c "$CONFIGURATION" --product HiveDaemon
swift build -c "$CONFIGURATION" --target HiveWatchApp

icon_document_is_valid() {
  python3 - "$ROOT/Sources/HiveApp/Resources/AppIcon" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
icon = root / "Hive.icon"
icon_json = icon / "icon.json"
assets = icon / "Assets"
if not icon_json.exists():
    raise SystemExit(1)
try:
    data = json.loads(icon_json.read_text())
except Exception:
    raise SystemExit(1)
groups = data.get("groups") or []
if not groups:
    raise SystemExit(1)
layer_count = 0
for group in groups:
    layers = group.get("layers") or []
    if not layers:
        raise SystemExit(1)
    for layer in layers:
        name = layer.get("image-name")
        if not name or not (assets / name).exists():
            raise SystemExit(1)
        layer_count += 1
if layer_count == 0:
    raise SystemExit(1)
raise SystemExit(0)
PY
}

if [[ "${HIVE_REGENERATE_ICON:-0}" == "1" ]] || ! icon_document_is_valid; then
  swift scripts/render_app_icon.swift >/dev/null
fi
scripts/export_icon_composer_assets.sh >/dev/null

BIN_DIR="$ROOT/.build/$(uname -m)-apple-macosx/$CONFIGURATION"
if [[ ! -x "$BIN_DIR/HiveApp" ]]; then
  BIN_DIR="$ROOT/.build/$CONFIGURATION"
fi

mkdir -p "$(dirname "$APP_DIR")"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES" "$HELPERS"
cp "$BIN_DIR/HiveApp" "$MACOS/Hive"
cp "$BIN_DIR/HiveDaemon" "$HELPERS/HiveDaemon"
if [[ -f "$ROOT/Sources/HiveApp/Resources/AppIcon/Hive.icns" ]]; then
  cp "$ROOT/Sources/HiveApp/Resources/AppIcon/Hive.icns" "$RESOURCES/Hive.icns"
fi
if [[ -d "$ROOT/Sources/HiveApp/Resources/AppIcon/Hive.icon" ]]; then
  cp -R "$ROOT/Sources/HiveApp/Resources/AppIcon/Hive.icon" "$RESOURCES/Hive.icon"
fi
for bundle in "$BIN_DIR"/Hive_*.bundle; do
  [[ -d "$bundle" ]] || continue
  name="$(basename "$bundle")"
  cp -R "$bundle" "$RESOURCES/$name"
done
chmod 755 "$MACOS/Hive" "$HELPERS/HiveDaemon"

cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>Hive</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_IDENTIFIER}</string>
  <key>CFBundleName</key>
  <string>Hive</string>
  <key>CFBundleDisplayName</key>
  <string>Hive</string>
  <key>CFBundleIconFile</key>
  <string>Hive</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSAppDataUsageDescription</key>
  <string>Hive imports browser history only when you ask it to copy a browser profile snapshot.</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>Hive uses the microphone only when you press a mic button to dictate into Ask or record a Field voice note.</string>
  <key>NSSpeechRecognitionUsageDescription</key>
  <string>Hive uses Apple speech recognition when available to turn your dictation into editable local memory.</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>ApplePersistenceIgnoreState</key>
  <true/>
  <key>NSQuitAlwaysKeepsWindows</key>
  <false/>
  <key>NSSupportsAutomaticGraphicsSwitching</key>
  <true/>
${GOOGLE_INFO_PLIST_KEYS}
</dict>
</plist>
PLIST

rm -rf "$HOME/Library/Saved Application State/${BUNDLE_IDENTIFIER}.savedState"
plutil -lint "$CONTENTS/Info.plist" >/dev/null
if [[ -n "$GOOGLE_CLIENT_ID" ]]; then
  python3 - "$CONTENTS/Info.plist" "$GOOGLE_CLIENT_ID" "$GOOGLE_REVERSED_CLIENT_ID" <<'PY'
import plistlib
import sys

path, expected_client_id, expected_callback_scheme = sys.argv[1:4]
with open(path, "rb") as file:
    info = plistlib.load(file)

if info.get("GIDClientID") != expected_client_id:
    raise SystemExit("Hive.app Info.plist is missing GIDClientID for Google sign-in.")
if info.get("HiveGoogleReversedClientID") != expected_callback_scheme:
    raise SystemExit("Hive.app Info.plist is missing HiveGoogleReversedClientID for Google sign-in.")

schemes = [
    scheme
    for url_type in info.get("CFBundleURLTypes", [])
    for scheme in url_type.get("CFBundleURLSchemes", [])
]
if expected_callback_scheme not in schemes:
    raise SystemExit("Hive.app Info.plist is missing the Google callback URL scheme.")
PY
fi

cat > "$CONTENTS/Hive.entitlements" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>com.apple.developer.applesignin</key>
  <array>
    <string>Default</string>
  </array>
  <key>com.apple.developer.team-identifier</key>
  <string>${DEVELOPMENT_TEAM}</string>
  <key>com.apple.application-identifier</key>
  <string>${DEVELOPMENT_TEAM}.${BUNDLE_IDENTIFIER}</string>
  <key>com.apple.developer.icloud-container-identifiers</key>
  <array>
    <string>${ICLOUD_CONTAINER_IDENTIFIER}</string>
  </array>
  <key>com.apple.developer.icloud-services</key>
  <array>
    <string>CloudDocuments</string>
  </array>
  <key>com.apple.developer.ubiquity-container-identifiers</key>
  <array>
    <string>${ICLOUD_CONTAINER_IDENTIFIER}</string>
  </array>
  <key>com.apple.developer.ubiquity-kvstore-identifier</key>
  <string>${UBIQUITY_KVSTORE_IDENTIFIER}</string>
</dict>
</plist>
PLIST

plutil -lint "$CONTENTS/Hive.entitlements" >/dev/null
if [[ "$SIGN_IDENTITY" == "-" && "$ALLOW_UNSIGNED_LOCKED_BUILD" != "1" ]]; then
  echo "Hive requires Sign in with Apple before app access." >&2
  echo "HIVE_CODESIGN_IDENTITY cannot be '-' for a usable build." >&2
  exit 1
fi
xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --sign "$SIGN_IDENTITY" "$HELPERS/HiveDaemon" >/dev/null
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  echo "Packaging an unsigned Hive diagnostic build without production login entitlements." >&2
  echo "Provider sign-in is unavailable in this build; temporary guest access is enabled for local UI testing and must be removed before production." >&2
  codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_DIR" >/dev/null
else
  codesign --force --deep --sign "$SIGN_IDENTITY" --entitlements "$CONTENTS/Hive.entitlements" "$APP_DIR" >/dev/null
fi
ENTITLEMENTS_DUMP="$(mktemp)"
trap 'rm -f "$ENTITLEMENTS_DUMP"' EXIT
if ! codesign -d --entitlements :- "$APP_DIR" >"$ENTITLEMENTS_DUMP" 2>/dev/null; then
  echo "Hive.app was signed, but its entitlements could not be inspected." >&2
  exit 1
fi
if [[ "$SIGN_IDENTITY" != "-" ]] && ! grep -q "com.apple.developer.applesignin" "$ENTITLEMENTS_DUMP"; then
  echo "Hive.app is missing the Sign in with Apple entitlement. Refusing to package a broken login build." >&2
  exit 1
fi
SIGNING_DETAILS="$(codesign -dv "$APP_DIR" 2>&1 || true)"
if [[ "$SIGN_IDENTITY" != "-" ]] && ! grep -q "TeamIdentifier=" <<<"$SIGNING_DETAILS"; then
  echo "Hive.app was signed without an Apple TeamIdentifier. Sign in with Apple will not work reliably." >&2
  exit 1
fi
if [[ "$SIGN_IDENTITY" != "-" ]] && ! grep -q "TeamIdentifier=${DEVELOPMENT_TEAM}" <<<"$SIGNING_DETAILS"; then
  echo "Hive.app TeamIdentifier does not match HIVE_DEVELOPMENT_TEAM." >&2
  exit 1
fi
codesign --verify --deep --strict --verbose=2 "$APP_DIR" >/dev/null
echo "$APP_DIR"
