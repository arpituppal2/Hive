#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-"$HOME/Applications/Hive.app"}"
HELPER_PATH="$APP_PATH/Contents/Library/Helpers/HiveDaemon"
LABEL="com.hive.daemon"
PLIST_PATH="$HOME/Library/LaunchAgents/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs/Hive"

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  printf '%s' "$value"
}

if [[ ! -d "$APP_PATH" ]]; then
  echo "Hive.app not found at: $APP_PATH" >&2
  echo "Run scripts/build_app.sh release first, or pass an explicit .app path." >&2
  exit 1
fi

if [[ ! -x "$HELPER_PATH" ]]; then
  echo "HiveDaemon helper not found at: $HELPER_PATH" >&2
  echo "Run scripts/build_app.sh release first." >&2
  exit 1
fi

mkdir -p "$HOME/Library/LaunchAgents" "$LOG_DIR"

TMP_PLIST="$(mktemp "$HOME/Library/LaunchAgents/$LABEL.plist.XXXXXX")"
trap 'rm -f "$TMP_PLIST"' EXIT

HELPER_XML="$(xml_escape "$HELPER_PATH")"
OUT_XML="$(xml_escape "$LOG_DIR/daemon.out.log")"
ERR_XML="$(xml_escape "$LOG_DIR/daemon.err.log")"

cat > "$TMP_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$HELPER_XML</string>
    <string>--scheduled</string>
  </array>
  <key>StartInterval</key>
  <integer>900</integer>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$OUT_XML</string>
  <key>StandardErrorPath</key>
  <string>$ERR_XML</string>
</dict>
</plist>
PLIST

plutil -lint "$TMP_PLIST" >/dev/null
mv "$TMP_PLIST" "$PLIST_PATH"
trap - EXIT

launchctl bootout "gui/$(id -u)" "$PLIST_PATH" >/dev/null 2>&1 || true
launchctl bootstrap "gui/$(id -u)" "$PLIST_PATH"
launchctl enable "gui/$(id -u)/$LABEL"

echo "Installed $LABEL"
echo "Plist: $PLIST_PATH"
echo "Helper: $HELPER_PATH"
echo "Logs: $LOG_DIR/daemon.out.log and $LOG_DIR/daemon.err.log"
