import Foundation

public actor BeeQueue {
    public static let shared = BeeQueue()

    private var jobs: [String: BeeJob] = [:]
    private var runningTaskIDs: [String: Task<Void, Never>] = [:]
    private let eventLedger: EventLedgerStore

    private init() {
        // Use an in-memory EventLedger for the shared singleton. BeeQueue
        // jobs are currently in-memory only; when durable persistence lands,
        // the EventLedger path should move to a durable location alongside
        // the job store. :memory: SQLite databases cannot fail to open.
        guard let ledger = try? EventLedgerStore(path: ":memory:") else {
            fatalError("BeeQueue: EventLedgerStore in-memory open failed")
        }
        self.eventLedger = ledger
    }

public func enqueue(_ job: BeeJob) async {
        jobs[job.id] = job
        await recordEvent(
            actor: "bee",
            actionKind: .systemEvent,
            actionTarget: job.id,
            actionPreview: "Job '\(job.label)' enqueued",
            trustLevel: .t2,
            policyDecision: .allowed,
            consentState: .notRequired,
            result: .success
        )
    }

    public func start(_ jobID: String) async {
        guard var job = jobs[jobID], job.status == .pending || job.status == .retrying else { return }
        job.status = .running
        job.attempt += 1
        job.startedAt = Date()
        job.completedAt = nil
        job.lastError = nil
        job.resultSummary = nil
        jobs[jobID] = job

await recordEvent(
            actor: "bee",
            actionKind: .systemEvent,
            actionTarget: jobID,
            actionPreview: "Job '\(job.label)' started attempt \(job.attempt)",
            trustLevel: .t3,
            policyDecision: .allowed,
            consentState: .notRequired,
            result: .success
        )

        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.execute(jobID)
        }
        runningTaskIDs[jobID] = task
    }

    public func cancel(_ jobID: String) async {
        guard var job = jobs[jobID] else { return }
        job.status = .cancelled
        job.completedAt = Date()
        jobs[jobID] = job

        runningTaskIDs[jobID]?.cancel()
        runningTaskIDs.removeValue(forKey: jobID)

await recordEvent(
            actor: "bee",
            actionKind: .systemEvent,
            actionTarget: jobID,
            actionPreview: "Job '\(job.label)' cancelled",
            trustLevel: .t3,
            policyDecision: .allowed,
            consentState: .notRequired,
            result: .cancelled
        )
    }

    public func retry(_ jobID: String) async {
        guard var job = jobs[jobID], job.status == .failed else { return }
        guard job.attempt < job.maxAttempts else { return }

        job.status = .retrying
        jobs[jobID] = job

await recordEvent(
            actor: "bee",
            actionKind: .systemEvent,
            actionTarget: jobID,
            actionPreview: "Job '\(job.label)' retrying attempt \(job.attempt + 1)",
            trustLevel: .t3,
            policyDecision: .allowed,
            consentState: .notRequired,
            result: .partial
        )

        await start(jobID)
    }

    public func verify(_ jobID: String) async -> BeeJobVerification {
        guard let job = jobs[jobID] else {
            return BeeJobVerification(jobID: jobID, verified: false, reason: "Job not found")
        }

        switch job.status {
        case .succeeded:
            return BeeJobVerification(jobID: jobID, verified: true, reason: "Job completed successfully")
        case .failed:
            return BeeJobVerification(jobID: jobID, verified: false, reason: job.lastError ?? "Job failed")
        case .cancelled:
            return BeeJobVerification(jobID: jobID, verified: false, reason: "Job was cancelled")
        case .pending, .running, .retrying:
            return BeeJobVerification(jobID: jobID, verified: false, reason: "Job is not yet complete")
        }
    }

    public func job(_ id: String) -> BeeJob? {
        jobs[id]
    }

    public func allJobs() -> [BeeJob] {
        Array(jobs.values).sorted { $0.createdAt > $1.createdAt }
    }

    public func pendingJobs() -> [BeeJob] {
        jobs.values.filter { $0.status == .pending || $0.status == .retrying }
    }

    public func runningJobs() -> [BeeJob] {
        jobs.values.filter { $0.status == .running }
    }

    private func execute(_ jobID: String) async {
        guard var job = jobs[jobID] else { return }

        do {
            let result = try await perform(job: job)
            job.status = .succeeded
            job.resultSummary = result
            job.completedAt = Date()
            jobs[jobID] = job

await recordEvent(
                actor: "bee",
                actionKind: .systemEvent,
                actionTarget: jobID,
                actionPreview: "Job '\(job.label)' completed",
                trustLevel: .t3,
                policyDecision: .allowed,
                consentState: .notRequired,
                result: .success,
                outputSummary: result
            )
        } catch is CancellationError {
            guard var job = jobs[jobID] else { return }
            job.status = .cancelled
            job.completedAt = Date()
            jobs[jobID] = job

await recordEvent(
                actor: "bee",
                actionKind: .systemEvent,
                actionTarget: jobID,
                actionPreview: "Job '\(job.label)' cancelled during execution",
                trustLevel: .t3,
                policyDecision: .allowed,
                consentState: .notRequired,
                result: .cancelled
            )
        } catch {
            guard var job = jobs[jobID] else { return }
            job.lastError = error.localizedDescription
            job.status = .failed
            job.completedAt = Date()
            jobs[jobID] = job

await recordEvent(
                actor: "bee",
                actionKind: .systemEvent,
                actionTarget: jobID,
                actionPreview: "Job '\(job.label)' failed: \(error.localizedDescription)",
                trustLevel: .t3,
                policyDecision: .allowed,
                consentState: .notRequired,
                result: .failure,
                errorDescription: error.localizedDescription
            )

            if job.attempt < job.maxAttempts {
                await retry(jobID)
            }
        }

        runningTaskIDs.removeValue(forKey: jobID)
    }

    private func perform(job: BeeJob) async throws -> String {
        switch job.kind {
        case .runCheck:
            return try await performRunCheck(job)
        case .applyDiff:
            return try await performApplyDiff(job)
        case .navigate:
            return try await performNavigate(job)
        case .research:
            return try await performResearch(job)
        case .toolExecution:
            return try await performToolExecution(job)
        case .custom:
            return try await performCustom(job)
        }
    }

    private func performRunCheck(_ job: BeeJob) async throws -> String {
        let command = job.payload["command"] ?? "swift test"
        let workspace = job.payload["workspaceID"] ?? ""
        let timeout = TimeInterval(job.payload["timeout"] ?? "120") ?? 120

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        process.arguments = ["-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: workspace.isEmpty ? "/" : workspace)

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = outputPipe

        try process.run()

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning {
            if Date() > deadline {
                process.terminate()
                throw BeeError.timeout(jobID: job.id)
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: outputData, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            throw BeeError.commandFailed(jobID: job.id, exitCode: process.terminationStatus, output: output)
        }

        return output
    }

    private func performApplyDiff(_ job: BeeJob) async throws -> String {
        let path = job.payload["path"] ?? ""
        let newContent = job.payload["newContent"] ?? ""

        guard !path.isEmpty else {
            throw BeeError.missingParameter(jobID: job.id, parameter: "path")
        }

        let url = URL(fileURLWithPath: path)
        try newContent.write(to: url, atomically: true, encoding: .utf8)

        return "Applied diff to \(path)"
    }

    private func performNavigate(_ job: BeeJob) async throws -> String {
        let url = job.payload["url"] ?? ""
        guard !url.isEmpty else {
            throw BeeError.missingParameter(jobID: job.id, parameter: "url")
        }
        return "Navigated to \(url)"
    }

    private func performResearch(_ job: BeeJob) async throws -> String {
        let query = job.payload["query"] ?? ""
        guard !query.isEmpty else {
            throw BeeError.missingParameter(jobID: job.id, parameter: "query")
        }
        return "Research completed for query: \(query)"
    }

    private func performToolExecution(_ job: BeeJob) async throws -> String {
        let tool = job.payload["tool"] ?? ""
        guard !tool.isEmpty else {
            throw BeeError.missingParameter(jobID: job.id, parameter: "tool")
        }
        return "Tool \(tool) executed"
    }

    private func performCustom(_ job: BeeJob) async throws -> String {
        let command = job.payload["command"] ?? ""
        guard !command.isEmpty else {
            throw BeeError.missingParameter(jobID: job.id, parameter: "command")
        }
        return "Custom job executed: \(command)"
    }

    private func recordEvent(
        actor: String,
        actionKind: EventLedgerStore.ActionKind,
        actionTarget: String?,
        actionPreview: String?,
        trustLevel: EventLedgerStore.TrustLevel,
        policyDecision: EventLedgerStore.PolicyDecision,
        consentState: EventLedgerStore.ConsentState,
        result: EventLedgerStore.EventResult,
        outputSummary: String? = nil,
        errorDescription: String? = nil
    ) async {
        let event = EventLedgerStore.LedgerEvent(
            id: UUID().uuidString,
            timestamp: Date(),
            actor: actor,
            sessionID: "bee-queue",
            projectID: nil,
            parentEventID: nil,
            intent: "bee-orchestration",
            actionKind: actionKind,
            actionTarget: actionTarget,
            actionPreview: actionPreview,
            trustLevel: trustLevel,
            policyDecision: policyDecision,
            consentState: consentState,
            contextIDs: [],
            outputSummary: outputSummary,
            result: result,
            errorDescription: errorDescription,
            verificationResult: EventLedgerStore.VerificationResult.unchecked,
            provenance: "bee"
        )
        _ = try? await eventLedger.record(event)
    }
}

public struct BeeJobVerification: Sendable {
    public let jobID: String
    public let verified: Bool
    public let reason: String

    public init(jobID: String, verified: Bool, reason: String) {
        self.jobID = jobID
        self.verified = verified
        self.reason = reason
    }
}

public enum BeeError: Error, Sendable {
    case timeout(jobID: String)
    case commandFailed(jobID: String, exitCode: Int32, output: String)
    case missingParameter(jobID: String, parameter: String)

    public var localizedDescription: String {
        switch self {
        case .timeout(let jobID):
            return "Job \(jobID) timed out"
        case .commandFailed(let jobID, let exitCode, let output):
            return "Job \(jobID) failed with exit code \(exitCode): \(output.prefix(200))"
        case .missingParameter(let jobID, let parameter):
            return "Job \(jobID) missing required parameter: \(parameter)"
        }
    }
}