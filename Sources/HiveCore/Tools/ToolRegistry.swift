import Foundation

// MARK: - ToolRegistry (SWARM-004)

/// The typed tool registry — SWARM-004's "structured tool protocol" (§7.4).
///
/// A tool is a *typed, registered capability*, never a regex-matched chat
/// command. Every tool declares:
/// - typed input fields (name, type, required, description),
/// - a risk class (read / draft / act / privileged / developer),
/// - idempotency, timeout, and an optional rollback kind,
/// - whether it requires explicit user confirmation.
///
/// The registry is the single admission point: `invoke` rejects any tool ID
/// that is not registered. There is no string-matching fallback — a tool the
/// registry does not know is simply not a tool. This is the hard boundary
/// AGENTS.md §7.4 calls for ("no command regex is privileged").
public actor ToolRegistry {

    // MARK: - Public types

    /// Risk class maps to the trust-level ladder (§9.3). A tool's risk class
    /// fixes the minimum trust level its invocations may carry — the policy
    /// engine cannot be talked into a lower trust level.
    public enum RiskClass: String, Sendable, Codable, CaseIterable {
        case read        // T0/T1 — safe reads (page metadata, graph query)
        case draft       // T2 — reversible local drafts (unsent file draft)
        case act         // T3 — approved mutations (apply diff, run test)
        case privileged  // T4 — other apps / system surface (send, account)
        case developer   // T5 — irreversible / destructive (delete, config)

        /// The minimum trust level an invocation of this tool may carry.
        public var minimumTrustLevel: EventLedgerStore.TrustLevel {
            switch self {
            case .read: return .t0
            case .draft: return .t2
            case .act: return .t3
            case .privileged: return .t4
            case .developer: return .t5
            }
        }
    }

    /// A typed input field of a tool's argument schema.
    public struct InputField: Sendable, Codable, Equatable, Identifiable {
        public enum FieldType: String, Sendable, Codable {
            case string
            case integer
            case double
            case bool
            case filePath
            case url
            case json
            /// A shell command string that must pass the destructive-command
            /// deny-list before execution. Free-form commands at T3 are only
            /// acceptable behind this guard + explicit confirmation.
            case command
        }

        public var id: String { name }
        public let name: String
        public let type: FieldType
        public let required: Bool
        public let description: String

        public init(name: String, type: FieldType, required: Bool = true, description: String = "") {
            self.name = name
            self.type = type
            self.required = required
            self.description = description
        }

        /// Validates a raw value against this field's type. The typed-value
        /// gate: a filePath must be a relative path (no `..` escapes, no
        /// leading `/` — the worker scope resolves it); a url must parse and
        /// be http(s); an integer must be a whole number.
        public func validate(_ value: ToolValue) -> Bool {
            switch type {
            case .string:
                if case .string = value { return true }
                return false
            case .integer:
                if case .integer = value { return true }
                return false
            case .double:
                switch value {
                case .double, .integer: return true
                default: return false
                }
            case .bool:
                if case .bool = value { return true }
                return false
            case .filePath:
                guard case .string(let raw) = value else { return false }
                return Self.isSafeRelativePath(raw)
            case .url:
                guard case .string(let raw) = value,
                      let url = URL(string: raw),
                      let scheme = url.scheme?.lowercased() else { return false }
                return scheme == "http" || scheme == "https"
            case .json:
                if case .string(let raw) = value,
                   let data = raw.data(using: .utf8) {
                    return (try? JSONSerialization.jsonObject(with: data)) != nil
                }
                return false
            case .command:
                guard case .string(let raw) = value else { return false }
                return Self.isSafeCommand(raw)
            }
        }

        /// Rejects destructive shell patterns so a free-form check command
        /// cannot silently become `rm -rf` or a shell pipe. This is a guard,
        /// not a sandbox: the worker still runs in a bounded workspace, but
        /// the deny-list removes the obvious destructive classes up front.
        public static func isSafeCommand(_ raw: String) -> Bool {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            let lower = trimmed.lowercased()
            let destructiveTokens = [
                "rm ", " rm", "rm -rf", "rmdir ", "unlink ", "shred ",
                "sudo ", "mkfs", "dd if=", "chmod -r", "chown -r", "| xargs",
                "> /dev/", "2> /dev/", "> /etc/", "2> /etc/",
                "curl ", "wget ", "nc ", "bash <", "sh <",
                "| sh", "| bash", "| zsh", "&&", "||", ";",
                "`", "$( "
            ]
            // `swift test` / `swift build` never contain these tokens. Bare
            // `>` / `<` are deliberately NOT blocked: `swift test 2>&1` and
            // `grep x < file` are ordinary, harmless check patterns — only
            // the dangerous redirection targets (device, /etc) are.
            // The `curl`/`wget` guard is broad: a check command that fetches
            // remote code is out of scope for a bounded project check.
            // Note: this is a contains-based guard, so a *quoted string*
            // containing a destructive token (e.g. `echo "rm -rf"`) is also
            // rejected. That conservative false positive is intentional —
            // do not "fix" it into a bypass.
            return !destructiveTokens.contains { lower.contains($0) }
        }

        /// A safe relative path: non-empty, no leading `/`, no `..` component,
        /// no scheme prefix, no drive/colon or backslash escapes. Path
        /// traversal is a first-class denial reason.
        public static func isSafeRelativePath(_ raw: String) -> Bool {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("/"), !trimmed.contains("..") else {
                return false
            }
            guard !trimmed.contains("://") else { return false }
            // macOS-relative paths never carry a drive colon (`C:\evil`) or a
            // backslash escape (`..\\etc`). Rejecting both costs nothing and
            // removes an entire class of cross-platform traversal.
            guard !trimmed.contains(":"), !trimmed.contains("\\") else { return false }
            return true
        }
    }

    /// The registered tool definition.
    public struct Tool: Sendable, Codable, Identifiable, Equatable {
        public let id: String          // stable ID, e.g. "file.write"
        public let title: String
        public let summary: String
        public let riskClass: RiskClass
        public let inputFields: [InputField]
        public let idempotent: Bool
        public let timeoutSeconds: Int
        public let rollbackKind: String?  // "git.restore_or_patch", "backup", nil
        public let requiresConfirmation: Bool

        public init(
            id: String,
            title: String,
            summary: String,
            riskClass: RiskClass,
            inputFields: [InputField] = [],
            idempotent: Bool = false,
            timeoutSeconds: Int = 30,
            rollbackKind: String? = nil,
            requiresConfirmation: Bool = false
        ) {
            self.id = id
            self.title = title
            self.summary = summary
            self.riskClass = riskClass
            self.inputFields = inputFields
            self.idempotent = idempotent
            self.timeoutSeconds = timeoutSeconds
            self.rollbackKind = rollbackKind
            self.requiresConfirmation = requiresConfirmation
        }
    }

    /// A typed argument value. Never a free-form string blob for privileged
    /// tools — the field schema decides what a value may be.
    public enum ToolValue: Sendable, Codable, Equatable {
        case string(String)
        case integer(Int)
        case double(Double)
        case bool(Bool)

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if let s = try? container.decode(String.self) { self = .string(s); return }
            if let i = try? container.decode(Int.self) { self = .integer(i); return }
            if let d = try? container.decode(Double.self) { self = .double(d); return }
            if let b = try? container.decode(Bool.self) { self = .bool(b); return }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "ToolValue must be a string, integer, double, or bool"
            )
        }

        public func encode(to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            switch self {
            case .string(let s): try container.encode(s)
            case .integer(let i): try container.encode(i)
            case .double(let d): try container.encode(d)
            case .bool(let b): try container.encode(b)
            }
        }

        public var displayText: String {
            switch self {
            case .string(let s): return s
            case .integer(let i): return String(i)
            case .double(let d): return String(d)
            case .bool(let b): return b ? "true" : "false"
            }
        }
    }

    // MARK: - State

    private var tools: [String: Tool] = [:]

    public init() {}

    /// Registers a tool. Later registrations with the same ID replace the
    /// earlier one (the registry is the source of truth for capability).
    public func register(_ tool: Tool) {
        tools[tool.id] = tool
    }

    /// Registers many tools at once.
    public func register(_ tools: [Tool]) {
        for tool in tools { register(tool) }
    }

    /// Returns a registered tool by ID, or nil.
    public func tool(named id: String) -> Tool? {
        tools[id]
    }

    /// All registered tools, sorted by ID for stable presentation.
    public func allTools() -> [Tool] {
        tools.values.sorted { $0.id < $1.id }
    }

    /// Whether a tool ID is registered. The hard boundary: anything not here
    /// is not a tool.
    public func isRegistered(_ id: String) -> Bool {
        tools[id] != nil
    }

    // MARK: - The built-in registry

    /// The default capability set. This is the honest, typed answer to
    /// "what can Swarm do": reads, drafts, approved mutations, and the
    /// privileged/developer rungs — each with a schema and a risk class.
    /// Connector and OS tools are added as their platforms land.
    ///
    /// `async` because `register` is actor-isolated; static context cannot
    /// call it synchronously.
    /// The canonical default tool set — shared by `defaultRegistry()` and by
    /// app-side registries that must be populated without a fresh instance
    /// (the browser state's policy gate registers these on first evaluation).
    public static let defaultTools: [Tool] = [
            // ── Read (T0/T1) ──────────────────────────────────────────────
            Tool(
                id: "honeycomb.query",
                title: "Query memory",
                summary: "Search Honeycomb knowledge graph (FTS5 + typed filter).",
                riskClass: .read,
                inputFields: [
                    InputField(name: "query", type: .string, description: "Full-text query"),
                    InputField(name: "limit", type: .integer, required: false, description: "Max results"),
                ],
                idempotent: true,
                timeoutSeconds: 10
            ),
            Tool(
                id: "browser.read",
                title: "Read page",
                summary: "Read current page metadata, title, and URL.",
                riskClass: .read,
                inputFields: [
                    InputField(name: "tabID", type: .string, required: false, description: "Target tab; defaults to active"),
                ],
                idempotent: true,
                timeoutSeconds: 10
            ),
            Tool(
                id: "studio.read",
                title: "Read project file",
                summary: "Read a file inside the selected Studio workspace root.",
                riskClass: .read,
                inputFields: [
                    InputField(name: "workspaceID", type: .string, required: false, description: "Target workspace"),
                    InputField(name: "path", type: .filePath, description: "Relative path in workspace"),
                ],
                idempotent: true,
                timeoutSeconds: 15
            ),

            // ── Draft (T2) ───────────────────────────────────────────────
            Tool(
                id: "studio.draft",
                title: "Draft file change",
                summary: "Create an unsent draft of a file change in the workspace.",
                riskClass: .draft,
                inputFields: [
                    InputField(name: "workspaceID", type: .string, required: false, description: "Target workspace"),
                    InputField(name: "path", type: .filePath, description: "Relative path in workspace"),
                    InputField(name: "content", type: .string, description: "Proposed file content"),
                ],
                idempotent: true,
                timeoutSeconds: 15,
                rollbackKind: "draft.discard"
            ),

            // ── Act (T3, explicit approval) ──────────────────────────────
            Tool(
                id: "studio.apply",
                title: "Apply file change",
                summary: "Apply an approved diff to a workspace file (backed up first).",
                riskClass: .act,
                inputFields: [
                    InputField(name: "workspaceID", type: .string, required: false, description: "Target workspace"),
                    InputField(name: "path", type: .filePath, description: "Relative path in workspace"),
                    InputField(name: "newContent", type: .string, description: "New file content"),
                ],
                idempotent: false,
                timeoutSeconds: 30,
                rollbackKind: "git.restore_or_patch",
                requiresConfirmation: true
            ),
            Tool(
                id: "studio.runCheck",
                title: "Run project check",
                summary: "Run the user-approved build/test command in the bounded workspace.",
                riskClass: .act,
                inputFields: [
                    InputField(name: "workspaceID", type: .string, required: false, description: "Target workspace"),
                    InputField(name: "command", type: .command, description: "Check command (must pass the deny-list)"),
                    InputField(name: "timeoutSeconds", type: .integer, required: false, description: "Override timeout"),
                ],
                idempotent: true,
                timeoutSeconds: 120,
                requiresConfirmation: true
            ),
            Tool(
                id: "browser.navigate",
                title: "Navigate tab",
                summary: "Navigate the active tab to a URL.",
                riskClass: .act,
                inputFields: [
                    InputField(name: "url", type: .url, description: "Destination URL"),
                ],
                idempotent: true,
                timeoutSeconds: 15,
                requiresConfirmation: true
            ),

            // ── Privileged (T4) ──────────────────────────────────────────
            Tool(
                id: "os.notify",
                title: "Send notification",
                summary: "Show a local notification (never sends external messages).",
                riskClass: .privileged,
                inputFields: [
                    InputField(name: "title", type: .string, description: "Notification title"),
                    InputField(name: "body", type: .string, required: false, description: "Notification body"),
                ],
                idempotent: true,
                timeoutSeconds: 10
            ),

            // ── Developer (T5, disabled by default in policy) ────────────
            Tool(
                id: "workspace.delete",
                title: "Delete workspace file",
                summary: "Permanently delete a file in the selected workspace.",
                riskClass: .developer,
                inputFields: [
                    InputField(name: "workspaceID", type: .string, required: false, description: "Target workspace"),
                    InputField(name: "path", type: .filePath, description: "Relative path in workspace"),
                ],
                idempotent: false,
                timeoutSeconds: 15,
                rollbackKind: nil,
                requiresConfirmation: true
            ),
        ]

    public static func defaultRegistry() async -> ToolRegistry {
        let registry = ToolRegistry()
        await registry.register(Self.defaultTools)
        return registry
    }
}
