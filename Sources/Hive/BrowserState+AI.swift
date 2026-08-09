//
//  BrowserState+AI.swift
//  Hive
//
//  Carved out of BrowserState.swift by scripts/split_browser_state.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - AI Infrastructure (Swarm agent pipeline) | Model Council (parallel multi-model AI dispatch) | - Unified Agent Pipeline | Agent pipeline helpers | - Summarize (Comet / Dia / Edge)
//

import SwiftUI
import Observation
import CefSwiftUI
import CefKit
import HiveCore
import AppKit


// MARK: - BrowserState + AI

@MainActor
extension BrowserState {

    /// Combined disclosure state for the browser chrome.
    var isPersistenceDegraded: Bool {
        PersistenceHealthPolicy(
            knowledgeDegraded: isKnowledgePersistenceDegraded,
            auditDegraded: isAuditPersistenceDegraded,
            sessionDegraded: isSessionPersistenceDegraded
        ).isDegraded
    }

    var persistenceHealthPolicy: PersistenceHealthPolicy {
        PersistenceHealthPolicy(
            knowledgeDegraded: isKnowledgePersistenceDegraded,
            auditDegraded: isAuditPersistenceDegraded,
            sessionDegraded: isSessionPersistenceDegraded
        )
    }


    func dismissPersistenceHealthNotice() {
        isPersistenceHealthNoticeDismissed = true
    }


    /// Marks a runtime Honeycomb failure as degraded. The flag is intentionally
    /// sticky for this process: silently retrying writes into a damaged store
    /// would make the browser look durable when it is not.
    func reportKnowledgePersistenceFailure() {
        isKnowledgePersistenceDegraded = true
        isPersistenceHealthNoticeDismissed = false
    }


    /// Marks a runtime EventLedger failure as degraded. Consequential actions
    /// remain blocked after this point until Hive is restarted and the durable
    /// audit store opens successfully.
    func reportAuditPersistenceFailure() {
        isAuditPersistenceDegraded = true
        isPersistenceHealthNoticeDismissed = false
    }


    /// Latches a failed browser-session write. A later success cannot prove
    /// that the earlier mutation was retained, so this remains visible until
    /// the next launch reopens the durable session store.
    func reportSessionPersistenceFailure() {
        let latched = persistenceHealthPolicy.afterSessionWrite(succeeded: false)
        isKnowledgePersistenceDegraded = latched.knowledgeDegraded
        isAuditPersistenceDegraded = latched.auditDegraded
        isSessionPersistenceDegraded = latched.sessionDegraded
        isPersistenceHealthNoticeDismissed = false
    }


    /// Records an audit event without allowing a failed write to disappear
    /// behind `try?`. Every caller that treats the ledger as evidence must use
    /// this boundary so runtime SQLite failures become a sticky, user-visible
    /// degraded state.
    @discardableResult
    func recordAuditEvent(_ event: EventLedgerStore.LedgerEvent) async -> Bool {
        guard !isAuditPersistenceDegraded else { return false }
        do {
            _ = try await eventLedger.record(event)
            return true
        } catch {
            reportAuditPersistenceFailure()
            return false
        }
    }


    /// Wires the CDP client to a live CEF browser. Call from BrowserWindow
    /// when the active browser changes. Re-wires on every call (safe to call
    /// repeatedly — old observer is removed before new one is added).
    func wireCDP(to browser: CefBrowser) {
        browser.unregisterDevToolsHandler()
        cdpClient.wireSend { [weak browser] json in
            browser?.sendDevToolsMessage(json)
        }
        browser.onDevToolsMessage = { [weak self] json in
            self?.cdpClient.handleResponse(json)
        }
        browser.registerDevToolsHandler()
        applyAdBlockPolicy(to: browser)
    }

    /// Applies the current ad-block setting to a browser's CDP session via
    /// Network.enable + Network.setBlockedURLs (pure commands, no interception
    /// round-trip). Patterns come from the EasyList fallback domain list; the
    /// Rust engine's per-URL matching remains the cosmetic path. Best-effort:
    /// a failure is silent — browsing never depends on the blocker.
    func applyAdBlockPolicy(to target: CefBrowser? = nil) {
        let enabled = isAdBlockEnabled
        let patterns = enabled
            ? AdBlockPolicy.cdpURLPatterns(for: EasyListBlocklist.domains)
            : []
        guard let browser = target ?? activeModel?.browser else { return }
        // Routing note: the send below goes through `cdpClient`, which is wired
        // to the most recently activated browser. Callers re-apply on every
        // activation (wireCDP) and on pref change, so a stale task can only
        // re-block the *current* browser — a redundant but harmless send, and
        // the next activation re-applies the intended policy. Self-healing by
        // construction; never blocks a browser that shouldn't be.
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                _ = try await self.cdpClient.send(method: "Network.enable")
                _ = try await self.cdpClient.send(
                    method: "Network.setBlockedURLs",
                    params: ["urls": patterns]
                )
            } catch {
                // Non-fatal: ad blocking is best-effort and degrades silently.
            }
        }
    }

    /// Best-effort cosmetic ad hiding after a page finishes loading: asks the
    /// Rust engine for hide-selectors for this URL and injects them through
    /// the model's proven JS bridge (same path as the media/link probes).
    /// Requires the staged libhive_adblock_ffi.dylib (release bundles); debug
    /// builds no-op gracefully via the engine's readiness guard.
    func applyCosmeticAdBlock(on model: CefWebViewModel, url: URL) {
        guard isAdBlockEnabled else { return }
        Task { @MainActor in
            await AdblockEngine.shared.initialize()
            let selectors = AdblockEngine.shared.cosmeticSelectors(for: url)
            guard let script = AdBlockPolicy.cosmeticHideScript(selectors: selectors) else { return }
            model.executeJavaScript(script)
        }
    }

    var browserTransitionID: UInt64 { contextTransitionToken.current() }


    /// The active page's effective host visibility. This is diagnostic/UI state
    /// only; `activeContextScope` and explicit-tab classification enforce it.
    var activeHostContextState: HostContextPolicy.EffectiveState {
        if hostContextPolicyPersistenceFailed, !isPrivateBrowsing, activeModel?.url != nil {
            return .blocked
        }
        return hostContextPolicy.effectiveState(
            for: activeModel?.url,
            isPrivateBrowsing: isPrivateBrowsing,
            sessionAllowsPageContext: true
        )
    }


    var activeHostContextDecision: HostContextPolicy.Decision {
        if hostContextPolicyPersistenceFailed { return .block }
        return hostContextPolicy.decision(for: activeModel?.url)
    }


    var canConfigureActiveHostContext: Bool {
        guard !isPrivateBrowsing, let url = activeModel?.url else { return false }
        return HostContextPolicy.canonicalOrigin(for: url) != nil
    }


    /// Persists an explicit user decision and then advances the context
    /// transition FIFO so an in-flight request cannot retain the old page
    /// admission state. Model output and page content cannot call this method.
    func setActiveHostContextDecision(_ decision: HostContextPolicy.Decision) {
        guard canConfigureActiveHostContext,
              let url = activeModel?.url,
              let updated = hostContextPolicy.setting(decision, for: url) else { return }
        guard updated != hostContextPolicy else { return }
        hostContextPolicyMutationGeneration &+= 1
        let generation = hostContextPolicyMutationGeneration
        let previousPolicy = hostContextPolicy
        let store = hostContextPolicyStore
        // Apply immediately so a request created after the user's click cannot
        // observe the previous visibility decision. The durable actor remains
        // authoritative; failure below rolls back to a fail-closed block.
        hostContextPolicy = updated
        hostContextPolicyPersistenceFailed = false
        isHostContextPolicyMutationPending = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            let persisted = await store.set(decision, for: url, sequence: generation)
            guard generation == self.hostContextPolicyMutationGeneration else { return }
            self.isHostContextPolicyMutationPending = false
            if !persisted {
                // Never continue using an optimistic allow after persistence
                // fails. Block until the user explicitly chooses again. This
                // flag also covers the race where an older mutation succeeded
                // before the newest mutation failed: stale completions cannot
                // reopen the page boundary.
                self.hostContextPolicy = previousPolicy.setting(.block, for: url) ?? previousPolicy
                self.hostContextPolicyPersistenceFailed = true
                return
            }
            self.hostContextPolicyPersistenceFailed = false
            let transitionID = self.contextTransitionToken.advance()
            guard let coordinator = self.contextRequestCoordinator else { return }
            await coordinator.announceTransition(transitionID)
            await coordinator.bind(
                scope: self.activeContextScope,
                transitionID: transitionID,
                clearCurrentPage: false
            )
        }
    }


    /// The exact scope sent to the context broker for the current browser
    /// profile/workspace. UI controls mutate this contract through
    /// `setContextMode`; request paths reuse it rather than rebuilding a
    /// subtly different scope.
    var activeContextScope: ContextScope {
        // Private tabs are visible browser content but never valid Swarm
        // context. Keep the scope empty rather than relying on downstream
        // consumers to remember a private-tab exception.
        guard !isPrivateBrowsing else {
            return ContextScope(
                includesCurrentPage: false,
                includesHotMemory: false,
                includesProjectNodes: false,
                includesPreferences: false,
                includesPrivateContent: false,
                pageVisibility: .privateBrowsing
            )
        }
        return ContextScope(
            profileID: currentProfileID.uuidString,
            workspaceID: currentWorkspaceID.uuidString,
            includesCurrentPage: true,
            includesHotMemory: contextMode.includesHotMemory,
            includesProjectNodes: contextMode == .workspace,
            includesPreferences: contextMode == .workspace,
            pageVisibility: activeHostContextState
        )
    }


    /// Classifies explicit @tab selections for the composer without changing
    /// the admission policy used by the request executor. The returned values
    /// contain no page content; the view only renders their aggregate counts.
    func tabAttachmentSummary(for selectedIDs: Set<String>) -> TabAttachmentSummary {
        let candidates = tabs.map { tab in
            let tabURL = tab.model.url
            let hasUsableHTTPURL = tabURL.flatMap { url in
                guard let scheme = url.scheme?.lowercased(),
                      ["http", "https"].contains(scheme),
                      url.host != nil else { return nil }
                return true
            } ?? false
            let visibility = hostContextPolicy.effectiveState(
                for: tabURL,
                isPrivateBrowsing: isPrivateBrowsing || tab.isPrivate,
                sessionAllowsPageContext: true
            )
            return TabAttachmentSummary.Candidate(
                id: tab.id,
                profileID: tab.profileID.uuidString,
                workspaceID: tab.workspaceID.uuidString,
                isPrivate: tab.isPrivate,
                isActive: tab.id == activeTabID,
                hasUsableHTTPURL: hasUsableHTTPURL,
                pageVisibility: visibility
            )
        }
        let classifications = TabAttachmentSummary.classify(
            selectedIDs: selectedIDs,
            candidates: candidates,
            currentProfileID: currentProfileID.uuidString,
            currentWorkspaceID: currentWorkspaceID.uuidString,
            isPrivateBrowsing: isPrivateBrowsing,
            includesCurrentPage: activeContextScope.includesCurrentPage
        )
        return TabAttachmentSummary(
            selectedIDs: selectedIDs,
            classifications: classifications,
            isPrivateBrowsing: isPrivateBrowsing
        )
    }


    /// Changes the visible context contract and serializes the new binding
    /// through the same transition FIFO as profile/workspace switches. The
    /// current page remains available in both modes; only durable context
    /// expansion changes.
    func setContextMode(_ mode: ContextMode) {
        guard contextMode != mode else { return }
        contextMode = mode
        let transitionID = contextTransitionToken.advance()
        let scope = activeContextScope
        guard let coordinator = contextRequestCoordinator else { return }
        Task {
            await coordinator.announceTransition(transitionID)
            await coordinator.bind(scope: scope, transitionID: transitionID, clearCurrentPage: false)
        }
    }


    // MARK: Model Council (parallel multi-model AI dispatch)

    /// Convene the parallel model council for a question. Runs MLX-local,
    /// Tavily-cloud, and BYOK-remote models simultaneously and synthesizes
    /// through the chair model. Results are stored in ``latestCouncilVerdict``.
    /// Honest degradation: fewer models is visible, never silent.
    ///
    /// Uses streaming dispatch: each model's response appears in the UI
    /// as it arrives via ``councilLiveResponses``, then the synthesized
    /// verdict replaces them when the chair completes.
    func conveneCouncil(question: String, pageContext: String? = nil) {
        guard !isCouncilConvening, let council = modelCouncil else { return }

        // Cancel any stale task (safety)
        councilDeliberationTask?.cancel()

        isCouncilConvening = true
        latestCouncilVerdict = nil
        councilLiveResponses = []
        councilError = nil
        agentError = nil
        lastQuery = question
        broadcastWebChromeState()

        let query = CouncilQuery(
            question: question,
            pageContext: pageContext ?? buildPageContext()?.text,
            timeout: 30
        )

        // Launch deliberation as a cancellable Task
        councilDeliberationTask = Task {
            let stream = council.streamConvene(query)
            for await event in stream {
                // Check cancellation between events
                if Task.isCancelled { break }

                switch event {
                case .responseReceived(let response):
                    councilLiveResponses.append(response)
                    broadcastWebChromeState()
                case .degraded(let provider, let reason):
                    _ = (provider, reason)
                case .verdictReady(let verdict):
                    latestCouncilVerdict = verdict
                    councilLiveResponses = []
                    saveCouncilVerdict()
                    broadcastWebChromeState()
                }
            }

            if Task.isCancelled {
                // Clean up cancelled deliberation
                councilLiveResponses = []
                broadcastWebChromeState()
            }

            isCouncilConvening = false
        }
    }


    /// Cancel the active council deliberation. Stops in-flight providers
    /// via AsyncStream cancellation and resets UI state.
    func cancelCouncil() {
        councilDeliberationTask?.cancel()
        councilDeliberationTask = nil
        councilLiveResponses = []
        isCouncilConvening = false
        broadcastWebChromeState()
    }


    /// Cancels in-flight deep research.
    func cancelDeepResearch() {
        deepResearchTask?.cancel()
        deepResearchTask = nil
        deepResearchStep = nil
        broadcastWebChromeState()
    }


    /// Saves the current council verdict to UserDefaults as JSON.
    /// Called automatically when a verdict is set; small payload, one at a time.
    func saveCouncilVerdict() {
        guard let verdict = latestCouncilVerdict else { return }
        do {
            let data = try JSONEncoder().encode(verdict)
            UserDefaults.standard.set(data, forKey: "HiveCouncilVerdict")
        } catch {
            // Best-effort: verdict lives in memory regardless
        }
    }


    /// Restores a previously-saved council verdict from UserDefaults.
    /// Called once during init(); silently no-ops when no verdict was saved.
    func restoreCouncilVerdict() {
        guard let data = UserDefaults.standard.data(forKey: "HiveCouncilVerdict") else { return }
        do {
            latestCouncilVerdict = try JSONDecoder().decode(CouncilVerdict.self, from: data)
        } catch {
            UserDefaults.standard.removeObject(forKey: "HiveCouncilVerdict")
        }
    }


    /// Dismisses the current council verdict from the UI.
    /// Cancels any in-flight deliberation and clears all council state.
    func dismissCouncilVerdict() {
        councilDeliberationTask?.cancel()
        councilDeliberationTask = nil
        latestCouncilVerdict = nil
        councilLiveResponses = []
        deepResearchStep = nil
        deepResearchTask?.cancel()
        deepResearchTask = nil
        isCouncilConvening = false
        councilError = nil
        agentError = nil
        lastQuery = ""
        UserDefaults.standard.removeObject(forKey: "HiveCouncilVerdict")
        broadcastWebChromeState()
    }


    // MARK: - Unified Agent Pipeline

    /// Runs the full AI agent pipeline: council → deep research → browser actions.
    /// Each phase streams progress via ``agentTask`` and ``broadcastWebChromeState``.
    /// Cancel with ``cancelAgentPipeline()``.
    func runAgentPipeline(question: String) {
        guard agentPipelineTask == nil else { return }

        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        lastQuery = trimmed
        councilError = nil
        agentError = nil
        updateAgentTask(phase: "council", label: "Convening AI council…", progress: 0)

        agentPipelineTask = Task { [weak self] in
            guard let self else { return }

            // ── Phase 1: Council ──
            self.conveneCouncil(question: trimmed)
            // Wait for council to finish (poll the state since conveneCouncil is async)
            while self.isCouncilConvening && !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(200))
                let liveCount = self.councilLiveResponses.count
                self.updateAgentTask(phase: "council", label: "Council deliberating…", progress: min(Double(liveCount) / 4.0, 0.95))
            }
            if Task.isCancelled { self.finishAgentTask(success: false); return }

            let verdict = self.latestCouncilVerdict
            let answer = verdict?.answer ?? ""
            self.updateAgentTask(phase: "council", label: "Council complete", progress: 1.0, verdict: verdict)

            // ── Phase 2: Deep Research (if suggested) ──
            if answer.lowercased().contains("search") || answer.lowercased().contains("research") || answer.lowercased().contains("look up") {
                self.updateAgentTask(phase: "researching", label: "Researching…", progress: 0)
                self.performDeepResearch(query: trimmed)
                while self.deepResearchStep != nil && !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(200))
                    if let step = self.deepResearchStep {
                        self.updateAgentTask(phase: "researching", label: step.label, progress: step.progress)
                    }
                    if case .complete = self.deepResearchStep { break }
                }
                if Task.isCancelled { self.finishAgentTask(success: false); return }
                self.updateAgentTask(phase: "researching", label: "Research complete", progress: 1.0)
            }

            // ── Phase 3: Browser Actions ──
            let actions = self.extractBrowserActions(from: answer)
            if !actions.isEmpty {
                var results: [WebChromeAgentAction] = []
                for (i, action) in actions.enumerated() {
                    if Task.isCancelled { break }
                    let progress = Double(i) / Double(max(actions.count, 1))
                    self.updateAgentTask(phase: "acting", label: action.label, progress: progress, actions: results)
                    let success = await self.executeBrowserAction(action)
                    results.append(WebChromeAgentAction(tool: action.tool, label: action.label, success: success))
                    self.updateAgentTask(phase: "acting", label: action.label, progress: Double(i + 1) / Double(actions.count), actions: results)
                }
                if Task.isCancelled { self.finishAgentTask(success: false); return }
            }

            self.finishAgentTask(success: true)
        }
    }


    func cancelAgentPipeline() {
        agentPipelineTask?.cancel()
        agentPipelineTask = nil
        cancelCouncil()
        deepResearchTask?.cancel()
        deepResearchTask = nil
        deepResearchStep = nil
        agentTask = nil
        broadcastWebChromeState()
    }


    // MARK: Agent pipeline helpers

    func updateAgentTask(phase: String, label: String, progress: Double,
                                  verdict: CouncilVerdict? = nil, actions: [WebChromeAgentAction] = []) {
        let researchDTO: WebChromeDeepResearchStep?
        if let step = deepResearchStep {
            researchDTO = WebChromeDeepResearchStep(label: step.label, progress: step.progress,
                isComplete: { if case .complete = step { return true }; return false }())
        } else { researchDTO = nil }
        let verdictDTO: WebChromeCouncilVerdict?
        if let v = verdict ?? latestCouncilVerdict {
            verdictDTO = WebChromeCouncilVerdict(
                answer: v.answer, reasoning: v.reasoning,
                agreements: v.agreements, disagreements: v.disagreements,
                confidence: v.confidence, activeProviders: v.activeProviders.map(\.rawValue),
                isDegraded: v.isDegraded,
                responses: v.responses.map { r in WebChromeCouncilResponse(
                    provider: r.provider.rawValue, answer: r.answer, confidence: r.confidence,
                    durationMS: Int(r.duration * 1000), status: r.status == .success ? "success" : "timeout")})
        } else { verdictDTO = nil }
        agentTask = WebChromeAgentTask(
            question: latestCouncilVerdict != nil ? "" : (agentTask?.question ?? ""),
            phase: phase, stepLabel: label, stepProgress: progress,
            verdict: verdictDTO, research: researchDTO, actions: actions)
        broadcastWebChromeState()
    }


    func finishAgentTask(success: Bool) {
        updateAgentTask(phase: success ? "done" : "failed",
                        label: success ? "Complete" : "Cancelled", progress: 1.0)
        agentPipelineTask = nil
    }


    func extractBrowserActions(from answer: String) -> [BrowserAction] {
        var actions: [BrowserAction] = []
        // Parse [NAVIGATE: url] markers
        let navPattern = try? NSRegularExpression(pattern: #"\[NAVIGATE:\s*([^\]]+)\]"#, options: [])
        if let matches = navPattern?.matches(in: answer, range: NSRange(answer.startIndex..., in: answer)) {
            for match in matches {
                if let range = Range(match.range(at: 1), in: answer) {
                    let url = String(answer[range]).trimmingCharacters(in: .whitespaces)
                    actions.append(BrowserAction(tool: "navigate", label: "Open \(url)", url: url, selector: nil, value: nil))
                }
            }
        }
        // Parse [CLICK: selector] markers
        let clickPattern = try? NSRegularExpression(pattern: #"\[CLICK:\s*([^\]]+)\]"#, options: [])
        if let matches = clickPattern?.matches(in: answer, range: NSRange(answer.startIndex..., in: answer)) {
            for match in matches {
                if let range = Range(match.range(at: 1), in: answer) {
                    let sel = String(answer[range]).trimmingCharacters(in: .whitespaces)
                    actions.append(BrowserAction(tool: "click", label: "Click \(sel)", url: nil, selector: sel, value: nil))
                }
            }
        }
        // Parse [FILL: selector = value] markers
        let fillPattern = try? NSRegularExpression(pattern: #"\[FILL:\s*([^=]+?)\s*=\s*([^\]]+)\]"#, options: [])
        if let matches = fillPattern?.matches(in: answer, range: NSRange(answer.startIndex..., in: answer)) {
            for match in matches {
                if let selRange = Range(match.range(at: 1), in: answer),
                   let valRange = Range(match.range(at: 2), in: answer) {
                    let sel = String(answer[selRange]).trimmingCharacters(in: .whitespaces)
                    let val = String(answer[valRange]).trimmingCharacters(in: .whitespaces)
                    actions.append(BrowserAction(tool: "fill", label: "Fill \(sel)", url: nil, selector: sel, value: val))
                }
            }
        }
        return actions
    }


    func executeBrowserAction(_ action: BrowserAction) async -> Bool {
        do {
            switch action.tool {
            case "navigate":
                if let urlStr = action.url, let url = URL(string: urlStr) {
                    newTab(url: url, activate: true)
                }
                return true
            case "click":
                if let sel = action.selector {
                    _ = try await cdpClient.click(selector: sel)
                }
                return true
            case "fill":
                if let sel = action.selector, let val = action.value {
                    _ = try await cdpClient.fill(selector: sel, value: val)
                }
                return true
            default:
                return false
            }
        } catch {
            return false
        }
    }


    func dismissNavigationHealthNotice() {
        navigationHealthNotice = nil
    }


    /// Retries the exact URL that stalled, using a fresh tab-scoped navigation
    /// generation. A late completion from the old attempt cannot mutate this
    /// notice because the generation and model identity guards reject it.
    func retryNavigationHealthNotice() {
        guard let notice = navigationHealthNotice,
              let tab = tabs.first(where: { $0.id == notice.tabID }),
              !tab.isPrivate,
              !tab.isHibernated else {
            navigationHealthNotice = nil
            return
        }

        navigationHealthNotice = nil
        if tab.workspaceID != currentWorkspaceID {
            switchWorkspace(to: tab.workspaceID)
        }
        selectTab(id: tab.id)
        let attemptID = beginNavigationAttempt(for: tab)
        invalidatePreview(for: tab.id)
        tab.model.load(notice.url)
        armNavigationObservation(for: tab, attemptID: attemptID, url: notice.url)
    }


    /// Publishes a bounded, user-visible explanation for a blocked address-bar
    /// submission. The timeout prevents stale chrome from surviving unrelated
    /// navigation while the explicit dismiss path keeps the user in control.
    func showNavigationBlockNotice(for scheme: String) {
        navigationBlockNoticeTask?.cancel()
        navigationBlockNotice = NavigationBlockNotice(scheme: scheme)
        navigationBlockNoticeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.dismissNavigationBlockNotice()
        }
    }


    func dismissNavigationBlockNotice() {
        navigationBlockNoticeTask?.cancel()
        navigationBlockNoticeTask = nil
        navigationBlockNotice = nil
    }


    // MARK: - Summarize (Comet / Dia / Edge)

    func summarizeCurrentPage() {
        let title = activeModel?.title ?? "this page"
        geminiMessages.append(GeminiMessage(role: .user, text: "Summarize \(title)"))
        withAnimation(isReduceMotionEnabled ? nil : HiveDesign.Animation.spring) {
            isGeminiPanelOpen = true
        }
        // Use the Swarm agent pipeline: hot memory context → retrieval ranking → generation
        generateOrchestratedResponse(
            role: .summarizer,
            intent: "Summarize the page titled \"\(title)\". Give a brief overview of what this page is about.",
            maxTokens: 256
        )
    }
}
