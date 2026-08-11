import SwiftUI
import HiveCore

// MARK: - SearchEngineManagerPanel

/// Manage the default search engine, view all built-in engines, and
/// add/remove custom search engines with URL templates.
struct SearchEngineManagerPanel: View {
    @Environment(BrowserState.self) private var state
    @State private var query: String = ""
    @State private var showAddForm: Bool = false
    @State private var newName: String = ""
    @State private var newTemplate: String = ""
    @State private var newKeyword: String = ""
    @State private var templateError: String?

    private var allEngines: [EngineItem] {
        let builtin = BrowserState.SearchEngine.allCases.map { EngineItem.builtIn($0) }
        let custom = state.customSearchEngines.map { EngineItem.custom($0) }
        let combined = builtin + custom
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return combined }
        return combined.filter { $0.name.lowercased().contains(q) || $0.host.lowercased().contains(q) }
    }

    enum EngineItem: Identifiable {
        case builtIn(BrowserState.SearchEngine)
        case custom(BrowserState.CustomSearchEngine)

        var id: String {
            switch self {
            case .builtIn(let e): return "builtin:" + e.rawValue
            case .custom(let c): return "custom:" + c.id
            }
        }

        var name: String {
            switch self {
            case .builtIn(let e): return e.rawValue
            case .custom(let c): return c.name
            }
        }

        var host: String {
            switch self {
            case .builtIn(let e): return URL(string: e.searchURL)?.host ?? ""
            case .custom(let c): return c.displayHost
            }
        }

        var icon: String {
            switch self {
            case .builtIn(let e): return e.icon
            case .custom: return "magnifyingglass"
            }
        }

        var color: Color {
            switch self {
            case .builtIn(let e): return e.color
            case .custom: return .secondary
            }
        }

        var isBuiltIn: Bool {
            switch self { case .builtIn: return true; case .custom: return false }
        }

        var keyword: String? {
            switch self {
            case .builtIn: return nil
            case .custom(let c): return c.keyword
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if allEngines.isEmpty {
                emptyState
            } else {
                engineList
            }
            if showAddForm {
                addForm
            }
            Divider()
            footer
        }
        .background(HiveDesign.Material.panel)
        .frame(width: 480, height: 440)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass.circle")
                .font(HiveDesign.Typography.panelTitleMedium)
                .foregroundStyle(.secondary)

            TextField("Filter engines...", text: $query)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.subHeading)

            if !query.isEmpty {
                Button(action: { query = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                showAddForm.toggle()
                if showAddForm { newName = ""; newTemplate = ""; newKeyword = ""; templateError = nil }
            }) {
                Label(showAddForm ? "Cancel" : "Add Engine", systemImage: showAddForm ? "xmark" : "plus")
                    .font(HiveDesign.Typography.smallLabelBold)
                    .foregroundStyle(showAddForm ? Color.secondary : Color.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(showAddForm ? Color.clear : HiveDesign.Accent.primary)
                    .overlay(showAddForm ? RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)) : nil)
                    .clipShape(RoundedRectangle(cornerRadius: HiveDesign.Radius.md, style: .continuous))
            }
            .buttonStyle(.plain)
            .help("Add a custom search engine")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Add Form

    private var addForm: some View {
        VStack(spacing: 8) {
            TextField("Name (e.g. My Search)", text: $newName)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.smallLabelMedium)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(HiveDesign.Surface.level1)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            TextField("URL with {query} (e.g. https://example.com/search?q={query})", text: $newTemplate)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.monoMicro)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(HiveDesign.Surface.level1)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .onChange(of: newTemplate) { _, _ in templateError = nil }

            TextField("Keyword (optional, e.g. yt → type \"yt kittens\" in the address bar)", text: $newKeyword)
                .textFieldStyle(.plain)
                .font(HiveDesign.Typography.smallLabelMedium)
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(HiveDesign.Surface.level1)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            if let error = templateError {
                Text(error)
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.red)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("Add") { addCustomEngine() }
                    .font(HiveDesign.Typography.smallLabelBold)
                    .buttonStyle(.borderedProminent)
                    .tint(HiveDesign.Accent.primary)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || newTemplate.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(HiveDesign.Surface.level1)
    }

    // MARK: - List

    private var engineList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                ForEach(allEngines) { item in
                    EngineRow(
                        item: item,
                        isSelected: item.isBuiltIn
                            ? (state.searchEngine.rawValue == item.name && state.activeCustomSearchEngineID == nil)
                            : (state.activeCustomSearchEngineID == item.id),
                        onSelect: {
                            switch item {
                            case .builtIn(let e):
                                state.searchEngine = e
                                state.activeCustomSearchEngineID = nil
                                state.scheduleAutosave()
                            case .custom(let c):
                                state.activeCustomSearchEngineID = c.id
                                state.scheduleAutosave()
                            }
                        },
                        onRemove: {
                            if case .custom(let c) = item {
                                removeCustomEngine(c)
                            }
                        },
                        onKeywordChange: { newKeyword in
                            if case .custom(let c) = item {
                                updateCustomEngineKeyword(c, to: newKeyword)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No matching engines")
                .font(HiveDesign.Typography.bodyMedium)
                .foregroundStyle(.secondary)
            Text("Try a different name or add a custom engine")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            Text("\(allEngines.count) engine\(allEngines.count == 1 ? "" : "s")")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Built-in engines cannot be removed")
                .font(HiveDesign.Typography.buttonCaption)
                .foregroundStyle(.tertiary)
            Button("Done") { state.isSearchEngineManagerPanelOpen = false }
                .font(HiveDesign.Typography.smallLabelBold)
                .buttonStyle(.borderedProminent)
                .tint(HiveDesign.Accent.primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: - Actions

    private func addCustomEngine() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = newTemplate.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !name.isEmpty, !template.isEmpty else { return }
        guard template.contains("{query}") else {
            templateError = "Template must include {query} placeholder"
            return
        }
        // Reuses the HiveCore policy so the add form and the omnibox resolver
        // validate identically (the policy also rejects non-http(s) schemes).
        guard SiteSearchKeywordPolicy.isValidTemplate(template) else {
            templateError = "Invalid URL template"
            return
        }

        var engines = state.customSearchEngines
        let engine = BrowserState.CustomSearchEngine(
            id: UUID().uuidString,
            name: name,
            template: template,
            keyword: SiteSearchKeywordPolicy.normalizedKeyword(newKeyword)
        )
        engines.append(engine)
        state.customSearchEngines = engines
        state.scheduleAutosave()

        showAddForm = false
        newName = ""
        newTemplate = ""
        newKeyword = ""
        templateError = nil
    }

    private func removeCustomEngine(_ engine: BrowserState.CustomSearchEngine) {
        var engines = state.customSearchEngines
        engines.removeAll { $0.id == engine.id }
        state.customSearchEngines = engines
        if state.activeCustomSearchEngineID == engine.id {
            state.activeCustomSearchEngineID = nil
        }
        state.scheduleAutosave()
    }

    private func updateCustomEngineKeyword(_ engine: BrowserState.CustomSearchEngine, to raw: String) {
        guard let index = state.customSearchEngines.firstIndex(where: { $0.id == engine.id }) else { return }
        state.customSearchEngines[index].keyword = SiteSearchKeywordPolicy.normalizedKeyword(raw)
        state.scheduleAutosave()
    }
}

// MARK: - EngineRow

private struct EngineRow: View {
    let item: SearchEngineManagerPanel.EngineItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onRemove: () -> Void
    let onKeywordChange: (String) -> Void

    @State private var isHovered: Bool = false
    @State private var keywordDraft: String = ""
    @State private var isEditingKeyword: Bool = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(HiveDesign.Typography.panelTitleMedium)
                .foregroundStyle(item.color)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(HiveDesign.Typography.bodyMedium)
                    .foregroundStyle(.primary)
                Text(item.host)
                    .font(HiveDesign.Typography.buttonCaption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Text("DEFAULT")
                    .font(HiveDesign.Typography.microTinyBold)
                    .foregroundStyle(HiveDesign.Accent.primary)
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(HiveDesign.Accent.muted)
                    .clipShape(Capsule())
            }

            if !item.isBuiltIn, isHovered {
                // Chrome-style keyword chip: shows the keyword when set, and
                // clicking opens an inline edit field (empty clears it).
                if isEditingKeyword {
                    TextField("keyword", text: $keywordDraft)
                        .textFieldStyle(.plain)
                        .font(HiveDesign.Typography.monoMicro)
                        .frame(width: 72)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(HiveDesign.Surface.level1)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .onSubmit { commitKeyword() }
                        .onExitCommand { commitKeyword() }
                } else {
                    Button {
                        keywordDraft = item.keyword ?? ""
                        isEditingKeyword = true
                    } label: {
                        Text(item.keyword?.isEmpty == false ? item.keyword! : "+ kw")
                            .font(HiveDesign.Typography.microTinyBold)
                            .foregroundStyle(item.keyword?.isEmpty == false ? HiveDesign.Accent.primary : HiveDesign.Text.tertiary)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(item.keyword?.isEmpty == false ? HiveDesign.Accent.muted : Color.clear)
                            .overlay(
                                item.keyword?.isEmpty == false
                                    ? nil
                                    : RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3))
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    .buttonStyle(.plain)
                    .help("Keyword: type \"\(item.keyword ?? "kw")\" + query in the address bar to search this site")
                }

                Button(action: onRemove) {
                    Image(systemName: "trash")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.red.opacity(0.8))
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Remove custom engine")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: HiveDesign.Radius.lg, style: .continuous)
                .fill(isSelected ? HiveDesign.Accent.muted : (isHovered ? HiveDesign.Surface.level1 : Color.clear))
        )
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
    }

    private func commitKeyword() {
        onKeywordChange(keywordDraft)
        isEditingKeyword = false
    }
}
