import SwiftUI
import HiveCore

// MARK: - GeminiSidePanel
//
// Chat UI with message bubbles, copy button, model label,
// stop-generation, timestamps, empty state with suggestions,
// auto-scroll, URL detection with Open buttons, and quick-action chips.

struct GeminiSidePanel: View {
    @Environment(BrowserState.self) private var state
    @State private var input: String = ""
    @State private var scrollProxy: ScrollViewProxy?
    @ObservedObject private var speechRecognizer = SpeechRecognizer.shared
    @State private var voiceOutput = VoiceSpeechOutput()
    @State private var voiceTurnTask: Task<Void, Never>?
    @State private var isPreSendContextExpanded: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var bottomID

    // @tab autocomplete state
    @State private var referencedTabIDs: Set<String> = []
    @State private var showTabAutocomplete: Bool = false
    @State private var tabAutocompleteFilter: String = ""
    @State private var autocompleteIndex: Int = 0

    // Heads-up memory strip state — what Hive already knows about the current
    // page at the moment the user asks (the "second brain keeps watching"
    // moment). Local reads only; nothing leaves the device. The generation
    // token + cancellable task debounce rapid tab switches and prevent a stale
    // refresh from overwriting the strip with a previous page's memory.
    @State private var relatedPreferences: [PreferenceMemory] = []
    @State private var trackedMemoryCount: Int = 0
    @State private var headsUpTask: Task<Void, Never>?
    @State private var headsUpGeneration: Int = 0

    private var lastMessageID: UUID? { state.geminiMessages.last?.id }

    var body: some View {
        VStack(spacing: 0) {
            header
            contextModeControl
            Divider()

            // Context scope preview — Dia-style diagnostics showing what context the AI used
            if let diag = state.lastContextDiagnostics {
                contextScopePreview(diag)
            }

            if state.geminiMessages.isEmpty {
                emptyState
            } else {
                messageList
            }

            councilVerdictSection
            deepResearchProgress
            modelFooter
            inputArea
        }
        .frame(width: 340)
        .background(HiveDesign.Material.panel)
        .overlay(alignment: .leading) {
            Divider().opacity(0.35)
        }
        .onAppear {
            voiceOutput.onFinished = { @MainActor in
                state.voiceCoordinator.finishSpeaking()
            }
            refreshHeadsUp()
        }
        // Keep the related-memory strip live: it must follow tab switches,
        // in-tab navigations, and new captures/notes.
        .onChange(of: state.activeTabID) { _, _ in refreshHeadsUp() }
        .onChange(of: state.activePageContext?.url?.absoluteString) { _, _ in refreshHeadsUp() }
        .onChange(of: state.memoryRevision) { _, _ in refreshHeadsUp() }
        .onDisappear {
            voiceTurnTask?.cancel()
            voiceOutput.stop()
            state.cancelVoiceCommand()
        }
    }

    // MARK: - Header

    // MARK: - Context Scope Control

    /// Explicitly controls the context contract for the next request. This is
    /// intentionally a menu, not a toggle hidden in settings: the user should
    /// be able to see and narrow Swarm's reach at the moment they ask.
    private var contextModeControl: some View {
        Menu {
            ForEach(BrowserState.ContextMode.allCases) { mode in
                Button {
                    state.setContextMode(mode)
                } label: {
                    HStack {
                        Label(mode.title, systemImage: mode.icon)
                        if mode == state.contextMode {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            Divider()
            Text(state.contextMode.detail)
                .font(HiveDesign.Typography.caption)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: state.contextMode.icon)
                    .font(HiveDesign.Typography.captionSemiBold)
                    .foregroundStyle(Color.hiveAccent)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Context")
                        .font(HiveDesign.Typography.microLabelBold)
                        .foregroundStyle(.tertiary)
                        .textCase(.uppercase)
                    Text(state.contextMode.title)
                        .font(HiveDesign.Typography.sectionHeader)
                        .foregroundStyle(.primary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.down")
                    .font(.system(size: HiveDesign.Typography.sizeXS, weight: .bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HiveDesign.Surface.level1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
        .accessibilityLabel("Context scope")
        .accessibilityValue("\(state.contextMode.title). \(state.contextMode.detail)")
        .help(state.contextMode.detail)
    }

    // MARK: - Context Scope Preview (Dia-style diagnostics)

    /// A collapsible strip showing what context the AI used for the last response.
    /// Matches Dia's "thinking UI" — sources, node count, ranker status, duration.
    @State private var isContextScopeExpanded: Bool = false
    /// Live hot-context nodes with scores — shown in the expanded strip with
    /// per-node forget controls ("the AI stays out of the way until you need it").
    @State private var scopeNodes: [(id: String, score: Double, label: String)] = []
    /// How many nodes the user has forgotten this session — drives the restore
    /// affordance and keeps the strip visible after the last node is forgotten.
    @State private var forgottenCount: Int = 0

    private func contextScopePreview(_ diag: ContextDiagnostics) -> some View {
        VStack(spacing: 0) {
            Button(action: { withAnimation(reduceMotion ? nil : HiveDesign.Animation.springQuick) { isContextScopeExpanded.toggle() } }) {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(HiveDesign.Typography.buttonCaption)
                        .foregroundStyle(Color.hiveAccent)

                    Text("Context")
                        .font(HiveDesign.Typography.sectionHeader)
                        .foregroundStyle(.primary)

                    Text("\(diag.contextNodeCount) nodes")
                        .font(HiveDesign.Typography.buttonCaption)
                        .foregroundStyle(.secondary)

                    if let ranker = diag.rankerProvider, ranker != "degraded" {
                        Image(systemName: "line.3.horizontal.decrease.circle.fill")
                            .font(HiveDesign.Typography.microLabelSecondary)
                            .foregroundStyle(Color.hiveAccent.opacity(0.7))
                    }

                    Text("\(diag.durationMS)ms")
                        .font(HiveDesign.Typography.monoMicro)
                        .foregroundStyle(.tertiary)

                    Spacer()

                    Image(systemName: isContextScopeExpanded ? "chevron.up" : "chevron.down")
                        .font(HiveDesign.Typography.microLabelBold)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isContextScopeExpanded {
                Divider().opacity(0.5)
                VStack(alignment: .leading, spacing: 8) {
                    if let title = diag.pageTitle, let host = diag.pageHost {
                        HStack(spacing: 6) {
                            Image(systemName: "doc.text")
                                .font(HiveDesign.Typography.microLabelSecondary)
                                .foregroundStyle(.secondary)
                            Text("Current page:")
                                .font(HiveDesign.Typography.buttonCaption)
                                .foregroundStyle(.secondary)
                            Text(title)
                                .font(HiveDesign.Typography.captionSemiBold)
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                            Text("(\(host))")
                                .font(HiveDesign.Typography.monoMicro)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                        }
                    }

                    HStack(spacing: 8) {
                        contextStat("Nodes", "\(diag.contextNodeCount)", "square.grid.3x3")
                        contextStat("Provider", providerDisplayLabel(diag.providerLabel), "cpu")
                        contextStat("Time", "\(diag.durationMS)ms", "clock")
                        if let ranker = diag.rankerProvider {
                            contextStat("Ranker", ranker == "degraded" ? "fallback" : ranker, "line.3.horizontal.decrease")
                        }
                    }

                    // Per-node hot-context control — what the second brain is
                    // currently tracking, with one-tap forget. The user stays
                    // in control of what the AI knows (friction thesis).
                    if !scopeNodes.isEmpty || forgottenCount > 0 {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Hot context")
                                    .font(HiveDesign.Typography.microLabel)
                                    .foregroundStyle(.tertiary)
                                Spacer()
                                if forgottenCount > 0 {
                                    Button("Restore") { restoreForgottenNodes() }
                                        .buttonStyle(.plain)
                                        .font(HiveDesign.Typography.microLabelMedium)
                                        .foregroundStyle(Color.hiveAccent)
                                        .help("Restore \(forgottenCount) forgotten context node(s)")
                                }
                                Text("\(scopeNodes.count) tracked")
                                    .font(HiveDesign.Typography.microLabelMedium)
                                    .foregroundStyle(.tertiary.opacity(0.6))
                            }
                            ForEach(Array(scopeNodes.enumerated()), id: \.element.id) { _, node in
                                HStack(spacing: 6) {
                                    Circle()
                                        .fill(scopeScoreColor(node.score))
                                        .frame(width: 5, height: 5)
                                    Text(node.label)
                                        .font(HiveDesign.Typography.buttonCaption)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text("\(Int(node.score * 100))%")
                                        .font(HiveDesign.Typography.monoMicroMedium)
                                        .foregroundStyle(.tertiary)
                                    Spacer()
                                    Button(action: { forgetScopeNode(node.id) }) {
                                        Image(systemName: "xmark")
                                            .font(.system(size: HiveDesign.Typography.sizeXS, weight: .bold))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .buttonStyle(.plain)
                                    .help("Forget this context — the AI won't see it")
                                }
                            }
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(0.06))
                        )
                    }

                    if !diag.contextSummary.isEmpty {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Context summary")
                                .font(HiveDesign.Typography.microLabel)
                                .foregroundStyle(.tertiary)
                            Text(diag.contextSummary)
                                .font(HiveDesign.Typography.monoMicro)
                                .foregroundStyle(.secondary)
                                .lineLimit(6)
                        }
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.secondary.opacity(0.06))
                        )
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .onAppear { loadScopeNodes() }
            }
        }
    }

    // MARK: - Hot context controls

    /// Loads the live hot-memory scope (top scored entries) for the strip.
    private func loadScopeNodes() {
        Task { @MainActor in
            scopeNodes = await state.hotMemory.currentContextScope()
            forgottenCount = await state.hotMemory.forgottenNodeIDList().count
        }
    }

    /// Forgets a single context node — the AI won't see it for the rest of the
    /// session (passive re-access can't resurrect it).
    private func forgetScopeNode(_ id: String) {
        Task { @MainActor in
            await state.hotMemory.forgetNode(id: id)
            loadScopeNodes()
        }
    }

    /// Restores every forgotten context node — the user changed their mind.
    private func restoreForgottenNodes() {
        Task { @MainActor in
            for id in await state.hotMemory.forgottenNodeIDList() {
                await state.hotMemory.unforgetNode(id: id)
            }
            loadScopeNodes()
        }
    }

    /// Color-codes a node's relevance: accent = hot, orange = cooling, gray = cold.
    private func scopeScoreColor(_ score: Double) -> Color {
        if score > 0.7 { return Color.hiveAccent }
        if score > 0.3 { return HiveDesign.State.warning }
        return HiveDesign.Text.tertiary
    }

    private func contextStat(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(HiveDesign.Typography.microLabelSecondary)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(HiveDesign.Typography.monoMicroMedium)
                .foregroundStyle(.primary)
                .lineLimit(1)
            Text(label)
                .font(.system(size: HiveDesign.Typography.sizeXS))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Compact provider label for the context scope strip (Dia diagnostics).
    /// Full labels live in `providerLabel` (footer); this is the short stat form.
    private func providerDisplayLabel(_ raw: String) -> String {
        switch raw {
        case "appleFMF": return "Apple"
        case "mlx": return "MLX"
        case "byokRemote": return "Cloud"
        case "mock": return "Offline"
        case "error": return "Error"
        default: return raw.prefix(8).description
        }
    }

    /// Full provider label for the model footer. Maps the raw provider string
    /// (stored in `state.lastGeminiProvider`) to a human-readable status.
    private var providerLabel: String {
        if state.isGeminiGenerating { return "generating..." }
        switch state.lastGeminiProvider {
        case "appleFMF": return "local · Apple on-device"
        case "mlx": return "local · MLX on-device"
        case "byokRemote": return "remote · connected"
        case "mock": return "local · offline"
        case "error": return "error"
        default: return "local · ready"
        }
    }

    // MARK: - Header (original)

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(HiveDesign.Typography.bodySemiBold)
                .foregroundStyle(Color.hiveAccent)

            Text("Ask Hive")
                .font(HiveDesign.Typography.bodySemiBold)
                .foregroundStyle(.primary)

            Spacer()

            if state.isGeminiGenerating {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 14, height: 14)
                    Text("Generating")
                        .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                        .foregroundStyle(Color.hiveAccent)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(HiveDesign.Surface.level2)
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            // Model toggle — Comet-style: switch the underlying provider from
            // the panel header. The choice is persisted; the footer + context
            // strip always show which provider actually answered (honest).
            Menu {
                ForEach(GeminiProviderOption.allCases) { option in
                    Button(action: { state.setPreferredModelProvider(option.rawValue) }) {
                        if option.rawValue == state.preferredModelProvider {
                            Label(option.title, systemImage: "checkmark")
                        } else {
                            Text(option.title)
                        }
                    }
                }
                Divider()
                Text("The provider that actually answers is shown below. If the selected model is unavailable, Hive falls back honestly.")
            } label: {
                Image(systemName: "cpu")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .menuStyle(.borderlessButton)
            .help("Model: \(state.preferredModelProvider)")

            Button(action: { state.isGeminiPanelOpen = false }) {
                Image(systemName: "xmark")
                    .font(HiveDesign.Typography.smallLabelBold)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: 24)
                    .background(Color.secondary.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Ask Hive")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(state.geminiMessages) { message in
                        GeminiMessageRow(message: message)
                            .id(message.id)
                    }
                    Color.clear.frame(height: 1).id(bottomID)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            }
            .onAppear { scrollProxy = proxy }
            .onChange(of: state.geminiMessages.count) { _, _ in
                withAnimation(reduceMotion ? nil : .smooth) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
            .onChange(of: lastMessageID) { _, _ in
                withAnimation(reduceMotion ? nil : .smooth) {
                    proxy.scrollTo(bottomID, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "sparkles")
                .font(HiveDesign.Typography.heroDisplay)
                .foregroundStyle(Color.hiveAccent.opacity(0.5))

            VStack(spacing: 4) {
                Text("Ask anything about this page")
                    .font(.system(size: HiveDesign.Typography.sizeHeading2, weight: .semibold))
                    .foregroundStyle(.primary)
                Text("Summarize, compare, or ask questions")
                    .font(HiveDesign.Typography.body)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                suggestionChip("Summarize this page", icon: "text.alignleft")
                suggestionChip("What are the key points?", icon: "list.number")
                suggestionChip("Compare to another tab", icon: "arrow.left.arrow.right")
                deepResearchChip
            }

            Spacer()
        }
    }

    private func suggestionChip(_ text: String, icon: String) -> some View {
        Button(action: {
            input = text
            send()
        }) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                Text(text)
                    .font(HiveDesign.Typography.sidebarItem)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }        .buttonStyle(.plain)
    }

    /// Prefills the input with /deep for multi-step research.
    /// Does NOT auto-send — the user types their query after the prefix.


    // MARK: - Model Footer

    // MARK: - Council Verdict Section

    /// Shows the parallel multi-model council verdict when available.
    /// While convening: animated progress with provider count.
    /// Once complete: synthesized answer with per-provider responses and degradation indicators.
    @ViewBuilder
    private var councilVerdictSection: some View {
        if state.isCouncilConvening {
            councilConveningView
        } else if let verdict = state.latestCouncilVerdict {
            councilVerdictView(verdict)
        }
    }

    private var councilConveningView: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
                Text("Council deliberating...")
                    .font(HiveDesign.Typography.captionSemiBold)
                    .foregroundStyle(Color.hiveAccent)
                Spacer()
                Text("Deliberating…")
                    .font(HiveDesign.Typography.monoMicroMedium)
                    .foregroundStyle(.tertiary)
            }
            if let verdict = state.latestCouncilVerdict {
                // Intermediate state: some models have responded
                HStack(spacing: 4) {
                    ForEach(verdict.responses) { response in
                        Circle()
                            .fill(response.status == CouncilResponse.ResponseStatus.success ? Color.green : Color.hiveAccent)
                            .frame(width: 6, height: 6)
                    }
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(HiveDesign.Surface.level1)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
        }
    }

    private func councilVerdictView(_ verdict: CouncilVerdict) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header: consensus indicator + stats
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(HiveDesign.Typography.captionSemiBold)
                    .foregroundStyle(Color.hiveAccent)
                Text("Council Verdict")
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(.primary)
                Spacer()
                // Degradation indicator — honest, never hidden
                if verdict.isDegraded {
                    HStack(spacing: 3) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 8))
                        Text("Degraded")
                            .font(HiveDesign.Typography.microLabelMedium)
                    }
                    .foregroundStyle(HiveDesign.State.warning)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(HiveDesign.State.warning.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                Text("\(verdict.activeProviders.count) models")
                    .font(HiveDesign.Typography.monoMicroMedium)
                    .foregroundStyle(.tertiary)
                Text("\(Int(verdict.confidence * 100))%")
                    .font(HiveDesign.Typography.monoMicroMedium)
                    .foregroundStyle(verdict.confidence > 0.7 ? Color.green : Color.orange)
            }

            // Synthesized answer
            Text(verdict.answer)
                .font(.system(size: 12, weight: .regular, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(8)
                .textSelection(.enabled)

            if !verdict.reasoning.isEmpty {
                Text(verdict.reasoning)
                    .font(HiveDesign.Typography.monoMicro)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            // Agreement / disagreement summary
            if !verdict.agreements.isEmpty || !verdict.disagreements.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    if !verdict.agreements.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.green)
                            Text("Agreed: \(verdict.agreements.prefix(3).joined(separator: ", "))")
                                .font(HiveDesign.Typography.microLabelSecondary)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                    if !verdict.disagreements.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.orange)
                            Text("Disagreed: \(verdict.disagreements.prefix(3).joined(separator: ", "))")
                                .font(HiveDesign.Typography.microLabelSecondary)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }
            }

            // Per-provider responses (expandable)
            DisclosureGroup {
                VStack(spacing: 6) {
                    ForEach(verdict.responses) { response in
                        HStack(alignment: .top, spacing: 6) {
                            Circle()
                                .fill(response.status == CouncilResponse.ResponseStatus.success ? Color.green : Color.orange)
                                .frame(width: 6, height: 6)
                                .padding(.top, 5)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(response.provider.rawValue)
                                        .font(HiveDesign.Typography.microLabelBold)
                                        .foregroundStyle(.primary)
                                    Text("\(Int(response.confidence * 100))%")
                                        .font(HiveDesign.Typography.monoMicroMedium)
                                        .foregroundStyle(.tertiary)
                                    Text("\(Int(response.duration * 1000))ms")
                                        .font(HiveDesign.Typography.monoMicro)
                                        .foregroundStyle(.tertiary)
                                }
                                Text(response.answer)
                                    .font(HiveDesign.Typography.monoMicro)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(3)
                            }
                        }
                    }
                }
                .padding(.leading, 4)
            } label: {
                Text("Show \(verdict.responses.count) model responses")
                    .font(HiveDesign.Typography.microLabelMedium)
                    .foregroundStyle(Color.hiveAccent)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(HiveDesign.Surface.level1)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1)
        }
    }

    // MARK: - Deep Research Progress

    /// Shows live progress of a multi-step deep research query.
    /// Plan → Search → Read → Synthesize → Refine (optional).
    @ViewBuilder
    private var deepResearchProgress: some View {
        if let step = state.deepResearchStep {
            switch step {
            case .complete:
                EmptyView()
            default:
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        ProgressView(value: step.progress, total: 1.0).progressViewStyle(.linear)
                            .scaleEffect(x: 1, y: 0.5)
                            .tint(Color.hiveAccent)
                        Text("\(Int(step.progress * 100))%")
                            .font(HiveDesign.Typography.monoMicroMedium)
                            .foregroundStyle(Color.hiveAccent)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(HiveDesign.Typography.captionSemiBold)
                            .foregroundStyle(Color.hiveAccent)
                            .symbolEffect(.pulse, options: .repeating)
                        Text(step.label)
                            .font(HiveDesign.Typography.captionSemiBold)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("Deep Research")
                            .font(HiveDesign.Typography.microLabelBold)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(HiveDesign.Surface.level1)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Color.white.opacity(0.04)).frame(height: 1)
                }
            }
        }
    }

    private var modelFooter: some View {
        HStack(spacing: 4) {
            Image(systemName: "cpu")
                .font(HiveDesign.Typography.microLabelSecondary)
                .foregroundStyle(.tertiary)
            Text(providerLabel)
                .font(HiveDesign.Typography.buttonCaption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 2)
    }



    // MARK: - Input Area

    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()

            headsUpStrip

            preSendContextDisclosure

            // Tab reference pills — Comet-style @tab attachment badges
            if !referencedTabIDs.isEmpty {
                tabReferencePills
            }

            // @tab autocomplete dropdown
            if showTabAutocomplete && !matchingTabs.isEmpty {
                tabAutocompleteDropdown
            }

            // Voice turn disclosure — makes clarification and confirmation
            // explicit instead of leaving the user to infer state from a chat
            // bubble or microphone indicator. It is presentation-only; the
            // existing gateway/coordinator remains the authority.
            voiceTurnDisclosure

            // Voice status readout — compact and explicit rather than a
            // decorative orb. The transcript remains visible while recording;
            // route/clarification state is shown after submission.
            if state.voiceCoordinator.state != .idle,
               state.voiceCoordinator.state != .completed,
               state.voiceCoordinator.state != .cancelled {
                HStack(spacing: 6) {
                    Circle()
                        .fill(speechRecognizer.isRecording ? Color.red : Color.hiveAccent)
                        .frame(width: 5, height: 5)
                    Text(voiceStatusLabel)
                        .font(HiveDesign.Typography.monoMicroEmph)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("LOCAL AUDIO")
                        .font(HiveDesign.Typography.monoTiny)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 5)
                .background(HiveDesign.Surface.level1)
            }

            // Transcribed speech preview — Comet-style voice dictation
            if speechRecognizer.isRecording && !speechRecognizer.transcribedText.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "waveform")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(Color.hiveAccent)
                        .symbolEffect(.variableColor, options: .repeating)
                    Text(speechRecognizer.transcribedText)
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(HiveDesign.Surface.level1)
            }

            HStack(spacing: 8) {
                // Voice input button — Comet's Shift+Alt+V voice mode
                if state.isVoiceModeActive {
                    Button(action: { toggleVoiceRecording() }) {
                        Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic.slash.fill")
                            .font(HiveDesign.Typography.sidebarItemBold)
                            .foregroundStyle(speechRecognizer.isRecording ? Color.red : .secondary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(speechRecognizer.isRecording ? Color.red.opacity(0.10) : Color.secondary.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                            .help(speechRecognizer.isRecording ? "Stop recording and route voice command" : "Start local voice command")
                }

                TextField("Ask about this page...", text: $input)
                    .textFieldStyle(.plain)
                    .font(HiveDesign.Typography.body)
                    .padding(.vertical, 9)
                    .padding(.horizontal, 12)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous))
                    .onSubmit { send() }
                    .onChange(of: input) { _, _ in detectTabReferences() }

                if state.isGeminiGenerating {
                    Button(action: { state.stopGeminiGeneration() }) {
                        Image(systemName: "stop.fill")
                            .font(HiveDesign.Typography.sidebarItemBold)
                            .foregroundStyle(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.10))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: { send() }) {
                        Image(systemName: "arrow.up")
                            .font(HiveDesign.Typography.smallLabelBold)
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(input.isEmpty ? Color.secondary.opacity(0.3) : Color.hiveAccent)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(input.isEmpty && referencedTabIDs.isEmpty)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Heads Up (related memory)

    /// A quiet strip above the composer showing what Hive already remembers
    /// about the current page: relevant user preferences and how many memory
    /// items are being tracked. It answers "what do you already know about
    /// this?" at the exact moment the user would ask — without sending any of
    /// it anywhere. Tapping opens the Knowledge panel.
    @ViewBuilder
    private var headsUpStrip: some View {
        let hasPage = !state.isPrivateBrowsing && state.activePageContext?.url != nil
        if hasPage, !relatedPreferences.isEmpty || trackedMemoryCount > 0 {
            VStack(alignment: .leading, spacing: 6) {
                // The strip header is a real button: VoiceOver announces the
                // open-knowledge affordance, and the header never competes with
                // the preference chips below it.
                Button(action: { state.toggleKnowledgePanel() }) {
                    HStack(spacing: 6) {
                        Image(systemName: "eye")
                            .font(HiveDesign.Typography.microLabel)
                            .foregroundStyle(Color.hiveAccent.opacity(0.8))
                        Text("Related memory")
                            .font(HiveDesign.Typography.microLabelBold)
                            .foregroundStyle(.tertiary)
                            .textCase(.uppercase)
                        if trackedMemoryCount > 0 {
                            Text("\(trackedMemoryCount) related")
                                .font(HiveDesign.Typography.monoMicroMedium)
                                .foregroundStyle(.tertiary.opacity(0.7))
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: HiveDesign.Typography.sizeXS, weight: .bold))
                            .foregroundStyle(.tertiary.opacity(0.4))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Open knowledge panel")
                .accessibilityValue("\(trackedMemoryCount) related memory items")

                if !relatedPreferences.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 5) {
                            ForEach(Array(relatedPreferences.prefix(3).enumerated()), id: \.offset) { _, pref in
                                Button(action: { state.toggleKnowledgePanel() }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "gearshape")
                                            .font(.system(size: HiveDesign.Typography.sizeXS))
                                        Text(pref.value)
                                            .font(HiveDesign.Typography.captionSemiBold)
                                        if let tail = pref.path.split(separator: ".").last {
                                            Text(String(tail))
                                                .font(HiveDesign.Typography.microLabelSecondary)
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                    .foregroundStyle(Color.hiveAccent)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .fill(HiveDesign.Surface.level2)
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .help(pref.path)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(HiveDesign.Surface.level1)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 1)
            }
        }
    }

    /// Local read of Honeycomb + hot memory for the current page. Private
    /// browsing and non-web pages show nothing — the strip is never populated
    /// from private content. Each call supersedes the previous in-flight task,
    /// so rapid tab switches cannot produce a stale overwrite.
    private func refreshHeadsUp() {
        headsUpGeneration &+= 1
        let generation = headsUpGeneration
        headsUpTask?.cancel()
        headsUpTask = Task { @MainActor in
            guard !state.isPrivateBrowsing,
                  let ctx = state.activePageContext,
                  let url = ctx.url,
                  let scheme = url.scheme?.lowercased(),
                  scheme == "http" || scheme == "https" else {
                relatedPreferences = []
                trackedMemoryCount = 0
                return
            }
            let pageKey = url.absoluteString
            let title = ctx.title
            let query = [title, url.host].compactMap { $0 }.joined(separator: " ")
            let prefs = await PreferenceMemoryBridge.relevantPreferences(for: query, from: state.honeycomb)
            let scope = await state.hotMemory.currentContextScope()
            // Only publish if this task is still current AND the page has not
            // changed while the queries were in flight.
            guard generation == headsUpGeneration,
                  state.activePageContext?.url?.absoluteString == pageKey else { return }
            relatedPreferences = prefs
            // Honest count: memory entries that actually relate to this page
            // (its page node, or a stored label matching the page title) —
            // never the global hot set.
            let pageNodeID = "page-\(pageKey.hashValue)"
            trackedMemoryCount = scope.filter { entry in
                entry.id == pageNodeID ||
                entry.label.localizedCaseInsensitiveCompare(title) == .orderedSame
            }.count
        }
    }

    // MARK: - Context Before Send

    /// The final, compact scope disclosure before the user sends text or voice.
    /// It reads the browser's canonical scope rather than rebuilding permissions
    /// in the view. No page text, URLs, memory contents, or identifiers are
    /// rendered here.
    @ViewBuilder
    private var preSendContextDisclosure: some View {
        let summary = ContextScopeSummary(
            scope: state.activeContextScope,
            explicitTabCount: referencedTabIDs.count,
            isPrivateBrowsing: state.isPrivateBrowsing
        )
        let attachmentSummary = state.tabAttachmentSummary(for: referencedTabIDs)

        VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.16)) {
                    isPreSendContextExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: summary.title == "Private browsing"
                          ? "lock.shield"
                          : "square.stack.3d.up")
                        .font(HiveDesign.Typography.captionSemiBold)
                        .foregroundStyle(summary.title == "Private browsing"
                                         ? HiveDesign.State.warning
                                         : Color.hiveAccent)

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 5) {
                            Text("Before send")
                                .font(HiveDesign.Typography.microLabelBold)
                                .foregroundStyle(.tertiary)
                                .textCase(.uppercase)
                            Text(summary.title)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.primary)
                        }
                        Text(summary.detail)
                            .font(.system(size: 9.5, weight: .regular))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)

                    if summary.explicitTabCount > 0, !state.isPrivateBrowsing {
                        Text("\(summary.explicitTabCount) selected tab\(summary.explicitTabCount == 1 ? "" : "s")")
                            .font(HiveDesign.Typography.monoMicroMedium)
                            .foregroundStyle(Color.hiveAccent)
                    }

                    Image(systemName: isPreSendContextExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: HiveDesign.Typography.sizeXS, weight: .bold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Context before send")
            .accessibilityValue("\(summary.title). \(summary.detail). \(summary.privacyDetail)")
            .accessibilityHint(isPreSendContextExpanded ? "Collapse context details" : "Expand context details")

            if isPreSendContextExpanded {
                Divider().opacity(0.45)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(summary.rows) { row in
                        HStack(spacing: 7) {
                            Image(systemName: row.isIncluded ? "checkmark.circle.fill" : "minus.circle")
                                .font(HiveDesign.Typography.microLabel)
                                .foregroundStyle(row.isIncluded ? Color.hiveAccent : HiveDesign.Text.tertiary)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(row.label)
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundStyle(row.isIncluded ? .primary : .tertiary)
                                Text(row.detail)
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    HStack(spacing: 5) {
                        Image(systemName: "shield.lefthalf.filled")
                            .font(.system(size: HiveDesign.Typography.sizeXS))
                            .foregroundStyle(.tertiary)
                        Text(summary.privacyDetail)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 2)

                    if !referencedTabIDs.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: state.isPrivateBrowsing
                                  ? "lock.shield"
                                  : attachmentSummary.warning == nil
                                    ? "checkmark.circle"
                                    : "exclamationmark.triangle")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(state.isPrivateBrowsing || attachmentSummary.warning != nil
                                                 ? HiveDesign.State.warning
                                                 : Color.hiveAccent)
                            Text(state.isPrivateBrowsing
                                 ? "Attachments unavailable"
                                 : attachmentSummary.detail)
                                .font(.system(size: 8.5, weight: .medium))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }

                        if let warning = attachmentSummary.warning, !state.isPrivateBrowsing {
                            Text(warning)
                                .font(.system(size: 8, weight: .regular))
                                .foregroundStyle(HiveDesign.State.warning)
                                .lineLimit(2)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(HiveDesign.Surface.level1)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1)
        }
    }

    // MARK: - Tab Reference Pills

    private var tabReferencePills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(referencedTabIDs), id: \.self) { tabID in
                    if let tab = state.tabs.first(where: { $0.id == tabID }) {
                        tabPill(tab)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    private func tabPill(_ tab: BrowserState.Tab) -> some View {
        let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "tab") : tab.model.title
        let displayTitle = title.count > 30 ? String(title.prefix(27)) + "..." : title
        return HStack(spacing: 4) {
            Image(systemName: "doc.text")
                .font(HiveDesign.Typography.microLabelMedium)
            Text(displayTitle)
                .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                .lineLimit(1)
            Button(action: { removeTabReference(tab.id) }) {
                Image(systemName: "xmark")
                    .font(.system(size: HiveDesign.Typography.sizeXS, weight: .bold))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color.hiveAccent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(HiveDesign.Surface.level2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .onTapGesture { state.selectTab(id: tab.id) }
    }

    // MARK: - @tab Autocomplete Dropdown

    private var tabAutocompleteDropdown: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.5)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(matchingTabs.enumerated()), id: \.element.id) { idx, tab in
                        tabAutocompleteRow(tab, index: idx)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .background(HiveDesign.Material.panel)
    }

    private func tabAutocompleteRow(_ tab: BrowserState.Tab, index: Int) -> some View {
        let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "Untitled") : tab.model.title
        let url = tab.model.url?.host ?? ""
        let isHighlighted = index == autocompleteIndex
        return Button(action: { insertTabReference(tab) }) {
            HStack(spacing: 8) {
                if let favicon = tab.model.faviconURL {
                    FaviconImage(url: favicon)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "doc.text")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(url)
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("@tab")
                    .font(HiveDesign.Typography.monoMicroMedium)
                    .foregroundStyle(Color.hiveAccent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(HiveDesign.Surface.level2)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isHighlighted
                    ? HiveDesign.Surface.level2
                    : Color.clear
            )
        }        .buttonStyle(.plain)
    }

    /// Prefills the input with /deep for multi-step research.
    /// Does NOT auto-send — the user types their query after the prefix.
    private var deepResearchChip: some View {
        Button(action: {
            input = "/deep "
        }) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                Text("Deep research")
                    .font(HiveDesign.Typography.sidebarItem)
                Spacer()
                Text("15+ sources")
                    .font(HiveDesign.Typography.monoMicroMedium)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(Color.hiveAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.hiveAccent.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.hiveAccent.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Deep research — type your query after /deep")
    }




    // MARK: - Voice turn disclosure

    /// Explains the current voice lifecycle without rendering the transcript,
    /// classifier reason, page data, URLs, tab IDs, or model output.
    @ViewBuilder
    private var voiceTurnDisclosure: some View {
        if let disclosure = VoiceTurnDisclosure.make(
            state: state.voiceCoordinator.state,
            pendingDecision: state.voiceCoordinator.pendingDecision
        ) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: disclosure.iconName)
                    .font(HiveDesign.Typography.sectionHeader)
                    .foregroundStyle(disclosure.isBlocking
                                     ? HiveDesign.State.warning
                                     : Color.hiveAccent)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 2) {
                    Text(disclosure.title)
                        .font(HiveDesign.Typography.captionSemiBold)
                        .foregroundStyle(.primary)
                    Text(disclosure.detail)
                        .font(HiveDesign.Typography.microLabelSecondary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if let instruction = disclosure.instruction {
                        Text(instruction)
                            .font(.system(size: 8.5, weight: .medium))
                            .foregroundStyle(disclosure.isBlocking
                                             ? HiveDesign.State.warning
                                             : HiveDesign.Text.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 4)

                if disclosure.isBlocking {
                    Button("Cancel") {
                        voiceTurnTask?.cancel()
                        voiceOutput.stop()
                        state.cancelVoiceCommand()
                    }
                    .buttonStyle(.plain)
                    .font(HiveDesign.Typography.microLabel)
                    .foregroundStyle(HiveDesign.State.warning)
                    .accessibilityLabel("Cancel voice request")
                    .help("Stop this voice request without running an action")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                disclosure.isBlocking
                    ? HiveDesign.State.warning.opacity(0.08)
                    : HiveDesign.Surface.level1
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(disclosure.isBlocking
                          ? HiveDesign.State.warning.opacity(0.18)
                          : Color.white.opacity(0.04))
                    .frame(height: 1)
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Voice turn: \(disclosure.title)")
            .accessibilityValue(
                [disclosure.detail, disclosure.instruction]
                    .compactMap { $0 }
                    .joined(separator: " ")
            )
        }
    }

    private var voiceStatusLabel: String {
        switch state.voiceCoordinator.state {
        case .listening: return "LISTENING"
        case .transcribing: return "TRANSCRIBING"
        case .classifying: return "ROUTING"
        case .clarifying: return "CLARIFYING"
        case .executing: return "WORKING"
        case .speaking: return "SPEAKING"
        case .failed: return "VOICE ERROR"
        case .cancelled: return "CANCELLED"
        case .unsupported: return "UNAVAILABLE"
        case .completed: return "READY"
        case .idle: return "READY"
        }
    }

    private func toggleVoiceRecording() {
        if speechRecognizer.isRecording {
            let finalText = speechRecognizer.transcribedText
            speechRecognizer.stopRecording()
            Task { @MainActor in
                state.voiceCoordinator.markTranscribing()
                await submitVoiceTranscript(finalText)
            }
            return
        }

        voiceTurnTask?.cancel()
        voiceOutput.stop()
        state.resetVoiceCommand()
        voiceTurnTask = Task { @MainActor in
            state.voiceCoordinator.beginListening()
            if !speechRecognizer.isAuthorized {
                guard await speechRecognizer.requestAuthorization() else {
                    state.cancelVoiceCommand()
                    return
                }
            }
            guard !Task.isCancelled else { return }
            do {
                try speechRecognizer.startRecording()
            } catch {
                state.cancelVoiceCommand()
                state.geminiMessages.append(GeminiMessage(
                    role: .assistant,
                    text: "Voice input is unavailable: \(error.localizedDescription)"
                ))
            }
        }
    }

    private func submitVoiceTranscript(_ transcript: String) async {
        let text = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            state.cancelVoiceCommand()
            return
        }
        let outcome = await state.submitVoiceCommand(text, referencedTabIDs: referencedTabIDs)
        switch outcome {
        case .clarification(let prompt, _):
            state.geminiMessages.append(GeminiMessage(role: .assistant, text: prompt))
            voiceOutput.speak(prompt)
        case .executed(let result, _):
            if result.shouldSpeak {
                voiceOutput.speak(result.text)
            } else {
                state.voiceCoordinator.finishSpeaking()
            }
        case .unsupported(let message, _):
            state.geminiMessages.append(GeminiMessage(role: .assistant, text: message))
            voiceOutput.speak(message)
        case .failed(let message, _):
            state.geminiMessages.append(GeminiMessage(role: .assistant, text: message))
            voiceOutput.speak(message)
        case .cancelled:
            break
        }
    }

    private func send() {
        guard !input.isEmpty else { return }
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let tabIDs = referencedTabIDs
        input = ""
        referencedTabIDs = []
        showTabAutocomplete = false

        // /research <query> → live web research through the user's Vane
        // (Perplexica) instance, with cited sources (honest "vane" provider).
        // Requires the space so "/researcher" or "/researching" never collide.
        if trimmedInput == "/research" || trimmedInput.hasPrefix("/research ") {
            let query = String(trimmedInput.dropFirst("/research".count))
                .trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else {
                state.geminiMessages.append(GeminiMessage(role: .user, text: trimmedInput))
                state.geminiMessages.append(GeminiMessage(
                    role: .assistant,
                    text: "Usage: `/research <query>` — runs a live web research query through your Vane (Perplexica) instance and returns a cited answer. Configure the URL in Settings → Performance → Web Research."))
                return
            }
            state.geminiMessages.append(GeminiMessage(role: .user, text: "/research \(query)"))
            state.performResearch(query: query)
            return
        }

        // /deep <query> → multi-step deep research: plan sub-queries → search →
        // read top sources → synthesize → refine. 15+ sources, iterative.
        if trimmedInput == "/deep" || trimmedInput.hasPrefix("/deep ") {
            let query = String(trimmedInput.dropFirst("/deep".count))
                .trimmingCharacters(in: .whitespaces)
            guard !query.isEmpty else {
                state.geminiMessages.append(GeminiMessage(role: .user, text: trimmedInput))
                state.geminiMessages.append(GeminiMessage(
                    role: .assistant,
                    text: "Usage: `/deep <query>` — runs multi-step deep research across 15+ sources with iterative refinement. Results include a full synthesis with cited sources and a table of contents."))
                return
            }
            state.geminiMessages.append(GeminiMessage(role: .user, text: "/deep \(query)"))
            state.performDeepResearch(query: query)
            return
        }

        let text = stripTabReferences(from: trimmedInput)
        state.sendGeminiMessage(text, referencedTabIDs: tabIDs)
    }

    /// Strips @tab-name references from the display text while preserving
    /// the referenced tab IDs for the AI context.
    private func stripTabReferences(from text: String) -> String {
        var result = text
        for tabID in referencedTabIDs {
            if let tab = state.tabs.first(where: { $0.id == tabID }) {
                let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "tab") : tab.model.title
                let ref = "@\(title)"
                result = result.replacingOccurrences(of: ref, with: "")
            }
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    /// Detects @tab references in the current input and updates autocomplete state.
    private func detectTabReferences() {
        guard let lastAt = input.lastIndex(of: "@") else {
            showTabAutocomplete = false
            tabAutocompleteFilter = ""
            return
        }
        let afterAt = String(input[input.index(after: lastAt)...])
        // Show all tabs when @ is typed with nothing after it
        if afterAt.isEmpty {
            tabAutocompleteFilter = ""
            showTabAutocomplete = true
            autocompleteIndex = 0
            return
        }
        // Split by spaces: only the first "word" after @ is the filter
        let words = afterAt.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
        let filterWord = String(words[0])
        // If there's more text after a space following the filter word,
        // the user has moved on — hide autocomplete. Otherwise show it.
        if words.count > 1 && !words[1].isEmpty {
            showTabAutocomplete = false
        } else {
            tabAutocompleteFilter = filterWord.lowercased()
            showTabAutocomplete = true
            autocompleteIndex = 0
        }
    }

    /// Tabs matching the current @filter (current workspace, not active tab).
    private var matchingTabs: [BrowserState.Tab] {
        let candidates = state.tabs.filter {
            $0.workspaceID == state.currentWorkspaceID && $0.id != state.activeTabID
        }
        guard !tabAutocompleteFilter.isEmpty else { return Array(candidates.prefix(8)) }
        return candidates.filter { tab in
            let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "") : tab.model.title
            return title.lowercased().contains(tabAutocompleteFilter)
        }
    }

    /// Inserts an @tab reference into the input text, preserving any text
    /// that follows the @filter word (e.g., "compare @goo prices" → "compare @Google prices").
    private func insertTabReference(_ tab: BrowserState.Tab) {
        referencedTabIDs.insert(tab.id)
        guard let lastAt = input.lastIndex(of: "@") else { return }
        let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "tab") : tab.model.title
        let displayTitle = title.count > 30 ? String(title.prefix(27)) + "..." : title
        let beforeAt = String(input[..<lastAt])
        let afterAt = String(input[input.index(after: lastAt)...])
        // Find where the filter word ends (first space or end of string)
        let filterEnd: String.Index
        if let spaceIdx = afterAt.firstIndex(of: " ") {
            filterEnd = spaceIdx
        } else {
            filterEnd = afterAt.endIndex
        }
        // Everything after the filter word (including the space separator)
        let trailing = String(afterAt[filterEnd...])
        input = beforeAt + "@" + displayTitle + trailing
        showTabAutocomplete = false
    }

    /// Removes a tab from the referenced set.
    private func removeTabReference(_ tabID: String) {
        referencedTabIDs.remove(tabID)
        // Also remove @tab-name from input text
        if let tab = state.tabs.first(where: { $0.id == tabID }) {
            let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "tab") : tab.model.title
            let displayTitle = title.count > 30 ? String(title.prefix(27)) + "..." : title
            input = input.replacingOccurrences(of: "@" + displayTitle, with: "")
        }
    }
}

// MARK: - Provider Options (Comet-style model toggle)

/// The selectable AI providers in the Gemini panel header. Raw values map 1:1
/// to `Dispatcher.ProviderPreference` so the choice flows straight through to
/// the routing layer.
private enum GeminiProviderOption: String, CaseIterable, Identifiable {
    case auto = "auto"
    case mlx = "mlx"
    case appleFMF = "appleFMF"
    case byokRemote = "byokRemote"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto: return "Auto"
        case .mlx: return "MLX on-device"
        case .appleFMF: return "Apple on-device"
        case .byokRemote: return "Remote (BYOK)"
        }
    }
}

// MARK: - GeminiMessageRow

struct GeminiMessageRow: View {
    let message: GeminiMessage
    @Environment(BrowserState.self) private var state
    @State private var isHovered: Bool = false
    @State private var isGrounding: Bool = false
    @State private var groundingURL: URL?
    @State private var groundingMessage: String?
    @State private var groundingSucceeded: Bool = false

    private var timestamp: String {
        message.timestamp.formatted(date: .omitted, time: .shortened)
    }

    /// Cached link detector — avoids recompiling the regex on every render.
    private static let linkDetector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)

    /// Extracts http/https URLs from the message text.
    private var detectedURLs: [(url: URL, host: String)] {
        guard message.role == .assistant else { return [] }
        var results: [(URL, String)] = []
        Self.linkDetector?.enumerateMatches(in: message.text, range: NSRange(message.text.startIndex..., in: message.text)) { match, _, _ in
            guard let match, let url = match.url,
                  url.scheme == "http" || url.scheme == "https" else { return }
            let host = url.host ?? url.absoluteString
            if !results.contains(where: { $0.0 == url }) {
                results.append((url, host))
            }
        }
        return results
    }

    var body: some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 3) {
            HStack {
                if message.role == .assistant {
                    Spacer(minLength: 32)
                }

                VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                    messageContent
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: HiveDesign.Radius.xl, style: .continuous)
                                .fill(message.role == .user
                                    ? Color.hiveAccent
                                    : Color.secondary.opacity(0.10))
                        )
                        .textSelection(.enabled)

                    // URL actions — open the source or explicitly ground one
                    // source into Honeycomb. This is a fetch affordance, not a claim that
                    // arbitrary assistant prose is a verified citation. It
                    // is never automatic: it
                    // requires this visible user gesture and remains session-
                    // scoped. Unavailable/private failures stay inline instead
                    // of becoming a silent no-op.
                    if !detectedURLs.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(detectedURLs.prefix(3)), id: \.url) { item in
                                HStack(spacing: 5) {
                                    Button(action: { state.openSuggestedURL(item.url) }) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "arrow.up.forward.square")
                                                .font(HiveDesign.Typography.buttonCaption)
                                            Text(item.host)
                                                .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                                                .lineLimit(1)
                                            Spacer(minLength: 4)
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: HiveDesign.Typography.sizeXS, weight: .bold))
                                        }
                                        .foregroundStyle(Color.hiveAccent)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(HiveDesign.Surface.level2)
                                        )
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity)

                                    Button(action: { ground(item.url) }) {
                                        Image(systemName: groundingURL == item.url && isGrounding
                                            ? "arrow.triangle.2.circlepath"
                                            : groundingURL == item.url && groundingSucceeded
                                                ? "checkmark"
                                                : "tray.and.arrow.down")
                                            .font(HiveDesign.Typography.captionSemiBold)
                                            .foregroundStyle(Color.hiveAccent)
                                            .frame(width: 28, height: 28)
                                            .background(HiveDesign.Surface.level2)
                                            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(isGrounding)
                                    .help("Fetch this URL locally for this session")
                                }
                            }

                            if let groundingMessage {
                                Label(
                                    groundingMessage,
                                    systemImage: groundingSucceeded
                                        ? "checkmark.circle"
                                        : "info.circle"
                                )
                                .font(HiveDesign.Typography.microLabelMedium)
                                .foregroundStyle(
                                    groundingSucceeded ? Color.green : .secondary
                                )
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(.top, 2)
                    }

                    HStack(spacing: 6) {
                        Text(timestamp)
                            .font(HiveDesign.Typography.microLabelSecondary)
                            .foregroundStyle(.tertiary)

                        if message.role == .assistant {
                            if !detectedURLs.isEmpty {
                                Text("\(detectedURLs.count) link\(detectedURLs.count == 1 ? "" : "s")")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(Color.hiveAccent.opacity(0.7))
                            }

                            Button(action: { copyMessage() }) {
                                HStack(spacing: 2) {
                                    Image(systemName: copied ? "checkmark" : "square.on.square")
                                        .font(.system(size: HiveDesign.Typography.sizeXS))
                                    Text(copied ? "Copied" : "Copy")
                                        .font(HiveDesign.Typography.microLabelMedium)
                                }
                                .foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                            .opacity(isHovered ? 1 : 0)
                        }
                    }
                }

                if message.role == .user {
                    Spacer(minLength: 32)
                }
            }
        }
        .onHover { isHovered = $0 }
    }

    @State private var copied: Bool = false

    // MARK: - Markdown Rendering

    /// Renders the message as Markdown when possible, falling back to plain text.
    /// Supports bold, italic, inline code, code blocks, bullet lists, numbered lists,
    /// and links — matching Comet and Aside's rich AI chat output.
    private var messageContent: some View {
        if let attributed = try? AttributedString(markdown: message.text) {
            Text(attributed)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(message.role == .user ? .white : .primary)
        } else {
            Text(message.text)
                .font(.system(size: 13, weight: .regular, design: .rounded))
                .foregroundStyle(message.role == .user ? .white : .primary)
        }
    }

    private func copyMessage() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.text, forType: .string)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            copied = false
        }
    }

    /// Performs one explicit source handoff. The browser state owns privacy,
    /// recovery, bundle, and worker validation; this row only presents the
    /// result so the user never has to guess whether grounding happened.
    private func ground(_ url: URL) {
        guard !isGrounding else { return }
        groundingURL = url
        groundingMessage = nil
        groundingSucceeded = false
        isGrounding = true
        Task { @MainActor in
            defer { isGrounding = false }
            do {
                _ = try await state.handoffResearchSource(urlString: url.absoluteString)
                groundingSucceeded = true
                groundingMessage = "Fetched locally for this session"
            } catch {
                groundingSucceeded = false
                groundingMessage = error.localizedDescription
            }
        }
    }
}
