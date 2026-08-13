import SwiftUI
import AppKit
import HiveCore

/// Clean Tabs (Arc/Boost parity) — review duplicate and stale tabs, then
/// close the ones you don't want. Every candidate is pre-selected; pinned,
/// essential, private, and internal-chrome tabs never appear.
struct CleanTabsSheet: View {
    @Environment(BrowserState.self) private var state
    @State private var plan: TabCleanupPlanner.Plan = .init(duplicateGroups: [], staleTabs: [])
    @State private var excluded: Set<String> = []

    private var selectedCount: Int {
        plan.closeIDs.filter { !excluded.contains($0) }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            if plan.isEmpty { emptyState } else { candidateList }
            Divider()
            footer
        }
        .frame(width: 580, height: 440)
        .background(HiveDesign.Material.panel)
        .onAppear { plan = state.currentCleanupPlan() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .font(HiveDesign.Typography.dialogTitle)
                .foregroundStyle(Color.hiveAccent)

            Text("Clean Up Tabs")
                .font(HiveDesign.Typography.subHeadingBold)

            Spacer()

            Text(summaryText)
                .font(HiveDesign.Typography.smallLabelMedium)
                .foregroundStyle(.secondary)

            Button("Done") { state.closeCleanTabs() }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(Color.hiveAccent)
                .accessibilityLabel("Close clean tabs review")
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var summaryText: String {
        guard !plan.isEmpty else { return "Nothing to clean up" }
        let duplicates = plan.duplicateGroups.reduce(0) { $0 + $1.closeIDs.count }
        var parts: [String] = []
        if duplicates > 0 {
            parts.append("\(duplicates) duplicate\(duplicates == 1 ? "" : "s")")
        }
        if !plan.staleTabs.isEmpty {
            parts.append("\(plan.staleTabs.count) stale")
        }
        return parts.joined(separator: " · ")
    }

    private var candidateList: some View {
        List {
            ForEach(plan.duplicateGroups, id: \.url) { group in
                Section {
                    ForEach(group.closeIDs, id: \.self) { id in
                        candidateRow(id: id, context: contextText(for: id))
                    }
                } header: {
                    Text("Duplicate: \(group.url) · keeping \(displayTitle(for: group.keepID))")
                        .font(HiveDesign.Typography.captionBold)
                        .foregroundStyle(.secondary)
                }
            }
            if !plan.staleTabs.isEmpty {
                Section("Stale Tabs") {
                    ForEach(plan.staleTabs, id: \.id) { stale in
                        candidateRow(id: stale.id, context: contextText(for: stale.id))
                    }
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    private func candidateRow(id: String, context: String) -> some View {
        let isSelected = !excluded.contains(id)
        return Toggle(isOn: Binding(
            get: { !excluded.contains(id) },
            set: { isOn in
                if isOn { excluded.remove(id) } else { excluded.insert(id) }
            }
        )) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle(for: id))
                        .font(HiveDesign.Typography.bodyMedium)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(displayURL(for: id) ?? "Untitled tab")
                        .font(HiveDesign.Typography.smallLabel)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Spacer()
                Text(context)
                    .font(HiveDesign.Typography.smallLabel)
                    .foregroundStyle(.secondary)
            }
        }
        .toggleStyle(.checkbox)
        .accessibilityLabel(isSelected
            ? "Close \(displayTitle(for: id))"
            : "Keep \(displayTitle(for: id))")
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.seal")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tertiary)
            Text("Nothing to clean up")
                .font(HiveDesign.Typography.subHeadingSemiBold)
                .foregroundStyle(.secondary)
            Text("Duplicate and stale tabs will appear here for one-click review.")
                .font(HiveDesign.Typography.sidebarItem)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }

    private var footer: some View {
        HStack {
            Text("Pinned and essential tabs are never suggested.")
                .font(HiveDesign.Typography.smallLabel)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { state.closeCleanTabs() }
                .buttonStyle(.borderless)
                .accessibilityLabel("Cancel clean tabs")
            Button(selectedCount == 0 ? "Nothing Selected" : "Close \(selectedCount) Tab\(selectedCount == 1 ? "" : "s")") {
                let ids = Set(plan.closeIDs.filter { !excluded.contains($0) })
                state.closeTabs(withIDs: ids)
            }
            .buttonStyle(.borderedProminent)
            .tint(selectedCount > 0 ? .red : .gray)
            .disabled(selectedCount == 0)
            .accessibilityLabel("Close selected tabs")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Display helpers

    private func tab(for id: String) -> BrowserState.Tab? {
        state.tabs.first { $0.id == id }
    }

    private func displayTitle(for id: String) -> String {
        guard let tab = tab(for: id) else { return "Tab" }
        return tab.model.title ?? tab.model.url?.host ?? "Untitled"
    }

    private func displayURL(for id: String) -> String? {
        guard let tab = tab(for: id) else { return nil }
        return (tab.model.url ?? tab.savedURL)?.absoluteString
    }

    private func relativeTime(for id: String) -> String {
        guard let tab = tab(for: id) else { return "" }
        return tab.lastAccessed.formatted(.relative(presentation: .named))
    }

    private func contextText(for id: String) -> String {
        var text = relativeTime(for: id)
        if tab(for: id)?.isHibernated == true {
            text += text.isEmpty ? "sleeping" : " · sleeping"
        }
        return text
    }
}
