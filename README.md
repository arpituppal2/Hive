# The Hive Browser

A local-first, Apple-native macOS browser with persistent memory and an integrated
intelligence and execution layer. **One product.** The browser is the entry point;
memory and Swarm are progressively disclosed from meaningful browsing context.

Swarm lives *inside* Hive — as home, sidebar, omnibar modes, and controlled action
surfaces — not as a separate app.

## Naming

- **Swarm** — the intelligence/orchestration layer inside Hive.
- **Cells** — subagent worker units.
- **Honeycomb** — the graph memory substrate.

## Canonical documents (read in this order)

- `AGENTS.md` — canonical product spec and AI continuation protocol. Start here.
- `HIVE_BROWSER_MASTER_SPEC.md` — master build doc.
- `SPEC.md` — UI/UX spec.
- `PITCH/` — research and competitive context.

## Status

Rebuild in progress from a clean base. The previous codebase was retired.
See `AGENTS.md` for the current phase and the workstream ledger.

## Running

```bash
swift build
swift test
swift run Hive
```
