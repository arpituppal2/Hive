# BLOCKER 2 — Re-index Trust Status

| Requirement | Implemented in Code | Tested in CI | Still Needs Mac Validation | Notes |
|---|---|---|---|---|
| Re-index pre-audit of current source hashes vs local files | Yes | No | Yes | `Sources/HiveCore/HiveReindexTrustCoordinator.swift :: auditAndQueueSourcesForReindex()` compares file hash to `SourceRecord.sha256` and marks changed/stale |
| Stale marking / invalidation for orphaned or changed sources | Yes | No | Yes | Missing files are marked `deletionState = .derivedRetracted`; changed files clear derived products and are re-queued |
| Transaction-wrapped coordinator | Yes (partial scope) | No | Yes | `store.inTransaction` wraps audit+dedup+knowledge/log stages; extraction runs outside transaction due long-running I/O |
| Dedup stage before graph reconstruction | Yes | No | Yes | `deduplicateClaims()` merges duplicate normalized claim text and deletes duplicates before `knowledgeLoop.updateDerivedKnowledge()` |
| Topic-dominance computation in data layer | Yes | Yes (unit) | Yes | `topicDominanceWarning(for:)` computes dominant topic ratio with threshold |
| Surfaced dominance-warning model/state for UI | Yes | No | Yes | `HiveAppModel.topicDominanceWarning` + `HiveMacRootView.runtimeNotice` banner when Field selected |
| Re-index thrash protection | Yes | No | Yes | `HiveAppModel.requestHiveReindex()` rejects concurrent calls with `trustedReindexInProgress` guard |
| Re-index logging with structured counters | Yes | No | Yes | `appendReindexLog(report:)` appends `## [YYYY-MM-DD HH:mm] reindex | ...` to `Vault/Colony/log.md` |
| Prompt acceptance scenario execution | No | No | Yes | Scenarios are still unrun in Apple runtime environment |

## Notes on unrun scenarios

- This branch now contains executable trust logic for hash audit, stale invalidation, dedup, and dominance state.
- Prompt acceptance scenarios requiring app runtime and/or simulator/device are not executed in this Linux environment.
