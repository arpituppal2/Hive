# Sign in with Apple Setup

Hive requires Sign in with Apple before it opens Field, The Colony, The Hive, Swarm, menu bar actions, hotkeys, or App Intents.

## Apple Developer configuration

1. Create or use a macOS App ID in the Apple Developer portal.
2. Enable the Sign in with Apple capability for that App ID.
3. Install a signing identity for the same Apple Developer team on this Mac.
4. Build Hive with the matching bundle identifier, team ID, and signing identity:

```bash
HIVE_BUNDLE_IDENTIFIER="com.example.hive" \
HIVE_DEVELOPMENT_TEAM="TEAMID" \
HIVE_CODESIGN_IDENTITY="Apple Development: Name (TEAMID)" \
scripts/build_app.sh release
```

## Verification

Run:

```bash
HIVE_BUNDLE_IDENTIFIER="com.example.hive" \
HIVE_DEVELOPMENT_TEAM="TEAMID" \
scripts/apple_signin_preflight.sh
```

The preflight must pass before native Sign in with Apple can succeed.

## Diagnostic builds

For local UI work without an Apple signing identity:

```bash
HIVE_ALLOW_UNSIGNED_LOCKED_BUILD=1 scripts/build_app.sh release
```

Sign in with Apple is unavailable in this build. For local UI testing only, Hive shows a temporary `Continue as Guest` button that unlocks the app without Apple identity validation; remove this path before production.
