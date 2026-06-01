# Hive Apple Native UI System

Figma source: `Hive Apple Native UI System`

Local board export:

- `Design/Figma/Hive-Apple-Native-UI-Kit-Board.svg`
- `Design/Figma/Hive-Apple-Native-UI-System-Figma-Snapshot.png`

## Frame Map

The board contains six implementation frames.

1. `01 App Shell`
   - One sidebar model.
   - One toolbar cluster model.
   - One inspector model.
   - Explicit close, archive, forget, open, and evidence actions.

2. `02 Raw Inputs`
   - Intake is evidence-only.
   - Default view uses intent clusters.
   - Raw browser/file fragments are hidden in inspectors.
   - No hex cards outside the graph.

3. `03 Wiki`
   - Fully editable authored article surface.
   - `Show in Hive` in the article header.
   - Related concepts can jump back to graph nodes.
   - Evidence remains outside article prose.

4. `04 Hive Graph`
   - Base graph is wordless.
   - Nodes are small colored hexes.
   - Edges are straight line segments.
   - Selection highlights selected plus first-order neighbors.
   - Right inspector carries the title, summary, why it matters, actions, and connected memories.

5. `05 Chat, Command, Settings`
   - Chat has an indexed-memory-only state when no local model is installed.
   - Command palette uses clear action names and previews.
   - Settings are behavior-first, with technical controls hidden under advanced sections.

6. `06 Motion & States`
   - Import uses a one-shot symbol bounce and row slide.
   - Synthesis uses active-only symbol motion.
   - Promotion fades into Wiki and forms a graph node.
   - Selection brightens selected plus first-order neighbors.
   - Wiki-to-Hive centers and selects the target graph node.
   - Reduced motion keeps causal ordering through opacity and tint changes.

## Typography

- Controls and metadata: SF Pro Text.
- Authored memory and Wiki prose: New York when available, Source Serif 4 fallback when needed.
- Do not use ornamental display type inside controls.

## Shape Grammar

- Hexagons: graph memory nodes and graph-neighbor mini nodes only.
- Standard controls: Apple-native rounded buttons, rows, sheets, and side panels.
- Status: small dots, labels, and SF Symbols.
- Do not use hex badges, hex sidebar icons, hex raw-input cards, honeycomb backgrounds, or decorative graph language outside the graph.

## Color Grammar

Use graph-only life-domain colors:

- Education/UCLA/math: deep gold.
- Projects/apps/startups: amber.
- Hardware/tools/workflow: bronze.
- Finance/grants/shopping: olive.
- Health/body: muted red-brown.
- Family/relationships/social: rose-brown.
- Identity/preferences/bio: pale honey.
- Background/unknown: neutral wax.

The rest of the interface stays restrained: warm neutrals, clear contrast, and amber only for selected or primary action state.

## Implementation Contract

- The graph never follows the mouse.
- The graph does not show base labels.
- Hover can reveal a preview without moving layout.
- Click opens the right inspector.
- `Open Wiki` from a graph node opens the canonical article.
- `Show in Hive` from Wiki switches surfaces, selects the matched node, centers it, and highlights first-order neighbors.
- Raw Inputs never become Wiki article prose.
- Chat must answer from indexed memory if no model is installed.

## Figma Import Status

The SVG board was pasted directly into an open Figma design file after project-level SVG import failed with Figma's message: "To import an SVG, add it directly into an open Figma file." The board is now present in the Figma canvas and the file has been renamed to `Hive Apple Native UI System`.
