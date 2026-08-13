//
//  GeminiSidePanel+Autocomplete.swift
//  Hive
//
//  Carved out of GeminiSidePanel.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - @tab Autocomplete Dropdown
//

import SwiftUI
import HiveCore

// MARK: - GeminiSidePanel + Autocomplete

@MainActor
extension GeminiSidePanel {


    // MARK: - @tab Autocomplete Dropdown

    var tabAutocompleteDropdown: some View {
        VStack(spacing: 0) {
            Divider().opacity(0.5)
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(matchingTabs.enumerated()), id: \.element.id) { idx, tab in
                        tabAutocompleteRow(tab, index: idx)
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .background(HiveDesign.Material.panel)
    }


    func tabAutocompleteRow(_ tab: BrowserState.Tab, index: Int) -> some View {
        let title = tab.model.title.isEmpty ? (tab.model.url?.host ?? "Untitled") : tab.model.title
        let url = tab.model.url?.host ?? ""
        let isHighlighted = index == autocompleteIndex
        return Button(action: { insertTabReference(tab) }) {
            HStack(spacing: 8) {
                if let favicon = tab.model.faviconURL {
                    FaviconImage(url: favicon)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "doc.text")
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 16, height: 16)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(url)
                        .font(HiveDesign.Typography.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
                Text("@tab")
                    .font(HiveDesign.Typography.monoMicroMedium)
                    .foregroundStyle(Color.hiveAccent)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(HiveDesign.Surface.level2)
                    )
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isHighlighted
                    ? HiveDesign.Surface.level2
                    : Color.clear
            )
        }        .buttonStyle(.plain)
    }


    /// Prefills the input with /deep for multi-step research.
    /// Does NOT auto-send — the user types their query after the prefix.
    var deepResearchChip: some View {
        Button(action: {
            input = "/deep "
        }) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass.circle")
                    .font(.system(size: HiveDesign.Typography.sizeMD, weight: .medium))
                Text("Deep research")
                    .font(HiveDesign.Typography.sidebarItem)
                Spacer()
                Text("15+ sources")
                    .font(HiveDesign.Typography.monoMicroMedium)
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(Color.hiveAccent)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(Color.hiveAccent.opacity(0.10))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.hiveAccent.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Deep research — type your query after /deep")
    }
}
