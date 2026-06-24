import SwiftUI
import HiveCore

private struct HiveHoverFeedbackModifier: ViewModifier {
    @Binding var isHovered: Bool
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        #if os(watchOS)
        content
        #else
        content.onHover { hovering in
            guard !reduceMotion else { return }
            withAnimation(HiveMotion.hoverLift) { isHovered = hovering }
        }
        #endif
    }
}

public enum HiveSymbolName: String, CaseIterable, Identifiable, Sendable {
    case rawInputs = "leaf.fill"
    case wiki = "books.vertical.fill"
    case hiveGraph = "hexagon.fill"
    case chat = "bubble.left.and.bubble.right.fill"
    case liveAssistant = "waveform.circle.fill"
    case settings = "gearshape.fill"
    case sidebar = "sidebar.left"
    case feedHive = "plus.circle.fill"
    case importAction = "square.and.arrow.down.fill"
    case attach = "paperclip"
    case archive = "archivebox.fill"
    case forget = "trash.fill"
    case close = "xmark.circle.fill"
    case search = "magnifyingglass"
    case zoomIn = "plus.magnifyingglass"
    case zoomOut = "minus.magnifyingglass"
    case openWiki = "book.fill"
    case markImportant = "star.fill"
    case unmarkImportant = "star.slash"
    case markIncidental = "minus.circle"
    case recenter = "scope"
    case synthesizing = "sparkles"
    case confirmed = "checkmark.circle.fill"
    case conflict = "exclamationmark.triangle"
    case localOnly = "internaldrive"
    case indexedOnly = "doc.text.magnifyingglass"
    case edit = "pencil.and.outline"
    case send = "paperplane.fill"
    case voiceNote = "mic.fill"
    case speak = "speaker.wave.2"
    case filter = "line.3.horizontal.decrease.circle"
    case quickCapture = "square.and.pencil"
    case screenshot = "camera.viewfinder"
    case download = "arrow.down.doc"
    case showGraph = "hexagon"
    case runMaintenance = "arrow.clockwise"
    case staged = "clock.badge"
    case processing = "arrow.triangle.2.circlepath"
    case processNow = "bolt.fill"
    case previewSource = "eye.fill"
    case rawSourcesSheet = "doc.on.doc"
    case status = "circle.fill"
    case time = "clock"
    case explain = "info.circle.fill"
    case ellipsis = "ellipsis.circle"
    case merge = "arrow.triangle.merge"
    case inspect = "magnifyingglass.circle"
    case command = "command"
    case shortcutOption = "option"
    case shortcutShift = "shift"
    case shortcutControl = "control"
    case shortcutReset = "arrow.counterclockwise"
    case shortcutRecord = "keyboard"
    case select = "checkmark.circle"
    case unselected = "circle"
    case appleAccount = "apple.logo"
    case googleAccount = "person.crop.circle.badge.checkmark"
    case signOut = "rectangle.portrait.and.arrow.right"
    case sourcePlugins = "slider.horizontal.3"
    case webLink = "link"
    case localDisk = "externaldrive.fill"
    case cloudSource = "cloud"
    case appUsage = "macwindow.on.rectangle"
    case presentation = "rectangle.on.rectangle.angled"
    case disclosure = "chevron.down"

    public var id: String { rawValue }

    public var accessibilityTitle: String {
        switch self {
        case .rawInputs:
            return "Field"
        case .wiki:
            return "The Colony"
        case .hiveGraph:
            return "The Hive"
        case .chat:
            return "Chat"
        case .liveAssistant:
            return "Hive Live"
        case .settings:
            return "Settings"
        case .sidebar:
            return "Navigator"
        case .feedHive:
            return "Feed Hive"
        case .importAction:
            return "Import"
        case .attach:
            return "Attach"
        case .archive:
            return "Archive"
        case .forget:
            return "Forget"
        case .close:
            return "Close"
        case .search:
            return "Search"
        case .zoomIn:
            return "Zoom In"
        case .zoomOut:
            return "Zoom Out"
        case .openWiki:
            return "Open The Colony"
        case .markImportant:
            return "Mark Important"
        case .unmarkImportant:
            return "Unmark Important"
        case .markIncidental:
            return "Mark Incidental"
        case .recenter:
            return "Recenter"
        case .synthesizing:
            return "Synthesizing"
        case .confirmed:
            return "Confirmed"
        case .conflict:
            return "Conflict"
        case .localOnly:
            return "Local Only"
        case .indexedOnly:
            return "Indexed Memory Only"
        case .edit:
            return "Edit"
        case .send:
            return "Send"
        case .voiceNote:
            return "Voice Note"
        case .speak:
            return "Speak"
        case .filter:
            return "Filter"
        case .quickCapture:
            return "Quick Capture"
        case .screenshot:
            return "Capture Current Page"
        case .download:
            return "Download Attachments"
        case .showGraph:
            return "Show in The Hive"
        case .runMaintenance:
            return "Refresh"
        case .staged:
            return "Staged"
        case .processing:
            return "Processing"
        case .processNow:
            return "Process Now"
        case .previewSource:
            return "Preview Source"
        case .rawSourcesSheet:
            return "Raw Sources"
        case .status:
            return "Status"
        case .time:
            return "Time"
        case .explain:
            return "Explain"
        case .ellipsis:
            return "More"
        case .merge:
            return "Merge"
        case .inspect:
            return "Inspect"
        case .command:
            return "Command"
        case .shortcutOption:
            return "Option"
        case .shortcutShift:
            return "Shift"
        case .shortcutControl:
            return "Control"
        case .shortcutReset:
            return "Reset Shortcut"
        case .shortcutRecord:
            return "Record Shortcut"
        case .select:
            return "Selected"
        case .unselected:
            return "Not Selected"
        case .appleAccount:
            return "Apple Account"
        case .googleAccount:
            return "Google Account"
        case .signOut:
            return "Sign Out of Hive"
        case .sourcePlugins:
            return "Source Plugins"
        case .webLink:
            return "Link"
        case .localDisk:
            return "Local Disk"
        case .cloudSource:
            return "Cloud Source"
        case .appUsage:
            return "Apps"
        case .presentation:
            return "Slide Deck"
        case .disclosure:
            return "Open Menu"
        }
    }

    public static func sourceStatus(_ status: OrganicProcessingState) -> HiveSymbolName {
        switch status {
        case .confused:
            return .conflict
        case .foraging:
            return .runMaintenance
        case .digesting:
            return .indexedOnly
        case .synthesizing:
            return .synthesizing
        case .understood:
            return .confirmed
        case .resting:
            return .status
        }
    }

    public static func organismState(_ state: HiveOrganismState) -> HiveSymbolName {
        switch state {
        case .confused:
            return .conflict
        case .foraging:
            return .runMaintenance
        case .digesting:
            return .indexedOnly
        case .synthesizing:
            return .synthesizing
        case .understood:
            return .confirmed
        case .resting:
            return .status
        }
    }
}

public enum HiveSymbolRendering: Sendable {
    case hierarchical
    case palette(primary: Color, secondary: Color)
    case monochrome(Color)
    case primaryAction
}

public enum HiveSymbolMotion: String, CaseIterable, Sendable {
    case none
    case bounce
    case pulse
    case variableColor
    case replace
    case scale

    public var respectsReducedMotion: Bool { true }
}

public struct HiveSymbol: View {
    public var name: HiveSymbolName
    public var size: CGFloat
    public var weight: Font.Weight
    public var active: Bool
    public var rendering: HiveSymbolRendering
    public var motion: HiveSymbolMotion
    public var motionValue: Int
    public var accessibilityLabel: String

    public init(
        _ name: HiveSymbolName,
        size: CGFloat = 16,
        weight: Font.Weight = .semibold,
        active: Bool = false,
        rendering: HiveSymbolRendering = .hierarchical,
        motion: HiveSymbolMotion = .none,
        motionValue: Int = 0,
        accessibilityLabel: String? = nil
    ) {
        self.name = name
        self.size = size
        self.weight = weight
        self.active = active
        self.rendering = rendering
        self.motion = motion
        self.motionValue = motionValue
        self.accessibilityLabel = accessibilityLabel ?? name.accessibilityTitle
    }

    public var body: some View {
        baseImage
            .modifier(HiveSymbolRenderingModifier(rendering: rendering, active: active))
            .modifier(HiveSymbolMotionModifier(motion: motion, value: motionValue))
            .accessibilityLabel(accessibilityLabel)
    }

    private var baseImage: some View {
        Image(systemName: name.rawValue)
            .font(.system(size: size, weight: weight, design: .default))
            .imageScale(.medium)
    }
}

public struct HiveSymbolStatusMark: View {
    public var symbol: HiveSymbolName
    public var color: Color
    public var size: CGFloat
    public var label: String

    public init(
        _ symbol: HiveSymbolName,
        color: Color,
        size: CGFloat = 9,
        label: String? = nil
    ) {
        self.symbol = symbol
        self.color = color
        self.size = size
        self.label = label ?? symbol.accessibilityTitle
    }

    public var body: some View {
        HiveSymbol(
            symbol,
            size: size,
            weight: .semibold,
            active: true,
            rendering: .monochrome(color),
            accessibilityLabel: label
        )
        .frame(width: max(12, size + 4), height: max(12, size + 4))
    }
}

private struct HiveSymbolRenderingModifier: ViewModifier {
    var rendering: HiveSymbolRendering
    var active: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        switch rendering {
        case .hierarchical:
            content
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(active ? HiveColorToken.waxAmberBright.color : HiveColorToken.scaffoldGray.color)
        case .palette(let primary, let secondary):
            content
                .symbolRenderingMode(.palette)
                .foregroundStyle(primary, secondary)
        case .monochrome(let color):
            content
                .symbolRenderingMode(.monochrome)
                .foregroundStyle(color)
        case .primaryAction:
            content
                .symbolRenderingMode(.palette)
                .foregroundStyle(HiveColorToken.waxAmberBright.color, HiveColorToken.waxAmberDeep.color)
        }
    }
}

private struct HiveSymbolMotionModifier: ViewModifier {
    var motion: HiveSymbolMotion
    var value: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ViewBuilder
    func body(content: Content) -> some View {
        if reduceMotion || motion == .none {
            content
        } else {
            switch motion {
            case .none:
                content
            case .bounce:
                content
                    .scaleEffect(value.isMultiple(of: 2) ? 1 : 1.045)
            case .pulse:
                content
                    .opacity(value.isMultiple(of: 2) ? 1 : 0.78)
            case .variableColor:
                content
                    .scaleEffect(value.isMultiple(of: 2) ? 1 : 1.035)
            case .replace:
                content
                    .contentTransition(.opacity)
            case .scale:
                content
                    .scaleEffect(value.isMultiple(of: 2) ? 1 : 1.08)
            }
        }
    }
}

public struct HiveSymbolButton: View {
    public var symbol: HiveSymbolName
    public var title: String?
    public var active: Bool
    public var destructive: Bool
    public var motion: HiveSymbolMotion
    public var motionValue: Int
    public var compact: Bool
    public var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    public init(
        _ symbol: HiveSymbolName,
        title: String? = nil,
        active: Bool = false,
        destructive: Bool = false,
        motion: HiveSymbolMotion = .none,
        motionValue: Int = 0,
        compact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.title = title
        self.active = active
        self.destructive = destructive
        self.motion = motion
        self.motionValue = motionValue
        self.compact = compact
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HiveLiquidGlassSurface(placement: .button) {
                HStack(spacing: title == nil ? 0 : 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: HiveLayoutMetrics.smallCornerRadius, style: .continuous)
                            .fill(iconBackgroundColor)
                        HiveSymbol(
                            symbol,
                            size: compact ? 16 : 18,
                            active: active,
                            rendering: rendering,
                            motion: motion,
                            motionValue: motionValue
                        )
                    }
                    .frame(width: compact ? 24 : 28, height: compact ? 24 : 28)
                    if let title {
                        HiveText(title, role: active ? .scaffoldAction : .scaffoldBody)
                            .lineLimit(1)
                    }
                }
                .padding(.vertical, compact ? 6 : 8)
                .padding(.horizontal, title == nil ? (compact ? 6 : 8) : (compact ? 10 : 12))
                .frame(
                    minWidth: HiveHIGPolicy.targetSize(compact: compact),
                    minHeight: HiveHIGPolicy.targetSize(compact: compact)
                )
                .foregroundStyle(foregroundColor)
                .background(stateOverlay)
            }
            .overlay(
                RoundedRectangle(cornerRadius: HiveGlassPlacement.button.cornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .contentShape(Rectangle())
            .shadow(
                color: shadowColor,
                radius: isHovered || active ? 12 : 3,
                x: 0,
                y: isHovered || active ? 5 : 1
            )
        }
        .buttonStyle(HiveControlPressStyle())
        .scaleEffect(reduceMotion ? 1 : (isHovered ? 1.045 : 1))
        .offset(y: reduceMotion ? 0 : (isHovered ? -1 : 0))
        .help(title ?? symbol.accessibilityTitle)
        .accessibilityLabel(title ?? symbol.accessibilityTitle)
        .accessibilityHint(HiveHIGPolicy.accessibilityHint(for: title ?? symbol.accessibilityTitle))
        .accessibilityAddTraits(.isButton)
        .modifier(HiveHoverFeedbackModifier(isHovered: $isHovered, reduceMotion: reduceMotion))
    }

    private var rendering: HiveSymbolRendering {
        if destructive {
            return .palette(primary: HiveColorToken.conflict.color, secondary: HiveColorToken.waxAmberDeep.color)
        }
        if active {
            return .primaryAction
        }
        return .hierarchical
    }

    private var foregroundColor: Color {
        if destructive {
            return HiveColorToken.conflict.color
        }
        if active {
            return HiveColorToken.waxAmberBright.color
        }
        return HiveColorToken.nectarText.color
    }

    private var stateOverlay: Color {
        if destructive {
            return HiveColorToken.conflict.color.opacity(isHovered ? 0.16 : 0.1)
        }
        if active {
            return HiveColorToken.waxAmber.color.opacity(isHovered ? 0.24 : 0.16)
        }
        return HiveColorToken.nectarText.color.opacity(isHovered ? 0.055 : 0.025)
    }

    private var iconBackgroundColor: Color {
        if destructive {
            return HiveColorToken.conflict.color.opacity(isHovered ? 0.26 : 0.18)
        }
        if active {
            return HiveColorToken.waxAmber.color.opacity(isHovered ? 0.3 : 0.22)
        }
        return HiveColorToken.nectarText.color.opacity(isHovered ? 0.07 : 0.0)
    }

    private var borderColor: Color {
        if destructive {
            return HiveColorToken.conflict.color.opacity(isHovered ? 0.6 : 0.42)
        }
        if active {
            return HiveColorToken.waxAmber.color.opacity(isHovered ? 0.42 : 0.28)
        }
        return isHovered ? HiveColorToken.scaffoldFaint.color.opacity(0.16) : .clear
    }

    private var borderWidth: CGFloat {
        (!active && !destructive && !isHovered) ? 0 : 1
    }

    private var shadowColor: Color {
        if destructive {
            return HiveColorToken.conflict.color.opacity(0.16)
        }
        if active {
            return HiveColorToken.waxAmberDeep.color.opacity(0.18)
        }
        return HiveColorToken.backgroundDeep.color.opacity(0.08)
    }
}

public enum HiveMenuBarIconState: Sendable {
    case active
    case paused
}

public struct HiveMenuBarIcon: View {
    public var state: HiveMenuBarIconState

    public init(state: HiveMenuBarIconState = .active) {
        self.state = state
    }

    public var body: some View {
        HiveSymbol(
            state == .active ? .hiveGraph : .quickCapture,
            size: 17,
            weight: .bold,
            active: true,
            rendering: .monochrome(state == .active ? .white : HiveColorToken.nectarMuted.color),
            accessibilityLabel: "Hive"
        )
        .frame(width: 30, height: 20)
        .shadow(color: .black.opacity(0.28), radius: 1.5, x: 0, y: 0.5)
        .frame(width: 34, height: 24)
        .accessibilityLabel("Hive")
    }
}

public struct HiveAskAboutBox: View {
    public var title: String
    public var placeholder: String
    public var onSubmit: (String) -> Void
    @State private var draft = ""
    @StateObject private var speechInput = HiveSpeechInputController()
    @FocusState private var focused: Bool

    public init(
        title: String = "Ask about this",
        placeholder: String = "Ask what changed, why it matters, or what to do next",
        onSubmit: @escaping (String) -> Void
    ) {
        self.title = title
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HiveText(title, role: .scaffoldLabel)
            HStack(spacing: 8) {
                TextField(placeholder, text: $draft)
                    .textFieldStyle(.plain)
                    .font(HiveTypography.chromeSearch)
                    .foregroundStyle(HiveColorToken.nectarText.color)
                    .focused($focused)
                    .onSubmit(submit)
                HiveSpeechInputButton(speechInput: speechInput, text: $draft, compact: true)
                HiveSymbolButton(.send, title: nil, active: canSubmit, compact: true, action: submit)
                    .disabled(!canSubmit)
                    .opacity(canSubmit ? 1 : 0.55)
            }
            .padding(.vertical, 8)
            .padding(.leading, 12)
            .padding(.trailing, 8)
            .background(HiveColorToken.raisedSurface.color)
            .clipShape(RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous))
            if speechInput.shouldShowStatus {
                HiveText(speechInput.statusText, role: .scaffoldBody)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(title)
    }

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        let question = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else { return }
        draft = ""
        onSubmit(question)
    }
}

public struct HiveToolbarIconButton: View {
    public var symbol: HiveSymbolName
    public var title: String?
    public var accessibilityLabel: String
    public var active: Bool
    public var action: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    public init(
        _ symbol: HiveSymbolName,
        title: String? = nil,
        accessibilityLabel: String? = nil,
        active: Bool = false,
        action: @escaping () -> Void
    ) {
        self.symbol = symbol
        self.title = title
        self.accessibilityLabel = accessibilityLabel ?? symbol.accessibilityTitle
        self.active = active
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: title == nil ? 0 : 7) {
                HiveSymbol(symbol, size: 18, active: active || isHovered)
                    .frame(width: 24, height: 26)
                if let title {
                    Text(title)
                        .font(HiveTypography.chromeAction)
                        .lineLimit(1)
                        .minimumScaleFactor(0.94)
                        .fixedSize(horizontal: true, vertical: false)
                }
            }
            .padding(.horizontal, title == nil ? 9 : 12)
            .frame(minWidth: HiveHIGPolicy.minimumMacControlTarget, minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius, style: .continuous)
                    .fill(toolbarFill)
            )
            .contentShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.controlCornerRadius, style: .continuous))
        }
        .buttonStyle(HiveControlPressStyle())
        .scaleEffect(reduceMotion ? 1 : (isHovered ? 1.035 : 1))
        .offset(y: reduceMotion ? 0 : (isHovered ? -1 : 0))
        .foregroundStyle(active ? HiveColorToken.waxAmberBright.color : HiveColorToken.nectarText.color)
        .controlSize(.regular)
        .help(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(HiveHIGPolicy.accessibilityHint(for: accessibilityLabel))
        .modifier(HiveHoverFeedbackModifier(isHovered: $isHovered, reduceMotion: reduceMotion))
    }

    private var toolbarFill: Color {
        if active {
            return HiveColorToken.waxAmber.color.opacity(isHovered ? 0.22 : 0.15)
        }
        return HiveColorToken.nectarText.color.opacity(isHovered ? 0.075 : 0.0)
    }
}

public struct HiveContextAskSurface<Supplemental: View>: View {
    public var title: String
    public var placeholder: String
    public var onSubmit: (String) -> Void
    public var supplemental: Supplemental

    public init(
        title: String = "Ask about this",
        placeholder: String = "Ask what changed, why it matters, or what to do next",
        onSubmit: @escaping (String) -> Void,
        @ViewBuilder supplemental: () -> Supplemental
    ) {
        self.title = title
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.supplemental = supplemental()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HiveAskAboutBox(
                title: title,
                placeholder: placeholder,
                onSubmit: onSubmit
            )
            supplemental
        }
        .accessibilityElement(children: .contain)
    }
}

public extension HiveContextAskSurface where Supplemental == EmptyView {
    init(
        title: String = "Ask about this",
        placeholder: String = "Ask what changed, why it matters, or what to do next",
        onSubmit: @escaping (String) -> Void
    ) {
        self.init(
            title: title,
            placeholder: placeholder,
            onSubmit: onSubmit,
            supplemental: { EmptyView() }
        )
    }
}

public struct HiveContextTip: View {
    public var title: String
    public var message: String
    public var symbol: HiveSymbolName
    public var onDismiss: () -> Void

    public init(
        title: String,
        message: String,
        symbol: HiveSymbolName,
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.symbol = symbol
        self.onDismiss = onDismiss
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 9) {
                HiveSymbol(symbol, size: 16, active: true, rendering: .hierarchical)
                    .frame(width: 22, height: 22)
                    .accessibilityHidden(true)
                HiveText(title, role: .scaffoldLabel)
                Spacer(minLength: 8)
                HiveSymbolButton(.close, title: "Dismiss tip", compact: true, action: onDismiss)
            }
            HiveText(message, role: .nectarBody, lineSpacing: 5)
                .foregroundStyle(HiveColorToken.nectarMuted.color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 12)
        .padding(.leading, 14)
        .padding(.trailing, 10)
        .background(HiveColorToken.raisedSurface.color.opacity(0.74))
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("\(title). \(message)")
    }
}

public enum HiveGlassPlacement: String, CaseIterable, Sendable {
    case button
    case navigation
    case toolbar
    case search
    case commandPalette
    case chatSheet
    case inspector
    case popover
    case modal

    public var cornerRadius: CGFloat {
        switch self {
        case .button:
            return HiveLayoutMetrics.controlCornerRadius
        case .navigation:
            return 0
        case .toolbar, .search:
            return HiveLayoutMetrics.rowCornerRadius
        case .popover, .chatSheet:
            return HiveLayoutMetrics.surfaceCornerRadius
        case .inspector:
            return HiveLayoutMetrics.prominentSurfaceCornerRadius
        case .commandPalette, .modal:
            return HiveLayoutMetrics.surfaceCornerRadius
        }
    }

    var solidFill: Color {
        switch self {
        case .button:
            return HiveColorToken.cellSurface.color
        case .toolbar, .search:
            return HiveColorToken.cellSurface.color
        case .navigation:
            return HiveColorToken.backgroundMid.color
        case .commandPalette, .modal:
            return HiveColorToken.raisedSurface.color
        case .chatSheet, .popover:
            return HiveColorToken.cellSurface.color
        case .inspector:
            return HiveColorToken.raisedSurface.color
        }
    }

    var shadowRadius: CGFloat {
        switch self {
        case .button:
            return 7
        case .toolbar, .search:
            return 4
        case .navigation:
            return 0
        case .chatSheet, .popover:
            return 12
        case .commandPalette, .modal:
            return 16
        case .inspector:
            return 18
        }
    }

    var shadowYOffset: CGFloat {
        switch self {
        case .button:
            return 2
        case .toolbar, .search:
            return 2
        case .navigation:
            return 0
        case .chatSheet, .popover:
            return 8
        case .commandPalette, .modal:
            return 10
        case .inspector:
            return 12
        }
    }

    var surfaceWarmthOpacity: Double {
        switch self {
        case .navigation:
            return 0.03
        case .button, .toolbar, .search:
            return 0.05
        case .chatSheet, .popover:
            return 0.07
        case .commandPalette, .modal, .inspector:
            return 0.08
        }
    }

    var surfaceAmberOpacity: Double {
        switch self {
        case .navigation:
            return 0.02
        case .button, .toolbar, .search:
            return 0.035
        case .chatSheet, .popover:
            return 0.045
        case .commandPalette, .modal, .inspector:
            return 0.055
        }
    }

    var powerShadowOpacity: Double {
        switch self {
        case .navigation:
            return 0
        case .button, .toolbar, .search:
            return 0.18
        case .chatSheet, .popover:
            return 0.24
        case .commandPalette, .modal, .inspector:
            return 0.28
        }
    }

    var warmUnderglowOpacity: Double {
        switch self {
        case .navigation:
            return 0
        case .button, .toolbar, .search:
            return 0.055
        case .chatSheet, .popover:
            return 0.07
        case .commandPalette, .modal, .inspector:
            return 0.085
        }
    }

    var surfaceLayerRole: HiveSurfaceLayerRole {
        switch self {
        case .button:
            return .button
        case .navigation:
            return .navigation
        case .toolbar:
            return .toolbar
        case .search:
            return .search
        case .commandPalette:
            return .commandPalette
        case .chatSheet:
            return .chatSheet
        case .inspector:
            return .inspector
        case .popover:
            return .popover
        case .modal:
            return .modal
        }
    }
}

public typealias HiveGlassLevel = HiveGlassPlacement

public struct HiveGlassPolicy: Sendable {
    public var placement: HiveGlassPlacement
    public var reduceTransparency: Bool
    public var reduceMotion: Bool
    public var colorSchemeContrast: ColorSchemeContrast

    public init(
        placement: HiveGlassPlacement,
        reduceTransparency: Bool,
        reduceMotion: Bool,
        colorSchemeContrast: ColorSchemeContrast
    ) {
        self.placement = placement
        self.reduceTransparency = reduceTransparency
        self.reduceMotion = reduceMotion
        self.colorSchemeContrast = colorSchemeContrast
    }

    public var usesSystemGlass: Bool {
        false
    }

    public var usesInteractiveGlass: Bool {
        false
    }

    public var fallbackFill: Color {
        colorSchemeContrast == .increased ? HiveColorToken.backgroundDeep.color : placement.solidFill
    }

    public var fallbackStroke: Color {
        if placement == .navigation {
            return .clear
        }
        return colorSchemeContrast == .increased
            ? HiveColorToken.nectarText.color.opacity(0.36)
            : HiveColorToken.scaffoldFaint.color.opacity(0.32)
    }
}

public struct HiveLiquidGlassSurface<Content: View>: View {
    public var placement: HiveGlassPlacement
    public var content: Content
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.colorScheme) private var colorScheme

    public init(placement: HiveGlassPlacement = .popover, @ViewBuilder content: () -> Content) {
        self.placement = placement
        self.content = content()
    }

    public var body: some View {
        let policy = HiveGlassPolicy(
            placement: placement,
            reduceTransparency: reduceTransparency,
            reduceMotion: reduceMotion,
            colorSchemeContrast: colorSchemeContrast
        )
        return solidSurfaceBody(policy: policy)
            .clipShape(shape)
            .shadow(
                color: HiveColorToken.backgroundDeep.color.opacity(placement.powerShadowOpacity),
                radius: placement.shadowRadius,
                x: 0,
                y: placement.shadowYOffset
            )
            .shadow(
                color: HiveColorToken.waxAmberDeep.color.opacity(placement.warmUnderglowOpacity),
                radius: placement.shadowRadius * 0.55,
                x: 0,
                y: max(1, placement.shadowYOffset / 2)
            )
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: placement.cornerRadius, style: .continuous)
    }

    private func solidSurfaceBody(policy: HiveGlassPolicy) -> some View {
        content
            .background {
                shape
                    .fill(policy.fallbackFill)
                    .overlay(shape.fill(warmSurfaceGradient))
                    .overlay(shape.fill(amberSurfaceDepth))
                    .overlay(shape.stroke(policy.fallbackStroke, lineWidth: 1))
            }
    }

    private var warmSurfaceGradient: LinearGradient {
        LinearGradient(
            colors: [
                HiveAmbientPalette.honeyHighlight(for: colorScheme).opacity(placement.surfaceWarmthOpacity),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var amberSurfaceDepth: LinearGradient {
        LinearGradient(
            colors: [
                Color.clear,
                HiveAmbientPalette.honeyAmber(for: colorScheme).opacity(placement.surfaceAmberOpacity)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

public struct HiveGlassButtonStyle: ButtonStyle {
    public var active: Bool
    public var destructive: Bool
    public var compact: Bool

    public init(active: Bool = false, destructive: Bool = false, compact: Bool = false) {
        self.active = active
        self.destructive = destructive
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        HiveLiquidGlassSurface(placement: .button) {
            configuration.label
                .font(compact ? HiveTypography.chromeCaption : HiveTypography.chromeAction)
                .foregroundStyle(foregroundColor)
                .padding(.horizontal, compact ? 9 : 12)
                .padding(.vertical, compact ? 6 : 8)
                .frame(minHeight: HiveHIGPolicy.targetSize(compact: compact))
                .background(stateOverlay(configuration: configuration))
                .contentShape(Rectangle())
        }
        .scaleEffect(configuration.isPressed ? 0.985 : 1)
        .opacity(configuration.isPressed ? 0.9 : 1)
        .animation(HiveMotion.focus, value: configuration.isPressed)
    }

    private var foregroundColor: Color {
        if destructive {
            return HiveColorToken.conflict.color
        }
        if active {
            return HiveColorToken.waxAmberBright.color
        }
        return HiveColorToken.nectarText.color
    }

    private func stateOverlay(configuration: Configuration) -> Color {
        if destructive {
            return HiveColorToken.conflict.color.opacity(configuration.isPressed ? 0.2 : 0.12)
        }
        if active {
            return HiveColorToken.waxAmber.color.opacity(configuration.isPressed ? 0.25 : 0.17)
        }
        return HiveColorToken.nectarText.color.opacity(configuration.isPressed ? 0.08 : 0.025)
    }

}

public struct HiveSolidButtonStyle: ButtonStyle {
    public var active: Bool
    public var compact: Bool

    public init(active: Bool = false, compact: Bool = false) {
        self.active = active
        self.compact = compact
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? HiveTypography.chromeCaption : HiveTypography.chromeAction)
            .foregroundStyle(active ? HiveColorToken.waxAmberBright.color : HiveColorToken.nectarText.color)
            .padding(.horizontal, compact ? 9 : 12)
            .padding(.vertical, compact ? 6 : 8)
            .frame(minHeight: HiveHIGPolicy.targetSize(compact: compact))
            .background(
                RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous)
                    .fill(backgroundColor(configuration: configuration))
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous)
                    .stroke(borderColor, lineWidth: borderWidth)
            )
            .scaleEffect(configuration.isPressed ? 0.992 : 1)
            .animation(HiveMotion.focus, value: configuration.isPressed)
    }

    private func backgroundColor(configuration: Configuration) -> Color {
        if active {
            return HiveColorToken.waxAmberDeep.color.opacity(configuration.isPressed ? 0.24 : 0.18)
        }
        return HiveColorToken.raisedSurface.color.opacity(configuration.isPressed ? 0.9 : 0.72)
    }

    private var borderColor: Color {
        active ? HiveColorToken.waxAmber.color.opacity(0.46) : HiveColorToken.scaffoldFaint.color.opacity(0.24)
    }

    private var borderWidth: CGFloat {
        active ? 1 : 0
    }
}

public struct HiveGlassSurface<Content: View>: View {
    public var level: HiveGlassLevel
    public var content: Content

    public init(level: HiveGlassLevel = .popover, @ViewBuilder content: () -> Content) {
        self.level = level
        self.content = content()
    }

    public var body: some View {
        HiveLiquidGlassSurface(placement: level) {
            content
        }
    }
}

public struct HiveGlassShell: ViewModifier {
    public var level: HiveGlassLevel

    public init(level: HiveGlassLevel = .popover) {
        self.level = level
    }

    public func body(content: Content) -> some View {
        HiveLiquidGlassSurface(placement: level) {
            content
        }
    }
}
