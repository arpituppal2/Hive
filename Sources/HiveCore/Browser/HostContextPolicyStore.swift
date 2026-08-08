import Foundation

/// Durable local storage for host-scoped Swarm page visibility decisions.
///
/// The store is intentionally tiny and origin-only. It does not retain page
/// content, paths, query strings, fragments, credentials, history, cookies,
/// screenshots, or model output. Missing and malformed files resolve to the
/// safe empty policy until the user explicitly changes a setting.
public actor HostContextPolicyStore {
    private struct Envelope: Codable {
        let version: Int
        let decisions: [String: HostContextPolicy.Decision]
    }

    private static let currentVersion = 1
    private let fileURL: URL
    private let persistenceOverride: (@Sendable (Data, URL) -> Bool)?
    private var policy: HostContextPolicy
    private var lastMutationSequence: UInt64 = 0
    /// Synchronously available bootstrap snapshot for browser state. The actor
    /// remains authoritative for all later mutations; exposing this immutable
    /// Sendable value avoids a privacy-permissive window while the UI boots.
    public nonisolated let initialPolicy: HostContextPolicy

    public init(
        path: URL? = nil,
        persistenceOverride: (@Sendable (Data, URL) -> Bool)? = nil
    ) {
        let resolvedURL = path ?? Self.defaultURL()
        let loadedPolicy = Self.load(from: resolvedURL)
        self.fileURL = resolvedURL
        self.persistenceOverride = persistenceOverride
        self.policy = loadedPolicy
        self.initialPolicy = loadedPolicy
    }

    /// Returns the saved decision for this URL, or `.default` for invalid/non-web URLs.
    public func decision(for url: URL?) -> HostContextPolicy.Decision {
        policy.decision(for: url)
    }

    /// Returns the current effective decision map for diagnostics and tests.
    /// Values are canonical-origin keyed and never contain raw URL input.
    public func origins() -> [String] {
        policy.decisions.keys.sorted()
    }

    /// Sets a decision for a canonical web origin. `.default` removes the
    /// origin instead of persisting a redundant value. Returns false when the
    /// URL cannot produce a safe HTTP(S) origin.
    @discardableResult
    public func set(
        _ decision: HostContextPolicy.Decision,
        for url: URL?,
        sequence: UInt64? = nil
    ) -> Bool {
        guard let updated = policy.setting(decision, for: url) else { return false }
        let previousPolicy = policy
        let previousSequence = lastMutationSequence
        if let sequence {
            // Browser-state mutations carry a MainActor generation. Reject an
            // older task that arrives after a newer task, so durable state can
            // never regress even when asynchronous writes complete out of order.
            guard sequence >= lastMutationSequence else { return false }
            lastMutationSequence = sequence
        }
        guard updated != policy else { return true }
        policy = updated
        guard persist() else {
            // A failed write must not leave runtime admission different from
            // durable policy. Roll back both state and sequencing metadata.
            policy = previousPolicy
            lastMutationSequence = previousSequence
            return false
        }
        return true
    }

    /// Removes one origin decision. Returns false only for an invalid URL or a
    /// failed persistence operation.
    @discardableResult
    public func reset(for url: URL?) -> Bool {
        set(.default, for: url)
    }

    /// Removes every saved host decision and persists the empty policy.
    @discardableResult
    public func resetAll() -> Bool {
        guard !policy.decisions.isEmpty else { return true }
        let previousPolicy = policy
        policy = HostContextPolicy()
        guard persist() else {
            policy = previousPolicy
            return false
        }
        return true
    }

    /// Test/support diagnostic: the file location, never included in model context.
    public nonisolated var path: URL { fileURL }

    private func persist() -> Bool {
        let envelope = Envelope(version: Self.currentVersion, decisions: policy.decisions)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(envelope) else { return false }

        if let persistenceOverride {
            return persistenceOverride(data, fileURL)
        }

        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let temporaryURL = directory.appendingPathComponent(
                ".\(fileURL.lastPathComponent).\(UUID().uuidString).tmp"
            )
            try data.write(to: temporaryURL, options: [.atomic])
            defer { try? FileManager.default.removeItem(at: temporaryURL) }

            if FileManager.default.fileExists(atPath: fileURL.path) {
                _ = try FileManager.default.replaceItemAt(
                    fileURL,
                    withItemAt: temporaryURL,
                    backupItemName: nil,
                    options: .usingNewMetadataOnly
                )
            } else {
                try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
            }
            return true
        } catch {
            return false
        }
    }

    private static func load(from url: URL) -> HostContextPolicy {
        guard let data = try? Data(contentsOf: url),
              let envelope = try? JSONDecoder().decode(Envelope.self, from: data),
              envelope.version == currentVersion else {
            return HostContextPolicy()
        }
        return HostContextPolicy(decisions: envelope.decisions)
    }

    private static func defaultURL() -> URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("Hive", isDirectory: true)
            .appendingPathComponent("host_context_policy.json")
    }
}
