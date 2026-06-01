import Foundation
import SQLite3

public enum BrowserIntent: String, Codable, Sendable {
    case incidental
    case possibleIntent
    case intentional
}

public struct BrowserVisitSignal: Hashable, Sendable {
    public var url: URL
    public var title: String
    public var durationSeconds: TimeInterval
    public var repeatCount: Int
    public var bookmarked: Bool
    public var downloaded: Bool
    public var shared: Bool
    public var activeInteractionCount: Int

    public init(
        url: URL,
        title: String,
        durationSeconds: TimeInterval,
        repeatCount: Int,
        bookmarked: Bool = false,
        downloaded: Bool = false,
        shared: Bool = false,
        activeInteractionCount: Int = 0
    ) {
        self.url = url
        self.title = title
        self.durationSeconds = durationSeconds
        self.repeatCount = repeatCount
        self.bookmarked = bookmarked
        self.downloaded = downloaded
        self.shared = shared
        self.activeInteractionCount = activeInteractionCount
    }
}

public struct BrowserEngagementScore: Hashable, Sendable {
    public var score: Double
    public var intent: BrowserIntent
    public var confidence: Double
    public var reason: String
}

public struct BrowserEngagementScorer: Sendable {
    public init() {}

    public func score(_ signal: BrowserVisitSignal) -> BrowserEngagementScore {
        var score = 0.0
        var reasons: [String] = []
        let isYouTubeShorts = Self.isYouTubeShorts(signal.url)

        if signal.durationSeconds >= 180 {
            score += 0.25
            reasons.append("long session")
        } else if signal.durationSeconds >= 45 {
            score += 0.12
            reasons.append("short active session")
        }

        if signal.repeatCount >= 3 {
            score += 0.2
            reasons.append("repeat visits")
        }
        if signal.bookmarked {
            score += 0.25
            reasons.append("saved")
        }
        if signal.downloaded {
            score += 0.2
            reasons.append("downloaded")
        }
        if signal.shared {
            score += 0.2
            reasons.append("shared")
        }
        if signal.activeInteractionCount >= 4 {
            score += 0.18
            reasons.append("active engagement")
        }

        let clamped = min(score, 1)
        let intent: BrowserIntent
        if signal.bookmarked || signal.downloaded || signal.shared || clamped >= 0.62 {
            intent = .intentional
        } else if clamped >= 0.28 {
            intent = .possibleIntent
        } else {
            intent = .incidental
        }

        let reason = reasons.isEmpty
            ? "Browser appearance alone is incidental and is not treated as preference."
            : reasons.joined(separator: ", ")
        if isYouTubeShorts && clamped < 0.95 {
            let shortsReason = reasons.isEmpty
                ? "YouTube Shorts are ignored unless engagement confidence reaches 95%."
                : "YouTube Shorts require 95% engagement confidence before becoming memory; \(reason)."
            return BrowserEngagementScore(score: clamped, intent: .incidental, confidence: 0.95, reason: shortsReason)
        }
        return BrowserEngagementScore(score: clamped, intent: intent, confidence: intent == .incidental ? 0.8 : clamped, reason: reason)
    }

    private static func isYouTubeShorts(_ url: URL) -> Bool {
        let host = url.host(percentEncoded: false)?.lowercased() ?? ""
        let path = url.path.lowercased()
        return (host == "youtube.com" || host.hasSuffix(".youtube.com") || host == "youtu.be")
            && path.contains("/shorts")
    }
}

public enum URLSafetyDecision: Hashable, Sendable {
    case allowed
    case blocked(String)
}

public struct URLSafetyPolicy: Sendable {
    public init() {}

    public func evaluate(_ url: URL) -> URLSafetyDecision {
        guard let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme) else {
            return .blocked("Only HTTP and HTTPS URLs are allowed.")
        }
        guard let host = url.host(percentEncoded: false)?.lowercased(), !host.isEmpty else {
            return .blocked("URL has no host.")
        }
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") {
            return .blocked("Local hosts are private.")
        }
        if isPrivateIPAddress(host) {
            return .blocked("Private, loopback, link-local, multicast, and metadata IPs are blocked.")
        }
        return .allowed
    }

    public func isAllowed(_ url: URL) -> Bool {
        if case .allowed = evaluate(url) { return true }
        return false
    }

    private func isPrivateIPAddress(_ host: String) -> Bool {
        let trimmed = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]")).lowercased()
        if let aliasedIPv4 = wildcardDNSIPv4(host: trimmed), isPrivateIPv4(aliasedIPv4) {
            return true
        }
        if let ipv4 = parseIPv4Literal(trimmed) {
            return isPrivateIPv4(ipv4)
        }
        if trimmed.hasPrefix("::ffff:") {
            return isPrivateIPAddress(String(trimmed.dropFirst("::ffff:".count)))
        }
        if trimmed.hasPrefix("0:0:0:0:0:ffff:") {
            return isPrivateIPAddress(String(trimmed.dropFirst("0:0:0:0:0:ffff:".count)))
        }
        if trimmed == "::" || trimmed == "::1" {
            return true
        }
        if trimmed.hasPrefix("fc") || trimmed.hasPrefix("fd") || trimmed.hasPrefix("fe80") {
            return true
        }
        return false
    }

    private func wildcardDNSIPv4(host: String) -> UInt32? {
        for suffix in [".nip.io", ".sslip.io"] where host.hasSuffix(suffix) {
            let prefix = String(host.dropLast(suffix.count)).replacingOccurrences(of: "-", with: ".")
            if let ipv4 = parseIPv4Literal(prefix) {
                return ipv4
            }
        }
        return nil
    }

    private func parseIPv4Literal(_ value: String) -> UInt32? {
        if value.hasPrefix("0x"), let parsed = UInt32(value.dropFirst(2), radix: 16) {
            return parsed
        }
        if value.allSatisfy(\.isNumber), let parsed = UInt32(value, radix: 10) {
            return parsed
        }
        let parts = value.split(separator: ".")
        guard parts.count == 4 else { return nil }
        var octets: [UInt32] = []
        for part in parts {
            let parsed: UInt32?
            if part.hasPrefix("0x") {
                parsed = UInt32(part.dropFirst(2), radix: 16)
            } else {
                parsed = UInt32(part, radix: 10)
            }
            guard let parsed, parsed <= 255 else { return nil }
            octets.append(parsed)
        }
        return (octets[0] << 24) | (octets[1] << 16) | (octets[2] << 8) | octets[3]
    }

    private func isPrivateIPv4(_ value: UInt32) -> Bool {
        let a = Int((value >> 24) & 0xff)
        let b = Int((value >> 16) & 0xff)
        if value == 0 || a == 0 { return true }
        if a == 10 || a == 127 { return true }
        if a == 169 && b == 254 { return true }
        if a == 172 && (16...31).contains(b) { return true }
        if a == 192 && b == 168 { return true }
        if a >= 224 { return true }
        return false
    }
}

public struct BrowserSnapshotService: Sendable {
    public init() {}

    public func makeSafeSQLiteSnapshot(sourceURL: URL, destinationDirectory: URL) throws -> URL {
        try FileManager.default.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
        let destination = uniqueDestination(for: sourceURL, in: destinationDirectory)
        if try sqliteBackup(from: sourceURL, to: destination) {
            guard quickCheck(databaseURL: destination) else {
                try? FileManager.default.removeItem(at: destination)
                throw BrowserSnapshotError.quickCheckFailed(destination)
            }
            return destination
        }
        try? FileManager.default.removeItem(at: destination)
        if sidecarExists(for: sourceURL) {
            throw BrowserSnapshotError.requiresSQLiteBackup(sourceURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        guard quickCheck(databaseURL: destination) else {
            try? FileManager.default.removeItem(at: destination)
            throw BrowserSnapshotError.quickCheckFailed(destination)
        }
        return destination
    }

    private func sidecarExists(for sourceURL: URL) -> Bool {
        FileManager.default.fileExists(atPath: sourceURL.path + "-wal")
            || FileManager.default.fileExists(atPath: sourceURL.path + "-shm")
    }

    private func uniqueDestination(for sourceURL: URL, in destinationDirectory: URL) -> URL {
        let base = sourceURL.lastPathComponent.replacingOccurrences(of: "/", with: "-")
        let stamp = "\(Int(Date().timeIntervalSince1970 * 1_000))-\(UUID().uuidString.prefix(8))"
        return destinationDirectory.appendingPathComponent("\(base)-\(stamp).sqlite")
    }

    private func sqliteBackup(from sourceURL: URL, to destinationURL: URL) throws -> Bool {
        var sourceDB: OpaquePointer?
        var destinationDB: OpaquePointer?
        guard sqlite3_open_v2(sourceURL.path, &sourceDB, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(sourceDB)
            return false
        }
        defer { sqlite3_close(sourceDB) }

        guard sqlite3_open_v2(destinationURL.path, &destinationDB, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(destinationDB)
            return false
        }
        defer { sqlite3_close(destinationDB) }

        guard let backup = sqlite3_backup_init(destinationDB, "main", sourceDB, "main") else {
            return false
        }
        defer { sqlite3_backup_finish(backup) }

        let result = sqlite3_backup_step(backup, -1)
        return result == SQLITE_DONE
    }

    private func quickCheck(databaseURL: URL) -> Bool {
        var db: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &db, SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            sqlite3_close(db)
            return false
        }
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA quick_check", -1, &statement, nil) == SQLITE_OK else {
            sqlite3_finalize(statement)
            return false
        }
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW,
              let text = sqlite3_column_text(statement, 0) else {
            return false
        }
        return String(cString: text).lowercased() == "ok"
    }
}

public enum BrowserSnapshotError: Error, LocalizedError, Sendable {
    case quickCheckFailed(URL)
    case requiresSQLiteBackup(URL)

    public var errorDescription: String? {
        switch self {
        case .quickCheckFailed(let url):
            return "Browser snapshot failed SQLite quick_check: \(url.lastPathComponent)"
        case .requiresSQLiteBackup(let url):
            return "Browser snapshot requires SQLite backup because WAL sidecars exist: \(url.lastPathComponent)"
        }
    }
}
