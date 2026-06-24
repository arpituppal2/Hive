# HIVE REMAINING EXECUTION PLAN

## Current state

All meaningful agent-owned code/config/doc preparation gaps are closed in this environment.  
Remaining open work is human-owned and requires macOS/Xcode/simulator/device execution.

## Human-owned remaining execution

1. **Objective:** Run full Apple platform acceptance matrix and collect evidence.
   **Primary doc:** `docs/HIVE_MAC_FINALIZATION_RUNBOOK.md`
   **Evidence ledger template:** `docs/HIVE_MAC_ACCEPTANCE_LEDGER_TEMPLATE.md`

2. **Objective:** Execute Icon Composer and complete Xcode asset validation.
   **Primary doc:** `docs/BLOCKER_4_ICON_AND_MENUBAR_MAC_CHECKLIST.md`

3. **Objective:** Validate AppKit graph preview path and tune parity under runtime interaction.
   **Primary docs:**
   - `docs/BLOCKER_5_APPKIT_GRAPH_MIGRATION_PLAN.md`
   - `docs/HIVE_MAC_FINALIZATION_RUNBOOK.md` (Graph interaction section)

4. **Objective:** Run and record all acceptance suites (Prompt, Emergency, FINAL I/E).
   **Primary docs:**
   - `docs/HIVE_SPEC_GAP_AUDIT.md` (Unrun Acceptance Tests)
   - `docs/HIVE_MAC_ACCEPTANCE_LEDGER_TEMPLATE.md`

## Exit criterion

Promote from `NO-SHIP` only after acceptance evidence is captured and open human-owned queue rows are closed.
