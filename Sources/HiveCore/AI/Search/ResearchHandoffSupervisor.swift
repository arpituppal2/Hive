import Foundation

// MARK: - Research handoff composition root

/// Owns the durable Swift-side composition of the research handoff boundary.
///
/// This is intentionally an explicit application seam, not an implicit global
/// singleton. The browser lifecycle can construct one instance when its
/// research surface is ready, call `reconcilePending()` after startup, and
/// forward verified worker documents to `ingest(json:)`.
///
/// The worker remains an untrusted input source. This type validates the
/// handoff through `ResearchHandoffAdapter`, but it does not authenticate the
/// Rust process or the NDJSON transport. A future authenticated worker
/// boundary must be added separately.
public actor ResearchHandoffSupervisor {
    public enum SupervisorError: Error, Sendable, Equatable, CustomStringConvertible {
        case emptyPath(label: String)
        case pathsMustBeDistinct
        case directoryCreationFailed(path: String, message: String)
        case keyStore(KeychainHMACKeyStore.StoreError)
        case registry(RetentionCapabilityError)
        case journal(HandoffRecoveryJournal.JournalError)

        public var description: String {
            switch self {
            case .emptyPath(let label):
                return "research handoff \(label) path is empty"
            case .pathsMustBeDistinct:
                return "research handoff registry and recovery journal must use distinct paths"
            case .directoryCreationFailed(let path, let message):
                return "research handoff storage directory \(path) could not be created: \(message)"
            case .keyStore(let error):
                return "research handoff approval key could not be loaded: \(error)"
            case .registry(let error):
                return "research handoff capability registry could not be opened: \(error)"
            case .journal(let error):
                return "research handoff recovery journal could not be opened: \(error)"
            }
        }
    }

    private let approvalAuthority: RetentionCapabilityAuthority
    private let adapter: ResearchHandoffAdapter

    /// Opens the durable handoff stores and loads the selected versioned key.
    ///
    /// Initialization provisions the approval key if it is absent, but does
    /// not reconcile or mutate research data. Call `reconcilePending()` as an
    /// explicit startup step after the rest of the application is ready.
    public init(
        honeycomb: HoneycombStore,
        ledger: EventLedgerStore,
        registryPath: String,
        journalPath: String,
        issuerID: String = "hive-approval-controller",
        keyVersion: KeychainHMACKeyStore.Version = .current,
        keychainAccessGroup: String? = nil,
        keychainBackend: (any HMACKeyMaterialBackend)? = nil
    ) async throws {
        let normalizedRegistryPath = try Self.prepareStoragePath(registryPath, label: "registry")
        let normalizedJournalPath = try Self.prepareStoragePath(journalPath, label: "recovery journal")
        guard normalizedRegistryPath != normalizedJournalPath else {
            throw SupervisorError.pathsMustBeDistinct
        }

        let keyStore = KeychainHMACKeyStore(
            accessGroup: keychainAccessGroup,
            backend: keychainBackend
        )
        let capabilityRegistry: RetentionCapabilityRegistry
        do {
            capabilityRegistry = try RetentionCapabilityRegistry(path: normalizedRegistryPath)
        } catch let error as RetentionCapabilityError {
            throw SupervisorError.registry(error)
        }
        let recoveryJournal: HandoffRecoveryJournal
        do {
            recoveryJournal = try HandoffRecoveryJournal(path: normalizedJournalPath)
        } catch let error as HandoffRecoveryJournal.JournalError {
            throw SupervisorError.journal(error)
        }
        let approvalAuthority: RetentionCapabilityAuthority
        do {
            approvalAuthority = try await keyStore.makeAuthority(
                issuerID: issuerID,
                version: keyVersion
            )
        } catch let error as KeychainHMACKeyStore.StoreError {
            throw SupervisorError.keyStore(error)
        }

        self.approvalAuthority = approvalAuthority
        self.adapter = ResearchHandoffAdapter(
            honeycomb: honeycomb,
            ledger: ledger,
            capabilityRegistry: capabilityRegistry,
            recoveryJournal: recoveryJournal,
            approvalAuthority: approvalAuthority
        )
    }

    /// Ingests a worker-produced handoff after the caller has selected its
    /// privacy, session, project, and already-approved retention capability.
    public func ingest(
        json: Data,
        privacy: ResearchHandoffAdapter.PrivacyScope = .nonPrivate,
        sessionID: String? = nil,
        projectID: String? = nil,
        retentionCapability: RetentionCapability? = nil
    ) async throws -> ResearchHandoffAdapter.IngestedSource {
        try await adapter.ingest(
            json: json,
            privacy: privacy,
            sessionID: sessionID,
            projectID: projectID,
            retentionCapability: retentionCapability
        )
    }

    /// Explicit startup recovery. Initialization deliberately does not call
    /// this because it performs durable reads, possible source writes, and
    /// ledger repairs that the application should schedule and observe.
    public func reconcilePending() async throws -> [ResearchHandoffAdapter.ReconciliationResult] {
        try await adapter.reconcilePending()
    }

    /// Signs a capability after an upstream policy/controller has already
    /// recorded user approval. This method does not decide whether approval is
    /// warranted; its name makes that boundary explicit for callers.
    public func issueApprovedCapability(
        _ capability: RetentionCapability
    ) throws -> RetentionCapability {
        try approvalAuthority.issue(capability)
    }

    /// Exposes the active issuer version for diagnostics and rotation-aware
    /// callers without exposing key material.
    public nonisolated var activeKeyVersion: Int {
        approvalAuthority.keyVersion
    }

    private static func prepareStoragePath(_ path: String, label: String) throws -> String {
        guard !path.isEmpty else {
            throw SupervisorError.emptyPath(label: label)
        }
        guard path == ":memory:" else {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            let parent = url.deletingLastPathComponent()
            do {
                try FileManager.default.createDirectory(
                    at: parent,
                    withIntermediateDirectories: true
                )
            } catch {
                throw SupervisorError.directoryCreationFailed(
                    path: parent.path,
                    message: String(describing: error)
                )
            }
            return url.path
        }
        return path
    }
}
