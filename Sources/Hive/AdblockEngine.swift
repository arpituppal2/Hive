import Foundation

// MARK: - AdblockEngine (Hive target)
//
// Swift wrapper over the hive-adblock-ffi Rust crate (Brave's adblock-rust).
// Uses dlopen/dlsym at runtime so the build succeeds even without the
// Rust .dylib present. Falls back gracefully to EasyListBlocklist.
//
// When the Rust crate is built and staged into the app bundle's
// Frameworks directory, the engine initializes automatically.

enum AdblockResult: Sendable {
    case allowed
    case blocked(reason: String)
    case unavailable
}

@MainActor
final class AdblockEngine: @unchecked Sendable {

    static let shared = AdblockEngine()

    private(set) var isReady = false
    private var initTask: Task<Void, Never>?

    // Runtime-resolved function pointers (loaded via dlopen)
    private typealias CreateFn = @convention(c) () -> Int32
    private typealias DestroyFn = @convention(c) () -> Void
    private typealias AddFiltersFn = @convention(c) (UnsafePointer<CChar>) -> Int32
    private typealias CheckURLFn = @convention(c) (UnsafePointer<CChar>, UnsafePointer<CChar>, UnsafePointer<CChar>) -> Int32

    private var engineCreate: CreateFn?
    private var engineDestroy: DestroyFn?
    private var engineAddFilters: AddFiltersFn?
    private var engineCheckURL: CheckURLFn?

    private var dylibHandle: UnsafeMutableRawPointer?

    // MARK: Public API

    func initialize() async {
        if isReady { return }
        if let existing = initTask { return await existing.value }
        let task = Task {
            guard loadLibrary() else { return }
            guard engineCreate?() == 0 else { return }
            let filters = EasyListBlocklist.domains
                .map { "||\($0)^" }
                .joined(separator: "\n")
            let added = filters.withCString { ptr in engineAddFilters?(ptr) ?? -1 }
            if added >= 0 { isReady = true }
            else { engineDestroy?() }
        }
        initTask = task
        await task.value
    }

    func check(url: URL, sourceHostname: String = "", requestType: String = "other") -> AdblockResult {
        guard isReady, let checkFn = engineCheckURL else {
            return fallbackCheck(url: url)
        }
        let urlStr = url.absoluteString
        let result = urlStr.withCString { u in
            sourceHostname.withCString { s in
                requestType.withCString { t in checkFn(u, s, t) }
            }
        }
        if result == 1 { return .blocked(reason: "Matched EasyList filter (native)") }
        if result < 0 { return fallbackCheck(url: url) }
        return .allowed
    }

    // MARK: Private

    private func loadLibrary() -> Bool {
        // Look for the dylib in the app bundle's Frameworks directory
        let frameworkPath = Bundle.main.privateFrameworksPath
            ?? Bundle.main.bundlePath + "/Contents/Frameworks"
        let libPath = frameworkPath + "/libhive_adblock_ffi.dylib"

        guard let handle = dlopen(libPath, RTLD_NOW) else {
            // Library not staged yet — will use fallback
            return false
        }
        dylibHandle = handle

        engineCreate = dlsym_safe(handle, "engine_create")
        engineDestroy = dlsym_safe(handle, "engine_destroy")
        engineAddFilters = dlsym_safe(handle, "engine_add_filters")
        engineCheckURL = dlsym_safe(handle, "engine_check_url")

        return engineCreate != nil && engineCheckURL != nil
    }

    private func dlsym_safe<T>(_ handle: UnsafeMutableRawPointer, _ name: String) -> T? {
        guard let sym = dlsym(handle, name) else { return nil }
        return unsafeBitCast(sym, to: T.self)
    }

    private func fallbackCheck(url: URL) -> AdblockResult {
        guard let host = url.host else { return .allowed }
        if EasyListBlocklist.domains.contains(host) {
            return .blocked(reason: "Matched EasyList filter (fallback)")
        }
        return .allowed
    }
}
