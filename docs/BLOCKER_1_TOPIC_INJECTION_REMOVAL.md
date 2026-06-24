# BLOCKER 1 — Topic Injection Removal

## Files changed

- `Sources/HiveCore/MemorySelfHealingEngine.swift`
- `Sources/HiveCore/PresentationAdapters.swift`
- `Sources/HiveCore/GraphPresentationSemantics.swift`
- `Sources/HiveCore/MemoryQualityPolicy.swift`
- `Sources/HiveCore/MemoryCompiler.swift`
- `Sources/HiveCore/MemoryNodeLayerClassifier.swift`
- `Sources/HiveCore/MemoryRelevanceEngine.swift`
- `Sources/HiveApp/Resources/Seeds/HiveMemorySeed.json`
- `Tests/HiveCoreTests/HiveCoreTests.swift`

## Exact removed hardcoded strings/rules

Removed from production logic:

- `entity-mac-studio-funding-goal`
- `claim-mac-studio-funding-goal`
- `Mac Studio Funding Goal`
- `M3 Ultra Mac Studio`
- Explicit self-healing canonicalization branch that merged claims/entities into a fixed Mac Studio funding target
- User-specific bundle rule table used for deterministic consolidation into fixed entities (UCLA/UConsulting/Cabin/Hive/LAMT/BREV rule IDs and statements)
- Topic-specific synthetic browser clustering path named `semantic:mac-studio-funding`

## Replacement generalization logic

- `consolidateMemoryBundles(...)` now returns no prewired topic bundling and no pre-assigned canonical IDs.
- Presentation clustering now uses generic topic descriptors (`coursework`, `project-work`, `knowledge-system-work`, `compute-workflow`, etc.) without user-specific identity/project slugs.
- Domain and node-layer term lists were sanitized to generic terms so no single personal topic is privileged by static code paths.
- Seed statement mentioning a specific model/family was replaced with a generic workstation requirement.

## Regression coverage added

- `Tests/HiveCoreTests/HiveCoreTests.swift :: testProductionLogicContainsNoPrivilegedTopicInjectionStrings`
  - Scans key production logic files for banned privileged markers.

## Remaining risk

- This environment cannot execute the full app runtime acceptance flow.
- Additional user-specific phrasing may still exist in non-logic artifacts (historical tests/docs/design assets), but production consolidation logic no longer contains fixed privileged canonicalization rules.
