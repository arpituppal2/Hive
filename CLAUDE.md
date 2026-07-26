# Hive Browser — CLAUDE.md

## Project Identity

**Product:** The Hive Browser — a local-first Apple-native browser with persistent memory, AI orchestration (Swarm), and knowledge graph (Honeycomb) as a single integrated product.

**Internal brands:**
- **Swarm** — the intelligence/orchestration layer
- **Cells** — subagent worker units (never "Bees")
- **Honeycomb** — the graph database/memory substrate

## Architecture

Two-app SPM structure:
- **HiveCore** — All shared logic: AI, memory, models, design tokens, security
- **HiveBrowser** — The Chromium shell + native SwiftUI/AppKit UI
- **Swarm** — Agentic execution surface (lives inside HiveBrowser, separate target)

## Key Design Principles

1. Local-first by default. Cloud is optional, explicit, paid.
2. Universal base product — works for someone who never opens Settings.
3. Progressive disclosure of depth — advanced features dormant until invoked.
4. Easy Chrome/Safari transfer — 90-second import, 75 shortcut parity.
5. Dark-first visual language with single warm amber accent (#FFC824).
6. No AI sparkle icons, no gradient text, no glass on content.
7. Memory-first: knowledge graph builds from browsing automatically.

## Master Specs (read before implementation)

- `HIVE_BROWSER_MASTER_SPEC.md` — canonical build doc, supersedes all
- `SPEC.md` — definitive UI/UX spec, every pixel and animation
- `PITCH/competitive.md` — competitive landscape analysis

## Running

```bash
swift build          # Compile all targets
swift test           # Run tests
swift run HiveBrowser  # Launch browser
swift run Swarm      # Launch Swarm agent
```

## Skill routing

When the user's request matches an available skill, invoke it via the Skill tool. When in doubt, invoke the skill.

Key routing rules:
- Product ideas/brainstorming → invoke /office-hours
- Strategy/scope → invoke /plan-ceo-review
- Architecture → invoke /plan-eng-review
- Design system/plan review → invoke /design-consultation or /plan-design-review
- Full review pipeline → invoke /autoplan
- Bugs/errors → invoke /investigate
- QA/testing site behavior → invoke /qa or /qa-only
- Code review/diff check → invoke /review
- Visual polish → invoke /design-review
- Ship/deploy/PR → invoke /ship or /land-and-deploy
- Save progress → invoke /context-save
- Resume context → invoke /context-restore
- Author a backlog-ready spec/issue → invoke /spec