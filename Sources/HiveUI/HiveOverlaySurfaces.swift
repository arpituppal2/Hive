import SwiftUI
import HiveCore
import HiveDesignSystem
import HiveMetalRenderer
#if os(macOS)
import AppKit
#endif

public struct HiveCommandPalette: View {
    @Binding public var query: String
    public var onCommand: (HiveCommand) -> Void
    public var commandAvailability: (HiveCommand) -> HiveCommandAvailability
    public var onDismiss: () -> Void
    @FocusState private var searchFocused: Bool
    @State private var selectedCommand: HiveCommand = .addSources

    public init(
        query: Binding<String>,
        onCommand: @escaping (HiveCommand) -> Void,
        commandAvailability: @escaping (HiveCommand) -> HiveCommandAvailability = { HiveCommandAvailability.enabled(for: $0) },
        onDismiss: @escaping () -> Void
    ) {
        self._query = query
        self.onCommand = onCommand
        self.commandAvailability = commandAvailability
        self.onDismiss = onDismiss
    }

    public var body: some View {
        ZStack {
            HiveColorToken.backgroundDeep.color.opacity(0.72)
                .onTapGesture {
                    onDismiss()
                }
            VStack(spacing: HiveSpacing.lg) {
                HStack(spacing: 10) {
                    HiveSymbol(.search, size: 16, rendering: .monochrome(HiveColorToken.scaffoldFaint.color))
                    TextField("Search actions...", text: $query)
                        .textFieldStyle(.plain)
                        .font(HiveTypography.hiveBody)
                        .foregroundStyle(HiveColorToken.nectarText.color)
                        .focused($searchFocused)
                        .onSubmit {
                            run(activeCommand)
                        }
                    HiveSymbolButton(.close, title: nil, compact: true, action: onDismiss)
                        .keyboardShortcut(.escape, modifiers: [])
                }
                .padding(.horizontal, HiveSpacing.md)
                .frame(height: 40)
                .background(HiveColorToken.raisedSurface.color)
                .clipShape(RoundedRectangle(cornerRadius: HiveRadius.sm, style: .continuous))

                HStack(alignment: .top, spacing: HiveSpacing.lg) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: HiveSpacing.lg) {
                            ForEach(CommandPaletteSection.allCases) { section in
                                let commands = filteredCommands.filter { section.commands.contains($0) }
                                if !commands.isEmpty {
                                    VStack(alignment: .leading, spacing: HiveSpacing.sm) {
                                        Text(section.rawValue)
                                            .font(HiveTypography.hiveMeta)
                                            .tracking(0.3)
                                            .foregroundStyle(HiveColorToken.scaffoldFaint.color)
                                        ForEach(commands) { command in
                                            let availability = commandAvailability(command)
                                            CommandPaletteRow(
                                                command: command,
                                                availability: availability,
                                                selected: activeCommand == command
                                            ) {
                                                run(command)
                                            }
                                            .onHover { hovering in
                                                if hovering { selectedCommand = command }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .frame(width: 430)
                    .frame(maxHeight: 460)

                    CommandPalettePreviewPane(
                        command: activeCommand,
                        availability: commandAvailability(activeCommand)
                    )
                    .frame(width: 230)
                }
            }
            .padding(HiveSpacing.lg)
            .modifier(HiveGlassShell(level: .commandPalette))
            .frame(width: 720)
            .transition(.scale(scale: 0.96).combined(with: .opacity))
            .onAppear {
                searchFocused = true
                selectedCommand = filteredCommands.first ?? .addSources
            }
            .onChange(of: query) { _, _ in
                selectedCommand = filteredCommands.first ?? .addSources
            }
        }
    }

    private var activeCommand: HiveCommand {
        filteredCommands.contains(selectedCommand) ? selectedCommand : filteredCommands.first ?? .addSources
    }

    private func run(_ command: HiveCommand) {
        guard commandAvailability(command).isEnabled else { return }
        onCommand(command)
    }

    private var filteredCommands: [HiveCommand] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return HiveCommand.allCases }
        return HiveCommand.allCases.filter {
            $0.rawValue.lowercased().contains(trimmed)
                || $0.description.lowercased().contains(trimmed)
                || $0.scope.lowercased().contains(trimmed)
                || $0.defaultShortcut.lowercased().contains(trimmed)
        }
    }

}

private struct CommandPalettePreviewPane: View {
    var command: HiveCommand
    var availability: HiveCommandAvailability

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.md) {
            HiveSymbol(command.symbolName, size: 32, active: availability.isEnabled)
                .frame(width: 44, height: 44)
                .background(HiveColorToken.waxAmber.color.opacity(availability.isEnabled ? 0.14 : 0.05), in: RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: HiveSpacing.xs) {
                Text(command.rawValue)
                    .font(HiveTypography.hiveTitle)
                    .foregroundStyle(availability.isEnabled ? HiveColorToken.nectarText.color : HiveColorToken.scaffoldFaint.color)
                Text(availability.isEnabled ? command.preview : availability.reason ?? command.preview)
                    .font(HiveTypography.hiveBody)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            ShortcutBadge(availability.shortcut)
        }
        .padding(HiveSpacing.lg)
        .frame(maxHeight: 460, alignment: .topLeading)
        .background(HiveColorToken.raisedSurface.color.opacity(0.74), in: RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(command.rawValue). \(availability.isEnabled ? command.preview : availability.reason ?? command.preview)")
    }
}

private enum CommandPaletteSection: String, CaseIterable, Identifiable {
    case capture = "CAPTURE"
    case navigate = "NAVIGATE"
    case organize = "ORGANIZE"
    case review = "REVIEW"

    var id: String { rawValue }

    var commands: [HiveCommand] {
        switch self {
        case .capture:
            return [.addSources, .live, .chat]
        case .navigate:
            return [.findMemory, .wiki, .graph, .rawSources]
        case .organize:
            return [.reviewMemory, .fileAnswer, .createSlideDeck]
        case .review:
            return [.downloadAttachments, .settings]
        }
    }
}

private struct CommandPaletteRow: View {
    var command: HiveCommand
    var availability: HiveCommandAvailability
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                HiveSymbol(
                    command.symbolName,
                    size: 16,
                    active: selected && availability.isEnabled,
                    rendering: .monochrome(selected ? HiveColorToken.waxAmber.color : HiveColorToken.nectarMuted.color)
                )
                .frame(width: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text(command.rawValue)
                        .font(HiveTypography.hiveBodyMed)
                        .foregroundStyle(availability.isEnabled ? HiveColorToken.nectarText.color : HiveColorToken.scaffoldFaint.color)
                        .lineLimit(1)
                    if !availability.isEnabled, let reason = availability.reason {
                        Text(reason)
                            .font(HiveTypography.hiveCaption)
                            .foregroundStyle(HiveColorToken.nectarMuted.color)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 10)
                ShortcutBadge(availability.shortcut)
            }
            .padding(.horizontal, HiveSpacing.lg)
            .frame(height: 44)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        .disabled(!availability.isEnabled)
        .opacity(availability.isEnabled ? 1 : 0.62)
        .accessibilityHint(availability.isEnabled ? "Runs \(command.rawValue)." : availability.reason ?? "This command needs more context.")
    }

    private var rowBackground: Color {
        selected
            ? HiveColorToken.waxAmber.color.opacity(0.12)
            : Color.clear
    }
}

private struct ShortcutBadge: View {
    var value: String

    init(_ value: String) {
        self.value = value
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(ShortcutVisualToken.tokens(from: value)) { token in
                switch token.kind {
                case .symbol(let symbol, let label):
                    HiveSymbol(symbol, size: 12, weight: .bold, rendering: .monochrome(HiveColorToken.nectarMuted.color), accessibilityLabel: label)
                        .frame(width: 14, height: 14)
                        .accessibilityHidden(true)
                case .text(let text):
                    Text(text)
                        .font(HiveTypography.chromeShortcut)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(HiveColorToken.raisedSurface.color)
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.smallCornerRadius, style: .continuous))
        .accessibilityLabel("Shortcut \(value)")
    }
}

private struct ShortcutVisualToken: Identifiable, Hashable {
    enum Kind: Hashable {
        case symbol(HiveSymbolName, String)
        case text(String)
    }

    var id: String
    var kind: Kind

    static func tokens(from value: String) -> [ShortcutVisualToken] {
        guard let shortcut = HiveKeyboardShortcut.parse(value) else {
            return fallbackTokens(from: value)
        }
        var result = HiveShortcutModifier.appleDisplayOrder
            .filter { shortcut.modifiers.contains($0) }
            .map { ShortcutVisualToken(id: $0.rawValue, kind: .symbol($0.symbolName, $0.title)) }
        result.append(ShortcutVisualToken(id: "key-\(shortcut.key)", kind: .text(shortKeyLabel(shortcut.key))))
        return result
    }

    private static func fallbackTokens(from value: String) -> [ShortcutVisualToken] {
        let pieces = value
            .components(separatedBy: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "+-")))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters)) }
            .filter { !$0.isEmpty }

        let tokens = pieces.enumerated().map { index, piece -> ShortcutVisualToken in
            if let symbol = modifierSymbol(for: piece) {
                return ShortcutVisualToken(id: "modifier-\(index)-\(piece)", kind: .symbol(symbol.name, symbol.label))
            }
            return ShortcutVisualToken(id: "text-\(index)-\(piece)", kind: .text(shortKeyLabel(piece)))
        }

        return tokens.isEmpty ? [ShortcutVisualToken(id: "raw-\(value)", kind: .text(value))] : tokens
    }

    private static func modifierSymbol(for piece: String) -> (name: HiveSymbolName, label: String)? {
        switch piece.lowercased() {
        case "command", "cmd":
            return (.command, "Command")
        case "option", "alt":
            return (.shortcutOption, "Option")
        case "shift":
            return (.shortcutShift, "Shift")
        case "control", "ctrl":
            return (.shortcutControl, "Control")
        default:
            return nil
        }
    }

    private static func shortKeyLabel(_ value: String) -> String {
        switch value.lowercased() {
        case "comma":
            return ","
        case "space":
            return "Space"
        case "return", "enter":
            return "Return"
        case "delete", "backspace":
            return "Delete"
        case "escape", "esc":
            return "Esc"
        default:
            return value.uppercased()
        }
    }
}

public struct HiveChatSheet: View {
    @Binding public var text: String
    public var entries: [HiveChatEntry]
    public var statusText: String
    public var onSend: () -> Void
    public var onFileAnswer: () -> Void
    public var onClose: () -> Void
    @StateObject private var speechInput = HiveSpeechInputController()
    @FocusState private var inputFocused: Bool

    public init(
        text: Binding<String>,
        entries: [HiveChatEntry],
        statusText: String = "Indexed memory only",
        onSend: @escaping () -> Void,
        onFileAnswer: @escaping () -> Void = {},
        onClose: @escaping () -> Void
    ) {
        self._text = text
        self.entries = entries
        self.statusText = statusText
        self.onSend = onSend
        self.onFileAnswer = onFileAnswer
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                HiveSymbol(statusSymbol, size: 15, active: statusSymbol == .synthesizing, motion: statusSymbol == .synthesizing ? .variableColor : .none, motionValue: entries.count)
                HiveText("Ask Hive", role: .scaffoldAction)
                Spacer()
                if entries.contains(where: { $0.speaker == .hive }) {
                    HiveSymbolButton(.quickCapture, title: "File answer", compact: true, action: onFileAnswer)
                }
                HiveSymbolButton(.close, title: nil, compact: true, action: onClose)
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(16)
            if entries.isEmpty {
                Spacer()
                VStack(spacing: 18) {
                    HiveSymbol(
                        .chat,
                        size: 38,
                        active: true,
                        rendering: .primaryAction,
                        motion: .pulse,
                        motionValue: 1
                    )
                    .padding(22)
                    .background(HiveColorToken.waxAmber.color.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.surfaceCornerRadius, style: .continuous))
                    .modifier(PulsingAmber())
                    VStack(spacing: 7) {
                        HiveText("Ask from local memory", role: .nectarCardTitle)
                    }
                    VStack(spacing: 8) {
                        ForEach(chatStarters, id: \.self) { starter in
                            ChatStarterButton(title: starter) {
                                text = starter
                                inputFocused = true
                            }
                        }
                    }
                    .frame(maxWidth: 300)
                }
                .padding(.horizontal, 24)
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(entries) { entry in
                            ChatRow(entry: entry)
                                .transition(.move(edge: entry.speaker == .user ? .trailing : .leading).combined(with: .opacity))
                        }
                    }
                    .padding(16)
                    .animation(HiveMotion.panel, value: entries)
                }
            }
            HStack(spacing: 10) {
                TextField("Ask Hive or add a note", text: $text)
                    .font(HiveTypography.chromeSearch)
                    .focused($inputFocused)
                    .onSubmit(onSend)
                    .accessibilityLabel("Ask Hive")
                    .accessibilityHint("Ask a question, or start with Remember, Note, or I am to add information to Hive.")
                    .hivePlainFieldChrome(focused: inputFocused)
                HiveSpeechInputButton(speechInput: speechInput, text: $text, compact: true)
                HiveSymbolButton(.send, title: "Send", active: !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, motion: .bounce, motionValue: entries.count, compact: true, action: onSend)
            }
            .padding(14)
            if speechInput.shouldShowStatus {
                HiveText(speechInput.statusText, role: .scaffoldBody)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
                    .padding(.bottom, 12)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(.clear)
        .onAppear {
            inputFocused = true
        }
    }

    private var statusSymbol: HiveSymbolName {
        statusText.localizedCaseInsensitiveContains("indexed") ? .indexedOnly : .synthesizing
    }

    private var chatStarters: [String] {
        [
            "What changed recently?",
            "What do you recommend?",
            "Remember I am working on..."
        ]
    }
}

public enum HiveLiveAssistantVisualState: String, CaseIterable, Sendable {
    case idle
    case listening
    case thinking

    var title: String {
        switch self {
        case .idle:
            return "Ready"
        case .listening:
            return "Listening"
        case .thinking:
            return "Thinking"
        }
    }

    var primaryColor: Color {
        switch self {
        case .idle:
            return HiveColorToken.scaffoldFaint.color
        case .listening:
            return HiveColorToken.sealed.color
        case .thinking:
            return HiveColorToken.waxAmberBright.color
        }
    }

    var secondaryColor: Color {
        switch self {
        case .idle:
            return HiveColorToken.nectarMuted.color
        case .listening:
            return HiveColorToken.waxAmberBright.color
        case .thinking:
            return HiveColorToken.neuralGold.color
        }
    }
}

public struct HiveLiveAssistantOverlay: View {
    @Binding public var text: String
    public var spokenText: String
    public var spokenSequence: Int
    public var isWorking: Bool
    public var statusText: String
    public var onSubmit: (String) -> Void
    public var onCaptureScreen: () -> Void
    public var onClose: () -> Void
    @StateObject private var speechInput = HiveSpeechInputController()
    @StateObject private var speechOutput = HiveSpeechOutputController()
    @FocusState private var inputFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    public init(
        text: Binding<String>,
        spokenText: String = "",
        spokenSequence: Int = 0,
        isWorking: Bool,
        statusText: String,
        onSubmit: @escaping (String) -> Void,
        onCaptureScreen: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self._text = text
        self.spokenText = spokenText
        self.spokenSequence = spokenSequence
        self.isWorking = isWorking
        self.statusText = statusText
        self.onSubmit = onSubmit
        self.onCaptureScreen = onCaptureScreen
        self.onClose = onClose
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                liveMark
                VStack(alignment: .leading, spacing: 3) {
                    HiveText("Hive Live", role: .scaffoldAction)
                    HiveText(currentStatusText, role: .scaffoldBody)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .lineLimit(1)
                }
                Spacer(minLength: 12)
                HiveSymbolButton(.screenshot, title: nil, active: visualState == .thinking, motion: .bounce, motionValue: isWorking ? 1 : 0, compact: true) {
                    onCaptureScreen()
                }
                HiveSpeechInputButton(
                    speechInput: speechInput,
                    text: $text,
                    compact: true,
                    onStartRecording: {
                        speechOutput.interruptForUserSpeech()
                    }
                )
                HiveSymbolButton(.speak, title: nil, active: speechOutput.isSpeaking, motion: speechOutput.isSpeaking ? .pulse : .none, motionValue: pulse ? 1 : 0, compact: true) {
                    if speechOutput.isSpeaking {
                        speechOutput.stop()
                    } else {
                        speechOutput.speakSwarmResponse(
                            text: spokenText,
                            selectedVoiceIdentifier: SwarmVoiceSettingsStore.selectedVoiceIdentifier()
                        )
                    }
                }
                .disabled(!canSpeak)
                .opacity(canSpeak ? 1 : 0.55)
                HiveSymbolButton(.send, title: nil, active: canSubmit, motion: .bounce, motionValue: text.count, compact: true) {
                    submit()
                }
                .disabled(!canSubmit)
                .opacity(canSubmit ? 1 : 0.55)
                HiveSymbolButton(.close, title: nil, compact: true, action: onClose)
                    .keyboardShortcut(.escape, modifiers: [])
            }

            TextField("Hello Hive, ask, capture, or remember", text: $text)
                .textFieldStyle(.plain)
                .font(HiveTypography.chromeSearch)
                .foregroundStyle(HiveColorToken.nectarText.color)
                .focused($inputFocused)
                .onSubmit(submit)
                .hivePlainFieldChrome(focused: inputFocused)
                .accessibilityLabel("Hive Live prompt")
                .accessibilityHint("Say or type a request. Hello Hive can start a voice request while this surface is open.")
        }
        .padding(14)
        .modifier(HiveGlassShell(level: .popover))
        .overlay(
            RoundedRectangle(cornerRadius: HiveGlassPlacement.popover.cornerRadius, style: .continuous)
                .stroke(visualState.primaryColor.opacity(visualState == .idle ? 0.26 : 0.54), lineWidth: 1)
        )
        .shadow(color: visualState.secondaryColor.opacity(visualState == .idle ? 0.08 : 0.18), radius: 18, x: 0, y: 10)
        .onAppear {
            inputFocused = true
            guard !reduceMotion else { return }
            withAnimation(HiveMotion.breathing) {
                pulse = true
            }
        }
        .onChange(of: spokenSequence) { _, _ in
            speechOutput.speakSwarmResponse(
                text: spokenText,
                selectedVoiceIdentifier: SwarmVoiceSettingsStore.selectedVoiceIdentifier()
            )
        }
        .animation(HiveMotion.focus, value: visualState.rawValue)
        .accessibilityElement(children: .contain)
    }

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSpeak: Bool {
        speechOutput.isSupported && !spokenText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var visualState: HiveLiveAssistantVisualState {
        if speechInput.isRecording { return .listening }
        if isWorking { return .thinking }
        return .idle
    }

    private var currentStatusText: String {
        if speechInput.isRecording {
            return "Listening"
        }
        if speechOutput.isSpeaking {
            return "Speaking"
        }
        let trimmed = statusText.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? visualState.title : trimmed
    }

    private var stateSymbol: HiveSymbolName {
        switch visualState {
        case .idle:
            return .liveAssistant
        case .listening:
            return .voiceNote
        case .thinking:
            return .synthesizing
        }
    }

    private var liveMark: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(visualState.primaryColor.opacity(visualState == .idle ? 0.16 : 0.24))
                .frame(width: 48, height: 48)
            RoundedRectangle(cornerRadius: pulse && visualState != .idle ? 26 : 23, style: .continuous)
                .stroke(visualState.secondaryColor.opacity(visualState == .idle ? 0.28 : 0.74), lineWidth: 1.2)
                .frame(width: pulse && visualState != .idle ? 52 : 46, height: pulse && visualState != .idle ? 52 : 46)
            HiveSymbol(
                stateSymbol,
                size: 21,
                active: visualState != .idle,
                rendering: .monochrome(visualState.secondaryColor),
                motion: visualState == .idle ? .none : .pulse,
                motionValue: pulse ? 1 : 0
            )
        }
        .frame(width: 54, height: 54)
        .accessibilityLabel("Hive Live \(visualState.title)")
    }

    private func submit() {
        let prompt = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        onSubmit(prompt)
    }
}

private struct ChatStarterButton: View {
    var title: String
    var action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Label {
                Text(title)
            } icon: {
                HiveSymbol(.search, size: 13)
            }
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(HiveGlassButtonStyle())
        .controlSize(.large)
        .accessibilityHint("Copies this question into the Ask Hive field.")
    }
}

private struct ChatRow: View {
    var entry: HiveChatEntry
    @State private var appeared = false

    var body: some View {
        VStack(alignment: entry.speaker == .user ? .trailing : .leading, spacing: 8) {
            HiveText(entry.text, role: entry.speaker == .user ? .scaffoldBody : .nectarBody, lineSpacing: 8)
                .frame(maxWidth: .infinity, alignment: entry.speaker == .user ? .trailing : .leading)
            if let note = entry.note, !note.isEmpty, entry.speaker == .hive {
                HiveText(note, role: .scaffoldLabel)
                    .foregroundStyle(HiveColorToken.scaffoldGray.color)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if !entry.citations.isEmpty {
                HStack {
                    ForEach(entry.citations.prefix(4)) { source in
                        Label {
                            Text(source.title)
                        } icon: {
                            HiveSymbol(.indexedOnly, size: 11)
                        }
                            .font(HiveTypography.chromeCaption)
                            .lineLimit(1)
                            .labelStyle(.titleAndIcon)
                            .padding(.vertical, 3)
                            .accessibilityLabel(source.title)
                    }
                }
            }
        }
        .opacity(appeared ? 1 : 0)
        .offset(x: appeared ? 0 : (entry.speaker == .user ? 18 : -18), y: appeared ? 0 : 8)
        .onAppear {
            withAnimation(HiveMotion.panel) {
                appeared = true
            }
        }
    }
}

private struct PulsingAmber: ViewModifier {
    @State private var active = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(active ? 1.035 : 0.975)
            .opacity(active ? 0.92 : 0.62)
            .onAppear {
                withAnimation(HiveMotion.welcome) {
                    active = true
                }
            }
    }
}

public struct HiveStartupSourcePluginSetup: View {
    @Binding private var selections: [HiveStartupSourcePluginSelection]
    @Binding private var pasteLocation: String
    @Binding private var prompt: String
    private var compact: Bool
    private var onToggleChange: ((HiveStartupSourcePluginKind, Bool) -> Void)?
    private var onPasteSubmit: (() -> Void)?
    @State private var pasteError: String?
    @FocusState private var pasteFieldFocused: Bool

    public init(
        selections: Binding<[HiveStartupSourcePluginSelection]>,
        pasteLocation: Binding<String>,
        prompt: Binding<String>,
        compact: Bool = false,
        onToggleChange: ((HiveStartupSourcePluginKind, Bool) -> Void)? = nil,
        onPasteSubmit: (() -> Void)? = nil
    ) {
        self._selections = selections
        self._pasteLocation = pasteLocation
        self._prompt = prompt
        self.compact = compact
        self.onToggleChange = onToggleChange
        self.onPasteSubmit = onPasteSubmit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: compact ? 10 : 14) {
            VStack(alignment: .leading, spacing: 4) {
                HiveText("Source plugins", role: compact ? .scaffoldAction : .nectarCardTitle)
                HiveText("Choose the source, then add it to Field. Hive does not scan anything until you run a capture or pick files.", role: .scaffoldBody)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            LazyVGrid(columns: pluginColumns, alignment: .leading, spacing: 12) {
                ForEach(selections.indices, id: \.self) { index in
                    sourcePluginRow(index: index)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    TextField(HiveStartupSourcePluginCatalog.pasteLocationPlaceholder, text: $pasteLocation)
                        .textFieldStyle(.plain)
                        .font(HiveTypography.chromeSearch)
                        .foregroundStyle(HiveColorToken.nectarText.color)
                        .focused($pasteFieldFocused)
                        .onSubmit(submitPaste)
                        .accessibilityLabel("Location to grab")
                    Button(action: submitPaste) {
                        HiveSymbol(.send, size: 16, active: !pasteLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    .buttonStyle(.plain)
                    .disabled(pasteLocation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Submit pasted source")
                }
                .padding(12)
                .background(HiveColorToken.cellSurface.color.opacity(0.96))
                .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
                if let pasteError {
                    Text(pasteError)
                        .font(HiveTypography.chromeFootnote)
                        .foregroundStyle(HiveColorToken.conflict.color)
                        .transition(.opacity)
                }
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $prompt)
                        .font(HiveTypography.chromeBody)
                        .foregroundStyle(HiveColorToken.nectarText.color)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .frame(minHeight: compact ? 72 : 86)
                        .background(HiveColorToken.cellSurface.color.opacity(0.96))
                        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
                        .accessibilityLabel("Prompt for Hive")
                    if prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HiveText(HiveStartupSourcePluginCatalog.promptPlaceholder, role: .scaffoldBody)
                            .foregroundStyle(HiveColorToken.nectarMuted.color.opacity(0.72))
                            .padding(.top, 18)
                            .padding(.leading, 16)
                            .allowsHitTesting(false)
                    }
                }
            }
            if !compact {
                HiveText("Links and instructions become Field requests. Local paths are imported when they exist.", role: .scaffoldLabel)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onAppear {
            selections = HiveSourcePluginToggleStore.loadSelections()
            pasteFieldFocused = true
        }
    }

    private func submitPaste() {
        let input = pasteLocation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        let type = PasteInputClassifier.classify(input)
        if let required = PasteInputClassifier.requiredPlugin(for: type),
           !HiveSourcePluginToggleStore.isEnabled(required) {
            withAnimation(.easeInOut(duration: 0.15)) {
                pasteError = "\(required.title) plugin is not enabled. Turn it on above to use this source."
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    pasteError = nil
                }
            }
            return
        }
        pasteError = nil
        onPasteSubmit?()
    }

    private var pluginColumns: [GridItem] {
        if compact {
            return [GridItem(.flexible(), spacing: 8)]
        }
        return [
            GridItem(.flexible(minimum: 190), spacing: 8),
            GridItem(.flexible(minimum: 190), spacing: 8)
        ]
    }

    private func sourcePluginRow(index: Int) -> some View {
        let selection = selections[index]
        return Toggle(isOn: Binding(
            get: { selections[index].isEnabled },
            set: { newValue in
                selections[index].isEnabled = newValue
                HiveSourcePluginToggleStore.setEnabled(selection.kind, newValue)
                onToggleChange?(selection.kind, newValue)
            }
        )) {
            HStack(alignment: .top, spacing: 10) {
                HiveSymbol(selection.kind.symbolName, size: 17, active: selection.isEnabled)
                    .frame(width: 24, height: 24)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        HiveText(selection.kind.title, role: .scaffoldAction)
                        if selection.kind == .googleDrive {
                            HiveText("Primary", role: .scaffoldLabel)
                                .foregroundStyle(HiveColorToken.waxAmberBright.color)
                        }
                    }
                    HiveText(selection.kind.summary, role: .scaffoldLabel)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.switch)
        .tint(HiveColorToken.waxAmber.color)
        .padding(10)
        .frame(minHeight: 120, alignment: .topLeading)
        .background(HiveColorToken.raisedSurface.color.opacity(selection.isEnabled ? 0.82 : 0.54))
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        .accessibilityHint(selection.kind.handlesPrivateMaterial ? "Requires explicit permission or a pasted location before Hive reads private material." : "Adds a source type for Field capture.")
    }
}

private extension HiveStartupSourcePluginKind {
    var symbolName: HiveSymbolName {
        switch self {
        case .googleDrive:
            return .cloudSource
        case .webPages:
            return .webLink
        case .uploads:
            return .importAction
        case .localDisk:
            return .localDisk
        case .downloadsFolder:
            return .download
        case .browserHistory:
            return .time
        case .appUsage:
            return .appUsage
        }
    }
}

public struct HiveSettingsSurface: View {
    @Binding private var learningSettings: HiveLearningSettings
    @Binding private var appearanceMode: String
    @Binding private var menuBarExtraVisible: Bool
    @Binding private var menuBarQuickCaptureEnabled: Bool
    public var onClose: () -> Void
    @State private var cloudAPIKeyDraft = ""
    @State private var cloudKeyStatus = "No key saved"
    @State private var sourcePluginRequest = HiveStartupSourcePluginCatalog.load()
    @State private var axisConfirmationMessage: String?
    @State private var swarmVoiceOptions = SwarmVoiceManager().highQualityVoiceOptions()
    @State private var advancedSettingsVisible = false
    @AppStorage(CloudInferenceSettingsStore.enabledKey) private var onlineAskEnabled = false
    @AppStorage(CloudInferenceSettingsStore.providerKey) private var onlineProviderName = "Online helper"
    @AppStorage(CloudInferenceSettingsStore.endpointKey) private var onlineEndpointURL = "https://api.openai.com/v1/responses"
    @AppStorage(CloudInferenceSettingsStore.modelKey) private var onlineModelName = "gpt-4.1-mini"
    @AppStorage(CloudInferenceSettingsStore.requiresPreSendReviewKey) private var onlineAskRequiresReview = true
    @AppStorage(HiveMaintenanceSchedule.enabledKey, store: UserDefaults(suiteName: HiveMaintenanceSchedule.defaultsSuiteName)) private var dailyMaintenanceEnabled = HiveMaintenanceSchedule.defaultEnabled
    @AppStorage(HiveMaintenanceSchedule.hourKey, store: UserDefaults(suiteName: HiveMaintenanceSchedule.defaultsSuiteName)) private var dailyMaintenanceHour = HiveMaintenanceSchedule.defaultHour
    @AppStorage(HiveMaintenanceSchedule.minuteKey, store: UserDefaults(suiteName: HiveMaintenanceSchedule.defaultsSuiteName)) private var dailyMaintenanceMinute = HiveMaintenanceSchedule.defaultMinute
    @AppStorage(GraphAxisVocabulary.topKey) private var axisTop = GraphAxisVocabulary.default.top
    @AppStorage(GraphAxisVocabulary.bottomKey) private var axisBottom = GraphAxisVocabulary.default.bottom
    @AppStorage(GraphAxisVocabulary.rightKey) private var axisRight = GraphAxisVocabulary.default.right
    @AppStorage(GraphAxisVocabulary.leftKey) private var axisLeft = GraphAxisVocabulary.default.left
    @AppStorage(HiveCloudSyncSettingsStore.modeKey) private var iCloudModeRaw = HiveCloudSyncMode.default.rawValue
    @AppStorage(SwarmVoiceSettingsStore.selectedVoiceIdentifierKey) private var selectedSwarmVoiceIdentifier = ""
    @State private var customAutomationGuideVisible = false
    @State private var customAutomationGoal = ""
    @State private var customAutomationSources = ""
    @State private var customAutomationCadence = ""
    @State private var customAutomationFrequency = ""
    @State private var customAutomationTime = ""
    @State private var customAutomationDuration = ""
    @State private var customAutomationOutput = ""
    @State private var automationReadiness = HiveAutomationReadinessReport.current()
    public var attachmentPathDescription: String
    public var sourcePluginStatusText: String
    public var onReplayTutorial: () -> Void
    public var onRunMorningBriefing: () -> Void
    public var onConfigureSourcePlugins: (HiveStartupSourcePluginRequest) -> Void
    public var onChooseSourcePluginFiles: (HiveStartupSourcePluginRequest) -> Void
    public var onChooseBrowserHistory: (HiveStartupSourcePluginRequest) -> Void
    public var onConfirmAxesAndReindex: (GraphAxisVocabulary) -> Void
    public var onAppleAccountChanged: (HiveAuthenticatedAccount?) -> Void
    public var commandAvailability: (HiveCommand) -> HiveCommandAvailability
    public var onCommand: (HiveCommand) -> Void

    public init(
        attachmentPathDescription: String = "Saved article images stay on this Mac.",
        sourcePluginStatusText: String = "",
        learningSettings: Binding<HiveLearningSettings> = .constant(.defaultValue),
        appearanceMode: Binding<String>,
        menuBarExtraVisible: Binding<Bool> = .constant(true),
        menuBarQuickCaptureEnabled: Binding<Bool> = .constant(true),
        onReplayTutorial: @escaping () -> Void = {},
        onRunMorningBriefing: @escaping () -> Void = {},
        onConfigureSourcePlugins: @escaping (HiveStartupSourcePluginRequest) -> Void = { request in
            HiveStartupSourcePluginCatalog.persist(request)
        },
        onChooseSourcePluginFiles: @escaping (HiveStartupSourcePluginRequest) -> Void = { _ in },
        onChooseBrowserHistory: @escaping (HiveStartupSourcePluginRequest) -> Void = { _ in },
        onConfirmAxesAndReindex: @escaping (GraphAxisVocabulary) -> Void = { _ in },
        onAppleAccountChanged: @escaping (HiveAuthenticatedAccount?) -> Void = { _ in },
        commandAvailability: @escaping (HiveCommand) -> HiveCommandAvailability = { HiveCommandAvailability.enabled(for: $0) },
        onCommand: @escaping (HiveCommand) -> Void = { _ in },
        onClose: @escaping () -> Void
    ) {
        self.attachmentPathDescription = attachmentPathDescription
        self.sourcePluginStatusText = sourcePluginStatusText
        self._learningSettings = learningSettings
        self.onReplayTutorial = onReplayTutorial
        self.onRunMorningBriefing = onRunMorningBriefing
        self.onConfigureSourcePlugins = onConfigureSourcePlugins
        self.onChooseSourcePluginFiles = onChooseSourcePluginFiles
        self.onChooseBrowserHistory = onChooseBrowserHistory
        self.onConfirmAxesAndReindex = onConfirmAxesAndReindex
        self.onAppleAccountChanged = onAppleAccountChanged
        self.commandAvailability = commandAvailability
        self.onCommand = onCommand
        self._appearanceMode = appearanceMode
        self._menuBarExtraVisible = menuBarExtraVisible
        self._menuBarQuickCaptureEnabled = menuBarQuickCaptureEnabled
        self.onClose = onClose
    }

    private var connectionAggressionBinding: Binding<Double> {
        Binding(
            get: { learningSettings.connectionAggression },
            set: { learningSettings.connectionAggression = $0 }
        )
    }

    private var sensitiveTopicsBinding: Binding<String> {
        Binding(
            get: { learningSettings.sensitiveTopics },
            set: { learningSettings.sensitiveTopics = $0 }
        )
    }

    private var learnsFromBrowserCapturesBinding: Binding<Bool> {
        Binding(
            get: { learningSettings.learnsFromBrowserCaptures },
            set: { learningSettings.learnsFromBrowserCaptures = $0 }
        )
    }

    private var learnsFromFilesBinding: Binding<Bool> {
        Binding(
            get: { learningSettings.learnsFromFiles },
            set: { learningSettings.learnsFromFiles = $0 }
        )
    }

    private var learnsFromCalendarBinding: Binding<Bool> {
        Binding(
            get: { learningSettings.learnsFromCalendar },
            set: { learningSettings.learnsFromCalendar = $0 }
        )
    }

    public var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                    Text("Hive Settings")
                        .font(HiveTypography.chromeTitle)
                    Text("Set defaults once. Day-to-day work stays in Field, The Colony, and The Hive.")
                        .font(HiveTypography.chromeBody)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                    }
                    Spacer()
                Button("Done", action: onClose)
                    .buttonStyle(HiveGlassButtonStyle(active: true))
                    .tint(HiveColorToken.waxAmber.color)
                        .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 12)

            ScrollView {
            Form {
                Section("Learning") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How aggressively should Hive connect ideas?")
                        Slider(value: connectionAggressionBinding, in: 0...1) {
                            Text("Connection strength")
                        } minimumValueLabel: {
                            Text("Cautious")
                        } maximumValueLabel: {
                            Text("Aggressive")
                        }
                        HStack {
                            Text(learningSettings.connectionAggressionLabel)
                                .font(HiveTypography.chromeFootnoteEmphasized)
                                .foregroundStyle(HiveColorToken.nectarText.color)
                            Spacer()
                            Button {
                                onCommand(.reviewMemory)
                            } label: {
                                HStack(spacing: 6) {
                                    HiveSymbol(.synthesizing, size: 13, active: commandAvailability(.reviewMemory).isEnabled)
                                        .accessibilityHidden(true)
                                    Text("Update The Hive")
                                }
                            }
                            .buttonStyle(HiveGlassButtonStyle(active: commandAvailability(.reviewMemory).isEnabled, compact: true))
                            .disabled(!commandAvailability(.reviewMemory).isEnabled)
                            .accessibilityLabel("Update The Hive")
                            .help("Rebuild current Colony and Hive connections")
                        }
                        Text("New Field items use this automatically.")
                            .font(HiveTypography.chromeFootnote)
                            .foregroundStyle(HiveColorToken.nectarMuted.color)
                    }
                    TextField("Topics Hive should never learn about", text: sensitiveTopicsBinding)
                        .hivePlainFieldChrome(focused: false)
                }

                Section("Automations") {
                    AutomationReadinessCard(
                        report: automationReadiness,
                        onRunNow: {
                            onRunMorningBriefing()
                            refreshAutomationReadiness()
                        }
                    )
                    Toggle("Morning Briefing", isOn: $dailyMaintenanceEnabled)
                        .toggleStyle(.switch)
                        .tint(HiveColorToken.waxAmber.color)
                    Picker("Briefing hour", selection: $dailyMaintenanceHour) {
                        ForEach(0..<24, id: \.self) { hour in
                            Text(Self.hourLabel(hour)).tag(hour)
                        }
                    }
                    .disabled(!dailyMaintenanceEnabled)
                    Picker("Briefing minute", selection: $dailyMaintenanceMinute) {
                        Text(":00").tag(0)
                        Text(":15").tag(15)
                        Text(":30").tag(30)
                        Text(":45").tag(45)
                    }
                    .disabled(!dailyMaintenanceEnabled)
                    Text("Runs locally each morning. Hive gathers approved new sources, reviews Field items from the last 24 hours, checks open actions, updates The Colony and The Hive, then writes a Swarm-only briefing page.")
                        .font(HiveTypography.chromeFootnote)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .fixedSize(horizontal: false, vertical: true)
                    if !automationReadiness.settings.customAutomations.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Saved custom automations")
                                .font(HiveTypography.chromeFootnoteEmphasized)
                                .foregroundStyle(HiveColorToken.nectarText.color)
                            ForEach(automationReadiness.settings.customAutomations) { automation in
                                CustomAutomationSummaryRow(automation: automation)
                            }
                        }
                    }
                    Button {
                        withAnimation(HiveMotion.panel) {
                            customAutomationGuideVisible.toggle()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            HiveSymbol(.runMaintenance, size: 13, active: true)
                            Text("Create Automation")
                        }
                    }
                    .buttonStyle(HiveGlassButtonStyle(active: true))
                    if customAutomationGuideVisible {
                        CustomAutomationGuide(
                            goal: $customAutomationGoal,
                            sources: $customAutomationSources,
                            cadence: $customAutomationCadence,
                            frequency: $customAutomationFrequency,
                            preferredTime: $customAutomationTime,
                            duration: $customAutomationDuration,
                            output: $customAutomationOutput,
                            onCreate: createCustomAutomationRequest
                        )
                    }
                }

                Section("Field") {
                    LabeledContent("Raw source files") {
                        Text(HiveRawSourceRetention.fixedRawFileRetention.label)
                            .font(HiveTypography.chromeFootnoteEmphasized)
                            .foregroundStyle(HiveColorToken.nectarText.color)
                    }
                    Text("Hive keeps copied raw files briefly, then keeps durable extracted memory, citations, and undo history.")
                        .font(HiveTypography.chromeFootnote)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Section("Source Plugins") {
                    HiveStartupSourcePluginSetup(
                        selections: $sourcePluginRequest.selections,
                        pasteLocation: $sourcePluginRequest.pasteLocation,
                        prompt: $sourcePluginRequest.prompt,
                        compact: true,
                        onToggleChange: { kind, enabled in
                            handlePluginToggle(kind: kind, enabled: enabled)
                        },
                        onPasteSubmit: {
                            submitSourcePluginPaste()
                        }
                    )
                    HStack(spacing: 10) {
                        Button("Add to Field") {
                            let request = HiveStartupSourcePluginCatalog.sanitizedRequest(sourcePluginRequest)
                            sourcePluginRequest = request
                            if request.hasBrowserHistoryIntent && !request.hasUserInstruction {
                                onChooseBrowserHistory(request)
                            } else {
                                onConfigureSourcePlugins(request)
                            }
                        }
                        .buttonStyle(HiveGlassButtonStyle(active: sourcePluginRequest.canRunWithoutPicker))
                        .disabled(!sourcePluginRequest.canRunWithoutPicker)
                        Button("Choose Files...") {
                            var request = HiveStartupSourcePluginCatalog.sanitizedRequest(sourcePluginRequest)
                            request.selections = request.selections.map { selection in
                                HiveStartupSourcePluginSelection(kind: selection.kind, isEnabled: selection.kind == .uploads ? true : selection.isEnabled)
                            }
                            sourcePluginRequest = request
                            onChooseSourcePluginFiles(request)
                        }
                        .buttonStyle(HiveGlassButtonStyle(active: true))
                        if sourcePluginRequest.hasBrowserHistoryIntent {
                            Button("Choose Browser History...") {
                                var request = HiveStartupSourcePluginCatalog.sanitizedRequest(sourcePluginRequest)
                                request.selections = request.selections.map { selection in
                                    HiveStartupSourcePluginSelection(kind: selection.kind, isEnabled: selection.kind == .browserHistory ? true : selection.isEnabled)
                                }
                                sourcePluginRequest = request
                                onChooseBrowserHistory(request)
                            }
                            .buttonStyle(HiveGlassButtonStyle(active: true))
                        }
                        Spacer(minLength: 0)
                    }
                    if !sourcePluginStatusText.isEmpty {
                        Text(sourcePluginStatusText)
                            .font(HiveTypography.chromeFootnote)
                            .foregroundStyle(HiveColorToken.nectarMuted.color)
                    }
                }

                Section("Account") {
                    HiveAppleAccountSection(onAccountChanged: onAppleAccountChanged)
                }

                Section("iCloud") {
                    Toggle("Use iCloud for Hive", isOn: iCloudEnabledBinding)
                        .toggleStyle(.switch)
                        .tint(HiveColorToken.waxAmber.color)
                    VStack(alignment: .leading, spacing: 6) {
                        LabeledContent(iCloudStatus.title, value: iCloudEnabled ? "On" : "Off")
                        Text(iCloudStatus.message)
                            .font(HiveTypography.chromeFootnote)
                            .foregroundStyle(HiveColorToken.nectarMuted.color)
                            .fixedSize(horizontal: false, vertical: true)
                        Text("Hive keeps your Field, The Colony, The Hive map, and app state together. Models and temporary work stay on this device.")
                            .font(HiveTypography.chromeFootnote)
                            .foregroundStyle(HiveColorToken.nectarMuted.color)
                            .fixedSize(horizontal: false, vertical: true)
                        if iCloudEnabled {
                            Text(HiveCloudContentPlan().deletionWarning)
                                .font(HiveTypography.chromeFootnote)
                                .foregroundStyle(HiveColorToken.conflict.color)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }

                Section("Ask") {
                    Toggle("Use online Ask when local memory is not enough", isOn: $onlineAskEnabled)
                        .toggleStyle(.switch)
                        .tint(HiveColorToken.waxAmber.color)
                    Toggle("Review before sending Colony context", isOn: $onlineAskRequiresReview)
                        .toggleStyle(.switch)
                        .tint(HiveColorToken.waxAmber.color)
                        .disabled(!onlineAskEnabled)
                    Text("Hive answers from The Colony first. Online Ask stays off-device only after you choose a key and allow the relevant question and Colony context to leave this Mac.")
                        .font(HiveTypography.chromeFootnote)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .fixedSize(horizontal: false, vertical: true)
                    LabeledContent("Helper name") {
                        TextField("Online helper", text: $onlineProviderName)
                            .hivePlainFieldChrome(focused: false)
                    }
                    LabeledContent("API key") {
                        SecureField("Paste key", text: $cloudAPIKeyDraft)
                            .hivePlainFieldChrome(focused: false)
                    }
                    HStack(spacing: 10) {
                        Button("Save Key") {
                            saveOnlineAskKey()
                        }
                        .buttonStyle(HiveGlassButtonStyle(active: !cloudAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                        .disabled(cloudAPIKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        Button("Remove Key") {
                            CloudInferenceKeyStore.delete()
                            cloudAPIKeyDraft = ""
                            refreshOnlineAskKeyStatus()
                        }
                        .buttonStyle(HiveGlassButtonStyle())
                        Spacer()
                        Text(cloudKeyStatus)
                            .font(HiveTypography.chromeFootnoteEmphasized)
                            .foregroundStyle(CloudInferenceKeyStore.hasKey() ? HiveColorToken.sealed.color : HiveColorToken.scaffoldGray.color)
                    }
                    Text("If the service is unavailable, Hive falls back to local memory without blocking the conversation.")
                        .font(HiveTypography.chromeFootnote)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                }

                Section("Swarm Live") {
                    Picker("Voice", selection: $selectedSwarmVoiceIdentifier) {
                        Text("System Voice").tag("")
                        ForEach(swarmVoiceOptions) { option in
                            Text(option.displayName).tag(option.identifier)
                        }
                    }
                    Text(swarmVoiceOptions.isEmpty
                        ? "Hive uses Apple speech output when high-quality English voices are not installed."
                        : "Live Mode uses Apple speech recognition for input and queues short spoken clauses with this on-device voice.")
                        .font(HiveTypography.chromeFootnote)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Starting dictation interrupts Swarm speech immediately.")
                        .font(HiveTypography.chromeFootnote)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                }

                Section("Privacy") {
                    Toggle("Learn from browser captures", isOn: learnsFromBrowserCapturesBinding)
                        .toggleStyle(.switch)
                        .tint(HiveColorToken.waxAmber.color)
                    Toggle("Learn from files", isOn: learnsFromFilesBinding)
                        .toggleStyle(.switch)
                        .tint(HiveColorToken.waxAmber.color)
                    Toggle("Learn from calendar", isOn: learnsFromCalendarBinding)
                        .toggleStyle(.switch)
                        .tint(HiveColorToken.waxAmber.color)
                }

                Section("Menu Bar") {
                    MenuBarPreview(enabled: menuBarExtraVisible)
                    Toggle("Show Hive in the menu bar", isOn: $menuBarExtraVisible)
                        .toggleStyle(.switch)
                        .tint(HiveColorToken.waxAmber.color)
                    Toggle("Show quick capture", isOn: $menuBarQuickCaptureEnabled)
                        .toggleStyle(.switch)
                        .tint(HiveColorToken.waxAmber.color)
                        .disabled(!menuBarExtraVisible)
                    Text("Menu bar controls stay focused on capture, Live, and opening Hive.")
                        .font(HiveTypography.chromeFootnote)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                }

                Section("Appearance") {
                    HiveSettingsSegmentedControl(
                        title: "Appearance",
                        selection: $appearanceMode,
                        options: HiveAppearanceMode.allCases.map { ($0.rawValue, $0.label) }
                    )
                }

                Section("Advanced") {
                    DisclosureGroup("Shortcuts, tools, and axes", isExpanded: $advancedSettingsVisible) {
                        VStack(alignment: .leading, spacing: 18) {
                            advancedSettingsHeading("Command Shortcuts")
                            ForEach(HiveCommand.allCases) { command in
                                CommandShortcutEditorRow(
                                    command: command,
                                    availability: commandAvailability(command),
                                    onRun: { onCommand(command) }
                                )
                            }

                            #if canImport(AppIntents)
                            advancedSettingsHeading("System Shortcuts")
                            ForEach(HiveAppShortcutCatalog.orderedShortcuts.prefix(5), id: \.route) { shortcut in
                                AppShortcutDiscoveryRow(shortcut: shortcut)
                            }
                            #endif

                            advancedSettingsHeading("Files and Links")
                            SettingsCommandActionRow(
                                command: .downloadAttachments,
                                availability: commandAvailability(.downloadAttachments),
                                detail: attachmentPathDescription,
                                action: { onCommand(.downloadAttachments) }
                            )

                            advancedSettingsHeading("Colony Tools")
                            SettingsCommandActionRow(
                                command: .reviewMemory,
                                availability: commandAvailability(.reviewMemory),
                                detail: "Review new sources and propose organized updates.",
                                action: { onCommand(.reviewMemory) }
                            )
                            SettingsCommandActionRow(
                                command: .wiki,
                                availability: commandAvailability(.wiki),
                                detail: "Open the organized pages Hive maintains.",
                                action: { onCommand(.wiki) }
                            )
                            SettingsCommandActionRow(
                                command: .createSlideDeck,
                                availability: commandAvailability(.createSlideDeck),
                                detail: "Build a presentation from the current article.",
                                action: { onCommand(.createSlideDeck) }
                            )
                            LabeledContent("AI status", value: aiStatusLabel)

                            advancedSettingsHeading("First Run Guide")
                            Button("Replay Tutorial", action: onReplayTutorial)
                                .buttonStyle(HiveGlassButtonStyle())

                            advancedSettingsHeading("Hive Axes")
                            Grid(horizontalSpacing: 12, verticalSpacing: 10) {
                                GridRow {
                                    Text("Top")
                                    TextField(GraphAxisVocabulary.default.top, text: $axisTop)
                                        .hivePlainFieldChrome(focused: false)
                                    TextField(GraphAxisVocabulary.default.bottom, text: $axisBottom)
                                        .hivePlainFieldChrome(focused: false)
                                    Text("Bottom")
                                }
                                GridRow {
                                    Text("Left")
                                    TextField(GraphAxisVocabulary.default.left, text: $axisLeft)
                                        .hivePlainFieldChrome(focused: false)
                                    TextField(GraphAxisVocabulary.default.right, text: $axisRight)
                                        .hivePlainFieldChrome(focused: false)
                                    Text("Right")
                                }
                            }
                            .font(HiveTypography.chromeBody)
                            let axisReview = GraphAxisVocabulary(top: axisTop, bottom: axisBottom, right: axisRight, left: axisLeft).review
                            HStack(spacing: 8) {
                                HiveSymbol(axisReview.isApproved ? .confirmed : .conflict, size: 14, active: true)
                                Text(axisConfirmationMessage ?? axisReview.message)
                                    .font(HiveTypography.chromeFootnote)
                            }
                            .foregroundStyle(axisReview.isApproved ? HiveColorToken.sealed.color : HiveColorToken.conflict.color)
                            HStack(spacing: 10) {
                                Button("Confirm and Re-Index") {
                                    confirmAxesAndReindex()
                                }
                                .buttonStyle(HiveGlassButtonStyle(active: axisReview.isApproved))
                                Button("Reset Hive Axes") {
                                    axisTop = GraphAxisVocabulary.default.top
                                    axisBottom = GraphAxisVocabulary.default.bottom
                                    axisRight = GraphAxisVocabulary.default.right
                                    axisLeft = GraphAxisVocabulary.default.left
                                    axisConfirmationMessage = nil
                                }
                                .buttonStyle(HiveGlassButtonStyle())
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .formStyle(.grouped)
            .tint(HiveColorToken.waxAmber.color)
            .accentColor(HiveColorToken.waxAmber.color)
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 14)
            .padding(.bottom, 32)
            }
            .scrollIndicators(.automatic)
        }
        .background(HiveColorToken.backgroundMid.color.opacity(0.98))
        .onAppear {
            refreshOnlineAskKeyStatus()
            refreshSwarmVoiceOptions()
            sourcePluginRequest = HiveStartupSourcePluginRequest(
                selections: HiveSourcePluginToggleStore.loadSelections(),
                pasteLocation: sourcePluginRequest.pasteLocation,
                prompt: sourcePluginRequest.prompt
            )
            refreshAutomationReadiness()
            saveOnlineAskMetadata()
        }
        .onChange(of: sourcePluginRequest) { _, request in
            HiveStartupSourcePluginCatalog.persist(request)
        }
        .onChange(of: onlineAskEnabled) { _, _ in saveOnlineAskMetadata() }
        .onChange(of: onlineProviderName) { _, _ in saveOnlineAskMetadata() }
        .onChange(of: onlineAskRequiresReview) { _, _ in saveOnlineAskMetadata() }
        .onChange(of: selectedSwarmVoiceIdentifier) { _, identifier in
            SwarmVoiceSettingsStore.saveSelectedVoiceIdentifier(identifier)
        }
        .onChange(of: dailyMaintenanceEnabled) { _, _ in persistAutomationSchedule() }
        .onChange(of: dailyMaintenanceHour) { _, _ in persistAutomationSchedule() }
        .onChange(of: dailyMaintenanceMinute) { _, _ in persistAutomationSchedule() }
    }

    private var iCloudEnabled: Bool {
        HiveCloudSyncMode(rawValue: iCloudModeRaw) == .iCloud
    }

    private func advancedSettingsHeading(_ title: String) -> some View {
        Text(title)
            .font(HiveTypography.hiveMeta)
            .foregroundStyle(HiveColorToken.scaffoldFaint.color)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var aiStatusLabel: String {
        if onlineAskEnabled && CloudInferenceKeyStore.hasKey() {
            return MemoryCompilerRuntimeRouter().aiStatusLabel(for: .cloudWithUserKey)
        }
        return MemoryCompilerRuntimeRouter().aiStatusLabel(for: .deterministicLocalRules)
    }

    private var iCloudStatus: HiveCloudSyncStatus {
        HiveCloudSyncStatus.current(settings: HiveCloudSyncSettings(mode: iCloudEnabled ? .iCloud : .localOnly))
    }

    private var iCloudEnabledBinding: Binding<Bool> {
        Binding(
            get: { iCloudEnabled },
            set: { enabled in
                let settings = HiveCloudSyncSettings(mode: enabled ? .iCloud : .localOnly)
                HiveCloudSyncSettingsStore.save(settings)
                iCloudModeRaw = settings.mode.rawValue
            }
        )
    }

    private func handlePluginToggle(kind: HiveStartupSourcePluginKind, enabled: Bool) {
        if !enabled, kind == .uploads {
            #if os(macOS)
            let alert = NSAlert()
            alert.messageText = "Disable Uploads?"
            alert.informativeText = "Disabling Uploads will prevent you from adding local files to Hive."
            alert.addButton(withTitle: "Disable")
            alert.addButton(withTitle: "Cancel")
            if alert.runModal() == .alertSecondButtonReturn {
                updatePluginSelection(kind, enabled: true)
                return
            }
            #endif
        }

        HiveSourcePluginToggleStore.setEnabled(kind, enabled)

        if enabled {
            switch kind {
            case .localDisk, .downloadsFolder:
                #if os(macOS)
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = false
                panel.message = kind == .downloadsFolder
                    ? "Confirm access to Downloads for Hive."
                    : "Choose a folder that Hive can read from."
                panel.begin { response in
                    guard response == .OK, let url = panel.url else {
                        HiveSourcePluginToggleStore.setEnabled(kind, false)
                        updatePluginSelection(kind, enabled: false)
                        return
                    }
                    if let data = try? url.bookmarkData(options: .withSecurityScope) {
                        HiveSourcePluginToggleStore.persistBookmark(data, for: kind)
                    }
                }
                #endif
            case .googleDrive:
                if !GoogleDriveOAuthStore.hasValidTokens {
                    sourcePluginStatusText = "Google Drive enabled. Connect your account in Settings to fetch Drive files."
                }
            default:
                break
            }
        } else {
            HiveSourcePluginToggleStore.clearBookmark(for: kind)
            if kind == .googleDrive {
                GoogleDriveOAuthStore.delete()
            }
        }

        updatePluginSelection(kind, enabled: enabled)
    }

    private func updatePluginSelection(_ kind: HiveStartupSourcePluginKind, enabled: Bool) {
        sourcePluginRequest.selections = sourcePluginRequest.selections.map { selection in
            guard selection.kind == kind else { return selection }
            return HiveStartupSourcePluginSelection(kind: kind, isEnabled: enabled)
        }
        HiveStartupSourcePluginCatalog.persist(sourcePluginRequest)
    }

    private func submitSourcePluginPaste() {
        let request = HiveStartupSourcePluginCatalog.sanitizedRequest(sourcePluginRequest)
        sourcePluginRequest = request
        sourcePluginRequest.pasteLocation = ""
        onClose()
        if request.hasBrowserHistoryIntent && !request.hasUserInstruction {
            onChooseBrowserHistory(request)
        } else {
            onConfigureSourcePlugins(request)
        }
    }

    private func confirmAxesAndReindex() {
        let vocabulary = GraphAxisVocabulary(top: axisTop, bottom: axisBottom, right: axisRight, left: axisLeft)
        let review = vocabulary.review
        guard review.isApproved else {
            axisConfirmationMessage = review.message
            return
        }
        axisTop = vocabulary.top
        axisBottom = vocabulary.bottom
        axisRight = vocabulary.right
        axisLeft = vocabulary.left
        vocabulary.save()
        axisConfirmationMessage = "Axes approved. Re-indexing The Hive."
        onConfirmAxesAndReindex(vocabulary)
    }

    private func saveOnlineAskMetadata() {
        CloudInferenceSettingsStore.saveMetadata(
            enabled: onlineAskEnabled,
            providerName: onlineProviderName,
            endpointURL: onlineEndpointURL,
            modelName: onlineModelName,
            requiresPreSendReview: onlineAskRequiresReview
        )
    }

    private func saveOnlineAskKey() {
        CloudInferenceKeyStore.save(cloudAPIKeyDraft)
        cloudAPIKeyDraft = ""
        refreshOnlineAskKeyStatus()
        saveOnlineAskMetadata()
    }

    private func refreshOnlineAskKeyStatus() {
        cloudKeyStatus = CloudInferenceKeyStore.hasKey() ? "Key saved" : "No key saved"
    }

    private func refreshSwarmVoiceOptions() {
        swarmVoiceOptions = SwarmVoiceManager().highQualityVoiceOptions()
        guard !selectedSwarmVoiceIdentifier.isEmpty else { return }
        if !swarmVoiceOptions.contains(where: { $0.identifier == selectedSwarmVoiceIdentifier }) {
            selectedSwarmVoiceIdentifier = ""
            SwarmVoiceSettingsStore.saveSelectedVoiceIdentifier(nil)
        }
    }

    private static func hourLabel(_ hour: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = 0
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func persistAutomationSchedule() {
        var settings = HiveAutomationSettingsStore.load()
        if dailyMaintenanceEnabled {
            settings.enabledKinds.insert(.morningBriefing)
        } else {
            settings.enabledKinds.remove(.morningBriefing)
        }
        settings.morningBriefingHour = dailyMaintenanceHour
        settings.morningBriefingMinute = dailyMaintenanceMinute
        HiveAutomationSettingsStore.save(settings)
        refreshAutomationReadiness()
    }

    private func refreshAutomationReadiness() {
        automationReadiness = HiveAutomationReadinessReport.current()
    }

    private func createCustomAutomationRequest() {
        let title = customAutomationGoal
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ")
            .prefix(5)
            .joined(separator: " ")
        let prompt = [
            HiveAutomationCatalog.template(for: .custom).promptTemplate,
            "Goal: \(customAutomationGoal)",
            "Sources: \(customAutomationSources)",
            "Frequency: \(customAutomationFrequency)",
            "Preferred time: \(customAutomationTime)",
            "Duration or stop rule: \(customAutomationDuration)",
            "Review policy: \(customAutomationCadence)",
            "Output: \(customAutomationOutput)",
            "Create this as an automation proposal first. Do not mutate The Colony or The Hive until the user confirms."
        ]
        .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .joined(separator: "\n")
        var request = HiveStartupSourcePluginCatalog.load()
        request.prompt = prompt
        request.pasteLocation = ""
        request.selections = request.selections.map { selection in
            HiveStartupSourcePluginSelection(kind: selection.kind, isEnabled: selection.kind == .uploads || selection.isEnabled)
        }
        sourcePluginRequest = request
        var settings = HiveAutomationSettingsStore.load()
        settings.enabledKinds.insert(.custom)
        settings.customAutomations.insert(HiveCustomAutomationDefinition(
            title: title.isEmpty ? "Custom Automation" : title,
            goal: customAutomationGoal,
            sources: customAutomationSources,
            cadence: customAutomationCadence,
            frequency: customAutomationFrequency,
            preferredTime: customAutomationTime,
            duration: customAutomationDuration,
            output: customAutomationOutput
        ), at: 0)
        HiveAutomationSettingsStore.save(settings)
        onConfigureSourcePlugins(request)
        customAutomationGuideVisible = false
        customAutomationGoal = ""
        customAutomationSources = ""
        customAutomationCadence = ""
        customAutomationFrequency = ""
        customAutomationTime = ""
        customAutomationDuration = ""
        customAutomationOutput = ""
        refreshAutomationReadiness()
    }
}

private struct AutomationReadinessCard: View {
    var report: HiveAutomationReadinessReport
    var onRunNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                HiveSymbol(.synthesizing, size: 18, active: report.settings.morningBriefingEnabled)
                    .frame(width: 26, height: 26)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.morningStatusTitle)
                        .font(HiveTypography.chromeFootnoteEmphasized)
                        .foregroundStyle(HiveColorToken.nectarText.color)
                    Text(report.morningStatusDetail)
                        .font(HiveTypography.chromeFootnote)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                Button("Run Now", action: onRunNow)
                    .buttonStyle(HiveGlassButtonStyle(active: report.settings.morningBriefingEnabled, compact: true))
                    .disabled(!report.settings.morningBriefingEnabled)
            }
            HStack(spacing: 14) {
                readinessMetric("Next", value: formatted(report.nextMorningBriefingRun) ?? "Off")
                readinessMetric("Last", value: formatted(report.lastMorningBriefingRun) ?? "Not yet")
                readinessMetric("Custom", value: "\(report.enabledCustomAutomationCount)")
            }
        }
        .padding(12)
        .background(HiveColorToken.raisedSurface.color.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
    }

    private func readinessMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(HiveTypography.hiveMeta)
                .foregroundStyle(HiveColorToken.scaffoldFaint.color)
            Text(value)
                .font(HiveTypography.chromeFootnoteEmphasized)
                .foregroundStyle(HiveColorToken.nectarText.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func formatted(_ date: Date?) -> String? {
        guard let date else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = Calendar.current.isDateInToday(date) ? .none : .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct CustomAutomationSummaryRow: View {
    var automation: HiveCustomAutomationDefinition

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HiveSymbol(.runMaintenance, size: 14, active: automation.isEnabled)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(automation.title)
                    .font(HiveTypography.chromeFootnoteEmphasized)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                Text("\(automation.scheduleSummary) - \(automation.goal)")
                    .font(HiveTypography.chromeFootnote)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
            }
            Spacer(minLength: 10)
            Text(automation.isEnabled ? "On" : "Off")
                .font(HiveTypography.hiveMeta)
                .foregroundStyle(automation.isEnabled ? HiveColorToken.waxAmber.color : HiveColorToken.scaffoldFaint.color)
        }
        .padding(.vertical, 4)
    }
}

private struct CustomAutomationGuide: View {
    @Binding var goal: String
    @Binding var sources: String
    @Binding var cadence: String
    @Binding var frequency: String
    @Binding var preferredTime: String
    @Binding var duration: String
    @Binding var output: String
    var onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Goal", text: $goal)
                .hivePlainFieldChrome(focused: false)
            TextField("Sources Hive may read", text: $sources)
                .hivePlainFieldChrome(focused: false)
            TextField("Frequency", text: $frequency)
                .hivePlainFieldChrome(focused: false)
            TextField("Preferred time", text: $preferredTime)
                .hivePlainFieldChrome(focused: false)
            TextField("Duration or stop rule", text: $duration)
                .hivePlainFieldChrome(focused: false)
            TextField("Review policy", text: $cadence)
                .hivePlainFieldChrome(focused: false)
            TextField("Output page or action", text: $output)
                .hivePlainFieldChrome(focused: false)
            Button("Create Automation Request", action: onCreate)
                .buttonStyle(HiveGlassButtonStyle(active: !goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                .disabled(goal.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.vertical, 6)
    }
}

private struct HiveSettingsSegmentedControl: View {
    var title: String
    @Binding var selection: String
    var options: [(value: String, label: String)]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(HiveTypography.chromeAction)
                .foregroundStyle(HiveColorToken.scaffoldGray.color)
            HStack(spacing: 4) {
                ForEach(options, id: \.value) { option in
                    Button {
                        withAnimation(HiveMotion.standard) {
                            selection = option.value
                        }
                    } label: {
                        Text(option.label)
                            .font(HiveTypography.segmentedOption(selected: selection == option.value))
                            .foregroundStyle(HiveColorToken.nectarText.color)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 34)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(
                        RoundedRectangle(cornerRadius: HiveLayoutMetrics.smallCornerRadius, style: .continuous)
                            .fill(selection == option.value ? HiveColorToken.waxAmber.color.opacity(0.18) : Color.clear)
                    )
                    .accessibilityLabel("\(title), \(option.label)")
                    .accessibilityAddTraits(selection == option.value ? .isSelected : [])
                }
            }
            .padding(4)
            .background(
                RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius, style: .continuous)
                    .fill(HiveColorToken.raisedSurface.color.opacity(0.86))
            )
        }
    }
}

private struct HivePlainFieldChrome: ViewModifier {
    var focused: Bool
    var compact: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .padding(.horizontal, compact ? 8 : 11)
            .frame(minHeight: compact ? 30 : 34)
            .background(
                RoundedRectangle(cornerRadius: compact ? HiveLayoutMetrics.smallCornerRadius : HiveLayoutMetrics.controlCornerRadius, style: .continuous)
                    .fill(HiveColorToken.raisedSurface.color.opacity(0.86))
            )
            .overlay(
                RoundedRectangle(cornerRadius: compact ? HiveLayoutMetrics.smallCornerRadius : HiveLayoutMetrics.controlCornerRadius, style: .continuous)
                    .stroke(focused ? HiveColorToken.waxAmber.color.opacity(0.82) : .clear, lineWidth: focused ? 1.5 : 0)
            )
            .shadow(color: focused ? HiveColorToken.waxAmber.color.opacity(0.1) : .clear, radius: focused ? 8 : 0, x: 0, y: 2)
    }
}

private extension View {
    func hivePlainFieldChrome(focused: Bool, compact: Bool = false) -> some View {
        modifier(HivePlainFieldChrome(focused: focused, compact: compact))
    }
}

#if canImport(AppIntents)
private struct AppShortcutDiscoveryRow: View {
    var shortcut: HiveAppShortcutDescriptor

    var body: some View {
        HStack(spacing: 12) {
            HiveSymbol(HiveSymbolName(rawValue: shortcut.systemImageName) ?? .command, size: 17)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(shortcut.title)
                    .font(HiveTypography.chromeAction)
                Text(shortcut.supportingDialogue)
                    .font(HiveTypography.chromeFootnote)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
            }
            Spacer(minLength: 12)
            Button {
                HiveIntentRequestStore.enqueue(route: shortcut.route)
            } label: {
                HStack(spacing: 6) {
                    HiveSymbol(.send, size: 13)
                        .accessibilityHidden(true)
                    Text(shortcut.phrases.first ?? shortcut.title)
                        .font(HiveTypography.chromeFootnoteEmphasized)
                        .lineLimit(1)
                }
            }
            .buttonStyle(HiveGlassButtonStyle(compact: true))
            .accessibilityLabel("Run \(shortcut.title)")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(shortcut.title). \(shortcut.fullDialogue)")
    }
}
#endif

private struct SettingsCommandActionRow: View {
    var command: HiveCommand
    var availability: HiveCommandAvailability
    var detail: String
    var action: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            HiveSymbol(command.symbolName, size: 17, active: availability.isEnabled)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                Text(command.rawValue)
                    .font(HiveTypography.chromeAction)
                Text(availability.isEnabled ? detail : availability.reason ?? detail)
                    .font(HiveTypography.chromeFootnote)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            Button(action: action) {
                HiveSymbol(.send, size: 14, active: availability.isEnabled)
            }
            .buttonStyle(HiveGlassButtonStyle(active: availability.isEnabled, compact: true))
            .disabled(!availability.isEnabled)
            .accessibilityLabel("Run \(command.rawValue)")
        }
        .opacity(availability.isEnabled ? 1 : 0.64)
    }
}

private struct CommandShortcutEditorRow: View {
    var command: HiveCommand
    var availability: HiveCommandAvailability
    var onRun: () -> Void
    @State private var shortcutText = ""
    @State private var editing = false
    @State private var draftModifiers: Set<HiveShortcutModifier> = [.command]
    @State private var draftKey = ""
    @FocusState private var keyFocused: Bool

    var body: some View {
        HStack(spacing: 12) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text(command.rawValue)
                        .font(HiveTypography.chromeAction)
                    Text(command.description)
                        .font(HiveTypography.chromeFootnote)
                        .foregroundStyle(HiveColorToken.nectarMuted.color)
                        .lineLimit(1)
                }
            } icon: {
                HiveSymbol(command.symbolName, size: 17)
                    .frame(width: 24)
            }

            Spacer(minLength: 12)

            if editing {
                shortcutRecorder
            } else {
                Button {
                    loadDraft(shortcutText)
                    editing = true
                } label: {
                    HStack(spacing: 6) {
                        HiveSymbol(.shortcutRecord, size: 13)
                            .accessibilityHidden(true)
                        ShortcutBadge(shortcutText)
                    }
                }
                .buttonStyle(HiveGlassButtonStyle(compact: true))
                .accessibilityLabel("Change shortcut for \(command.rawValue)")
            }

            Button(action: onRun) {
                HiveSymbol(.send, size: 15, active: availability.isEnabled)
            }
            .buttonStyle(HiveGlassButtonStyle(active: availability.isEnabled, compact: true))
            .disabled(!availability.isEnabled)
            .accessibilityLabel("Run \(command.rawValue)")

            Button {
                HiveCommandShortcutStore.resetShortcut(for: command)
                shortcutText = command.defaultShortcut
                loadDraft(shortcutText)
                editing = false
            } label: {
                HiveSymbol(.shortcutReset, size: 15)
            }
            .buttonStyle(HiveGlassButtonStyle(compact: true))
            .accessibilityLabel("Reset shortcut")
        }
        .onAppear {
            shortcutText = HiveCommandShortcutStore.shortcut(for: command)
            loadDraft(shortcutText)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(command.rawValue), shortcut \(HiveKeyboardShortcut.parse(shortcutText)?.accessibilityLabel ?? shortcutText)")
    }

    private var shortcutRecorder: some View {
        HStack(spacing: 6) {
            ForEach(HiveShortcutModifier.appleDisplayOrder, id: \.self) { modifier in
                ShortcutModifierToggle(
                    modifier: modifier,
                    active: draftModifiers.contains(modifier)
                ) {
                    if draftModifiers.contains(modifier) {
                        draftModifiers.remove(modifier)
                    } else {
                        draftModifiers.insert(modifier)
                    }
                }
            }
            TextField("Key", text: $draftKey)
                .font(HiveTypography.chromeAction)
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .focused($keyFocused)
                .frame(width: 42)
                .onChange(of: draftKey) { _, value in
                    normalizeDraftKey(value)
                }
                .onSubmit { save() }
            Button {
                save()
            } label: {
                HiveSymbol(.confirmed, size: 15, active: true)
            }
            .buttonStyle(HiveGlassButtonStyle(active: canSaveDraft, compact: true))
            .disabled(!canSaveDraft)
            .accessibilityLabel("Save shortcut")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .modifier(HiveGlassShell(level: .button))
        .onAppear { keyFocused = true }
    }

    private var canSaveDraft: Bool {
        HiveKeyboardShortcut(modifiers: draftModifiers, key: draftKey).isComplete
    }

    private func loadDraft(_ value: String) {
        let shortcut = HiveKeyboardShortcut.parse(value) ?? HiveKeyboardShortcut.parse(command.defaultShortcut)
        draftModifiers = shortcut?.modifiers ?? [.command]
        draftKey = shortcut?.key ?? ""
    }

    private func normalizeDraftKey(_ value: String) {
        guard value.count > 1 else {
            draftKey = HiveKeyboardShortcut.normalizedKey(value)
            return
        }
        if value.localizedCaseInsensitiveContains("comma") {
            draftKey = "Comma"
        } else if value.localizedCaseInsensitiveContains("space") {
            draftKey = "Space"
        } else if let last = value.trimmingCharacters(in: .whitespacesAndNewlines).last {
            draftKey = HiveKeyboardShortcut.normalizedKey(String(last))
        }
    }

    private func save() {
        let shortcut = HiveKeyboardShortcut(modifiers: draftModifiers, key: draftKey)
        guard shortcut.isComplete else { return }
        HiveCommandShortcutStore.setShortcut(shortcut.storageValue, for: command)
        shortcutText = HiveCommandShortcutStore.shortcut(for: command)
        loadDraft(shortcutText)
        editing = false
    }
}

private struct ShortcutModifierToggle: View {
    var modifier: HiveShortcutModifier
    var active: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HiveSymbol(modifier.symbolName, size: 13, active: active, rendering: .monochrome(active ? HiveColorToken.waxAmber.color : HiveColorToken.nectarMuted.color))
                .frame(width: 20, height: 20)
        }
        .buttonStyle(HiveGlassButtonStyle(active: active, compact: true))
        .accessibilityLabel("\(active ? "Remove" : "Add") \(modifier.title)")
    }
}

private struct MenuBarPreview: View {
    var enabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: HiveLayoutMetrics.smallCornerRadius, style: .continuous)
                    .fill(enabled ? HiveColorToken.waxAmber.color.opacity(0.16) : HiveColorToken.raisedSurface.color.opacity(0.55))
                HiveMenuBarIcon()
                    .opacity(enabled ? 1 : 0.45)
            }
            .frame(width: 48, height: 34)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 3) {
                HiveText(enabled ? "Menu bar icon is visible" : "Menu bar icon is hidden", role: .scaffoldAction)
                HiveText(enabled ? "Quick capture and status are available without opening the window." : "The main app still works. Turn this on to restore the icon.", role: .scaffoldBody)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(HiveColorToken.cellSurface.color.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

public struct HiveAccessibilityNodeOverlay: View {
    public var nodes: [GraphNodeRecord]
    public var onSelect: (String) -> Void
    private let items: [HiveAccessibilityGraphItem]

    public init(nodes: [GraphNodeRecord], onSelect: @escaping (String) -> Void) {
        self.nodes = nodes
        self.onSelect = onSelect
        self.items = Self.accessibleItems(from: nodes)
    }

    public var body: some View {
        VStack {
            ForEach(items) { item in
                Button(item.title) {
                    onSelect(item.id)
                }
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .accessibilityLabel(item.label)
                .accessibilityValue(item.value)
                .accessibilityHint("Selects this memory and opens its details.")
            }
        }
        .accessibilityElement(children: .contain)
    }

    private static func accessibleItems(from nodes: [GraphNodeRecord]) -> [HiveAccessibilityGraphItem] {
        let anchors = nodes
            .filter { node in
                node.kind != .claim && !isStatementLike(node.title)
            }
            .sorted { lhs, rhs in
                if lhs.memoryLayer != rhs.memoryLayer {
                    return layerRank(lhs.memoryLayer) > layerRank(rhs.memoryLayer)
                }
                if lhs.kind != rhs.kind {
                    return kindRank(lhs.kind) > kindRank(rhs.kind)
                }
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
        return anchors.prefix(72).map { node in
            let model = GraphPresentationModel(node: node)
            let domain = GraphLifeDomainClassifier.domain(for: node).label
            return HiveAccessibilityGraphItem(
                id: node.id,
                title: model.title,
                label: "\(model.title). \(domain) memory.",
                value: "\(layerLabel(for: node.memoryLayer)). \(model.confidenceText)."
            )
        }
    }

    private static func isStatementLike(_ title: String) -> Bool {
        let cleaned = SourcePresentationModel.cleanTitle(title)
        let lower = cleaned.lowercased()
        return cleaned.count > 48
            || lower.hasPrefix("the user ")
            || lower.hasPrefix("user ")
            || lower.hasPrefix("the user's ")
    }

    private static func layerRank(_ layer: MemoryNodeLayer) -> Int {
        switch layer {
        case .definingTrait:
            return 4
        case .importantTrait:
            return 3
        case .connector:
            return 2
        case .detail:
            return 1
        }
    }

    private static func kindRank(_ kind: GraphNodeKind) -> Int {
        switch kind {
        case .project:
            return 5
        case .entity:
            return 4
        case .topic:
            return 3
        case .event, .task, .habit:
            return 2
        case .claim:
            return 1
        case .source, .insight:
            return 0
        }
    }

    private static func layerLabel(for layer: MemoryNodeLayer) -> String {
        switch layer {
        case .detail:
            return "Detail"
        case .connector:
            return "Connection"
        case .importantTrait:
            return "Important"
        case .definingTrait:
            return "Defining"
        }
    }
}

private struct HiveAccessibilityGraphItem: Identifiable {
    var id: String
    var title: String
    var label: String
    var value: String
}
