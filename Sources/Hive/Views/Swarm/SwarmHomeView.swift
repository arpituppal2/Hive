import SwiftUI
import HiveCore
import os.log

// MARK: - SwarmHomeView
//
// The memory home surface — the "second brain" landing tab of the Workspace
// sidebar. One glance answers "what has Hive remembered?" and one keystroke
// captures a thought:
//
//   Quick Capture  — freeform note → Honeycomb `.note` node (provenance "user")
//   Today's Memory — recent sources/captures with relative timestamps
//   Preferences    — stored user rules ("I'm vegetarian", "work hours 9-5")
//   Knowledge      — live per-type node counts (the graph overview)
//   Recent Briefs  — last saved research outputs, one tap to reload in chat
//
// Modeled on Mem.ai's flat capture stream + Reflect's daily-note timeline +
// Obsidian's backlink sidebar: zero-friction in, structured recall out.

struct SwarmHomeView: View {

    @Environment(ChromeState.self) private var state
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var captureText: String = ""
    @State private var captureFlash = false
    @State private var recentNodes: [HoneycombStore.Node] = []
    @State private var preferenceNodes: [HoneycombStore.Node] = []
    @State private var relatedPreferences: [PreferenceMemory] = []
    @State private var recentBriefs: [Brief] = []
    @State private var nodeCounts: [HoneycombStore.NodeType: Int] = [:]
    @State private var isLoading = false
    /// Which memory/brief row is hovered, for the Chrome-class row wash.
    @State private var hoveredNodeID: String? = nil
    @State private var hoveredBriefID: String? = nil

    private static let log = Logger(subsystem: "com.hive.browser", category: "SwarmHome")

    /// Shared relative-date formatter — construction is expensive and this view
    /// re-renders rows frequently (Apple guidance: cache DateFormatter instances).
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: HiveSpacing.s16) {
                    quickCapture
                    if isLoading {
                        loadingRow
                    } else {
                        relatedSection
                        preferencesSection
                        recentSection
                        knowledgeSection
                        briefsSection
                    }
                }
                .padding(.horizontal, HiveSpacing.s8)
                .padding(.vertical, HiveSpacing.s8)
            }
        }
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
        .background(Color.hiveBackground)
        .task { await loadAll() }
        .onChange(of: state.isSwarmOpen) { _, open in
            if open { Task { await loadAll() } }
        }
        // Heads Up must track the *current* page — refresh relevance on tab change.
        .onChange(of: state.activeTabID) { _, _ in
            Task { await refreshRelevance() }
        }
        // In-tab navigation: the relevance strip must follow the URL even when
        // the tab itself doesn't change (SPA pushes + full navigations).
        // refreshRelevance reads the live tab at execution time, so concurrent
        // refreshes cannot publish stale preferences.
        .onChange(of: state.activeTab?.url?.absoluteString) { _, _ in
            Task { await refreshRelevance() }
        }
        // Live memory: a page capture bumps memoryRevision in ChromeState —
        // refresh Today's Memory immediately instead of waiting for reopen.
        .onChange(of: state.memoryRevision) { _, _ in
            Task { await loadAll() }
        }
    }

    // MARK: - Quick Capture

    private var quickCapture: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            HStack(spacing: HiveSpacing.s4) {
                Image(systemName: "square.and.pencil")
                    .font(HiveTypography.font(.caption3Medium))
                    .foregroundStyle(state.activeAccentColor)
                Text("Quick Capture")
                    .hiveType(.chromeLabel)
                    .foregroundStyle(.hiveInk)
                Spacer()
                if captureFlash {
                    Text("Saved")
                        .hiveType(.caption2)
                        .foregroundStyle(state.activeAccentColor)
                        .transition(.opacity)
                }
            }

            HStack(spacing: HiveSpacing.s8) {
                TextField("Capture a thought…", text: $captureText)
                    .textFieldStyle(.plain)
                    .hiveType(.bodySmall)
                    .onSubmit(capture)
                Button(action: capture) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(HiveTypography.font(.dialogTitle))
                        .foregroundStyle(
                            captureText.trimmingCharacters(in: .whitespaces).isEmpty
                                ? Color.hiveMist : state.activeAccentColor
                        )
                }
                .buttonStyle(.plain)
                .disabled(captureText.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Save capture")
            }
            .padding(.horizontal, HiveSpacing.s8)
            .padding(.vertical, HiveSpacing.s8)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .fill(Color.hiveSurfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: HiveRadius.r8)
                    .stroke(Color.hiveBorderSubtle, lineWidth: 1)
            )

            Text("Also try Capture Page (⌘⇧S) while browsing to save the whole page to memory.")
                .hiveType(.caption2)
                .foregroundStyle(.hiveMist)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(HiveSpacing.s12)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r12)
                .fill(Color.hiveSurface.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: HiveRadius.r12)
                .stroke(Color.hiveBorderSubtle, lineWidth: 0.5)
        )
    }

    private var loadingRow: some View {
        HStack {
            Spacer()
            ProgressView().progressViewStyle(.circular).controlSize(.small)
            Spacer()
        }
        .padding(.vertical, HiveSpacing.s24)
    }

    // MARK: - Related to current page (Mem.ai "Heads Up")
    //
    // The differentiator: while browsing, Hive surfaces what it already knows
    // that's relevant to this page — preferences ("I'm vegetarian") and captured
    // knowledge — without the user asking. Quiet, dismissible-by-absence, and
    // only for the active page (never background tabs).

    @ViewBuilder
    private var relatedSection: some View {
        let host = state.activeTab?.url?.host ?? ""
        if !relatedPreferences.isEmpty {
            VStack(alignment: .leading, spacing: HiveSpacing.s8) {
                sectionHeader(icon: "sparkles", title: "Related to \(host.isEmpty ? "this page" : host)")
                LazyVStack(alignment: .leading, spacing: HiveSpacing.s4) {
                    ForEach(relatedPreferences, id: \.id) { pref in
                        HStack(spacing: HiveSpacing.s8) {
                            Image(systemName: "heart.fill")
                                .font(HiveTypography.font(.microTiny))
                                .foregroundStyle(state.activeAccentColor)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(pref.path)
                                    .hiveType(.bodySmall)
                                    .foregroundStyle(.hiveInk)
                                    .lineLimit(1)
                                Text(pref.value)
                                    .hiveType(.caption2)
                                    .foregroundStyle(.hiveGraphite)
                                    .lineLimit(2)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, HiveSpacing.s8)
                        .padding(.vertical, HiveSpacing.s4)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.r8)
                                .fill(state.activeAccentColor.opacity(0.08))
                        )
                    }
                }
            }
        }
    }

    // MARK: - Preferences

    @ViewBuilder
    private var preferencesSection: some View {
        if !preferenceNodes.isEmpty {
            sectionHeader(icon: "person.crop.circle.badge.checkmark", title: "Preferences")
            LazyVStack(alignment: .leading, spacing: HiveSpacing.s4) {
                ForEach(preferenceNodes.prefix(4), id: \.id) { node in
                    preferenceRow(node)
                }
            }
        }
    }

    private func preferenceRow(_ node: HoneycombStore.Node) -> some View {
        HStack(spacing: HiveSpacing.s8) {
            Image(systemName: "heart.fill")
                .font(HiveTypography.font(.microTiny))
                .foregroundStyle(state.activeAccentColor)
            Text(node.label)
                .hiveType(.bodySmall)
                .foregroundStyle(.hiveInk)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, HiveSpacing.s8)
        .padding(.vertical, HiveSpacing.s4)
        .background(
            RoundedRectangle(cornerRadius: HiveRadius.r8)
                .fill(state.activeAccentColor.opacity(0.06))
        )
        .contextMenu {
            Button("Forget this preference") {
                Task {
                    try? await state.honeycomb?.deleteNode(id: node.id)
                    await loadAll()
                }
            }
        }
    }

    // MARK: - Recent memory

    @ViewBuilder
    private var recentSection: some View {
        if !recentNodes.isEmpty {
            sectionHeader(icon: "clock.arrow.circlepath", title: "Today's Memory")
            LazyVStack(alignment: .leading, spacing: HiveSpacing.s4) {
                ForEach(recentNodes.prefix(6), id: \.id) { node in
                    memoryRow(node)
                }
            }
        } else {
            VStack(spacing: HiveSpacing.s8) {
                Image(systemName: "memorychip")
                    .font(HiveTypography.font(.featureTitle))
                    .foregroundStyle(.hiveMist)
                Text("Nothing captured yet.")
                    .hiveType(.bodySmall)
                    .foregroundStyle(.hiveGraphite)
                Text("Capture pages as you browse and Hive will build your memory here.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HiveSpacing.s16)
        }
    }

    @ViewBuilder
    private func memoryRow(_ node: HoneycombStore.Node) -> some View {
        // Sources/captures navigate; notes/preferences load into the chat as context.
        let isNavigable = node.type == .source || node.type == .capture
        let isHovered = hoveredNodeID == node.id
        Button {
            if isNavigable, let url = nodeURL(from: node), let nsurl = URL(string: url) {
                state.newTab(url: nsurl)
            } else {
                loadNodeInChat(node)
            }
        } label: {
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: icon(for: node.type))
                    .font(HiveTypography.font(.microMedium))
                    .foregroundStyle(accent(for: node.type))
                    .frame(width: 16)
                VStack(alignment: .leading, spacing: 1) {
                    Text(node.label)
                        .hiveType(.bodySmall)
                        .foregroundStyle(.hiveInk)
                        .lineLimit(1)
                    Text(relativeDate(node.createdAt))
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveMist)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, HiveSpacing.s8)
            .padding(.vertical, HiveSpacing.s4)
            .background(
                RoundedRectangle(cornerRadius: HiveRadius.r6)
                    .fill(Color.hiveSurface.opacity(isHovered ? 0.5 : 0))
            )
            .contentShape(Rectangle())
            .animation(.hiveMicro, value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            hoveredNodeID = hovering ? node.id : nil
        }
    }

    // MARK: - Knowledge overview

    private var knowledgeSection: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            sectionHeader(icon: "hexagon", title: "Knowledge")

            let total = nodeCounts.values.reduce(0, +)
            if total == 0 {
                Text("No knowledge stored yet — capture a page to begin.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
            } else {
                // Compact 2-column count grid.
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: HiveSpacing.s4) {
                    ForEach(knowledgeRows) { row in
                        HStack(spacing: HiveSpacing.s4) {
                            Circle()
                                .fill(row.color)
                                .frame(width: 6, height: 6)
                            Text(row.title)
                                .hiveType(.caption2)
                                .foregroundStyle(.hiveGraphite)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            Text("\(row.count)")
                                .hiveType(.caption2)
                                .foregroundStyle(.hiveInk)
                                .monospacedDigit()
                        }
                        .padding(.horizontal, HiveSpacing.s8)
                        .padding(.vertical, HiveSpacing.s4)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.r6)
                                .fill(Color.hiveSurface.opacity(0.35))
                        )
                    }
                }
                .animation(.hiveMicro, value: total)
            }
        }
    }

    private var knowledgeRows: [KnowledgeRow] {
        let interesting: [HoneycombStore.NodeType] = [.source, .capture, .claim, .brief, .note, .preference]
        var rows: [KnowledgeRow] = []
        for type in interesting {
            let count = nodeCounts[type] ?? 0
            if count > 0 {
                rows.append(KnowledgeRow(title: typeLabel(type), count: count, color: accent(for: type)))
            }
        }
        return rows
    }

    // MARK: - Recent briefs

    @ViewBuilder
    private var briefsSection: some View {
        if !recentBriefs.isEmpty {
            sectionHeader(icon: "doc.text", title: "Recent Briefs")
            LazyVStack(alignment: .leading, spacing: HiveSpacing.s4) {
                ForEach(recentBriefs.prefix(3), id: \.id) { brief in
                    let isHovered = hoveredBriefID == brief.id
                    Button {
                        state.loadBriefIntoContext(brief)
                    } label: {
                        HStack(spacing: HiveSpacing.s8) {
                            Image(systemName: "doc.text")
                                .font(HiveTypography.font(.microMedium))
                                .foregroundStyle(state.activeAccentColor)
                                .frame(width: 16)
                            Text(brief.title)
                                .hiveType(.bodySmall)
                                .foregroundStyle(.hiveInk)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            if !brief.sourceIDs.isEmpty {
                                Image(systemName: "link")
                                    .font(.system(size: 7))
                                    .foregroundStyle(.hiveAccent)
                            }
                        }
                        .padding(.horizontal, HiveSpacing.s8)
                        .padding(.vertical, HiveSpacing.s4)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.r6)
                                .fill(Color.hiveSurface.opacity(isHovered ? 0.5 : 0))
                        )
                        .contentShape(Rectangle())
                        .animation(.hiveMicro, value: isHovered)
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        hoveredBriefID = hovering ? brief.id : nil
                    }
                }
            }
        }
    }

    // MARK: - Shared bits

    private func sectionHeader(icon: String, title: String) -> some View {
        HStack(spacing: HiveSpacing.s4) {
            Image(systemName: icon)
                .font(HiveTypography.font(.microMedium))
                .foregroundStyle(.hiveGraphite)
            Text(title)
                .hiveType(.caption2)
                .foregroundStyle(.hiveInk.opacity(0.8))
        }
    }

    // MARK: - Capture action

    private func capture() {
        let text = captureText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, let hc = state.honeycomb else { return }

        // Truncate the label, keep full content in metadata.
        let label = String(text.prefix(80))
        let node = HoneycombStore.Node(
            type: .note,
            label: label,
            metadata: .object(["content": .string(text)]),
            contentHash: HoneycombStore.sha256("note|" + text),
            provenance: "user"
        )

        Task {
            _ = try? await hc.insertNode(node)
            await MainActor.run {
                captureText = ""
                withAnimation(reduceMotion ? nil : .hiveMicro) {
                    captureFlash = true
                }
                Task {
                    try? await Task.sleep(nanoseconds: 1_500_000_000)
                    await MainActor.run {
                        withAnimation(reduceMotion ? nil : .hiveMicro) { captureFlash = false }
                    }
                }
            }
            await loadAll()
        }
    }

    // MARK: - Loading

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }
        guard let hc = state.honeycomb else { return }

        // Recent memory: sources + captures + notes (preferences are shown in their
        // own section — excluding them here avoids rendering the same node twice).
        var nodes: [HoneycombStore.Node] = []
        for type in [HoneycombStore.NodeType.source, .capture, .note] {
            let typed = (try? await hc.getNodesByType(type, limit: 8)) ?? []
            nodes.append(contentsOf: typed)
        }
        nodes.sort { $0.createdAt > $1.createdAt }
        recentNodes = Array(nodes.prefix(8))

        // All preferences, minus the ones already surfaced in the "Related"
        // section (avoid rendering the same rule twice).
        let allPrefs = (try? await hc.getNodesByType(.preference, limit: 50)) ?? []
        let relatedIDs = Set(relatedPreferences.map { $0.id })
        preferenceNodes = allPrefs.filter { !relatedIDs.contains($0.id) }

        // Per-type counts for the knowledge grid.
        var counts: [HoneycombStore.NodeType: Int] = [:]
        for type in HoneycombStore.NodeType.allCases {
            counts[type] = (try? await hc.countNodes(type: type)) ?? 0
        }
        nodeCounts = counts

        // Recent briefs.
        if let store = state.briefStore {
            recentBriefs = (try? await store.list(limit: 5)) ?? []
        }

        // Preferences relevant to the current page — the "Heads Up" surface.
        await refreshRelevance(hc: hc)
    }

    /// Re-queries preference relevance for the active page. Cheap (1000-node scan
    /// capped) so it can run on every tab switch.
    private func refreshRelevance(hc: HoneycombStore? = nil) async {
        guard let honeycomb = hc ?? state.honeycomb else {
            relatedPreferences = []
            return
        }
        let pageQuery = [state.activeTab?.displayTitle, state.activeTab?.url?.host]
            .compactMap { $0 }
            .joined(separator: " ")
        if pageQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            relatedPreferences = []
        } else {
            relatedPreferences = await PreferenceMemoryBridge.relevantPreferences(
                for: pageQuery, from: honeycomb
            )
        }
    }

    // MARK: - Helpers

    private func nodeURL(from node: HoneycombStore.Node) -> String? {
        guard case .object(let dict) = node.metadata,
              case .string(let url) = dict["url"] else { return nil }
        return url
    }

    private func relativeDate(_ date: Date) -> String {
        Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    /// Loads a memory node's content into the Swarm chat as an assistant message,
    /// so notes and preferences are inspectable without leaving the workspace.
    private func loadNodeInChat(_ node: HoneycombStore.Node) {
        state.isSwarmOpen = true
        let content: String = {
            if case .object(let dict) = node.metadata,
               case .string(let text) = dict["content"] {
                return text
            }
            return node.label
        }()
        state.swarmMessages.append(SwarmMessage(
            role: .assistant,
            content: "# \(node.label)\n\n\(content)",
            scope: .memory,
            providerLabel: "Memory — \(node.type.rawValue.capitalized)"
        ))
    }

    private func icon(for type: HoneycombStore.NodeType) -> String {
        switch type {
        case .source:   return "link"
        case .capture:  return "doc.richtext"
        case .note:     return "note.text"
        case .preference: return "heart.fill"
        case .claim:    return "quote.opening"
        case .brief:    return "doc.text"
        case .artifact: return "doc.badge.gearshape"
        default:        return "circle.fill"
        }
    }

    private func accent(for type: HoneycombStore.NodeType) -> Color {
        switch type {
        case .source, .claim:   return .hiveAccent
        case .capture, .note:   return .hiveGraphite
        case .preference:       return state.activeAccentColor
        default:                return .hiveMist
        }
    }

    private func typeLabel(_ type: HoneycombStore.NodeType) -> String {
        switch type {
        case .source:    return "Sources"
        case .capture:   return "Captures"
        case .claim:     return "Claims"
        case .brief:     return "Briefs"
        case .note:      return "Notes"
        case .preference: return "Preferences"
        default:         return type.rawValue.capitalized
        }
    }
}

// MARK: - KnowledgeRow

private struct KnowledgeRow: Identifiable {
    let id = UUID()
    let title: String
    let count: Int
    let color: Color
}
