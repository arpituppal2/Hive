import Foundation

// MARK: - Research handoff coordinator

/// Connects one explicit research-source fetch to the durable handoff
/// supervisor. This is intentionally not a background crawler and does not
/// replace the browser's answer provider: callers choose the URL and invoke
/// this coordinator only after a user-visible research action.
///
/// The production initializer keeps worker transport and durable ingestion
/// behind their existing actors. The injected initializer makes policy and
/// failure behavior testable without launching a process or touching disk.
public struct ResearchHandoffCoordinator: Sendable {
    public struct Result: Sendable, Equatable {
        public let fetched: ResearchWorkerClient.FetchedSource
        public let ingested: ResearchHandoffAdapter.IngestedSource

        public init(
            fetched: ResearchWorkerClient.FetchedSource,
            ingested: ResearchHandoffAdapter.IngestedSource
        ) {
            self.fetched = fetched
            self.ingested = ingested
        }
    }

    public enum CoordinatorError: Error, Sendable, Equatable, CustomStringConvertible, LocalizedError {
        case privateBrowsingNotAllowed
        case unavailable(String)
        case invalidURL

        public var description: String {
            switch self {
            case .privateBrowsingNotAllowed:
                return "research handoff is disabled in private browsing"
            case .unavailable(let reason):
                return "research handoff is unavailable: \(reason)"
            case .invalidURL:
                return "research handoff requires an HTTP(S) URL without credentials"
            }
        }

        public var errorDescription: String? { description }
    }

    public typealias Fetch = @Sendable (URL) async throws -> ResearchWorkerClient.FetchedSource
    public typealias Ingest = @Sendable (
        Data,
        ResearchHandoffAdapter.PrivacyScope,
        String?
    ) async throws -> ResearchHandoffAdapter.IngestedSource

    private let fetch: Fetch
    private let ingest: Ingest

    /// Production composition: the worker and supervisor remain independently
    /// permissioned actors; this value only coordinates one explicit handoff.
    public init(
        worker: ResearchWorkerClient,
        supervisor: ResearchHandoffSupervisor
    ) {
        self.fetch = { url in
            try await worker.fetch(url: url, isPrivateBrowsing: false)
        }
        self.ingest = { payload, privacy, sessionID in
            try await supervisor.ingest(
                json: payload,
                privacy: privacy,
                sessionID: sessionID
            )
        }
    }

    /// Test/composition initializer. Callers must still provide the same
    /// typed fetched source and validated ingestion result as production.
    public init(fetch: @escaping Fetch, ingest: @escaping Ingest) {
        self.fetch = fetch
        self.ingest = ingest
    }

    /// Performs one bounded, non-private source handoff. Session retention is
    /// the only default: no durable project/provenance capability is minted by
    /// this type. A future project-save flow must obtain explicit approval and
    /// pass a capability through `ResearchHandoffSupervisor` itself.
    public func handoff(
        url: URL,
        isPrivateBrowsing: Bool = false,
        sessionID: String? = nil
    ) async throws -> Result {
        guard !isPrivateBrowsing else {
            throw CoordinatorError.privateBrowsingNotAllowed
        }
        guard let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil,
              url.user == nil,
              url.password == nil else {
            throw CoordinatorError.invalidURL
        }

        let fetched = try await fetch(url)
        let payload = try fetched.makeHandoffPayload(
            retentionClass: "session",
            deletionScope: "this_source"
        )
        let ingested = try await ingest(payload, .nonPrivate, sessionID)
        return Result(fetched: fetched, ingested: ingested)
    }
}
