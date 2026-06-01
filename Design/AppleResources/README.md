# Apple Design Resources

This folder is the local cache from the official Apple Design Resources page.

## Files

- `apple-design-resources.html`: saved copy of the Apple resources page used for parsing.
- `apple-design-resource-manifest.json`: parsed resource manifest.
- `figma-community-links.txt`: Apple Figma Community resources to duplicate/open in Figma.
- `direct-download-links.txt`: direct Apple download URLs.
- `downloads/`: direct downloaded Apple assets.

## Download Result

- Parsed resources: 82
- Figma Community links: 17
- Direct Apple downloads listed: 46
- Direct Apple downloads completed: 45
- Failed direct download: `Thumbnail-Bezel-Keynote_2x.dmg` returned HTTP 403 from Apple's CDN.

## Installed Fonts

The official Apple `SF-Pro.dmg` and `NY.dmg` packages were mounted, extracted, and copied into the user font folder:

- `~/Library/Fonts/SF-Pro-*`
- `~/Library/Fonts/NY-*`

The DMGs were unmounted after installation. No system-wide installer was run.

## Important Notes

Figma Community files are not mirrored as local `.fig` files here. Use the links in `figma-community-links.txt` from Figma/Comet and duplicate them into the team if needed. The current Figma account already had the `iOS/iPadOS 26 UIKit` file in recents during this pass.

Official source:

- https://developer.apple.com/design/resources/
