import Foundation
import Testing
@testable import HiveCore

// MARK: - SourceFetcher tests (SWARM-002 adversarial fixtures)

@Suite("SourceFetcher")
struct SourceFetcherTests {

    private func htmlResponse(_ html: String, status: Int = 200, headers: [String: String] = ["Content-Type": "text/html; charset=utf-8"], url: URL = URL(string: "https://example.com/")!) -> SourceFetcher.FetchResponse {
        SourceFetcher.FetchResponse(data: Data(html.utf8), statusCode: status, headers: headers, finalURL: url)
    }

    private func stub(_ handler: @escaping @Sendable (URL) async throws -> SourceFetcher.FetchResponse) -> SourceFetcher {
        SourceFetcher { url in try await handler(url) }
    }

    // MARK: - Scheme allowlist

    @Test func rejectsNonHTTPSchemes() async {
        for scheme in ["file", "ftp", "javascript", "data", "chrome"] {
            let url = URL(string: "\(scheme)://example.com/x")!
            let fetcher = stub { _ in self.htmlResponse("<html></html>") }
            do {
                _ = try await fetcher.fetchAndExtract(from: url)
                Issue.record("\(scheme):// should be rejected")
            } catch let error as SourceFetcher.FetchError {
                guard case .disallowedScheme = error else {
                    Issue.record("\(scheme):// wrong error: \(error)")
                    break
                }
            } catch {
                Issue.record("\(scheme):// wrong error type")
            }
        }
    }

    // MARK: - SSRF guard

    @Test func blocksPrivateAndLoopbackHosts() async {
        // IPv6 literals are bracketed because URL(string:) requires that form
        // ("http://::1/" is not a valid URL) — and URL.host returns the
        // brackets, so the test also covers the bracket-stripping in isSSRFSafe.
        let badHosts = [
            "127.0.0.1", "127.0.0.2", "localhost", "myhost.localhost",
            "10.0.0.5", "172.16.0.1", "172.31.255.254", "192.168.1.1",
            "169.254.169.254", "0.0.0.0", "100.64.0.1", "100.127.255.254",
            "192.0.0.1", "192.0.2.10", "198.18.0.1", "198.51.100.7",
            "203.0.113.9", "224.0.0.1", "240.0.0.1", "255.255.255.255",
            "[::1]", "[::]", "[fe80::1]", "[fc00::1]", "[fd00::1]", "[2001:db8::1]",
            "[::ffff:127.0.0.1]", "[::ffff:192.168.0.1]",
            "dev.local", "corp.internal",
        ]
        for host in badHosts {
            #expect(SourceFetcher.isSSRFSafe(URL(string: "http://\(host)/")!) == false, "\(host) must be blocked")
        }
    }

    @Test func allowsPublicHosts() async {
        let goodHosts = ["example.com", "www.wikipedia.org", "8.8.8.8", "1.1.1.1", "example.com:8443", "docs.swift.org"]
        for host in goodHosts {
            #expect(SourceFetcher.isSSRFSafe(URL(string: "https://\(host)/")!) == true, "\(host) must pass the SSRF guard")
        }
    }

    @Test func fetchRejectsSSRFBeforeAnyNetwork() async {
        // Box the flag: the stub closure is @Sendable, so capturing a mutable
        // var would violate Swift 6 strict concurrency.
        final class FetchFlag: @unchecked Sendable { var called = false }
        let flag = FetchFlag()
        let fetcher = stub { _ in
            flag.called = true
            return self.htmlResponse("<html></html>")
        }
        do {
            _ = try await fetcher.fetchAndExtract(from: URL(string: "http://169.254.169.254/latest/meta-data")!)
            Issue.record("metadata URL must be blocked")
        } catch let error as SourceFetcher.FetchError {
            guard case .ssrfBlocked = error else {
                Issue.record("wrong error: \(error)")
                return
            }
        } catch {
            Issue.record("wrong error type")
        }
        #expect(flag.called == false, "no network call may happen for a blocked host")
    }

    // MARK: - Redirects

    @Test func followsRedirectsWithinCapAndRevalidatesPolicy() async throws {
        let fetcher = stub { url in
            switch url.absoluteString {
            case "https://a.example/":
                return SourceFetcher.FetchResponse(data: Data(), statusCode: 302, headers: ["Location": "https://b.example/page"], finalURL: url)
            case "https://b.example/page":
                return SourceFetcher.FetchResponse(data: Data(), statusCode: 301, headers: ["Location": "/final"], finalURL: url)
            default:
                return self.htmlResponse("<html><head><title>Final</title></head><body><p>Hello world</p></body></html>", url: url)
            }
        }
        let result = try await fetcher.fetchAndExtract(from: URL(string: "https://a.example/")!)
        #expect(result.redirectCount == 2)
        // The relative "/final" resolves against the redirecting URL
        // (https://b.example/page), per RFC 7231 — not the original a.example.
        #expect(result.finalURL.absoluteString == "https://b.example/final")
        #expect(result.title == "Final")
        #expect(result.text.contains("Hello world"))
    }

    @Test func capsRedirectLoops() async {
        let fetcher = stub { url in
            SourceFetcher.FetchResponse(data: Data(), statusCode: 302, headers: ["Location": url.absoluteString], finalURL: url)
        }
        do {
            _ = try await fetcher.fetchAndExtract(from: URL(string: "https://a.example/")!)
            Issue.record("redirect loop must be capped")
        } catch let error as SourceFetcher.FetchError {
            guard case .tooManyRedirects = error else {
                Issue.record("wrong error: \(error)")
                return
            }
        } catch {
            Issue.record("wrong error type")
        }
    }

    @Test func redirectToBlockedSchemeIsDenied() async {
        let fetcher = stub { _ in
            SourceFetcher.FetchResponse(data: Data(), statusCode: 302, headers: ["Location": "file:///etc/passwd"], finalURL: URL(string: "https://a.example/")!)
        }
        do {
            _ = try await fetcher.fetchAndExtract(from: URL(string: "https://a.example/")!)
            Issue.record("redirect to file:// must be denied")
        } catch let error as SourceFetcher.FetchError {
            guard case .disallowedScheme = error else {
                Issue.record("wrong error: \(error)")
                return
            }
        } catch {
            Issue.record("wrong error type")
        }
    }

    @Test func redirectToPrivateHostIsDenied() async {
        let fetcher = stub { _ in
            SourceFetcher.FetchResponse(data: Data(), statusCode: 302, headers: ["Location": "http://192.168.1.1/admin"], finalURL: URL(string: "https://a.example/")!)
        }
        do {
            _ = try await fetcher.fetchAndExtract(from: URL(string: "https://a.example/")!)
            Issue.record("redirect to private IP must be denied")
        } catch let error as SourceFetcher.FetchError {
            guard case .ssrfBlocked = error else {
                Issue.record("wrong error: \(error)")
                return
            }
        } catch {
            Issue.record("wrong error type")
        }
    }

    // MARK: - Content-type allowlist

    @Test func rejectsBinaryContentTypes() async {
        let fetcher = stub { _ in
            SourceFetcher.FetchResponse(data: Data([0x89, 0x50, 0x4E, 0x47]), statusCode: 200, headers: ["Content-Type": "image/png"], finalURL: URL(string: "https://example.com/i.png")!)
        }
        do {
            _ = try await fetcher.fetchAndExtract(from: URL(string: "https://example.com/i.png")!)
            Issue.record("binary content must be rejected")
        } catch let error as SourceFetcher.FetchError {
            guard case .disallowedContentType("image/png") = error else {
                Issue.record("wrong error: \(error)")
                return
            }
        } catch {
            Issue.record("wrong error type")
        }
    }

    @Test func acceptsNormalizedHTMLWithParameters() async throws {
        let fetcher = stub { _ in
            self.htmlResponse("<html><title>OK</title></html>", headers: ["Content-Type": "text/html; charset=UTF-8"])
        }
        let result = try await fetcher.fetchAndExtract(from: URL(string: "https://example.com/")!)
        #expect(result.title == "OK")
        #expect(result.contentType == "text/html")
    }

    // MARK: - Size cap + HTTP errors

    @Test func capsContentSize() async {
        let big = Data(repeating: 0x41, count: 6 * 1024 * 1024)
        let fetcher = stub { _ in
            SourceFetcher.FetchResponse(data: big, statusCode: 200, headers: ["Content-Type": "text/html"], finalURL: URL(string: "https://example.com/")!)
        }
        do {
            _ = try await fetcher.fetchAndExtract(from: URL(string: "https://example.com/")!)
            Issue.record("oversized content must be rejected")
        } catch let error as SourceFetcher.FetchError {
            guard case .contentTooLarge = error else {
                Issue.record("wrong error: \(error)")
                return
            }
        } catch {
            Issue.record("wrong error type")
        }
    }

    @Test func surfacesHTTPErrors() async {
        let fetcher = stub { _ in
            SourceFetcher.FetchResponse(data: Data("Not found".utf8), statusCode: 404, headers: ["Content-Type": "text/html"], finalURL: URL(string: "https://example.com/")!)
        }
        do {
            _ = try await fetcher.fetchAndExtract(from: URL(string: "https://example.com/")!)
            Issue.record("404 must be an error")
        } catch let error as SourceFetcher.FetchError {
            guard case .httpError(404) = error else {
                Issue.record("wrong error: \(error)")
                return
            }
        } catch {
            Issue.record("wrong error type")
        }
    }

    // MARK: - Timeout

    @Test func timesOutSlowFetches() async {
        let fetcher = SourceFetcher(config: SourceFetcher.Config(timeout: .milliseconds(120))) { url in
            try await Task.sleep(for: .seconds(5))
            return self.htmlResponse("<html></html>", url: url)
        }
        do {
            _ = try await fetcher.fetchAndExtract(from: URL(string: "https://example.com/")!)
            Issue.record("slow fetch must time out")
        } catch let error as SourceFetcher.FetchError {
            guard case .timedOut = error else {
                Issue.record("wrong error: \(error)")
                return
            }
        } catch {
            Issue.record("wrong error type")
        }
    }

    // MARK: - Extraction

    @Test func extractsTitleDescriptionAndBody() throws {
        let html = """
        <html><head><title>Hive Docs</title>
        <meta name="description" content="The Hive Browser turns what you browse into organized memory.">
        </head><body>
        <h1>Welcome</h1>
        <p>Hive is a browser-native workspace.</p>
        <script>alert(&#39;x&#39;)</script>
        <style>.cls{}</style>
        </body></html>
        """
        let extracted = SourceFetcher.extractText(fromHTML: html)
        #expect(extracted.title == "Hive Docs")
        #expect(extracted.description == "The Hive Browser turns what you browse into organized memory.")
        #expect(extracted.text.contains("Welcome"))
        #expect(extracted.text.contains("browser-native workspace"))
        #expect(!extracted.text.contains("alert"))
        #expect(!extracted.text.contains(".cls"))
    }

    @Test func metaDescriptionWorksInEitherAttributeOrder() throws {
        let html = "<html><head><meta content='reverse order' name='description'></head><body></body></html>"
        let extracted = SourceFetcher.extractText(fromHTML: html)
        #expect(extracted.description == "reverse order")
    }

    @Test func producesDeterministicTextExtraction() throws {
        let html = "<html><body>Same content</body></html>"
        let a = SourceFetcher.extractText(from: Data(html.utf8))
        let b = SourceFetcher.extractText(from: Data(html.utf8))
        #expect(a.text == b.text)
        #expect(a.text.contains("Same content"))
    }
}
