import SwiftUI
import AppKit
import HiveCore

// MARK: - Knowledge Panel

/// A minimal Honeycomb knowledge surface. Shows the browser's accumulated
/// memory — recently captured/accessed nodes and hot context — in a sidebar
/// panel. Proves the "browser that remembers" thesis.
///
/// Three sections:
/// 1. Hot Memory — what the AI is currently tracking (from HotMemoryStore)
/// 2. Recent Captures — latest nodes stored in Honeycomb
/// 3. Search — full-text search across the knowledge graph
struct KnowledgePanel: View {
    @Environment(BrowserState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Panel modes: the knowledge graph (hot memory / recent / search) or the
    /// projects + next-action surface (the Organize step of the demo spine).
    private enum Mode: String, CaseIterable, Identifiable {
        case knowledge
        case projects
        var id: String { rawValue }
        var label: String {
            switch self {
            case .knowledge: return "Knowledge"
            case .projects: return "Projects"
            }
        }
        var icon: String {
            switch self {
            case .knowledge: return "hexagon.fill"
            case .projects: return "folder.fill"
            }
        }
    }

    @State private var mode: Mode = .knowledge
    @State private var searchQuery: String = ""
    @State private var searchResults: [HoneycombStore.Node] = []
    @State private var hotEntries: [HotMemoryStore.HotEntry] = []
    @State private var recentNodes: [HoneycombStore.Node] = []
    @State private var nodeCount: Int = 0
    @State private var isSearching: Bool = false
    @State private var captureText: String = ""
    @State private var isSavingNote: Bool = false
    @State private var saveFlash: Bool = false
    @State private var captureError: String? = nil
    @State private var selectedNode: HoneycombStore.Node?

    var body: some View {
        VStack(spacing: 0) {
            header
            modePicker
            Divider()
            switch mode {
            case .knowledge:
                VStack(spacing: 0) {
                    quickCapture
                    Divider()
                    searchBar
                    Divider()
                    knowledgeContent
                }
            case .projects:
                ProjectsPanel()
            }
        }
        .frame(width: 300)
        .background(HiveDesign.Material.sidebar)
        .task { await refresh() }
        // Live refresh: capture a page or note while the panel is open and the
        // memory lists update immediately — no reopen required.
        .onChange(of: state.memoryRevision) { _, _ in
            _ = Task { await refresh() }
        }
        .sheet(item: $selectedNode) { node in
            KnowledgeNodeInspector(node: node) {
                selectedNode = nil
                _ = Task { await refresh() }
            }
        }
    }

    // MARK: - Mode Picker

    /// A quiet segmented switch between the two panel surfaces. No pill
    /// chrome, no fake glass — just a two-segment underline control.
    private var modePicker: some View {
        HStack(spacing: 2) {
            ForEach(Mode.allCases) { m in
                Button(action: { withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) { mode = m } }) {
                    HStack(spacing: 5) {
                        Image(systemName: m.icon)
                            .font(HiveDesign.Typography.microLabel)
                        Text(m.label)
                            .font(HiveDesign.Typography.captionSemiBold)
                    }
                    .foregroundStyle(mode == m ? HiveDesign.Text.primary : HiveDesign.Text.tertiary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill(mode == m ? HiveDesign.Surface.level2 : .clear)
                    )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
    }

    // MARK: - Knowledge Content

    @ViewBuilder
    private var knowledgeContent: some View {
        if isSearching {
            searchResultsList
        } else {
            contentList
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "hexagon.fill")
                .font(HiveDesign.Typography.bodySemiBold)
                .foregroundStyle(HiveDesign.Accent.primary)
            Text("Knowledge")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(HiveDesign.Text.primary)
            Spacer()
            Text("\(nodeCount) nodes")
                .font(HiveDesign.Typography.monoCaptionMedium)
                .foregroundStyle(HiveDesign.Text.tertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(HiveDesign.Surface.level2)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(HiveDesign.Text.tertiary)
            TextField("Search knowledge...", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.sidebarItem)
                .onSubmit { Task { await performSearch() } }
            if !searchQuery.isEmpty {
                Button(action: {
                    searchQuery = ""
                    searchResults = []
                    isSearching = false
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(HiveDesign.Text.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(HiveDesign.Surface.level1)
    }

    // MARK: - Quick Capture

    /// The capture-first inbox: type a thought, press ⏎, and it lands in
    /// Honeycomb as a `.note` node (deduplicated, audited, warmed into hot
    /// memory) — the "keeps watching" entry point of the Knowledge panel.
    private var quickCapture: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(HiveDesign.Accent.primary)
                TextField("Capture a thought…", text: $captureText)
                    .textFieldStyle(.plain)
                    .font(HiveDesign.Typography.sidebarItem)
                    .onSubmit { saveNote() }
                if isSavingNote {
                    ProgressView().controlSize(.mini)
                } else if saveFlash {
                    Image(systemName: "checkmark.circle.fill")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(.green)
                        .accessibilityHidden(true)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Button(action: saveNote) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(HiveDesign.Typography.bodyLarge)
                            .foregroundStyle(captureText.trimmingCharacters(in: .whitespaces).isEmpty
                                             ? HiveDesign.Text.tertiary.opacity(0.4)
                                             : HiveDesign.Accent.primary)
                    }
                    .buttonStyle(.plain)
                    .disabled(captureText.trimmingCharacters(in: .whitespaces).isEmpty || isSavingNote)
                    .accessibilityLabel("Save note")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(HiveDesign.Surface.level1)
            if let captureError {
                Text(captureError)
                    .font(HiveDesign.Typography.caption)
                    .foregroundStyle(.red.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                    .transition(.opacity)
            }
        }
    }

    private func saveNote() {
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSavingNote else { return }
        isSavingNote = true
        captureError = nil
        Task {
            do {
                _ = try await state.captureNote(text)
                await MainActor.run {
                    withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) {
                        captureText = ""
                        saveFlash = true
                    }
                }
                // Let the checkmark breathe, then fade it out.
                try? await Task.sleep(for: .seconds(1.2))
                await MainActor.run {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.15)) { saveFlash = false }
                }
            } catch {
                // A failed write must never destroy the user's words: keep the
                // text and surface the failure inline instead.
                await MainActor.run {
                    withAnimation(reduceMotion ? nil : HiveDesign.Animation.spring) {
                        captureError = error.localizedDescription
                    }
                }
            }
            await MainActor.run { isSavingNote = false }
        }
    }

    // MARK: - Content List

    private var contentList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                hotMemorySection
                recentSection
                if hotEntries.isEmpty && recentNodes.isEmpty {
                    emptyState
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Hot Memory Section

    private var hotMemorySection: some View {
        Group {
            if !hotEntries.isEmpty {
                let visibleEntries = hotEntries.filter {
                    $0.admission == .durable && !$0.isPrivate
                }
                if !visibleEntries.isEmpty {
                    sectionHeader("Hot Memory", icon: "flame.fill", count: visibleEntries.count)
                    ForEach(visibleEntries.prefix(10)) { entry in
                        HotMemoryRow(entry: entry)
                    }
                }
                Divider().padding(.horizontal, 14).padding(.vertical, 4)
            }
        }
    }

    // MARK: - Recent Section

    private var recentSection: some View {
        Group {
            if !recentNodes.isEmpty {
                sectionHeader("Recent", icon: "clock", count: recentNodes.count)
                ForEach(recentNodes.prefix(15)) { node in
                    KnowledgeRow(node: node) { selectedNode = node }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "hexagon")
                .font(.system(size: 32))
                .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.5))
            Text("No knowledge yet")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(HiveDesign.Text.secondary)
            Text("Browse pages and use the AI assistant to build up your knowledge graph.")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(HiveDesign.Text.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 30)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Search Results

    private var searchResultsList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                sectionHeader("Results", icon: "magnifyingglass", count: searchResults.count)
                if searchResults.isEmpty {
                    Text("No results for \"\(searchQuery)\"")
                        .font(HiveDesign.Typography.sidebarItem)
                        .foregroundStyle(HiveDesign.Text.tertiary)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 20)
                } else {
                    ForEach(searchResults) { node in
                        KnowledgeRow(node: node) { selectedNode = node }
                    }
                }
            }
            .padding(.bottom, 20)
        }
        .onChange(of: searchQuery) { _, newValue in
            if newValue.isEmpty {
                isSearching = false
                searchResults = []
            }
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, icon: String, count: Int) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(HiveDesign.Typography.captionSemiBold)
                .foregroundStyle(HiveDesign.Accent.primary)
            Text(title.uppercased())
                .font(HiveDesign.Typography.microLabelBold)
                .foregroundStyle(HiveDesign.Text.tertiary)
            Spacer()
            Text("\(count)")
                .font(HiveDesign.Typography.monoMicroMedium)
                .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.6))
        }
        .padding(.horizontal, 18)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - Refresh

    private func refresh() async {
        // Hot memory entries
        hotEntries = await state.hotMemory.currentHotEntries()

        // Recent nodes across every memory type users create while browsing
        // (sources, captures, notes, briefs, claims) — one query per type,
        // merged by recency so the panel reflects the full second brain, not
        // just captured pages.
        var merged: [HoneycombStore.Node] = []
        for type in [HoneycombStore.NodeType.source, .capture, .note, .brief, .claim] {
            if let nodes = try? await state.honeycomb.getNodesByType(type, limit: 20) {
                merged.append(contentsOf: nodes.filter(BrowserState.isInspectableKnowledgeNode))
            }
        }
        recentNodes = Array(merged.sorted { $0.createdAt > $1.createdAt }.prefix(15))

        // Keep the panel count aligned with the durable rows it can actually
        // inspect; candidate/session entries never become durable rows here.
        nodeCount = merged.count
    }

    private func performSearch() async {
        guard !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty else {
            isSearching = false
            return
        }
        isSearching = true
        if let results = try? await state.honeycomb.search(query: searchQuery, limit: 30) {
            searchResults = results.filter(BrowserState.isInspectableKnowledgeNode)
        }
    }
}

// MARK: - Hot Memory Row

private struct HotMemoryRow: View {
    @Environment(BrowserState.self) private var state
    let entry: HotMemoryStore.HotEntry
    @State private var isHovered = false

    var body: some View {
        Button(action: openIfPossible) {
            HStack(spacing: 8) {
                Circle()
                    .fill(scoreColor)
                    .frame(width: 6, height: 6)
                Image(systemName: entryIcon)
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(entryColor)
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(entryLabel)
                        .font(HiveDesign.Typography.smallLabelMedium)
                        .foregroundStyle(HiveDesign.Text.secondary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Text(entry.sourceHint)
                            .font(HiveDesign.Typography.microLabelSecondary)
                            .foregroundStyle(HiveDesign.Text.tertiary)
                        Text("·")
                            .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.4))
                        Text("\(entry.accessCount)×")
                            .font(HiveDesign.Typography.monoMicroMedium)
                            .foregroundStyle(HiveDesign.Text.tertiary)
                    }
                }
                Spacer()
                Text(String(format: "%.0f%%", entry.score * 100))
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(HiveDesign.Text.tertiary)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHovered ? HiveDesign.Surface.level2.opacity(0.6) : .clear)
                .padding(.horizontal, 8)
        )
        .onHover { isHovered = $0 }
    }

    /// URL-bearing hot entries re-open their page in a tab; content-bearing
    /// entries (notes, extractions) open their stamped content in the AI
    /// panel. Every row acts — no dead clicks.
    private func openIfPossible() {
        state.openHotEntry(entry)
    }

    /// Human-readable label for the hot entry — the stamped title/content when
    /// available (set at access time), never raw UUID tails.
    private var entryLabel: String {
        if let label = entry.label, !label.isEmpty { return label }
        if let content = entry.content, !content.isEmpty { return String(content.prefix(40)) }
        if entry.id.hasPrefix("page-") { return "Page" }
        if entry.id.hasPrefix("response-") { return "Response" }
        if entry.id.hasPrefix("librarian-") { return "Extraction" }
        return String(entry.id.suffix(8))
    }

    /// SF Symbol matching the entry kind (bubble, doc, extraction).
    private var entryIcon: String {
        if entry.id.hasPrefix("page-") { return "doc.text" }
        if entry.id.hasPrefix("response-") { return "bubble.left" }
        if entry.id.hasPrefix("librarian-") { return "text.magnifyingglass" }
        return "hexagon"
    }

    private var entryColor: Color {
        if entry.id.hasPrefix("page-") { return HiveDesign.Accent.primary }
        if entry.id.hasPrefix("response-") { return .teal }
        if entry.id.hasPrefix("librarian-") { return .purple }
        return HiveDesign.Text.tertiary
    }

    private var scoreColor: Color {
        if entry.score > 0.7 { return HiveDesign.Accent.primary }
        if entry.score > 0.3 { return .orange }
        return HiveDesign.Text.tertiary.opacity(0.5)
    }
}

// MARK: - Knowledge Row

private struct KnowledgeRow: View {
    @Environment(BrowserState.self) private var state
    let node: HoneycombStore.Node
    let onInspect: () -> Void
    @State private var isHovered = false

    /// Rows that point at a page (sources, captures) open that page in a new
    /// tab. Rows with stored content (notes, briefs, claims) open their
    /// content in the AI panel. A meaningful label alone also acts (claims
    /// fall back to their label when metadata is absent). The affordance and
    /// the click agree — no row acts without a chevron, no chevron is dead.
    private var nodeURL: String? { BrowserState.knowledgeNodeURL(from: node) }
    private var nodeContent: String? { BrowserState.knowledgeNodeContent(from: node) }
    private var hasMeaningfulLabel: Bool {
        !node.label.isEmpty && node.label != "(untitled)"
    }
    private var isActionable: Bool { nodeURL != nil || nodeContent != nil || hasMeaningfulLabel }

    var body: some View {
        Button(action: openIfPossible) {
            HStack(spacing: 8) {
                Image(systemName: nodeIcon)
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(nodeColor)
                    .frame(width: 18)
                VStack(alignment: .leading, spacing: 2) {
                    Text(node.label.isEmpty ? "(untitled)" : node.label)
                        .font(HiveDesign.Typography.smallLabelMedium)
                        .foregroundStyle(HiveDesign.Text.primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 4) {
                        Text(node.type.rawValue)
                            .font(HiveDesign.Typography.microLabelSecondary)
                            .foregroundStyle(HiveDesign.Text.tertiary)
                        Text("·")
                            .foregroundStyle(HiveDesign.Text.tertiary.opacity(0.4))
                        Text(node.createdAt, style: .relative)
                            .font(HiveDesign.Typography.microLabelSecondary)
                            .foregroundStyle(HiveDesign.Text.tertiary)
                    }
                }
                Spacer()
                if isActionable {
                    Image(systemName: nodeURL != nil ? "arrow.up.right" : "chevron.right")
                        .font(HiveDesign.Typography.microLabel)
                        .foregroundStyle(isHovered ? HiveDesign.Accent.primary : HiveDesign.Text.tertiary.opacity(0.35))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(isHovered ? HiveDesign.Surface.level2.opacity(0.6) : .clear)
                .padding(.horizontal, 8)
        )
        .onHover { isHovered = $0 }
        .contextMenu {
            Button("Inspect memory") { onInspect() }
        }
    }

    private func openIfPossible() {
        guard isActionable else { return }
        state.openKnowledgeNode(node)
    }

    private var nodeIcon: String {
        switch node.type {
        case .source:     return "link"
        case .capture:    return "doc.text"
        case .claim:      return "lightbulb"
        case .artifact:   return "doc"
        case .project:    return "folder"
        case .task:       return "checkmark.circle"
        case .brief:      return "doc.plaintext"
        case .decision:   return "scalemass"
        case .question:   return "questionmark.circle"
        case .preference: return "gearshape"
        case .note:       return "note.text"
        case .unknown:    return "questionmark"
        }
    }

    private var nodeColor: Color {
        switch node.type {
        case .source:     return .blue
        case .capture:    return .green
        case .claim:      return .yellow
        case .artifact:   return .purple
        case .project:    return HiveDesign.Accent.primary
        case .task:       return .orange
        case .brief:      return .indigo
        case .decision:   return .red
        case .question:   return .pink
        case .preference: return .gray
        case .note:       return .teal
        case .unknown:    return .gray
        }
    }
}

// MARK: - Durable Memory Inspector

private struct KnowledgeNodeInspector: View {
    @Environment(BrowserState.self) private var state
    @Environment(\.dismiss) private var dismiss
    let originalNode: HoneycombStore.Node
    let onChanged: () -> Void

    @State private var label: String
    @State private var content: String
    @State private var revisions: [HoneycombStore.Revision] = []
    @State private var errorMessage: String?
    @State private var showDeleteConfirmation = false
    @State private var isSaving = false

    init(node: HoneycombStore.Node, onChanged: @escaping () -> Void) {
        self.originalNode = node
        self.onChanged = onChanged
        let extracted = BrowserState.knowledgeNodeContent(from: node) ?? ""
        _label = State(initialValue: node.label)
        _content = State(initialValue: extracted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "hexagon.fill")
                    .foregroundStyle(HiveDesign.Accent.primary)
                Text("Inspect memory")
                    .font(HiveDesign.Typography.heading)
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderless)
            }
            .padding(16)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    metadataBlock
                    Text("Label")
                        .font(HiveDesign.Typography.captionSemiBold)
                        .foregroundStyle(HiveDesign.Text.secondary)
                    TextField("Label", text: $label)
                        .textFieldStyle(.roundedBorder)
                    Text("Content")
                        .font(HiveDesign.Typography.captionSemiBold)
                        .foregroundStyle(HiveDesign.Text.secondary)
                    TextEditor(text: $content)
                        .font(HiveDesign.Typography.sidebarItem)
                        .frame(minHeight: 130)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(HiveDesign.Surface.level3))
                    revisionsBlock
                    if let errorMessage {
                        Text(errorMessage)
                            .font(HiveDesign.Typography.caption)
                            .foregroundStyle(.red)
                    }
                }
                .padding(16)
            }
            Divider()
            HStack {
                Button("Delete", role: .destructive) { showDeleteConfirmation = true }
                Spacer()
                Button("Export Markdown") { exportMarkdown() }
                Button(isSaving ? "Saving…" : "Save correction") { saveCorrection() }
                    .buttonStyle(.borderedProminent)
                    .disabled(isSaving || label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
        }
        .frame(width: 520, height: 620)
        .background(HiveDesign.Material.panel)
        .task { await loadRevisions() }
        .confirmationDialog("Delete this durable memory?", isPresented: $showDeleteConfirmation,
                            titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteNode() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the node, search index, graph edges, and revision history. This cannot be undone.")
        }
    }

    private var metadataBlock: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(originalNode.type.rawValue.capitalized)
                .font(HiveDesign.Typography.subHeadingSemiBold)
            Text("Provenance · \(originalNode.provenance)")
            Text("Created · \(originalNode.createdAt, style: .date)")
            Text("Updated · \(originalNode.updatedAt, style: .relative)")
        }
        .font(HiveDesign.Typography.caption)
        .foregroundStyle(HiveDesign.Text.tertiary)
    }

    @ViewBuilder private var revisionsBlock: some View {
        if !revisions.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Revision history")
                    .font(HiveDesign.Typography.captionSemiBold)
                ForEach(revisions) { revision in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(revision.previousLabel)
                            .font(HiveDesign.Typography.smallLabelMedium)
                        Text(revision.revisedAt, style: .relative)
                            .font(HiveDesign.Typography.microLabelSecondary)
                            .foregroundStyle(HiveDesign.Text.tertiary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(HiveDesign.Surface.level1)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                }
            }
        }
    }

    private func loadRevisions() async {
        revisions = (try? await state.honeycomb.getRevisions(nodeID: originalNode.id)) ?? []
    }

    private func saveCorrection() {
        let trimmedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLabel.isEmpty, !isSaving else { return }
        isSaving = true
        errorMessage = nil
        Task {
            do {
                switch originalNode.type {
                case .claim:
                    _ = try await state.honeycomb.correctClaim(
                        claimID: originalNode.id,
                        text: content.isEmpty ? trimmedLabel : content
                    )
                case .brief:
                    _ = try await state.honeycomb.updateBrief(
                        briefID: originalNode.id,
                        title: trimmedLabel,
                        content: content
                    )
                default:
                    var metadata = originalNode.metadata
                    if case .object(var values) = metadata {
                        switch originalNode.type {
                        case .source:
                            values["title"] = .string(trimmedLabel)
                        case .capture, .note, .decision, .question, .preference:
                            values["content"] = .string(content)
                        default:
                            break
                        }
                        metadata = .object(values)
                    }
                    _ = try await state.honeycomb.updateNode(id: originalNode.id,
                                                              label: trimmedLabel,
                                                              metadata: metadata)
                }
                await MainActor.run {
                    onChanged()
                    dismiss()
                }
            } catch {
                await MainActor.run { errorMessage = error.localizedDescription; isSaving = false }
            }
        }
    }

    private func exportMarkdown() {
        Task {
            guard let markdown = try? await state.honeycomb.exportMarkdown(originalNode) else {
                await MainActor.run { errorMessage = "Export failed." }
                return
            }
            await MainActor.run {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.plainText]
                panel.nameFieldStringValue = "\(originalNode.label.isEmpty ? "memory" : originalNode.label).md"
                guard panel.runModal() == .OK, let url = panel.url else { return }
                do { try markdown.write(to: url, atomically: true, encoding: .utf8) }
                catch { errorMessage = "Export failed: \(error.localizedDescription)" }
            }
        }
    }

    private func deleteNode() {
        Task {
            let event = EventLedgerStore.LedgerEvent(
                    actor: "user",
                    intent: "Delete durable memory",
                    actionKind: .systemEvent,
                    actionTarget: originalNode.id,
                    actionPreview: "Delete \(originalNode.type.rawValue): \(originalNode.label)",
                    trustLevel: .t2,
                    policyDecision: .allowed,
                    consentState: .approved,
                    contextIDs: [originalNode.id],
                    result: .partial,
                    provenance: "knowledge-panel"
                )
            do {
                guard await state.recordAuditEvent(event) else {
                    await MainActor.run { errorMessage = "Delete blocked: audit storage is unavailable." }
                    return
                }
                try await state.honeycomb.deleteNode(id: originalNode.id)
                await state.hotMemory.removeNode(id: originalNode.id)
                let completionRecorded = await state.recordAuditEvent(EventLedgerStore.LedgerEvent(
                    actor: "user",
                    parentEventID: event.id,
                    intent: "Delete durable memory completed",
                    actionKind: .systemEvent,
                    actionTarget: originalNode.id,
                    actionPreview: "Deleted \(originalNode.type.rawValue): \(originalNode.label)",
                    trustLevel: .t2,
                    policyDecision: .allowed,
                    consentState: .approved,
                    contextIDs: [originalNode.id],
                    result: .success,
                    provenance: "knowledge-panel"
                ))
                if !completionRecorded {
                    await MainActor.run {
                        state.lastPolicyDenial = "Memory deleted, but completion could not be recorded because audit storage is unavailable."
                    }
                }
                await MainActor.run {
                    onChanged()
                    dismiss()
                }
            } catch {
                _ = await state.recordAuditEvent(EventLedgerStore.LedgerEvent(
                    actor: "user",
                    parentEventID: event.id,
                    intent: "Delete durable memory failed",
                    actionKind: .systemEvent,
                    actionTarget: originalNode.id,
                    actionPreview: "Could not delete \(originalNode.type.rawValue): \(originalNode.label)",
                    trustLevel: .t2,
                    policyDecision: .allowed,
                    consentState: .approved,
                    contextIDs: [originalNode.id],
                    result: .failure,
                    errorDescription: error.localizedDescription,
                    provenance: "knowledge-panel"
                ))
                await MainActor.run { errorMessage = error.localizedDescription }
            }
        }
    }
}

// Metadata extractors (url/content keys) live as static helpers on
// BrowserState — shared with the panel rows as the single source of
// truth for Honeycomb node metadata keys.
