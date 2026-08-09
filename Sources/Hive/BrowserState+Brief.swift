//
//  BrowserState+Brief.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Brief Capture (Browse → Remember → Organize) | - Morning Brief
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Brief

@MainActor
extension BrowserState {


    func toggleBriefCapture() {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            isBriefCaptureOpen.toggle()
        }
    }


    /// Public accessor for page context — used by BriefCaptureView.
    var activePageContext: PageContext? {
        buildPageContext()
    }


    /// Captures the current page into Honeycomb as a Source node.
    /// - Returns: The Honeycomb node ID of the created Source node.
    func captureCurrentPage() async throws -> String {
        guard !isKnowledgePersistenceDegraded, !isAuditPersistenceDegraded else {
            throw CaptureError.persistenceUnavailable
        }
        guard !isPrivateBrowsing,
              let ctx = buildPageContext(), let pageURL = ctx.url else {
            throw CaptureError.noPage
        }
        let nodeID = pageNodeID(for: pageURL.absoluteString)

        let contentForHash = "\(pageURL.absoluteString)\n\(ctx.title)"
        let hash = HoneycombStore.sha256(contentForHash)

        // Check for an existing node (dedup). A failed lookup is a storage
        // failure, not a cache miss: continuing would risk turning a damaged
        // durable store into an apparent successful capture.
        do {
            if let existing = try await honeycomb.findNode(type: .source, contentHash: hash) {
                await hotMemory.didAccessNode(id: existing.id, sourceHint: "captured",
                                              label: existing.label,
                                              workspaceID: currentWorkspaceID.uuidString,
                                              profileID: currentProfileID.uuidString)
                return existing.id
            }
        } catch {
            reportKnowledgePersistenceFailure()
            throw CaptureError.persistenceUnavailable
        }

        // Build metadata as JSONValue
        var metaObj: [String: JSONValue] = [:]
        metaObj["url"] = .string(pageURL.absoluteString)
        metaObj["host"] = .string(pageURL.host ?? "")
        metaObj["captured_at"] = .string(ISO8601DateFormatter().string(from: Date()))
        metaObj["method"] = .string("manual_capture")

        let node = HoneycombStore.Node(
            id: nodeID,
            type: .source,
            label: ctx.title,
            metadata: .object(metaObj),
            contentHash: hash,
            provenance: "browser_capture"
        )
        do {
            _ = try await honeycomb.insertNode(node)
        } catch {
            reportKnowledgePersistenceFailure()
            throw CaptureError.persistenceUnavailable
        }

        await hotMemory.didAccessNode(id: nodeID, sourceHint: "captured",
                                      label: ctx.title,
                                      workspaceID: currentWorkspaceID.uuidString,
                                           profileID: currentProfileID.uuidString)

        let auditRecorded = await recordAuditEvent(EventLedgerStore.LedgerEvent(
            id: UUID().uuidString,
            timestamp: Date(),
            actor: "user",
            intent: "Captured page: \(ctx.title)",
            actionKind: .capture,
            actionTarget: pageURL.absoluteString,
            actionPreview: "Source node from \(pageURL.host ?? "unknown")",
            trustLevel: .t0,
            policyDecision: .allowed,
            consentState: .notRequired,
            contextIDs: [nodeID],
            environment: "swift-6",
            result: .success
        ))
        guard auditRecorded else {
            throw CaptureError.partialPersistence
        }

        memoryRevision &+= 1
        return nodeID
    }


    /// Captures a user-authored note into Honeycomb — the quick-capture inbox
    /// for the Knowledge panel. Identical notes dedup to the same node, the
    /// note warms hot memory, and the write is audited like a capture.
    @discardableResult
    func captureNote(_ text: String) async throws -> String {
        guard !isKnowledgePersistenceDegraded, !isAuditPersistenceDegraded else {
            throw CaptureError.persistenceUnavailable
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CaptureError.noNote
        }
        let label = String(trimmed.prefix(80))
        let hash = HoneycombStore.sha256(trimmed)

        // Fail closed like captureCurrentPage: a failed dedup lookup is a
        // storage failure, not a cache miss — continuing could mint a
        // duplicate on a damaged store.
        let existing: HoneycombStore.Node?
        do {
            existing = try await honeycomb.findNode(type: .note, contentHash: hash)
        } catch {
            reportKnowledgePersistenceFailure()
            throw CaptureError.persistenceUnavailable
        }
        if let existing {
            await hotMemory.didAccessNode(id: existing.id, sourceHint: "explicit",
                                          label: existing.label,
                                          workspaceID: currentWorkspaceID.uuidString,
                                          profileID: currentProfileID.uuidString)
            memoryRevision &+= 1
            return existing.id
        }

        let node = HoneycombStore.Node(
            type: .note,
            label: label,
            metadata: .object(["content": .string(trimmed)]),
            contentHash: hash,
            provenance: "user"
        )
        let stored: HoneycombStore.Node
        do {
            stored = try await honeycomb.insertNode(node)
        } catch {
            reportKnowledgePersistenceFailure()
            throw CaptureError.persistenceUnavailable
        }

        await hotMemory.didAccessNode(id: stored.id, sourceHint: "explicit",
                                      label: stored.label,
                                      workspaceID: currentWorkspaceID.uuidString,
                                      profileID: currentProfileID.uuidString)

        let auditRecorded = await recordAuditEvent(EventLedgerStore.LedgerEvent(
            id: UUID().uuidString,
            timestamp: Date(),
            actor: "user",
            intent: "Captured note",
            actionKind: .capture,
            actionTarget: "note",
            actionPreview: String(trimmed.prefix(120)),
            trustLevel: .t0,
            policyDecision: .allowed,
            consentState: .notRequired,
            contextIDs: [stored.id],
            environment: "swift-6",
            result: .success
        ))
        guard auditRecorded else {
            throw CaptureError.partialPersistence
        }

        memoryRevision &+= 1
        return stored.id
    }


    // MARK: - Morning Brief

    /// Builds the Morning Brief JSON (schema: the Dia-style brief template at
    /// Sources/Hive/WebChrome/brief/). The template is JSON-driven — the HTML
    /// holds a __HIVE_BRIEF_JSON__ placeholder filled at serve time — so Hive
    /// injects *real* browsing data with zero JS surgery: greeting + time, the
    /// user's open tabs as to-dos, top history domains as suggested tasks, and
    /// a source credit footer. Honest: when there is no history yet, the brief
    /// greets without inventing fake items.
    func buildBriefJSON() -> String {
        // Hardened JSON escaper for untrusted browser data (tab titles, URLs,
        // hosts — all network/user-controlled). Beyond standard JSON escapes it
        // neutralizes '<' '>' '&' and U+2028/2029 so a malicious page title can
        // never break out of the brief's <script id="brief-data"> tag or the
        // JSON.parse boundary (</script>-breakout / XSS). Non-ASCII is passed
        // through UTF-8 (valid in JSON) and control chars are \u-escaped.
        func esc(_ s: String) -> String {
            var out = ""
            for ch in s.unicodeScalars {
                switch ch.value {
                case 0x5C: out += "\\\\"            // backslash
                case 0x22: out += "\\\""              // double quote
                case 0x0A: out += "\\n"
                case 0x0D: out += "\\r"
                case 0x09: out += "\\t"
                case 0x08: out += "\\b"
                case 0x0C: out += "\\f"
                case 0x3C: out += "\\u003c"           // < — kills </script> breakout
                case 0x3E: out += "\\u003e"           // >
                case 0x26: out += "\\u0026"           // &
                case 0x2028: out += "\\u2028"         // JS line separator
                case 0x2029: out += "\\u2029"         // JS paragraph separator
                case 0x00...0x1F:
                    out += String(format: "\\u%04X", ch.value)
                default:
                    out.unicodeScalars.append(ch)
                }
            }
            return out
        }

        // Greeting from the clock.
        let hour = Calendar.current.component(.hour, from: Date())
        let greeting: String
        switch hour {
        case 5..<12: greeting = "Good morning. Here's what's on your radar today."
        case 12..<17: greeting = "Good afternoon. Here's what's worth your attention."
        default: greeting = "Good evening. A quiet recap of your day."
        }

        let isoDate = ISO8601DateFormatter().string(from: Date())

        // Open tabs → top to-dos ("resume reading" style).
        // Private tabs are excluded: the brief is browsing-data-derived and is
        // served in normal-profile tabs — a private tab's title/URL must never
        // surface here (mirror of the newTab() isPrivate guard).
        var todos: [[String: String]] = []
        for tab in tabs.prefix(8) where !tab.isPrivate {
            guard let url = tab.model.url,
                  let host = url.host, !host.isEmpty,
                  url.scheme == "http" || url.scheme == "https"
            else { continue }
            let title = tab.model.title ?? host
            todos.append([
                "title": title,
                "source_url": url.absoluteString,
                "tier": "now",
                "rank": String(todos.count + 1),
                "context": "Open in a tab — pick up where you left off.",
            ])
        }

        // History domains → suggested tasks.
        var tasks: [[String: String]] = []
        for (i, site) in topDomainsFromHistory(limit: 6).enumerated() {
            tasks.append([
                "title": site.host,
                "source_url": site.url.absoluteString,
                "description": i == 0 ? "Your most-visited site this week." : "From your recent browsing.",
            ])
        }

        // Footer source chips.
        var sources: [[String: String]] = []
        for site in topDomainsFromHistory(limit: 6) {
            sources.append(["url": site.url.absoluteString, "name": site.host])
        }

        func jsonItems(_ items: [[String: String]]) -> String {
            items.map { item in
                "{" + item.map { "\"\($0.key)\":\"\(esc($0.value))\"" }.joined(separator: ",") + "}"
            }.joined(separator: ",")
        }

        var members: [String] = []
        members.append("\"header\": { \"greeting\": \"\(esc(greeting))\", \"date_time\": \"\(isoDate)\" }")
        members.append("\"top_todos\": [\(jsonItems(todos))]")
        members.append("\"tasks\": [\(jsonItems(tasks))]")
        if !sources.isEmpty {
            members.append("\"footer\": { \"sources\": [\(jsonItems(sources))] }")
        }
        return "{\n  " + members.joined(separator: ",\n  ") + "\n}"
    }


    /// Pushes a fresh start-data snapshot to every open web start page and to
    /// the persistent chrome shell so the UI stays live (new tab, closed tab,
    /// switched tab, switched space, layout change).
    ///
    /// Scoped to hive://start browsers only: the global bridge broadcast
    /// injects the payload into EVERY page, and a malicious page could define
    /// `window.cefSwift._emit` to capture browsing data. We emit only into
    /// browsers whose current URL is our own web chrome.
    func broadcastWebChromeState() {
        let snapshot = webChromeStartData()
        guard let data = try? JSONEncoder().encode(snapshot),
              let json = String(data: data, encoding: .utf8)
        else { return }
        let script = "if(window.cefSwift&&window.cefSwift._emit){window.cefSwift._emit(\"hive.stateChanged\","
            + json + ");}"
        if let chrome = chromeModel, chrome.url?.host == "start" {
            chrome.browser?.executeJavaScript(script)
        }
        for tab in tabs where tab.model.url?.host == "start" {
            tab.model.browser?.executeJavaScript(script)
        }
    }
}
