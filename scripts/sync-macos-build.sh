#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BRANCH="${HIVE_SYNC_BRANCH:-arpituppal2/hive-production-rebuild-82c2}"

cd "$ROOT"

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "error: $ROOT is not a git repository."
  echo "Clone instead:"
  echo "  git clone https://github.com/arpituppal2/Hive.git ~/Developer/Hive"
  echo "  cd ~/Developer/Hive && git checkout $BRANCH"
  exit 1
fi

echo "==> Fetching origin"
git fetch origin

echo "==> Checking out $BRANCH"
git checkout "$BRANCH"
git pull --ff-only origin "$BRANCH"

echo "==> Restoring canonical Sources/HiveMacApp from git"
git checkout HEAD -- Sources/HiveMacApp/

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

echo "==> Expected HiveMacApp sources:"
ls -1 Sources/HiveMacApp

echo
echo "Done. Next:"
echo "  open Package.swift"
echo "In Xcode: File > Packages > Reset Package Caches, then Product > Clean Build Folder, then build HiveApp."
