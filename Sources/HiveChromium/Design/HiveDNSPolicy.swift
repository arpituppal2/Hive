import Foundation
import HiveCore
#if canImport(Darwin)
import Darwin
#endif

/// Resolves a research URL before URLSession opens the request and rejects any
/// private/reserved answer. SourceFetcher already protects literal hosts and
/// redirect hops; this app-layer preflight covers hostname DNS answers.
///
/// This is intentionally a preflight rather than a claim of perfect DNS
/// pinning: URLSession may resolve again after this check, so a hostile DNS
/// server could still race the resolver/request boundary. Closing that final
/// TOCTOU requires a custom connected transport or a URLSession stack that can
/// pin the peer address; Hive records this limitation rather than hiding it.
enum HiveDNSPolicy {
    enum Error: Swift.Error, LocalizedError, Sendable {
        case noHost
        case resolutionFailed(String)
        case blockedAddress(String)
        case noAddresses

        var errorDescription: String? {
            switch self {
            case .noHost:
                return "The source URL has no hostname."
            case .resolutionFailed(let host):
                return "The source hostname could not be resolved: \(host)."
            case .blockedAddress(let address):
                return "The source resolved to a private or reserved address: \(address)."
            case .noAddresses:
                return "The source hostname returned no usable addresses."
            }
        }
    }

    /// Performs synchronous getaddrinfo work off the MainActor. Every answer
    /// must pass SourceFetcher's literal-IP policy; rejecting the whole host if
    /// one answer is private avoids choosing an unsafe address by accident.
    static func validate(_ url: URL) throws {
        guard SourceFetcher.isAllowedScheme(url) else {
            throw SourceFetcher.FetchError.disallowedScheme(url.scheme ?? "unknown")
        }
        guard let host = url.host, !host.isEmpty else {
            throw HiveDNSPolicy.Error.noHost
        }
        guard SourceFetcher.isSSRFSafe(url) else {
            throw SourceFetcher.FetchError.ssrfBlocked(host)
        }

        #if canImport(Darwin)
        var hints = addrinfo()
        hints.ai_family = AF_UNSPEC
        hints.ai_socktype = SOCK_STREAM
        hints.ai_protocol = IPPROTO_TCP
        hints.ai_flags = AI_ADDRCONFIG

        var result: UnsafeMutablePointer<addrinfo>?
        let status = host.withCString { getaddrinfo($0, nil, &hints, &result) }
        guard status == 0 else {
            throw HiveDNSPolicy.Error.resolutionFailed(host)
        }
        defer {
            if let result { freeaddrinfo(result) }
        }

        var cursor = result
        var foundAddress = false
        while let info = cursor {
            guard let address = info.pointee.ai_addr else {
                cursor = info.pointee.ai_next
                continue
            }
            let length = info.pointee.ai_addrlen
            if let numeric = numericHost(address, length: length) {
                foundAddress = true
                let urlHost = numeric.contains(":")
                    ? "[\(numeric.replacingOccurrences(of: "%", with: "%25"))]"
                    : numeric
                guard let numericURL = URL(string: "http://\(urlHost)/"),
                      SourceFetcher.isSSRFSafe(numericURL) else {
                    throw HiveDNSPolicy.Error.blockedAddress(numeric)
                }
            }
            cursor = info.pointee.ai_next
        }

        guard foundAddress else { throw HiveDNSPolicy.Error.noAddresses }
        #else
        // HiveChromium currently ships on macOS. Keep non-Darwin builds
        // compilable without pretending a resolver exists in this target.
        throw HiveDNSPolicy.Error.resolutionFailed(host)
        #endif
    }

    #if canImport(Darwin)
    private static func numericHost(
        _ address: UnsafePointer<sockaddr>,
        length: socklen_t
    ) -> String? {
        var buffer = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let result = getnameinfo(
            address,
            length,
            &buffer,
            socklen_t(buffer.count),
            nil,
            0,
            NI_NUMERICHOST
        )
        guard result == 0 else { return nil }
        let end = buffer.firstIndex(of: 0) ?? buffer.endIndex
        return String(decoding: buffer[..<end].map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
    #endif
}
