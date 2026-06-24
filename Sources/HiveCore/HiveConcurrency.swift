import Foundation

/// Errors surfaced by the Hive intelligence concurrency model.
public enum HiveIntelligenceError: Error, Sendable {
    /// A bounded operation exceeded its allotted wall-clock budget.
    case timeout
}

// MARK: - IntelligenceActor

/// Serializes access to the Neural Engine so that only a single intelligence
/// operation is ever in flight at a time.
///
/// The Neural Engine cannot meaningfully parallelize the model inference work
/// the rest of Hive relies on. Rather than letting callers contend for the
/// hardware (and thrash), the `IntelligenceActor` hands out exactly one logical
/// permit. Callers either drive the lifecycle manually via `acquire()` /
/// `release()`, or — preferably — wrap their work in `run(_:)`, which guarantees
/// the permit is released even when the operation throws.
public actor IntelligenceActor {
    /// Whether an operation currently holds the single Neural Engine permit.
    private var isProcessing: Bool = false

    /// Callers parked while another operation holds the permit, resumed in
    /// FIFO order as the permit becomes available.
    private var queue: [CheckedContinuation<Void, Never>] = []

    public init() {}

    /// Acquires the single Neural Engine permit, suspending until it is free.
    public func acquire() async {
        if !isProcessing {
            isProcessing = true
            return
        }

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            queue.append(continuation)
        }
    }

    /// Releases the permit, handing it directly to the next waiter if any.
    public func release() {
        if queue.isEmpty {
            isProcessing = false
        } else {
            let continuation = queue.removeFirst()
            continuation.resume()
        }
    }

    /// Runs `operation` while exclusively holding the Neural Engine permit.
    ///
    /// The permit is acquired before the operation begins and released via
    /// `defer` so it is returned even if the operation throws.
    public func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async rethrows -> T {
        await acquire()
        defer { release() }
        return try await operation()
    }
}

// MARK: - FileSystemActor

/// Guarantees that no two tasks write to the same path concurrently.
///
/// Concurrent reads are fine, but overlapping writes to the same file can
/// corrupt on-disk state. This actor tracks the set of paths currently being
/// written and makes any new writer to an active path spin (with a short sleep)
/// until the path frees up.
public actor FileSystemActor {
    /// Paths that currently have an exclusive writer.
    private var activeWritePaths: Set<String> = []

    public init() {}

    /// Runs `operation` with exclusive write access to `path`.
    ///
    /// If another writer holds `path`, this spins — sleeping 50ms between
    /// checks — until the path is free, then claims it for the duration of the
    /// operation. The path is removed via `defer` so it is always released.
    public func withExclusiveWrite<T: Sendable>(
        to path: String,
        _ operation: @Sendable () async throws -> T
    ) async rethrows -> T {
        while activeWritePaths.contains(path) {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }

        activeWritePaths.insert(path)
        defer { activeWritePaths.remove(path) }

        return try await operation()
    }
}

// MARK: - IngestionActor

/// Caps the number of concurrently running ingestion (utility) tasks.
///
/// Ingestion is best-effort background work; running too many sources at once
/// starves the foreground experience. This actor tracks active source ids and
/// lets callers wait for a free slot under a small concurrency cap (the
/// 2-concurrent-utility-task budget from Part 2).
public actor IngestionActor {
    /// Source ids whose ingestion is currently in flight.
    public private(set) var activeSourceIds: Set<Int> = []

    /// Whether a full reindex pass is currently underway.
    public var isReindexing: Bool = false

    public init() {}

    /// Marks a source as actively ingesting.
    public func markActive(_ sourceId: Int) {
        activeSourceIds.insert(sourceId)
    }

    /// Marks a source as no longer ingesting, freeing its slot.
    public func markIdle(_ sourceId: Int) {
        activeSourceIds.remove(sourceId)
    }

    /// Suspends until fewer than `maxConcurrent` ingestion tasks are active.
    public func waitForSlot(maxConcurrent: Int = 2) async {
        while activeSourceIds.count >= maxConcurrent {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }
}

// MARK: - ColonyActor

/// Provides per-article logical locks for the colony (wiki) layer.
///
/// Editing an article involves multiple non-atomic steps; this actor lets a
/// caller claim an article by id so concurrent mutators can detect the conflict
/// and back off rather than clobbering each other.
public actor ColonyActor {
    /// Article identifiers currently held for modification.
    public private(set) var articlesBeingModified: Set<String> = []

    public init() {}

    /// Marks an article as being modified.
    public func lock(_ articleId: String) {
        articlesBeingModified.insert(articleId)
    }

    /// Releases a previously locked article.
    public func unlock(_ articleId: String) {
        articlesBeingModified.remove(articleId)
    }

    /// Reports whether an article is currently locked for modification.
    public func isLocked(_ articleId: String) -> Bool {
        articlesBeingModified.contains(articleId)
    }
}

// MARK: - Timeout

/// Runs `operation`, throwing `HiveIntelligenceError.timeout` if it does not
/// finish within `seconds`.
///
/// This races the operation against a sleeping cancellation task inside a
/// throwing task group. Whichever finishes first wins; the group's remaining
/// task is cancelled before returning so no work is leaked.
public func withTimeout<T: Sendable>(
    seconds: Double,
    operation: @Sendable @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }

        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw HiveIntelligenceError.timeout
        }

        guard let result = try await group.next() else {
            group.cancelAll()
            throw HiveIntelligenceError.timeout
        }

        group.cancelAll()
        return result
    }
}

// MARK: - Global singletons

/// Namespaced global actor singletons for the Hive concurrency model.
///
/// The original spec used bare top-level `let` globals (`intelligence`,
/// `fileSystem`, …). Those would pollute the global scope and collide with
/// existing symbols, so they are gathered under a caseless `enum` namespace.
public enum HiveConcurrency {
    /// Serializes Neural Engine usage.
    public static let intelligence = IntelligenceActor()

    /// Serializes exclusive writes per file path.
    public static let fileSystem = FileSystemActor()

    /// Caps concurrent ingestion (utility) tasks.
    public static let ingestion = IngestionActor()

    /// Provides per-article modification locks.
    public static let colony = ColonyActor()
}
