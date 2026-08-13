import CCef
import Foundation

// MARK: - CefTaskType
//
// Maps the CEF `cef_task_type_t` enum to a Swift type with a stable raw
// value and a human label for the Task Manager UI.

public enum CefTaskType: Int32, Sendable, Equatable {
    case unknown = 0
    case browser = 1
    case gpu = 2
    case zygote = 3
    case utility = 4
    case renderer = 5
    case extensionProcess = 6
    case guest = 7
    case plugin = 8
    case sandboxHelper = 9
    case dedicatedWorker = 10
    case sharedWorker = 11
    case serviceWorker = 12

    init(_ raw: cef_task_type_t) {
        self = CefTaskType(rawValue: Int32(raw.rawValue)) ?? .unknown
    }

    /// Human-readable process name (Chrome Task Manager style).
    public var label: String {
        switch self {
        case .browser: return "Browser"
        case .gpu: return "GPU Process"
        case .zygote: return "Zygote"
        case .utility: return "Utility"
        case .renderer: return "Renderer"
        case .extensionProcess: return "Extension"
        case .guest: return "Guest"
        case .plugin: return "Plugin"
        case .sandboxHelper: return "Sandbox Helper"
        case .dedicatedWorker: return "Dedicated Worker"
        case .sharedWorker: return "Shared Worker"
        case .serviceWorker: return "Service Worker"
        case .unknown: return "Task"
        }
    }
}

// MARK: - CefTaskInfo
//
// An immutable snapshot of one process task's live resource usage.

public struct CefTaskInfo: Sendable, Equatable {
    public let id: Int64
    public let type: CefTaskType
    public let isKillable: Bool
    public let title: String
    /// CPU usage of the process on which the task runs; range is
    /// 0 … number_of_processors × 100% (a 100 means one full core).
    public let cpuUsage: Double
    /// Number of processors available on the system.
    public let processorCount: Int
    /// Memory footprint in bytes; -1 means no valid value is available.
    public let memoryBytes: Int64
    /// GPU memory in bytes; -1 means no valid value is available.
    public let gpuMemoryBytes: Int64

    init(_ info: cef_task_info_t) {
        self.id = info.id
        self.type = CefTaskType(info.type)
        self.isKillable = info.is_killable != 0
        self.title = CefStringUtil.string(from: info.title)
        self.cpuUsage = info.cpu_usage
        self.processorCount = Int(info.number_of_processors)
        self.memoryBytes = info.memory
        self.gpuMemoryBytes = info.gpu_memory
    }
}

// MARK: - CefTaskManager
//
// Swift wrapper over CEF's process-wide task manager. All methods must be
// called on the UI thread (the main thread with CefSwift's message pump),
// matching CEF's documented constraint. The global instance is fetched
// through `cef_task_manager_get()` and refcounted for the wrapper's
// lifetime.

@MainActor
public final class CefTaskManager {
    /// Owned +1 reference to the global task manager; nil if the framework
    /// isn't loaded or the call came from the wrong thread.
    private var raw: UnsafeMutablePointer<cef_task_manager_t>?

    /// The global task manager, or nil when CEF isn't initialized.
    public static let shared = CefTaskManager()

    private init() {
        // CEF owns the global task manager for the app's lifetime; the
        // returned pointer stays valid until cef_shutdown. No addref/release
        // bookkeeping is needed (and a deinit could not safely touch it).
        raw = cef_task_manager_get()
    }

    /// Number of tasks currently tracked.
    public var tasksCount: Int {
        raw.map { Int($0.pointee.get_tasks_count?($0) ?? 0) } ?? 0
    }

    /// The tracked task IDs in CEF's stable order (browser first, then GPU,
    /// then renderers with their related processes kept together).
    public var taskIDs: [Int64] {
        guard let raw, tasksCount > 0 else { return [] }
        let capacity = tasksCount
        var ids = [Int64](repeating: 0, count: capacity)
        var count = capacity
        let ok = ids.withUnsafeMutableBufferPointer { buffer in
            raw.pointee.get_task_ids_list?(raw, &count, buffer.baseAddress) ?? 0
        }
        guard ok != 0 else { return [] }
        return Array(ids.prefix(count))
    }

    /// Live resource snapshot for a task, or nil if the id is invalid.
    public func taskInfo(for id: Int64) -> CefTaskInfo? {
        guard let raw else { return nil }
        var info = cef_task_info_t()
        info.size = MemoryLayout<cef_task_info_t>.stride
        let ok = raw.pointee.get_task_info?(raw, id, &info) ?? 0
        guard ok != 0 else { return nil }
        return CefTaskInfo(info)
    }

    /// Attempts to terminate a task. Returns whether the request was issued.
    @discardableResult
    public func killTask(_ id: Int64) -> Bool {
        guard let raw else { return false }
        return (raw.pointee.kill_task?(raw, id) ?? 0) != 0
    }

    /// The task ID backing a browser (from `CefBrowser.identifier`), or -1.
    public func taskID(forBrowser identifier: Int32) -> Int64 {
        guard let raw else { return -1 }
        return raw.pointee.get_task_id_for_browser_id?(raw, identifier) ?? -1
    }
}
