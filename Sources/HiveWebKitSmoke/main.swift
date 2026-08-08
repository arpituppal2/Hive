import AppKit
import Darwin
import Foundation
import WebKit

/// A deliberately small loopback HTTP fixture used only by the opt-in runtime smoke target.
/// It avoids external dependencies and serves one HTML page plus one attachment response.
final class LocalHTTPFixtureServer: @unchecked Sendable {
    private let socketFD: Int32
    private let lock = NSLock()
    private var isRunning = true
    let port: UInt16

    init() throws {
        let fd = socket(AF_INET, SOCK_STREAM, 0)
        guard fd >= 0 else { throw SmokeError.server("socket failed") }

        var reuse: Int32 = 1
        setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var address = sockaddr_in()
        address.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        address.sin_family = sa_family_t(AF_INET)
        address.sin_port = 0
        address.sin_addr = in_addr(s_addr: inet_addr("127.0.0.1"))

        let bindResult = withUnsafePointer(to: &address) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                bind(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        guard bindResult == 0 else {
            close(fd)
            throw SmokeError.server("bind failed")
        }
        guard listen(fd, 4) == 0 else {
            close(fd)
            throw SmokeError.server("listen failed")
        }

        var boundAddress = sockaddr_in()
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        let nameResult = withUnsafeMutablePointer(to: &boundAddress) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                getsockname(fd, $0, &length)
            }
        }
        guard nameResult == 0 else {
            close(fd)
            throw SmokeError.server("getsockname failed")
        }

        socketFD = fd
        port = UInt16(bigEndian: boundAddress.sin_port)
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.acceptLoop()
        }
    }

    deinit {
        stop()
    }

    func stop() {
        lock.lock()
        guard isRunning else {
            lock.unlock()
            return
        }
        isRunning = false
        lock.unlock()
        shutdown(socketFD, SHUT_RDWR)
        close(socketFD)
    }

    private func acceptLoop() {
        while running {
            let client = accept(socketFD, nil, nil)
            guard client >= 0 else { break }
            handle(client)
            close(client)
        }
    }

    private var running: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isRunning
    }

    private func handle(_ client: Int32) {
        var buffer = [UInt8](repeating: 0, count: 4096)
        let count = recv(client, &buffer, buffer.count, 0)
        guard count > 0,
              let request = String(bytes: buffer.prefix(count), encoding: .utf8) else { return }
        let path = request.split(separator: " ").dropFirst().first.map(String.init) ?? "/"

        switch path {
        case "/download":
            let body = Data("Hive native download smoke\n".utf8)
            writeResponse(client,
                          status: "200 OK",
                          headers: [
                            "Content-Type: application/octet-stream",
                            "Content-Disposition: attachment; filename=\"hive-smoke.txt\"",
                            "Content-Length: \(body.count)",
                            "Cache-Control: no-store"
                          ],
                          body: body)
        default:
            let body = Data("""
            <!doctype html>
            <html><head><title>Hive Download Fixture</title></head>
            <body><h1>Hive Download Fixture</h1><p>Navigation fixture is ready.</p></body>
            </html>
            """.utf8)
            writeResponse(client,
                          status: "200 OK",
                          headers: [
                            "Content-Type: text/html; charset=utf-8",
                            "Content-Length: \(body.count)",
                            "Cache-Control: no-store"
                          ],
                          body: body)
        }
    }

    private func writeResponse(_ client: Int32, status: String, headers: [String], body: Data) {
        let head = (["HTTP/1.1 \(status)"] + headers + ["Connection: close", "", ""]).joined(separator: "\r\n")
        var response = Data(head.utf8)
        response.append(body)
        response.withUnsafeBytes { bytes in
            guard let base = bytes.baseAddress else { return }
            _ = send(client, base, bytes.count, 0)
        }
    }
}

@MainActor
final class WebKitSmokeController: NSObject, NSApplicationDelegate, WKNavigationDelegate, WKDownloadDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?
    private var server: LocalHTTPFixtureServer?
    private var destination: URL?
    private var phase = "launch"
    private var timeoutWorkItem: DispatchWorkItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            let server = try LocalHTTPFixtureServer()
            self.server = server
            let configuration = WKWebViewConfiguration()
            let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 900, height: 600), configuration: configuration)
            webView.navigationDelegate = self
            self.webView = webView

            let window = NSWindow(contentRect: webView.frame,
                                  styleMask: [.titled, .closable],
                                  backing: .buffered,
                                  defer: false)
            window.title = "Hive WebKit Smoke"
            window.contentView = webView
            window.center()
            window.orderFrontRegardless()
            self.window = window

            let pageURL = URL(string: "http://127.0.0.1:\(server.port)/page")!
            phase = "navigation"
            webView.load(URLRequest(url: pageURL))
            scheduleTimeout()
        } catch {
            finishFailure("launch: \(error.localizedDescription)")
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func webView(_ webView: WKWebView,
                 didFinish navigation: WKNavigation!) {
        guard phase == "navigation" else { return }
        guard let server else {
            finishFailure("navigation: fixture server stopped")
            return
        }
        guard webView.url?.path == "/page" else {
            finishFailure("navigation: unexpected URL \(webView.url?.absoluteString ?? "nil")")
            return
        }
        webView.evaluateJavaScript("document.body && document.body.innerText.includes('Navigation fixture is ready.')") { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                guard error == nil, (result as? Bool) == true else {
                    self.finishFailure("navigation: fixture DOM marker missing")
                    return
                }
                self.phase = "download"
                let downloadURL = URL(string: "http://127.0.0.1:\(server.port)/download")!
                webView.load(URLRequest(url: downloadURL))
            }
        }
    }

    @MainActor
    func webView(_ webView: WKWebView,
                             decidePolicyFor navigationResponse: WKNavigationResponse,
                             decisionHandler: @escaping @MainActor @Sendable (WKNavigationResponsePolicy) -> Void) {
        let contentDisposition = (navigationResponse.response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Disposition") ?? ""
        let isAttachment = contentDisposition.localizedCaseInsensitiveContains("attachment")
        let policy: WKNavigationResponsePolicy = isAttachment ? .download : .allow
        decisionHandler(policy)
    }

    func webView(_ webView: WKWebView,
                 navigationResponse: WKNavigationResponse,
                 didBecome download: WKDownload) {
        download.delegate = self
    }

    func download(_ download: WKDownload,
                  decideDestinationUsing response: URLResponse,
                  suggestedFilename: String,
                  completionHandler: @escaping @MainActor @Sendable (URL?) -> Void) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HiveWebKitSmoke-\(UUID().uuidString)", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let destination = directory.appendingPathComponent(suggestedFilename)
            self.destination = destination
            completionHandler(destination)
        } catch {
            finishFailure("destination: \(error.localizedDescription)")
            completionHandler(nil)
        }
    }

    func downloadDidFinish(_ download: WKDownload) {
        guard let destination else {
            finishFailure("download: destination callback was never received")
            return
        }
        guard let data = try? Data(contentsOf: destination),
              String(data: data, encoding: .utf8) == "Hive native download smoke\n" else {
            finishFailure("download: destination content mismatch path=\(destination.path)")
            return
        }
        finishSuccess("navigation=passed download=passed path=\(destination.path)")
    }

    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        finishFailure("download: \(error.localizedDescription) resumeData=\(resumeData != nil)")
    }

    private func scheduleTimeout() {
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self, self.phase != "done" else { return }
                self.finishFailure("timeout phase=\(self.phase)")
            }
        }
        timeoutWorkItem = item
        DispatchQueue.global().asyncAfter(deadline: .now() + 20, execute: item)
    }

    private func finishSuccess(_ message: String) {
        finish(.success(message))
    }

    private func finishFailure(_ message: String) {
        finish(.failure(SmokeFailure(message: message)))
    }

    private func finish(_ result: Result<String, SmokeFailure>) {
        guard phase != "done" else { return }
        phase = "done"
        timeoutWorkItem?.cancel()
        server?.stop()
        switch result {
        case .success(let message):
            print("HIVE_WEBKIT_SMOKE PASS \(message)")
            NSApp.terminate(nil)
        case .failure(let failure):
            fputs("HIVE_WEBKIT_SMOKE FAIL \(failure.message)\n", stderr)
            NSApp.terminate(nil)
        }
    }
}

struct SmokeFailure: Error {
    let message: String
}

enum SmokeError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case .server(let message): return message
        }
    }
}

@main
struct HiveWebKitSmokeMain {
    @MainActor
    static func main() {
        let app = NSApplication.shared
        let delegate = WebKitSmokeController()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.activate(ignoringOtherApps: true)
        app.run()
    }
}
