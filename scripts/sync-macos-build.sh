#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="${HIVE_SYNC_BRANCH:-arpituppal2/hive-production-rebuild-82c2}"
KEEP_LOCAL_CHANGES="${HIVE_KEEP_LOCAL_CHANGES:-0}"

cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: $ROOT is not a git repository."
  echo "Clone instead:"
  echo "  git clone https://github.com/arpituppal2/Hive.git ~/Developer/Hive"
  echo "  cd ~/Developer/Hive && git checkout $BRANCH"
  exit 1
fi

echo "==> Fetching origin/$BRANCH"
git fetch origin "$BRANCH"

if [[ "$KEEP_LOCAL_CHANGES" == "1" ]]; then
  echo "==> Stashing local changes before sync"
  git stash push -u -m "hive-sync-backup $(date +%Y-%m-%dT%H%M%S)" || true
fi

echo "==> Checking out $BRANCH"
if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
  git checkout "$BRANCH"
else
  git checkout -B "$BRANCH" "origin/$BRANCH"
fi

echo "==> Resetting working tree to origin/$BRANCH"
git reset --hard "origin/$BRANCH"
git clean -fd

echo "==> Removing known local-only files that break macOS builds"
rm -f \
  Sources/HiveMacApp/HiveAppModel.swift \
  Sources/HiveMacApp/HivePrompt10AppKit.swift

if [[ -f Sources/HiveMacApp/HiveAppModel.swift || -f Sources/HiveMacApp/HivePrompt10AppKit.swift ]]; then
  echo "error: stray HiveMacApp files still present after cleanup"
  ls -la Sources/HiveMacApp
  exit 1
fi

echo "==> Resetting Swift package state"
rm -rf .build
rm -rf ~/Library/Developer/Xcode/DerivedData/Hive-*
rm -rf ~/Library/Caches/org.swift.swiftpm
xattr -cr "$ROOT" 2>/dev/null || true

if command -v xcrun >/dev/null 2>&1; then
  echo "==> Resolving Swift package dependencies"
  env DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p 2>/dev/null || true)}" \
    xcrun --sdk macosx swift package resolve || true
fi

echo "==> HiveMacApp sources:"
ls -1 Sources/HiveMacApp

echo
echo "Synced to $(git rev-parse --short HEAD) on $BRANCH"
echo "Next:"
echo "  open Package.swift"
echo "In Xcode: File > Packages > Reset Package Caches, then Product > Clean Build Folder, then build HiveApp."
