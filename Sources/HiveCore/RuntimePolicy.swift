import Foundation
#if canImport(Darwin)
import Darwin
#endif

public enum WorkloadClass: String, Codable, Sendable {
    case interactive
    case lightExtraction
    case embedding
    case summarization
    case mediaTranscription
    case graphAudit
}

public enum ComputeMode: String, Codable, CaseIterable, Sendable {
    case background
    case balanced
    case maximum
}

public struct RuntimeDecision: Hashable, Sendable {
    public var allowed: Bool
    public var reason: String
    public var maxConcurrentJobs: Int
    public var memoryLimitBytes: UInt64
    public var timeoutSeconds: TimeInterval
    public var selectedModelID: String?

    public init(
        allowed: Bool,
        reason: String,
        maxConcurrentJobs: Int,
        memoryLimitBytes: UInt64,
        timeoutSeconds: TimeInterval,
        selectedModelID: String? = nil
    ) {
        self.allowed = allowed
        self.reason = reason
        self.maxConcurrentJobs = maxConcurrentJobs
        self.memoryLimitBytes = memoryLimitBytes
        self.timeoutSeconds = timeoutSeconds
        self.selectedModelID = selectedModelID
    }
}

public struct RuntimeProfiler: Sendable {
    public init() {}

    public func currentProfile(foregroundUserActive: Bool = true) -> RuntimeProfile {
        let process = ProcessInfo.processInfo
        return RuntimeProfile(
            chipName: machineIdentifier(),
            physicalMemoryBytes: process.physicalMemory,
            processorCount: process.processorCount,
            thermalState: mapThermalState(process.thermalState),
            powerState: .unknown,
            batteryChargeFraction: nil,
            lowPowerModeEnabled: process.isLowPowerModeEnabled,
            foregroundUserActive: foregroundUserActive
        )
    }

    private func mapThermalState(_ state: ProcessInfo.ThermalState) -> RuntimeProfile.ThermalState {
        switch state {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .unknown
        }
    }

    private func machineIdentifier() -> String {
        #if canImport(Darwin)
        var size = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let bytes = model.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
        #else
        return "unknown"
        #endif
    }
}

public struct ModelCatalog: Sendable {
    public var capabilities: [ModelCapability]

    public init(capabilities: [ModelCapability] = ModelCatalog.defaultCapabilities) {
        self.capabilities = capabilities
    }

    public func recommendedModel(for task: String, profile: RuntimeProfile, preferStrongest: Bool = false) -> ModelCapability? {
        let memoryGB = Int(profile.physicalMemoryBytes / 1_073_741_824)
        return capabilities
            .filter { $0.task == task && $0.memoryTierGB <= max(memoryGB, 4) }
            .sorted { left, right in
                if left.installed != right.installed { return left.installed && !right.installed }
                if left.memoryTierGB == right.memoryTierGB { return left.modelName < right.modelName }
                return preferStrongest ? left.memoryTierGB > right.memoryTierGB : left.memoryTierGB < right.memoryTierGB
            }
            .first
    }

    public func resolvingInstalledModels(in modelsDirectory: URL, fileManager: FileManager = .default) -> ModelCatalog {
        let fingerprints = modelFingerprints(in: modelsDirectory, fileManager: fileManager)
        let resolved = capabilities.map { capability in
            var updated = capability
            if capability.installed || fingerprints.contains(where: { fingerprint in
                fingerprint.contains(Self.normalized(capability.id))
                    || fingerprint.contains(Self.normalized(capability.modelName))
            }) {
                updated.installed = true
            }
            return updated
        }
        return ModelCatalog(capabilities: resolved)
    }

    private func modelFingerprints(in modelsDirectory: URL, fileManager: FileManager) -> Set<String> {
        guard fileManager.fileExists(atPath: modelsDirectory.path) else { return [] }
        var fingerprints: Set<String> = []
        if let names = try? fileManager.contentsOfDirectory(atPath: modelsDirectory.path) {
            for name in names.prefix(250) {
                fingerprints.insert(Self.normalized(name))
            }
        }
        guard let enumerator = fileManager.enumerator(
            at: modelsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return fingerprints
        }
        var visited = 0
        for case let url as URL in enumerator {
            visited += 1
            if visited > 500 { break }
            fingerprints.insert(Self.normalized(url.lastPathComponent))
            if ["gguf", "mlmodelc", "safetensors", "mlx"].contains(url.pathExtension.lowercased()) {
                fingerprints.insert(Self.normalized(url.deletingPathExtension().lastPathComponent))
            }
        }
        return fingerprints
    }

    private static func normalized(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined()
    }

    public static let defaultCapabilities: [ModelCapability] = [
        ModelCapability(id: "mlx-qwen3-embedding-0.6b", task: "embedding", modelName: "Qwen3 Embedding 0.6B MLX", memoryTierGB: 8, notes: "Default local MLX embedding candidate."),
        ModelCapability(id: "mlx-bge-m3", task: "embedding", modelName: "BGE-M3 MLX", memoryTierGB: 16, notes: "Higher-quality MLX embedding candidate."),
        ModelCapability(id: "mlx-qwen3-reranker-0.6b", task: "rerank", modelName: "Qwen3 Reranker 0.6B MLX", memoryTierGB: 8, notes: "Use only for important searches."),
        ModelCapability(id: "mlx-qwen3-4b-4bit", task: "chat", modelName: "Qwen3 4B 4-bit MLX", memoryTierGB: 8, notes: "Default background chat/summarization model for base M4."),
        ModelCapability(id: "mlx-qwen2-5-7b-4bit", task: "chat", modelName: "Qwen2.5 7B Instruct 4-bit MLX", memoryTierGB: 16, notes: "Manual higher-quality summarization candidate."),
        ModelCapability(id: "mlx-llama3-8b-4bit", task: "chat", modelName: "Llama 3 8B Instruct 4-bit MLX", memoryTierGB: 15, notes: "Manual higher-quality fallback."),
        ModelCapability(id: "apple-vision-ocr", task: "ocr", modelName: "Apple Vision OCR", memoryTierGB: 4, installed: true, notes: "System framework; local only."),
        ModelCapability(id: "mlx-qwen2-5-vl-3b-4bit", task: "vision", modelName: "Qwen2.5-VL 3B 4-bit MLX", memoryTierGB: 16, notes: "Stronger local MLX vision candidate."),
        ModelCapability(id: "apple-speech-transcriber", task: "transcription", modelName: "Apple Speech Transcriber", memoryTierGB: 4, installed: true, notes: "System framework; local only.")
    ]
}

public struct RuntimePolicy: Sendable {
    public var catalog: ModelCatalog

    public init(catalog: ModelCatalog = ModelCatalog()) {
        self.catalog = catalog
    }

    public func decision(
        for workload: WorkloadClass,
        profile: RuntimeProfile,
        manual: Bool = false,
        computeMode: ComputeMode = .balanced
    ) -> RuntimeDecision {
        if !manual, isBackgroundInference(workload), profile.thermalState != .nominal {
            return RuntimeDecision(
                allowed: false,
                reason: "Hive waits until the device is cool enough to think quietly.",
                maxConcurrentJobs: 1,
                memoryLimitBytes: profile.physicalMemoryBytes / 8,
                timeoutSeconds: 30
            )
        }

        if !manual,
           isBackgroundInference(workload),
           profile.powerState == .battery,
           let batteryChargeFraction = profile.batteryChargeFraction,
           batteryChargeFraction < 0.40 {
            return RuntimeDecision(
                allowed: false,
                reason: "Hive waits for more power before thinking in the background.",
                maxConcurrentJobs: 1,
                memoryLimitBytes: profile.physicalMemoryBytes / 8,
                timeoutSeconds: 30
            )
        }

        if profile.thermalState == .critical || profile.thermalState == .serious {
            return RuntimeDecision(
                allowed: manual && workload == .interactive,
                reason: "Thermal pressure is high.",
                maxConcurrentJobs: 1,
                memoryLimitBytes: profile.physicalMemoryBytes / 8,
                timeoutSeconds: 30
            )
        }

        if profile.lowPowerModeEnabled && !manual && computeMode != .maximum && workload != .lightExtraction {
            return RuntimeDecision(
                allowed: false,
                reason: "Low Power Mode is enabled; background inference is paused.",
                maxConcurrentJobs: 1,
                memoryLimitBytes: profile.physicalMemoryBytes / 8,
                timeoutSeconds: 30
            )
        }

        if profile.foregroundUserActive && !manual && computeMode != .maximum {
            switch workload {
            case .interactive, .lightExtraction:
                break
            default:
                return RuntimeDecision(
                    allowed: false,
                    reason: "User is active; heavy background work waits for idle time.",
                    maxConcurrentJobs: 1,
                    memoryLimitBytes: profile.physicalMemoryBytes / 8,
                    timeoutSeconds: 60
                )
            }
        }

        let task = taskName(for: workload)
        let preferStrongest = computeMode == .maximum || manual || (profile.foregroundUserActive && workload == .interactive)
        let model = catalog.recommendedModel(for: task, profile: profile, preferStrongest: preferStrongest)
        let divisor = memoryDivisor(manual: manual, computeMode: computeMode)
        return RuntimeDecision(
            allowed: true,
            reason: reason(manual: manual, computeMode: computeMode, profile: profile),
            maxConcurrentJobs: concurrencyLimit(processorCount: profile.processorCount, manual: manual, computeMode: computeMode),
            memoryLimitBytes: max(512 * 1_048_576, profile.physicalMemoryBytes / divisor),
            timeoutSeconds: timeout(for: workload, manual: manual),
            selectedModelID: model?.id
        )
    }

    private func taskName(for workload: WorkloadClass) -> String {
        switch workload {
        case .interactive, .summarization: return "chat"
        case .embedding, .graphAudit: return "embedding"
        case .mediaTranscription: return "transcription"
        case .lightExtraction: return "ocr"
        }
    }

    private func isBackgroundInference(_ workload: WorkloadClass) -> Bool {
        switch workload {
        case .summarization, .embedding, .mediaTranscription, .graphAudit:
            return true
        case .interactive, .lightExtraction:
            return false
        }
    }

    private func memoryDivisor(manual: Bool, computeMode: ComputeMode) -> UInt64 {
        switch computeMode {
        case .maximum: return 2
        case .balanced: return manual ? 3 : 5
        case .background: return 7
        }
    }

    private func concurrencyLimit(processorCount: Int, manual: Bool, computeMode: ComputeMode) -> Int {
        switch computeMode {
        case .maximum:
            return max(1, processorCount - 1)
        case .balanced:
            return max(1, min(processorCount / 2, manual ? 6 : 2))
        case .background:
            return 1
        }
    }

    private func reason(manual: Bool, computeMode: ComputeMode, profile: RuntimeProfile) -> String {
        switch computeMode {
        case .maximum:
            return profile.lowPowerModeEnabled
                ? "Maximum local compute is enabled; Low Power Mode is being overridden for this run."
                : "Maximum local compute is enabled; Hive may use stronger local models and most CPU cores."
        case .balanced:
            return manual ? "Manual work is allowed with local limits." : "Background work fits current device policy."
        case .background:
            return "Quiet background mode is enabled; Hive uses one worker and a conservative memory budget."
        }
    }

    private func timeout(for workload: WorkloadClass, manual: Bool) -> TimeInterval {
        switch workload {
        case .interactive: return manual ? 120 : 45
        case .lightExtraction: return 60
        case .embedding: return 180
        case .summarization: return 240
        case .mediaTranscription: return 900
        case .graphAudit: return 600
        }
    }
}

public struct DailyScheduler: Sendable {
    public var hour: Int
    public var minute: Int
    public var calendar: Calendar

    public init(hour: Int = 0, minute: Int = 0, calendar: Calendar = .current) {
        self.hour = hour
        self.minute = minute
        self.calendar = calendar
    }

    public func nextRun(after date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        let today = calendar.date(from: components) ?? date
        if today > date { return today }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? date.addingTimeInterval(86_400)
    }

    public func shouldRunMissedSchedule(lastRun: Date?, now: Date) -> Bool {
        guard let lastRun else { return true }
        let scheduled = previousRun(before: now)
        return lastRun < scheduled
    }

    private func previousRun(before date: Date) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: date)
        components.hour = hour
        components.minute = minute
        components.second = 0
        let today = calendar.date(from: components) ?? date
        if today <= date { return today }
        return calendar.date(byAdding: .day, value: -1, to: today) ?? date.addingTimeInterval(-86_400)
    }
}

public struct HiveMaintenanceSchedule: Codable, Hashable, Sendable {
    public static let defaultsSuiteName = "com.hive.shared"
    public static let enabledKey = "hive.maintenance.enabled"
    public static let hourKey = "hive.maintenance.hour"
    public static let minuteKey = "hive.maintenance.minute"
    public static let lastRunKey = "hive.maintenance.lastRunAt"
    public static let defaultEnabled = true
    public static let defaultHour = 0
    public static let defaultMinute = 0

    public var enabled: Bool
    public var hour: Int
    public var minute: Int

    public init(enabled: Bool = Self.defaultEnabled, hour: Int = Self.defaultHour, minute: Int = Self.defaultMinute) {
        self.enabled = enabled
        self.hour = min(23, max(0, hour))
        self.minute = min(59, max(0, minute))
    }

    public var scheduler: DailyScheduler {
        DailyScheduler(hour: hour, minute: minute)
    }

    public var displayTime: String {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
        guard let date = Calendar.current.date(from: components) else {
            return String(format: "%02d:%02d", hour, minute)
        }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    public func shouldRun(lastRun: Date?, now: Date = Date()) -> Bool {
        enabled && scheduler.shouldRunMissedSchedule(lastRun: lastRun, now: now)
    }

    public func nextRun(after date: Date = Date()) -> Date {
        scheduler.nextRun(after: date)
    }

    public static func makeSharedDefaults() -> UserDefaults {
        UserDefaults(suiteName: defaultsSuiteName) ?? .standard
    }

    public static func load(defaults: UserDefaults? = nil) -> HiveMaintenanceSchedule {
        let defaults = defaults ?? makeSharedDefaults()
        let enabled: Bool
        if defaults.object(forKey: enabledKey) == nil {
            enabled = defaultEnabled
        } else {
            enabled = defaults.bool(forKey: enabledKey)
        }
        let hour: Int
        if defaults.object(forKey: hourKey) == nil {
            hour = defaultHour
        } else {
            hour = defaults.integer(forKey: hourKey)
        }
        let minute: Int
        if defaults.object(forKey: minuteKey) == nil {
            minute = defaultMinute
        } else {
            minute = defaults.integer(forKey: minuteKey)
        }
        return HiveMaintenanceSchedule(enabled: enabled, hour: hour, minute: minute)
    }

    public func save(defaults: UserDefaults? = nil) {
        let defaults = defaults ?? Self.makeSharedDefaults()
        defaults.set(enabled, forKey: Self.enabledKey)
        defaults.set(hour, forKey: Self.hourKey)
        defaults.set(minute, forKey: Self.minuteKey)
    }
}
