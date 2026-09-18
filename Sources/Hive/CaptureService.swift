import Foundation
import HiveCore
import CefSwiftUI

/// Runs Mozilla Readability (Apache-2.0, vendored) inside the captured page's
/// JS context and receives the extraction through the internal one-shot
/// `capture.pageResult` bridge capability. Failed extractions never enter the
/// corpus; the raw-visible-text fallback is a separate explicit user action.
@MainActor
final class CaptureService {
    private let store: CaptureStore
    private let bus: EventBus
    private var pending: [String: PendingCapture] = [:]   // requestId → pending

    struct PendingCapture {
        let tabId: String
        let url: String
        var isRawFallback: Bool = false
        var timeoutTask: Task<Void, Never>?
    }

    init(store: CaptureStore, bus: EventBus) {
        self.store = store
        self.bus = bus
    }

    func requestCapture(controller: AppController, tabId: String?) {
        guard let tab = tabId.flatMap({ t in controller.tabs.first(where: { $0.id == t }) })
                ?? controller.activeTab,
              let url = tab.model.url?.absoluteString,
              url.hasPrefix("http") else {
            bus.emit("capture.failed", ["reason": .string("no-page")])
            return
        }
        guard let browser = tab.model.browser else {
            bus.emit("capture.failed", ["reason": .string("no-browser")])
            return
        }
        // One capture at a time per tab.
        if pending.values.contains(where: { $0.tabId == tab.id && !$0.isRawFallback }) { return }
        let reqId = UUID().uuidString
        let entry = PendingCapture(tabId: tab.id, url: url)
        pending[reqId] = entry
        armTimeout(reqId)
        browser.executeJavaScript(Self.readabilityScript(reqId: reqId))
    }

    /// Explicit user-approved fallback after an extraction failure.
    func requestRawText(controller: AppController, tabId: String?) {
        guard let tab = controller.activeTab,
              let url = tab.model.url?.absoluteString, url.hasPrefix("http"),
              let browser = tab.model.browser else { return }
        let reqId = UUID().uuidString
        pending[reqId] = PendingCapture(tabId: tab.id, url: url, isRawFallback: true)
        armTimeout(reqId)
        browser.executeJavaScript(Self.rawTextScript(reqId: reqId))
    }

    /// Internal bridge capability target. Only honored for in-flight ids.
    nonisolated func handlePageResult(id: String, payload: [String: JSONValue]) {
        MainActor.assumeIsolated {
            guard var entry = pending.removeValue(forKey: id) else { return }   // stale/spoofed → drop silently
            entry.timeoutTask?.cancel()
            if let err = payload["error"]?.stringValue {
                fail(entry, reason: "extraction-error", detail: err)
                return
            }
            let text = payload["text"]?.stringValue ?? ""
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            let words = trimmed.split(separator: " ").count
            guard words >= 25 else {
                fail(entry, reason: "extraction-empty",
                     detail: "only \(words) usable words")
                return
            }
            let title = payload["title"]?.stringValue ?? entry.url
            let confidence = words > 400 ? 0.9 : (words > 150 ? 0.7 : 0.45)
            do {
                let cap = try store.storeCapture(url: entry.url, title: title,
                                                 rawText: trimmed, confidence: confidence)
                bus.emit("capture.captured", [
                    "captureId": .int(Int(cap.id)),
                    "url": .string(cap.url),
                    "title": .string(cap.title),
                    "wordCount": .int(cap.wordCount),
                    "confidence": .double(cap.confidence),
                    "spanCount": .int((try? store.allSpans().count) ?? 0),
                ])
            } catch {
                fail(entry, reason: "store-error", detail: "\(error)")
            }
        }
    }

    private func fail(_ entry: PendingCapture, reason: String, detail: String) {
        bus.emit("capture.failed", [
            "reason": .string(reason),
            "url": .string(entry.url),
            "canRetryRaw": .bool(reason == "extraction-empty" || reason == "extraction-error"),
        ])
        #if DEBUG
        NSLog("[Hive.Capture] failed (%@): %@", reason, detail)
        #endif
    }

    private func armTimeout(_ reqId: String) {
        let task = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard let self, let entry = self.pending.removeValue(forKey: reqId) else { return }
            self.fail(entry, reason: "timeout", detail: reqId)
        }
        pending[reqId]?.timeoutTask = task
    }

    // MARK: Injected scripts

    private static let readabilitySource: String = {
        if let url = HiveSchemeHandler.assetURL("Readability.js") as URL?,
           let raw = try? String(contentsOf: url, encoding: .utf8), !raw.isEmpty {
            return raw
        }
        if let url = Bundle.module.url(forResource: "Readability", withExtension: "js",
                                       subdirectory: "Resources"),
           let bundled = try? String(contentsOf: url, encoding: .utf8) {
            return bundled
        }
        return "/* readability missing */"
    }()

    static func readabilityScript(reqId: String) -> String {
        """
        (function(){
          try {
            \(readabilitySource)
            var docClone = document.cloneNode(true);
            var parsed = new Readability(docClone).parse();
            window.cefSwift && window.cefSwift.invoke('capture.pageResult', {
              id: '\(reqId)',
              title: (parsed && parsed.title) || document.title || '',
              text: (parsed && parsed.textContent) || ''
            });
          } catch (e) {
            window.cefSwift && window.cefSwift.invoke('capture.pageResult', {
              id: '\(reqId)', error: String(e)
            });
          }
        })();
        """
    }

    static func rawTextScript(reqId: String) -> String {
        """
        (function(){
          try {
            var t = document.body ? (document.body.innerText || '') : '';
            window.cefSwift && window.cefSwift.invoke('capture.pageResult', {
              id: '\(reqId)', title: document.title || '', text: t
            });
          } catch (e) {
            window.cefSwift && window.cefSwift.invoke('capture.pageResult', {
              id: '\(reqId)', error: String(e)
            });
          }
        })();
        """
    }
}
