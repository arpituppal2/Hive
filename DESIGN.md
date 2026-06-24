# Hive Design System Constraints

## Core constraints

- Dark-first baseline
- One accent color family (amber)
- Semantic color tokens over hardcoded hex values
- Visual hierarchy through spacing, typography, and contrast

## Spacing grid

- Base spacing unit: 4pt
- Preferred layout rhythm: 8/12/16/24/32
- Lists and cards must align to the same grid cadence
- Avoid ad hoc spacing constants in view code

## Typography

- Use system typography and defined app tokens
- No decorative font substitutions for core content
- Keep hierarchy predictable between list, detail, and tool surfaces

## SF Symbols usage rules

- Use SF Symbols for functional affordances and state hints
- Keep symbol sizing consistent within each component class
- Avoid symbol-only meaning where text clarification is required

## Liquid Glass boundary

- Use glass only for floating chrome layers and overlays
- Do not apply glass to dense content bodies
- Avoid stacked glass-on-glass compositions

## Empty-state rules

- Every empty state must include icon, title, guidance, and action
- Empty surfaces must never render as blank containers
- Empty-state copy must be specific to the current surface

## Motion rules

- Motion must communicate state change, not decoration
- Respect reduced-motion settings in all interactive transitions
- Prefer short, interruptible transitions over theatrical sequences
- Keyboard-triggered control actions should avoid unnecessary animation

## Color and style bans

- No purple or blue gradient AI styling
- No rainbow status palettes for semantic meaning
- No color-only status communication without text/icon support

## Copy and voice constraints

- No exclamation marks in product UI copy by default
- Prefer direct, clear labels over slogan-like language
- Error copy must include corrective action

## No generic SaaS patterns

- No dashboard noise blocks
- No vanity metric tiles without actionability
- No decorative trend charts without user decisions attached
