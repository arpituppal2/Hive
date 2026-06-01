import Foundation
import HiveCore

struct HiveDaemon {
    let paths: HivePaths
    let store: HiveStore
    let ingestion: IngestionCoordinator
    let controlPlane: ControlPlane
    let knowledgeLoop: KnowledgeLoop
    let profiler = RuntimeProfiler()
    let policy = RuntimePolicy()

    init() throws {
        paths = try HivePaths.applicationSupport()
        try paths.createDirectories()
        store = try HiveStore(databaseURL: paths.database)
        ingestion = IngestionCoordinator(paths: paths, store: store)
        controlPlane = ControlPlane(store: store, paths: paths)
        knowledgeLoop = KnowledgeLoop(store: store, paths: paths)
    }

    func runOnce(manual: Bool) throws {
        let profile = profiler.currentProfile(foregroundUserActive: false)
        let extractionDecision = policy.decision(for: .lightExtraction, profile: profile, manual: manual)
        guard extractionDecision.allowed else {
            print("HiveDaemon paused: \(extractionDecision.reason)")
            return
        }

        _ = try store.scrubLegacyPrivacyAuditDetails()
        let purged = try controlPlane.purgeExpiredRawInputs()
        try ingestion.processPending(limit: extractionDecision.maxConcurrentJobs * 8)
        let graph = try knowledgeLoop.updateDerivedKnowledge()
        print("HiveDaemon complete: purged=\(purged) nodes=\(graph.nodes.count) edges=\(graph.edges.count)")
    }

    func runScheduled() throws {
        let schedule = HiveMaintenanceSchedule.load()
        guard schedule.enabled else {
            print("HiveDaemon maintenance disabled")
            return
        }
        let defaults = HiveMaintenanceSchedule.makeSharedDefaults()
        let lastRun = defaults.object(forKey: HiveMaintenanceSchedule.lastRunKey) as? Date
        let now = Date()
        guard schedule.shouldRun(lastRun: lastRun, now: now) else {
            print("HiveDaemon maintenance not due until \(schedule.nextRun(after: now))")
            return
        }
        try runConfiguredSourcePlugins(now: now)
        try runOnce(manual: false)
        let briefing = try HiveAutomationOrchestrator(store: store, paths: paths).runMorningBriefing(now: now)
        print("HiveDaemon morning briefing: \(briefing.title)")
        defaults.set(now, forKey: HiveMaintenanceSchedule.lastRunKey)
    }

    func runConfiguredSourcePlugins(now: Date) throws {
        let request = HiveStartupSourcePluginCatalog.load()
        guard request.canRunWithoutPicker else {
            return
        }
        let result = try HiveStartupSourcePluginBackend().execute(
            request: request,
            paths: paths,
            store: store,
            ingestionEngine: ingestion,
            now: now,
            processImmediately: true
        )
        print("HiveDaemon source plugins: \(result.summary)")
    }

    func importApprovedBrowserData(includeAppUsage: Bool = false) throws {
        let request = HiveStartupSourcePluginRequest(
            selections: HiveStartupSourcePluginCatalog.orderedKinds.map {
                HiveStartupSourcePluginSelection(
                    kind: $0,
                    isEnabled: $0 == .browserHistory || (includeAppUsage && $0 == .appUsage)
                )
            },
            pasteLocation: "",
            prompt: ""
        )
        let result = try HiveStartupSourcePluginBackend().execute(
            request: request,
            paths: paths,
            store: store,
            ingestionEngine: ingestion,
            processImmediately: true
        )
        try ingestion.processPending(limit: 250)
        let graph = try knowledgeLoop.updateDerivedKnowledge()
        let label = includeAppUsage ? "local context import" : "browser import"
        print("HiveDaemon \(label): \(result.summary) nodes=\(graph.nodes.count) edges=\(graph.edges.count)")
    }

    func importAppUsageSnapshot(at url: URL?) throws {
        let data: Data
        if let url {
            data = try Data(contentsOf: url)
        } else {
            data = FileHandle.standardInput.readDataToEndOfFile()
        }
        let importer = AppUsageSnapshotImporter(paths: paths, store: store)
        let snapshot = try importer.decodeSnapshotJSON(data)
        if let source = try importer.importSnapshot(snapshot) {
            try ingestion.processPending(limit: 50)
            let graph = try knowledgeLoop.updateDerivedKnowledge()
            print("HiveDaemon app usage import: source=\(source.id) nodes=\(graph.nodes.count) edges=\(graph.edges.count)")
        } else {
            print("HiveDaemon app usage import: no app context rows")
        }
    }

    func importMemorySeed(at url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        guard let seed = AIMemorySeedParser().parse(text) else {
            throw NSError(
                domain: "HiveDaemon",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "File is not a valid Hive memory seed or question-priority JSON."]
            )
        }
        let imported = try ingestion.ingest(urls: [url])
        for original in imported {
            var source = original
            source.connector = "ai-memory-import"
            source.title = source.title.localizedCaseInsensitiveContains("memory")
                ? source.title
                : "AI Memory Seed - \(source.title)"
            source.status = .extracted
            try store.saveSource(source)
            _ = try store.deleteAutogeneratedDerivedDataForMemoryImport(sourceID: source.id)
            let summary = try AIMemorySeedImporter(store: store).persist(seed: seed, source: source)
            print("HiveDaemon imported memory seed: entities=\(summary.entityCount) claims=\(summary.claimCount) pages=\(summary.pageCount)")
        }
        let graph = try knowledgeLoop.updateDerivedKnowledge()
        print("HiveDaemon memory seed refresh: nodes=\(graph.nodes.count) edges=\(graph.edges.count)")
    }

    func importFiles(at urls: [URL]) throws {
        guard !urls.isEmpty else {
            throw NSError(
                domain: "HiveDaemon",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "--import-files requires one or more file paths."]
            )
        }
        let imported = try ingestion.ingest(urls: urls, processImmediately: true)
        try ingestion.processPending(limit: max(250, imported.count * 2))
        let graph = try knowledgeLoop.updateDerivedKnowledge()
        print("HiveDaemon file import: sources=\(imported.count) nodes=\(graph.nodes.count) edges=\(graph.edges.count)")
    }

    func fullForgetSources(ids: [String]) throws {
        guard !ids.isEmpty else {
            throw NSError(
                domain: "HiveDaemon",
                code: 4,
                userInfo: [NSLocalizedDescriptionKey: "--full-forget-source requires one or more source IDs."]
            )
        }
        for id in ids {
            try controlPlane.fullForgetSource(id: id)
        }
        let graph = try knowledgeLoop.updateDerivedKnowledge()
        print("HiveDaemon full forget: sources=\(ids.count) nodes=\(graph.nodes.count) edges=\(graph.edges.count)")
    }

    func runLoop() throws {
        while true {
            let schedule = HiveMaintenanceSchedule.load()
            guard schedule.enabled else {
                print("HiveDaemon maintenance disabled; checking again in 1 hour")
                Thread.sleep(forTimeInterval: 3_600)
                continue
            }
            let now = Date()
            let next = schedule.nextRun(after: now)
            let delay = max(10, next.timeIntervalSince(now))
            print("HiveDaemon sleeping until \(next)")
            Thread.sleep(forTimeInterval: delay)
            try runScheduled()
        }
    }
}

do {
    let daemon = try HiveDaemon()
    let orderedArgs = Array(CommandLine.arguments.dropFirst())
    let args = Set(orderedArgs)
    if let importIndex = orderedArgs.firstIndex(of: "--import-memory-seed") {
        guard orderedArgs.indices.contains(importIndex + 1) else {
            throw NSError(
                domain: "HiveDaemon",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "--import-memory-seed requires a file path."]
            )
        }
        try daemon.importMemorySeed(at: URL(fileURLWithPath: orderedArgs[importIndex + 1]))
    } else if let importIndex = orderedArgs.firstIndex(of: "--import-files") {
        let fileArgs = orderedArgs.dropFirst(importIndex + 1).filter { !$0.hasPrefix("--") }
        try daemon.importFiles(at: fileArgs.map { URL(fileURLWithPath: $0) })
    } else if let importIndex = orderedArgs.firstIndex(of: "--import-app-usage-json") {
        let url: URL?
        if orderedArgs.indices.contains(importIndex + 1), orderedArgs[importIndex + 1] != "-" {
            url = URL(fileURLWithPath: orderedArgs[importIndex + 1])
        } else {
            url = nil
        }
        try daemon.importAppUsageSnapshot(at: url)
    } else if let forgetIndex = orderedArgs.firstIndex(of: "--full-forget-source") {
        let sourceIDs = orderedArgs.dropFirst(forgetIndex + 1).filter { !$0.hasPrefix("--") }
        try daemon.fullForgetSources(ids: Array(sourceIDs))
    } else if args.contains("--import-local-context") {
        try daemon.importApprovedBrowserData(includeAppUsage: true)
    } else if args.contains("--import-browser-data") {
        try daemon.importApprovedBrowserData()
    } else if args.contains("--scheduled") {
        try daemon.runScheduled()
    } else if args.contains("--loop") {
        try daemon.runLoop()
    } else {
        try daemon.runOnce(manual: args.contains("--manual"))
    }
} catch {
    fputs("HiveDaemon error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
