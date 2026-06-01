import SwiftUI
import UniformTypeIdentifiers
import HiveCore
import HiveDesignSystem
import HiveMetalRenderer
#if os(macOS)
import AppKit
#elseif canImport(UIKit)
import UIKit
#endif
#if canImport(QuickLookThumbnailing) && !os(watchOS)
import QuickLookThumbnailing
#endif

#if os(macOS)
private typealias HiveAttachmentPlatformImage = NSImage
#elseif canImport(UIKit)
private typealias HiveAttachmentPlatformImage = UIImage
#else
private struct HiveAttachmentPlatformImage {}
#endif

public struct RawInputsSurface: View {
    public var sources: [SourcePresentationModel]
    public var rawSources: [SourcePresentationModel]
    public var clusters: [RawInputCellCluster]
    public var organismState: HiveOrganismState
    public var selectedSourceID: String?
    public var onSelect: (String) -> Void
    public var onImport: ([URL]) -> Void
    public var onSubmitText: (String) -> Void
    public var onRequestImport: () -> Void
    public var onSynthesize: () -> Void
    public var onProcessNow: (String) -> Void
    public var onRemoveSource: (String) -> Void
    public var onPreviewSource: (String) -> Void
    public var onReprocessSource: (String) -> Void
    public var isWorking: Bool

    @State private var dragPoint: CGPoint?
    @State private var feedDraft = ""
    @State private var feedDropTargeted = false
    @State private var feedDropPulse = 0
    @State private var hoveredClusterID: String?
    @State private var formationTrigger = 0
    @State private var lastSourceCount = 0
    @State private var sourceSearchText = ""
    @State private var feedStatusText: String?
    @State private var rawSourcesSheetVisible = false
    @StateObject private var voiceRecorder = HiveVoiceNoteRecorder()
    @AppStorage("hive.tip.rawSources.dismissed") private var rawSourcesTipDismissed = false

    public init(
        sources: [SourcePresentationModel],
        rawSources: [SourcePresentationModel]? = nil,
        clusters: [RawInputCellCluster],
        organismState: HiveOrganismState,
        selectedSourceID: String? = nil,
        onSelect: @escaping (String) -> Void,
        onImport: @escaping ([URL]) -> Void,
        onSubmitText: @escaping (String) -> Void = { _ in },
        onRequestImport: @escaping () -> Void = {},
        onSynthesize: @escaping () -> Void = {},
        onProcessNow: @escaping (String) -> Void = { _ in },
        onRemoveSource: @escaping (String) -> Void = { _ in },
        onPreviewSource: @escaping (String) -> Void = { _ in },
        onReprocessSource: @escaping (String) -> Void = { _ in },
        isWorking: Bool = false
    ) {
        self.sources = sources
        self.rawSources = rawSources ?? sources
        self.clusters = clusters
        self.organismState = organismState
        self.selectedSourceID = selectedSourceID
        self.onSelect = onSelect
        self.onImport = onImport
        self.onSubmitText = onSubmitText
        self.onRequestImport = onRequestImport
        self.onSynthesize = onSynthesize
        self.onProcessNow = onProcessNow
        self.onRemoveSource = onRemoveSource
        self.onPreviewSource = onPreviewSource
        self.onReprocessSource = onReprocessSource
        self.isWorking = isWorking
    }

    public var body: some View {
        HiveMetalScene {
            VStack(alignment: .leading, spacing: HiveSpacing.lg) {
                surfaceHeader
                    .padding(.horizontal, HiveLayoutMetrics.contentHorizontalPadding)
                if !rawSourcesTipDismissed && allClusters.isEmpty {
                    HiveContextTip(
                        title: "Start with anything",
                        message: "Drop files, screenshots, notes, tasks, or books. Select a Field item to ask what Hive understood while the original stays separate.",
                        symbol: .rawInputs
                    ) {
                        withAnimation(HiveMotion.focus) {
                            rawSourcesTipDismissed = true
                        }
                    }
                    .padding(.horizontal, HiveLayoutMetrics.contentHorizontalPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
                sourceListControls
                    .padding(.horizontal, HiveLayoutMetrics.contentHorizontalPadding)
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if allClusters.isEmpty {
                            RawSourcesEmptyState(
                                onImport: onRequestImport,
                                onUpdateWiki: onSynthesize
                            )
                            .padding(.top, 18)
                        } else if visibleClusters.isEmpty {
                            RawSourcesNoMatchesState(
                                query: sourceSearchText,
                                onClear: { sourceSearchText = "" }
                            )
                            .padding(.top, 18)
                        } else {
                            ForEach(visibleClusters) { cluster in
                                let selected = cluster.contains(sourceID: selectedSourceID)
                                SourceRow(
                                    source: cluster.primary,
                                    title: cluster.title,
                                    summary: cluster.summary,
                                    selected: selected,
                                    hovered: cluster.id == hoveredClusterID,
                                    onProcessNow: { onProcessNow(cluster.primary.sourceID) },
                                    onExtractMore: { onReprocessSource(cluster.primary.sourceID) },
                                    onRemove: { onRemoveSource(cluster.primary.sourceID) },
                                    onPreview: { onPreviewSource(cluster.primary.sourceID) }
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    if !cluster.primary.isProcessing {
                                        onSelect(cluster.primary.id)
                                    }
                                }
                                .onHover { hovering in
                                    hoveredClusterID = hovering ? cluster.id : nil
                                }
                                .accessibilityAddTraits(.isButton)
                                .accessibilityAddTraits(selected ? .isSelected : AccessibilityTraits())
                                .accessibilityLabel("\(cluster.title). \(cluster.summary)")
                                .accessibilityValue(selected ? "Selected" : "Not selected")
                                .accessibilityHint("Opens Field details and an ask box.")
                                .transition(.move(edge: .top).combined(with: .opacity))
                            }
                        }
                    }
                    .padding(.horizontal, HiveLayoutMetrics.contentHorizontalPadding)
                    .padding(.bottom, HiveSpacing.lg)
                }
                feedComposer
                    .padding(.horizontal, HiveLayoutMetrics.contentHorizontalPadding)
            }
            .padding(.vertical, HiveLayoutMetrics.contentVerticalPadding)
            .frame(maxWidth: HiveLayoutMetrics.contentMaxWidth, maxHeight: .infinity, alignment: .topLeading)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .onAppear {
                lastSourceCount = sources.count
            }
            .onChange(of: sources.count) { _, count in
                if count != lastSourceCount {
                    lastSourceCount = count
                    formationTrigger += 1
                }
            }
            .onDrop(of: [.fileURL, .text], isTargeted: $feedDropTargeted) { providers, location in
                handleFeedDrop(providers: providers, location: location)
            }
            .onChange(of: voiceRecorder.statusText) { _, value in
                feedStatusText = value
            }
            .sheet(isPresented: $rawSourcesSheetVisible) {
                RawSourcesAuditSheet(
                    sources: rawSources,
                    onPreview: onPreviewSource,
                    onProcessNow: onProcessNow,
                    onReprocess: onReprocessSource,
                    onRemove: onRemoveSource
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(HiveColorToken.backgroundMid.color)
            }
        }
    }

    private var surfaceHeader: some View {
        HStack(alignment: .lastTextBaseline) {
            HiveText("Field", role: .nectarTitle)
            Spacer()
            HiveSymbolButton(.rawSourcesSheet, title: nil, compact: true) {
                rawSourcesSheetVisible = true
            }
            .help("Raw Sources")
            .accessibilityLabel("Raw Sources")
            if let badge = surfaceStatusBadge {
                HiveText(badge, role: .scaffoldAction)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 12)
                    .background(HiveColorToken.raisedSurface.color.opacity(0.72))
                    .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var surfaceStatusBadge: String? {
        if isWorking {
            return "Updating The Colony"
        }
        switch organismState {
        case .confused:
            return "Needs Attention"
        case .foraging, .digesting, .synthesizing:
            return organismState.rawValue
        case .resting, .understood:
            return nil
        }
    }

    private var visibleClusters: [RawInputCellCluster] {
        let query = sourceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return allClusters }
        return allClusters.filter { cluster in
            cluster.searchText.contains(query)
        }
    }

    private var allClusters: [RawInputCellCluster] {
        clusters
    }

    private var sourceListControls: some View {
        HStack(spacing: 12) {
            RawSourceSearchField(
                text: $sourceSearchText,
                resultCount: visibleClusters.count,
                totalCount: allClusters.count
            )
            Button {
                formationTrigger += 1
                onSynthesize()
            } label: {
                Label {
                    Text(isWorking ? "Updating" : "Update")
                } icon: {
                    HiveSymbol(.runMaintenance, size: 15, active: isWorking)
                }
            }
            .buttonStyle(HiveGlassButtonStyle(active: isWorking))
            .controlSize(.large)
            .disabled(isWorking)
            if isWorking {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(HiveColorToken.waxAmber.color)
                    HiveText("Updating The Colony", role: .scaffoldLabel)
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(HiveColorToken.cellSurface.color.opacity(0.82))
                .clipShape(RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private var feedComposer: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.sm) {
            HStack(alignment: .bottom, spacing: HiveSpacing.sm) {
                Button(action: toggleVoiceNote) {
                    HiveSymbol(
                        .voiceNote,
                        size: 16,
                        active: voiceRecorder.isRecording || voiceRecorder.isTranscribing,
                        motion: voiceRecorder.isRecording ? .pulse : .none,
                        motionValue: voiceRecorder.isRecording ? 1 : 0
                    )
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .disabled(voiceRecorder.isTranscribing)
                .accessibilityLabel("Speak")
                .accessibilityHint("Records a spoken note, transcribes it on device when available, and feeds it to Hive.")

                ZStack(alignment: .topLeading) {
                    TextEditor(text: $feedDraft)
                        .font(HiveTypography.memoryEditor)
                        .foregroundStyle(HiveColorToken.nectarText.color)
                        .scrollContentBackground(.hidden)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 2)
                        .frame(minHeight: 42, maxHeight: 118)
                        .accessibilityLabel("Message for Hive")
                    if feedDraft.isEmpty {
                        HiveText("Tell Hive...", role: .scaffoldBody)
                            .foregroundStyle(HiveColorToken.nectarMuted.color.opacity(0.76))
                            .padding(.top, 15)
                            .padding(.leading, 7)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }

                Button(action: onRequestImport) {
                    HiveSymbol(.attach, size: 16)
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Attach")

                Button(action: submitFeedText) {
                    HiveSymbol(
                        .send,
                        size: 16,
                        active: !feedDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                        motion: .bounce,
                        motionValue: formationTrigger
                    )
                    .frame(width: 36, height: 36)
                    .background(
                        !feedDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? HiveColorToken.waxAmber.color.opacity(0.18)
                            : HiveColorToken.nectarText.color.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: HiveRadius.md, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
                .disabled(feedDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(feedDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.55 : 1)

                if isWorking {
                    ProgressView()
                        .controlSize(.small)
                        .tint(HiveColorToken.waxAmber.color)
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, HiveSpacing.sm)
            .padding(.vertical, HiveSpacing.xs)
            .background(HiveColorToken.cellSurface.color, in: RoundedRectangle(cornerRadius: HiveRadius.lg, style: .continuous))
            .shadow(color: HiveColorToken.backgroundDeep.color.opacity(0.25), radius: 3, x: 0, y: 1)
            if let feedStatusText {
                HiveText(feedStatusText, role: .scaffoldBody)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .accessibilityLabel(feedStatusText)
            }
        }
    }

    private func toggleVoiceNote() {
        if voiceRecorder.isRecording {
            voiceRecorder.stop { result in
                feedStatusText = result.message
                onImport([result.audioURL])
                if let transcript = result.transcript?.trimmingCharacters(in: .whitespacesAndNewlines), !transcript.isEmpty {
                    onSubmitText("Voice note\n\n\(transcript)")
                }
                formationTrigger += 1
            }
        } else {
            feedStatusText = "Recording"
            voiceRecorder.start()
        }
    }

    private func submitFeedText() {
        let trimmed = feedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSubmitText(trimmed)
        feedDraft = ""
        formationTrigger += 1
    }

    private func handleFeedDrop(providers: [NSItemProvider], location: CGPoint) -> Bool {
        dragPoint = location
        feedDropPulse += 1
        let collector = DropPayloadCollector()
        let group = DispatchGroup()
        for provider in providers {
            let containsFileURL = provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
            if containsFileURL {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let data = item as? Data,
                       let value = String(data: data, encoding: .utf8),
                       let url = URL(string: value) {
                        collector.append(url)
                    } else if let url = item as? URL {
                        collector.append(url)
                    }
                }
            } else if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                group.enter()
                provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
                    defer { group.leave() }
                    if let text = item as? String {
                        collector.append(text)
                    } else if let data = item as? Data,
                              let text = String(data: data, encoding: .utf8) {
                        collector.append(text)
                    }
                }
            }
        }
        group.notify(queue: .main) {
            dragPoint = nil
            feedDropTargeted = false
            if !collector.urls.isEmpty {
                onImport(collector.urls)
            }
            let droppedText = collector.text
            if !droppedText.isEmpty {
                onSubmitText(droppedText)
            }
        }
        return true
    }

}

private struct RawSourcesEmptyState: View {
    var onImport: () -> Void
    var onUpdateWiki: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("Field is empty")
            } icon: {
                HiveSymbol(.rawInputs, size: 18, active: true)
            }
        } description: {
            Text("Add a file, folder, screenshot, note, or web capture. Hive keeps originals separate and writes the organized version in The Colony.")
        } actions: {
            HStack(spacing: 10) {
                Button(action: onImport) {
                    Label {
                        Text("Add to Field…")
                    } icon: {
                        HiveSymbol(.importAction, size: 15, active: true)
                    }
                }
                .buttonStyle(HiveGlassButtonStyle(active: true))
                Button(action: onUpdateWiki) {
                    Label {
                        Text("Update The Colony")
                    } icon: {
                        HiveSymbol(.synthesizing, size: 15)
                    }
                }
                .buttonStyle(HiveGlassButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}

private struct RawSourcesNoMatchesState: View {
    var query: String
    var onClear: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label {
                Text("No matching Field items")
            } icon: {
                HiveSymbol(.search, size: 18, active: true)
            }
        } description: {
            Text("Clear the search or try a broader word from the title, project, or topic.")
        } actions: {
            Button(action: onClear) {
                Label {
                    Text("Clear Search")
                } icon: {
                    HiveSymbol(.close, size: 15)
                }
            }
            .buttonStyle(HiveGlassButtonStyle())
        }
        .frame(maxWidth: .infinity, minHeight: 220)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("No matching Field items for \(query)")
    }
}

private struct RawSourceSearchField: View {
    @Binding var text: String
    var resultCount: Int
    var totalCount: Int
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 10) {
            HiveSymbol(.search, size: 15, active: focused)
            TextField("Titles, topics, or summaries", text: $text)
                .textFieldStyle(.plain)
                .font(HiveTypography.chromeSearch)
                .foregroundStyle(HiveColorToken.nectarText.color)
                .focused($focused)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Label {
                        Text("Clear")
                    } icon: {
                        HiveSymbol(.close, size: 12, accessibilityLabel: "Clear search")
                    }
                    .labelStyle(.iconOnly)
                }
                .buttonStyle(HiveGlassButtonStyle(compact: true))
                .accessibilityLabel("Clear search")
            }
            Text(statusText)
                .font(HiveTypography.chromeCaption)
                .foregroundStyle(HiveColorToken.scaffoldFaint.color)
                .lineLimit(1)
        }
        .padding(.horizontal, HiveSpacing.md)
        .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
        .background(HiveColorToken.raisedSurface.color, in: RoundedRectangle(cornerRadius: HiveRadius.sm, style: .continuous))
        .contentShape(Rectangle())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Search Field")
        .accessibilityHint("Refines the visible Field clusters as you type.")
    }

    private var statusText: String {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Recent Field"
        }
        if resultCount == 0 {
            return "No matches"
        }
        return resultCount == 1 ? "1 result" : "\(resultCount) results"
    }
}

public struct RawInputCellCluster: Identifiable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var summary: String
    public var primary: SourcePresentationModel
    public var sources: [SourcePresentationModel]
    public var isSynthetic: Bool

    public var count: Int {
        sources.count
    }

    public init(
        id: String,
        title: String? = nil,
        summary: String? = nil,
        primary: SourcePresentationModel,
        sources: [SourcePresentationModel],
        isSynthetic: Bool = false
    ) {
        self.id = id
        self.title = title ?? primary.title
        self.summary = summary ?? primary.summary
        self.primary = primary
        self.sources = sources
        self.isSynthetic = isSynthetic
    }

    public func contains(sourceID: String?) -> Bool {
        guard let sourceID else { return false }
        return sources.contains { $0.id == sourceID }
    }

    public var searchText: String {
        ([title, summary] + sources.flatMap { source in
            [source.title, source.summary, source.status.rawValue, source.relativeAge]
        })
        .joined(separator: " ")
        .lowercased()
    }

    public static func clusters(from sources: [SourcePresentationModel], limit: Int = 72) -> [RawInputCellCluster] {
        RawInputSemanticClusterer().clusters(from: sources, limit: limit).map { cluster in
            RawInputCellCluster(
                id: cluster.id,
                title: cluster.title,
                summary: cluster.summary,
                primary: cluster.primary,
                sources: cluster.sources,
                isSynthetic: cluster.isSynthetic
            )
        }
    }
}

private final class DropPayloadCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [URL] = []
    private var strings: [String] = []

    var urls: [URL] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }

    var text: String {
        lock.lock()
        defer { lock.unlock() }
        return strings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
    }

    func append(_ url: URL) {
        lock.lock()
        values.append(url)
        lock.unlock()
    }

    func append(_ text: String) {
        lock.lock()
        strings.append(text)
        lock.unlock()
    }
}

private struct FeedPulseOverlay: View {
    var active: Bool
    var token: Int
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: HiveLayoutMetrics.prominentSurfaceCornerRadius + CGFloat(index * 2), style: .continuous)
                    .stroke(
                        HiveColorToken.waxAmber.color.opacity(active ? 0.24 - Double(index) * 0.055 : 0.04),
                        lineWidth: CGFloat(1 + index)
                    )
                    .padding(CGFloat(10 + index * 14))
                    .scaleEffect(active ? 1.0 + CGFloat(index) * 0.018 : 0.965)
            }
            LinearGradient(
                colors: [
                    HiveAmbientPalette.honeyHighlight(for: colorScheme).opacity(active ? 0.2 : 0.07),
                    .clear,
                    HiveAmbientPalette.honeyAmber(for: colorScheme).opacity(active ? 0.14 : 0.035)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .opacity(active ? 1 : 0.55)
        }
        .allowsHitTesting(false)
        .animation(HiveMotion.reveal, value: token)
        .animation(HiveMotion.control, value: active)
    }
}

private struct SourceRow: View {
    var source: SourcePresentationModel
    var title: String
    var summary: String
    var selected: Bool
    var hovered: Bool
    var onProcessNow: () -> Void
    var onExtractMore: () -> Void
    var onRemove: () -> Void
    var onPreview: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: source.isStaged ? 1 : 60)) { context in
            rowContent(now: context.date)
        }
        .disabled(source.isProcessing)
        .opacity(source.isProcessing ? 0.5 : 1)
        .contextMenu {
            if source.isStaged {
                Button(action: onProcessNow) {
                    HiveMenuActionLabel("Process now", symbol: .processNow)
                }
                Button(action: onPreview) {
                    HiveMenuActionLabel("Preview source", symbol: .previewSource)
                }
                Divider()
                Button(role: .destructive, action: onRemove) {
                    HiveMenuActionLabel("Remove", symbol: .forget)
                }
            } else {
                Button(action: onPreview) {
                    HiveMenuActionLabel("Preview source", symbol: .previewSource)
                }
                Button(action: onExtractMore) {
                    HiveMenuActionLabel("Extract more information", symbol: .indexedOnly)
                }
            }
        }
    }

    private func rowContent(now: Date) -> some View {
        HStack(spacing: HiveSpacing.md) {
            rowStatusSymbol
            if let preview = source.attachmentPreview {
                SourceAttachmentPreviewArtwork(preview: preview, width: 54, height: 42)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    if source.status == .understood {
                        HiveSymbol(.wiki, size: 12, rendering: .monochrome(HiveColorToken.waxAmber.color.opacity(0.58)))
                            .accessibilityLabel("Grouped in The Colony")
                    }
                    if isSystemSeed {
                        HiveText("System", role: .scaffoldLabel)
                            .foregroundStyle(HiveColorToken.scaffoldFaint.color)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 6)
                            .background(HiveColorToken.cellSurface.color.opacity(0.55), in: Capsule())
                    }
                    HiveText(title, role: .nectarCardTitle)
                        .lineLimit(1)
                        .help(title)
                }
                if let preview = source.attachmentPreview {
                    HStack(spacing: 6) {
                        HiveSymbol(symbol(for: preview), size: 12, active: selected || hovered)
                        Text(preview.displayName)
                            .font(HiveTypography.chromeCaption)
                            .lineLimit(1)
                            .foregroundStyle(HiveColorToken.nectarMuted.color)
                            .help(preview.displayName)
                    }
                }
                Text(source.isProcessing ? "Analyzing..." : (rowSummary ?? "No summary yet"))
                    .font(HiveTypography.hiveCaption)
                    .lineLimit(1)
                    .foregroundStyle(rowSummary == nil || source.isProcessing ? HiveColorToken.scaffoldFaint.color : HiveColorToken.nectarMuted.color)
                    .help(rowSummary ?? "No summary yet")
            }
            Spacer(minLength: 16)
            VStack(alignment: .trailing, spacing: 4) {
                if source.status != .understood && !source.isStaged && !source.isProcessing {
                    HiveText(source.status.rawValue, role: .scaffoldLabel)
                }
                HiveText(source.isStaged ? source.stagedRemainingText(now: now) : source.relativeAge, role: .scaffoldBody)
                    .opacity(0.72)
                if selected || hovered {
                    HiveSymbol(.explain, size: 16, active: true, rendering: .monochrome(HiveColorToken.waxAmber.color))
                    .padding(.top, 2)
                    .transition(.opacity.combined(with: .move(edge: .trailing)))
                }
            }
        }
        .padding(.vertical, HiveSpacing.md)
        .padding(.horizontal, HiveSpacing.lg)
        .frame(minHeight: 56)
        .background(rowBackground)
        .overlay(alignment: .bottomLeading) {
            if source.isStaged {
                StagedSourceProgress(progress: source.stagedProgress(now: now))
                    .padding(.horizontal, HiveSpacing.lg)
            } else {
                Rectangle()
                    .fill(HiveColorToken.scaffoldFaint.color.opacity(0.16))
                    .frame(height: 1)
                    .padding(.leading, HiveSpacing.lg)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.rowCornerRadius, style: .continuous))
    }

    @ViewBuilder
    private var rowStatusSymbol: some View {
        if source.isStaged {
            HiveSymbol(.staged, size: selected ? 15 : 13, rendering: .monochrome(HiveColorToken.scaffoldFaint.color))
                .frame(width: 18, height: 18)
        } else if source.isProcessing {
            RotatingProcessingSymbol()
                .frame(width: 18, height: 18)
        } else {
            HiveSymbolStatusMark(
                HiveSymbolName.sourceStatus(source.status),
                color: statusDotColor,
                size: selected ? 11 : 9,
                label: source.status.rawValue
            )
        }
    }

    private var rowBackground: Color {
        if selected { return HiveColorToken.waxAmber.color.opacity(0.12) }
        if hovered { return HiveColorToken.cellSurface.color.opacity(0.7) }
        return Color.clear
    }

    private func symbol(for preview: SourceAttachmentPreview) -> HiveSymbolName {
        switch preview.kind {
        case .image:
            return .screenshot
        case .document, .text, .file:
            return .indexedOnly
        case .folder:
            return .localDisk
        case .audio:
            return .voiceNote
        case .video:
            return .presentation
        case .web:
            return .webLink
        }
    }

    private var rowSummary: String? {
        let trimmed = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if source.status == .understood,
           (trimmed.caseInsensitiveCompare("Original saved. The Colony can use it when relevant.") == .orderedSame
            || trimmed.caseInsensitiveCompare("Saved locally.") == .orderedSame) {
            return nil
        }
        if HiveDisplaySanitizer.shouldHideSourceSummary(trimmed) {
            return nil
        }
        return trimmed
    }

    private var statusDotColor: Color {
        switch source.status {
        case .confused:
            return HiveColorToken.conflict.color
        case .foraging, .digesting, .synthesizing:
            return HiveColorToken.waxAmberBright.color
        case .understood:
            return HiveColorToken.sealed.color
        case .resting:
            return HiveColorToken.scaffoldFaint.color
        }
    }

    private var isSystemSeed: Bool {
        let lower = title.lowercased()
        return lower == "memory boundary reset"
            || lower == "hive start questions"
            || lower == "captured memory seed"
    }
}

private struct StagedSourceProgress: View {
    var progress: Double

    var body: some View {
        GeometryReader { proxy in
            let clamped = max(0, min(1, progress))
            ZStack(alignment: .trailing) {
                Capsule()
                    .fill(HiveColorToken.cellSurface.color.opacity(0.85))
                Capsule()
                    .fill(HiveColorToken.waxAmber.color.opacity(0.16))
                    .frame(width: proxy.size.width * CGFloat(1 - clamped))
            }
        }
        .frame(height: 2)
        .accessibilityHidden(true)
    }
}

private struct RotatingProcessingSymbol: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let rotation = timeline.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.1) / 1.1 * 360
            HiveSymbol(.processing, size: 14, active: true, rendering: .monochrome(HiveColorToken.waxAmber.color))
                .rotationEffect(.degrees(rotation))
        }
        .accessibilityLabel("Analyzing")
    }
}

private struct HiveMenuActionLabel: View {
    var title: String
    var symbol: HiveSymbolName

    init(_ title: String, symbol: HiveSymbolName) {
        self.title = title
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: HiveSpacing.sm) {
            HiveSymbol(symbol, size: 13)
            Text(title)
        }
    }
}

private struct RawSourcesAuditSheet: View {
    var sources: [SourcePresentationModel]
    var onPreview: (String) -> Void
    var onProcessNow: (String) -> Void
    var onReprocess: (String) -> Void
    var onRemove: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(sources) { source in
                    RawSourceAuditRow(source: source)
                        .contextMenu {
                            Button {
                                onPreview(source.sourceID)
                            } label: {
                                HiveMenuActionLabel("Preview source", symbol: .previewSource)
                            }
                            if source.isStaged {
                                Button {
                                    onProcessNow(source.sourceID)
                                } label: {
                                    HiveMenuActionLabel("Process now", symbol: .processNow)
                                }
                            } else {
                                Button {
                                    onReprocess(source.sourceID)
                                } label: {
                                    HiveMenuActionLabel("Extract more information", symbol: .indexedOnly)
                                }
                            }
                            Divider()
                            Button(role: .destructive) {
                                onRemove(source.sourceID)
                            } label: {
                                HiveMenuActionLabel("Remove source", symbol: .forget)
                            }
                        }
                }
                .onDelete { offsets in
                    for index in offsets {
                        guard sources.indices.contains(index) else { continue }
                        onRemove(sources[index].sourceID)
                    }
                }
            }
            .navigationTitle("Raw Sources")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct RawSourceAuditRow: View {
    var source: SourcePresentationModel

    var body: some View {
        HStack(spacing: HiveSpacing.md) {
            HiveSymbol(symbol, size: 16, active: source.recordStatus == .extracted)
            VStack(alignment: .leading, spacing: 3) {
                HiveText(source.title, role: .nectarBody)
                    .lineLimit(1)
                HiveText(source.rawURI, role: .scaffoldLabel)
                    .foregroundStyle(HiveColorToken.nectarMuted.color)
                    .lineLimit(1)
            }
            Spacer(minLength: HiveSpacing.md)
            VStack(alignment: .trailing, spacing: 3) {
                HiveText(statusLabel, role: .scaffoldLabel)
                HiveText(source.relativeAge, role: .scaffoldBody)
                    .foregroundStyle(HiveColorToken.scaffoldFaint.color)
            }
        }
        .padding(.vertical, HiveSpacing.xs)
    }

    private var symbol: HiveSymbolName {
        if source.sourceKind.rawValue == ["p", "d", "f"].joined() {
            return .indexedOnly
        }
        switch source.sourceKind {
        case .image, .screenshot:
            return .screenshot
        case .audio:
            return .voiceNote
        case .video:
            return .presentation
        case .browserBookmark, .browserHistory:
            return .webLink
        case .folder:
            return .localDisk
        default:
            return .rawSourcesSheet
        }
    }

    private var statusLabel: String {
        switch source.recordStatus {
        case .queued:
            return "Staged"
        case .extracting:
            return "Analyzing"
        case .extracted:
            return "Processed"
        case .needsReview:
            return "Needs review"
        case .failed:
            return "Failed"
        case .deleted:
            return "Removed"
        case .discovered:
            return "Discovered"
        }
    }
}

public struct SourceAttachmentPreviewArtwork: View {
    public var preview: SourceAttachmentPreview
    public var width: CGFloat
    public var height: CGFloat
    @State private var image: HiveAttachmentPlatformImage?
    @State private var requestedPath: String?

    public init(preview: SourceAttachmentPreview, width: CGFloat, height: CGFloat) {
        self.preview = preview
        self.width = width
        self.height = height
    }

    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: HiveLayoutMetrics.smallCornerRadius, style: .continuous)
                .fill(HiveColorToken.cellSurface.color.opacity(0.96))
            if canRenderImage, let image {
                platformImageView(image)
                    .scaledToFill()
                    .frame(width: width, height: height)
                    .clipped()
            } else {
                HiveSymbol(symbol, size: min(width, height) * 0.42, active: canRenderImage)
            }
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: HiveLayoutMetrics.smallCornerRadius, style: .continuous))
        .task(id: preview.localPath) {
            loadImageIfNeeded()
        }
        .accessibilityLabel("\(preview.kindLabel) preview for \(preview.displayName)")
    }

    private var canRenderImage: Bool {
        guard let path = preview.localPath, !path.isEmpty else { return false }
        switch preview.kind {
        case .image, .document, .file, .text:
            return true
        case .folder, .audio, .video, .web:
            return false
        }
    }

    private var symbol: HiveSymbolName {
        switch preview.kind {
        case .image:
            return .screenshot
        case .document, .text, .file:
            return .indexedOnly
        case .folder:
            return .localDisk
        case .audio:
            return .voiceNote
        case .video:
            return .presentation
        case .web:
            return .webLink
        }
    }

    @ViewBuilder
    private func platformImageView(_ image: HiveAttachmentPlatformImage) -> some View {
        #if os(macOS)
        Image(nsImage: image)
            .resizable()
        #elseif canImport(UIKit)
        Image(uiImage: image)
            .resizable()
        #else
        EmptyView()
        #endif
    }

    private func loadImageIfNeeded() {
        guard canRenderImage, let path = preview.localPath, requestedPath != path else { return }
        requestedPath = path
        image = nil
        let url = URL(fileURLWithPath: path)
        #if canImport(QuickLookThumbnailing) && !os(watchOS)
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: CGSize(width: width * 2, height: height * 2),
            scale: previewScale,
            representationTypes: .thumbnail
        )
        QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, _ in
            if let representation {
                #if os(macOS)
                let renderedImage = representation.nsImage
                #elseif canImport(UIKit)
                let renderedImage = representation.uiImage
                #else
                let renderedImage: HiveAttachmentPlatformImage? = nil
                #endif
                DispatchQueue.main.async {
                    self.image = renderedImage
                }
            } else {
                let renderedImage = Self.directImage(from: url)
                DispatchQueue.main.async {
                    self.image = renderedImage
                }
            }
        }
        #else
        let renderedImage = Self.directImage(from: url)
        DispatchQueue.main.async {
            self.image = renderedImage
        }
        #endif
    }

    private var previewScale: CGFloat {
        #if os(macOS)
        NSScreen.main?.backingScaleFactor ?? 2
        #elseif canImport(UIKit)
        UIScreen.main.scale
        #else
        2
        #endif
    }

    nonisolated private static func directImage(from url: URL) -> HiveAttachmentPlatformImage? {
        #if os(macOS)
        return NSImage(contentsOf: url)
        #elseif canImport(UIKit)
        return UIImage(contentsOfFile: url.path)
        #else
        return nil
        #endif
    }
}
