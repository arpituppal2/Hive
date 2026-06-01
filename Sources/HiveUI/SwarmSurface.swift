import SwiftUI
import HiveCore
import HiveDesignSystem
import HiveMetalRenderer
import UniformTypeIdentifiers

private func swarmDropFileURL(from item: NSSecureCoding?) -> URL? {
    if let url = item as? URL {
        return url
    }
    if let url = item as? NSURL {
        return url as URL
    }
    if let data = item as? Data {
        return URL(dataRepresentation: data, relativeTo: nil)
    }
    if let string = item as? String {
        if let url = URL(string: string), url.isFileURL {
            return url
        }
        return URL(fileURLWithPath: string)
    }
    return nil
}

public struct SwarmSurface: View {
    @ObservedObject public var model: HiveAppModel
    public var onCommand: (HiveCommand) -> Void
    public var onOpenImportPanel: () -> Void

    @State private var hoveredThreadID: UUID?
    @State private var attachmentDropTargeted = false
    @State private var messageDisplayLimit = HiveAppModel.swarmSurfaceMessageLimit
    @FocusState private var composerFocused: Bool

    public init(
        model: HiveAppModel,
        onCommand: @escaping (HiveCommand) -> Void,
        onOpenImportPanel: @escaping () -> Void
    ) {
        self.model = model
        self.onCommand = onCommand
        self.onOpenImportPanel = onOpenImportPanel
    }

    public var body: some View {
        HStack(spacing: 0) {
            threadColumn
                .frame(width: 292)
            Divider()
                .opacity(0.45)
            conversationColumn
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider()
                .opacity(0.35)
            actionColumn
                .frame(width: 288)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(HiveColorToken.backgroundDeep.color)
    }

    private var threadColumn: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                HiveSymbol(.liveAssistant, size: 20, active: true)
                    .frame(width: 32, height: 32)
                    .background(HiveColorToken.waxAmber.color.opacity(0.12), in: RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    HiveText("Swarm", role: .nectarCardTitle)
                    HiveText(model.chatStatusText, role: .scaffoldLabel)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .lineLimit(1)
                }
                Spacer()
                Button {
                    withAnimation(HiveMotion.panel) {
                        model.startNewSwarmThread()
                    }
                    composerFocused = true
                } label: {
                    HiveSymbol(.quickCapture, size: 16, active: true)
                }
                .buttonStyle(HiveGlassButtonStyle(active: true, compact: true))
                .accessibilityLabel("Start new Swarm chat")
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(model.visibleSwarmThreadsForSurface) { thread in
                        SwarmThreadRow(
                            thread: thread,
                            selected: thread.id == model.activeSwarmThreadID,
                            hovered: hoveredThreadID == thread.id,
                            onOpen: { model.openSwarmThread(thread.id) },
                            onDelete: { model.deleteSwarmThread(thread.id) }
                        )
                        .onHover { hovered in
                            hoveredThreadID = hovered ? thread.id : nil
                        }
                    }
                    if model.hiddenSwarmThreadCount > 0 {
                        SwarmPreservedHistoryRow(text: "\(model.hiddenSwarmThreadCount) older chats preserved")
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 16)
            }
        }
        .background(HiveColorToken.backgroundMid.color.opacity(0.72))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Swarm chat history")
    }

    private var conversationColumn: some View {
        VStack(spacing: 0) {
            conversationHeader
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 12)
            Divider()
                .opacity(0.24)
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        if activeMessages.isEmpty {
                            SwarmEmptyState(
                                onAskRecommendation: {
                                    model.swarmDraft = "What do you recommend I do next based on The Colony, The Hive, and recent Field sources?"
                                    model.sendSwarmMessage()
                                },
                                onAddMemory: {
                                    model.swarmDraft = "Remember "
                                    composerFocused = true
                                }
                            )
                            .padding(.top, 40)
                        } else {
                            if hiddenActiveMessageCount > 0 {
                                Button {
                                    withAnimation(HiveMotion.panel) {
                                        messageDisplayLimit = min(
                                            messageDisplayLimit + HiveAppModel.swarmSurfaceMessageLimit,
                                            HiveAppModel.swarmSurfaceExpandedMessageLimit
                                        )
                                    }
                                } label: {
                                    SwarmPreservedHistoryRow(text: "Show earlier messages")
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Show earlier Swarm messages")
                            }
                            ForEach(activeMessages) { message in
                                SwarmMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 18)
                }
                .onChange(of: activeMessages.count) { _, _ in
                    if let lastID = activeMessages.last?.id {
                        withAnimation(HiveMotion.panel) {
                            proxy.scrollTo(lastID, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: model.activeSwarmThreadID) { _, _ in
                    messageDisplayLimit = HiveAppModel.swarmSurfaceMessageLimit
                }
            }
            composer
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
        }
    }

    private var conversationHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HiveText(model.activeSwarmThreadTitle, role: .nectarTitle)
                    .lineLimit(1)
                HiveText("Ask, add context, capture a page, or pull in Field and Colony entries with @.", role: .scaffoldBody)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .lineLimit(2)
            }
            Spacer()
            HiveSymbolButton(.quickCapture, title: "New", compact: true) {
                model.startNewSwarmThread()
                composerFocused = true
            }
            HiveSymbolButton(.quickCapture, title: "Save", compact: true) {
                onCommand(.fileAnswer)
            }
            .disabled(!model.commandAvailability(for: .fileAnswer).isEnabled)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if model.swarmDraft.contains("@") {
                let suggestions = model.swarmMentionSuggestions()
                if !suggestions.isEmpty {
                    mentionStrip(suggestions)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            if !model.swarmDraftAttachments.isEmpty {
                attachmentStrip
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
            HStack(alignment: .bottom, spacing: 10) {
                Button(action: onOpenImportPanel) {
                    HiveSymbol(.attach, size: 16)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach files")
                .help("Attach files")
                TextField("Ask Swarm or type @ to add context", text: $model.swarmDraft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(HiveTypography.chromeBody)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                    .lineLimit(1...5)
                    .focused($composerFocused)
                    .onSubmit { model.sendSwarmMessage() }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 2)
                Button {
                    model.sendSwarmMessage()
                } label: {
                    HiveSymbol(.send, size: 16, active: composerHasSendableContent)
                        .frame(width: 36, height: 36)
                        .background(
                            composerHasSendableContent
                                ? HiveColorToken.waxAmber.color.opacity(0.18)
                                : HiveColorToken.nectarText.color.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!composerHasSendableContent)
                .accessibilityLabel("Send to Swarm")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(minHeight: 54)
            .background(
                attachmentDropTargeted
                    ? HiveColorToken.waxAmber.color.opacity(0.14)
                    : HiveColorToken.raisedSurface.color,
                in: RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous)
            )
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill((composerFocused || attachmentDropTargeted) ? HiveColorToken.waxAmber.color.opacity(0.5) : .clear)
                    .frame(height: 1)
                    .padding(.horizontal, 14)
            }
            .shadow(color: HiveColorToken.backgroundDeep.color.opacity(0.18), radius: 8, x: 0, y: 3)
            .onDrop(of: [UTType.fileURL.identifier], isTargeted: $attachmentDropTargeted, perform: handleAttachmentDrop)
        }
    }

    private var composerHasSendableContent: Bool {
        !model.swarmDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.swarmDraftAttachments.isEmpty
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.swarmDraftAttachments) { attachment in
                    SwarmAttachmentChip(attachment: attachment) {
                        model.removeSwarmAttachment(attachment.id)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .accessibilityLabel("Draft attachments")
    }

    private func handleAttachmentDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = swarmDropFileURL(from: item) else { return }
                Task { @MainActor in
                    model.addSwarmAttachmentURLs([url])
                }
            }
        }
        return accepted
    }

    private func mentionStrip(_ suggestions: [HiveSwarmReference]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(suggestions) { reference in
                    Button {
                        model.insertSwarmMention(reference)
                        composerFocused = true
                    } label: {
                        HStack(spacing: 7) {
                            HiveSymbol(reference.kind.symbolName, size: 13, active: true)
                            Text(reference.title)
                                .font(HiveTypography.chromeFootnoteEmphasized)
                                .lineLimit(1)
                            Text(reference.kind.displayTitle)
                                .font(HiveTypography.chromeCaption)
                                .foregroundStyle(HiveColorToken.nectarMuted.color)
                        }
                    }
                    .buttonStyle(HiveGlassButtonStyle(compact: true))
                    .accessibilityLabel("Add \(reference.title) from \(reference.kind.displayTitle)")
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var actionColumn: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HiveText("Plugins", role: .scaffoldLabel)
                    ForEach(HiveSwarmPlugin.allCases) { plugin in
                        SwarmPluginRow(
                            plugin: plugin,
                            enabled: model.swarmEnabledPlugins.contains(plugin),
                            onToggle: { model.toggleSwarmPlugin(plugin) }
                        )
                    }
                }
                VStack(alignment: .leading, spacing: 10) {
                    HiveText("Actions", role: .scaffoldLabel)
                    SwarmActionButton(symbol: .importAction, title: "Add Files", detail: "Choose files or folders for Field.", action: onOpenImportPanel)
                    SwarmActionButton(symbol: .screenshot, title: "Capture Page", detail: "Save the current page into Field.") {
                        model.captureCurrentPage(command: "Capture the current page for Swarm.")
                    }
                    SwarmActionButton(symbol: .runMaintenance, title: "Review Field", detail: "Process queued sources and refresh The Colony.") {
                        onCommand(.reviewMemory)
                    }
                    SwarmActionButton(symbol: .hiveGraph, title: "Re-Index Hive", detail: "Rebuild the map from current memory.") {
                        model.requestHiveReindex()
                    }
                    SwarmActionButton(symbol: .settings, title: "Automations", detail: "Review daily passes and shortcuts.") {
                        onCommand(.settings)
                    }
                }
            }
            .padding(18)
        }
        .background(HiveColorToken.backgroundMid.color.opacity(0.54))
    }

    private var activeMessages: [HiveSwarmMessage] {
        model.activeSwarmMessagesForDisplay(limit: messageDisplayLimit)
    }

    private var hiddenActiveMessageCount: Int {
        model.hiddenActiveSwarmMessageCount(limit: messageDisplayLimit)
    }
}

public struct SwarmQuickChatSurface: View {
    @ObservedObject public var model: HiveAppModel
    public var onAttach: () -> Void
    public var onOpenHive: () -> Void
    public var onDismiss: () -> Void

    @StateObject private var speechInput = HiveSpeechInputController()
    @StateObject private var speechOutput = HiveSpeechOutputController()
    @State private var attachmentDropTargeted = false
    @State private var voiceModeActive = false
    @State private var lastSpokenMessageID: UUID?
    @FocusState private var composerFocused: Bool

    public init(
        model: HiveAppModel,
        onAttach: @escaping () -> Void,
        onOpenHive: @escaping () -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.model = model
        self.onAttach = onAttach
        self.onOpenHive = onOpenHive
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(spacing: 12) {
            header
            messagePreview
            quickComposer
        }
        .padding(12)
        .frame(width: 680)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.xl, style: .continuous)
                .fill(HiveColorToken.backgroundDeep.color.opacity(0.98))
        )
        .overlay(HiveGrainLayer().allowsHitTesting(false).opacity(0.028))
        .shadow(color: HiveColorToken.backgroundDeep.color.opacity(0.5), radius: 32, x: 0, y: 18)
        .onDrop(of: [UTType.fileURL.identifier], isTargeted: $attachmentDropTargeted, perform: handleAttachmentDrop)
        .onAppear {
            model.prepareQuickSwarmPopup()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                composerFocused = true
            }
            speakLastSwarmResponseIfNeeded()
        }
        .onDisappear {
            speechInput.stop()
            speechOutput.stop()
        }
        .onChange(of: model.activeSwarmLastMessageID) { _, _ in
            speakLastSwarmResponseIfNeeded()
        }
        .animation(HiveMotion.panel, value: model.swarmDraftAttachments)
        .animation(HiveMotion.panel, value: activeMessages.count)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Swarm quick chat")
    }

    private var header: some View {
        HStack(spacing: 10) {
            HiveSymbol(
                .hiveGraph,
                size: 17,
                active: true,
                rendering: .palette(
                    primary: HiveColorToken.waxAmberBright.color,
                    secondary: HiveColorToken.waxAmberDeep.color
                )
            )
            .frame(width: 34, height: 34)
            .background(HiveColorToken.waxAmber.color.opacity(0.12), in: RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 2) {
                HiveText("Swarm", role: .scaffoldAction)
                HiveText(headerDetail, role: .scaffoldMicro)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Menu {
                Button {
                    model.startNewSwarmThread()
                    composerFocused = true
                } label: {
                    HStack {
                        HiveSymbol(.feedHive, size: 14, active: true)
                        Text("New Chat")
                    }
                }
                Divider()
                ForEach(model.swarmThreads.prefix(8)) { thread in
                    Button {
                        model.openSwarmThread(thread.id)
                        composerFocused = true
                    } label: {
                        HStack {
                            HiveSymbol(.chat, size: 14, active: thread.id == model.activeSwarmThreadID)
                            Text(thread.title)
                        }
                    }
                }
            } label: {
                HiveSymbol(.chat, size: 15, active: true)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(HiveGlassButtonStyle(compact: true))
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Open old Swarm chats")

            Button(action: onOpenHive) {
                HStack(spacing: 7) {
                    HiveSymbol(.hiveGraph, size: 14, active: true)
                    HiveText("Open Hive", role: .scaffoldLabel)
                }
                .padding(.horizontal, 10)
                .frame(height: 34)
            }
            .buttonStyle(HiveGlassButtonStyle(active: true, compact: true))
            .accessibilityLabel("Open Hive")

            Button(action: onDismiss) {
                HiveSymbol(.close, size: 16)
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(HiveGlassButtonStyle(compact: true))
            .keyboardShortcut(.escape, modifiers: [])
            .accessibilityLabel("Dismiss Swarm quick chat")
        }
    }

    private var messagePreview: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if activeMessages.isEmpty {
                        HStack(spacing: 10) {
                            HiveSymbol(.liveAssistant, size: 18, active: true)
                            HiveText("Ask a quick question, attach context, or use @ to pull in Field and Colony memory.", role: .scaffoldBody, lineSpacing: 4)
                                .foregroundStyle(HiveColorToken.nectarMuted.color)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(HiveColorToken.cellSurface.color.opacity(0.44), in: RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous))
                    } else {
                        ForEach(activeMessages.suffix(5)) { message in
                            SwarmQuickMessageRow(message: message)
                                .id(message.id)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: 218)
            .scrollIndicators(.hidden)
            .onChange(of: activeMessages.last?.id) { _, lastID in
                guard let lastID else { return }
                withAnimation(HiveMotion.panel) {
                    proxy.scrollTo(lastID, anchor: .bottom)
                }
            }
        }
    }

    private var quickComposer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !model.swarmDraftAttachments.isEmpty {
                attachmentStrip
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(alignment: .bottom, spacing: 8) {
                Button(action: onAttach) {
                    HiveSymbol(.attach, size: 16, active: attachmentDropTargeted)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach files")

                TextField("Ask Swarm…", text: $model.swarmDraft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(HiveTypography.chromeBody)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                    .lineLimit(1...4)
                    .focused($composerFocused)
                    .onSubmit { submit() }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 4)

                Button(action: toggleVoiceMode) {
                    HiveSymbol(
                        .liveAssistant,
                        size: 18,
                        active: voiceModeActive || speechInput.isRecording,
                        rendering: speechInput.isRecording ? .primaryAction : .hierarchical,
                        motion: speechInput.isRecording ? .pulse : .none,
                        motionValue: speechInput.isRecording ? 1 : 0
                    )
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(speechInput.isRecording ? "Stop voice mode" : "Start voice mode")
                .accessibilityValue(speechInput.statusText)
                .help("Voice mode uses Apple speech recognition and speaks Swarm replies.")

                Button(action: submit) {
                    HiveSymbol(.send, size: 16, active: composerHasSendableContent)
                        .frame(width: 36, height: 36)
                        .background(
                            composerHasSendableContent
                                ? HiveColorToken.waxAmber.color.opacity(0.18)
                                : HiveColorToken.nectarText.color.opacity(0.04),
                            in: RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .disabled(!composerHasSendableContent)
                .accessibilityLabel("Send to Swarm")
            }
            .padding(8)
            .background(composerBackground, in: RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(composerStroke)
                    .frame(height: composerFocused || attachmentDropTargeted ? 1 : 0)
                    .padding(.horizontal, 14)
            }

            if speechInput.shouldShowStatus {
                HiveText(speechInput.statusText, role: .scaffoldMicro)
                    .foregroundStyle(speechInput.isRecording ? HiveColorToken.waxAmberBright.color : HiveColorToken.nectarMuted.color)
                    .padding(.leading, 10)
            }
        }
    }

    private var attachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.swarmDraftAttachments) { attachment in
                    SwarmAttachmentChip(attachment: attachment) {
                        model.removeSwarmAttachment(attachment.id)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .accessibilityLabel("Quick chat attachments")
    }

    private var activeMessages: [HiveSwarmMessage] {
        model.activeSwarmMessagesForDisplay(limit: 5)
    }

    private var headerDetail: String {
        if voiceModeActive || speechInput.isRecording { return speechInput.statusText }
        if model.isWorking { return "Working with your local Hive context" }
        return model.activeSwarmThreadTitle
    }

    private var composerHasSendableContent: Bool {
        !model.swarmDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !model.swarmDraftAttachments.isEmpty
    }

    private var composerBackground: Color {
        if attachmentDropTargeted { return HiveColorToken.waxAmber.color.opacity(0.18) }
        if composerFocused { return HiveColorToken.raisedSurface.color.opacity(0.96) }
        return HiveColorToken.cellSurface.color.opacity(0.86)
    }

    private var composerStroke: Color {
        if attachmentDropTargeted || composerFocused { return HiveColorToken.waxAmberBright.color.opacity(0.52) }
        return HiveColorToken.scaffoldFaint.color.opacity(0.24)
    }

    private func submit() {
        guard composerHasSendableContent else { return }
        lastSpokenMessageID = activeMessages.last?.id
        model.sendSwarmMessage()
        composerFocused = true
    }

    private func toggleVoiceMode() {
        voiceModeActive = true
        if !speechInput.isRecording {
            speechOutput.interruptForUserSpeech()
        }
        speechInput.toggle(appendingTo: model.swarmDraft) { updated in
            model.swarmDraft = updated
        }
    }

    private func speakLastSwarmResponseIfNeeded() {
        guard voiceModeActive,
              let message = activeMessages.last,
              message.speaker == .swarm,
              message.id != lastSpokenMessageID,
              !message.text.localizedCaseInsensitiveContains("Thinking with The Colony"),
              !message.text.localizedCaseInsensitiveContains("Reading attachments")
        else { return }
        lastSpokenMessageID = message.id
        speechOutput.speakSwarmResponse(
            text: message.text,
            selectedVoiceIdentifier: SwarmVoiceSettingsStore.selectedVoiceIdentifier()
        )
    }

    private func handleAttachmentDrop(_ providers: [NSItemProvider]) -> Bool {
        var accepted = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                guard let url = swarmDropFileURL(from: item) else { return }
                Task { @MainActor in
                    model.addSwarmAttachmentURLs([url])
                }
            }
        }
        return accepted
    }
}

private struct SwarmQuickMessageRow: View {
    var message: HiveSwarmMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.speaker == .user { Spacer(minLength: 44) }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    HiveSymbol(message.speaker == .user ? .command : .liveAssistant, size: 12, active: message.speaker == .swarm)
                    HiveText(message.speaker == .user ? "You" : "Swarm", role: .scaffoldMicro)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                    if let note = message.note, !note.isEmpty {
                        HiveText(note, role: .scaffoldMicro)
                            .foregroundStyle(HiveColorToken.scaffoldGray.color)
                    }
                }
                Text(message.text)
                    .font(HiveTypography.chromeBody)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                    .lineLimit(5)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 540, alignment: .leading)
            .background(bubbleBackground, in: RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous))
            if message.speaker == .swarm { Spacer(minLength: 44) }
        }
    }

    private var bubbleBackground: Color {
        message.speaker == .user ? HiveColorToken.waxAmber.color.opacity(0.16) : HiveColorToken.raisedSurface.color.opacity(0.76)
    }

}

private struct SwarmThreadRow: View {
    var thread: HiveSwarmThread
    var selected: Bool
    var hovered: Bool
    var onOpen: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    HiveSymbol(.chat, size: 15, active: selected)
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(thread.title)
                            .font(HiveTypography.chromeAction)
                            .lineLimit(1)
                        Text(summary)
                            .font(HiveTypography.chromeCaption)
                            .foregroundStyle(HiveColorToken.nectarMuted.color)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if hovered || selected {
                Button(action: onDelete) {
                    HiveSymbol(.forget, size: 13)
                }
                .buttonStyle(HiveGlassButtonStyle(destructive: true, compact: true))
                .accessibilityLabel("Delete \(thread.title)")
            }
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 52)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        .animation(HiveMotion.panel, value: hovered)
        .animation(HiveMotion.panel, value: selected)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(thread.title)
    }

    private var summary: String {
        thread.messages.last?.text ?? "No messages yet"
    }

    private var rowBackground: Color {
        if selected { return HiveColorToken.waxAmber.color.opacity(0.14) }
        if hovered { return HiveColorToken.cellSurface.color.opacity(0.58) }
        return HiveColorToken.cellSurface.color.opacity(0.32)
    }
}

private struct SwarmPreservedHistoryRow: View {
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            HiveSymbol(.archive, size: 12)
            Text(text)
                .font(HiveTypography.chromeCaption)
                .foregroundStyle(HiveColorToken.nectarMuted.color)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HiveColorToken.cellSurface.color.opacity(0.28), in: RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

private struct SwarmMessageBubble: View {
    var message: HiveSwarmMessage

    var body: some View {
        HStack(alignment: .top) {
            if message.speaker == .user { Spacer(minLength: 48) }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    HiveSymbol(message.speaker == .user ? .command : .liveAssistant, size: 13, active: message.speaker == .swarm)
                    HiveText(message.speaker == .user ? "You" : "Swarm", role: .scaffoldLabel)
                    if let note = message.note, !note.isEmpty {
                        HiveText(note, role: .scaffoldMicro)
                            .foregroundStyle(HiveColorToken.nectarMuted.color)
                    }
                }
                Text(message.text)
                    .font(HiveTypography.chromeBody)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                    .fixedSize(horizontal: false, vertical: true)
                if !message.citations.isEmpty {
                    citationStrip
                }
            }
            .padding(13)
            .frame(maxWidth: 640, alignment: .leading)
            .background(bubbleBackground, in: RoundedRectangle(cornerRadius: HiveLayoutMetrics.surfaceCornerRadius, style: .continuous))
            if message.speaker == .swarm { Spacer(minLength: 48) }
        }
        .frame(maxWidth: .infinity, alignment: message.speaker == .user ? .trailing : .leading)
    }

    private var citationStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(message.citations.prefix(8)) { reference in
                    Label {
                        Text(reference.title)
                            .lineLimit(1)
                    } icon: {
                        HiveSymbol(reference.kind.symbolName, size: 11)
                    }
                    .font(HiveTypography.chromeCaption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(HiveColorToken.backgroundMid.color.opacity(0.72), in: Capsule())
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                }
            }
        }
    }

    private var bubbleBackground: Color {
        message.speaker == .user ? HiveColorToken.waxAmber.color.opacity(0.16) : HiveColorToken.raisedSurface.color.opacity(0.82)
    }

}

private struct SwarmAttachmentChip: View {
    var attachment: SwarmDraftAttachment
    var onRemove: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HiveSymbol(symbol, size: 13, active: attachment.status == .extracted)
            VStack(alignment: .leading, spacing: 1) {
                Text(attachment.displayName)
                    .font(HiveTypography.chromeFootnoteEmphasized)
                    .lineLimit(1)
                Text(statusText)
                    .font(HiveTypography.chromeCaption)
                    .foregroundStyle(statusColor)
                    .lineLimit(1)
            }
            Button(action: onRemove) {
                HiveSymbol(.close, size: 10)
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Remove \(attachment.displayName)")
        }
        .padding(.leading, 10)
        .padding(.trailing, 6)
        .padding(.vertical, 7)
        .background(HiveColorToken.cellSurface.color.opacity(0.62), in: RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        .frame(maxWidth: 260)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(attachment.displayName), \(statusText)")
    }

    private var symbol: HiveSymbolName {
        let pdfKind = SourceKind(rawValue: "pdf")
        switch attachment.kind {
        case .image, .screenshot:
            return .screenshot
        case let kind where kind == pdfKind || kind == .text || kind == .genericFile || kind == .attachment:
            return .indexedOnly
        case .audio:
            return .voiceNote
        case .video:
            return .presentation
        default:
            return .importAction
        }
    }

    private var statusText: String {
        switch attachment.status {
        case .extracted:
            return attachment.chunkCount == 1 ? "Ready, 1 chunk" : "Ready, \(attachment.chunkCount) chunks"
        case .failed:
            return attachment.errorMessage ?? "Could not extract"
        default:
            return attachment.status.displayTitle
        }
    }

    private var statusColor: Color {
        switch attachment.status {
        case .extracted:
            return HiveColorToken.waxAmberBright.color
        case .failed, .cancelled:
            return HiveColorToken.conflict.color
        default:
            return HiveColorToken.nectarMuted.color
        }
    }
}

private struct SwarmEmptyState: View {
    var onAskRecommendation: () -> Void
    var onAddMemory: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                HiveSymbol(.liveAssistant, size: 26, active: true)
                    .frame(width: 52, height: 52)
                    .background(HiveColorToken.waxAmber.color.opacity(0.12), in: RoundedRectangle(cornerRadius: HiveLayoutMetrics.surfaceCornerRadius, style: .continuous))
                VStack(alignment: .leading, spacing: 7) {
                    HiveText("Ask Swarm", role: .nectarCardTitle)
                    HiveText("Use @ to bring in a Field item, Colony page, or Hive cell. Swarm will route notes, captures, searches, and questions through the real Hive backend.", role: .nectarBody, lineSpacing: 6)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                }
            }
            HStack(spacing: 10) {
                HiveSymbolButton(.chat, title: "Recommend", active: true, compact: true, action: onAskRecommendation)
                HiveSymbolButton(.rawInputs, title: "Add Memory", compact: true, action: onAddMemory)
            }
        }
        .padding(18)
        .frame(maxWidth: 620, alignment: .leading)
        .background(HiveColorToken.raisedSurface.color.opacity(0.74), in: RoundedRectangle(cornerRadius: HiveLayoutMetrics.surfaceCornerRadius, style: .continuous))
    }
}

private struct SwarmPluginRow: View {
    var plugin: HiveSwarmPlugin
    var enabled: Bool
    var onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(alignment: .center, spacing: 10) {
                HiveSymbol(plugin.symbolName, size: 16, active: enabled)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(plugin.title)
                        .font(HiveTypography.chromeAction)
                    Text(plugin.subtitle)
                        .font(HiveTypography.chromeCaption)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .lineLimit(2)
                }
                Spacer()
                HiveSymbol(enabled ? .select : .unselected, size: 15, active: enabled)
            }
            .padding(10)
            .background(enabled ? HiveColorToken.waxAmber.color.opacity(0.12) : HiveColorToken.cellSurface.color.opacity(0.42), in: RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(enabled ? "Disable" : "Enable") \(plugin.title)")
    }
}

private struct SwarmActionButton: View {
    var symbol: HiveSymbolName
    var title: String
    var detail: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: 10) {
                HiveSymbol(symbol, size: 16, active: true)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(HiveTypography.chromeAction)
                    Text(detail)
                        .font(HiveTypography.chromeCaption)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .lineLimit(2)
                }
                Spacer()
                HiveSymbol(.send, size: 13)
            }
            .padding(10)
            .background(HiveColorToken.cellSurface.color.opacity(0.44), in: RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}
