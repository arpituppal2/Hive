import Foundation

// MARK: - PolicyEngine (SWARM-004)

/// The gate between a proposed tool invocation and any execution. Per
/// AGENTS.md §7.4 the policy engine "evaluates trust level before a tool
/// receives executable arguments" — this is the non-bypassable check that
/// runs on every `ToolInvocation` before a worker sees it.
///
/// Decisions:
/// - `.allowed` — T0/T1 reads and idempotent low-risk calls, and T3+ calls
///   the approval controller has already cleared.
/// - `.requiresConfirmation` — the tool or the trust level demands explicit
///   user consent first (the approval panel renders preview + Approve/Deny).
/// - `.denied` — unregistered tool, schema violation, path traversal, or the
///   requested trust level is below the tool's risk floor.
/// - `.escalated` — T5 developer tools are disabled by default; only an
///   explicit policy override admits them.
public struct PolicyEngine: Sendable {

    /// Whether T5 (developer) tools are allowed at all. Off by default —
    /// irreversible operations must be explicitly enabled.
    public var allowsDeveloperTools: Bool

    public init(allowsDeveloperTools: Bool = false) {
        self.allowsDeveloperTools = allowsDeveloperTools
    }

    // MARK: - Verdict

    public struct Verdict: Sendable, Equatable {
        public enum Decision: String, Sendable, Equatable {
            case allowed
            case requiresConfirmation
            case denied
            case escalated
        }

        public let decision: Decision
        /// Human-readable reason — shown in the approval panel and recorded
        /// in the EventLedger's policy decision field.
        public let reason: String
        /// The tool's risk-floor trust level (nil when the tool is unknown).
        public let requiredTrustLevel: EventLedgerStore.TrustLevel?

        public init(decision: Decision, reason: String, requiredTrustLevel: EventLedgerStore.TrustLevel? = nil) {
            self.decision = decision
            self.reason = reason
            self.requiredTrustLevel = requiredTrustLevel
        }

        public static let allowed = Verdict(decision: .allowed, reason: "Allowed", requiredTrustLevel: nil)

        public static func denied(_ reason: String) -> Verdict {
            Verdict(decision: .denied, reason: reason)
        }
    }

    // MARK: - Evaluation

    /// Evaluates a proposed invocation against the registry. This is the only
    /// path that decides whether a tool may run; workers never decide their
    /// own permissions (§7.4 Worker row).
    public func evaluate(_ invocation: ToolInvocation, registry: ToolRegistry) async -> Verdict {
        guard let tool = await registry.tool(named: invocation.toolID) else {
            return .denied("Unregistered tool '\(invocation.toolID)'. Only registered tools may execute.")
        }

        // T5 gate: developer tools are disabled by default.
        if tool.riskClass == .developer && !allowsDeveloperTools {
            return Verdict(
                decision: .escalated,
                reason: "Developer tool '\(tool.id)' is disabled by default. Enable developer tools to use it.",
                requiredTrustLevel: tool.riskClass.minimumTrustLevel
            )
        }

        // Trust floor: the invocation may not carry a trust level below the
        // tool's risk class.
        if invocation.trustLevel.rank < tool.riskClass.minimumTrustLevel.rank {
            return Verdict(
                decision: .denied,
                reason: "Tool '\(tool.id)' requires at least \(tool.riskClass.minimumTrustLevel.rawValue) "
                    + "(\(tool.riskClass.rawValue)) but the invocation only carries \(invocation.trustLevel.rawValue).",
                requiredTrustLevel: tool.riskClass.minimumTrustLevel
            )
        }

        // Schema: every required field must be present and typed correctly,
        // and NO undeclared argument may ride along. A tool call carrying a
        // key the schema doesn't declare is denied — if a worker ever reads
        // undeclared keys, that would be a bypass vector.
        let declared = Set(tool.inputFields.map(\.name))
        let supplied = Set(invocation.allValues.keys)
        let undeclared = supplied.subtracting(declared)
        if !undeclared.isEmpty {
            let sorted = undeclared.sorted().joined(separator: ", ")
            return .denied("Undeclared argument(s) for '\(tool.id)': \(sorted).")
        }
        var missing: [String] = []
        var invalid: [String] = []
        for field in tool.inputFields {
            guard let value = invocation.allValues[field.name] else {
                if field.required { missing.append(field.name) }
                continue
            }
            if !field.validate(value) {
                invalid.append(field.name)
            }
        }
        if !missing.isEmpty {
            return .denied("Missing required argument(s) for '\(tool.id)': \(missing.joined(separator: ", ")).")
        }
        if !invalid.isEmpty {
            return .denied("Invalid argument(s) for '\(tool.id)': \(invalid.joined(separator: ", ")).")
        }

        // Confirmation: the tool declares it, or the trust level demands it.
        if tool.requiresConfirmation || invocation.requiresConfirmation {
            return Verdict(
                decision: .requiresConfirmation,
                reason: "Tool '\(tool.id)' requires explicit user approval before execution.",
                requiredTrustLevel: tool.riskClass.minimumTrustLevel
            )
        }

        return .allowed
    }
}

// MARK: - Trust level rank

extension EventLedgerStore.TrustLevel {
    /// Numeric rank (T0=0 … T5=5) for policy comparisons — robust against
    /// lexicographic surprises and safe to compare across enum ordering.
    public var rank: Int {
        switch self {
        case .t0: return 0
        case .t1: return 1
        case .t2: return 2
        case .t3: return 3
        case .t4: return 4
        case .t5: return 5
        }
    }
}
