import Foundation

/// Typed envelope for every bridge response. The shim passes this through as-is.
public struct Envelope<T: Codable & Sendable>: Codable, Sendable {
    public var ok: Bool
    public var data: T?
    public var err: BridgeError?

    public static func ok(_ data: T) -> Envelope { Envelope(ok: true, data: data, err: nil) }
    public static func fail(_ code: String, _ message: String) -> Envelope {
        Envelope(ok: false, data: nil, err: BridgeError(code: code, message: message))
    }
}

public struct Unit: Codable, Sendable { public init() {} }

public struct BridgeError: Codable, Sendable {
    public var code: String
    public var message: String
    public init(code: String, message: String) { self.code = code; self.message = message }
}

/// Canonical list of every registered bridge method (data owned by HiveCore
/// so tests and app agree on one source of truth). The contract test asserts the web
/// side calls exactly these (and vice versa). `reader.open` is a v1.1 extension;
/// `capture.pageResult` is internal (untrusted-page → native one-shot result).
public enum BridgeRegistry {
    public static let methods: [String] = [
        "tabs.create", "tabs.select", "tabs.close", "tabs.list",
        "nav.go", "nav.back", "nav.forward", "nav.reload",
        "omnibox.submit", "omnibox.suggest",
        "bookmark.add", "bookmark.list", "bookmark.remove",
        "capture.request", "capture.rawSave",
        "ask.request", "ask.cancel",
        "settings.get", "settings.set",
        "session.restore",
        "events.get",
        "captures.recent",
        "reader.open",
        "capture.pageResult",   // internal capability; excluded from chrome-side contract
    ]

    public static let internalMethods: Set<String> = ["capture.pageResult"]
}
