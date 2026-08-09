import Foundation

// MARK: - AdblockEngine (Hive target)
//
// Swift wrapper over the hive-adblock-ffi Rust crate (Brave's adblock-rust).
// Uses dlopen/dlsym at runtime so the build succeeds even without the
// Rust .dylib present. Falls back gracefully to EasyListBlocklist.
//
// When the Rust crate is built and staged into the app bundle's
// Frameworks directory, the engine initializes automatically.

// MARK: - Brave-Aligned Match Result

/// Match result mirroring Brave's AdblockEngineMatchResult.
/// Provides detailed blocking information instead of a simple yes/no.
struct AdblockMatchResult: Sendable {
    let didMatchRule: Bool
    let didMatchException: Bool
    let didMatchImportant: Bool
    let redirect: String?
    let rewrittenURL: String?
    let filter: String?

    var isBlocked: Bool { didMatchImportant || (didMatchRule && !didMatchException) }

    static let allowed = AdblockMatchResult(
        didMatchRule: false, didMatchException: false,
        didMatchImportant: false, redirect: nil, rewrittenURL: nil, filter: nil
    )

    static func blocked(reason: String? = nil) -> AdblockMatchResult {
        AdblockMatchResult(
            didMatchRule: true, didMatchException: false,
            didMatchImportant: false, redirect: nil, rewrittenURL: nil, filter: reason
        )
    }
}

enum AdblockResult: Sendable {
    case allowed
    case blocked(reason: String)
    case unavailable

    /// Returns a detailed match result (Brave-aligned API).
    var matchResult: AdblockMatchResult {
        switch self {
        case .allowed: return .allowed
        case .blocked(let reason): return .blocked(reason: reason)
        case .unavailable: return .allowed
        }
    }
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
    private typealias CosmeticSelectorsFn = @convention(c) (UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?
    private typealias FreeStringFn = @convention(c) (UnsafeMutablePointer<CChar>?) -> Void

    private var engineCreate: CreateFn?
    private var engineDestroy: DestroyFn?
    private var engineAddFilters: AddFiltersFn?
    private var engineCheckURL: CheckURLFn?
    private var engineCosmeticSelectors: CosmeticSelectorsFn?
    private var engineFreeString: FreeStringFn?

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
            if added >= 0 {
                isReady = true
                // Snapshot the check pointer for the network-layer predicate,
                // which runs on CEF's IO thread (no main-actor hop allowed).
                Self.snapshotNativeCheck(engineCheckURL)
            } else {
                engineDestroy?()
            }
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

    // MARK: Thread-safe native check (network-layer predicate)
    //
    // CefResourceFilter consults the adblock decision on the browser-process
    // IO thread and must never hop to the main actor. adblock-rust checks are
    // stateless per call and thread-safe, so after initialize() installs the
    // FFI pointers on the main actor we snapshot the check function into an
    // immutable box readable from any thread. Returns nil when the engine is
    // unavailable or errors — callers then fall back to the static EasyList
    // domain set.

    nonisolated(unsafe) private static let nativeLock = NSLock()
    nonisolated(unsafe) private static var nativeCheck: CheckURLFn?

    /// Stores the FFI check pointer (main actor, during initialize()).
    @MainActor
    private static func snapshotNativeCheck(_ check: CheckURLFn?) {
        nativeLock.lock(); defer { nativeLock.unlock() }
        nativeCheck = check
    }

    /// Runs the native engine check from any thread. `nil` = not available.
    nonisolated static func nativeShouldBlock(url: URL, sourceHostname: String) -> Bool? {
        let check: CheckURLFn?
        nativeLock.lock(); defer { nativeLock.unlock() }
        check = nativeCheck
        guard let check else { return nil }
        let urlStr = url.absoluteString
        let result = urlStr.withCString { u in
            sourceHostname.withCString { s in
                check(u, s, "other")
            }
        }
        if result == 1 { return true }
        if result < 0 { return nil }  // engine error — fall back
        return false
    }

    // MARK: Brave-Aligned Extended API

    /// Returns CSS selectors for cosmetic filtering (Brave-aligned).
    /// Called by the renderer to hide ad elements without blocking the page.
    /// Wired to adblock-rust's url_cosmetic_resources via FFI (returns JSON array).
    func cosmeticSelectors(for url: URL) -> [String] {
        guard isReady, let cosmeticFn = engineCosmeticSelectors, let freeFn = engineFreeString else {
            return []
        }
        let urlStr = url.absoluteString
        guard let cResult = urlStr.withCString({ cosmeticFn($0) }) else { return [] }
        defer { freeFn(cResult) }
        guard let json = String(cString: cResult, encoding: .utf8),
              let data = json.data(using: .utf8),
              let selectors = try? JSONDecoder().decode([String].self, from: data)
        else { return [] }
        return selectors
    }

    /// Returns CSP directives to inject for a URL (Brave-aligned).
    func cspDirectives(for url: URL) -> String? {
        guard let host = url.host else { return nil }
        if EasyListBlocklist.domains.contains(host) {
            return "script-src 'none'; frame-src 'none'"
        }
        return nil
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
        engineCosmeticSelectors = dlsym_safe(handle, "engine_cosmetic_selectors")
        engineFreeString = dlsym_safe(handle, "engine_free_string")

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
