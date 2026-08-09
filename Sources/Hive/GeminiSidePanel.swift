import SwiftUI
import HiveCore

// MARK: - GeminiSidePanel
//
// Chat UI with message bubbles, copy button, model label,
// stop-generation, timestamps, empty state with suggestions,
// auto-scroll, URL detection with Open buttons, and quick-action chips.

struct GeminiSidePanel: View {
    @Environment(BrowserState.self) var state
    @State var input: String = ""
    @State var scrollProxy: ScrollViewProxy?
    @ObservedObject var speechRecognizer = SpeechRecognizer.shared
    @State var voiceOutput = VoiceSpeechOutput()
    @State var voiceTurnTask: Task<Void, Never>?
    @State var isPreSendContextExpanded: Bool = false
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Namespace var bottomID

    // @tab autocomplete state
    @State var referencedTabIDs: Set<String> = []
    @State var showTabAutocomplete: Bool = false
    @State var tabAutocompleteFilter: String = ""
    @State var autocompleteIndex: Int = 0

    // Heads-up memory strip state — what Hive already knows about the current
    // page at the moment the user asks (the "second brain keeps watching"
    // moment). Local reads only; nothing leaves the device. The generation
    // token + cancellable task debounce rapid tab switches and prevent a stale
    // refresh from overwriting the strip with a previous page's memory.
    @State var relatedPreferences: [PreferenceMemory] = []
    @State var trackedMemoryCount: Int = 0
    @State var headsUpTask: Task<Void, Never>?
    @State var headsUpGeneration: Int = 0

    // MARK: - Context Scope Preview (Dia-style diagnostics)

    /// A collapsible strip showing what context the AI used for the last response.
    /// Matches Dia's "thinking UI" — sources, node count, ranker status, duration.
    @State var isContextScopeExpanded: Bool = false
    /// Live hot-context nodes with scores — shown in the expanded strip with
    /// per-node forget controls ("the AI stays out of the way until you need it").
    @State var scopeNodes: [(id: String, score: Double, label: String)] = []
    /// How many nodes the user has forgotten this session — drives the restore
    /// affordance and keeps the strip visible after the last node is forgotten.
    @State var forgottenCount: Int = 0
}

// MARK: - Provider Options (Comet-style model toggle)

/// The selectable AI providers in the Gemini panel header. Raw values map 1:1
/// to `Dispatcher.ProviderPreference` so the choice flows straight through to
/// the routing layer.
enum GeminiProviderOption: String, CaseIterable, Identifiable {
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
