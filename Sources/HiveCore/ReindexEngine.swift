import Foundation

public enum ReindexEnginePhase: String, Codable, Hashable, Sendable {
    case idle
    case auditing
    case extracting
    case deduplicating
    case rebuilding
    case completed
    case failed
}

public struct ReindexEngineReport: Codable, Hashable, Sendable {
    public var phase: ReindexEnginePhase
    public var trustReport: HiveReindexTrustReport

    public init(phase: ReindexEnginePhase, trustReport: HiveReindexTrustReport) {
        self.phase = phase
        self.trustReport = trustReport
    }
}

/// Coordinates trusted re-index execution with thrash protection and phase reporting.
public final class ReindexEngine: @unchecked Sendable {
    private let coordinator: HiveReindexTrustCoordinator
    private let lock = NSLock()
    private var phase: ReindexEnginePhase = .idle
    private var isRunning = false

    public init(
        store: HiveStore,
        ingestion: IngestionCoordinator,
        knowledgeLoop: KnowledgeLoop,
        paths: HivePaths,
        fileManager: FileManager = .default
    ) {
        coordinator = HiveReindexTrustCoordinator(
            store: store,
            ingestion: ingestion,
            knowledgeLoop: knowledgeLoop,
            paths: paths,
            fileManager: fileManager
        )
    }

    public var currentPhase: ReindexEnginePhase {
        lock.lock()
        defer { lock.unlock() }
        return phase
    }

    public var isReindexInProgress: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRunning
    }

    @discardableResult
    public func runTrustedReindex() throws -> ReindexEngineReport {
        lock.lock()
        if isRunning {
            lock.unlock()
            return ReindexEngineReport(
                phase: .idle,
                trustReport: HiveReindexTrustReport(ignoredConcurrentRequest: true)
            )
        }
        isRunning = true
        phase = .auditing
        lock.unlock()

        defer {
            lock.lock()
            isRunning = false
            if phase != .failed {
                phase = .completed
            }
            lock.unlock()
        }

        do {
            setPhase(.auditing)
            setPhase(.extracting)
            let trustReport = try coordinator.run()
            setPhase(.deduplicating)
            setPhase(.rebuilding)
            setPhase(.completed)
            return ReindexEngineReport(phase: .completed, trustReport: trustReport)
        } catch {
            setPhase(.failed)
            throw error
        }
    }

    private func setPhase(_ next: ReindexEnginePhase) {
        lock.lock()
        phase = next
        lock.unlock()
    }
}
