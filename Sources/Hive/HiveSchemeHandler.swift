import Foundation
import CefKit
import HiveCore

/// Serves the web chrome over `hive://`. Two audiences, two per-launch tokens:
/// `/chrome` (shell + ask panes) uses `shellToken`; app pages loaded as tab
/// content (`/start`, `/reader`) use `pageToken`. The token replaces a
/// `__HIVE_TOKEN__` placeholder at serve time; bridge calls present it and
/// mismatched tokens are rejected. Arbitrary web content can never read
/// either token (`displayIsolated` + no shim off-origin).
struct HiveSchemeHandler: CefSchemeHandler {
    static let schemeName = "hive"

    let shellToken: String
    let pageToken: String
    let readerProvider: @Sendable (Int64) async -> ReaderDocument?

    nonisolated static let assets: [String: (mime: String, resource: String)] = [
        "/app.js": ("text/javascript; charset=utf-8", "app.js"),
        "/styles.css": ("text/css; charset=utf-8", "styles.css"),
    ]

    func response(for request: CefSchemeRequest) async -> CefSchemeResponse {
        guard let url = request.url else { return .notFound("bad url") }
        let path = url.path.isEmpty ? "/" : url.path

        switch path {
        case "/", "/index.html", "/chrome":
            return html(route: "chrome", pane: url["pane"] ?? "shell",
                        token: shellToken)
        case "/start":
            return html(route: "chrome", pane: "start", token: pageToken)
        case "/reader":
            // Server-rendered capture text; cited span pre-highlighted.
            let capID = Int64(url["capture"] ?? "") ?? -1
            let spanIdx = url["span"]
            if var doc = await readerProvider(capID) {
                doc.highlightSpan(idx: spanIdx)
                return CefSchemeResponse(status: 200, mimeType: "text/html; charset=utf-8",
                                         body: Data(doc.html().utf8))
            }
            return .notFound("No such capture")
        default:
            if let asset = Self.assets[path] {
                return serveResource(asset.resource, mime: asset.mime)
            }
            return .notFound("No such asset: \(path)")
        }
    }

    private func html(route: String, pane: String, token: String) -> CefSchemeResponse {
        guard var page = try? String(contentsOf: Self.assetURL("index.html"), encoding: .utf8) else {
            return .notFound("chrome index missing")
        }
        page = page
            .replacingOccurrences(of: "__HIVE_TOKEN__", with: token)
            .replacingOccurrences(of: "data-pane=\"full\"", with: "data-pane=\"\(pane)\"")
        return CefSchemeResponse(status: 200, mimeType: "text/html; charset=utf-8",
                                 body: Data(page.utf8))
    }

    private func serveResource(_ name: String, mime: String) -> CefSchemeResponse {
        do {
            let data = try Data(contentsOf: Self.assetURL(name))
            return CefSchemeResponse(status: 200, mimeType: mime, body: data)
        } catch {
            return .notFound("asset unreadable: \(name)")
        }
    }

    nonisolated static func assetURL(_ name: String) -> URL {
        // Assets live under WebChrome/ in the module bundle.
        if let u = Bundle.module.url(forResource: name, withExtension: nil,
                                     subdirectory: "WebChrome") { return u }
        return Bundle.module.resourceURL!.appending(path: "WebChrome/\(name)")
    }
}

extension URL {
    /// Tiny query-string accessor for hive:// URLs.
    subscript(key: String) -> String? {
        guard let comps = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let items = comps.queryItems else { return nil }
        return items.first(where: { $0.name == key })?.value
    }
}

/// Server-side rendered reader document (the citation proof-of-memory surface).
struct ReaderDocument {
    var title: String
    var host: String
    var capturedAt: Date
    var text: String          // normalized extraction string; offsets are char-based
    var spans: [(id: String, start: Int, end: Int)]
    var highlight: String?

    mutating func highlightSpan(idx: String?) {
        highlight = idx
    }

    /// Renders stored text with each span wrapped; the cited span gets an id anchor.
    func html() -> String {
        let esc = escapeHTML(text)
        // Wrap spans back-to-front so offsets stay valid.
        var out = esc
        let ns = out as NSString
        for span in spans.reversed() {
            let start = min(span.start, ns.length), end = min(span.end, ns.length)
            guard end > start else { continue }
            let cls = span.id.hasSuffix(highlight.map { ":" + $0 } ?? "\u{0}") ? " cite-hl" : ""
            let marked = "<span class=\"cite\(cls)\" id=\"s-\(escapeHTML(span.id))\">" +
                ns.substring(with: NSRange(start..<end)) + "</span>"
            out = (out as NSString).replacingCharacters(in: NSRange(start..<end), with: marked)
        }
        let df = DateFormatter()
        df.dateStyle = .medium; df.timeStyle = .short
        return """
        <!doctype html><html><head><meta charset="utf-8"><title>\(escapeHTML(title)) — Hive Reader</title>
        <style>
          body{margin:0;background:#141312;color:#F4F1EE;font:16px/1.65 Manrope,-apple-system,'Helvetica Neue',sans-serif}
          main{max-width:680px;margin:0 auto;padding:56px 24px}
          h1{font-size:26px;line-height:1.25;margin:0 0 6px}
          .meta{color:#8F8A82;font-size:13px;margin-bottom:32px}
          .cite{border-radius:4px;transition:background .12s cubic-bezier(.2,0,0,1)}
          .cite:hover{background:rgba(232,163,61,.14)}
          .cite-hl{background:rgba(232,163,61,.28);outline:2px solid rgba(232,163,61,.55)}
          ::selection{background:rgba(232,163,61,.35)}
        </style></head><body><main>
        <h1>\(escapeHTML(title))</h1><div class="meta">\(escapeHTML(host)) · captured \(df.string(from: capturedAt)) · stored locally on this Mac</div>
        \(out.split(separator: "\n").map { "<p>\($0)</p>" }.joined(separator: "\n"))
        </main></body></html>
        """
    }

    private func escapeHTML(_ s: String) -> String {
        s.replacingOccurrences(of: "&", with: "&amp;")
         .replacingOccurrences(of: "<", with: "&lt;")
         .replacingOccurrences(of: ">", with: "&gt;")
    }
}
