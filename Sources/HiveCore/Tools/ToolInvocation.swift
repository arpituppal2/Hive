import Foundation

// MARK: - ToolInvocation: the structured action envelope (§7.4)

/// The typed action envelope from AGENTS.md §7.4 — the wire format for every
/// tool call, replacing string-matching natural-language commands. A tool
/// invocation is *data*, not intent soup: it names a registered tool, carries
/// typed arguments, a preview, the trust level it requests, whether it needs
/// confirmation, a rollback plan, and the evidence (Honeycomb node IDs) that
/// grounds it.
///
/// ```json
/// {
///   "action_id": "uuid",
///   "kind": "file.write",
///   "target": { "workspace_id": "uuid", "path": "relative/path.swift" },
///   "preview": { "diff": "..." },
///   "trust_level": "t3",
///   "requires_confirmation": true,
///   "rollback": { "kind": "git.restore_or_patch" },
///   "evidence": ["source:uuid", "test:uuid"]
/// }
/// ```
///
/// Target/argument keys MUST match the registered tool's schema field names
/// exactly (camelCase, e.g. `workspaceID`, `newContent`). The PolicyEngine's
/// undeclared-argument check runs on `allValues` (arguments + target merged),
/// so any key the tool's schema does not declare — including snake_case
/// forms like `workspace_id` from older docs — is rejected before execution.
public struct ToolInvocation: Sendable, Codable, Identifiable, Equatable {

    public let id: String                       // action_id
    public let toolID: String                   // kind — must be a registered tool
    public let arguments: [String: ToolRegistry.ToolValue]
    /// The typed target (workspace ID + path etc.). Kept as a flat dictionary
    /// so the envelope stays Codable without schema-typed target structs per
    /// tool; the tool's input fields give the argument semantics.
    public let target: [String: ToolRegistry.ToolValue]
    /// Human-readable preview (diff, URL change, etc.) — what the approval
    /// panel shows before any execution.
    public let preview: String?
    public let trustLevel: EventLedgerStore.TrustLevel
    public let requiresConfirmation: Bool
    public let rollback: RollbackPlan?
    public let evidence: [String]               // Honeycomb node IDs
    public let sourceNodeID: String?            // which node/page triggered this
    public let createdAt: Date

    public struct RollbackPlan: Sendable, Codable, Equatable {
        public let kind: String                 // "git.restore_or_patch", "backup", "draft.discard"
        public let detail: String?              // e.g. backup path
        public init(kind: String, detail: String? = nil) {
            self.kind = kind
            self.detail = detail
        }
    }

    public init(
        id: String = UUID().uuidString,
        toolID: String,
        arguments: [String: ToolRegistry.ToolValue] = [:],
        target: [String: ToolRegistry.ToolValue] = [:],
        preview: String? = nil,
        trustLevel: EventLedgerStore.TrustLevel,
        requiresConfirmation: Bool = false,
        rollback: RollbackPlan? = nil,
        evidence: [String] = [],
        sourceNodeID: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.toolID = toolID
        self.arguments = arguments
        self.target = target
        self.preview = preview
        self.trustLevel = trustLevel
        self.requiresConfirmation = requiresConfirmation
        self.rollback = rollback
        self.evidence = evidence
        self.sourceNodeID = sourceNodeID
        self.createdAt = createdAt
    }

    /// All argument values merged from `arguments` and `target` (target wins
    /// on collision — the target is the explicit destination).
    public var allValues: [String: ToolRegistry.ToolValue] {
        arguments.merging(target) { _, new in new }
    }

    /// Stable, value-sensitive identity for a user approval grant.
    ///
    /// A session grant is permission for this exact structured invocation, not
    /// a blanket permission for every future call to the tool. Canonical
    /// sorted JSON avoids delimiter collisions and preserves typed values;
    /// dictionary insertion order therefore cannot change the approved scope.
    /// The action ID and creation timestamp are deliberately excluded so a
    /// retried request with the same effective action can reuse its grant.
    public var approvalScopeKey: String {
        encodedApprovalScopeKey ?? ""
    }

    /// False means the invocation is not eligible to create or consume a
    /// session grant. Keeping this separate from the display/audit key makes
    /// the fail-closed rule explicit at every grant call site.
    public var hasGrantableApprovalScope: Bool {
        encodedApprovalScopeKey != nil
    }

    private var encodedApprovalScopeKey: String? {
        var encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.nonConformingFloatEncodingStrategy = .convertToString(
            positiveInfinity: "infinity",
            negativeInfinity: "-infinity",
            nan: "nan"
        )
        let payload = ApprovalScopePayload(
            toolID: toolID,
            values: allValues,
            trustLevel: trustLevel,
            requiresConfirmation: requiresConfirmation,
            rollback: rollback
        )
        // The built-in value types are expected to encode, but this property
        // is part of a security boundary: an unexpected future value type must
        // fail closed rather than crash the browser or produce a broad key.
        guard let data = try? encoder.encode(payload) else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}

private struct ApprovalScopePayload: Codable {
    let toolID: String
    let values: [String: ToolRegistry.ToolValue]
    let trustLevel: EventLedgerStore.TrustLevel
    let requiresConfirmation: Bool
    let rollback: ToolInvocation.RollbackPlan?
}

// MARK: - Canonical factories (the app's approved producers)

/// The application-facing producers construct envelopes ONLY through these
/// factories, so the schema (field names, trust levels, confirmation flags)
/// cannot drift between HiveCore and the UI layer. Each factory's output is
/// locked by ToolInvocationFactoryTests against the default registry.
extension ToolInvocation {

    /// The `studio.apply` envelope — the diff IS the preview the user approves.
    public static func studioApply(
        path: String,
        newContent: String,
        workspaceID: String?,
        diff: String
    ) -> ToolInvocation {
        ToolInvocation(
            toolID: "studio.apply",
            arguments: [
                "path": .string(path),
                "newContent": .string(newContent),
            ],
            target: workspaceID.map { ["workspaceID": .string($0)] } ?? [:],
            preview: diff,
            trustLevel: .t3,
            requiresConfirmation: true,
            rollback: RollbackPlan(
                kind: "git.restore_or_patch",
                detail: "Original backed up by StudioWorkspace before write"
            )
        )
    }

    /// The `studio.runCheck` envelope. The command is validated by the policy
    /// engine's `.command` deny-list BEFORE it is presented for approval.
    public static func studioRunCheck(
        command: String,
        workspaceID: String?,
        timeout: Int = 60
    ) -> ToolInvocation {
        ToolInvocation(
            toolID: "studio.runCheck",
            arguments: [
                "command": .string(command),
                "timeoutSeconds": .integer(timeout),
            ],
            target: workspaceID.map { ["workspaceID": .string($0)] } ?? [:],
            preview: "Command:\n$ \(command)\n\nRuns inside the selected Studio workspace with a \(timeout)s timeout.",
            trustLevel: .t3,
            requiresConfirmation: true
        )
    }

    /// The `browser.navigate` envelope for AI-proposed navigation.
    public static func browserNavigate(url: URL, preview: String? = nil) -> ToolInvocation {
        ToolInvocation(
            toolID: "browser.navigate",
            arguments: ["url": .string(url.absoluteString)],
            preview: preview ?? "Navigate to \(url.absoluteString)",
            trustLevel: .t3,
            requiresConfirmation: true
        )
    }
}
