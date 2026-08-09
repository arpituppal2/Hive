//
//  BrowserState+Approval.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Action Approval (Act) | - Session Grants (SWARM-005)
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Approval

@MainActor
extension BrowserState {


    func toggleApprovalPanel() {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            if isApprovalPanelOpen {
                isApprovalPanelOpen = false
                presentedApprovalAction = nil
            } else {
                // Opening with nothing to approve would render a blank panel
                // frame — the gate needs a presented action. Close instead.
                guard !approvalQueue.pending.isEmpty else { return }
                isApprovalPanelOpen = true
                presentedApprovalAction = approvalQueue.pending.first
            }
        }
    }


    /// Canonical close path for the approval panel — used by the window
    /// overlay closures, the header X, and the decided-view Close button.
    func dismissApprovalPanel() {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            isApprovalPanelOpen = false
            presentedApprovalAction = nil
        }
    }


    /// Records an approval/denial decision to the EventLedger, then executes
    /// the action if approved. Execution happens only after the consent is
    /// durably recorded — an approval that runs nothing would be theater.
    @discardableResult
    func recordApproval(action: PendingAction, approved: Bool, consent: EventLedgerStore.ConsentState = .approved) async -> Bool {
        guard !isAuditPersistenceDegraded else {
            lastPolicyDenial = "Action blocked: durable audit storage is unavailable. Nothing ran."
            if action.execution?.isRunCheck == true {
                studioCheckError = lastPolicyDenial
            }
            return false
        }
        let auditRecorded = await recordAuditEvent(EventLedgerStore.LedgerEvent(
            id: UUID().uuidString,
            timestamp: Date(),
            actor: "user",
            intent: action.summary,
            actionKind: action.actionKind,
            actionPreview: action.preview,
            trustLevel: action.trustLevel,
            policyDecision: approved ? .allowed : .denied,
            consentState: approved ? consent : .denied,
            contextIDs: action.sourceNodeID.map { [$0] } ?? [],
            toolName: action.toolInvocation?.toolID,
            environment: "swift-6",
            // An approved executable action has not run yet. `.partial`
            // means consent is recorded while execution remains pending;
            // it prevents the ledger from claiming success before the
            // bounded worker returns.
            result: approved
                ? (action.execution == nil ? .success : .partial)
                : .failure
        ))
        guard auditRecorded else {
            // Evidence is a hard prerequisite for execution. Keep the action
            // pending and fail closed if the audit store is unavailable.
            lastPolicyDenial = "Action blocked: EventLedger could not record the decision."
            if action.execution?.isRunCheck == true {
                studioCheckError = lastPolicyDenial
            }
            return false
        }
        approvalQueue.remove(action)
        // A non-check action must not leave a stale check banner behind
        // (approve a code edit after denying a check, and the panel should
        // not still show the check error). Approved runChecks re-publish
        // their own results in performExecution, so this clear is safe for
        // both paths.
        if action.execution?.isRunCheck != true {
            studioCheckResult = nil
            studioCheckError = nil
        }
        if approved, let execution = action.execution {
            await performExecution(execution)
        } else if !approved, action.execution?.isRunCheck == true {
            // A denied check must not leave the Studio panel spinning at
            // "Waiting for approval…" — publish the terminal state so the
            // panel's onChange observers fire and the UI returns to idle.
            studioCheckResult = nil
            studioCheckError = "Check was not approved — nothing ran."
        }
        return true
    }


    /// Runs a typed approved action. All cases are MainActor state methods;
    /// the enum keeps the execution surface small and auditable.
    func performExecution(_ execution: PendingActionExecution) async {
        switch execution {
        case .navigate(let url):
            navigateToURL(url)
        case .codeApply(let relativePath, _, let newContent):
            // The workspace backs up the original before writing, so the
            // change stays reversible even after approval. Capture the
            // returned FileEdit so the Studio panel can offer rollback.
            if let edit = try? await studioWorkspace.applyEdit(relativePath, newContent: newContent) {
                lastAppliedEdit = edit
            }
        case .runCheck(let command, _):
            // workspaceID is deliberately discarded here: v1 runs checks in
            // the single selected workspace. It is carried on the envelope
            // target so the PolicyEngine can scope the invocation; the
            // execution itself is already bounded by StudioWorkspace.
            // SWARM-004: the approved check runs through the bounded workspace;
            // output publishes for the Studio panel to render. A failing check
            // must show WHY it failed — the collected output rides along in
            // the error, mirroring the old direct-call behavior.
            do {
                let output = try await studioWorkspace.runCheck(command: command, timeout: 60)
                studioCheckResult = output.isEmpty ? "✓ check passed (no output)" : output
                studioCheckError = nil
            } catch {
                if let studioError = error as? StudioWorkspace.StudioError,
                   case .commandFailed(_, _, let failedOutput) = studioError,
                   !failedOutput.isEmpty {
                    studioCheckResult = failedOutput
                } else {
                    studioCheckResult = nil
                }
                studioCheckError = (error as? StudioWorkspace.StudioError)?.errorDescription ?? error.localizedDescription
            }
        }
    }


    /// The code studio's first real approval producer (STUDIO-002): takes a
    /// proposed file edit, renders the unified diff as the preview, and routes
    /// it through requestApproval as a T3 codeWrite action. Nothing is written
    /// until the user approves — the diff IS the consent prompt.
    func proposeCodeEdit(relativePath: String, originalContent: String, newContent: String) async {
        let diff = StudioWorkspace.unifiedDiff(
            original: originalContent,
            new: newContent,
            path: relativePath
        )
        // rootURL is actor-isolated (StudioWorkspace is an actor) — read it
        // via await for the envelope's optional workspaceID target.
        let workspaceID = await studioWorkspace.rootURL?.path
        let action = PendingAction(
            summary: "Apply edit to \(relativePath)",
            detail: "Writes the proposed change to \(relativePath) inside the selected project folder. The original is backed up and can be rolled back.",
            preview: diff,
            trustLevel: .t3,
            actionKind: .codeWrite,
            execution: .codeApply(
                relativePath: relativePath,
                originalContent: originalContent,
                newContent: newContent
            ),
            toolInvocation: .studioApply(
                path: relativePath,
                newContent: newContent,
                workspaceID: workspaceID,
                diff: diff
            )
        )
        requestApproval(for: action)
    }


    /// SWARM-004: run a project check through the approval center. The command
    /// is wrapped in a studio.runCheck envelope — the policy engine validates
    /// it (destructive-command deny-list) and the user approves before the
    /// bounded workspace runs it. Output publishes to studioCheckResult.
    func proposeRunCheck(command: String) async {
        let workspaceID = await studioWorkspace.rootURL?.path
        let action = PendingAction(
            summary: "Run check: \(command)",
            detail: "Runs \"\(command)\" inside the selected project folder with a 60-second timeout. The command must pass the destructive-command guard before it is presented for approval.",
            preview: "Command:\n$ \(command)\n\nExecutes in the bounded Studio workspace (selected project root).",
            trustLevel: .t3,
            actionKind: .codeTest,
            execution: .runCheck(command: command, workspaceID: workspaceID),
            toolInvocation: .studioRunCheck(command: command, workspaceID: workspaceID)
        )
        // Fresh check run: clear stale results and denials so the panel's
        // onChange observers fire on the new outcome.
        lastPolicyDenial = nil
        studioCheckResult = nil
        studioCheckError = nil
        requestApproval(for: action)
    }


    // MARK: - Session Grants (SWARM-005)

    func hasGrant(for invocation: ToolInvocation) -> Bool {
        guard invocation.hasGrantableApprovalScope else { return false }
        return sessionGrants.contains {
            $0.toolID == invocation.toolID &&
            $0.approvalScopeKey == invocation.approvalScopeKey
        }
    }


    /// Pre-approves this exact structured invocation for the rest of the
    /// session. A different command, path, workspace, URL, or payload has a
    /// different scope key and must return to the approval panel. The grant
    /// never overrides a policy denial.
    @discardableResult
    func grantSessionAccess(for invocation: ToolInvocation, summary: String) async -> Bool {
        guard invocation.hasGrantableApprovalScope else { return false }
        if hasGrant(for: invocation) { return true }
        let toolID = invocation.toolID
        let auditRecorded = await recordAuditEvent(EventLedgerStore.LedgerEvent(
            id: UUID().uuidString,
            timestamp: Date(),
            actor: "user",
            intent: "Session grant: \(toolID)",
            actionKind: .consentGranted,
            actionTarget: invocation.approvalScopeKey,
            actionPreview: summary,
            trustLevel: .t3,
            policyDecision: .allowed,
            consentState: .approved,
            contextIDs: invocation.evidence,
            toolName: toolID,
            environment: "swift-6",
            result: .success
        ))
        guard auditRecorded else {
            lastPolicyDenial = "Session grant blocked: EventLedger could not record consent."
            return false
        }
        sessionGrants.append(SessionGrant(
            toolID: toolID,
            approvalScopeKey: invocation.approvalScopeKey,
            summary: summary
        ))
        return true
    }


    /// Revokes one exact session grant. Other approved scopes for the same
    /// tool remain independent and continue to require their own policy-bound
    /// consent records. The ledger write is awaited so revocation evidence is
    /// ordered before a subsequent action can use the changed grant set.
    func revokeGrant(for grant: SessionGrant) async {
        let auditRecorded = await recordAuditEvent(EventLedgerStore.LedgerEvent(
            id: UUID().uuidString,
            timestamp: Date(),
            actor: "user",
            intent: "Revoked session grant: \(grant.toolID)",
            actionKind: .consentRevoked,
            actionTarget: grant.approvalScopeKey,
            actionPreview: grant.summary,
            trustLevel: .t3,
            policyDecision: .allowed,
            consentState: .denied,
            contextIDs: [],
            toolName: grant.toolID,
            environment: "swift-6",
            result: .success
        ))
        guard auditRecorded else {
            lastPolicyDenial = "Grant revocation blocked: EventLedger could not record the decision."
            return
        }
        sessionGrants.removeAll { $0.id == grant.id }
    }


    /// Submits a proposed action for user approval. Envelope-carrying actions
    /// are evaluated by the PolicyEngine FIRST — denied actions never reach
    /// the panel, allowed actions auto-execute, and only
    /// requiresConfirmation verdicts are presented. Legacy (envelope-less)
    /// actions keep the trust-level ladder: T0/T1 proposals auto-approve
    /// unless they carry an execution, T2+ opens the panel (DEC-005: no raw
    /// agent bypass).
    func requestApproval(for action: PendingAction) {
        guard let invocation = action.toolInvocation else {
            legacyRequestApproval(for: action)
            return
        }
        let engine = policyEngine
        let registry = toolRegistry
        Task {
            if !toolRegistryPopulated {
                await registry.register(ToolRegistry.defaultTools)
                toolRegistryPopulated = true
            }
            let verdict = await engine.evaluate(invocation, registry: registry)
            // SWARM-005: a session grant downgrades confirmation-gated tools
            // to auto-execute. It never overrides a policy denial.
            if verdict.decision == .requiresConfirmation, hasGrant(for: invocation) {
                approvalQueue.submit(action)
                await recordApproval(action: action, approved: true, consent: .approved)
                return
            }
            switch verdict.decision {
            case .denied, .escalated:
                // Policy blocked it — record the denial durably, never render
                // a preview, and surface the reason to the producer.
                let auditRecorded = await recordAuditEvent(EventLedgerStore.LedgerEvent(
                    id: UUID().uuidString,
                    timestamp: Date(),
                    actor: "user",
                    intent: action.summary,
                    actionKind: action.actionKind,
                    actionPreview: action.preview,
                    trustLevel: action.trustLevel,
                    policyDecision: verdict.decision == .escalated ? .escalated : .denied,
                    consentState: .denied,
                    contextIDs: action.sourceNodeID.map { [$0] } ?? [],
                    toolName: invocation.toolID,
                    environment: "swift-6",
                    outputSummary: "Blocked by policy: \(verdict.reason)",
                    result: .failure,
                    errorDescription: verdict.reason
                ))
                if auditRecorded {
                    lastPolicyDenial = verdict.reason
                } else {
                    lastPolicyDenial = "Action blocked: the policy denial could not be recorded because audit storage is unavailable. Nothing ran."
                }
            case .allowed:
                // Policy cleared it without confirmation — execute now with
                // consent recorded as notRequired (it was policy-gated, not
                // user-approved).
                approvalQueue.submit(action)
                await recordApproval(action: action, approved: true, consent: .notRequired)
            case .requiresConfirmation:
                // Carry the verdict reason into the panel so the Tool card
                // shows WHY confirmation is required (SWARM-004).
                let presented = action.withPolicyNote(verdict.reason)
                approvalQueue.submit(presented)
                // If the panel is already showing a decision, don't steal the
                // presented slot mid-decision — the queued action is surfaced
                // on the next open (toggleApprovalPanel seeds pending.first).
                guard !isApprovalPanelOpen else { return }
                presentedApprovalAction = presented
                withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
                    isApprovalPanelOpen = true
                }
            }
        }
    }


    /// The pre-protocol submission path for actions without a ToolInvocation
    /// envelope. Kept only for legacy producers; new producers attach an
    /// envelope so the policy engine gates them (SWARM-004).
    func legacyRequestApproval(for action: PendingAction) {
        // Deprecation trace: an envelope-less action bypasses the PolicyEngine
        // entirely. Record a systemEvent so any producer that forgets to attach
        // a ToolInvocation is visible in the audit trail (SWARM-004).
        Task {
            let _ = await recordAuditEvent(EventLedgerStore.LedgerEvent(
                id: UUID().uuidString,
                timestamp: Date(),
                actor: "system",
                intent: "Legacy envelope-less approval path used for \(action.summary)",
                actionKind: .systemEvent,
                actionPreview: action.preview,
                trustLevel: action.trustLevel,
                policyDecision: .requiresConfirmation,
                consentState: .notRequired,
                contextIDs: action.sourceNodeID.map { [$0] } ?? [],
                environment: "swift-6",
                outputSummary: "Action submitted without a ToolInvocation envelope — attach one (SWARM-004).",
                result: .partial
            ))
        }
        // Whether this action must go through the approval panel. T0/T1 are
        // proposals, not executions — but if a producer attaches an execution
        // to a low-trust action, escalate to the panel rather than auto-running
        // it (DEC-005: no raw agent bypass).
        let needsPanel: Bool
        switch action.trustLevel {
        case .t0, .t1: needsPanel = action.execution != nil
        default: needsPanel = true
        }
        if needsPanel {
            approvalQueue.submit(action)
            // If the panel is already showing a decision, don't steal the
            // presented slot mid-decision — the queued action is surfaced on
            // the next open (toggleApprovalPanel seeds pending.first).
            guard !isApprovalPanelOpen else { return }
            presentedApprovalAction = action
            withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
                isApprovalPanelOpen = true
            }
        } else {
            // Auto-approve low-risk actions
            approvalQueue.submit(action)
            Task { await recordApproval(action: action, approved: true) }
        }
    }


    func beginResponse() -> UInt64 {
        geminiGenerationTask?.cancel()
        isGeminiGenerating = true
        return responseLifecycleToken.begin()
    }


    func finishResponse(_ responseID: UInt64) {
        guard responseLifecycleToken.isCurrent(responseID) else { return }
        isGeminiGenerating = false
    }


    func responseIsCurrent(_ responseID: UInt64) -> Bool {
        responseLifecycleToken.isCurrent(responseID)
    }
}
