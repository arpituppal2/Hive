import Foundation

public struct BackgroundWorkerStatus: Codable, Hashable, Sendable {
    public var label: String
    public var helperPath: String
    public var launchAgentPlistPath: String
    public var outLogPath: String
    public var errLogPath: String
    public var isInstalled: Bool
    public var plistTargetsCurrentHelper: Bool
    public var nextScheduledRun: Date
    public var lastOutputLine: String?
    public var lastErrorLine: String?

    public init(
        label: String,
        helperPath: String,
        launchAgentPlistPath: String,
        outLogPath: String,
        errLogPath: String,
        isInstalled: Bool,
        plistTargetsCurrentHelper: Bool,
        nextScheduledRun: Date,
        lastOutputLine: String?,
        lastErrorLine: String?
    ) {
        self.label = label
        self.helperPath = helperPath
        self.launchAgentPlistPath = launchAgentPlistPath
        self.outLogPath = outLogPath
        self.errLogPath = errLogPath
        self.isInstalled = isInstalled
        self.plistTargetsCurrentHelper = plistTargetsCurrentHelper
        self.nextScheduledRun = nextScheduledRun
        self.lastOutputLine = lastOutputLine
        self.lastErrorLine = lastErrorLine
    }

    public var installState: String {
        if !isInstalled { return "Not installed" }
        return plistTargetsCurrentHelper ? "Installed" : "Installed for a different app path"
    }
}

public struct BackgroundWorkerMonitor: Sendable {
    public var label: String
    public var scheduler: DailyScheduler
    public var homeDirectory: URL?

    public init(
        label: String = "com.hive.daemon",
        scheduler: DailyScheduler = DailyScheduler(),
        homeDirectory: URL? = nil
    ) {
        self.label = label
        self.scheduler = scheduler
        self.homeDirectory = homeDirectory
    }

    public func status(helperPath: String, now: Date = Date()) -> BackgroundWorkerStatus {
        #if os(macOS)
        let home = homeDirectory ?? FileManager.default.homeDirectoryForCurrentUser
        #else
        let home = homeDirectory ?? FileManager.default.temporaryDirectory
        #endif
        let launchAgentPlist = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
        let logDirectory = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Logs", isDirectory: true)
            .appendingPathComponent("Hive", isDirectory: true)
        let outLog = logDirectory.appendingPathComponent("daemon.out.log")
        let errLog = logDirectory.appendingPathComponent("daemon.err.log")
        let installed = FileManager.default.fileExists(atPath: launchAgentPlist.path)
        return BackgroundWorkerStatus(
            label: label,
            helperPath: helperPath,
            launchAgentPlistPath: launchAgentPlist.path,
            outLogPath: outLog.path,
            errLogPath: errLog.path,
            isInstalled: installed,
            plistTargetsCurrentHelper: installed && plistProgramArguments(at: launchAgentPlist).contains(helperPath),
            nextScheduledRun: scheduler.nextRun(after: now),
            lastOutputLine: lastNonEmptyLine(in: outLog),
            lastErrorLine: lastNonEmptyLine(in: errLog)
        )
    }

    private func plistProgramArguments(at url: URL) -> [String] {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let dict = plist as? [String: Any],
              let arguments = dict["ProgramArguments"] as? [String] else {
            return []
        }
        return arguments
    }

    private func lastNonEmptyLine(in url: URL) -> String? {
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        let text = String(decoding: data.suffix(16_384), as: UTF8.self)
        return text
            .components(separatedBy: .newlines)
            .reversed()
            .first { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }
}
