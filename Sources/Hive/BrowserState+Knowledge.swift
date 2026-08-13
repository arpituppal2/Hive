//
//  BrowserState+Knowledge.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Knowledge Panel (Honeycomb) | - Knowledge memory actions (Knowledge panel + hot memory)
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + Knowledge

@MainActor
extension BrowserState {


    func toggleKnowledgePanel() {
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            isKnowledgePanelOpen.toggle()
        }
    }


    /// Only durable, user-visible Honeycomb records belong in the Knowledge
    /// lifecycle UI. Model-derived legacy records are rejected defensively even
    /// if an older database or importer left one behind.
    static func isInspectableKnowledgeNode(_ node: HoneycombStore.Node) -> Bool {
        HoneycombStore.isInspectableNode(node)
    }


    // MARK: - Knowledge memory actions (Knowledge panel + hot memory)

    /// Opens a knowledge node from the panel. Page-bearing rows (sources,
    /// captures) open in a new tab. Content-bearing rows (notes, briefs,
    /// claims) load their content into the AI panel as an honest
    /// "Memory — <type>" message — Chromium parity with the Workspace
    /// Home's `loadNodeInChat`. Every row acts; nothing is a silent no-op.
    func openKnowledgeNode(_ node: HoneycombStore.Node) {
        if let urlString = Self.knowledgeNodeURL(from: node),
           let url = URL(string: urlString) {
            newTab(url: url)
            return
        }
        let content = Self.knowledgeNodeContent(from: node) ?? node.label
        // Briefs carry their evidence as graph edges — append the linked
        // sources so the memory message is self-contained (§11.1 "inspect its
        // sources"). The Gemini message renderer linkifies the source URLs,
        // so each one becomes an actionable Open button.
        if node.type == .brief {
            Task {
                let sources = await Self.linkedSourceNodes(for: node.id, honeycomb: honeycomb)
                var text = content
                if !sources.isEmpty {
                    text += "\n\nSources:\n" + sources.enumerated().map { index, source in
                        let title = source.label.isEmpty ? "Source \(index + 1)" : source.label
                        let url = Self.knowledgeNodeURL(from: source) ?? ""
                        return "\(index + 1). \(title) — \(url)"
                    }.joined(separator: "\n")
                }
                presentMemory(nodeType: node.type.rawValue, label: node.label, content: text)
            }
            return
        }
        presentMemory(nodeType: node.type.rawValue, label: node.label, content: content)
    }


    /// Follows `references` + `derivedFrom` edges from a brief to its Source
    /// nodes. The Chromium brief store links via `.references`; the WKWebView
    /// store via `.derivedFrom` — following both resolves evidence either way.
    static func linkedSourceNodes(
        for briefID: String,
        honeycomb: HoneycombStore
    ) async -> [HoneycombStore.Node] {
        var targetIDs = Set<String>()
        for relation in [HoneycombStore.EdgeRelation.references, HoneycombStore.EdgeRelation.derivedFrom] {
            if let edges = try? await honeycomb.getEdges(from: briefID, relation: relation) {
                targetIDs.formUnion(edges.map(\.targetID))
            }
        }
        guard !targetIDs.isEmpty else { return [] }
        let nodes = (try? await honeycomb.getNodes(ids: Array(targetIDs))) ?? []
        // Stable evidence ordering — getNodes(ids:) makes no order guarantee.
        return nodes.filter { $0.type == .source }
            .sorted { $0.createdAt < $1.createdAt }
    }


    /// Opens a hot-memory entry. URL-bearing entries re-open their page in a
    /// tab (the existing behavior). Everything else presents the entry's
    /// stamped label/content in the AI panel — the stamped content avoids a
    /// graph round-trip when Honeycomb is unavailable.
    func openHotEntry(_ entry: HotMemoryStore.HotEntry) {
        Task {
            let node = try? await honeycomb.getNode(id: entry.id)
            if let node,
               let urlString = Self.knowledgeNodeURL(from: node),
               let url = URL(string: urlString) {
                newTab(url: url)
                return
            }
            let stampedContent = entry.content.flatMap { $0.isEmpty ? nil : $0 }
            let content = stampedContent
                ?? node.flatMap { Self.knowledgeNodeContent(from: $0) }
                ?? entry.label.flatMap { $0.isEmpty ? nil : $0 }
                ?? entry.id
            let label = entry.label.flatMap { $0.isEmpty ? nil : $0 }
                ?? node?.label
                ?? "Memory"
            presentMemory(
                nodeType: node?.type.rawValue ?? "memory",
                label: label,
                content: content
            )
        }
    }


    /// Appends a memory item into the AI panel as an assistant-labeled memory
    /// message and opens the panel. The message says "Memory — <type>" — it
    /// is display-only (T0) and never pretends to be a model answer. Repeated
    /// clicks on the same item collapse to one message (the header matches the
    /// previous message), so memory rows cannot flood the chat.
    func presentMemory(nodeType: String, label: String, content: String) {
        let header = "Memory — \(nodeType): \(label)"
        if geminiMessages.last?.text.hasPrefix(header) != true {
            geminiMessages.append(GeminiMessage(role: .assistant, text: "\(header)\n\n\(content)"))
        }
        isGeminiPanelOpen = true
    }


    /// Canonical `url` extraction from Honeycomb node metadata. Shared with
    /// the Knowledge panel rows — one source of truth for metadata keys.
    static func knowledgeNodeURL(from node: HoneycombStore.Node) -> String? {
        guard case .object(let dict) = node.metadata,
              case .string(let url) = dict["url"], !url.isEmpty else { return nil }
        return url
    }


    /// Body-text extraction — notes/briefs store body text under "content",
    /// claims under "text". Shared with the Knowledge panel rows.
    static func knowledgeNodeContent(from node: HoneycombStore.Node) -> String? {
        guard case .object(let dict) = node.metadata else { return nil }
        for key in ["content", "text"] {
            if case .string(let text) = dict[key], !text.isEmpty { return text }
        }
        return nil
    }


    /// Base URL of the user's self-hosted Vane (formerly Perplexica) instance,
    /// used for `/research` queries. Stored in UserDefaults — a local server
    /// address, not a credential (AGENTS.md §9.2 rule 7 keeps secrets out of
    /// UserDefaults; a server URL isn't a secret).
    var vaneBaseURL: String {
        get { UserDefaults.standard.string(forKey: "HiveVaneBaseURL") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "HiveVaneBaseURL") }
    }


    /// The user's Tavily API key, read from Keychain ("" when unset).
    var tavilyAPIKey: String {
        KeychainSecretStore.read(key: Self.tavilyAPIKeyAccount) ?? ""
    }


    /// Commits the Tavily key to Keychain; an empty value removes it.
    func setTavilyAPIKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainSecretStore.delete(key: Self.tavilyAPIKeyAccount)
        } else {
            KeychainSecretStore.save(key: Self.tavilyAPIKeyAccount, value: trimmed)
        }
    }


    /// The provider `/research` will actually use, or nil when the selected
    /// provider is off or missing its configuration. One resolution point for
    /// chat, voice, settings, and diagnostics — the UI never diverges from
    /// what the research path can run.
    func activeResearchProvider() -> ResearchProvider? {
        switch researchProvider {
        case .off: return nil
        case .vane:
            return vaneBaseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : .vane
        case .tavily:
            return tavilyAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : .tavily
        }
    }


    /// Replaces the in-flight research placeholder with honest, provider-aware
    /// configuration guidance when the selected provider cannot run.
    func guideResearchConfiguration(id: UUID, responseID: UInt64, missing: String) {
        guard responseIsCurrent(responseID), !Task.isCancelled else { return }
        replaceMessage(id: id, text:
            "Web research isn't ready yet.\n\n\(missing) Type `/research <query>` again once it's configured.")
    }


    /// Live web research through the configured provider (Vane or Tavily). Runs a
    /// real search, formats cited sources via `CitationFormatter`, and appends
    /// the result into the conversation. Honest states: unconfigured → clear
    /// guidance; failure → the actual error, never a fabricated answer.
    func performResearch(query: String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let responseID = beginResponse()
        let placeholder = GeminiMessage(role: .assistant, text: "...")
        geminiMessages.append(placeholder)

        geminiGenerationTask = Task { [weak self] in
            defer { self?.finishResponse(responseID) }
            guard let self else { return }

            // Resolve the provider selected in Settings → Performance → Web
            // Research: self-hosted Vane or cloud Tavily. Honest states — off
            // or unconfigured → provider-aware guidance; failure → the actual
            // error, never a fabricated answer.
            let provider: any WebSearchProvider
            let providerLabel: String
            switch self.activeResearchProvider() {
            case .vane:
                let baseURLString = self.vaneBaseURL.trimmingCharacters(in: .whitespaces)
                guard !baseURLString.isEmpty, let baseURL = URL(string: baseURLString) else {
                    self.guideResearchConfiguration(
                        id: placeholder.id, responseID: responseID,
                        missing: "Set up a self-hosted Vane (formerly Perplexica) instance, then add its URL in Settings → Performance → Web Research.")
                    return
                }
                provider = VaneSearchProvider(baseURL: baseURL)
                providerLabel = "vane"
            case .tavily:
                let key = self.tavilyAPIKey
                guard !key.isEmpty else {
                    self.guideResearchConfiguration(
                        id: placeholder.id, responseID: responseID,
                        missing: "Add your Tavily API key in Settings → Performance → Web Research.")
                    return
                }
                provider = TavilySearchProvider(apiKey: key)
                providerLabel = "tavily"
            case .off, nil:
                self.guideResearchConfiguration(
                    id: placeholder.id, responseID: responseID,
                    missing: "Turn on Web Research in Settings → Performance → Web Research.")
                return
            }

            let started = Date()
            do {
                let result = try await provider.search(query: trimmed, focusMode: .webSearch)
                guard self.responseIsCurrent(responseID), !Task.isCancelled else { return }

                let formatted = CitationFormatter.format(answer: result.answer, sources: result.sources)

                var finalText = formatted.answer
                if !formatted.footer.isEmpty {
                    finalText += "\n\n" + formatted.footer
                }
                if !result.relatedQuestions.isEmpty {
                    finalText += "\n\n**Related:** " + result.relatedQuestions.prefix(3).joined(separator: " · ")
                }                // Reply-first: render the answer immediately. The durable
                // recording (Honeycomb sources + brief, with best-effort page
                // enrichment) runs in a background task so page fetches never
                // stack on top of Vane's own research latency; the "saved to
                // memory / N of M fetched" notes append via a follow-up
                // message when recording finishes.
                self.lastGeminiProvider = providerLabel
                self.lastContextDiagnostics = ContextDiagnostics(
                    contextNodeCount: result.sources.count,
                    contextSummary: "\(result.sources.count) web source\(result.sources.count == 1 ? "" : "s") cited via \(providerLabel)",
                    rankerProvider: nil,
                    providerLabel: providerLabel,
                    durationMS: Int(Date().timeIntervalSince(started) * 1000),
                    pageTitle: nil,
                    pageHost: nil
                )
                self.replaceMessage(id: placeholder.id, text: finalText)

                let messageID = placeholder.id
                let query = trimmed
                Task { [weak self] in
                    guard let self else { return }
                    // Durable research (SWARM-002): persist sources to
                    // Honeycomb (deduped by URL or content hash) and save the
                    // cited answer as a brief, so every citation resolves to a
                    // retained source object (§7.3).
                    let recorder = ResearchRecorder(honeycomb: self.honeycomb)
                    // Fetch/extract each cited source through the
                    // policy-guarded SourceFetcher (SSRF/redirect/content-type/
                    // size/timeout), so the stored Source carries contentHash +
                    // extractedText + extractorVersion — the substrate claim
                    // spans will read from. Best-effort: un-fetchable pages
                    // degrade to metadata-only, never failing the research.
                    // HiveCore stays network-free; the URLSession hop lives
                    // here in the app layer (injected closure).
                    let fetcher = SourceFetcher(config: SourceFetcher.Config(timeout: .seconds(15))) { url in
                        // This closure is invoked once per SourceFetcher hop,
                        // including redirects. Validate here rather than only
                        // at the recorder boundary so hostname redirects get
                        // the same DNS preflight as the original URL.
                        try HiveDNSPolicy.validate(url)
                        var request = URLRequest(url: url)
                        request.timeoutInterval = 15
                        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Hive/1.0",
                                         forHTTPHeaderField: "User-Agent")
                        // Do not use URLSession.shared here: its default
                        // redirect behavior would bypass SourceFetcher’s
                        // per-hop scheme/SSRF checks. The delegate returns the
                        // raw 3xx response for SourceFetcher to inspect.
                        let redirectDelegate = HiveRedirectBlockingDelegate()
                        let configuration = URLSessionConfiguration.ephemeral
                        configuration.httpShouldSetCookies = false
                        configuration.httpCookieStorage = nil
                        let session = URLSession(configuration: configuration,
                                                  delegate: redirectDelegate,
                                                  delegateQueue: nil)
                        defer { session.invalidateAndCancel() }
                        let (data, response) = try await session.data(for: request)
                        var headers: [String: String] = [:]
                        if let http = response as? HTTPURLResponse {
                            for (key, value) in http.allHeaderFields {
                                if let k = key as? String, let v = value as? String {
                                    headers[k] = v
                                }
                            }
                        }
                        return SourceFetcher.FetchResponse(
                            data: data,
                            statusCode: (response as? HTTPURLResponse)?.statusCode ?? 0,
                            headers: headers,
                            finalURL: response.url ?? url
                        )
                    }
                    let recording: ResearchRecorder.Recording?
                    let recordingError: Error?
                    do {
                        recording = try await recorder.record(
                            query: query,
                            result: result,
                            enrich: { urlString in
                                guard let url = URL(string: urlString),
                                      url.scheme == "http" || url.scheme == "https"
                                else { return nil }
                                return try await fetcher.fetchAndExtract(from: url)
                            }
                        )
                        recordingError = nil
                    } catch {
                        // Sources/briefs may already exist when a later claim
                        // write fails. Keep their IDs out of a false success
                        // event, but record the attempt as partial so the user
                        // can distinguish "answer rendered" from "durable
                        // grounding complete".
                        recording = nil
                        recordingError = error
                    }
                    let realSourceIDs = recording?.sourceIDs ?? []
                    let enrichedCount = recording?.enrichedCount ?? 0
                    let claimIDs = recording?.claimIDs ?? []
                    let unmatchedCount = recording?.unmatchedCitationCount ?? 0
                    let persistenceErrorText = recording?.persistenceError

                    var contextIDs = realSourceIDs + claimIDs
                    if let briefID = recording?.briefID {
                        contextIDs.append(briefID)
                    }
                    let durableErrorText = recordingError?.localizedDescription ?? persistenceErrorText
                    let _ = await self.recordAuditEvent(EventLedgerStore.LedgerEvent(
                        id: UUID().uuidString,
                        timestamp: Date(),
                        actor: "user",
                        intent: "Web research: \(query)",
                        actionKind: .research,
                        actionTarget: "web-research://\(providerLabel)",
                        actionPreview: durableErrorText == nil
                            ? "\(result.sources.count) sources cited"
                            : "Research answer rendered; durable recording incomplete",
                        trustLevel: .t1,
                        policyDecision: .allowed,
                        consentState: .auto,
                        contextIDs: contextIDs,
                        environment: "swift-6",
                        result: durableErrorText == nil ? .success : .partial,
                        errorDescription: durableErrorText
                    ))

                    // Note: this background task is unstructured — it does not
                    // inherit cancellation from geminiGenerationTask. The
                    // recording is deliberately allowed to complete even if the
                    // user stops the visible generation: the answer was already
                    // rendered, and losing the durable brief would waste the
                    // research. (A guard on Task.isCancelled would be inert.)
                    var note = ""
                    if recording?.briefID != nil {
                        note += "\n\n_Saved to Hive memory as a brief._"
                    }
                    if enrichedCount > 0 {
                        note += "\n\n_\(enrichedCount) of \(result.sources.count) sources fetched for grounding._"
                    }
                    if !claimIDs.isEmpty {
                        note += "\n\n_\(claimIDs.count) claim\(claimIDs.count == 1 ? "" : "s") grounded with quote spans._"
                    }
                    if unmatchedCount > 0 {
                        note += "\n\n_\(unmatchedCount) citation\(unmatchedCount == 1 ? "" : "s") could not be grounded to stored text._"
                    }
                    if let durableErrorText {
                        note += "\n\n_Research answer shown, but durable grounding was incomplete: \(durableErrorText)_"
                    }
                    if !note.isEmpty, self.responseIsCurrent(responseID) {
                        self.appendNote(note, to: messageID)
                    }
                }
            } catch {
                guard self.responseIsCurrent(responseID), !Task.isCancelled else { return }
                self.lastContextDiagnostics = nil

                let retryHint: String
                switch self.activeResearchProvider() {
                case .vane:
                    retryHint = "Check that your Vane instance is running at \(self.vaneBaseURL.trimmingCharacters(in: .whitespaces)) and try again."
                case .tavily:
                    retryHint = "Check your Tavily API key in Settings → Performance → Web Research and try again."
                case .off, nil:
                    retryHint = "Configure Web Research in Settings → Performance and try again."
                }
                self.replaceMessage(id: placeholder.id, text:
                    "Research failed: \(error.localizedDescription)\n\n\(retryHint)")
            }
        }
    }


    func setPreferredModelProvider(_ rawValue: String) {
        preferredModelProvider = rawValue
        scheduleAutosave()
    }
}
