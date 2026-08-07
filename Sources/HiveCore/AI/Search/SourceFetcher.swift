import Foundation
import CryptoKit

// MARK: - SourceFetcher (SWARM-002 fetch/extract)

/// The fetch/extract half of the real research pipeline (§7.3 steps 3–5).
/// Fetches a URL under policy — http/https only, SSRF guard (private,
/// loopback, link-local, CGNAT, documentation ranges), redirect cap, content-
/// type allowlist, size cap, hard timeout — then extracts readable text
/// (title, meta description, body copy) with no external dependencies.
///
/// The network hop is INJECTED (`fetch` closure), so HiveCore stays
/// network-free by design and the entire policy surface is testable without
/// sockets. The closure performs ONE request; redirects are resolved by the
/// fetcher loop, re-validating scheme + SSRF policy at every hop.
public struct SourceFetcher: Sendable {

    // MARK: - Config

    public struct Config: Sendable {
        public var maxRedirects: Int
        public var maxBytes: Int
        public var timeout: Duration
        public var allowedContentTypes: Set<String>

        public init(
            maxRedirects: Int = 5,
            maxBytes: Int = 5 * 1024 * 1024,
            timeout: Duration = .seconds(15),
            allowedContentTypes: Set<String> = ["text/html", "application/xhtml+xml", "text/plain"]
        ) {
            self.maxRedirects = maxRedirects
            self.maxBytes = maxBytes
            self.timeout = timeout
            self.allowedContentTypes = allowedContentTypes
        }
    }

    // MARK: - Errors

    public enum FetchError: Error, LocalizedError, Sendable, Equatable {
        case disallowedScheme(String)
        case ssrfBlocked(String)
        case tooManyRedirects
        case redirectWithoutLocation
        case disallowedContentType(String)
        case contentTooLarge(Int)
        case timedOut
        case httpError(Int)
        case transport(String)

        public var errorDescription: String? {
            switch self {
            case .disallowedScheme(let scheme):
                return "Blocked scheme '\(scheme)'. Only http/https URLs may be fetched."
            case .ssrfBlocked(let host):
                return "Blocked host '\(host)' — private, loopback, link-local, CGNAT, or documentation addresses are not fetchable."
            case .tooManyRedirects:
                return "Too many redirects — the server exceeded the configured redirect cap."
            case .redirectWithoutLocation:
                return "Redirect response without a Location header."
            case .disallowedContentType(let type):
                return "Blocked content type '\(type)' — not in the fetch allowlist."
            case .contentTooLarge(let bytes):
                return "Content too large (\(bytes) bytes) — over the fetch size cap."
            case .timedOut:
                return "Fetch timed out."
            case .httpError(let code):
                return "HTTP \(code) while fetching."
            case .transport(let detail):
                return "Fetch failed: \(detail)"
            }
        }
    }

    // MARK: - Response / Result types

    /// One network response. The injected closure returns this; the fetcher
    /// loop interprets status + Location to follow redirects. `finalURL` is
    /// informational (what the closure actually hit) — the fetcher tracks
    /// redirects itself via `current` in its loop.
    public struct FetchResponse: Sendable {
        public let data: Data
        public let statusCode: Int
        public let headers: [String: String]
        public let finalURL: URL?

        public init(data: Data, statusCode: Int, headers: [String: String], finalURL: URL? = nil) {
            self.data = data
            self.statusCode = statusCode
            self.headers = headers
            self.finalURL = finalURL
        }
    }

    /// The policy-cleared, extracted result — what a Brief/Claim records.
    public struct FetchResult: Sendable {
        public let finalURL: URL
        public let contentType: String?
        public let title: String?
        public let description: String?
        public let text: String
        public let contentHash: String
        public let fetchedAt: Date
        public let redirectCount: Int

        public init(
            finalURL: URL,
            contentType: String?,
            title: String?,
            description: String?,
            text: String,
            contentHash: String,
            fetchedAt: Date,
            redirectCount: Int
        ) {
            self.finalURL = finalURL
            self.contentType = contentType
            self.title = title
            self.description = description
            self.text = text
            self.contentHash = contentHash
            self.fetchedAt = fetchedAt
            self.redirectCount = redirectCount
        }
    }

    public struct ExtractedText: Sendable {
        public let title: String?
        public let description: String?
        public let text: String

        public init(title: String?, description: String?, text: String) {
            self.title = title
            self.description = description
            self.text = text
        }
    }

    // MARK: - State

    public var config: Config
    /// Injected network fetch — ONE request, no redirect handling. The
    /// fetcher loop owns redirect resolution and policy re-validation.
    public let fetch: @Sendable (URL) async throws -> FetchResponse

    public init(
        config: Config = Config(),
        fetch: @escaping @Sendable (URL) async throws -> FetchResponse
    ) {
        self.config = config
        self.fetch = fetch
    }

    // MARK: - Fetch + extract

    /// Fetches `url` under policy and returns the extracted result. Every
    /// redirect hop re-runs the scheme + SSRF checks against the NEW URL, so
    /// a redirect can never smuggle a fetch to a private address or a
    /// non-http scheme.
    public func fetchAndExtract(from url: URL) async throws -> FetchResult {
        var current = url
        var redirects = 0
        let started = Date()

        while true {
            guard Self.isAllowedScheme(current) else {
                throw FetchError.disallowedScheme(current.scheme ?? "unknown")
            }
            guard Self.isSSRFSafe(current) else {
                throw FetchError.ssrfBlocked(current.host ?? current.absoluteString)
            }

            // `current` mutates per loop iteration — capture an immutable
            // copy so the @Sendable timeout closure doesn't capture a var.
            let targetURL = current
            let response = try await withTimeout(config.timeout) {
                try await fetch(targetURL)
            }

            // Redirect chain
            if (300..<400).contains(response.statusCode) {
                guard let location = response.headers["Location"] ?? response.headers["location"],
                      let next = URL(string: location, relativeTo: current)?.absoluteURL else {
                    throw FetchError.redirectWithoutLocation
                }
                redirects += 1
                guard redirects <= config.maxRedirects else {
                    throw FetchError.tooManyRedirects
                }
                current = next
                continue
            }

            guard response.statusCode < 400 else {
                throw FetchError.httpError(response.statusCode)
            }
            guard response.data.count <= config.maxBytes else {
                throw FetchError.contentTooLarge(response.data.count)
            }

            let contentType = Self.normalizedContentType(
                response.headers["Content-Type"] ?? response.headers["content-type"]
            )
            // A MISSING Content-Type header is allowed — misconfigured servers
            // commonly omit it — only a present, disallowed type is rejected.
            if let contentType, !config.allowedContentTypes.contains(contentType) {
                throw FetchError.disallowedContentType(contentType)
            }

            let extracted = Self.extractText(from: response.data)

            return FetchResult(
                finalURL: current,
                contentType: contentType,
                title: extracted.title,
                description: extracted.description,
                text: extracted.text,
                contentHash: Self.sha256Hex(response.data),
                fetchedAt: started,
                redirectCount: redirects
            )
        }
    }

    // MARK: - Policy (static, testable in isolation)

    /// Scheme allowlist: http/https only.
    public static func isAllowedScheme(_ url: URL) -> Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    /// SSRF guard at the URL layer: blocks private/loopback/link-local/CGNAT/
    /// documentation/reserved IP literals and local-only hostnames.
    ///
    /// Honest scope: this validates the literal host BEFORE any fetch. DNS
    /// rebinding (a hostname that resolves to a private address at fetch
    /// time) is the worker boundary's job — the injected `fetch` closure is
    /// that boundary.
    public static func isSSRFSafe(_ url: URL) -> Bool {
        guard let rawHost = url.host?.lowercased(), !rawHost.isEmpty else { return false }
        // URL.host returns IPv6 literals WITH brackets ("[::1]") — strip them
        // so the literal checks see the bare address. Without this, a
        // bracketed loopback/ULA/documentation literal would bypass the guard.
        let host = rawHost.hasPrefix("[") && rawHost.hasSuffix("]")
            ? String(rawHost.dropFirst().dropLast())
            : rawHost
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") || host.hasSuffix(".internal") {
            return false
        }
        if isIPv6Literal(host) {
            return !isBlockedIPv6(host)
        }
        if ipv4Value(host) != nil {
            return !isBlockedIPv4(host)
        }
        return true // plain hostname — resolved at fetch time by the worker boundary
    }

    // MARK: - Extraction (dependency-free)

    public static func extractText(from data: Data) -> ExtractedText {
        guard let html = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1) else {
            return ExtractedText(title: nil, description: nil, text: "")
        }
        return extractText(fromHTML: html)
    }

    public static func extractText(fromHTML html: String) -> ExtractedText {
        ExtractedText(
            title: firstTagContent(html, tag: "title"),
            description: firstMetaDescription(html),
            text: strippedBodyText(html)
        )
    }

    // MARK: - Internals: timeout

    /// Runs `body` with a hard timeout. The injected fetch closure must honor
    /// cancellation — if it ignores it, the drain below waits for it like any
    /// task group would (cancellation is cooperative).
    private func withTimeout<T: Sendable>(_ duration: Duration, _ body: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await body() }
            group.addTask {
                // Plain `try await`, NOT `try?`: when the group cancels this
                // timer after the body wins, the sleep ends with
                // CancellationError BEFORE the timedOut throw executes —
                // otherwise the timer would throw timedOut after being
                // cancelled, and the group would rethrow that unconsumed
                // error over the winner on scope exit.
                try await Task.sleep(for: duration)
                throw FetchError.timedOut
            }
            do {
                guard let result = try await group.next() else {
                    throw FetchError.transport("Fetch task ended without a result")
                }
                group.cancelAll()
                // Drain remaining child errors so scope exit cannot rethrow a
                // cancelled-timer (or cancelled-body) error over the winner.
                while (try? await group.next()) != nil {}
                return result
            } catch {
                group.cancelAll()
                while (try? await group.next()) != nil {}
                throw error
            }
        }
    }

    // MARK: - Internals: SSRF

    private static func isIPv6Literal(_ host: String) -> Bool {
        host.contains(":")
    }

    private static func ipv4Value(_ host: String) -> UInt32? {
        var addr = in_addr()
        let ok = host.withCString { inet_pton(AF_INET, $0, &addr) == 1 }
        guard ok else { return nil }
        return UInt32(bigEndian: addr.s_addr)
    }

    private static func isBlockedIPv4(_ host: String) -> Bool {
        guard let v = ipv4Value(host) else { return false }
        // 0/8, 10/8, 100.64/10 (CGNAT), 127/8, 169.254/16, 172.16/12,
        // 192.0.0/24, 192.0.2/24 (doc), 198.18/15 (benchmark),
        // 198.51.100/24 (doc), 192.168/16, 203.0.113/24 (doc),
        // 224/4 (multicast), 240/4 (reserved) + broadcast.
        let ranges: [(UInt32, UInt32)] = [
            (0x00000000, 0x00FFFFFF),
            (0x0A000000, 0x0AFFFFFF),
            (0x64400000, 0x647FFFFF),
            (0x7F000000, 0x7FFFFFFF),
            (0xA9FE0000, 0xA9FEFFFF),
            (0xAC100000, 0xAC1FFFFF),
            (0xC0000000, 0xC00000FF),
            (0xC0000200, 0xC00002FF),
            (0xC0586300, 0xC05863FF),   // 192.88.99/24 6to4 relay anycast (deprecated)
            (0xC6120000, 0xC613FFFF),
            (0xC6336400, 0xC63364FF),
            (0xC0A80000, 0xC0A8FFFF),
            (0xCB007100, 0xCB0071FF),
            (0xE0000000, 0xEFFFFFFF),
            (0xF0000000, 0xFFFFFFFF),
        ]
        return ranges.contains { v >= $0.0 && v <= $0.1 }
    }

    /// Blocked IPv6 literal check. Callers MUST pass the bracket-stripped
    /// form (isSSRFSafe strips the brackets URL.host adds) — a bracketed
    /// literal would not match any prefix below.
    private static func isBlockedIPv6(_ host: String) -> Bool {
        let h = host.lowercased()
        let zoneStripped = h.split(separator: "%", maxSplits: 1).first.map(String.init) ?? h
        // IPv4-mapped (::ffff:a.b.c.d) — validate the embedded IPv4.
        if zoneStripped.contains("."),
           let v4Part = zoneStripped.split(separator: ":").last.map(String.init),
           ipv4Value(v4Part) != nil {
            return isBlockedIPv4(v4Part)
        }
        if zoneStripped == "::" || zoneStripped == "::1" { return true }          // unspecified / loopback
        if zoneStripped.hasPrefix("fe80") || zoneStripped.hasPrefix("fc") || zoneStripped.hasPrefix("fd") {
            return true                                                            // link-local / ULA
        }
        if zoneStripped.hasPrefix("2001:db8") { return true }                      // documentation
        return false
    }

    // MARK: - Internals: helpers

    private static func normalizedContentType(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        return raw.split(separator: ";").first.map(String.init)?
            .trimmingCharacters(in: .whitespaces)
            .lowercased()
    }

    private static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func firstTagContent(_ html: String, tag: String) -> String? {
        guard let regex = try? NSRegularExpression(
            pattern: "<\(tag)[^>]*>(.*?)</\(tag)>",
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges > 1,
              let contentRange = Range(match.range(at: 1), in: html) else { return nil }
        return cleanText(String(html[contentRange]))
    }

    private static func firstMetaDescription(_ html: String) -> String? {
        let patterns = [
            "<meta[^>]+name=[\"']description[\"'][^>]+content=[\"']([^\"']*)[\"'][^>]*>",
            "<meta[^>]+content=[\"']([^\"']*)[\"'][^>]+name=[\"']description[\"'][^>]*>",
        ]
        for pattern in patterns {
            if let value = firstCapture(html, pattern: pattern) {
                return cleanText(value)
            }
        }
        return nil
    }

    private static func firstCapture(_ html: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[captureRange])
    }

    private static func strippedBodyText(_ html: String) -> String {
        var text = html
        if let bodyRange = text.range(of: "<body", options: .caseInsensitive) {
            text = String(text[bodyRange.lowerBound...])
        }
        for pattern in ["<script[\\s\\S]*?</script>", "<style[\\s\\S]*?</style>", "<!--[\\s\\S]*?-->"] {
            text = replacingMatches(text, pattern: pattern, with: " ")
        }
        text = replacingMatches(text, pattern: "</?(p|div|h[1-6]|li|tr|br|section|article)[^>]*>", with: "\n")
        text = replacingMatches(text, pattern: "<[^>]+>", with: " ")
        for (entity, replacement) in [
            ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&nbsp;", " "),
        ] {
            text = text.replacingOccurrences(of: entity, with: replacement)
        }
        text = collapseWhitespace(text)
        if text.count > 100_000 {
            text = String(text.prefix(100_000))
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replacingMatches(_ input: String, pattern: String, with replacement: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else {
            return input
        }
        let range = NSRange(input.startIndex..., in: input)
        return regex.stringByReplacingMatches(in: input, range: range, withTemplate: replacement)
    }

    private static func collapseWhitespace(_ input: String) -> String {
        input.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    private static func cleanText(_ input: String) -> String {
        let decoded = input
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
        return collapseWhitespace(decoded).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
