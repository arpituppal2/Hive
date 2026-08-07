import SwiftUI
import HiveCore
import os.log

// MARK: - SwarmWorkspaceView
//
// Obsidian-style knowledge sidebar for the Swarm panel. Three tabs mirror
// Honeycomb's typed node model:
//
//   Projects — active containers for related work (sources, briefs, tasks)
//   Briefs   — saved research outputs with linked sources
//   Sources  — captured pages with metadata and extraction text
//
// Tapping an item opens it in the chat context (detail view for briefs,
// context injection for projects/sources). The sidebar is the durable
// knowledge navigator that turns Swarm from "just a chat" into "your
// second-brain browser."
//
// Design: industrial instrument-panel. Hairline borders, tabular data,
// minimal chrome, dark-first. Matches the Hive design tokens (§5 SPEC.md).

struct SwarmWorkspaceView: View {

    @Environment(ChromeState.self) private var state

    @State private var selectedTab: WorkspaceTab = .home
    @State private var projects: [Project] = []
    @State private var briefs: [Brief] = []
    @State private var sources: [HoneycombStore.Node] = []
    @State private var searchText: String = ""
    @State private var isLoading: Bool = false
    @State private var selectedBrief: Brief?
    @State private var selectedProject: Project?
    /// Which knowledge row is hovered, for the Chrome-class row wash.
    @State private var hoveredRowID: String? = nil

    private static let log = Logger(subsystem: "com.hive.browser", category: "SwarmWorkspace")

    // Shared formatter — per-call construction was the same perf anti-pattern
    // fixed on StartPage / SwarmHome / TabOverview / ArchivedShelf / History.
    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f
    }()

    var body: some View {
        VStack(spacing: 0) {
            headerView
            tabPicker
            Divider().overlay(Color.hiveBorderSubtle)

            if !searchText.isEmpty {
                searchField
            }

            if isLoading {
                Spacer()
                ProgressView().progressViewStyle(.circular)
                Spacer()
            } else {
                contentList
            }

            Divider().overlay(Color.hiveBorderSubtle)
            footerView
        }
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
        .background(Color.hiveBackground)
        .task { await loadAll() }
        .onChange(of: state.isSwarmOpen) { _, open in
            if open { Task { await loadAll() } }
        }
        .sheet(item: $selectedBrief) { brief in
            briefDetailSheet(brief)
                .frame(width: 600, height: 500)
        }
        .sheet(item: $selectedProject) { project in
            projectDetailSheet(project)
                .frame(width: 600, height: 500)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: HiveSpacing.s4) {
            Image(systemName: "chart.node")
                .font(HiveTypography.font(.bodyMedium))
                .foregroundStyle(state.activeAccentColor)
            Text("Workspace")
                .hiveType(.chromeLabel)
                .foregroundStyle(.hiveInk)
            Spacer()
            Text("\(totalCount)")
                .hiveType(.caption2)
                .foregroundStyle(.hiveMist)
                .monospacedDigit()
        }
        .padding(.horizontal, HiveSpacing.s8)
        .padding(.vertical, HiveSpacing.s8)
    }

    // MARK: - Tab Picker

    private var tabPicker: some View {
        HStack(spacing: 0) {
            ForEach(WorkspaceTab.allCases) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 3) {
                        HStack(spacing: 4) {
                            Image(systemName: tab.icon)
                                .font(HiveTypography.font(.microMedium))
                            Text(tab.label)
                                .hiveType(.caption2)
                            if tab != .home {
                                Text("\(count(for: tab))")
                                    .hiveType(.caption2)
                                    .foregroundStyle(.hiveMist)
                                    .monospacedDigit()
                            }
                        }
                        .foregroundStyle(selectedTab == tab ? state.activeAccentColor : .hiveGraphite)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 8)

                        Rectangle()
                            .fill(selectedTab == tab ? state.activeAccentColor : Color.clear)
                            .frame(height: 2)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, HiveSpacing.s4)
    }

    // MARK: - Search

    private var searchField: some View {
        HStack(spacing: HiveSpacing.s4) {
            Image(systemName: "magnifyingglass")
                .font(HiveTypography.font(.caption3))
                .foregroundStyle(.hiveGraphite)
            TextField("Filter \(selectedTab.label)...", text: $searchText)
                .textFieldStyle(.plain)
                .hiveType(.bodySmall)
        }
        .padding(HiveSpacing.s4)
        .background(RoundedRectangle(cornerRadius: HiveRadius.r6).stroke(Color.hiveBorderSubtle))
        .padding(.horizontal, HiveSpacing.s8)
        .padding(.vertical, HiveSpacing.s4)
    }

    // MARK: - Content List

    @ViewBuilder
    private var contentList: some View {
        if selectedTab == .home {
            // Home renders its own scroll + capture surface; never nest scrolls.
            SwarmHomeView()
        } else if isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: HiveSpacing.s4) {
                    switch selectedTab {
                    case .home:
                        EmptyView()
                    case .projects:
                        ForEach(Array(filteredProjects.enumerated()), id: \.element.id) { index, project in
                            projectRow(project)
                            if index < filteredProjects.count - 1 { rowDivider }
                        }
                    case .briefs:
                        ForEach(Array(filteredBriefs.enumerated()), id: \.element.id) { index, brief in
                            briefRow(brief)
                            if index < filteredBriefs.count - 1 { rowDivider }
                        }
                    case .sources:
                        ForEach(Array(filteredSources.enumerated()), id: \.element.id) { index, source in
                            sourceRow(source)
                            if index < filteredSources.count - 1 { rowDivider }
                        }
                    }
                }
                .padding(.vertical, HiveSpacing.s4)
            }
        }
    }

    private var rowDivider: some View {
        Divider()
            .overlay(Color.hiveBorderSubtle.opacity(0.4))
            .padding(.leading, HiveSpacing.s8)
    }

    // MARK: - Project Row

    private func projectRow(_ project: Project) -> some View {
        let isHovered = hoveredRowID == project.id
        return Button {
            selectedProject = project
        } label: {
            HStack(spacing: HiveSpacing.s8) {
                Circle()
                    .fill(lifecycleColor(project.lifecycle))
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 2) {
                    Text(project.title)
                        .hiveType(.bodySmall)
                        .foregroundStyle(.hiveInk)
                        .lineLimit(1)
                    if !project.purpose.isEmpty {
                        Text(project.purpose)
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveGraphite)
                            .lineLimit(1)
                    }
                }
                Spacer()
                if project.lifecycle == .archived {
                    Text("ARCHIVED")
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveMist)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(
                            RoundedRectangle(cornerRadius: HiveRadius.r3)
                                .stroke(Color.hiveBorderSubtle, lineWidth: 0.5)
                        )
                }
                Text(project.createdAt, style: .date)
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
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
            hoveredRowID = hovering ? project.id : nil
        }
        .contextMenu {
            Button("Delete Project") {
                Task {
                    guard let hc = state.honeycomb else { return }
                    _ = try? await hc.deleteProject(id: project.id)
                    await loadAll()
                }
            }
        }
    }

    // MARK: - Brief Row

    private func briefRow(_ brief: Brief) -> some View {
        let isHovered = hoveredRowID == brief.id
        return Button {
            selectedBrief = brief
        } label: {
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: "doc.text")
                    .font(HiveTypography.font(.captionMedium))
                    .foregroundStyle(state.activeAccentColor)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(brief.title)
                        .hiveType(.bodySmall)
                        .foregroundStyle(.hiveInk)
                        .lineLimit(1)
                    Text(brief.content.prefix(80).replacingOccurrences(of: "\n", with: " "))
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveGraphite)
                        .lineLimit(1)
                }
                Spacer()
                HStack(spacing: 3) {
                    if !brief.sourceIDs.isEmpty {
                        Image(systemName: "link")
                            .font(HiveTypography.font(.microTiny))
                        Text("\(brief.sourceIDs.count)")
                            .hiveType(.caption2)
                            .monospacedDigit()
                    }
                }
                .foregroundStyle(.hiveAccent)
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
            hoveredRowID = hovering ? brief.id : nil
        }
        .contextMenu {
            Button("Load in Chat") {
                state.loadBriefIntoContext(brief)
            }
            Button("Delete Brief") {
                Task {
                    try? await state.briefStore?.delete(id: brief.id)
                    await loadAll()
                }
            }
        }
    }

    // MARK: - Source Row

    private func sourceRow(_ source: HoneycombStore.Node) -> some View {
        let isHovered = hoveredRowID == source.id
        return Button {
            if let url = sourceURL(from: source), let nsurl = URL(string: url) {
                state.newTab(url: nsurl)
            }
        } label: {
            HStack(spacing: HiveSpacing.s8) {
                Image(systemName: "link")
                    .font(HiveTypography.font(.caption3Medium))
                    .foregroundStyle(.hiveAccent)
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.label)
                        .hiveType(.bodySmall)
                        .foregroundStyle(.hiveInk)
                        .lineLimit(1)
                    if let url = sourceURL(from: source) {
                        Text(urlShortHost(url))
                            .hiveType(.caption2)
                            .foregroundStyle(.hiveGraphite)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Text(relativeDate(source.createdAt))
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
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
            hoveredRowID = hovering ? source.id : nil
        }
        .contextMenu {
            Button("Delete Source") {
                Task {
                    try? await state.honeycomb?.deleteNode(id: source.id)
                    await loadAll()
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: HiveSpacing.s12) {
            Image(systemName: selectedTab.emptyIcon)
                .font(.system(size: 28))
                .foregroundStyle(.hiveMist)
            Text(selectedTab.emptyTitle)
                .hiveType(.bodySmall)
                .foregroundStyle(.hiveGraphite)
                .multilineTextAlignment(.center)
            Text(selectedTab.emptyHint)
                .hiveType(.caption2)
                .foregroundStyle(.hiveMist)
                .multilineTextAlignment(.center)
                .padding(.horizontal, HiveSpacing.s16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(HiveSpacing.s32)
    }

    // MARK: - Detail Sheets

    private func briefDetailSheet(_ brief: Brief) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(brief.title)
                        .hiveType(.chromeTitle)
                        .foregroundStyle(.hiveInk)
                    Text("Saved \(brief.createdAt, style: .date) · \(brief.sourceIDs.count) source\(brief.sourceIDs.count == 1 ? "" : "s")")
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveGraphite)
                }
                Spacer()
                Button("Done") { selectedBrief = nil }
                    .buttonStyle(.plain)
                    .foregroundStyle(state.activeAccentColor)
                Button {
                    state.loadBriefIntoContext(brief)
                    selectedBrief = nil
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.turn.down.left")
                            .font(HiveTypography.font(.caption3))
                        Text("Load in Chat")
                            .hiveType(.caption2)
                    }
                    .foregroundStyle(state.activeAccentColor)
                }
                .buttonStyle(.plain)
            }
            .padding(HiveSpacing.s12)

            Divider().overlay(Color.hiveBorderSubtle)

            ScrollView {
                if let attributed = try? AttributedString(
                    markdown: brief.content,
                    options: AttributedString.MarkdownParsingOptions(
                        interpretedSyntax: .inlineOnlyPreservingWhitespace
                    )
                ) {
                    Text(attributed)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(HiveSpacing.s12)
                } else {
                    Text(brief.content)
                        .hiveType(.body)
                        .foregroundStyle(.hiveInk)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(HiveSpacing.s12)
                }

                // Linked sources — every claim traceable to stored evidence (§7.3).
                BriefSourcesList(briefID: brief.id)
                    .padding(.horizontal, HiveSpacing.s12)
                    .padding(.bottom, HiveSpacing.s16)
            }
        }
        .background(Color.hiveBackground)
    }

    private func projectDetailSheet(_ project: Project) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(lifecycleColor(project.lifecycle))
                            .frame(width: 8, height: 8)
                        Text(project.title)
                            .hiveType(.chromeTitle)
                            .foregroundStyle(.hiveInk)
                    }
                    if !project.purpose.isEmpty {
                        Text(project.purpose)
                            .hiveType(.bodySmall)
                            .foregroundStyle(.hiveGraphite)
                    }
                }
                Spacer()
                Button("Done") { selectedProject = nil }
                    .buttonStyle(.plain)
                    .foregroundStyle(state.activeAccentColor)
            }
            .padding(HiveSpacing.s12)

            Divider().overlay(Color.hiveBorderSubtle)

            ProjectTaskListView(projectID: project.id)
        }
        .background(Color.hiveBackground)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack(spacing: HiveSpacing.s4) {
            Image(systemName: "square.and.pencil")
                .font(HiveTypography.font(.caption3))
                .foregroundStyle(.hiveGraphite)
            Button("New Project") {
                createProject()
            }
            .hiveType(.caption2)
            .foregroundStyle(state.activeAccentColor)
            .buttonStyle(.plain)
            Spacer()
            Text(state.honeycomb != nil ? "Honeycomb" : "Memory")
                .hiveType(.caption2)
                .foregroundStyle(.hiveMist)
        }
        .padding(.horizontal, HiveSpacing.s8)
        .padding(.vertical, HiveSpacing.s4)
    }

    // MARK: - Helpers

    private var filteredProjects: [Project] {
        guard !searchText.isEmpty else { return projects }
        return projects.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    private var filteredBriefs: [Brief] {
        guard !searchText.isEmpty else { return briefs }
        return briefs.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.content.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredSources: [HoneycombStore.Node] {
        guard !searchText.isEmpty else { return sources }
        return sources.filter {
            $0.label.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredItems: Int {
        switch selectedTab {
        case .home:     return 1 // home is never "empty" — it has capture + guidance
        case .projects: return filteredProjects.count
        case .briefs:   return filteredBriefs.count
        case .sources:  return filteredSources.count
        }
    }

    private var isEmpty: Bool { filteredItems == 0 }

    private var totalCount: Int { projects.count + briefs.count + sources.count }

    private func count(for tab: WorkspaceTab) -> Int {
        switch tab {
        case .home:     return 0
        case .projects: return projects.count
        case .briefs:   return briefs.count
        case .sources:  return sources.count
        }
    }

    private func sourceURL(from source: HoneycombStore.Node) -> String? {
        honeycombNodeURL(from: source)
    }

    private func urlShortHost(_ url: String) -> String {
        URL(string: url)?.host ?? url
    }

    private func relativeDate(_ date: Date) -> String {
        Self.relativeFormatter.localizedString(for: date, relativeTo: Date())
    }

    private func lifecycleColor(_ lifecycle: Project.Lifecycle) -> Color {
        lifecycle == .active ? state.activeAccentColor : .hiveMist
    }

    private func loadAll() async {
        isLoading = true
        defer { isLoading = false }

        // Projects from Honeycomb (extension methods)
        if let hc = state.honeycomb {
            projects = (try? await hc.getAllProjects()) ?? []
        }

        // Briefs from BriefStore actor
        if let store = state.briefStore {
            briefs = (try? await store.list(limit: 50)) ?? []
        }

        // Recent sources from Honeycomb
        if let hc = state.honeycomb {
            sources = (try? await hc.getNodesByType(.source, limit: 30)) ?? []
        }
    }

    private func createProject() {
        let alert = NSAlert()
        alert.messageText = "New Project"
        alert.informativeText = "Enter a name for the new project."
        alert.addButton(withTitle: "Create")
        alert.addButton(withTitle: "Cancel")

        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        input.placeholderString = "Project name"
        alert.accessoryView = input
        alert.window.initialFirstResponder = input

        if alert.runModal() == .alertFirstButtonReturn {
            let title = input.stringValue.trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty, let hc = state.honeycomb else { return }
            let project = Project(title: title)
            Task {
                _ = try? await hc.createProject(project)
                await loadAll()
            }
        }
    }
}

// MARK: - BriefSourcesList

/// Loads and renders the Source objects linked to a Brief via `.references` edges.
/// Each row shows title/URL, capture method, and retrieval date — the provenance
/// every generated brief must expose (AGENTS.md §11.1).
private struct BriefSourcesList: View {
    let briefID: String
    @Environment(ChromeState.self) private var state
    @State private var sourceNodes: [HoneycombStore.Node] = []
    @State private var isLoading = false

    var body: some View {
        VStack(alignment: .leading, spacing: HiveSpacing.s8) {
            HStack(spacing: HiveSpacing.s4) {
                Image(systemName: "link")
                    .font(HiveTypography.font(.caption3Medium))
                    .foregroundStyle(state.activeAccentColor)
                Text("Sources")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveInk.opacity(0.8))
                Spacer()
                if !sourceNodes.isEmpty {
                    Text("\(sourceNodes.count)")
                        .hiveType(.caption2)
                        .foregroundStyle(.hiveMist)
                        .monospacedDigit()
                }
            }

            if isLoading {
                ProgressView().progressViewStyle(.circular).controlSize(.small)
            } else if sourceNodes.isEmpty {
                Text("No sources linked to this brief.")
                    .hiveType(.caption2)
                    .foregroundStyle(.hiveMist)
            } else {
                LazyVStack(alignment: .leading, spacing: HiveSpacing.s4) {
                    ForEach(Array(sourceNodes.enumerated()), id: \.element.id) { index, node in
                        let url = honeycombNodeURL(from: node) ?? node.label
                        Button {
                            if let nsurl = URL(string: url) {
                                state.newTab(url: nsurl)
                            }
                        } label: {
                            HStack(spacing: HiveSpacing.s8) {
                                Text("\(index + 1)")
                                    .hiveType(.caption2)
                                    .foregroundStyle(.hiveMist)
                                    .monospacedDigit()
                                    .frame(width: 18, alignment: .trailing)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(node.label)
                                        .hiveType(.bodySmall)
                                        .foregroundStyle(.hiveInk)
                                        .lineLimit(1)
                                    Text(url)
                                        .hiveType(.caption2)
                                        .foregroundStyle(.hiveGraphite)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right.square")
                                    .font(HiveTypography.font(.micro))
                                    .foregroundStyle(.hiveGraphite)
                            }
                            .padding(.horizontal, HiveSpacing.s8)
                            .padding(.vertical, HiveSpacing.s4)
                            .background(
                                RoundedRectangle(cornerRadius: HiveRadius.r6)
                                    .fill(Color.hiveSurfaceElevated.opacity(0.5))
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open source \(index + 1): \(node.label)")
                    }
                }
            }
        }
        .task {
            isLoading = true
            defer { isLoading = false }
            guard let hc = state.honeycomb else { return }
            // Follow the Brief's source edges to its Source nodes, then batch-fetch
            // all targets in one call (no N+1). The Hive-side BriefStore.save links
            // briefs to sources via `.derivedFrom` edges — match that relation so
            // the panel shows what the save path actually wrote.
            let edges = (try? await hc.getEdges(from: briefID, relation: .derivedFrom)) ?? []
            let targetIDs = edges.map { $0.targetID }
            let nodes = (try? await hc.getNodes(ids: targetIDs)) ?? []
            sourceNodes = nodes
        }
    }
}

// MARK: - Shared helper

/// Extracts the canonical `url` from a Honeycomb node's JSON metadata.
private func honeycombNodeURL(from node: HoneycombStore.Node) -> String? {
    guard case .object(let dict) = node.metadata,
          case .string(let url) = dict["url"] else { return nil }
    return url
}

// MARK: - WorkspaceTab

private enum WorkspaceTab: String, CaseIterable, Identifiable {
    case home
    case projects
    case briefs
    case sources

    var id: String { rawValue }

    var label: String {
        switch self {
        case .home:     return "Home"
        case .projects: return "Projects"
        case .briefs:   return "Briefs"
        case .sources:  return "Sources"
        }
    }

    var icon: String {
        switch self {
        case .home:     return "house"
        case .projects: return "folder"
        case .briefs:   return "doc.text"
        case .sources:  return "link"
        }
    }

    var emptyIcon: String {
        switch self {
        case .home:     return "house"
        case .projects: return "folder.badge.questionmark"
        case .briefs:   return "doc.text.magnifyingglass"
        case .sources:  return "link.badge.plus"
        }
    }

    var emptyTitle: String {
        switch self {
        case .home:     return ""
        case .projects: return "No projects yet"
        case .briefs:   return "No briefs yet"
        case .sources:  return "No sources captured"
        }
    }

    var emptyHint: String {
        switch self {
        case .home:
            return ""
        case .projects:
            return "Create a project to organize your research."
        case .briefs:
            return "Ask the Librarian a research question, then save the answer as a brief."
        case .sources:
            return "Sources are automatically captured when you browse and save pages."
        }
    }
}

// MARK: - Project Task List View

/// Loads and displays the tasks belonging to a project from Honeycomb.
private struct ProjectTaskListView: View {
    let projectID: String
    @Environment(ChromeState.self) private var state
    @State private var taskNodes: [HoneycombStore.Node] = []
    @State private var isLoading = false

    var body: some View {
        Group {
            if isLoading {
                Spacer()
                ProgressView().progressViewStyle(.circular)
                Spacer()
            } else if taskNodes.isEmpty {
                VStack(spacing: HiveSpacing.s8) {
                    Image(systemName: "checklist")
                        .font(HiveTypography.font(.featureTitle))
                        .foregroundStyle(.hiveMist)
                    Text("No tasks in this project")
                        .hiveType(.bodySmall)
                        .foregroundStyle(.hiveGraphite)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(HiveSpacing.s32)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: HiveSpacing.s4) {
                        ForEach(taskNodes, id: \.id) { node in
                            HStack(spacing: HiveSpacing.s8) {
                                Image(systemName: "circle")
                                    .font(HiveTypography.font(.microTiny))
                                    .foregroundStyle(.hiveAccent)
                                Text(node.label)
                                    .hiveType(.bodySmall)
                                    .foregroundStyle(.hiveInk)
                            }
                            .padding(.horizontal, HiveSpacing.s12)
                            .padding(.vertical, HiveSpacing.s4)
                        }
                    }
                    .padding(.vertical, HiveSpacing.s8)
                }
            }
        }
        .task {
            guard let hc = state.honeycomb else { return }
            isLoading = true
            let edgeNodes = (try? await hc.getEdges(
                from: projectID, relation: .belongsTo
            )) ?? []
            var nodes: [HoneycombStore.Node] = []
            for edge in edgeNodes {
                if let node = try? await hc.getNode(id: edge.targetID) {
                    nodes.append(node)
                }
            }
            taskNodes = nodes
            isLoading = false
        }
    }
}
