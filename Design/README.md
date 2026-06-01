# Hive Design Workspace

This folder contains the Apple-native design-resource pass for Hive.

## Current Source Of Truth

- Figma file: `Hive Apple Native UI System`
- Local Figma board export: `Design/Figma/Hive-Apple-Native-UI-Kit-Board.svg`
- Local Figma snapshot: `Design/Figma/Hive-Apple-Native-UI-System-Figma-Snapshot.png`
- Apple resource index: `Design/AppleResources/apple-design-resource-manifest.json`

The Figma board is a consistency target, not final app code. It defines the app's shared surface model, motion states, action naming, graph behavior, Raw Inputs clustering, Wiki editing, chat fallback, and settings structure.

## North Star

Hive is quiet memory cartography: a local graph of the user's life, with authored Wiki articles as the readable layer and Raw Inputs as evidence intake.

The app must not read as a hex-themed dashboard. Hexagons belong only to the Hive graph. Everywhere else should use Apple-native controls, clear rows, readable typography, and obvious actions.

## Immediate Design Rules

- Graph nodes are small colored hexes with straight edges.
- Base graph shows no node words.
- Hover reveals a short preview; click opens the side inspector.
- Selection highlights the chosen node and first-order neighbors only.
- Raw Inputs show synthesized intent clusters, not browser/file fragments.
- Wiki pages are fully editable authored articles.
- Chat works in indexed-memory mode when no local model exists.
- Every panel must have an obvious close action when it is dismissible.
- Archive, forget, open Wiki, show in Hive, and show evidence must be plain actions, not mystery controls.

## Apple Resources Used

Official Apple resources were pulled from the Apple Design Resources page:

- https://developer.apple.com/design/resources/
- https://developer.apple.com/design/human-interface-guidelines/
- https://developer.apple.com/sf-symbols/
- https://developer.apple.com/icon-composer/

The downloaded direct resources are stored under `Design/AppleResources/downloads/`. Figma Community resources are listed in `Design/AppleResources/figma-community-links.txt` because those are cloud files, not normal direct-download assets.
