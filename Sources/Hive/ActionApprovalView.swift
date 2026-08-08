import SwiftUI
import HiveCore

// MARK: - PendingAction

/// The typed thing that runs when a pending action is approved. Kept as a
/// value enum (not a closure) so PendingAction stays Sendable with no retain
/// cycles; BrowserState.recordApproval switches on it after the
/// ledger record. An approval that executes nothing would be theater.
enum PendingActionExecution: Sendable {
    case navigate(URL)
    /// Apply an edit inside the StudioWorkspace (STUDIO-002). Carries the
    /// proposed change; the workspace backs up and applies it on approval.
    case codeApply(relativePath: String, originalContent: String, newContent: String)
    /// Run a project check inside the bounded workspace (SWARM-004 wiring).
    /// The command is validated by the policy engine's deny-list before the
    /// user approves; output publishes to state.studioCheckResult.
    case runCheck(command: String, workspaceID: String?)

    /// True for a check-run execution — drives the Studio panel's terminal
    /// state (result/error banner) on approval or denial.
    var isRunCheck: Bool {
        if case .runCheck = self { return true }
        return false
    }
}

/// A proposed action awaiting user approval. Rendered in the ActionApprovalView
/// with a preview/diff and approve/deny controls. Logged to EventLedger on decision.
struct PendingAction: Identifiable, Sendable {
    let id = UUID()
    let summary: String           // Human-readable one-liner (e.g. "Navigate to github.com")
    let detail: String            // Full description of what will happen
    let preview: String           // Diff, URL change, or visual preview
    let trustLevel: EventLedgerStore.TrustLevel
    let timestamp: Date = Date()
    let actionKind: EventLedgerStore.ActionKind

    /// Source context — which Honeycomb node or page triggered this action.
    let sourceNodeID: String?

    /// What actually runs on approval. nil = record-only action (e.g. a
    /// T0/T1 auto-approved proposal with nothing to execute).
    let execution: PendingActionExecution?

    /// SWARM-004: the structured envelope the policy engine evaluates BEFORE
    /// this action may reach the panel or execute. Producers that attach an
    /// envelope get a real policy verdict; envelope-less actions keep the
    /// legacy trust-level ladder only.
    let toolInvocation: ToolInvocation?

    /// The policy engine's verdict reason, surfaced in the approval panel
    /// (e.g. "requires explicit user approval before execution").
    let policyNote: String?

    init(
        summary: String,
        detail: String,
        preview: String,
        trustLevel: EventLedgerStore.TrustLevel,
        actionKind: EventLedgerStore.ActionKind,
        sourceNodeID: String? = nil,
        execution: PendingActionExecution? = nil,
        toolInvocation: ToolInvocation? = nil,
        policyNote: String? = nil
    ) {
        self.summary = summary
        self.detail = detail
        self.preview = preview
        self.trustLevel = trustLevel
        self.actionKind = actionKind
        self.sourceNodeID = sourceNodeID
        self.execution = execution
        self.toolInvocation = toolInvocation
        self.policyNote = policyNote
    }

    /// Returns a copy carrying a policy verdict note for the approval panel.
    /// PendingAction is immutable; the policy engine attaches the note only
    /// after it has actually evaluated the envelope (SWARM-004).
    func withPolicyNote(_ note: String) -> PendingAction {
        PendingAction(
            summary: summary,
            detail: detail,
            preview: preview,
            trustLevel: trustLevel,
            actionKind: actionKind,
            sourceNodeID: sourceNodeID,
            execution: execution,
            toolInvocation: toolInvocation,
            policyNote: note
        )
    }
}

// MARK: - SessionGrant (SWARM-005)

/// A session-scoped pre-approval for one tool. Grants are in-memory by
/// design (they die with the session — a fresh launch always asks again),
/// recorded in the EventLedger as consentGranted/consentRevoked, and can
/// only downgrade `requiresConfirmation` verdicts — they never override a
/// policy denial (the hard boundary stays intact).
struct SessionGrant: Identifiable, Sendable {
    let id: UUID
    let toolID: String
    /// The exact structured invocation scope approved by the user. This is
    /// intentionally immutable: changing a command, path, workspace, or
    /// payload requires a new approval.
    let approvalScopeKey: String
    let summary: String
    let createdAt: Date

    init(id: UUID = UUID(), toolID: String, approvalScopeKey: String, summary: String, createdAt: Date = Date()) {
        self.id = id
        self.toolID = toolID
        self.approvalScopeKey = approvalScopeKey
        self.summary = summary
        self.createdAt = createdAt
    }
}

// MARK: - ActionApprovalView
///
/// Renders a pending action with a preview, trust-level badge, and explicit
/// Approve/Deny buttons. Every decision is logged to EventLedger for audit.
///
/// This is the "Act" step of the demo spine: show → ask → act with visible
/// permissions and provenance.
struct ActionApprovalView: View {
    @Environment(BrowserState.self) private var state

    let action: PendingAction

    @State private var isProcessing = false
    @State private var decisionResult: String?
    /// "Allow for this session" checkbox — grants the presented tool a
    /// session-scoped pre-approval (SWARM-005).
    @State private var grantForSession = false

    var body: some View {
        VStack(spacing: 0) {
            // Header with trust level badge
            HStack(spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .font(HiveDesign.Typography.subHeadingSemiBold)
                    .foregroundStyle(HiveDesign.Accent.primary)
                    .accessibilityHidden(true)

                Text("Action Approval")
                    .font(HiveDesign.Typography.heading)

                Spacer()

                // Trust level pill
                trustBadge

                Button(action: handleDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(HiveDesign.Typography.subHeading)
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing)
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if let result = decisionResult {
                // Already decided
                decidedView(result: result)
            } else {
                actionDetailView
            }
        }
        .frame(width: 420, height: 480)
        .background(HiveDesign.Material.panel)
        .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.xl, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 10, x: 0, y: 5)
    }

    // MARK: - Trust Badge

    private var trustBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: trustIcon)
                .font(HiveDesign.Typography.microLabelBold)
                .accessibilityHidden(true)
            Text(trustLabel)
                .font(HiveDesign.Typography.captionSemiBold)
        }
        .foregroundStyle(trustColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(trustColor.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .accessibilityLabel("Trust Level: \(trustLabel)")
    }

    private var trustLabel: String {
        switch action.trustLevel {
        case .t0: return "T0 · Observe"
        case .t1: return "T1 · Suggest"
        case .t2: return "T2 · Assist"
        case .t3: return "T3 · Act"
        case .t4: return "T4 · Privileged"
        case .t5: return "T5 · Developer"
        }
    }

    private var trustIcon: String {
        switch action.trustLevel {
        case .t0, .t1: return "eye"
        case .t2: return "hand.raised"
        case .t3: return "gearshape"
        case .t4, .t5: return "exclamationmark.shield"
        }
    }

    private var trustColor: Color {
        switch action.trustLevel {
        case .t0, .t1: return .green
        case .t2: return .blue
        case .t3: return .orange
        case .t4, .t5: return .red
        }
    }

    // MARK: - Action Detail

    private var actionDetailView: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // What is happening
                    VStack(alignment: .leading, spacing: 8) {
                        Label("What", systemImage: "questionmark.bubble")
                            .font(HiveDesign.Typography.sectionHeader)
                            .foregroundStyle(HiveDesign.Text.secondary)

                        Text(action.summary)
                            .font(HiveDesign.Typography.subHeadingSemiBold)

                        Text(action.detail)
                            .font(HiveDesign.Typography.sidebarItem)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HiveDesign.Surface.level2)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Preview / Diff
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Preview", systemImage: "text.alignleft")
                            .font(HiveDesign.Typography.sectionHeader)
                            .foregroundStyle(HiveDesign.Text.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            Text(action.preview.isEmpty ? "(no preview available)" : action.preview)
                                .font(HiveDesign.Typography.monoSmall)
                                .foregroundStyle(action.preview.isEmpty ? .tertiary : .primary)
                                .padding(10)
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color.black.opacity(0.2))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .padding(12)
                    .background(HiveDesign.Surface.level1)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Tool / policy (SWARM-004) — shown when the action
                    // carries a structured envelope.
                    if let tool = action.toolInvocation {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Tool", systemImage: "wrench.and.screwdriver")
                                .font(HiveDesign.Typography.sectionHeader)
                                .foregroundStyle(HiveDesign.Text.secondary)
                            Text(tool.toolID)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(HiveDesign.Accent.primary.opacity(0.12))
                                .foregroundStyle(HiveDesign.Accent.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                            if let note = action.policyNote {
                                Text(note)
                                    .font(HiveDesign.Typography.smallLabel)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(HiveDesign.Surface.level1)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }

                    // Safety info
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Safety", systemImage: "shield.checkered")
                            .font(HiveDesign.Typography.sectionHeader)
                            .foregroundStyle(HiveDesign.Text.secondary)

                        safetyRow("checkmark", "This action will be logged to EventLedger")
                        safetyRow("hand.raised", "Nothing runs until you approve")
                        if action.trustLevel == .t4 || action.trustLevel == .t5 {
                            safetyRow("exclamationmark.shield", "Privileged — affects another app or your system")
                        }
                    }
                    .padding(12)
                    .background(HiveDesign.Surface.level1)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(16)
            }

            Divider()

            // Session-grant row (SWARM-005): for the presented tool, offer
            // the pre-approve checkbox or show the active grant with a
            // revoke action. The panel only ever presents confirmation-
            // required actions (`.allowed` verdicts auto-execute without a
            // panel), so the checkbox always accompanies a real consent
            // moment — keep that invariant if a producer changes later.
            // NOTE: granted tools auto-execute in requestApproval BEFORE the
            // panel ever presents, so this row is defense-in-depth — it is
            // only visible if a future "always confirm" exception presents an
            // already-granted tool. The chips row below is the real revoke
            // surface; do not "simplify" this branch away.
            if let toolID = action.toolInvocation?.toolID,
               let grant = action.toolInvocation.flatMap({ invocation in
                   state.sessionGrants.first(where: {
                       $0.toolID == invocation.toolID &&
                       $0.approvalScopeKey == invocation.approvalScopeKey
                   })
               }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(HiveDesign.Accent.primary)
                    Text("\(toolID) allowed for this exact action")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(HiveDesign.Text.tertiary)
                        .help(grant.summary)
                    Spacer()
                    Button {
                        Task { await state.revokeGrant(for: grant) }
                    } label: {
                        Text("Revoke")
                    }
                        .buttonStyle(.plain)
                        .font(HiveDesign.Typography.buttonCaption)
                        .foregroundStyle(.red.opacity(0.8))
                        .accessibilityLabel("Revoke \(toolID) session grant")
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            } else if action.toolInvocation?.toolID != nil {
                HStack(spacing: 6) {
                    Toggle(isOn: $grantForSession) {
                        Text("Allow for this session")
                            .font(HiveDesign.Typography.caption)
                            .foregroundStyle(HiveDesign.Text.tertiary)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.mini)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
            }

            // All active session grants — revoke any of them (SWARM-005).
            // Chips scroll horizontally so many grants can't clip the fixed
            // 420pt panel width.
            if !state.sessionGrants.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Session grants")
                        .font(HiveDesign.Typography.microLabelBold)
                        .foregroundStyle(HiveDesign.Text.tertiary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(state.sessionGrants) { grant in
                                HStack(spacing: 3) {
                                    Text(grant.toolID)
                                        .font(HiveDesign.Typography.monoMicro)
                                        .foregroundStyle(HiveDesign.Text.secondary)
                                    Button {
                                        Task { await state.revokeGrant(for: grant) }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(HiveDesign.Typography.microLabelSecondary)
                                            .foregroundStyle(HiveDesign.Text.tertiary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Revoke \(grant.toolID) for this session")
                                    .accessibilityLabel("Revoke \(grant.toolID) session grant")
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(HiveDesign.Surface.level2)
                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                .help("Approved \(grant.createdAt.formatted(.relative(presentation: .named))): \(grant.summary)")
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 2)
            }

            // Action buttons
            HStack(spacing: 12) {
                Button(action: deny) {
                    HStack(spacing: 6) {
                        Image(systemName: "xmark")
                            .accessibilityHidden(true)
                        Text("Deny")
                    }
                    .font(HiveDesign.Typography.bodySemiBold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.bordered)
                .tint(.red)
                .disabled(isProcessing)
                .accessibilityLabel("Deny this action")

                Button(action: approve) {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark")
                            .accessibilityHidden(true)
                        Text("Approve")
                    }
                    .font(HiveDesign.Typography.bodySemiBold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .tint(HiveDesign.Accent.primary)
                .disabled(isProcessing)
                .accessibilityLabel("Approve this action")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Decided view

    private func decidedView(result: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: result == "auditUnavailable"
                  ? "exclamationmark.triangle.fill"
                  : (result == "approved" ? "checkmark.circle.fill" : "xmark.circle.fill"))
                .font(HiveDesign.Typography.heroDisplayXL)
                .foregroundStyle(result == "auditUnavailable"
                                 ? .orange
                                 : (result == "approved" ? .green : .red))
                .accessibilityLabel(result == "auditUnavailable" ? "Audit unavailable" : (result == "approved" ? "Approved" : "Denied"))
            Text(result == "auditUnavailable"
                 ? "Not Run — Audit Unavailable"
                 : (result == "approved" ? "Action Approved" : "Action Denied"))
                .font(HiveDesign.Typography.dialogTitleBold)
            Text(result == "auditUnavailable"
                 ? "Nothing ran and the action remains pending. Try again when EventLedger is available."
                 : "Logged to EventLedger for audit trail.")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(.secondary)
            Button("Close") { state.dismissApprovalPanel() }
                .buttonStyle(.borderedProminent)
                .tint(HiveDesign.Accent.primary)
                .padding(.top, 8)
                .accessibilityLabel("Close approval panel")
            Spacer()
        }
    }

    // MARK: - Actions

    private func approve() {
        isProcessing = true
        Task {
            // Pre-approve for the session BEFORE executing, so the ledger order
            // is consentGranted → action. One task owns the sequence; a second
            // detached task here would race the action ledger record.
            if grantForSession, let invocation = action.toolInvocation {
                await state.grantSessionAccess(for: invocation, summary: action.summary)
            }
            let recorded = await state.recordApproval(action: action, approved: true)
            await MainActor.run {
                decisionResult = recorded ? "approved" : "auditUnavailable"
                isProcessing = false
            }
        }
    }

    private func deny() {
        isProcessing = true
        Task {
            let recorded = await state.recordApproval(action: action, approved: false)
            await MainActor.run {
                decisionResult = recorded ? "denied" : "auditUnavailable"
                isProcessing = false
            }
        }
    }

    /// Close path for the header X. Once a decision is recorded the panel
    /// stays open so the confirmation is actually seen; X just closes it.
    /// While the action is still pending, X is an implicit deny — dismissing
    /// an approval prompt means the action must not run, so record the denial
    /// to the ledger and clear the queue (AGENTS.md §16.2 deny path).
    private func handleDismiss() {
        guard decisionResult == nil else {
            state.dismissApprovalPanel()
            return
        }
        isProcessing = true
        Task {
            let recorded = await state.recordApproval(action: action, approved: false)
            await MainActor.run {
                isProcessing = false
                if recorded {
                    state.dismissApprovalPanel()
                } else {
                    decisionResult = "auditUnavailable"
                }
            }
        }
    }

    // MARK: - Helpers

    private func safetyRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(HiveDesign.Typography.caption)
                .foregroundStyle(.green.opacity(0.7))
                .frame(width: 14)
            Text(text)
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Approval Queue

/// A simple in-memory queue of pending actions for the current session.
/// Uses @Observable for Swift 6 concurrency (no Combine dependency).
@MainActor
@Observable
final class ApprovalQueue {
    var pending: [PendingAction] = []
    var history: [PendingAction] = []

    func submit(_ action: PendingAction) {
        pending.append(action)
    }

    func remove(_ action: PendingAction) {
        pending.removeAll { $0.id == action.id }
        history.append(action)
        // Decisions are durably in the ledger; this is a convenience ring buffer.
        if history.count > 50 { history.removeFirst(history.count - 50) }
    }
}
