import SwiftUI
import HiveCore
import os.log

// MARK: - SwarmChatView
//
// The Swarm chat panel — Hive's integrated intelligence surface. Lives as a sidebar
// or overlay panel, connected to Honeycomb memory and EventLedger for provenance.
//
// Context scopes:
//   - .page       → current active page only
//   - .tabs       → all open tabs
//   - .workspace  → current space's pages + Honeycomb memory
//   - .memory     → full Honeycomb knowledge graph
struct SwarmChatView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(ChromeState.self) private var state

    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var runState: SwarmRunState = .idle
    @State private var activeTask: Task<Void, Never>?
    @State private var researchSession: SwarmResearchSession?
    @State private var runGeneration: UInt64 = 0
    @State private var contextScope: SwarmContextScope = .page
    @State private var savedMessageID: UUID?
    @State private var memorySearchText: String = ""
    @State private var lastContextSize: Int = 0

    // MARK: - Voice dictation (Comet-style speak-to-fill)

    @State private var voiceManager = VoiceDictationManager()
    @State private var voiceTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            if state.honeycomb != nil && state.isWorkspaceOpen {
                SwarmWorkspaceView()
                Divider().overlay(Color.hiveBorderSubtle)
            }

            VStack(spacing: 0) {
                headerView

            if runState != .idle {
                runStatusView
            }

            Divider().overlay(Color.hiveBorderSubtle)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: HiveSpacing.s4) {
                        if state.swarmMessages.isEmpty {
                            emptyState
                        } else {
                            let messages = state.swarmMessages
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                                let isFirst = messageIsFirstInRun(at: index, in: messages)
                                SwarmMessageBubble(
                                    message: message,
                                    savedMessageID: $savedMessageID,
                                    isFirstInRun: isFirst
                                )
                                .id(message.id)
                                .padding(.top, isFirst ? HiveSpacing.s8 : 2)
                            }
                            if isLoading {
                                typingIndicator
                            }
                        }
                    }
                    .padding(HiveSpacing.s12)
                }
                .onChange(of: state.swarmMessages.count) { _, _ in
                    if let last = state.swarmMessages.last?.id {
                        withAnimation(reduceMotion ? nil : .hiveMicro) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }

            scopePicker
                .padding(.horizontal, HiveSpacing.s12)

            if lastContextSize > 0 {
                HStack(spacing: HiveSpacing.s4) {
                    Image(systemName: "doc.text")
                        .font(HiveTypography.font(.caption3))
                        .foregroundStyle(.hiveGraphite)
                    Text("Context: ~\(lastContextSize) chars")
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveGraphite)
                    if lastContextSize >= Self.tabsContextBudget {
                        Text("(max)")
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveAccent)
                    }
                }
                .padding(.horizontal, HiveSpacing.s12)
            }

            if state.honeycomb != nil {
                HStack(spacing: HiveSpacing.s8) {
                    Image(systemName: "magnifyingglass")
                        .font(HiveTypography.font(.caption3))
                        .foregroundStyle(.hiveGraphite)
                    TextField("Search memory...", text: $memorySearchText)
                        .textFieldStyle(.plain)
                        .hiveType(.bodySmall)
                        .onSubmit { searchMemory() }
                        .accessibilityLabel("Search archive")
                        .accessibilityIdentifier("swarm.memorySearch")
                    if !memorySearchText.isEmpty {
                        Button { searchMemory() } label: {
                            Text("Search")
                                .hiveType(.caption2)
                                .foregroundStyle(state.activeAccentColor)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("swarm.memorySearch.submit")
                    }
                }
                .padding(HiveSpacing.s8)
                .background(RoundedRectangle(cornerRadius: HiveRadius.r6).stroke(Color.hiveBorderSubtle))
                .padding(.horizontal, HiveSpacing.s12)
                .accessibilityLabel("Search archive")
            }

            Divider().overlay(Color.hiveBorderSubtle)

            inputBar
                .padding(HiveSpacing.s12)
            }
        }
        .hiveSurface(.swarm)
        .accessibilityIdentifier("swarm.panel")
        .onAppear {
            if let query = state.pendingSwarmQuery {
                state.pendingSwarmQuery = nil
                sendMessage(prefilled: query)
            }
        }
        .onDisappear {
            researchSession?.cancel()
            runGeneration &+= 1
            activeTask?.cancel()
            activeTask = nil
            isLoading = false
            if runState.isActive { runState = .cancelled }
            voiceTask?.cancel()
            if voiceManager.isRecording { voiceManager.stopRecording() }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        HStack(spacing: HiveSpacing.s8) {
            Image(systemName: "books.vertical")
                .foregroundStyle(state.activeAccentColor)
                .font(HiveTypography.font(.dialogTitle))
            Text("Librarian")
                .hiveType(.chromeTitle)
                .foregroundStyle(.hiveInk)
            Spacer()
            if state.honeycomb != nil {
                Button {
                    withAnimation(reduceMotion ? nil : .hiveExpand) {
                        state.isWorkspaceOpen.toggle()
                    }
                } label: {
                    Image(systemName: state.isWorkspaceOpen ? "sidebar.left" : "sidebar.left")
                        .font(HiveTypography.font(.caption1))
                        .foregroundStyle(state.isWorkspaceOpen ? state.activeAccentColor : .hiveGraphite)
                }
                .buttonStyle(.plain)
                .help("Toggle workspace browser")
                .accessibilityIdentifier("swarm.workspaceToggle")
            }
            if !state.swarmMessages.isEmpty {
                Button {
                    stopCurrentRun()
                    state.clearSwarmMessages()
                } label: {
                    Image(systemName: "trash")
                        .font(HiveTypography.font(.caption1))
                        .foregroundStyle(.hiveMist)
                }
                .buttonStyle(.plain)
                .help("Clear conversation")
                .accessibilityIdentifier("swarm.clearConversation")
            }
        }
        .padding(.horizontal, HiveSpacing.s12)
        .padding(.vertical, HiveSpacing.s8)
    }

    private var emptyState: some View {
        VStack(spacing: HiveSpacing.s16) {
            Image(systemName: "books.vertical")
                .font(HiveTypography.font(.display2))
                .foregroundStyle(state.activeAccentColor.opacity(0.5))
            Text("Query your archive")
                .hiveType(.body)
                .foregroundStyle(.hiveInk)
            VStack(alignment: .leading, spacing: HiveSpacing.s8) {
                suggestionChip("Summarize this page")
                suggestionChip("What are the key points?")
                suggestionChip("Compare with my other tabs")
                suggestionChip("Find related sources in my archive")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HiveSpacing.s48)
    }

    private func suggestionChip(_ text: String) -> some View {
        Button {
            inputText = text
            sendMessage()
        } label: {
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: "arrow.up.message")
                    .font(HiveTypography.font(.caption2))
                Text(text)
                    .hiveType(.bodySmall)
            }
            .foregroundStyle(.hiveGraphite)
            .padding(.horizontal, HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s8)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .stroke(Color.hiveBorderSubtle, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var scopePicker: some View {
        Picker("Context", selection: $contextScope) {
            ForEach(SwarmContextScope.allCases) { scope in
                Text(scope.label).tag(scope)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .accessibilityIdentifier("swarm.contextScope")
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            // Transcription preview — shows live dictation text above the composor
            if voiceManager.isRecording && !voiceManager.transcribedText.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "waveform")
                        .font(HiveTypography.font(.caption3))
                        .foregroundStyle(.red)
                    Text(voiceManager.transcribedText)
                        .hiveType(.bodySmall)
                        .foregroundStyle(.hiveGraphite)
                        .lineLimit(3)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: HiveRadius.r8)
                        .fill(Color.red.opacity(0.05))
                )
                .padding(.bottom, 6)
            }

            // Comet-style slash-command chips — expand into the composer, never
            // auto-fire. Every expansion maps to a command the IntentOrchestrator
            // actually recognizes, so nothing here is theater.
            if showSlashChips {
                SlashCommandChipStrip { expansion in
                    inputText = expansion
                }
                .padding(.bottom, HiveSpacing.s4)
            }

            HStack(spacing: HiveSpacing.s8) {
                // Mic button — Comet-style voice dictation
                Button {
                    toggleVoiceInput()
                } label: {
                    Image(systemName: voiceManager.isRecording ? "mic.fill" : "mic")
                        .font(HiveTypography.font(.dialogTitle))
                        .foregroundStyle(voiceManager.isRecording ? .red : .hiveGraphite)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(voiceManager.isRecording
                                    ? Color.red.opacity(0.10)
                                    : Color.secondary.opacity(0.06))
                        )
                }
                .buttonStyle(.plain)
                .help(voiceManager.isRecording ? "Stop recording and send" : "Start voice dictation")
                .accessibilityLabel(voiceManager.isRecording ? "Stop recording" : "Start voice dictation")
                .accessibilityIdentifier("swarm.mic")

                TextField("Ask the Librarian…", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .accessibilityIdentifier("swarm.composer")
                    .hiveType(.body)
                    .lineLimit(1...4)
                    .onSubmit { sendMessage() }

                if runState.isActive {
                    Button {
                        stopCurrentRun()
                    } label: {
                        Image(systemName: runState == .stopping ? "hourglass" : "stop.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(runState == .stopping ? .hiveMist : state.activeAccentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(runState == .stopping)
                    .help(runState == .stopping ? "Stopping Swarm" : "Stop Swarm")
                    .accessibilityLabel(runState == .stopping ? "Stopping Swarm" : "Stop Swarm")
                    .accessibilityIdentifier("swarm.stop")
                } else {
                    Button {
                        sendMessage()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(inputText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? .hiveMist : state.activeAccentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
                    .accessibilityLabel("Send to Swarm")
                    .accessibilityIdentifier("swarm.send")
                }
            }
            .padding(HiveSpacing.s8)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .fill(Color.hiveSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: HiveRadius.r8)
                            .stroke(Color.hiveBorderSubtle, lineWidth: 1)
                    )
            )
        }
    }

    /// True while the user is composing a `/`-command (typed `/` with no space
    /// yet) — the chip strip is shown then, and hides as soon as they continue.
    private var showSlashChips: Bool {
        inputText.hasPrefix("/") && !inputText.contains(" ")
    }

    private var runStatusView: some View {
        HStack(spacing: HiveSpacing.s4) {
            Image(systemName: runState.systemImage)
                .font(HiveTypography.font(.caption3Semibold))
                .foregroundStyle(runState == .failed ? .orange : state.activeAccentColor)
            Text(runState.label)
                .hiveType(.caption2)
                .foregroundStyle(.hiveGraphite)
            if runState == .running {
                Text("· scope: \(contextScope.label)")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
            }
            Spacer()
            if runState == .failed {
                Button("Retry") {
                    retryWebResearch()
                }
                .buttonStyle(.plain)
                .hiveType(.caption2)
                .foregroundStyle(state.activeAccentColor)
                .accessibilityIdentifier("swarm.retry")
            }
        }
        .padding(.horizontal, HiveSpacing.s12)
        .padding(.vertical, HiveSpacing.s4)
        .accessibilityIdentifier("swarm.status")
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Swarm status: \(runState.label)")
    }

    /// ChatGPT-style typing indicator — three dots with sequential opacity pulse.
    /// Each dot fades 0→1→0 over 1.2s, staggered 0.2s apart, creating a smooth wave.
    @State private var typingPhase: Double = 0

    private var typingIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(state.activeAccentColor.opacity(typingDotOpacity(for: i)))
                    .frame(width: 7, height: 7)
            }
        }
        .padding(.horizontal, HiveSpacing.s16)
        .padding(.vertical, HiveSpacing.s8)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r12)
                .fill(Color.hiveSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.r12)
                        .stroke(Color.hiveBorderSubtle, lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.03), radius: 4, y: 2)
        )
        .onAppear {
            withAnimation(reduceMotion ? nil : .linear(duration: 1.2).repeatForever(autoreverses: false)) {
                typingPhase = 1.0
            }
        }
    }

    /// Computes opacity for typing dot `i` (0-2) based on `typingPhase`.
    /// Each dot is offset by 0.2 in the 0..1 cycle, producing a staggered wave.
    private func typingDotOpacity(for i: Int) -> CGFloat {
        let offset = (typingPhase + Double(i) * 0.33).truncatingRemainder(dividingBy: 1.0)
        // Sinusoidal pulse: peaks at 0.5, fades to 0 at edges
        let raw = sin(offset * .pi)
        return max(0.15, raw * 0.7)  // never fully transparent, max 0.7 opacity
    }

    // MARK: - Actions

    private func sendMessage(prefilled: String? = nil) {
        let text = (prefilled ?? inputText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isLoading else { return }

        // Phase 0: Classify intent via the deterministic orchestrator.
        // This runs BEFORE any model dispatch — pure rules, <1ms, no network.
        let intent = IntentOrchestrator.classify(text, isWebScope: contextScope == .web)

        // Auto-switch scope based on classified intent so the context matches.
        let effectiveScope = intent.category == .webResearch ? .web
            : intent.category == .memorySearch ? .memory
            : contextScope
        if effectiveScope != contextScope {
            contextScope = effectiveScope
        }

        let userMessage = SwarmMessage(
            role: .user, content: text, scope: effectiveScope,
            intentCategory: intent.category.rawValue
        )
        state.swarmMessages.append(userMessage)
        if prefilled == nil { inputText = "" }
        activeTask?.cancel()
        researchSession?.cancel()
        runGeneration &+= 1
        isLoading = true
        runState = .running
        let generation = runGeneration

        // Phase 1: Route based on classified intent category.

        // .clarification — ask, don't assume. Append a clarifying question.
        if intent.needsClarification {
            let question = IntentOrchestrator.clarifyingQuestion(for: intent)
            appendRoutingMessage(text, question, generation: generation)
            return
        }

        // .browserAction — open URL, no model needed.
        if intent.category == .browserAction, let url = intent.params.targetURL {
            state.newTab(url: url)
            appendRoutingMessage(text, "Opening \(url.absoluteString)", generation: generation)
            return
        }

        // .systemCommand — execute chrome action.
        if intent.category == .systemCommand {
            executeSystemCommand(intent, generation: generation)
            return
        }

        // .pageQuestion — grounded Q&A on the active tab.
        if intent.category == .pageQuestion {
            let question = intent.params.searchQuery ?? text
            activeTask = Task {
                let answer = await state.askOnPage(question: question)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard generation == runGeneration else { return }
                    isLoading = false
                    runState = .completed
                    activeTask = nil
                    let provider = answer.providerLabel.isEmpty ? "pageQa" : "pageQa:\(answer.providerLabel)"
                    let body: String
                    switch answer.answerType {
                    case .found:
                        body = answer.answer + (answer.basis.isEmpty ? "" :
                            "\n\n*Grounded in this page* (\(String(format: "%.0f%%", answer.confidence * 100)) confidence)" +
                            answer.basis.map { "\n> „\($0.span)" }.joined())
                    case .pageDoesNotSay:
                        body = "This page doesn't say. \(answer.answer)"
                    case .pageClaimUnverified:
                        body = "\(answer.answer)\n\n*The page makes this claim but it is unverified.*"
                    case .privateBrowsing:
                        body = "This page is private, so Swarm did not inspect or retain its contents."
                    case .aiContextDisabled:
                        body = "Swarm page access is off for this tab, so its contents were not inspected."
                    case .parseError:
                        body = "Couldn't get an answer from the page-qa Cell\(answer.answer.isEmpty ? "" : ": \(answer.answer)")."
                    }
                    state.swarmMessages.append(SwarmMessage(
                        role: .assistant, content: body, scope: effectiveScope, providerLabel: provider))
                }
            }
            return
        }

        // .webResearch — stream through WebSearchProvider.
        if intent.category == .webResearch {
            let query = intent.params.searchQuery ?? text
            activeTask = nil
            streamWebSearch(prompt: query, generation: generation)
            return
        }

        // .memorySearch — search Honeycomb.
        if intent.category == .memorySearch {
            let query = intent.params.searchQuery ?? text
            executeMemorySearch(query: query, generation: generation)
            return
        }

        // .knowledgeAction — trigger brief/project creation.
        if intent.category == .knowledgeAction {
            let cmd = intent.params.commandVerb ?? ""
            if cmd == "project", let name = intent.params.commandArg, !name.isEmpty {
                Task {
                    let project = Project(title: name)
                    if let hc = state.honeycomb {
                        _ = try? await hc.createProject(project)
                    }
                    await MainActor.run {
                        guard generation == runGeneration else { return }
                        appendRoutingMessage(text, "Created project \"\(name)\". Open the workspace sidebar to see it.", generation: generation)
                    }
                }
                return
            }
            if cmd == "brief" {
                appendRoutingMessage(text, "To save as a brief: click 'Save as Brief' on any assistant message, or ask the Librarian a research question first.", generation: generation)
                return
            }
            // Fall through to generic question for other knowledge actions.
        }

        // .codeAction — route through librarian (future: Studio Cell).
        // Falls through to genericQuestion for now.

        // .genericQuestion / fallback — dispatch through the Cell system.
        activeTask = Task {
            let context = await buildContext(for: effectiveScope)
            guard !Task.isCancelled else { return }
            await MainActor.run { lastContextSize = context.count }

            if await hasRealInferenceConfigured() {
                await streamSwarmResponse(prompt: text, context: context, scope: effectiveScope, generation: generation)
            } else {
                let response = await querySwarm(prompt: text, context: context, scope: effectiveScope)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    guard !Task.isCancelled, generation == runGeneration else { return }
                    isLoading = false
                    runState = .completed
                    activeTask = nil
                    state.swarmMessages.append(response)
                }
            }
        }
    }

    /// Appends a routing confirmation message (assistant role) and cleans up state.
    private func appendRoutingMessage(_ userText: String, _ response: String, generation: UInt64) {
        guard generation == runGeneration else { return }
        isLoading = false
        runState = .completed
        activeTask = nil
        state.swarmMessages.append(SwarmMessage(
            role: .assistant,
            content: response,
            scope: contextScope,
            providerLabel: "Orchestrator"
        ))
    }

    /// Executes a classified system command against the browser chrome.
    private func executeSystemCommand(_ intent: ClassifiedIntent, generation: UInt64) {
        let verb = intent.params.commandVerb ?? ""
        let arg = intent.params.commandArg ?? ""
        switch verb {
        case "close":
            if arg == "tab" || arg.isEmpty {
                if let activeID = state.activeTabID {
                    state.closeTab(activeID)
                }
                appendRoutingMessage(intent.rawInput, "Closed tab.", generation: generation)
            } else {
                appendRoutingMessage(intent.rawInput, "I understood 'close' but couldn't determine what to close.", generation: generation)
            }
        case "new":
            let url: URL? = {
                if arg.isEmpty || arg == "tab" { return nil }
                if let u = URL(string: arg), u.scheme != nil { return u }
                return URL(string: "https://www.google.com/search?q=\(arg.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? arg)")
            }()
            state.newTab(url: url)
            appendRoutingMessage(intent.rawInput, url != nil ? "Opening new tab…" : "New tab opened.", generation: generation)
        case "switch":
            if let spaceName = intent.params.spaceName, !spaceName.isEmpty {
                // Try to switch to the named space
                if let space = state.spaces.first(where: { $0.name.localizedCaseInsensitiveCompare(spaceName) == .orderedSame }) {
                    state.switchSpace(to: space.id)
                    appendRoutingMessage(intent.rawInput, "Switched to '\(space.name)'.", generation: generation)
                } else {
                    appendRoutingMessage(intent.rawInput, "No space named '\(spaceName)' found.", generation: generation)
                }
            } else {
                appendRoutingMessage(intent.rawInput, "I understood 'switch' — which space?", generation: generation)
            }
        case "open":
            if arg == "settings" {
                state.openSettings()
                appendRoutingMessage(intent.rawInput, "Opening Settings…", generation: generation)
            } else {
                appendRoutingMessage(intent.rawInput, "Command '\(verb)' with arg '\(arg)' is not yet implemented.", generation: generation)
            }
        default:
            appendRoutingMessage(intent.rawInput, "Command '\(verb)' is not yet implemented.", generation: generation)
        }
    }

    private func stopCurrentRun() {
        guard runState.isActive else { return }
        runState = .stopping
        researchSession?.cancel()
        runGeneration &+= 1
        activeTask?.cancel()
        activeTask = nil
        isLoading = false
        runState = .cancelled
    }

    /// True when a real inference path (BYOK or present local weights) is
    /// available for the current `swarmRole`. Used to decide whether to stream
    /// token-by-token or fall back to the non-streaming mock/memory path.
    private func hasRealInferenceConfigured() async -> Bool {
        await Dispatcher.shared.availableStreamingProvider(for: swarmRole) != nil
    }

    /// Streams a web research query through the configured `WebSearchProvider`.
    /// Updates the last assistant message in place as chunks arrive; persists sources to
    /// Honeycomb after the stream completes.
    private func streamWebSearch(prompt: String, generation: UInt64) {
        guard let provider = state.webSearchProvider else {
            guard generation == runGeneration else { return }
            isLoading = false
            runState = .failed
            activeTask = nil
            state.swarmMessages.append(SwarmMessage(
                role: .assistant,
                content: "Web search isn't configured. Enable Vane in Settings → Models and enter your self-hosted Vane URL.",
                scope: .web,
                providerLabel: SwarmMessage.errorProviderLabel
            ))
            return
        }

        let placeholderID = UUID()
        state.swarmMessages.append(SwarmMessage(
            role: .assistant,
            content: "",
            scope: .web,
            providerLabel: provider.displayName,
            id: placeholderID
        ))

        let session = researchSession ?? SwarmResearchSession()
        researchSession = session
        session.start(
            provider: provider,
            query: prompt,
            focusMode: state.prefs.vaneDefaultFocusMode
        ) { snapshot in
            applyResearchSnapshot(
                snapshot,
                to: placeholderID,
                generation: generation,
                providerLabel: provider.displayName
            )
        }
    }

    private func retryWebResearch() {
        guard let last = state.swarmMessages.last(where: { $0.role == .user }),
              let provider = state.webSearchProvider else { return }

        let placeholderID = UUID()
        let prompt = last.content
        state.swarmMessages.append(SwarmMessage(
            role: .assistant,
            content: "",
            scope: .web,
            providerLabel: provider.displayName,
            id: placeholderID
        ))
        runGeneration &+= 1
        let generation = runGeneration
        isLoading = true
        runState = .running

        let session = researchSession ?? SwarmResearchSession()
        researchSession = session
        guard session.retry(observe: { snapshot in
            applyResearchSnapshot(
                snapshot,
                to: placeholderID,
                generation: generation,
                providerLabel: provider.displayName
            )
        }) else {
            state.swarmMessages.removeAll { $0.id == placeholderID }
            streamWebSearch(prompt: prompt, generation: generation)
            return
        }
    }

    private func applyResearchSnapshot(
        _ snapshot: SwarmResearchState,
        to placeholderID: UUID,
        generation: UInt64,
        providerLabel: String
    ) {
        guard generation == runGeneration else { return }
        let presentation = snapshot.presentation
        let citations = presentation.sources.map { SwarmCitation(url: $0.url, title: $0.title) }
        let label: String
        switch presentation.phase {
        case .running, .completed:
            label = providerLabel
        case .failed:
            label = SwarmMessage.errorProviderLabel
        case .cancelled:
            label = SwarmMessage.cancelledProviderLabel
        }

        isLoading = presentation.isLoading
        switch presentation.phase {
        case .running: runState = .running
        case .completed: runState = .completed
        case .failed: runState = .failed
        case .cancelled: runState = .cancelled
        }
        updateAssistantMessage(
            id: placeholderID,
            content: presentation.content,
            citations: citations,
            providerLabel: label
        )

        if presentation.isTerminal {
            activeTask = nil
        }
        if presentation.phase == .completed {
            Task { await persistWebSourcesToHoneycomb(presentation.sources) }
        }
    }

    private func updateAssistantMessage(
        id: UUID,
        content: String,
        citations: [SwarmCitation],
        providerLabel: String? = nil,
        latencyMS: Int? = nil,
        tokensGenerated: Int? = nil
    ) {
        guard let index = state.swarmMessages.firstIndex(where: { $0.id == id && $0.role == .assistant }) else { return }
        let last = state.swarmMessages[index]
        let updated = SwarmMessage(role: .assistant,
                                   content: content,
                                   scope: last.scope,
                                   citations: citations,
                                   providerLabel: providerLabel ?? last.providerLabel,
                                   latencyMS: latencyMS ?? last.latencyMS,
                                   tokensGenerated: tokensGenerated ?? last.tokensGenerated,
                                   id: id)
        state.swarmMessages[index] = updated
    }

    private func appendToAssistantMessage(id: UUID, text: String, citations: [SwarmCitation]) {
        guard let index = state.swarmMessages.firstIndex(where: { $0.id == id && $0.role == .assistant }) else { return }
        let last = state.swarmMessages[index]
        let updated = SwarmMessage(role: .assistant,
                                   content: last.content + text,
                                   scope: last.scope,
                                   citations: citations,
                                   providerLabel: last.providerLabel,
                                   latencyMS: last.latencyMS,
                                   tokensGenerated: last.tokensGenerated,
                                   id: id)
        state.swarmMessages[index] = updated
    }

    /// Persists streamed web sources as Honeycomb Source nodes and links them to the active
    /// space/project for provenance. Runs after the stream completes.
    private func persistWebSourcesToHoneycomb(_ sources: [WebSearchSource]) async {
        guard !sources.isEmpty, let honeycomb = state.honeycomb else { return }
        for source in sources {
            guard let canonicalURL = WebSearchSource.canonicalHTTPURLString(source.url),
                  let url = URL(string: canonicalURL) else { continue }
            let hash = HoneycombStore.sha256(canonicalURL)
            let existing = try? await honeycomb.findNode(type: .source, contentHash: hash)
            if existing == nil {
                let node = HoneycombStore.Node(
                    type: .source,
                    label: source.title,
                    metadata: .object([
                        "url": .string(url.absoluteString),
                        "title": .string(source.title)
                    ]),
                    contentHash: hash,
                    provenance: "web-search"
                )
                _ = try? await honeycomb.insertNode(node)
            }
        }
    }

    /// Maximum characters to send per page for the `.page` scope. Approx. 2,000 tokens.
    private static let pageContextBudget = 8_000
    /// Maximum total characters for the `.tabs` scope. Approx. 4,000 tokens shared across tabs.
    private static let tabsContextBudget = 16_000

    private func buildContext(for scope: SwarmContextScope) async -> String {
        switch scope {
        case .page:
            guard let tab = state.activeTab, let url = tab.url else {
                return "No active page."
            }
            if let context = await state.extractActivePageContext() {
                let text = SwarmChatView.truncate(context.text, to: Self.pageContextBudget)
                return """
                Current page: \(context.title.isEmpty ? tab.displayTitle : context.title)
                URL: \(url.absoluteString)

                Page content (truncated to ~\(text.count) chars):
                \(text)
                """
            }
            // Fallback when extraction is unavailable (private/hibernated/no webview).
            return "Current page: \(tab.displayTitle)\nURL: \(url.absoluteString)"

        case .tabs:
            let contexts = await state.extractAllTabsContext()
            var budget = Self.tabsContextBudget
            var parts: [String] = []
            // Include a short header for every open tab, then fill remaining budget with text.
            for context in contexts {
                let header = "• \(context.title) — \(context.url?.absoluteString ?? "no URL")"
                let remaining = budget - header.count
                guard remaining > 200 else { break }
                let text = SwarmChatView.truncate(context.text, to: min(remaining, 4_000))
                budget -= (header.count + text.count + 2)
                parts.append("\(header)\n\(text)")
            }
            // Always include a lightweight list of all tabs (including hibernated/private)
            // so the model sees the full set even if extraction was skipped for some.
            let allTabs = state.tabs.map { "• \($0.title) — \($0.url?.absoluteString ?? "no URL")" }
            return (parts + ["Open tabs:", allTabs.joined(separator: "\n")]).joined(separator: "\n\n")

        case .workspace:
            let spaceContext = await buildContext(for: .tabs)
            let honeycomb = state.honeycomb
            let sources: [HoneycombStore.Node]
            if let hc = honeycomb {
                sources = (try? await hc.getNodesByType(.source, limit: 5)) ?? []
            } else {
                sources = []
            }
            let captureTexts = sources.map { source in
                "• Source: \(source.label)"
            }
            let parts = [spaceContext, "Recent captures:"] + captureTexts
            return parts.joined(separator: "\n")

        case .memory:
            let honeycomb = state.honeycomb
            let sources: [HoneycombStore.Node]
            if let hc = honeycomb {
                sources = (try? await hc.getNodesByType(.source, limit: 20)) ?? []
            } else {
                sources = []
            }
            let captureTexts = sources.map { source in
                "• Source: \(source.label)"
            }
            return (["Memory (recent captures):"] + captureTexts).joined(separator: "\n")

        case .web:
            // Web search does not use local context; the provider searches the open web.
            return ""
        }
    }

    /// Truncates text at word boundaries and appends a clear truncation marker.
    private static func truncate(_ text: String, to limit: Int) -> String {
        guard text.count > limit else { return text }
        let trimmed = String(text.prefix(limit))
        if let lastSpace = trimmed.lastIndex(of: " ") {
            return String(trimmed[..<lastSpace]) + "… [truncated]"
        }
        return trimmed + "… [truncated]"
    }

    private func querySwarm(prompt: String, context: String, scope: SwarmContextScope) async -> SwarmMessage {
        let fullPrompt = """
        Context:
        \(context)

        User question: \(prompt)

        Instructions:
        - Answer based primarily on the context provided.
        - Cite sources by URL when referencing specific pages.
        - Be concise but thorough.
        - If the context doesn't contain enough information, say so honestly.
        """

        if let result = await tryGenerate(prompt: fullPrompt) {
            // Honest mock fallback: if no real model is configured, explain the situation
            // rather than silently emitting a low-fidelity placeholder.
            if result.provider == .mock {
                if let memoryAnswer = await answerFromMemory(query: prompt, scope: scope) {
                    return memoryAnswer
                }

                let cta = """
                I’m ready to answer, but no on-device model is loaded yet. To get real answers:

                1. Download MLX weights (e.g. Qwen3-0.6B) to ~/.hive/models, or
                2. Add a BYOK provider key in Settings → Models.

                Your question: "\(prompt)"
                """
                return SwarmMessage(
                    role: .assistant,
                    content: cta,
                    scope: scope,
                    providerLabel: "Mock — no model loaded"
                )
            }

            return SwarmMessage(
                role: .assistant,
                content: result.text,
                scope: scope,
                citations: extractCitations(from: result.text),
                providerLabel: result.modelLabel,
                latencyMS: result.latencyMS,
                tokensGenerated: result.tokensGenerated
            )
        }

        return SwarmMessage(
            role: .assistant,
            content: "Couldn't generate a response. Check that a model is configured in Settings, then try again.",
            scope: scope,
            providerLabel: SwarmMessage.errorProviderLabel
        )
    }

    private static let swarmLogger = Logger(subsystem: "com.hive.browser", category: "SwarmChat")

    /// The role Swarm dispatches to. Uses BYOK when the user has enabled and configured a
    /// remote model; otherwise falls back to the local-first librarian role (MLX/Apple FMF/Mock).
    private var swarmRole: ModelRole {
        state.prefs.byokEnabled && !state.prefs.byokBaseURL.isEmpty
            ? .byokFrontier
            : .librarian
    }

    private func tryGenerate(prompt: String) async -> GenerateResult? {
        do {
            // BYOK (remote) when configured; otherwise the local-first librarian role.
            // Dispatcher handles the honest fallback chain (MLX → Apple FMF → Mock).
            return try await Dispatcher.shared.generateWithCellPrompt(
                for: swarmRole,
                userInput: prompt,
                loader: state.cellPromptLoader
            )
        } catch {
            SwarmChatView.swarmLogger.error("Generation failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    /// Streams a response from the configured model path and updates the placeholder
    /// assistant message as chunks arrive. This is the real-time path used when a
    /// BYOK remote or present local model is available.
    private func streamSwarmResponse(prompt: String, context: String, scope: SwarmContextScope, generation: UInt64) async {
        let fullPrompt = """
        Context:
        \(context)

        User question: \(prompt)

        Instructions:
        - Answer based primarily on the context provided.
        - Cite sources by URL when referencing specific pages.
        - Be concise but thorough.
        - If the context doesn't contain enough information, say so honestly.
        """

        let placeholderID = UUID()
        let provider = await Dispatcher.shared.availableStreamingProvider(for: swarmRole)
        let providerLabel = streamingProviderLabel(provider)
        let placeholder = SwarmMessage(role: .assistant,
                                       content: "",
                                       scope: scope,
                                       providerLabel: providerLabel,
                                       id: placeholderID)
        await MainActor.run {
            state.swarmMessages.append(placeholder)
        }

        // Honest run provenance on the streaming path: wall-clock time and a
        // chunk count (an approximation of tokens, real and observable).
        let streamStart = Date()
        var chunkCount = 0

        do {
            let stream = await Dispatcher.shared.streamGenerateWithCellPrompt(
                for: swarmRole,
                userInput: fullPrompt,
                loader: state.cellPromptLoader
            )
            for try await chunk in stream {
                try Task.checkCancellation()
                chunkCount += 1
                await MainActor.run {
                    guard generation == runGeneration else { return }
                    isLoading = false
                    runState = .running
                    appendToAssistantMessage(id: placeholderID, text: chunk, citations: [])
                }
            }
            // Extract citations from the final text once the stream completes.
            let elapsedMS = Int(Date().timeIntervalSince(streamStart) * 1000)
            await MainActor.run {
                guard generation == runGeneration else { return }
                isLoading = false
                runState = .completed
                activeTask = nil
                if let index = state.swarmMessages.firstIndex(where: { $0.id == placeholderID && $0.role == .assistant }) {
                    let message = state.swarmMessages[index]
                    let citations = extractCitations(from: message.content)
                    let updated = SwarmMessage(role: .assistant,
                                               content: message.content,
                                               scope: message.scope,
                                               citations: citations,
                                               providerLabel: message.providerLabel,
                                               latencyMS: elapsedMS,
                                               tokensGenerated: chunkCount,
                                               id: message.id)
                    state.swarmMessages[index] = updated
                }
            }
        } catch is CancellationError {
            await MainActor.run {
                guard generation == runGeneration else { return }
                isLoading = false
                runState = .cancelled
                activeTask = nil
                updateAssistantMessage(
                    id: placeholderID,
                    content: "Response stopped before it completed.",
                    citations: []
                )
            }
        } catch {
            SwarmChatView.swarmLogger.error("Streaming generation failed: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                guard generation == runGeneration else { return }
                isLoading = false
                runState = .failed
                activeTask = nil
                updateAssistantMessage(
                    id: placeholderID,
                    content: "Couldn't complete the response: \(error.localizedDescription)",
                    citations: []
                )
            }
        }
    }

    /// Returns a human-readable provider label for the streaming response.
    private func streamingProviderLabel(_ provider: GenerateResult.Provider?) -> String {
        switch provider {
        case .byokRemote:
            return "BYOK — \(state.prefs.byokModelID)"
        case .mlx:
            return "MLX — \(ModelManifest.entries[swarmRole]?.baseModel ?? "local model")"
        case .appleFMF:
            return "Apple Foundation Models"
        case .systemEmbedder:
            return "On-device embedder"
        case .rule:
            return "Deterministic rules"
        case nil, .mock:
            return "Provider unavailable"
        }
    }

    /// Executes a Honeycomb memory search with the given query. Called both from
    /// the orchestrator's .memorySearch route and the chat's search bar.
    private func executeMemorySearch(query: String, generation: UInt64? = nil) {
        let query = query.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty, let honeycomb = state.honeycomb else { return }
        let gen = generation ?? runGeneration
        let scope = contextScope
        activeTask?.cancel()
        isLoading = true
        runState = .running
        activeTask = Task {
            do {
                let results = try await honeycomb.search(query: query, limit: 5)
                try Task.checkCancellation()
                let resultTexts = results.map { "\($0.type.rawValue): \($0.label)" }
                let msg = results.isEmpty
                    ? "No results found for \"\(query)\" in memory."
                    : "Memory search for \"\(query)\":\n\(resultTexts.joined(separator: "\n"))"
                await MainActor.run {
                    guard gen == runGeneration else { return }
                    isLoading = false
                    runState = .completed
                    activeTask = nil
                    memorySearchText = ""
                    state.swarmMessages.append(SwarmMessage(role: .assistant, content: msg, scope: scope))
                }
            } catch is CancellationError {
                await MainActor.run {
                    guard gen == runGeneration else { return }
                    isLoading = false
                    runState = .cancelled
                    activeTask = nil
                }
            } catch {
                await MainActor.run {
                    guard gen == runGeneration else { return }
                    isLoading = false
                    runState = .failed
                    activeTask = nil
                    state.swarmMessages.append(SwarmMessage(
                        role: .assistant,
                        content: "Couldn't search memory: \(error.localizedDescription)",
                        scope: scope,
                        providerLabel: SwarmMessage.errorProviderLabel
                    ))
                }
            }
        }
    }

    /// Backward-compatible wrapper: the search bar still uses @State memorySearchText.
    private func searchMemory() {
        let query = memorySearchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty, state.honeycomb != nil else { return }
        runGeneration &+= 1
        executeMemorySearch(query: query, generation: runGeneration)
    }

    /// Attempts to answer the user's question directly from the local Honeycomb archive when
    /// no generative model is loaded. This is the "Librarian" differentiator: real answers
    /// from captured sources, with citations, even when the model stack is unavailable.
    private func answerFromMemory(query: String, scope: SwarmContextScope) async -> SwarmMessage? {
        guard let honeycomb = state.honeycomb else { return nil }

        let results: [HoneycombStore.Node]
        do {
            results = try await honeycomb.search(query: query, limit: 5)
        } catch {
            return nil
        }

        // Build a list of Source-backed citations and a short human-readable answer.
        var citations: [SwarmCitation] = []
        var lines: [String] = []
        for node in results {
            if let source = Source.from(node) {
                let title = source.title?.isEmpty == false ? source.title! : source.url
                lines.append("• \(title)")
                citations.append(SwarmCitation(url: source.url, title: title))
            } else if node.type == .capture {
                // Captures carry their source URL in metadata.
                let url = extractURL(from: node.metadata) ?? node.label
                let title = node.label.isEmpty ? url : node.label
                lines.append("• \(title)")
                if url.hasPrefix("http") {
                    citations.append(SwarmCitation(url: url, title: title))
                }
            } else if node.type == .claim, let claim = Claim.from(node) {
                lines.append("• \(claim.text)")
            } else {
                lines.append("• \(node.label)")
            }
        }

        guard !lines.isEmpty else { return nil }

        let preamble = "I searched your archive and found \(lines.count) match(es) related to \"\(query)\"."
        let body = ([preamble, ""] + lines).joined(separator: "\n")

        return SwarmMessage(
            role: .assistant,
            content: body,
            scope: scope,
            citations: citations,
            providerLabel: "Archive (no model loaded)"
        )
    }

    /// Pulls a source URL out of a Capture node's metadata if present.
    private func extractURL(from metadata: JSONValue) -> String? {
        guard case .object(let dict) = metadata, case .string(let url) = dict["url"] else {
            return nil
        }
        return url
    }

    private func extractCitations(from text: String) -> [SwarmCitation] {
        let pattern = try? NSRegularExpression(pattern: "https?://[^\\s,\\)]+", options: [])
        let range = NSRange(text.startIndex..., in: text)
        let matches = pattern?.matches(in: text, range: range) ?? []
        return matches.compactMap { match -> SwarmCitation? in
            guard let matchRange = Range(match.range, in: text) else { return nil }
            let url = String(text[matchRange])
            let title = url.components(separatedBy: "/").last ?? url
            return SwarmCitation(url: url, title: title)
        }
    }

    /// Returns true when the message at `index` is the first in a consecutive run of
    /// same-role messages (ChatGPT-style grouping). Only the role matters — citations
    /// don't break a run, matching how ChatGPT groups replies.
    private func messageIsFirstInRun(at index: Int, in messages: [SwarmMessage]) -> Bool {
        guard index > 0 else { return true }
        return messages[index - 1].role != messages[index].role
    }

    /// Parses the `@this <question>` (or alias `@page`) ask-on-page route from a chat line.
    /// Returns the question, or nil when the line is not an ask-on-page invocation.
    /// Case-insensitive on the prefix; requires a non-empty question after it.
    private static func askOnPageQuestion(from text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["@this", "@page"] where trimmed.lowercased().hasPrefix(prefix) {
            let rest = trimmed.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rest.isEmpty { return rest }
        }
        return nil
    }

    // MARK: - Voice dictation

    /// Toggles local voice dictation. When recording stops, the transcribed text
    /// fills the composor and auto-sends — Comet-style speak-to-ask.
    private func toggleVoiceInput() {
        if voiceManager.isRecording {
            let finalText = voiceManager.transcribedText
            voiceManager.stopRecording()
            voiceTask?.cancel()
            voiceTask = Task { @MainActor in
                let trimmed = finalText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty, !Task.isCancelled else { return }
                inputText = trimmed
                sendMessage()
            }
            return
        }

        voiceTask?.cancel()
        if voiceManager.isRecording { voiceManager.stopRecording() }
        voiceTask = Task { @MainActor in
            if !voiceManager.isAuthorized {
                guard await voiceManager.requestAuthorization() else { return }
            }
            guard !Task.isCancelled else { return }
            do {
                try voiceManager.startRecording()
            } catch {
                Self.swarmLogger.error("Voice dictation failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

// MARK: - Models

struct SwarmMessage: Identifiable, Equatable, Sendable {
    enum Role: String, Equatable, Codable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    let content: String
    let scope: SwarmContextScope
    let citations: [SwarmCitation]
    let timestamp = Date()
    /// Model/provider label that produced the response (e.g. "MLX — Qwen3-0.6B" or
    /// "Mock — no model loaded"). Shown as a small provenance badge.
    let providerLabel: String?
    /// Classified intent category from the orchestrator. Shown as a badge on user
    /// messages so the user can see what Swarm understood.
    let intentCategory: String?
    /// Wall-clock inference time in ms for this response (from the run that produced
    /// it). Honest provenance — shown in the collapsible run-details block.
    let latencyMS: Int?
    /// Token count for this response (model-reported, or chunks counted on the
    /// streaming path). Honest provenance — shown in run details.
    let tokensGenerated: Int?

    /// Sentinel label for the error fallback state; used instead of a bare magic string.
    static let errorProviderLabel = "Error"
    static let cancelledProviderLabel = "Stopped"

    /// True when this message represents a generation error rather than a normal response.
    var isError: Bool { providerLabel == Self.errorProviderLabel }

    init(role: Role,
         content: String,
         scope: SwarmContextScope = .page,
         citations: [SwarmCitation] = [],
         providerLabel: String? = nil,
         intentCategory: String? = nil,
         latencyMS: Int? = nil,
         tokensGenerated: Int? = nil,
         id: UUID? = nil) {
        self.role = role
        self.content = content
        self.scope = scope
        self.citations = citations
        self.id = id ?? UUID()
        self.providerLabel = providerLabel
        self.intentCategory = intentCategory
        self.latencyMS = latencyMS
        self.tokensGenerated = tokensGenerated
    }
}

struct SwarmCitation: Identifiable, Equatable, Sendable {
    let id = UUID()
    let url: String
    let title: String
}

enum SwarmContextScope: String, CaseIterable, Identifiable {
    case page
    case tabs
    case workspace
    case memory
    case web

    var id: String { rawValue }

    var label: String {
        switch self {
        case .page:      return "Page"
        case .tabs:      return "Tabs"
        case .workspace: return "Workspace"
        case .memory:    return "Memory"
        case .web:       return "Web"
        }
    }
}

// MARK: - CitedMessageContent

private enum ContentSegment: Identifiable {
    case text(String)
    case code(String, language: String?)

    var id: String {
        switch self {
        case .text(let t):   return "t:\(t.hashValue)"
        case .code(let c, _): return "c:\(c.hashValue)"
        }
    }
}

private enum InlineCodePart {
    case plain(String)
    case codeSpan(String)
}

/// Parses inline code spans (single backticks) within text, returning alternating
/// `.plain` / `.codeSpan` parts. Unmatched backticks render as plain text.
private func parseInlineCode(_ text: String) -> [InlineCodePart] {
    var parts: [InlineCodePart] = []
    var remaining = text[...]

    while !remaining.isEmpty {
        guard let tick = remaining.firstIndex(of: "`") else {
            if !remaining.isEmpty { parts.append(.plain(String(remaining))) }
            break
        }
        // Text before the tick
        if tick > remaining.startIndex {
            parts.append(.plain(String(remaining[..<tick])))
        }
        // Find matching closing tick
        let afterTick = remaining.index(after: tick)
        if let closeTick = remaining[afterTick...].firstIndex(of: "`") {
            let code = String(remaining[afterTick..<closeTick])
            if !code.isEmpty { parts.append(.codeSpan(code)) }
            remaining = remaining[remaining.index(after: closeTick)...]
        } else {
            // Unmatched tick — treat rest as plain
            parts.append(.plain(String(remaining[tick...])))
            break
        }
    }
    return parts
}

/// Parses a raw Swarm message into alternating text/code segments by splitting on
/// triple-backtick fences (` ``` `). Unmatched fences render as text.
private func parseContentSegments(_ raw: String) -> [ContentSegment] {
    var segments: [ContentSegment] = []
    var remaining = raw[...]

    while !remaining.isEmpty {
        guard let fenceStart = remaining.range(of: "```") else {
            segments.append(.text(String(remaining)))
            break
        }

        // Text before the fence
        if fenceStart.lowerBound > remaining.startIndex {
            segments.append(.text(String(remaining[..<fenceStart.lowerBound])))
        }

        // Find the language hint and closing fence
        let afterFence = remaining[fenceStart.upperBound...]
        let lineEnd = afterFence.firstIndex(of: "\n") ?? afterFence.endIndex
        let langHint = String(afterFence[..<lineEnd])
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespaces)
        let codeStart = lineEnd < afterFence.endIndex ? afterFence.index(after: lineEnd) : afterFence.endIndex

        if let fenceEnd = remaining[codeStart...].range(of: "\n```") ?? remaining[codeStart...].range(of: "```") {
            let code = String(remaining[codeStart..<fenceEnd.lowerBound])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let language: String? = langHint.isEmpty ? nil : langHint
            segments.append(.code(code, language: language))
            remaining = remaining[fenceEnd.upperBound...]
        } else {
            // Unclosed fence — treat as text
            segments.append(.text(String(remaining[fenceStart.lowerBound...])))
            break
        }
    }

    return segments
}

/// Renders a Swarm answer as alternating Text + code blocks. Text gets AttributedString
/// markdown; code blocks get a dark monospace background with a copy button (ChatGPT-style).
private struct CitedMessageContent: View {
    @Environment(ChromeState.self) private var state
    let content: String
    let citations: [SwarmCitation]

    /// Tracks which code block's content was most recently copied, for "Copied!" feedback.
    @State private var copiedCodeContent: String?

    private var segments: [ContentSegment] { parseContentSegments(content) }

    var body: some View {
        if segments.isEmpty {
            EmptyView()
        } else if segments.count == 1, case .text(let t) = segments[0] {
            markdownText(t)
        } else {
            VStack(alignment: .leading, spacing: HiveSpacing.s8) {
                ForEach(segments) { segment in
                    switch segment {
                    case .text(let t):
                        markdownText(t)
                    case .code(let code, let language):
                        codeBlockView(code, language: language, wasCopied: copiedCodeContent == code)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func markdownText(_ text: String) -> some View {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleaned.isEmpty {
            EmptyView()
        } else {
            inlineCodeText(cleaned)
        }
    }

    /// Renders text with inline code spans (single backticks) highlighted with a
    /// monospace font + subtle tint background, matching ChatGPT/Claude behavior.
    @ViewBuilder
    private func inlineCodeText(_ text: String) -> some View {
        let parts = parseInlineCode(text)
        if parts.count <= 1 {
            Text(attributedString(from: text))
        } else {
            parts.reduce(Text("")) { result, part in
                switch part {
                case .plain(let s):
                    return result + Text(attributedString(from: s))
                case .codeSpan(let s):
                    return result + Text(" `\(s)` ")
                        .font(.system(size: 13, weight: .regular, design: .monospaced))
                        .foregroundStyle(.hiveAccent)
                }
            }
        }
    }

    private func attributedString(from markdown: String) -> AttributedString {
        do {
            return try AttributedString(
                markdown: markdown,
                options: AttributedString.MarkdownParsingOptions(
                    interpretedSyntax: .inlineOnly,
                    failurePolicy: .returnPartiallyParsedIfPossible
                )
            )
        } catch {
            return AttributedString(markdown)
        }
    }

    private func codeBlockView(_ code: String, language: String?, wasCopied: Bool) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: language label + copy button
            HStack(spacing: HiveSpacing.s8) {
                if let lang = language {
                    Text(lang)
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveMist)
                }
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(code, forType: .string)
                    copiedCodeContent = code
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if copiedCodeContent == code { copiedCodeContent = nil }
                    }
                } label: {
                    HStack(spacing: HiveSpacing.s4) {
                        Image(systemName: wasCopied ? "checkmark" : "doc.on.doc")
                            .font(HiveTypography.font(.caption3))
                        Text(wasCopied ? "Copied!" : "Copy")
                            .hiveType(.caption2)
                    }
                    .foregroundStyle(wasCopied ? .green : .hiveGraphite)
                }
                .buttonStyle(.plain)
                .animation(.hiveMicro, value: wasCopied)
            }
            .padding(.horizontal, HiveSpacing.s12)
            .padding(.vertical, HiveSpacing.s4)

            Divider().overlay(Color.hiveBorderSubtle)

            // Code content
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.hiveInk)
                    .textSelection(.enabled)
                    .padding(.horizontal, HiveSpacing.s12)
                    .padding(.vertical, HiveSpacing.s8)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(Color.hiveInk.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: HiveRadius.r8)
                        .stroke(Color.hiveBorderSubtle, lineWidth: 0.5)
                )
        )
    }
}

/// Human-readable label for an intent category shown on user message badges.
private func categoryLabel(_ raw: String) -> String {
    switch raw {
    case "genericQuestion": return "Question"
    case "webResearch":     return "Research"
    case "pageQuestion":    return "Page Q&A"
    case "browserAction":   return "Action"
    case "memorySearch":    return "Archive"
    case "knowledgeAction": return "Knowledge"
    case "codeAction":      return "Code"
    case "systemCommand":   return "Command"
    case "clarification":   return "Clarifying"
    case "voiceInput":      return "Voice"
    default:                return raw
    }
}

// MARK: - RunDetailsView

/// Collapsible honest provenance for an assistant message: provider, wall-clock
/// latency, and token count. Rendered only when the producing run reported real
/// timing/token data (never fabricated).
private struct RunDetailsView: View {
    let message: SwarmMessage

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                // Provider is already shown as a standalone badge above; the
                // disclosure adds the timing/token provenance only.
                if let ms = message.latencyMS {
                    detailRow("Latency", String(format: "%.2fs", Double(ms) / 1000))
                }
                if let tokens = message.tokensGenerated {
                    detailRow("Tokens", "\(tokens)")
                }
            }
            .padding(.top, HiveSpacing.s4)
        } label: {
            HStack(spacing: HiveSpacing.s4) {
                Image(systemName: "info.circle")
                    .font(HiveTypography.font(.micro))
                Text("Run details")
                    .hiveType(.caption2)
            }
            .foregroundStyle(.hiveMist)
        }
        .hiveType(.caption2)
        .accessibilityLabel("Run details for this response")
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: HiveSpacing.s8) {
            Text(label)
                .foregroundStyle(.hiveMist)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .monospaced()
                .foregroundStyle(.hiveGraphite)
                .textSelection(.enabled)
        }
    }
}

// MARK: - SlashCommandChipStrip

/// One expandable command in the Comet-style `/` palette. `expansion` is the exact
/// text inserted into the composer — every value maps to a command the
/// IntentOrchestrator recognizes, so chips are honest (expand, don't fire).
private struct SlashCommandChip: Identifiable {
    let id: String
    let symbol: String
    let title: String
    let hint: String
    let expansion: String
}

private let slashCommandChips: [SlashCommandChip] = [
    SlashCommandChip(id: "search", symbol: "globe", title: "/search", hint: "Web research", expansion: "/search "),
    SlashCommandChip(id: "find", symbol: "archivebox", title: "/find", hint: "Search memory", expansion: "/find "),
    SlashCommandChip(id: "code", symbol: "chevron.left.forwardslash.chevron.right", title: "/code", hint: "Code task", expansion: "/code "),
    SlashCommandChip(id: "ask", symbol: "doc.text.magnifyingglass", title: "@this", hint: "Ask this page", expansion: "@this "),
    SlashCommandChip(id: "brief", symbol: "square.and.arrow.down", title: "/brief", hint: "Save as brief", expansion: "save this as a brief"),
    SlashCommandChip(id: "project", symbol: "folder.badge.plus", title: "/project", hint: "New project", expansion: "create project ")
]

/// Horizontal strip of command chips shown while the user is composing a
/// `/`-command. Clicking inserts the expansion and dismisses the strip.
private struct SlashCommandChipStrip: View {
    let onSelect: (String) -> Void
    @State private var hoveredID: String? = nil

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: HiveSpacing.s4) {
                ForEach(slashCommandChips) { chip in
                    let isHovered = hoveredID == chip.id
                    Button {
                        onSelect(chip.expansion)
                    } label: {
                        HStack(spacing: HiveSpacing.s4) {
                            Image(systemName: chip.symbol)
                                .font(HiveTypography.font(.microMedium))
                            Text(chip.title)
                                .hiveType(.caption2)
                                .fontWeight(.semibold)
                            Text(chip.hint)
                                .hiveType(.caption2)
                                .foregroundStyle(.hiveMist)
                        }
                        .foregroundStyle(isHovered ? state.activeAccentColor : .hiveInk)
                        .padding(.horizontal, HiveSpacing.s8)
                        .padding(.vertical, HiveSpacing.s4)
                        .background(
                            Capsule()
                                .fill(isHovered ? state.activeAccentColor.opacity(0.10) : Color.hiveSurface)
                        )
                        .overlay(
                            Capsule()
                                .stroke(isHovered ? state.activeAccentColor.opacity(0.4) : Color.hiveBorderSubtle, lineWidth: 0.5)
                        )
                        .animation(.hiveMicro, value: isHovered)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredID = hovering ? chip.id : nil
                    }
                    .help(chip.hint)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    @Environment(ChromeState.self) private var state
}

// MARK: - SwarmMessageBubble

private struct SwarmMessageBubble: View {
    @Environment(ChromeState.self) private var state
    let message: SwarmMessage
    @Binding var savedMessageID: UUID?

    /// Consecutive same-role messages from the same sender should be visually
    /// grouped; the first in a run gets the avatar and full radius, subsequent
    /// ones get a tighter layout.
    var isFirstInRun: Bool = true

    private let bubbleRadius: CGFloat = HiveRadius.r12

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: HiveSpacing.s4) {
            HStack(alignment: .top, spacing: HiveSpacing.s8) {
                if message.role == .assistant && isFirstInRun {
                    // Librarian avatar — larger, distinct, visible
                    ZStack {
                        RoundedRectangle(cornerRadius: HiveRadius.r8)
                            .fill(state.activeAccentColor.opacity(0.10))
                            .frame(width: 28, height: 28)
                        Image(systemName: "books.vertical")
                            .font(HiveTypography.font(.panelTitle))
                            .foregroundStyle(state.activeAccentColor)
                    }
                } else if message.role == .assistant {
                    // Spacer to maintain alignment when avatar is hidden
                    Color.clear.frame(width: 28, height: 1)
                }

                VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                    // Intent badge — only on user messages
                    if message.role == .user, let category = message.intentCategory {
                        Text(categoryLabel(category))
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveAccent)
                            .padding(.horizontal, HiveSpacing.s4)
                            .padding(.vertical, 1)
                            .background(
                                RoundedRectangle(cornerRadius: HiveRadius.r3)
                                    .stroke(state.activeAccentColor.opacity(0.3), lineWidth: 0.5)
                            )
                            .padding(.leading, HiveSpacing.s4)
                    }

                    // Bubble content
                    CitedMessageContent(content: message.content, citations: message.citations)
                        .font(.body)
                        .foregroundStyle(.hiveInk)
                        .textSelection(.enabled)
                        .tint(state.activeAccentColor)
                        .padding(.horizontal, HiveSpacing.s12)
                        .padding(.vertical, HiveSpacing.s8)
                        .background(
                            RoundedRectangle(cornerRadius: bubbleRadius)
                                .fill(message.role == .user
                                    ? state.activeAccentColor.opacity(0.10)
                                    : Color.hiveSurface)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: bubbleRadius)
                                .stroke(message.role == .user
                                    ? state.activeAccentColor.opacity(0.15)
                                    : Color.hiveBorderSubtle,
                                    lineWidth: 0.5)
                        )
                        .shadow(color: .black.opacity(0.06),
                                radius: 4, y: 2)

                    // Citations
                    if !message.citations.isEmpty {
                        Text("Sources")
                            .hiveType(.caption1)
                            .foregroundStyle(.hiveMist)
                            .padding(.leading, HiveSpacing.s12)
                        VStack(alignment: .leading, spacing: HiveSpacing.s4) {
                            ForEach(Array(message.citations.enumerated()), id: \.element.id) { index, citation in
                                Button {
                                    if let url = URL(string: citation.url) {
                                        state.newTab(url: url)
                                    }
                                } label: {
                                    HStack(spacing: HiveSpacing.s4) {
                                        Image(systemName: "link")
                                            .font(HiveTypography.font(.caption3))
                                        Text(citation.title)
                                            .hiveType(.caption2)
                                            .lineLimit(1)
                                    }
                                    .foregroundStyle(state.activeAccentColor)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("swarm.citation.\(message.id.uuidString).\(index)")
                            }
                        }
                        .padding(.leading, HiveSpacing.s12)
                    }

                    // Compact action footer — speak + save + timestamp in one row
                    if message.role == .assistant {
                        HStack(spacing: HiveSpacing.s12) {
                            // Speak/stop button
                            Button {
                                if state.voiceOutput.isSpeaking {
                                    state.voiceOutput.stop()
                                } else {
                                    state.voiceOutput.speak(message.content)
                                }
                            } label: {
                                HStack(spacing: HiveSpacing.s4) {
                                    Image(systemName: state.voiceOutput.isSpeaking ? "stop.circle.fill" : "speaker.wave.2")
                                        .font(HiveTypography.font(.caption3))
                                    Text(state.voiceOutput.isSpeaking ? "Stop" : "Speak")
                                        .hiveType(.caption2)
                                }
                                .foregroundStyle(state.voiceOutput.isSpeaking ? .orange : state.activeAccentColor)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(state.voiceOutput.isSpeaking ? "Stop speaking" : "Read aloud")
                            .accessibilityIdentifier("swarm.speak.\(message.id.uuidString)")

                            // Save as Brief button
                            if state.briefStore != nil {
                                Button {
                                    state.saveAsBrief(message)
                                    savedMessageID = message.id
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                        if savedMessageID == message.id { savedMessageID = nil }
                                    }
                                } label: {
                                    HStack(spacing: HiveSpacing.s4) {
                                        Image(systemName: savedMessageID == message.id ? "checkmark" : "square.and.arrow.down")
                                            .font(HiveTypography.font(.caption3))
                                        Text(savedMessageID == message.id ? "Saved" : "Save as Brief")
                                            .hiveType(.caption2)
                                    }
                                    .foregroundStyle(savedMessageID == message.id ? .green : state.activeAccentColor)
                                }
                                .buttonStyle(.plain)
                                .accessibilityIdentifier("swarm.saveBrief.\(message.id.uuidString)")
                                .animation(.hiveMicro, value: savedMessageID)
                            }

                            Spacer(minLength: 0)

                            // Timestamp
                            Text(message.timestamp, style: .time)
                                .hiveType(.caption2)
                                .foregroundStyle(.hiveMist)
                        }
                        .padding(.leading, HiveSpacing.s12)
                    }

                    // Provider provenance badge
                    if let label = message.providerLabel {
                        Text(label)
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveMist)
                            .padding(.leading, HiveSpacing.s12)
                            .accessibilityLabel("Generated by \(label)")
                    }

                    // Run details — honest provenance disclosure (Dia/Comet
                    // transparency pattern). Only rendered when the run that
                    // produced this message reported real timing/token data.
                    if message.latencyMS != nil || message.tokensGenerated != nil {
                        RunDetailsView(message: message)
                            .padding(.leading, HiveSpacing.s12)
                    }

                    // Error: settings link
                    if message.isError {
                        Button {
                            state.openSettings()
                        } label: {
                            HStack(spacing: HiveSpacing.s4) {
                                Image(systemName: "gear")
                                    .font(HiveTypography.font(.caption3))
                                Text("Open Settings")
                                    .hiveType(.caption2)
                            }
                            .foregroundStyle(state.activeAccentColor)
                        }
                        .buttonStyle(.plain)
                        .padding(.leading, HiveSpacing.s12)
                    }
                }
                .frame(maxWidth: 520, alignment: message.role == .user ? .trailing : .leading)

                if message.role == .user {
                    Spacer(minLength: 0)
                }
            }
        }
    }
}
