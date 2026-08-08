import Foundation
import CryptoKit

// MARK: - GoogleSafeBrowsingClient
//
// Google Safe Browsing API v4 client using the hash-prefix privacy model.
// Only sends the first 4 bytes of SHA-256 URL hashes to Google — never
// the full URL. Matches Chrome and Edge's protection against phishing,
// malware, and unwanted software.
//
// Reference: https://developers.google.com/safebrowsing/v4

actor GoogleSafeBrowsingClient {
    private static let apiURL = "https://safebrowsing.googleapis.com/v4/threatMatches:find"

    private var threatCache: [String: (hashes: Set<String>, expiry: Date)] = [:]
    private let cacheDuration: TimeInterval = 1800 // 30 minutes

    private var lastRequestTime: Date = .distantPast
    private let minRequestInterval: TimeInterval = 1.0

    private static let threatTypes = [
        "MALWARE", "SOCIAL_ENGINEERING",
        "UNWANTED_SOFTWARE", "POTENTIALLY_HARMFUL_APPLICATION",
    ]
    private static let platforms = ["ANY_PLATFORM"]
    private static let clientVersion = "1.0.0"

    /// Keychain account for the Google Safe Browsing API key.
    /// Internal so the Settings view reads/writes the same key.
    static let apiKeyAccount = "googleSafeBrowsingKey"

    /// Cached API key — read from Keychain once on first use, then kept in
    /// memory. A Keychain read costs ~5ms per call, and check(url:) fires
    /// on every page navigation, so caching avoids a ~5ms stall per page.
    private var cachedKey: String? = nil
    private var keyLoaded = false

    private var apiKey: String {
        if !keyLoaded {
            cachedKey = KeychainSecretStore.read(key: Self.apiKeyAccount)
            keyLoaded = true
        }
        if let key = cachedKey, !key.isEmpty { return key }
        // CI/testing fallback only — never a persisted default.
        return ProcessInfo.processInfo.environment["HIVE_SAFE_BROWSING_KEY"] ?? ""
    }

    static let shared = GoogleSafeBrowsingClient()

    // MARK: - Public

    func check(url: URL) async -> String? {
        guard !apiKey.isEmpty else { return nil }

        guard let canonical = canonicalURL(url) else { return nil }
        let digest = SHA256.hash(data: Data(canonical.utf8))
        let fullHash = digest.map { String(format: "%02x", $0) }.joined()
        let prefixData = Data(digest.prefix(4))
        let prefixB64 = prefixData.base64EncodedString()
        let prefixHex = String(fullHash.prefix(8))

        // Check local cache first
        if let cached = await checkCache(prefix: prefixHex, fullHash: fullHash) {
            return cached
        }

        return await queryAPI(prefixB64: prefixB64, prefixHex: prefixHex, fullHash: fullHash)
    }

    // MARK: - Private

    private func canonicalURL(_ url: URL) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        var components = URLComponents()
        components.scheme = url.scheme?.lowercased() ?? "https"
        components.host = host
        components.path = url.path.lowercased()
        if let query = url.query?.lowercased() {
            let params = query.split(separator: "&").sorted().joined(separator: "&")
            if !params.isEmpty { components.query = params }
        }
        if let port = url.port {
            if (components.scheme == "https" && port != 443) ||
               (components.scheme == "http" && port != 80) {
                components.port = port
            }
        }
        return components.string
    }

    private func checkCache(prefix: String, fullHash: String) async -> String? {
        guard let entry = threatCache[prefix] else { return nil }
        guard entry.expiry > Date() else {
            threatCache.removeValue(forKey: prefix)
            return nil
        }
        if entry.hashes.contains(fullHash) { return "MALWARE" }
        return nil
    }

    private func queryAPI(prefixB64: String, prefixHex: String, fullHash: String) async -> String? {
        let elapsed = Date().timeIntervalSince(lastRequestTime)
        if elapsed < minRequestInterval {
            try? await Task.sleep(for: .seconds(minRequestInterval - elapsed))
        }
        lastRequestTime = Date()

        let body: [String: Any] = [
            "client": [
                "clientId": "hive-browser",
                "clientVersion": Self.clientVersion,
            ],
            "threatInfo": [
                "threatTypes": Self.threatTypes,
                "platformTypes": Self.platforms,
                "threatEntryTypes": ["URL"],
                "threatEntries": [
                    ["hash": prefixB64], // Base64-encoded 4-byte hash prefix per v4 spec
                ],
            ],
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body),
              let requestURL = URL(string: "\(Self.apiURL)?key=\(apiKey)") else { return nil }

        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return nil }

            if httpResponse.statusCode == 403 {
                print("[SafeBrowsing] API key rejected — check your key in Settings")
                return nil
            }
            guard httpResponse.statusCode == 200 else { return nil }

            if let result = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let matches = result["matches"] as? [[String: Any]],
               !matches.isEmpty {

                var returnedHashes = Set<String>()
                for match in matches {
                    if let threat = match["threat"] as? [String: Any],
                       let hashB64 = threat["hash"] as? String,
                       let hashData = Data(base64Encoded: hashB64) {
                        let hexHash = hashData.map { String(format: "%02x", $0) }.joined()
                        returnedHashes.insert(hexHash)
                    }
                }

                if !returnedHashes.isEmpty {
                    cacheThreat(prefix: prefixHex, hashes: returnedHashes)
                }

                if returnedHashes.contains(fullHash) {
                    for match in matches {
                        if let threatType = match["threatType"] as? String {
                            return threatLabel(threatType)
                        }
                    }
                    return "Dangerous site"
                }
            }
            return nil
        } catch {
            return nil // Network error — fail open
        }
    }

    private func cacheThreat(prefix: String, hashes: Set<String>) {
        threatCache[prefix] = (hashes, Date().addingTimeInterval(cacheDuration))
        let now = Date()
        threatCache = threatCache.filter { $0.value.expiry > now }
    }

    private func threatLabel(_ type: String) -> String {
        switch type {
        case "MALWARE": return "This site contains malware"
        case "SOCIAL_ENGINEERING": return "Deceptive site — phishing or social engineering"
        case "UNWANTED_SOFTWARE": return "This site may try to install harmful software"
        case "POTENTIALLY_HARMFUL_APPLICATION": return "This site hosts potentially harmful applications"
        default: return "Dangerous site detected by Safe Browsing"
        }
    }
}
