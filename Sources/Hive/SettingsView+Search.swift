//
//  SettingsView+Search.swift
//  Hive
//
//  Carved out of SettingsView.swift by scripts/split_swift_type.py.
//  Pure extension split, no behavior change. Access was widened from
//  `private`/`private(set)` to internal so the cross-file extensions
//  compile; this app target has no external API surface.
//
//  Sections: - Search
//

import SwiftUI
import AppKit
import HiveCore

// MARK: - SettingsView + Search

@MainActor
extension SettingsView {


    // MARK: - Search

    var searchTab: some View {
        VStack(alignment: .leading, spacing: 24) {
            settingsGroup("Search Engine") {
                VStack(spacing: 6) {
                    ForEach(BrowserState.SearchEngine.allCases) { engine in
                        Button(action: { state.searchEngine = engine; state.scheduleAutosave() }) {
                            HStack(spacing: 10) {
                                Image(systemName: engine.icon)
                                    .font(HiveDesign.Typography.panelTitleMedium)
                                    .foregroundStyle(engine.color)
                                    .frame(width: 22)

                                VStack(alignment: .leading, spacing: 1) {
                                    Text(engine.rawValue)
                                        .font(HiveDesign.Typography.bodyMedium)
                                        .foregroundStyle(.primary)
                                    Text(searchEngineDescription(for: engine))
                                        .font(HiveDesign.Typography.smallLabel)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer()

                                if state.searchEngine == engine {
                                    Image(systemName: "checkmark")
                                        .font(HiveDesign.Typography.smallLabelBold)
                                        .foregroundStyle(Color.hiveAccent)
                                }
                            }
                            .padding(12)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(state.searchEngine == engine
                                        ? HiveDesign.Surface.level2
                                        : Color.primary.opacity(0.03))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}
