import Foundation

public enum BeeJobStatus: String, Codable, Sendable, CaseIterable {
    case pending
    case running
    case succeeded
    case failed
    case cancelled
    case retrying
}

public enum BeeJobKind: String, Codable, Sendable, CaseIterable {
    case runCheck
    case applyDiff
    case navigate
    case research
    case toolExecution
    case custom
}

public struct BeeJob: Codable, Sendable, Identifiable, Equatable {
    public let id: String
    public let kind: BeeJobKind
    public let label: String
    public let payload: [String: String]
    public var status: BeeJobStatus
    public var attempt: Int
    public var maxAttempts: Int
    public var lastError: String?
    public var resultSummary: String?
    public let createdAt: Date
    public var startedAt: Date?
    public var completedAt: Date?
    public let provenance: String

    public init(
        id: String = UUID().uuidString,
        kind: BeeJobKind,
        label: String,
        payload: [String: String] = [:],
        status: BeeJobStatus = .pending,
        attempt: Int = 0,
        maxAttempts: Int = 3,
        lastError: String? = nil,
        resultSummary: String? = nil,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        completedAt: Date? = nil,
        provenance: String = "swarm"
    ) {
        self.id = id
        self.kind = kind
        self.label = label
        self.payload = payload
        self.status = status
        self.attempt = attempt
        self.maxAttempts = maxAttempts
        self.lastError = lastError
        self.resultSummary = resultSummary
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.provenance = provenance
    }
}