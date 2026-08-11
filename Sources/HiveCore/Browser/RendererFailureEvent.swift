import Foundation

/// A renderer failure reported by a browser-engine adapter.
///
/// The event contains only identifiers and diagnostics needed for recovery. It
/// deliberately carries no page text, cookies, screenshots, or model context.
/// CEF and WKWebView adapters can construct this value when their respective
/// process-termination callbacks fire.
public struct RendererFailureEvent: Sendable, Equatable, Codable {
    public let tabID: String
    public let url: URL?
    public let reason: String
    public let errorCode: Int?
    public let occurredAt: Date

    public init(
        tabID: String,
        url: URL? = nil,
        reason: String,
        errorCode: Int? = nil,
        occurredAt: Date = Date()
    ) {
        self.tabID = String(tabID.prefix(256))
        self.url = Self.diagnosticOrigin(from: url)
        self.reason = Self.diagnosticReason(from: reason)
        self.errorCode = errorCode
        self.occurredAt = occurredAt
    }

    private enum CodingKeys: String, CodingKey {
        case tabID, url, reason, errorCode, occurredAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            tabID: try container.decode(String.self, forKey: .tabID),
            url: try container.decodeIfPresent(URL.self, forKey: .url),
            reason: try container.decode(String.self, forKey: .reason),
            errorCode: try container.decodeIfPresent(Int.self, forKey: .errorCode),
            occurredAt: try container.decode(Date.self, forKey: .occurredAt)
        )
    }

    /// Recovery diagnostics must not retain credentials, query strings,
    /// fragments, or path tokens. The tab model remains the source of truth for
    /// the URL needed to recreate a browser; this event keeps only the origin.
    private static func diagnosticOrigin(from url: URL?) -> URL? {
        guard let url, let scheme = url.scheme?.lowercased(), let host = url.host,
              scheme == "http" || scheme == "https" else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host.lowercased()
        components.port = url.port
        return components.url
    }

    /// Failure messages are diagnostics, not an unbounded log channel. Flatten
    /// whitespace/control characters, redact URL-like and credential-shaped
    /// tokens, and cap the value so a renderer cannot inject page text or huge
    /// payloads into recovery records.
    private static func diagnosticReason(from reason: String) -> String {
        let flattened = reason.unicodeScalars.map { scalar -> Character in
            if scalar.properties.isWhitespace || scalar.value < 0x20 || scalar.value == 0x7F {
                return " "
            }
            return Character(scalar)
        }
        var value = String(flattened)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let sensitivePattern = #"(?i)\"?\b(api[_-]?key|access[_-]?token|refresh[_-]?token|client[_-]?secret|token|password|secret|authorization|auth)\b\"?\s*[=:]\s*(?:bearer\s+)?(?:\"(?:[^\"\\]|\\.)*\"|'(?:[^'\\]|\\.)*'|\"(?:[^\"\\]|\\.)*$|'(?:[^'\\]|\\.)*$|[^\s,;\"']+)"#
        if let regex = try? NSRegularExpression(pattern: sensitivePattern) {
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            value = regex.stringByReplacingMatches(
                in: value,
                range: range,
                withTemplate: "$1=[redacted]"
            )
        }

        let urlPattern = #"(?i)https?://[^\s]+"#
        if let regex = try? NSRegularExpression(pattern: urlPattern) {
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            value = regex.stringByReplacingMatches(
                in: value,
                range: range,
                withTemplate: "[url]"
            )
        }

        return String(value.prefix(512))
    }
}

/// The adapter-facing result after a renderer failure has been classified.
/// The browser shell owns the actual reload/recreation and UI presentation.
public struct RendererRecoveryPlan: Sendable, Equatable {
    public let event: RendererFailureEvent
    public let decision: CrashRecoveryDecision
    /// Delay the adapter must honor before an automatic reload. Zero for
    /// recovery-surface decisions and manual retries. The plan authorizes a
    /// bounded delay; it never performs the reload itself.
    public let retryAfter: TimeInterval
    /// Ephemeral identity for this recovery attempt. Adapters must retain it
    /// while scheduling a delayed reload and validate it before acting; it is
    /// intentionally not persisted or included in renderer diagnostics.
    public let attemptID: UUID

    public init(
        event: RendererFailureEvent,
        decision: CrashRecoveryDecision,
        retryAfter: TimeInterval = 0,
        attemptID: UUID = UUID()
    ) {
        self.event = event
        self.decision = decision
        self.retryAfter = decision == .retryAutomatically && retryAfter.isFinite
            ? min(max(0, retryAfter), CrashRecoveryPolicy.maximumAutomaticRetryDelay)
            : 0
        self.attemptID = attemptID
    }

    public var shouldReloadAutomatically: Bool {
        decision == .retryAutomatically
    }

    public var requiresRecoverySurface: Bool {
        if case .showRecovery = decision { return true }
        return false
    }
}

/// The narrow contract an engine adapter must satisfy before renderer recovery
/// can be called end to end. CefSwift's current `CefWebViewModel` owns the
/// browser delegate and does not expose a render-termination closure, so this
/// protocol is intentionally an integration boundary rather than a fabricated
/// callback path.
public protocol RendererFailureHandling: Sendable {
    func classify(
        _ event: RendererFailureEvent,
        crashRecord: CrashRecord,
        automaticRetriesUsed: Int
    ) -> RendererRecoveryPlan
}

public struct DefaultRendererFailureHandler: RendererFailureHandling {
    public let policy: CrashRecoveryPolicy

    public init(policy: CrashRecoveryPolicy = CrashRecoveryPolicy()) {
        self.policy = policy
    }

    public func classify(
        _ event: RendererFailureEvent,
        crashRecord: CrashRecord,
        automaticRetriesUsed: Int = 0
    ) -> RendererRecoveryPlan {
        let decision = policy.decision(
            for: crashRecord,
            automaticRetriesUsed: automaticRetriesUsed
        )
        let retryNumber = automaticRetriesUsed + 1
        return RendererRecoveryPlan(
            event: event,
            decision: decision,
            retryAfter: decision == .retryAutomatically
                ? policy.delay(forAutomaticRetryNumber: retryNumber)
                : 0
        )
    }
}
